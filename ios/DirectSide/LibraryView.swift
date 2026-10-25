import SwiftUI
import UniformTypeIdentifiers

struct LibraryView:View {
    @EnvironmentObject var engine:Engine
    @EnvironmentObject var updater:AppUpdater
    @ObservedObject var connection:Connection
    @State private var showImporter=false
    @State private var selected:DeviceApp?
    private var otherApps:[DeviceApp] {engine.deviceApps.filter {app in app.developer && !(app.id=="com.directside.app" || app.id.hasPrefix("com.directside.app.")) && !engine.managed.contains{engine.deviceApp(for:$0)?.id == app.id}}}
    var body:some View {
        List {
            HStack {
                Text(L("Meine Apps")).font(.largeTitle.bold()).tracking(-1)
                Spacer()
                Button {showImporter=true}label:{Image(systemName:"plus").font(.title3.weight(.semibold)).padding(12).background(Style.surface,in:Circle())}.accessibilityLabel(L("IPA importieren")).disabled(engine.busy)
            }.listRowBackground(Color.clear).listRowSeparator(.hidden)
            Section {
                Button {Task{await engine.renewAll(peer:connection.peer,port:connection.port)}}label:{Label(L("Alle Signaturen erneuern"),systemImage:"arrow.clockwise").frame(maxWidth:.infinity)}.buttonStyle(.borderedProminent).disabled(engine.busy || !engine.canSign || !engine.pairingReady)
            }
            Section {
                HStack(spacing:12) {
                    BrandIcon(size:50);Text("DirectSide").font(.subheadline.bold());Spacer()
                    if updater.available != nil {Button(L("Aktualisieren")){updater.showOffer=true}.font(.caption.bold()).buttonStyle(.borderedProminent).disabled(engine.busy || updater.downloading)}
                    SignatureBadge(expiresAt:engine.selfExpiration){engine.refreshSelf(peer:connection.peer,port:connection.port)}.disabled(engine.busy || !engine.canSign || !engine.pairingReady)
                }.padding(.vertical,8)
                ForEach(engine.managed.filter{$0.id != "com.directside.app"}) {app in
                    let deviceApp=engine.deviceApp(for:app)
                    HStack(spacing:12) {
                        if let icon=engine.deviceIcons[deviceApp?.id ?? ""] {DeviceArtwork(data:icon,name:app.name)} else {Artwork(url:app.iconURL,size:50)}
                        VStack(alignment:.leading,spacing:4) {Text(app.name).font(.subheadline.bold());Text(L("Sideload-App")).font(.caption).foregroundStyle(.secondary)}
                        Spacer()
                        if let update=engine.updates.first(where:{$0.app.id==app.id}) {Button(L("Aktualisieren")){Task{await engine.install(update.app,source:update.source,peer:connection.peer,port:connection.port)}}.font(.caption.bold()).buttonStyle(.borderedProminent).disabled(engine.busy)}
                        SignatureBadge(expiresAt:app.expiresAt){engine.refresh(app,peer:connection.peer,port:connection.port)}.disabled(engine.busy || !engine.canSign || !engine.pairingReady)
                    }.padding(.vertical,8)
                    .swipeActions(edge:.trailing,allowsFullSwipe:false){deleteButton(deviceApp)}
                    .contextMenu{deleteButton(deviceApp)}
                }
                ForEach(otherApps) {app in
                    HStack(spacing:12) {DeviceArtwork(data:engine.deviceIcons[app.id],name:app.name);VStack(alignment:.leading,spacing:4){Text(app.name).font(.subheadline.bold());Text(L("Entwickler-App · auf diesem Gerät")).font(.caption).foregroundStyle(.secondary)}}.padding(.vertical,8)
                    .swipeActions(edge:.trailing,allowsFullSwipe:false){deleteButton(app)}.contextMenu{deleteButton(app)}
                }
            } header:{HStack{Text(L("Installiert"));Spacer();if let slots=engine.slotsUsed {Text(L("\(slots) Entwickler-Apps"))}}}
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Style.background).toolbar(.hidden,for:.navigationBar)
        .scrollDismissesKeyboard(.interactively)
        .task{engine.inspectConnection(peer:connection.peer,port:connection.port)}
        .refreshable{await engine.refreshSources();engine.inspectConnection(peer:connection.peer,port:connection.port,force:true)}
        .safeAreaInset(edge:.bottom){EngineProgress()}
        .confirmationDialog(L("App und Daten löschen?"),isPresented:Binding(get:{selected != nil},set:{if !$0 {selected=nil}}),titleVisibility:.visible) {
            if let app=selected {Button(L("\(app.name) entfernen"),role:.destructive){engine.removeDeviceApp(app,peer:connection.peer,port:connection.port);selected=nil}}
            Button(L("Abbrechen"),role:.cancel){selected=nil}
        } message:{Text(L("Die App und ihre Daten werden von diesem Gerät gelöscht. Bei kostenlosen Accounts wird ihr App-Platz dadurch frei."))}
        .fileImporter(isPresented:$showImporter,allowedContentTypes:[UTType(filenameExtension:"ipa") ?? .data],allowsMultipleSelection:false) {result in
            switch result {
            case .success(let files):if let file=files.first {Task{await engine.importIPA(file)}}
            case .failure(let error):engine.fail(error.localizedDescription)
            }
        }
    }
    @ViewBuilder private func deleteButton(_ app:DeviceApp?)->some View {
        if let app {Button(role:.destructive){selected=app}label:{Label(L("App löschen"),systemImage:"trash")}.disabled(engine.busy)}
    }
}

struct DeviceArtwork:View {
    let data:Data?
    let name:String
    var body:some View {
        Group {
            if let data,let image=UIImage(data:data) {Image(uiImage:image).resizable().scaledToFill()}
            else {Text(String(name.prefix(1)).uppercased()).font(.title2.bold()).frame(maxWidth:.infinity,maxHeight:.infinity).background(Style.surface)}
        }.frame(width:50,height:50).clipShape(RoundedRectangle(cornerRadius:12))
    }
}
