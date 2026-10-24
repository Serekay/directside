import SwiftUI
import VisionKit
import AVFoundation

private enum AppSheet:String,Identifiable {case add,scan,preview,code,team;var id:String{rawValue}}

struct ContentView:View {
    @EnvironmentObject var engine:Engine
    @StateObject private var connection=Connection()
    @State private var tab=0
    @State private var sheet:AppSheet?
    @State private var sourceURL=""
    @State private var email=""
    @State private var password=""
    @State private var code=""
    @Environment(\.scenePhase) private var phase
    var body:some View {
        TabView(selection:$tab) {
            NavigationStack{DiscoverView(connection:connection,addSource:{sheet = .add},openAccount:{tab=3})}.tabItem{Label("Entdecken",systemImage:"safari")}.tag(0)
            NavigationStack{LibraryView(connection:connection)}.tabItem{Label("Meine Apps",systemImage:"square.stack")}.badge(engine.updates.count).tag(1)
            NavigationStack{SourcesView(connection:connection,addSource:{sheet = .add})}.tabItem{Label("Quellen",systemImage:"square.stack.3d.up")}.tag(2)
            NavigationStack{account}.tabItem{Label("Konto",systemImage:"person.crop.circle")}.tag(3)
        }.tint(Style.accent)
        .task {connection.discover();await engine.refreshSources()}
        .onAppear {if email.isEmpty {email=engine.accountEmail}}
        .onChange(of:engine.accountEmail){_,value in if email.isEmpty {email=value}}
        .onChange(of:phase){_,value in if value == .active {engine.refreshBootstrap()}}
        .onChange(of:engine.needsCode){_,value in if value {sheet = .code}}
        .onChange(of:engine.pendingSource?.id){_,value in if value != nil {sheet = .preview}}
        .onChange(of:engine.teams.count){_,value in if value>0 {sheet = .team}}
        .onChange(of:connection.port){_,value in if value>0 {engine.inspectConnection(peer:connection.peer,port:value)}}
        .sheet(item:$sheet,onDismiss:{if engine.needsCode {engine.cancelCode()};if !engine.teams.isEmpty {engine.chooseTeam("")}}){item in
            NavigationStack {sheetContent(item)}.presentationDetents(item == .scan ? [.large]:[.medium,.large]).interactiveDismissDisabled(item == .code || item == .team)
        }
        .alert("DirectSide",isPresented:Binding(get:{engine.error != nil},set:{if !$0 {engine.error=nil}})){Button("OK"){engine.error=nil}}message:{Text(engine.error ?? "")}
    }
    private var account:some View {
        Form {
            Section {
                HStack(spacing:14){BrandIcon(size:58);VStack(alignment:.leading,spacing:4){Text("Dein Apple Account").font(.headline);Text(engine.teamName).font(.caption).foregroundStyle(.secondary)}}.padding(.vertical,7)
                if engine.loggedIn {Button("Abmelden",role:.destructive){engine.logout()}.disabled(engine.busy)}
                else {
                    TextField("Apple-ID",text:$email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Apple-ID-Passwort",text:$password).textContentType(.password)
                    Button("Anmelden"){engine.login(email:email,password:password);password=""}.disabled(engine.busy || email.isEmpty || password.isEmpty)
                }
            } footer:{Text("Dein Passwort wird nicht gespeichert. Die Sitzung und deine Signierschlüssel bleiben im Schlüsselbund dieses Geräts.")}
            Section("Bereit zum Installieren") {
                Label(engine.pairingReady ? "Dieses iPhone ist eingerichtet":"Einmalig am Windows-PC einrichten",systemImage:engine.pairingReady ? "checkmark.circle.fill":"desktopcomputer")
                VStack(alignment:.leading,spacing:5){Label("LocalDevVPN",systemImage:"network");Text(connection.status).font(.caption).foregroundStyle(.secondary)}
                Button("Verbindung prüfen"){connection.discover();engine.refreshBootstrap();engine.inspectConnection(peer:connection.peer,port:connection.port)}
                Label(engine.slotsText,systemImage:"square.grid.3x1")
                Label("Signierung mit deiner eigenen Apple-ID",systemImage:"key")
            }
            Section("LiveContainer · optional") {
                Label(LiveContainerBridge.available ? "Installiert":"Noch nicht installiert",systemImage:"square.stack.3d.up")
                Button("LiveContainer einrichten"){LiveContainerBridge.configure(engine:engine)}.disabled(!engine.liveContainerCertificateReady)
                Text(engine.liveContainerCertificateReady ? "Zertifikat bereit. Nach der Übergabe in LiveContainer den JIT-less-Test ausführen.":"Am PC: Einstellungen → LiveContainer installieren → Zertifikat übertragen.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                DisclosureGroup("Erweiterte Verbindungseinstellungen") {
                    TextField("VPN-Gegenstelle",text:$connection.peer).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Remote-Pairing-Port",value:$connection.port,format:.number).keyboardType(.numberPad)
                    Button("Speichern"){connection.save()}
                }
            }
            Section {HStack{Text("DirectSide");Spacer();Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0").foregroundStyle(.secondary)};Text("Unabhängiger App-Katalog mit lokaler Signierung. LocalDevVPN wird als separate Verbindung verwendet.").font(.caption).foregroundStyle(.secondary)}
        }.navigationTitle("Dein Konto").safeAreaInset(edge:.bottom){EngineProgress()}
    }
    @ViewBuilder private func sheetContent(_ item:AppSheet)->some View {
        switch item {
        case .add:
            Form {
                Section {Text("Deine nächste Quelle.").font(.title2.bold());Text("Scanne den QR-Code einer Quelle oder füge ihre Adresse ein.").font(.subheadline).foregroundStyle(.secondary)}
                TextField("https://…/source.json",text:$sourceURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Quelle prüfen"){sheet=nil;Task{await engine.previewSource(sourceURL)}}.disabled(sourceURL.isEmpty)
                Button {Task {let allowed=await AVCaptureDevice.requestAccess(for:.video);if allowed && DataScannerViewController.isSupported && DataScannerViewController.isAvailable {sheet = .scan}else{engine.error="Die Kamera ist nicht verfügbar. Du kannst die Quellen-Adresse direkt eingeben."}}}label:{Label("QR-Code scannen",systemImage:"qrcode.viewfinder")}
            }.navigationTitle("Quelle hinzufügen").toolbar{Button("Schließen"){sheet=nil}}
        case .scan:
            QRScanner {raw in sheet=nil;Task{await engine.previewSource(raw)}}.ignoresSafeArea(edges:.bottom).navigationTitle("Quelle scannen").toolbar{Button("Schließen"){sheet=nil}}
        case .preview:
            if let source=engine.pendingSource {Form {Section {HStack(spacing:14){Artwork(url:source.iconURL,size:60,fallback:"square.stack.3d.up.fill");VStack(alignment:.leading,spacing:5){Text(source.name).font(.headline);Text(source.sourceURL?.host ?? "").font(.caption).foregroundStyle(.secondary)}};Text("\(source.apps.count) Apps");if let description=source.description ?? source.subtitle {Text(description).font(.subheadline).foregroundStyle(.secondary)}};Button("Quelle hinzufügen"){engine.acceptSource();sheet=nil};Button("Abbrechen",role:.cancel){engine.pendingSource=nil;sheet=nil}}.navigationTitle("Quelle prüfen")}
        case .code:
            Form {
                Text("Bestätige die Anmeldung und gib den sechsstelligen Code ein.")
                if !engine.codeError.isEmpty {Text(engine.codeError).foregroundStyle(.red)}
                TextField("Bestätigungscode",text:$code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                Button("Code bestätigen"){engine.submitCode(code);code="";if !engine.needsCode {sheet=nil}}
                Button("An vertrauenswürdige Geräte senden"){engine.requestCode("devices");sheet=nil}
                ForEach(Array(engine.codeNumbers.enumerated()),id:\.offset){_,number in
                    Button("SMS an \(number["numberWithDialCode"] as? String ?? "Telefonnummer")"){engine.requestCode("sms",number:number["id"] as? Int ?? 0);sheet=nil}
                }
                Button("Abbrechen",role:.cancel){engine.cancelCode();sheet=nil}
            }.navigationTitle("Apple-Bestätigung")
        case .team:
            List {ForEach(engine.teams,id:\.self){team in Button(team["name"] ?? "Developer-Team"){engine.chooseTeam(team["id"] ?? "");sheet=nil}};Button("Abbrechen",role:.cancel){engine.chooseTeam("");sheet=nil}}.navigationTitle("Developer-Team")
        }
    }
}
