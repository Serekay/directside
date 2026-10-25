import SwiftUI
import VisionKit
import AVFoundation

private enum AppSheet:String,Identifiable {case add,scan,preview,code,team,ipa,pairing,update;var id:String{rawValue}}

struct ContentView:View {
    @EnvironmentObject var engine:Engine
    @EnvironmentObject var updater:AppUpdater
    @StateObject private var connection=Connection()
    @State private var tab=0
    @State private var sheet:AppSheet?
    @State private var sourceURL=""
    @State private var code=""
    @Environment(\.scenePhase) private var phase
    var body:some View {
        TabView(selection:$tab) {
            NavigationStack{DiscoverView(connection:connection,addSource:{sheet = .add})}.tabItem{Label(L("Entdecken"),systemImage:"safari")}.tag(0)
            NavigationStack{LibraryView(connection:connection)}.tabItem{Label(L("Meine Apps"),systemImage:"square.stack")}.badge(engine.updates.count+(updater.available == nil ? 0:1)).tag(1)
            NavigationStack{SourcesView(connection:connection,addSource:{sheet = .add})}.tabItem{Label(L("Quellen"),systemImage:"square.stack.3d.up")}.tag(2)
            NavigationStack{SettingsView(connection:connection)}.tabItem{Label(L("Einstellungen"),systemImage:"gearshape")}.tag(3)
        }.tint(Style.accent)
        .background(KeyboardDismissal().frame(width:0,height:0))
        .task {connection.startMonitoring();await engine.refreshSources()}
        .task {await updater.check()}
        .onChange(of:phase){_,value in
            if value == .active {engine.refreshBootstrap();connection.startMonitoring();Task{await updater.check()}}
            else if value == .background {connection.stopMonitoring()}
        }
        .onChange(of:engine.needsPairingCode){_,value in if value {sheet = .pairing}}
        .onChange(of:engine.needsCode){_,value in if value {sheet = .code}}
        .onChange(of:engine.pendingSource?.id){_,value in if value != nil {sheet = .preview}}
        .onChange(of:engine.importedIPA?.id){_,value in if value != nil {tab=1;sheet = .ipa}}
        .onChange(of:engine.teams.count){_,value in if value>0 {sheet = .team}}
        .onChange(of:updater.showOffer){_,_ in presentUpdateIfReady()}
        .onChange(of:engine.busy){_,value in if !value {presentUpdateIfReady()}}
        .onChange(of:connection.port){_,value in if value>0 {engine.inspectConnection(peer:connection.peer,port:value)}}
        .onChange(of:connection.vpnReachable){_,value in if value {engine.inspectConnection(peer:connection.peer,port:connection.port)}}
        .sheet(item:$sheet,onDismiss:{if engine.needsPairingCode {engine.submitPairingCode("")};if engine.needsCode {engine.cancelCode()};if !engine.teams.isEmpty {engine.chooseTeam("")};if engine.importedIPA != nil {engine.cancelIPAImport()};presentUpdateIfReady()}){item in
            NavigationStack {sheetContent(item)}.presentationDetents(item == .scan ? [.large]:[.medium,.large]).interactiveDismissDisabled(item == .code || item == .team || item == .pairing)
        }
        .alert(L("LocalDevVPN verbinden"),isPresented:$engine.vpnRequired) {
            if connection.vpnInstalled {Button(L("LocalDevVPN öffnen")){connection.openVPN()}}
            else {Button(L("LocalDevVPN installieren")){UIApplication.shared.open(URL(string:"https://apps.apple.com/app/id6755608044")!)}}
            Button(L("Abbrechen"),role:.cancel){}
        } message:{Text(L("Zum Installieren muss LocalDevVPN verbunden sein. Öffne LocalDevVPN, aktiviere die Verbindung und versuche es anschließend erneut."))}
        .alert(L("DirectSide"),isPresented:Binding(get:{engine.error != nil},set:{if !$0 {engine.error=nil}})){Button(L("OK")){engine.error=nil}}message:{Text(L(engine.error ?? ""))}
    }
    private func presentUpdateIfReady() {
        guard updater.showOffer,sheet==nil,!engine.busy,!engine.needsCode,!engine.needsPairingCode,engine.teams.isEmpty else {return}
        updater.showOffer=false;sheet = .update
    }
    @ViewBuilder private func sheetContent(_ item:AppSheet)->some View {
        switch item {
        case .update:UpdateOffer(connection:connection)
        case .pairing:
            Form {Text(L("Den von iOS angezeigten Pairing-Code eingeben."));TextField(L("Pairing-Code"),text:$code).keyboardType(.numberPad).textContentType(.oneTimeCode);Button(L("Bestätigen")){engine.submitPairingCode(code);code="";sheet=nil};Button(L("Abbrechen"),role:.cancel){engine.submitPairingCode("");sheet=nil}}.navigationTitle(L("Gerät koppeln"))
        case .ipa:
            if let app=engine.importedIPA {
                Form {
                    Section {Label(L(app.name),systemImage:"app.fill").font(.headline);Text(L(app.version ?? ""));Text(L(app.bundleID)).font(.caption).textSelection(.enabled)}
                    Button(L("Signieren und installieren")){engine.installImportedIPA(peer:connection.peer,port:connection.port);sheet=nil}.disabled(!engine.canSign || !engine.pairingReady || engine.busy)
                    Button(L("Abbrechen"),role:.cancel){engine.cancelIPAImport();sheet=nil}
                }.navigationTitle(L("IPA installieren"))
            }
        case .add:
            Form {
                TextField("http(s)://…/source.json",text:$sourceURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(L("Quelle prüfen")){sheet=nil;Task{await engine.previewSource(sourceURL)}}.buttonStyle(.borderedProminent).disabled(sourceURL.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                Button {Task {let allowed=await AVCaptureDevice.requestAccess(for:.video);if allowed && DataScannerViewController.isSupported && DataScannerViewController.isAvailable {sheet = .scan}else{engine.error="Die Kamera ist nicht verfügbar. Du kannst die Quellen-Adresse direkt eingeben."}}}label:{Image(systemName:"qrcode.viewfinder").font(.title2).frame(maxWidth:.infinity)}.buttonStyle(.bordered).accessibilityLabel(L("QR-Code scannen")).buttonStyle(.bordered).accessibilityLabel(L("QR-Code scannen"))
            }.navigationTitle(L("Quelle hinzufügen")).toolbar{Button(L("Schließen")){sheet=nil}}
        case .scan:
            QRScanner {raw in sheet=nil;Task{await engine.previewSource(raw)}}.ignoresSafeArea(edges:.bottom).navigationTitle(L("Quelle scannen")).toolbar{Button(L("Schließen")){sheet=nil}}
        case .preview:
            if let source=engine.pendingSource {Form {Section {Label(source.name,systemImage:"tray.2.fill").font(.headline);if let url=source.sourceURL {Text(url.absoluteString).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)};Text(L("\(source.apps.count) Apps"));if let description=source.description ?? source.subtitle {Text(L(description)).font(.subheadline).foregroundStyle(.secondary)}};Button(L("Quelle hinzufügen")){engine.acceptSource();sheet=nil};Button(L("Abbrechen"),role:.cancel){engine.pendingSource=nil;sheet=nil}}.navigationTitle(L("Quelle prüfen"))}
        case .code:
            Form {
                Text(L("Bestätige die Anmeldung und gib den sechsstelligen Code ein."))
                if !engine.codeError.isEmpty {Text(L(engine.codeError)).foregroundStyle(.red)}
                TextField(L("Bestätigungscode"),text:$code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                Button(L("Code bestätigen")){engine.submitCode(code);code="";if !engine.needsCode {sheet=nil}}
                Button(L("An vertrauenswürdige Geräte senden")){engine.requestCode("devices");sheet=nil}
                ForEach(Array(engine.codeNumbers.enumerated()),id:\.offset){_,number in
                    Button(L("SMS an \(number["numberWithDialCode"] as? String ?? "Telefonnummer")")){engine.requestCode("sms",number:number["id"] as? Int ?? 0);sheet=nil}
                }
                Button(L("Abbrechen"),role:.cancel){engine.cancelCode();sheet=nil}
            }.navigationTitle(L("Apple-Bestätigung"))
        case .team:
            List {ForEach(engine.teams,id:\.self){team in Button(L(team["name"] ?? "Developer-Team")){engine.chooseTeam(team["id"] ?? "");sheet=nil}};Button(L("Abbrechen"),role:.cancel){engine.chooseTeam("");sheet=nil}}.navigationTitle(L("Developer-Team"))
        }
    }
}
