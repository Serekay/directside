import SwiftUI

struct SettingsView:View {
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    @AppStorage("language") private var language="en"
    var body:some View {
        List {
            Section {
                NavigationLink {AppleAccountSettings()} label:{
                    HStack(spacing:14) {BrandIcon(size:48);VStack(alignment:.leading,spacing:4){Text(L(engine.loggedIn ? engine.teamName:L("Apple Account"))).font(.headline);Text(L(engine.loggedIn ? engine.accountEmail:L("Nicht angemeldet"))).font(.caption).foregroundStyle(.secondary)}}.padding(.vertical,5)
                }
            }
            Section {
                VPNStatusView(connection:connection)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top:0,leading:0,bottom:0,trailing:0))
            }
            Section(L("Gerät & Signierung")) {
                NavigationLink {DeveloperModeHelp()} label:{Label(L("Entwicklermodus"),systemImage:"hammer")}
                NavigationLink {ConnectionSettings(connection:connection)} label:{SettingsRow(title:"Verbindung",icon:"network",value:engine.pairingReady ? "Gekoppelt":"Einrichten",ok:engine.pairingReady)}
                NavigationLink {ImportedSigningSettings()} label:{Label(L("Signierung"),systemImage:"checkmark.seal")}
                NavigationLink {CertificateManagementView()} label:{Label(L("Zertifikate"),systemImage:"signature")}.disabled(!engine.loggedIn)
                NavigationLink {AppIDsView()} label:{
                    HStack {Label(L("App-Kennungen"),systemImage:"app.badge.checkmark");Spacer();if let limit=engine.appIDsLimit,let free=engine.appIDsAvailable {Text("\(max(0,limit-free)) / \(limit)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)}}
                }
                NavigationLink {LiveContainerSettings(connection:connection)} label:{SettingsRow(title:"LiveContainer",icon:"square.stack.3d.up",value:LiveContainerBridge.available ? "Installiert":"Optional",ok:LiveContainerBridge.available)}
            }
            Section(L("Darstellung")) {
                Picker(L("Sprache"),selection:$language) {Text(L("English")).tag("en");Text(L("Deutsch")).tag("de")}
            }
            Section {NavigationLink {UpdateSettings(connection:connection)} label:{Label(L("DirectSide-Updates"),systemImage:"arrow.down.app")}}
            Section {HStack{Text(L("DirectSide"));Spacer();Text(L(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")).foregroundStyle(.secondary)}}
        }.navigationTitle(L("Einstellungen")).safeAreaInset(edge:.bottom){EngineProgress()}
    }
}

private struct SettingsRow:View {
    let title:String
    let icon:String
    let value:String
    let ok:Bool
    var body:some View {HStack{Label(L(title),systemImage:icon);Spacer();Text(L(value)).font(.caption.weight(.medium)).foregroundStyle(ok ? Color.green:Color.orange)}}
}

struct AppleAccountSettings:View {
    @EnvironmentObject var engine:Engine
    @State private var email=""
    @State private var password=""
    var body:some View {
        Form {
            Section {
                if engine.loggedIn {LabeledContent(L("Team"),value:engine.teamName);LabeledContent(L("Apple-ID"),value:engine.accountEmail);Button(L("Abmelden"),role:.destructive){engine.logout()}.disabled(engine.busy)}
                else {
                    TextField(L("Apple-ID"),text:$email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField(L("Passwort"),text:$password).textContentType(.password)
                    Button(L("Anmelden")){engine.login(email:email,password:password);password=""}.disabled(engine.busy || email.isEmpty || password.isEmpty)
                }
            }
        }.navigationTitle(L("Apple Account")).onAppear{email=engine.accountEmail}.safeAreaInset(edge:.bottom){EngineProgress()}
    }
}

struct ConnectionSettings:View {
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    var body:some View {
        Form {
            Section {
                NavigationLink {DeveloperModeHelp()} label:{Label(L("Entwicklermodus einrichten"),systemImage:"hammer")}
            }
            Section(L("Gerätekopplung")) {
                Label(L(engine.pairingReady ? "Dieses Gerät ist gekoppelt":"Dieses Gerät koppeln"),systemImage:engine.pairingReady ? "checkmark.circle.fill":"link").foregroundStyle(engine.pairingReady ? Color.green:Color.orange)
                if !engine.pairingReady {
                    Button(L("Jetzt koppeln")){engine.pairDevice(peer:connection.peer,port:connection.port)}.disabled(engine.busy || !connection.vpnReachable)
                }
            }
            Section(L("Verbindung")) {
                Text(L(connection.status)).font(.subheadline).foregroundStyle(.secondary)
                Button(L("Erneut suchen")){connection.discover();engine.refreshBootstrap()}.disabled(engine.busy)
            }
            Section {
                DisclosureGroup(L("Erweitert")) {
                    TextField(L("VPN-Gegenstelle"),text:$connection.peer).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField(L("Remote-Pairing-Port"),value:$connection.port,format:.number).keyboardType(.numberPad)
                    Button(L("Speichern")){connection.save();connection.checkVPN()}
                }
            }
        }.navigationTitle(L("Verbindung")).safeAreaInset(edge:.bottom){EngineProgress()}
    }
}

struct LiveContainerSettings:View {
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    @Environment(\.scenePhase) private var phase
    @State private var installed=LiveContainerBridge.available
    var body:some View {
        List {
            Section {
                Label(L("LiveContainer"),systemImage:"square.stack.3d.up.fill").font(.title2.bold())
            }
            Section {
                Label(L(installed ? "Installiert":"Nicht installiert"),systemImage:installed ? "checkmark.circle.fill":"arrow.down.app").foregroundStyle(installed ? Color.green:Color.orange)
                if !installed {Button(L("LiveContainer installieren")){Task{await engine.installLiveContainer(peer:connection.peer,port:connection.port);installed=LiveContainerBridge.available}}.disabled(engine.busy)}
                else {Button(L("Zertifikat übertragen")){engine.configureLiveContainer()}.disabled(engine.busy || !engine.canSign);Button(L("LiveContainer öffnen")){LiveContainerBridge.open()}}
            } header:{Text(L("Einrichten"))}
        }.navigationTitle(L("LiveContainer")).onChange(of:phase){_,value in if value == .active {installed=LiveContainerBridge.available}}.safeAreaInset(edge:.bottom){EngineProgress()}
    }
}
