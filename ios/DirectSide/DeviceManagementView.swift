import SwiftUI

struct ImportedIPA:Identifiable {
    var id:String {file.path}
    let file:URL
    let bundleID:String
    let name:String
    let version:String?
}

struct DeviceApp:Decodable,Identifiable {
    let id:String
    let name:String
    let developer:Bool
}
struct SigningCertificate:Decodable,Identifiable {
    var id:String {serial}
    let serial:String
    let name:String
    let reusable:Bool
    let expires:String?
}

struct DeviceManagementView:View {
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    @State private var search=""
    @State private var selected:DeviceApp?
    private var apps:[DeviceApp] {engine.deviceApps.filter{search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)}}
    var body:some View {
        List {
            Section {
                HStack {Text(engine.slotsText);Spacer();Button("Prüfen"){reload()}.disabled(engine.busy)}
            }
            Section("Apps auf diesem Gerät") {
                ForEach(apps) {app in
                    HStack(spacing:12) {
                        Image(systemName:app.developer ? "app.badge":"app.fill").font(.title2).foregroundStyle(Style.accent).frame(width:36)
                        VStack(alignment:.leading,spacing:4) {Text(app.name);if app.developer {Text("Entwickler-App").font(.caption).foregroundStyle(.secondary)}}
                        Spacer()
                        Button(role:.destructive){selected=app}label:{Image(systemName:"trash")}.buttonStyle(.borderless).disabled(engine.busy)
                    }
                }
                if engine.deviceApps.isEmpty {Text(engine.busy ? "Apps werden gelesen …":"LocalDevVPN verbinden und Apps prüfen.").foregroundStyle(.secondary)}
            }
        }.navigationTitle("Apps verwalten").searchable(text:$search,prompt:"App suchen")
        .task {reload()}.refreshable{reload()}
        .confirmationDialog("App entfernen?",isPresented:Binding(get:{selected != nil},set:{if !$0 {selected=nil}}),titleVisibility:.visible) {
            if let app=selected {Button("\(app.name) entfernen",role:.destructive){engine.removeDeviceApp(app,peer:connection.peer,port:connection.port);selected=nil}}
            Button("Abbrechen",role:.cancel){selected=nil}
        } message:{Text("Die App und ihre Daten werden von diesem Gerät gelöscht.")}
        .safeAreaInset(edge:.bottom){EngineProgress()}
    }
    private func reload(){engine.inspectConnection(peer:connection.peer,port:connection.port)}
}

struct CertificateManagementView:View {
    @EnvironmentObject var engine:Engine
    @State private var selected:SigningCertificate?
    var body:some View {
        List {
            Section {
                HStack {Text(engine.teamName);Spacer();Text("\(engine.signingCertificates.count)").foregroundStyle(.secondary)}
                Button("Zertifikate aktualisieren"){engine.loadCertificates()}.disabled(engine.busy || !engine.loggedIn)
            } footer:{Text("Zertifikate gelten für das Developer-Team. Die drei App-Plätze gelten pro Gerät.")}
            Section("Signierzertifikate") {
                ForEach(engine.signingCertificates) {certificate in
                    HStack {
                        VStack(alignment:.leading,spacing:5) {
                            Text(certificate.name)
                            Text(String(certificate.serial.suffix(8))).font(.caption.monospaced()).foregroundStyle(.secondary)
                            if certificate.reusable {Label("Schlüssel vorhanden",systemImage:"checkmark.circle.fill").font(.caption).foregroundStyle(.green)}
                        }
                        Spacer()
                        Button(role:.destructive){selected=certificate}label:{Image(systemName:"trash")}.buttonStyle(.borderless).disabled(engine.busy || certificate.serial.isEmpty)
                    }
                }
                if engine.certificatesLoaded && engine.signingCertificates.isEmpty {Text("Keine Zertifikate vorhanden").foregroundStyle(.secondary)}
            }
        }.navigationTitle("Zertifikate").task{engine.loadCertificates()}
        .confirmationDialog("Zertifikat widerrufen?",isPresented:Binding(get:{selected != nil},set:{if !$0 {selected=nil}}),titleVisibility:.visible) {
            if let certificate=selected {Button("\(certificate.name) widerrufen",role:.destructive){engine.revokeCertificate(certificate);selected=nil}}
            Button("Abbrechen",role:.cancel){selected=nil}
        } message:{Text("Damit signierte Apps auf allen Geräten müssen anschließend neu signiert werden.")}
        .safeAreaInset(edge:.bottom){EngineProgress()}
    }
}
