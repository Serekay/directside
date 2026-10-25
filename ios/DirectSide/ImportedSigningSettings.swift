import SwiftUI
import UniformTypeIdentifiers

struct ImportedSigningIdentity:Decodable {
    let name:String
    let team_id:String
    let expires_at:String?
    let profiles:Int
    let free:Bool
    let valid:Bool?
    let problem:String?
}

struct ImportedSigningSettings:View {
    @EnvironmentObject var engine:Engine
    @State private var showImporter=false
    @State private var importingProfiles=false
    @State private var p12:URL?
    @State private var profiles:[URL]=[]
    @State private var password=""
    var body:some View {
        Form {
            Section {
                Picker(L("Signieren mit"),selection:Binding(get:{engine.signingMode},set:{engine.setSigningMode($0)})) {
                    Text(L("Apple Account")).tag("account")
                    Text(L("Importiertes Zertifikat")).tag("imported")
                }.disabled(engine.busy)
                Text(L("Kostenlose und bezahlte Apple-Developer-Teams werden unterstützt. Gültigkeit, Geräte und App-Funktionen richten sich nach dem tatsächlichen Profil.")).font(.subheadline).foregroundStyle(.secondary)
            }
            if let identity=engine.importedIdentity {
                Section(L("Gespeichertes Zertifikat")) {
                    Label(identity.name,systemImage:"checkmark.seal")
                    if let problem=identity.problem {Text(L(problem)).font(.subheadline).foregroundStyle(.orange)}
                    LabeledContent(L("Team"),value:identity.team_id)
                    if let raw=identity.expires_at,let date=ISO8601DateFormatter().date(from:raw) {LabeledContent(L("Gültig bis"),value:date.formatted(date:.abbreviated,time:.omitted))}
                    Button(L("Importiertes Zertifikat entfernen"),role:.destructive){engine.forgetImportedIdentity()}.disabled(engine.busy)
                }
            }
            Section {
                Button {importingProfiles=false;showImporter=true}label:{Label(p12?.lastPathComponent ?? L("P12-Datei auswählen"),systemImage:"doc.badge.plus")}
                SecureField(L("Passwort der P12-Datei"),text:$password)
                Button {importingProfiles=true;showImporter=true}label:{Label(profiles.isEmpty ? L("Profile auswählen"):L("\(profiles.count) Profile ausgewählt"),systemImage:"doc.on.doc")}
                Button(L("Prüfen und sicher speichern")) {if let p12 {Task{await engine.importIdentity(p12:p12,profiles:profiles,password:password);password=""}}}.buttonStyle(.borderedProminent).disabled(p12==nil || profiles.isEmpty || engine.busy)
            } header:{Text(L("Zertifikat importieren"))} footer:{Text(L("Importiere eine P12-Datei mit privatem Schlüssel und die zugehörigen .mobileprovision-Dateien. Profile müssen zu App, Erweiterungen und iPhone passen. Die Zugangsdaten zu anderen Plattformen werden nicht benötigt."))}
        }.navigationTitle(L("Signierung"))
        .fileImporter(isPresented:$showImporter,allowedContentTypes:[.data],allowsMultipleSelection:importingProfiles){result in
            switch result {
            case .success(let urls):if importingProfiles {profiles=urls} else {p12=urls.first}
            case .failure(let error):engine.fail(error.localizedDescription)
            }
        }
    }
}
