import Foundation
import CryptoKit
import Security
import Combine

/// A scoped token is never embedded in the IPA or forwarded to an asset CDN.
enum UpdateCredential {
    private static var query:[String:Any] {[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.directside.updates",kSecAttrAccount as String:"github"]}
    static func read()->String? {
        var request=query;request[kSecReturnData as String]=true
        var result:CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary,&result)==errSecSuccess,let data=result as? Data else {return nil}
        return String(data:data,encoding:.utf8)
    }
    static func save(_ value:String) throws {
        guard value.range(of:"^[A-Za-z0-9_]{20,255}$",options:.regularExpression) != nil else {throw DirectSideError.message("Ungültiger GitHub-Zugang.")}
        let bytes=Data(value.utf8)
        let status=SecItemUpdate(query as CFDictionary,[kSecValueData as String:bytes] as CFDictionary)
        if status==errSecItemNotFound {
            var item=query;item[kSecValueData as String]=bytes;item[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary,nil)==errSecSuccess else {throw DirectSideError.message("Zugang konnte nicht sicher gespeichert werden.")}
        } else if status != errSecSuccess {throw DirectSideError.message("Zugang konnte nicht sicher gespeichert werden.")}
    }
    static func forget(){SecItemDelete(query as CFDictionary)}
}

final class UpdateTransport:NSObject,URLSessionDownloadDelegate,@unchecked Sendable {
    static let limit=500*1024*1024
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping (URLRequest?)->Void) {
        guard let url=request.url,url.scheme=="https",["api.github.com","release-assets.githubusercontent.com","objects.githubusercontent.com"].contains(url.host ?? ""),url.user==nil,url.password==nil,url.port==nil || url.port==443 else {completionHandler(nil);return}
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
    @Published var hasCredential=UpdateCredential.read() != nil
    @Published var showOffer=false
    private let transport=UpdateTransport()
    private lazy var session:URLSession = {
        let config=URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest=30;config.timeoutIntervalForResource=300
        return URLSession(configuration:config,delegate:transport,delegateQueue:nil)
    }()
    private var lastCheck:Date?
    private func request(_ path:String,asset:Bool=false)->URLRequest {
        var request=URLRequest(url:URL(string:"https://api.github.com/repos/Serekay/directside/"+path)!)
        request.setValue(asset ? "application/octet-stream":"application/vnd.github+json",forHTTPHeaderField:"Accept")
        request.setValue("2022-11-28",forHTTPHeaderField:"X-GitHub-Api-Version")
        request.setValue("DirectSide-iOS",forHTTPHeaderField:"User-Agent")
        if let token=UpdateCredential.read(){request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")}
        return request
    }
    func saveCredential(_ value:String) {
        do {try UpdateCredential.save(value.trimmingCharacters(in:.whitespacesAndNewlines));hasCredential=true;lastCheck=nil;message="Zugang gespeichert."}
        catch {message=error.localizedDescription}
    }
    func forgetCredential(){UpdateCredential.forget();hasCredential=false;available=nil;lastCheck=nil;message=""}
    func check(manual:Bool=false) async {
        guard !checking,!downloading else {return}
        if !manual,let lastCheck,Date().timeIntervalSince(lastCheck)<21600 {return}
        checking=true;defer{checking=false}
        message="Nach Updates suchen …"
        do {
            let (bytes,response)=try await session.bytes(for:request("releases/latest"))
            guard let http=response as? HTTPURLResponse else {throw DirectSideError.message("Updateprüfung fehlgeschlagen.")}
            if http.statusCode==404 {
                // A private repository and an empty release history both return 404.
                let (_,repoResponse)=try await session.data(for:request(""))
                if (repoResponse as? HTTPURLResponse)?.statusCode==200 {available=nil;message="Noch keine veröffentlichte Version verfügbar.";lastCheck=Date();return}
                throw DirectSideError.message("Für Updates aus dem privaten Repository einen GitHub-Zugang mit Leserechten hinterlegen.")
            }
            guard http.statusCode==200 else {throw DirectSideError.message("GitHub-Zugang oder Verbindung prüfen und erneut versuchen.")}
            var data=Data()
            for try await byte in bytes {data.append(byte);if data.count>2_000_000 {throw DirectSideError.message("Ungültige Updateantwort.")}}
            guard let release=try JSONSerialization.jsonObject(with:data) as? [String:Any],release["draft"] as? Bool==false,release["prerelease"] as? Bool==false,let tag=release["tag_name"] as? String,UpdateVersion.parts(tag) != nil else {throw DirectSideError.message("Ungültige Updateantwort.")}
            let installed=Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            guard UpdateVersion.newer(tag,than:installed) else {available=nil;message="DirectSide ist aktuell.";lastCheck=Date();return}
            guard let assets=release["assets"] as? [[String:Any]],let asset=assets.first(where:{$0["name"] as? String=="DirectSide.ipa"}),asset["state"] as? String=="uploaded",let id=asset["id"] as? Int,id>0,let size=asset["size"] as? Int,size>0,size<=UpdateTransport.limit,let digest=asset["digest"] as? String,digest.range(of:"^sha256:[a-fA-F0-9]{64}$",options:.regularExpression) != nil else {throw DirectSideError.message("Das iPhone-Update ist noch nicht vollständig veröffentlicht.")}
            available=AppRelease(version:tag.hasPrefix("v") ? String(tag.dropFirst()):tag,notes:release["body"] as? String ?? "",assetID:id,size:size,sha256:String(digest.dropFirst(7)).lowercased())
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
            let (file,response)=try await session.download(for:request("releases/assets/\(release.assetID)",asset:true))
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
