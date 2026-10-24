import SwiftUI
import UniformTypeIdentifiers

struct LibraryView:View {
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    @State private var showImporter=false
    @State private var showManagement=false
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                HStack {
                    Text(L("Meine Apps")).font(.largeTitle.bold()).tracking(-1)
                    Spacer()
                    Button {showImporter=true}label:{Image(systemName:"plus").font(.title3.weight(.semibold)).padding(12).background(Style.surface,in:Circle())}.accessibilityLabel(L("IPA importieren")).disabled(engine.busy)
                }.padding(.top,10)
                VStack(spacing:16) {
                    HStack {
                        Label(L("Signaturen"),systemImage:"checkmark.seal").font(.headline)
                        Spacer()
                    }
                    Button {Task{await engine.renewAll(peer:connection.peer,port:connection.port)}}label:{Label(L("Alle Signaturen erneuern"),systemImage:"arrow.clockwise").font(.subheadline.bold()).frame(maxWidth:.infinity).padding(.vertical,5)}.buttonStyle(.borderedProminent).disabled(engine.busy || !engine.loggedIn || !engine.pairingReady)
                }.padding(18).background(Style.surface,in:RoundedRectangle(cornerRadius:20))
                HStack {
                    Label(L("Updates"),systemImage:"arrow.down.circle").font(.subheadline.weight(.semibold))
                    Spacer()
                    if engine.updates.isEmpty {Label(L("Aktuell"),systemImage:"checkmark.circle.fill").font(.caption).foregroundStyle(Style.accent)}
                    else {Text("\(engine.updates.count)").font(.caption.bold()).foregroundStyle(Style.accent);Button(L("Alle aktualisieren")){Task{await engine.updateAll(peer:connection.peer,port:connection.port)}}.font(.caption.bold()).disabled(engine.busy)}
                }.padding(.horizontal,4)
                VStack(spacing:4) {
                    HStack {
                        Text(L("Installiert")).font(.title3.bold());Spacer()
                        if let slots=engine.slotsUsed {Text("\(slots) / 3").font(.caption.weight(.semibold)).foregroundStyle(slots>=3 ? Color.red:slots==2 ? Color.orange:Style.accent)}
                        Button {showManagement=true}label:{Label(L("Verwalten"),systemImage:"square.grid.2x2")}.font(.caption.bold())
                    }.padding(.bottom,10)
                    HStack(spacing:12) {
                        BrandIcon(size:50)
                        Text("DirectSide").font(.subheadline.bold())
                        Spacer()
                        SignatureBadge(expiresAt:engine.selfExpiration){engine.refreshSelf(peer:connection.peer,port:connection.port)}.disabled(engine.busy || !engine.loggedIn || !engine.pairingReady)
                    }.padding(.vertical,10)
                    ForEach(engine.managed.filter{$0.id != "com.directside.app"}) {app in
                        Divider().padding(.leading,62)
                        HStack(spacing:12) {
                            Artwork(url:app.iconURL,size:50)
                            Text(app.name).font(.subheadline.bold())
                            Spacer()
                            if let update=engine.updates.first(where:{$0.app.id==app.id}) {Button(L("Aktualisieren")){Task{await engine.install(update.app,source:update.source,peer:connection.peer,port:connection.port)}}.font(.caption.bold()).disabled(engine.busy)}
                            SignatureBadge(expiresAt:app.expiresAt){engine.refresh(app,peer:connection.peer,port:connection.port)}.disabled(engine.busy || !engine.loggedIn || !engine.pairingReady)
                        }.padding(.vertical,10)
                    }
                }
            }.padding(21)
        }.background(Style.background).toolbar(.hidden,for:.navigationBar)
        .refreshable{await engine.refreshSources();engine.inspectConnection(peer:connection.peer,port:connection.port)}
        .safeAreaInset(edge:.bottom){EngineProgress()}
        .sheet(isPresented:$showManagement){NavigationStack{DeviceManagementView(connection:connection).toolbar{Button(L("Fertig")){showManagement=false}}}.safeAreaInset(edge:.top){VPNStatusView(connection:connection)}}
        .fileImporter(isPresented:$showImporter,allowedContentTypes:[UTType(filenameExtension:"ipa") ?? .data],allowsMultipleSelection:false) {result in
            switch result {
            case .success(let files):if let file=files.first {Task{await engine.importIPA(file)}}
            case .failure(let error):engine.fail(error.localizedDescription)
            }
        }
    }
}
