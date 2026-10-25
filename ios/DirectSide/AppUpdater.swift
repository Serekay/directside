import Foundation
import CryptoKit
import Combine

final class UpdateTransport:NSObject,URLSessionDownloadDelegate,@unchecked Sendable {
    static let limit=500*1024*1024
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping (URLRequest?)->Void) {
        guard let url=request.url,url.scheme=="https",["github.com","api.github.com","release-assets.githubusercontent.com","objects.githubusercontent.com"].contains(url.host ?? ""),url.user==nil,url.password==nil,url.port==nil || url.port==443 else {completionHandler(nil);return}
        var next=request
        if url.host != "api.github.com" {next.setValue(nil,forHTTPHeaderField:"Authorization")}
        completionHandler(next)
    }
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didWriteData bytesWritten:Int64,totalBytesWritten:Int64,totalBytesExpectedToWrite:Int64) {
        if totalBytesWritten>Int64(Self.limit) || totalBytesExpectedToWrite>Int64(Self.limit) {downloadTask.cancel()}
    }
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didFinishDownloadingTo location:URL) {}
}

@MainActor final class AppUpdater:ObservableObject {
    @Published var available:AppRelease?
    @Published var checking=false
    @Published var downloading=false
    @Published var message=""
    @Published var showOffer=false
    private let transport=UpdateTransport()
    private lazy var session:URLSession = {
        let config=URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest=30;config.timeoutIntervalForResource=300
        return URLSession(configuration:config,delegate:transport,delegateQueue:nil)
    }()
    private var lastCheck:Date?
    private func request(_ path:String)->URLRequest {
        var request=URLRequest(url:URL(string:"https://api.github.com/repos/Serekay/directside/"+path)!)
        request.setValue("application/vnd.github+json",forHTTPHeaderField:"Accept")
        request.setValue("2022-11-28",forHTTPHeaderField:"X-GitHub-Api-Version")
        request.setValue("DirectSide-iOS",forHTTPHeaderField:"User-Agent")
        return request
    }
    func check(manual:Bool=false) async {
        guard !checking,!downloading else {return}
        if !manual,UserDefaults.standard.object(forKey:"automaticUpdates") as? Bool == false {return}
        if !manual,let lastCheck,Date().timeIntervalSince(lastCheck)<21600 {return}
        checking=true;defer{checking=false}
        message="Nach Updates suchen …"
        do {
            let (bytes,response)=try await session.bytes(for:request("releases/latest"))
            guard let http=response as? HTTPURLResponse else {throw DirectSideError.message("Updateprüfung fehlgeschlagen.")}
            if http.statusCode==404 {
                available=nil;message="Keine Updates verfügbar.";lastCheck=Date();return
            }
            if http.statusCode==403 || http.statusCode==429 {throw DirectSideError.message("Updateprüfung vorübergehend nicht verfügbar. Bitte später erneut versuchen.")}
            guard http.statusCode==200 else {throw DirectSideError.message("Updateprüfung nicht möglich. Bitte die Internetverbindung prüfen.")}
            var data=Data()
            for try await byte in bytes {data.append(byte);if data.count>2_000_000 {throw DirectSideError.message("Ungültige Updateantwort.")}}
            guard let metadata=try JSONSerialization.jsonObject(with:data) as? [String:Any] else {throw DirectSideError.message("Ungültige Updateantwort.")}
            let installed=Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            guard let release=try AppRelease.decode(metadata,installed:installed) else {available=nil;message="DirectSide ist aktuell.";lastCheck=Date();return}
            available=release
            message="Update verfügbar";lastCheck=Date();showOffer=true
        }catch {message=error.localizedDescription}
    }
    func install(engine:Engine,connection:Connection) async {
        guard let release=available,!downloading,!engine.busy else {return}
        engine.busy=true
        guard await engine.requireInstallConnection(peer:connection.peer,port:connection.port) else {return}
        downloading=true;engine.busy=true;defer{downloading=false;engine.busy=false}
        var staged:URL?
        do {
            message="Update herunterladen …"
            let (file,response)=try await session.download(from:release.downloadURL)
            defer{try? FileManager.default.removeItem(at:file)}
            guard (response as? HTTPURLResponse)?.statusCode==200 else {throw DirectSideError.message("Update-Download fehlgeschlagen.")}
            let size=(try file.resourceValues(forKeys:[.fileSizeKey])).fileSize
            guard size==release.size else {throw DirectSideError.message("Update-Dateigröße stimmt nicht.")}
            let handle=try FileHandle(forReadingFrom:file);defer{try? handle.close()}
            var digest=SHA256()
            while let block=try handle.read(upToCount:1_048_576),!block.isEmpty {digest.update(data:block)}
            guard digest.finalize().map({String(format:"%02x",$0)}).joined()==release.sha256 else {throw DirectSideError.message("Update-Prüfsumme stimmt nicht.")}
            let destination=Paths.support.appendingPathComponent("DirectSide-update.ipa")
            if FileManager.default.fileExists(atPath:destination.path){try FileManager.default.removeItem(at:destination)}
            try FileManager.default.moveItem(at:file,to:destination);staged=destination
            try FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:destination.path)
            // Persist before replacing the running process. The next launch promotes
            // this IPA only if the installed version matches the verified release.
            try JSONEncoder().encode(PendingSelfUpdate(version:release.version,sha256:release.sha256)).write(to:Self.pending,options:.atomic)
            try await engine.installSelfUpdate(destination,version:release.version,peer:connection.peer,port:connection.port)
            available=nil;message="Update installiert. DirectSide erneut öffnen."
        }catch {
            if !engine.vpnRequired {engine.fail(error.localizedDescription)}
            message="Update konnte nicht installiert werden."
            if let staged {try? FileManager.default.removeItem(at:staged)}
            try? FileManager.default.removeItem(at:Self.pending)
        }
    }
    private struct PendingSelfUpdate:Codable {let version:String;let sha256:String}
    private static var pending:URL {Paths.support.appendingPathComponent("pending-self-update.json")}
    static func recoverOriginal() throws {
        guard FileManager.default.fileExists(atPath:pending.path) else {return}
        let record=try JSONDecoder().decode(PendingSelfUpdate.self,from:Data(contentsOf:pending))
        let staged=Paths.support.appendingPathComponent("DirectSide-update.ipa")
        guard Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String==record.version else {return}
        let data=try Data(contentsOf:staged,options:.mappedIfSafe)
        guard SHA256.hash(data:data).map({String(format:"%02x",$0)}).joined()==record.sha256 else {throw DirectSideError.message("Update-Prüfsumme stimmt nicht.")}
        try data.write(to:Paths.original,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
        try FileManager.default.removeItem(at:staged);try FileManager.default.removeItem(at:pending)
    }
}
