import SwiftUI

struct UpdateSettings:View {
    @EnvironmentObject var updater:AppUpdater
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    @State private var token=""
    var body:some View {
        Form {
            Section {
                LabeledContent(L("Installierte Version"),value:Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                Button(L("Nach Updates suchen")){Task{await updater.check(manual:true)}}.disabled(updater.checking || updater.downloading)
                if !updater.message.isEmpty {Text(L(updater.message)).font(.subheadline).foregroundStyle(.secondary)}
            } footer:{Text(L("DirectSide prüft beim Start und anschließend höchstens alle sechs Stunden auf veröffentlichte Updates."))}
            if let release=updater.available {
                Section {
                    Label(L("Neue Version verfügbar")+" · "+release.version,systemImage:"sparkles").font(.headline)
                    if !release.notes.isEmpty {Text(release.notes).font(.subheadline)}
                    Button(L("Update installieren")){Task{await updater.install(engine:engine,connection:connection)}}.buttonStyle(.borderedProminent).disabled(engine.busy || updater.downloading)
                }
            }
            Section(L("Privates Repository")) {
                SecureField(L("GitHub-Zugang"),text:$token).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(L("Zugang speichern")){updater.saveCredential(token);token=""}.disabled(token.isEmpty || updater.downloading || updater.checking)
                if updater.hasCredential {Button(L("Zugang entfernen"),role:.destructive){updater.forgetCredential()}.disabled(updater.downloading || updater.checking)}
            } footer:{Text(L("Für Serekay/directside einen auf dieses Repository beschränkten GitHub-Zugang mit Contents: Read verwenden. Er wird nur im Schlüsselbund dieses iPhones gespeichert."))}
        }.navigationTitle(L("DirectSide-Updates"))
    }
}

struct UpdateOffer:View {
    @EnvironmentObject var updater:AppUpdater
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                BrandIcon(size:72)
                Text(L("Ein Update für DirectSide")).font(.largeTitle.bold())
                if let release=updater.available {
                    Text(L("Version")+" "+release.version).foregroundStyle(.secondary)
                    if !release.notes.isEmpty {Text(release.notes)}
                    Text(L("Die neue Version wird direkt auf diesem iPhone geprüft, signiert und installiert. LocalDevVPN muss verbunden sein.")).font(.subheadline).foregroundStyle(.secondary)
                    Button {dismiss();Task{await updater.install(engine:engine,connection:connection)}}label:{Label(L("Update installieren"),systemImage:"arrow.down.app").frame(maxWidth:.infinity)}.buttonStyle(.borderedProminent).disabled(engine.busy || updater.downloading)
                }
                Button(L("Später")){dismiss()}.frame(maxWidth:.infinity)
            }.padding(24)
        }
    }
}
