import UIKit
import Foundation
import Security

@MainActor
enum LiveContainerBridge {
    private static let service="com.directside.livecontainer"
    private static let account="signing-transfer"
    private struct CertificateArchive:Decodable {let certificate:[UInt8];let password:String}
    private static var query:[String:Any] {[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account]}
    static var certificateReady:Bool {
        var request=query;request[kSecReturnData as String]=true
        return SecItemCopyMatching(request as CFDictionary,nil)==errSecSuccess
    }
    static func importTransfer(from path:URL=Paths.documents.appendingPathComponent("DirectSide-livecontainer.json")) throws {
        guard FileManager.default.fileExists(atPath:path.path) else {return}
        let bytes=try Data(contentsOf:path)
        guard bytes.count<131072 else {throw DirectSideError.message("LiveContainer-Zertifikat ist ungültig.")}
        let archive=try JSONDecoder().decode(CertificateArchive.self,from:bytes)
        guard !archive.certificate.isEmpty,!archive.password.isEmpty else {throw DirectSideError.message("LiveContainer-Zertifikat ist unvollständig.")}
        // Validate PKCS#12 before replacing a previously stored identity.
        var imported:CFArray?
        guard SecPKCS12Import(Data(archive.certificate) as CFData,[kSecImportExportPassphrase as String:archive.password] as CFDictionary,&imported)==errSecSuccess else {throw DirectSideError.message("LiveContainer-Zertifikat konnte nicht geprüft werden.")}
        let update=[kSecValueData as String:bytes]
        let status=SecItemUpdate(query as CFDictionary,update as CFDictionary)
        if status==errSecItemNotFound {
            var item=query;item[kSecValueData as String]=bytes;item[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary,nil)==errSecSuccess else {throw DirectSideError.message("Zertifikat konnte nicht sicher gespeichert werden.")}
        } else if status != errSecSuccess {throw DirectSideError.message("Zertifikat konnte nicht sicher gespeichert werden.")}
        try FileManager.default.removeItem(at:path)
    }
    static func configure(engine:Engine) {
        guard available else {engine.error="LiveContainer zuerst in den Einstellungen installieren.";return}
        var request=query;request[kSecReturnData as String]=true
        var result:CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary,&result)==errSecSuccess,let data=result as? Data,let archive=try? JSONDecoder().decode(CertificateArchive.self,from:data) else {engine.error="Zertifikat unter Einstellungen → LiveContainer erneut übertragen.";return}
        var url=URLComponents();url.scheme="livecontainer";url.host="certificate"
        url.queryItems=[URLQueryItem(name:"cert",value:Data(archive.certificate).base64EncodedString()),URLQueryItem(name:"password",value:archive.password)]
        guard let destination=url.url else {return}
        UIApplication.shared.open(destination,options:[:]) {opened in Task{@MainActor in
            if opened {engine.message="Zertifikat an LiveContainer übergeben. Dort den JIT-less-Test starten."}
            else {engine.error="LiveContainer konnte nicht geöffnet werden."}
        }}
    }
    static var available:Bool {URL(string:"livecontainer://").map{UIApplication.shared.canOpenURL($0)} ?? false}
    static func open() {if let url=URL(string:"livecontainer://") {UIApplication.shared.open(url)}}
    @MainActor static func importApp(_ app:CatalogApp,engine:Engine) {
        guard available else {engine.error="LiveContainer ist noch nicht installiert. Du kannst die offizielle Standalone-IPA über DirectSide installieren. DirectSide und LiveContainer benötigen zusammen zwei der drei Plätze.";return}
        guard let latest=app.latest,(try? SourceURL.parse(latest.downloadURL.absoluteString)) != nil else {engine.error="Keine geeignete IPA-Adresse vorhanden.";return}
        var url=URLComponents();url.scheme="livecontainer";url.host="install";url.queryItems=[URLQueryItem(name:"url",value:latest.downloadURL.absoluteString)]
        guard let destination=url.url else {return}
        UIApplication.shared.open(destination,options:[:]){success in Task{@MainActor in
            if success {engine.message="An LiveContainer übergeben. Installation dort bestätigen."}
            else {engine.error="LiveContainer konnte nicht geöffnet werden."}
        }}
    }
}
