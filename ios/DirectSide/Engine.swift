import Foundation
import Combine
import SwiftUI
import CryptoKit

@MainActor final class Engine: ObservableObject {
    @Published var message = "Bereit"
    @Published var error: String?
    @Published var vpnRequired=false
    @Published var deviceIcons:[String:Data]=[:]
    @Published var busy = true
    private var restoring=true
    private var sessionImportPending=false
    private var pendingLocalIdentity:Data?
    var preparingAccount:Bool {restoring || sessionImportPending}
    var showsProgress:Bool {busy && !restoring}
    @Published var loggedIn = false
    @Published var signingMode=UserDefaults.standard.string(forKey:"signingMode") ?? "account"
    @Published var importedIdentity:ImportedSigningIdentity?
    private var identityImportFiles:[URL]=[]
    var canSign:Bool {signingMode=="imported" ? importedIdentity != nil && importedIdentity?.valid != false:loggedIn}
    func setSigningMode(_ mode:String) {guard !busy,["account","imported"].contains(mode) else {return};signingMode=mode;UserDefaults.standard.set(mode,forKey:"signingMode")}
    func forgetImportedIdentity(){guard !busy else {return};busy=true;send(["command":"forget_identity"])}
    func importIdentity(p12:URL,profiles:[URL],password:String) async {
        guard !busy,!profiles.isEmpty,profiles.count<=32 else {return}
        busy=true;error=nil;message="Zertifikat prüfen …"
        do {
            for (index,url) in ([p12]+profiles).enumerated() {
                let access=url.startAccessingSecurityScopedResource();defer{if access {url.stopAccessingSecurityScopedResource()}}
                guard ((try url.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? Int.max)<=262144 else {throw DirectSideError.message("Zertifikat oder Profil ist zu groß.")}
                let file=Paths.support.appendingPathComponent("identity-"+UUID().uuidString+(index==0 ? ".p12":".mobileprovision"))
                identityImportFiles.append(file)
                try FileManager.default.copyItem(at:url,to:file)
                try FileManager.default.setAttributes([.protectionKey:FileProtectionType.complete],ofItemAtPath:file.path)
            }
            send(["command":"import_identity","p12_path":identityImportFiles[0].path,"profile_paths":identityImportFiles.dropFirst().map(\.path),"password":password])
        }catch {cleanupIdentityImport();fail(error.localizedDescription)}
    }
    private func cleanupIdentityImport(){for file in identityImportFiles {try? FileManager.default.removeItem(at:file)};identityImportFiles=[]}
    @Published var teamName = "Nicht angemeldet"
    @Published var progress = 0.0
    @Published var needsCode = false
    @Published var accountEmail=UserDefaults.standard.string(forKey:"accountEmail") ?? ""
    @Published var codeNumbers:[[String:Any]]=[]
    @Published var codeError=""
    @Published var teams: [[String: String]] = []
    @Published var managed: [ManagedApp] = []
    @Published var sources: [SourceCatalog] = []
    @Published var pendingSource: SourceCatalog?
    @Published var pairingReady = false
    @Published var liveContainerCertificateReady = false
    private var timer: Timer?
    private var coreStarted=false
    private var signingImportPending=false
    private var importedArchivePending=false
    private var importedArchive:URL {Paths.support.appendingPathComponent("DirectSide-imported.json")}
    private var pendingApp: ManagedApp?
    private var bootstrap: Bootstrap?
    private var installContinuation: CheckedContinuation<Void,Error>?
    @Published var sourceFailures: [String:String] = [:]
    @Published var refreshingSources = false
    private let sourceRefresh=SourceRefreshCoordinator()
    @Published var selfExpiration:Date?
    @Published var slotsUsed:Int?
    @Published var appIDs:[RegisteredAppID]=[]
    @Published var appIDsLimit:Int?
    @Published var appIDsAvailable:Int?
    @Published var loadingAppIDs=false
    @Published var appIDsError:String?
    func loadAppIDs() {
        guard loggedIn,!busy,!loadingAppIDs else {return}
        loadingAppIDs=true;appIDsError=nil;send(["command":"app_ids"])
    }
    @Published var developerApps:[String]=[]
    @Published var deviceApps:[DeviceApp]=[]
    @Published var signingCertificates:[SigningCertificate]=[]
    @Published var certificatesLoaded=false
    @Published var certificateTeam=""
    private var removalConnection:(String,Int)?
    private var inspectionConnection:(String,Int)?
    private var inspecting=false
    private var lastInspection:Date?
    @Published var importedIPA:ImportedIPA?
    @Published var needsPairingCode=false
    private var importingPath:URL?
    func pairDevice(peer:String,port:Int) {
        guard !busy else {return}
        guard port>0 else {fail("LocalDevVPN verbinden und erneut suchen.");return}
        busy=true;error=nil;message="Gerät koppeln …"
        send(["command":"pair_local","peer":peer,"port":port,"pairing_path":Paths.pairing.path,"bootstrap_path":Paths.bootstrap.path])
    }
    func submitPairingCode(_ code:String) {needsPairingCode=false;send(["code":code])}
    func configureLiveContainer() {
        guard !busy,canSign else {return}
        busy=true;error=nil;message="Zertifikat vorbereiten …"
        send(["command":"export_livecontainer","path":Paths.support.appendingPathComponent("livecontainer-transfer.json").path,"signing_mode":signingMode])
    }
    func installLiveContainer(peer:String,port:Int) async {
        guard !busy else {return}
        guard canSign,pairingReady else {fail("In den Einstellungen anmelden oder ein Zertifikat importieren und dieses Gerät koppeln.");return}
        busy=true;error=nil
        guard await requireInstallConnection(peer:peer,port:port) else {return}
        message="LiveContainer herunterladen …"
        do {
            let (temp,response)=try await URLSession.shared.download(from:URL(string:"https://github.com/LiveContainer/LiveContainer/releases/download/3.8.0/LiveContainer.ipa")!)
            defer{try? FileManager.default.removeItem(at:temp)}
            guard (response as? HTTPURLResponse)?.statusCode==200,response.url?.scheme=="https" else {throw DirectSideError.message("LiveContainer-Download fehlgeschlagen.")}
            let bytes=try Data(contentsOf:temp,options:.mappedIfSafe)
            guard bytes.count==4_707_271,SHA256.hash(data:bytes).map({String(format:"%02x",$0)}).joined()=="b6fea95e30083382e29ffef88fa1aaa40b5069e1112e5307d490dab04648bba6" else {throw DirectSideError.message("LiveContainer-Prüfsumme stimmt nicht.")}
            let saved=Paths.support.appendingPathComponent("LiveContainer-3.8.0.ipa")
            try bytes.write(to:saved,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
            try await waitForInstall(saved,app:ManagedApp(id:"com.kdt.livecontainer",name:"LiveContainer",cachedIPA:saved.path,installedAt:Date(),version:"3.8.0"),peer:peer,port:port)
            configureLiveContainer()
        }catch{fail(error.localizedDescription)}
    }

    func importIPA(_ url:URL) async {
        guard !busy else {return}
        guard url.pathExtension.lowercased()=="ipa" else {fail("Bitte eine IPA-Datei auswählen.");return}
        busy=true;error=nil;message="IPA prüfen …"
        let saved=Paths.support.appendingPathComponent(UUID().uuidString+".ipa")
        do {
            try await Task.detached {
                let scoped=url.startAccessingSecurityScopedResource()
                defer {if scoped {url.stopAccessingSecurityScopedResource()}}
                try FileManager.default.copyItem(at:url,to:saved)
                try FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:saved.path)
            }.value
            importingPath=saved;send(["command":"inspect_ipa","path":saved.path])
        } catch {try? FileManager.default.removeItem(at:saved);fail(error.localizedDescription)}
    }
    func cancelIPAImport() {
        if let item=importedIPA {try? FileManager.default.removeItem(at:item.file)}
        importedIPA=nil
    }
    func installImportedIPA(peer:String,port:Int) {
        guard !busy,let item=importedIPA else {return}
        importedIPA=nil;busy=true
        let app=ManagedApp(id:item.bundleID,name:item.name,cachedIPA:item.file.path,installedAt:Date(),version:item.version)
        Task {do {try await waitForInstall(item.file,app:app,peer:peer,port:port)}catch{fail(error.localizedDescription)}}
    }

    func loadCertificates() {
        guard !busy,loggedIn else {return}
        busy=true;send(["command":"certificates"])
    }
    func revokeCertificate(_ certificate:SigningCertificate) {
        guard !busy,loggedIn,!certificate.serial.isEmpty,!certificateTeam.isEmpty,signingCertificates.contains(where:{$0.serial==certificate.serial}) else {return}
        busy=true;error=nil
        send(["command":"revoke_certificate","serial":certificate.serial,"team_id":certificateTeam,"confirmed":true])
    }
    func deviceApp(for app:ManagedApp)->DeviceApp? {
        if let id=app.installedBundleID {return deviceApps.first{$0.id==id} ?? DeviceApp(id:id,name:app.name,developer:true)}
        let team=signingMode=="imported" ? importedIdentity?.team_id ?? "":certificateTeam
        let candidates=deviceApps.filter {device in
            guard device.developer else {return false}
            if device.id==app.id || (!team.isEmpty && device.id==app.id+"."+team) {return true}
            guard device.name==app.name,device.id.hasPrefix(app.id+".") else {return false}
            let suffix=device.id.dropFirst(app.id.count+1)
            return suffix.utf8.count==10 && suffix.utf8.allSatisfy{(48...57).contains($0) || (65...90).contains($0)}
        }
        return candidates.count==1 ? candidates.first:nil
    }
    func removeDeviceApp(_ app:DeviceApp,peer:String,port:Int) {
        guard !busy,pairingReady,port>0,app.developer,deviceApps.contains(where:{$0.id==app.id && $0.developer}) || managed.contains(where:{$0.installedBundleID==app.id}) else {return}
        busy=true;error=nil;removalConnection=(peer,port)
        send(["command":"remove_local_app","bundle_id":app.id,"peer":peer,"port":port,"pairing_path":Paths.pairing.path,"confirmed":true])
    }
    var slotsText:String {slotsUsed.map{"\($0) Entwickler-Apps"} ?? "App-Plätze noch nicht geprüft"}
    func inspectConnection(peer:String,port:Int,force:Bool=false) {
        guard !busy,!inspecting,port>0,pairingReady else {return}
        if !force,let lastInspection,inspectionConnection?.0==peer,inspectionConnection?.1==port,Date().timeIntervalSince(lastInspection)<60 {return}
        inspecting=true;inspectionConnection=(peer,port)
        Task {
            guard await InstallConnection().reachable(peer:peer,port:port),!busy else {inspecting=false;return}
            send(["command":"inspect_local","peer":peer,"port":port,"pairing_path":Paths.pairing.path])
        }
    }
    var remainingDays:Int? {
        let dates=managed.compactMap{$0.expiresAt} + (selfExpiration.map{[$0]} ?? [])
        return dates.min().map{max(0,Int(ceil($0.timeIntervalSinceNow/86400)))}
    }
    var selfExpirationText:String {selfExpiration.map{expiryText($0)} ?? "Gültigkeit wird geprüft"}
    func expirationText(_ app:ManagedApp)->String {app.expiresAt.map{expiryText($0)} ?? "Zuletzt erneuert: \(app.installedAt.formatted(date:.abbreviated,time:.omitted))"}
    private func expiryText(_ date:Date)->String {date.timeIntervalSinceNow<=0 ? "Signatur abgelaufen":"Signatur noch \(max(1,Int(ceil(date.timeIntervalSinceNow/86400)))) Tage gültig"}

    var updates: [(app:CatalogApp,source:SourceCatalog)] {
        managed.compactMap { installed in
            guard let source=sources.first(where: { $0.id == installed.sourceID }),
                  let app=source.apps.first(where: { $0.id == installed.id }),let latest=app.latest,
                  latest.version != installed.version || latest.buildVersion != installed.buildVersion else { return nil }
            return (app,source)
        }
    }
    func installed(_ app:CatalogApp) -> ManagedApp? { managed.first { $0.id == app.id } }
    func hasUpdate(_ app:CatalogApp) -> Bool {
        guard let installed=installed(app),let latest=app.latest else { return false }
        return installed.version != latest.version || installed.buildVersion != latest.buildVersion
    }

    init() {
        let awaitingAccountTransfer=FileManager.default.fileExists(atPath:Paths.sessionImport.path)
        // A terminated import must not leave temporary private-key copies behind.
        if let files=try? FileManager.default.contentsOfDirectory(at:Paths.support,includingPropertiesForKeys:nil) {
            for file in files where file.lastPathComponent.hasPrefix("identity-") && ["p12","mobileprovision"].contains(file.pathExtension) {try? FileManager.default.removeItem(at:file)}
        }
        sources = load("sources.json") ?? []
        managed = load("apps.json") ?? []
        refreshBootstrap()
        guard ds_set_anisette_callback(ds_swift_anisette_generate,ds_swift_anisette_release) else {self.error="Could not connect the local authentication runtime.";return}
        guard ds_set_anisette_resync_callback(ds_swift_anisette_resync) else {self.error="Could not connect local authentication synchronization.";return}
        ds_start()
        coreStarted=true
        importSigningIfNeeded()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        if !awaitingAccountTransfer {send(["command":"restore"])}
        send(["command":"imported_identity"])
        if let path=Bundle.main.path(forResource:"embedded",ofType:"mobileprovision") {send(["command":"profile","path":path])}
    }
    func refreshBootstrap() {
        do {
            let partialSession=Paths.sessionImport.appendingPathExtension("pending")
            if let modified=try? partialSession.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate,Date().timeIntervalSince(modified)>600 {
                try? FileManager.default.removeItem(at:partialSession)
            }
            if FileManager.default.fileExists(atPath:Paths.sessionImport.path) {
                try FileManager.default.setAttributes([.protectionKey:FileProtectionType.complete],ofItemAtPath:Paths.sessionImport.path)
            }
            try Paths.importBootstrap()
            let transfer=Paths.documents.appendingPathComponent("DirectSide-imported.json")
            if FileManager.default.fileExists(atPath:transfer.path) {
                let data=try Data(contentsOf:transfer)
                guard data.count<=12_000_000 else {throw DirectSideError.message("Zertifikatsdatei ist zu groß.")}
                try data.write(to:importedArchive,options:[.atomic,.completeFileProtection])
                try FileManager.default.removeItem(at:transfer)
            }
            try AppUpdater.recoverOriginal()
            let transferred=try LiveContainerBridge.importTransfer()
            liveContainerCertificateReady=LiveContainerBridge.certificateReady
            bootstrap = try? JSONDecoder().decode(Bootstrap.self, from: Data(contentsOf: Paths.bootstrap))
            pairingReady = bootstrap != nil && FileManager.default.fileExists(atPath: Paths.pairing.path)
            importSigningIfNeeded()
            if transferred && LiveContainerBridge.available {LiveContainerBridge.configure(engine:self)}
        } catch { self.error = error.localizedDescription }
    }
    private func importSigningIfNeeded() {
        defer {importSessionIfNeeded()}
        if coreStarted,!importedArchivePending,FileManager.default.fileExists(atPath:importedArchive.path) {
            importedArchivePending=true;send(["command":"import_identity","archive_path":importedArchive.path])
        }
        guard coreStarted,!signingImportPending,FileManager.default.fileExists(atPath:Paths.signing.path) else {return}
        signingImportPending=true;send(["command":"import_signing","path":Paths.signing.path])
    }
    private func importSessionIfNeeded() {
        guard coreStarted,!signingImportPending,!sessionImportPending,FileManager.default.fileExists(atPath:Paths.sessionImport.path) else {return}
        guard let profile=Bundle.main.path(forResource:"embedded",ofType:"mobileprovision"),!accountEmail.isEmpty else {
            try? FileManager.default.removeItem(at:Paths.sessionImport);restoring=false;busy=false;return
        }
        sessionImportPending=true;restoring=true;busy=true
        if let data=try? Data(contentsOf:Paths.sessionImport),data.count<=131072,
           let transfer=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let identity=transfer["local_identity"] as? [String:Any] {
            pendingLocalIdentity=try? JSONSerialization.data(withJSONObject:identity)
        }
        send(["command":"import_session","path":Paths.sessionImport.path,"email":accountEmail,"profile_path":profile])
    }
    func send(_ request: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: request), let command = String(data: data, encoding: .utf8) else { return }
        if !command.withCString({ ds_send($0) }) { fail("Der Signierkern antwortet nicht.") }
    }
    func login(email: String, password: String) {
        guard !busy, !email.isEmpty, !password.isEmpty else { return }
        busy = true
        send(["command":"login", "email":email, "password":password])
    }
    func submitCode(_ code: String) {
        guard code.count == 6, code.allSatisfy(\.isNumber) else { error = "Bitte sechs Ziffern eingeben."; return }
        needsCode = false
        send(["action":"code", "code":code])
    }
    func cancelCode() { needsCode = false; send(["action":"cancel"]) }
    func requestCode(_ action:String,number:Int=0) {needsCode=false;send(["action":action,"number_id":number])}
    func chooseTeam(_ id: String) { teams=[]; send(["team_id":id]) }
    func logout() { guard !busy else { return }; send(["command":"logout"]); loggedIn=false; teamName="Nicht angemeldet" }
    private func poll() {
        for _ in 0..<100 {
            guard let pointer = ds_poll() else { break }
            let string = String(cString: pointer)
            ds_free(pointer)
            guard let data = string.data(using: .utf8), let event = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let type = event["event"] as? String else { continue }
            switch type {
            case "session_diagnostic":
                let report:[String:String]=["stage":event["stage"] as? String ?? "unknown","detail":event["detail"] as? String ?? ""]
                if let data=try? JSONSerialization.data(withJSONObject:report) {try? data.write(to:Paths.sessionImport.deletingLastPathComponent().appendingPathComponent("DirectSide-account-status.json"),options:[.atomic,.completeFileProtection])}
            case "imported_identity":
                if let value=event["identity"],!(value is NSNull),let bytes=try? JSONSerialization.data(withJSONObject:value) {importedIdentity=try? JSONDecoder().decode(ImportedSigningIdentity.self,from:bytes)} else {importedIdentity=nil}
                if !identityImportFiles.isEmpty || importedArchivePending {signingMode="imported";UserDefaults.standard.set(signingMode,forKey:"signingMode");cleanupIdentityImport();importedArchivePending=false}
                busy=restoring;message="Zertifikat geprüft."
            case "pairing_pin":needsPairingCode=true;message="Pairing-Code eingeben"
            case "paired_local":busy=false;needsPairingCode=false;refreshBootstrap();message="Gerät gekoppelt"
            case "livecontainer_exported":
                do {try LiveContainerBridge.importTransfer(from:Paths.support.appendingPathComponent("livecontainer-transfer.json"));liveContainerCertificateReady=LiveContainerBridge.certificateReady;busy=false;LiveContainerBridge.configure(engine:self)}catch{fail(error.localizedDescription)}
            case "status": message = event["message"] as? String ?? message
            case "progress": progress = (event["value"] as? Double ?? 0)/100
            case "logged_in": restoring=false;busy=false; loggedIn=true;signingCertificates=[];certificatesLoaded=false;certificateTeam=event["team_id"] as? String ?? ""; teamName=event["team"] as? String ?? "Developer-Team"; message="Angemeldet";if let email=event["email"] as? String {accountEmail=email;UserDefaults.standard.set(email,forKey:"accountEmail")}
            case "signing_imported": signingImportPending=false;if let email=event["email"] as? String {accountEmail=email;UserDefaults.standard.set(email,forKey:"accountEmail")};importSessionIfNeeded()
            case "session_imported":
                Task {
                    do {
                        if let identity=pendingLocalIdentity {try await LocalAnisetteService.shared.importIdentity(identity)}
                        pendingLocalIdentity=nil;sessionImportPending=false;signingMode="account";UserDefaults.standard.set(signingMode,forKey:"signingMode");send(["command":"restore"])
                    } catch {
                        pendingLocalIdentity=nil;sessionImportPending=false;restoring=false;busy=false;message="Bitte anmelden"
                        let report=["stage":"identity_import_failed","detail":error.localizedDescription]
                        if let data=try? JSONSerialization.data(withJSONObject:report) {try? data.write(to:Paths.sessionImport.deletingLastPathComponent().appendingPathComponent("DirectSide-account-status.json"),options:[.atomic,.completeFileProtection])}
                    }
                }
            case "profile": if let raw=event["expires_at"] as? String {selfExpiration=ISO8601DateFormatter().date(from:raw)}
            case "slots": slotsUsed=event["used"] as? Int;developerApps=(event["apps"] as? [[String:String]] ?? []).compactMap{$0["name"]}
            case "account_quota":appIDsLimit=event["limit"] as? Int;appIDsAvailable=event["available"] as? Int
            case "app_ids":
                loadingAppIDs=false;appIDsLimit=event["limit"] as? Int;appIDsAvailable=event["available"] as? Int
                if let bytes=try? JSONSerialization.data(withJSONObject:event["ids"] ?? []),let ids=try? JSONDecoder().decode([RegisteredAppID].self,from:bytes) {appIDs=ids.sorted{$0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending}}
            case "local_app_icons":
                for icon in event["icons"] as? [[String:String]] ?? [] {if let id=icon["id"],let raw=icon["png"],let data=Data(base64Encoded:raw),data.count<=1_048_576 {deviceIcons[id]=data}}
            case "local_apps":
                inspecting=false;lastInspection=Date()
                if let bytes=try? JSONSerialization.data(withJSONObject:event["apps"] ?? []),let apps=try? JSONDecoder().decode([DeviceApp].self,from:bytes) {deviceApps=apps.filter{$0.developer}.sorted{($0.developer ? "0":"1")+$0.name.lowercased()<($1.developer ? "0":"1")+$1.name.lowercased()}}
                for index in managed.indices where managed[index].installedBundleID==nil {
                    if let device=deviceApp(for:managed[index]) {managed[index].installedBundleID=device.id}
                }
                save(managed,"apps.json")
                if let (peer,port)=inspectionConnection {
                    let ids=deviceApps.map(\.id).filter{deviceIcons[$0]==nil}
                    for index in stride(from:0,to:ids.count,by:12) {send(["command":"local_app_icons","peer":peer,"port":port,"pairing_path":Paths.pairing.path,"bundles":Array(ids[index..<min(index+12,ids.count)])])}
                }
            case "ipa_inspected":
                if let path=event["path"] as? String,let file=importingPath,path==file.path,let bundle=event["bundle_id"] as? String {
                    importedIPA=ImportedIPA(file:file,bundleID:bundle,name:event["name"] as? String ?? "Imported app",version:event["version"] as? String)
                }
                importingPath=nil;busy=false
            case "app_removed":
                busy=false;message="App entfernt."
                if let id=event["bundle_id"] as? String {
                    let removed=managed.filter{$0.installedBundleID==id || $0.id==id || (!$0.id.isEmpty && id==$0.id+"."+certificateTeam)}
                    managed.removeAll{item in removed.contains{$0.id==item.id}}
                    save(managed,"apps.json")
                    for app in removed {
                        let file=URL(fileURLWithPath:app.cachedIPA).standardizedFileURL
                        if file.deletingLastPathComponent()==Paths.support.standardizedFileURL && !managed.contains(where:{$0.cachedIPA==file.path}) && file != Paths.original {try? FileManager.default.removeItem(at:file)}
                    }
                    deviceApps.removeAll{$0.id==id};deviceIcons.removeValue(forKey:id)
                }
                if let (peer,port)=removalConnection {removalConnection=nil;inspectConnection(peer:peer,port:port)}
            case "certificates":
                if let bytes=try? JSONSerialization.data(withJSONObject:event["certificates"] ?? []),let items=try? JSONDecoder().decode([SigningCertificate].self,from:bytes) {signingCertificates=items}
                certificateTeam=event["team_id"] as? String ?? "";certificatesLoaded=true;busy=false
            case "certificate_revoked":message="Zertifikat widerrufen. Zugehörige Apps neu signieren."
            case "logged_out": restoring=false;loggedIn=false; busy=false;signingCertificates=[];certificatesLoaded=false;certificateTeam="";appIDs=[];appIDsLimit=nil;appIDsAvailable=nil;loadingAppIDs=false;appIDsError=nil
            case "two_factor": codeNumbers=event["numbers"] as? [[String:Any]] ?? [];codeError=event["last_error"] == nil || event["last_error"] is NSNull ? "":"Code nicht akzeptiert. Bitte erneut versuchen.";needsCode=true;message="Apple-Bestätigung erforderlich"
            case "choose_team": teams=(event["teams"] as? [[String:Any]] ?? []).map { ["id":$0["id"] as? String ?? "", "name":$0["name"] as? String ?? "Developer-Team"] }
            case "installed":
                busy=false; progress=1; message="Installation abgeschlossen"
                if var app=pendingApp {
                    app.installedAt=Date()
                    app.installedBundleID=event["installed_bundle_id"] as? String ?? app.installedBundleID
                    if let seconds=event["expires_at"] as? Double { app.expiresAt=Date(timeIntervalSince1970:seconds) }
                    if let raw=event["expires_at"] as? String {app.expiresAt=ISO8601DateFormatter().date(from:raw)}
                    if app.id=="com.directside.app" {selfExpiration=app.expiresAt}
                    let old=managed.filter{$0.id==app.id}.map(\.cachedIPA)
                    managed.removeAll { $0.id==app.id }; managed.append(app); save(managed,"apps.json")
                    for path in old where path != app.cachedIPA {removeUnusedIPA(path)}
                }
                pendingApp=nil
                let continuation=installContinuation; installContinuation=nil; continuation?.resume()
            case "error":
                if event["command"] as? String == "import_session" {pendingLocalIdentity=nil;sessionImportPending=false;restoring=false;busy=false;message="Bitte anmelden";continue}
                if event["command"] as? String == "app_ids" {loadingAppIDs=false;appIDsError="App-Kennungen konnten nicht geladen werden. Bitte erneut versuchen.";continue}
                if event["command"] as? String == "local_app_icons" {continue}
                if event["command"] as? String == "inspect_local" {inspecting=false;lastInspection=nil;continue}
                if event["command"] as? String == "import_signing" {signingImportPending=false;try? FileManager.default.removeItem(at:Paths.sessionImport);restoring=false}
                if event["command"] as? String == "import_identity" {importedArchivePending=false}
                fail(event["message"] as? String ?? "Unbekannter Fehler")
            default: break
            }
        }
    }
    func fail(_ reason: String) {
        cleanupIdentityImport()
        if let app=pendingApp {removeUnusedIPA(app.cachedIPA)}
        pendingApp=nil
        try? FileManager.default.removeItem(at:Paths.support.appendingPathComponent("livecontainer-transfer.json"))
        if vpnRequired {busy=false;return}
        if let path=importingPath {try? FileManager.default.removeItem(at:path);importingPath=nil}
        busy=false;needsPairingCode=false; pendingApp=nil; message="Vorgang fehlgeschlagen"; error=reason
        let continuation=installContinuation; installContinuation=nil; continuation?.resume(throwing:DirectSideError.message(reason))
    }
    private func fetchSource(_ url:URL) async throws -> SourceCatalog {
        var request=URLRequest(url:try SourceURL.parse(url.absoluteString)); request.timeoutInterval=20
        let (bytes,response)=try await URLSession.shared.bytes(for:request)
        guard let http=response as? HTTPURLResponse,http.statusCode==200,let final=http.url,(try? SourceURL.parse(final.absoluteString)) != nil else { throw DirectSideError.message("Quelle nicht erreichbar.") }
        var data=Data()
        for try await byte in bytes { data.append(byte); if data.count>5_000_000 { throw DirectSideError.message("Quelldatei zu groß.") } }
        var result=try JSONDecoder().decode(SourceCatalog.self,from:data)
        guard result.apps.count<=5000 else { throw DirectSideError.message("Zu viele Apps in der Quelle.") }
        result.sourceURL=url; result.refreshedAt=Date(); return result
    }
    func refreshSources() async {
        await sourceRefresh.run { [weak self] in
            guard let self else {return}
            self.refreshingSources=true;defer{self.refreshingSources=false}
            await self.refreshSourceSnapshot()
        }
    }
    private func refreshSourceSnapshot() async {
        defer {save(sources,"sources.json")}
        for old in sources {
            guard let url=old.sourceURL else { continue }
            do {
                let refreshed=try await fetchSource(url)
                if let index=sources.firstIndex(where:{$0.id==old.id}) {sources[index]=refreshed}
                sourceFailures.removeValue(forKey:old.id)
            } catch {
                if SourceURL.isCancellation(error) || Task.isCancelled {return}
                if sources.contains(where:{$0.id==old.id}) {sourceFailures[old.id]=error.localizedDescription}
            }
        }
    }
    func updateAll(peer:String,port:Int) async {
        guard !busy else { return }
        for update in updates {
            await install(update.app,source:update.source,peer:peer,port:port)
            if error != nil { return }
        }
    }
    func renewAll(peer:String,port:Int) async {
        guard !busy else { return }
        busy=true
        do {
            for app in managed where app.id != "com.directside.app" {try await waitForInstall(URL(fileURLWithPath:app.cachedIPA),app:app,peer:peer,port:port)}
            try await waitForInstall(Paths.original,app:ManagedApp(id:"com.directside.app",name:"DirectSide",cachedIPA:Paths.original.path,installedAt:Date(),version:Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String),peer:peer,port:port)
        }catch{fail(error.localizedDescription)}
    }
    func previewSource(_ raw: String) async {
        guard !busy else { return }
        busy=true; message="Quelle laden …"
        defer { busy=false }
        do {
            let url=try SourceURL.parse(raw)
            var request=URLRequest(url:url); request.timeoutInterval=20
            let (bytes,response)=try await URLSession.shared.bytes(for:request)
            guard let http=response as? HTTPURLResponse, http.statusCode==200,let final=http.url,(try? SourceURL.parse(final.absoluteString)) != nil else { throw DirectSideError.message("Die Quelle konnte nicht geladen werden.") }
            var data=Data()
            for try await byte in bytes { data.append(byte); if data.count>5_000_000 { throw DirectSideError.message("Die Quelldatei ist zu groß.") } }
            var catalog=try JSONDecoder().decode(SourceCatalog.self,from:data)
            catalog.sourceURL=url; catalog.refreshedAt=Date()
            guard catalog.apps.count<=5000 else { throw DirectSideError.message("Die Quelle enthält zu viele Einträge.") }
            pendingSource=catalog; message="Quelle bereit"
        } catch { if !SourceURL.isCancellation(error) {fail(error.localizedDescription)} }
    }
    func acceptSource() {
        guard let source=pendingSource else { return }
        sources.removeAll { $0.id==source.id }; sources.append(source); save(sources,"sources.json"); pendingSource=nil
    }
    func removeSources(at offsets: IndexSet) { sources.remove(atOffsets:offsets); save(sources,"sources.json") }
    func removeSource(_ source:SourceCatalog) {sources.removeAll{$0.id==source.id};sourceFailures.removeValue(forKey:source.id);save(sources,"sources.json")}
    func install(_ app: CatalogApp, source: SourceCatalog? = nil, peer: String, port: Int) async {
        guard !busy else { return }
        refreshBootstrap()
        guard canSign else { fail("In den Einstellungen anmelden oder ein Zertifikat importieren."); return }
        guard pairingReady else { fail("Dieses Gerät unter Einstellungen → Verbindung koppeln."); return }
        guard let latest=app.latest else { fail("Diese App hat keine Download-Adresse."); return }
        busy=true
        guard await requireInstallConnection(peer:peer,port:port) else {return}
        message="IPA herunterladen …"; progress=0
        do {
            let url=try SourceURL.parse(latest.downloadURL.absoluteString)
            var request=URLRequest(url:url); request.timeoutInterval=180
            let (temp,response)=try await URLSession.shared.download(for:request)
            defer{try? FileManager.default.removeItem(at:temp)}
            guard let http=response as? HTTPURLResponse, http.statusCode==200,let final=http.url,(try? SourceURL.parse(final.absoluteString)) != nil else { throw DirectSideError.message("IPA-Download fehlgeschlagen.") }
            let saved=Paths.support.appendingPathComponent(UUID().uuidString+".ipa")
            try FileManager.default.moveItem(at:temp,to:saved)
            let managed=ManagedApp(id:app.id,name:app.name,cachedIPA:saved.path,installedAt:Date(),version:latest.version,buildVersion:latest.buildVersion,sourceID:source?.id,iconURL:app.iconURL)
            try await waitForInstall(saved,app:managed,peer:peer,port:port)
        } catch { fail(error.localizedDescription) }
    }
    func refresh(_ app: ManagedApp, peer: String, port: Int) {
        guard !busy else { return }
        busy=true
        Task {do { try await waitForInstall(URL(fileURLWithPath:app.cachedIPA),app:app,peer:peer,port:port) } catch { fail(error.localizedDescription) }}
    }
    func refreshSelf(peer: String, port: Int) {
        guard !busy else { return }
        busy=true
        Task {do { try await waitForInstall(Paths.original,app:ManagedApp(id:"com.directside.app",name:"DirectSide",cachedIPA:Paths.original.path,installedAt:Date(),version:Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String),peer:peer,port:port) } catch { fail(error.localizedDescription) }}
    }
    func requireInstallConnection(peer:String,port:Int) async -> Bool {
        guard canSign,pairingReady else {fail("In den Einstellungen anmelden oder ein Zertifikat importieren und dieses Gerät koppeln.");return false}
        guard await InstallConnection().reachable(peer:peer,port:port) else {busy=false;vpnRequired=true;return false}
        vpnRequired=false;return true
    }
    func installSelfUpdate(_ url:URL,version:String,peer:String,port:Int) async throws {
        try await waitForInstall(url,app:ManagedApp(id:"com.directside.app",name:"DirectSide",cachedIPA:Paths.original.path,installedAt:Date(),version:version),peer:peer,port:port,selfUpdate:version)
    }
    private func waitForInstall(_ url:URL,app:ManagedApp,peer:String,port:Int,selfUpdate:String?=nil) async throws {
        busy=true;pendingApp=app
        guard await requireInstallConnection(peer:peer,port:port) else {throw CancellationError()}
        try await withCheckedThrowingContinuation { continuation in
            installContinuation=continuation
            do { try startInstall(url,app:app,peer:peer,port:port,selfUpdate:selfUpdate) }
            catch { installContinuation=nil; continuation.resume(throwing:error); fail(error.localizedDescription) }
        }
    }
    private func startInstall(_ url: URL, app: ManagedApp, peer: String, port: Int,selfUpdate:String?=nil) throws {
        guard canSign else { throw DirectSideError.message("In den Einstellungen anmelden oder ein Zertifikat importieren.") }
        guard let bootstrap, pairingReady else { throw DirectSideError.message("Dieses Gerät unter Einstellungen → Verbindung koppeln.") }
        guard port>0 && port<=65535 else { throw DirectSideError.message("Remote-Pairing-Port fehlt. Unter Verbindung suchen.") }
        guard FileManager.default.fileExists(atPath:url.path) else { throw DirectSideError.message("Die Original-IPA fehlt. Bitte erneut vom PC übertragen.") }
        busy=true; progress=0; pendingApp=app
        var request:[String:Any] = ["command":"install_local","path":url.path,"peer":peer,"port":port,"udid":bootstrap.udid,"device_name":bootstrap.name,"pairing_path":Paths.pairing.path,"bundle_id":app.id]
        request["signing_mode"]=signingMode
        if app.id=="com.directside.app",let id=Bundle.main.bundleIdentifier {request["expected_installed_bundle_id"]=id}
        if let selfUpdate {request["self_update_version"]=selfUpdate}
        send(request)
    }
    private func removeUnusedIPA(_ path:String) {
        let file=URL(fileURLWithPath:path).standardizedFileURL
        guard file.deletingLastPathComponent()==Paths.support.standardizedFileURL,file.pathExtension=="ipa",file != Paths.original,!managed.contains(where:{$0.cachedIPA==path}) else {return}
        try? FileManager.default.removeItem(at:file)
    }
    private func load<T: Decodable>(_ name: String) -> T? { guard let data=try? Data(contentsOf:Paths.support.appendingPathComponent(name)) else { return nil }; return try? JSONDecoder().decode(T.self,from:data) }
    private func save<T: Encodable>(_ value: T,_ name: String) { do { try JSONEncoder().encode(value).write(to:Paths.support.appendingPathComponent(name),options:.atomic) } catch { self.error=error.localizedDescription } }
}
