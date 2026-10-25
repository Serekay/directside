import SwiftUI

struct UpdateSettings:View {
    @EnvironmentObject var updater:AppUpdater
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    @AppStorage("automaticUpdates") private var automaticUpdates=true
    var body:some View {
        Form {
            Section {
                HStack(spacing:16) {
                    BrandIcon(size:60)
                    VStack(alignment:.leading,spacing:5) {
                        Text("DirectSide").font(.title2.bold())
                        Text(L("Version")+" "+(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")).foregroundStyle(.secondary)
                    }
                }.padding(.vertical,8)
                if updater.checking {ProgressView(L("Nach Updates suchen …"))}
                else if !updater.message.isEmpty {Label(L(updater.message),systemImage:updater.available == nil ? "info.circle":"arrow.down.circle.fill").font(.subheadline).foregroundStyle(.secondary)}
                Button {Task{await updater.check(manual:true)}}label:{Label(L("Nach Updates suchen"),systemImage:"arrow.clockwise").frame(maxWidth:.infinity)}
                    .buttonStyle(.borderedProminent).disabled(updater.checking || updater.downloading)
            }
            if let release=updater.available {
                Section {
                    Label(L("Neue Version verfügbar")+" · "+release.version,systemImage:"sparkles").font(.headline)
                    if !release.notes.isEmpty {Text(release.notes).font(.subheadline)}
                    if updater.downloading {ProgressView(L("Update wird installiert …"))}
                    else {Button(L("Update installieren")){Task{await updater.install(engine:engine,connection:connection)}}.buttonStyle(.borderedProminent).disabled(engine.busy)}
                }
            }
            Section {
                Toggle(L("Automatisch nach Updates suchen"),isOn:$automaticUpdates)
            } footer:{Text(L("Prüft beim Öffnen der App, höchstens alle sechs Stunden. Ein verfügbares Update kannst du direkt auf dem iPhone installieren."))}
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
