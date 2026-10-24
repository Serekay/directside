import SwiftUI
import UniformTypeIdentifiers

enum Style {
    static let accent=Color(red:0.08,green:0.72,blue:0.56)
    static let background=Color(uiColor:.systemGroupedBackground)
    static let surface=Color(uiColor:.secondarySystemGroupedBackground)
    static let muted=Color.secondary
}

struct Artwork: View {
    var url:URL?
    var size:CGFloat=56
    var fallback="app.fill"
    var body: some View {
        AsyncImage(url:url?.scheme=="https" ? url:nil) { image in image.resizable().scaledToFill() } placeholder: {
            ZStack { Style.accent.opacity(0.12); Image(systemName:fallback).font(.system(size:size*0.43,weight:.medium)).foregroundStyle(Style.accent) }
        }.frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:size*0.25,style:.continuous))
    }
}

struct BrandIcon: View {
    var size:CGFloat=56
    var body: some View { Image("BrandIcon").resizable().scaledToFit().frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:size*0.25,style:.continuous)) }
}

struct SectionTitle: View {
    let title:String
    var action:String?
    var onAction:(()->Void)?
    var body: some View {
        HStack { Text(title).font(.title3.bold()); Spacer(); if let action { Button(action) { onAction?() }.font(.subheadline.weight(.medium)) } }.padding(.top,10)
    }
}

struct EngineProgress: View {
    @EnvironmentObject var engine:Engine
    var body: some View {
        if engine.busy {
            VStack(alignment:.leading,spacing:7) { ProgressView(value:engine.progress); Text(engine.message).font(.caption).foregroundStyle(.secondary) }
                .padding(14).background(.regularMaterial,in:RoundedRectangle(cornerRadius:16)).padding(.horizontal).padding(.bottom,8)
        }
    }
}

struct CatalogRow: View {
    @EnvironmentObject var engine:Engine
    let app:CatalogApp
    let source:SourceCatalog
    @ObservedObject var connection:Connection
    var body: some View {
        HStack(spacing:13) {
            NavigationLink { AppDetailView(app:app,source:source,connection:connection) } label: {
                HStack(spacing:13) { Artwork(url:app.iconURL); VStack(alignment:.leading,spacing:4) { Text(app.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary); Text(app.subtitle ?? app.developerName ?? source.name).font(.caption).foregroundStyle(.secondary).lineLimit(2) } }
            }.buttonStyle(.plain)
            Spacer(minLength:4)
            Button { installOrRenew() } label: { Text(buttonTitle).font(.caption.bold()).padding(.horizontal,15).padding(.vertical,9).background(Style.accent.opacity(0.12),in:Capsule()) }
                .buttonStyle(.plain).foregroundStyle(Style.accent).disabled(engine.busy || app.latest==nil)
        }.padding(.vertical,10)
    }
    private var buttonTitle:String { engine.hasUpdate(app) ? "Update" : engine.installed(app) != nil ? "Erneuern":"Laden" }
    private func installOrRenew() {
        if let installed=engine.installed(app), !engine.hasUpdate(app) {engine.refresh(installed,peer:connection.peer,port:connection.port)}
        else {Task {await engine.install(app,source:source,peer:connection.peer,port:connection.port)}}
    }
}

struct DiscoverView: View {
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    var addSource:()->Void
    var openAccount:()->Void
    @State private var query=""
    @State private var category="Alle"
    private var entries:[CatalogEntry] { engine.sources.flatMap { source in source.apps.map { CatalogEntry(app:$0,source:source) } } }
    private var categories:[String] { ["Alle"]+Set(entries.compactMap{$0.app.category}).sorted() }
    private var filtered:[CatalogEntry] {entries.filter { (category=="Alle" || $0.app.category==category) && (query.isEmpty || "\($0.app.name) \($0.app.developerName ?? "") \($0.source.name)".localizedCaseInsensitiveContains(query)) }}
    private var feature:CatalogEntry? { entries.first { $0.source.featuredApps?.contains($0.app.id)==true } ?? entries.first }
    var body: some View {
        ScrollView {
            LazyVStack(alignment:.leading,spacing:18) {
                HStack {
                    VStack(alignment:.leading,spacing:5) { Text("DIRECTSIDE").font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary); Text("Entdecken").font(.largeTitle.bold()).tracking(-1) }
                    Spacer(); Button(action:openAccount) { Image(systemName:"person.crop.circle.fill").font(.system(size:35)).symbolRenderingMode(.hierarchical) }.accessibilityLabel("Konto öffnen")
                }
                HStack(spacing:9) {Image(systemName:"magnifyingglass").foregroundStyle(.secondary); TextField("Apps, Entwickler und Quellen",text:$query).font(.subheadline).autocorrectionDisabled()}.padding(12).background(Color(uiColor:.tertiarySystemFill),in:RoundedRectangle(cornerRadius:13))
                if query.isEmpty,let feature { featured(feature) }
                if categories.count>1 {
                    ScrollView(.horizontal,showsIndicators:false) { HStack(spacing:8) {ForEach(categories,id:\.self) { value in Button(categoryName(value)) {category=value}.font(.caption.weight(.medium)).padding(.horizontal,14).padding(.vertical,10).background(category==value ? Color.primary:Style.surface,in:RoundedRectangle(cornerRadius:11)).foregroundStyle(category==value ? Style.background:Color.primary) }} }
                }
                SectionTitle(title:query.isEmpty ? "Für dein iPhone":"Suchergebnisse")
                if entries.isEmpty {
                    ContentUnavailableView {Label("Dein eigener App-Katalog",systemImage:"square.stack.3d.up")} description: {Text("Scanne eine Quelle oder füge ihre Adresse hinzu. Deine Apps erscheinen anschließend hier.")} actions: {Button("Erste Quelle hinzufügen",action:addSource).buttonStyle(.borderedProminent)}
                } else if filtered.isEmpty {ContentUnavailableView.search(text:query)}
                else { VStack(spacing:0) {ForEach(filtered) {entry in CatalogRow(app:entry.app,source:entry.source,connection:connection); if entry.id != filtered.last?.id {Divider().padding(.leading,69)} }} }
                if query.isEmpty, let story=engine.sources.flatMap({$0.news ?? []}).first {
                    SectionTitle(title:"Aus deinen Quellen")
                    VStack(alignment:.leading,spacing:10) {
                        if let image=story.imageURL {AsyncImage(url:image){$0.resizable().scaledToFill()} placeholder:{Style.accent.opacity(0.1)}.frame(height:150).clipped().clipShape(RoundedRectangle(cornerRadius:15))}
                        Text(story.title).font(.headline)
                        if let caption=story.caption {Text(caption).font(.subheadline).foregroundStyle(.secondary)}
                        if let url=story.url,url.scheme=="https" {Link("Mehr erfahren",destination:url).font(.subheadline.weight(.medium))}
                    }.padding(17).background(Style.surface,in:RoundedRectangle(cornerRadius:21))
                }
            }.padding(21)
        }.background(Style.background).toolbar(.hidden,for:.navigationBar)
         .refreshable {await engine.refreshSources()}.safeAreaInset(edge:.bottom) {EngineProgress()}
    }
    private func featured(_ entry:CatalogEntry)->some View {
        NavigationLink {AppDetailView(app:entry.app,source:entry.source,connection:connection)} label: {
            VStack(alignment:.leading,spacing:18) {
                Text("IM FOKUS · \(entry.source.name.uppercased())").font(.system(size:10,weight:.bold)).tracking(1.6).foregroundStyle(.white.opacity(0.7))
                Text(entry.app.subtitle ?? entry.app.name).font(.system(size:29,weight:.bold)).tracking(-0.8).lineLimit(3).frame(maxWidth:.infinity,alignment:.leading)
                Text(entry.app.developerName ?? entry.source.subtitle ?? entry.source.name).font(.caption).foregroundStyle(.white.opacity(0.75))
                HStack(spacing:10) {Artwork(url:entry.app.iconURL,size:38); VStack(alignment:.leading,spacing:3){Text(entry.app.name).font(.subheadline.bold());Text(entry.app.latest?.displayVersion ?? "App ansehen").font(.caption2).foregroundStyle(.white.opacity(0.7))};Spacer();Image(systemName:"arrow.up.right").font(.headline).padding(12).background(.white.opacity(0.14),in:Circle())}
            }.padding(22).foregroundStyle(.white).background(LinearGradient(colors:[Color(red:0.08,green:0.26,blue:0.25),Color(red:0.03,green:0.12,blue:0.16)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:23))
        }.buttonStyle(.plain)
    }
}

struct CatalogEntry:Identifiable {var app:CatalogApp;var source:SourceCatalog;var id:String {source.id+"|"+app.id}}
func categoryName(_ value:String)->String {["Alle":"Alle","entertainment":"Entertainment","games":"Spiele","utilities":"Werkzeuge","developer":"Entwicklung","photo-video":"Foto & Video","social":"Soziales","lifestyle":"Lifestyle","other":"Weitere"][value] ?? value.capitalized}

struct AppDetailView: View {
    @EnvironmentObject var engine:Engine
    let app:CatalogApp
    let source:SourceCatalog
    @ObservedObject var connection:Connection
    @State private var showHistory=false
    @State private var selectedImage:AppScreenshot?
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                HStack(alignment:.top,spacing:17) {
                    Artwork(url:app.iconURL,size:88)
                    VStack(alignment:.leading,spacing:6) {Text(app.name).font(.title2.bold());Text(app.developerName ?? source.name).font(.subheadline).foregroundStyle(.secondary);Button(engine.hasUpdate(app) ? "Aktualisieren":engine.installed(app) != nil ? "Erneuern":"Installieren") {if let installed=engine.installed(app), !engine.hasUpdate(app) {engine.refresh(installed,peer:connection.peer,port:connection.port)} else {Task {await engine.install(app,source:source,peer:connection.peer,port:connection.port)}}}.font(.caption.bold()).buttonStyle(.borderedProminent).buttonBorderShape(.capsule).disabled(engine.busy || app.latest==nil)}
                }
                HStack {metadata("VERSION",app.latest?.displayVersion ?? "–");Divider();metadata("GRÖSSE",app.latest?.size.map{ByteCountFormatter.string(fromByteCount:$0,countStyle:.file)} ?? "–");Divider();metadata("SYSTEM",app.latest?.minOSVersion.map{"iOS \($0)+"} ?? "iOS")}.frame(height:52).padding(.vertical,6)
                if let shots=app.screenshots?.all,!shots.isEmpty {
                    ScrollView(.horizontal,showsIndicators:false) {HStack(spacing:12) {ForEach(shots) { shot in Button {selectedImage=shot} label: {AsyncImage(url:shot.imageURL.scheme=="https" ? shot.imageURL:nil) {image in image.resizable().scaledToFit()} placeholder:{RoundedRectangle(cornerRadius:17).fill(Style.surface).overlay(ProgressView())}.frame(width:max(140,min(310,240*shot.aspectRatio)),height:240).clipShape(RoundedRectangle(cornerRadius:17))}.buttonStyle(.plain).accessibilityLabel("Screenshot vergrößern")}}}
                }
                if let description=app.localizedDescription {SectionTitle(title:"Über diese App");Text(description).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)}
                SectionTitle(title:"Das ist neu",action:"Versionsverlauf",onAction:{showHistory=true})
                if let latest=app.latest {HStack {Text(latest.displayVersion).font(.subheadline.bold());Spacer();Text(latest.date.map{String($0.prefix(10))} ?? "").font(.caption).foregroundStyle(.secondary)};Text(latest.localizedDescription ?? "Keine Versionshinweise vorhanden.").font(.subheadline).foregroundStyle(.secondary)}
                if app.latest==nil {Label("Keine mit diesem iOS kompatible Version verfügbar.",systemImage:"info.circle").font(.subheadline).foregroundStyle(.secondary)}
                Button {LiveContainerBridge.importApp(app,engine:engine)} label:{Label("In LiveContainer installieren",systemImage:"square.stack.3d.up").font(.subheadline.weight(.medium)).frame(maxWidth:.infinity).padding(15).background(Style.surface,in:RoundedRectangle(cornerRadius:15))}
                SectionTitle(title:"Informationen")
                VStack(spacing:0) {info("Entwickler",app.developerName ?? source.name);Divider();info("Kategorie",categoryName(app.category ?? "other"));Divider();info("Quelle",source.name);Divider();info("Bundle-ID",app.id)}.padding(16).background(Style.surface,in:RoundedRectangle(cornerRadius:17))
                if let permissions=app.appPermissions {
                    DisclosureGroup("App-Berechtigungen") {VStack(alignment:.leading,spacing:12) {ForEach((permissions.privacy ?? [:]).keys.sorted(),id:\.self) {key in VStack(alignment:.leading,spacing:4){Text(key).font(.caption.bold());Text(permissions.privacy?[key] ?? "").font(.caption).foregroundStyle(.secondary)}};ForEach(permissions.entitlements ?? [],id:\.self){Text($0).font(.caption).foregroundStyle(.secondary)}}.padding(.top,10)}.font(.subheadline)
                }
            }.padding(21)
        }.background(Style.background).navigationTitle(app.name).navigationBarTitleDisplayMode(.inline).safeAreaInset(edge:.bottom){EngineProgress()}
         .sheet(isPresented:$showHistory) {NavigationStack {List(app.versions ?? [],id:\.displayVersion) {version in VStack(alignment:.leading,spacing:9) {Text(version.displayVersion).font(.headline);Text(version.date ?? "").font(.caption).foregroundStyle(.secondary);Text(version.localizedDescription ?? "Keine Versionshinweise.").font(.subheadline)}}.navigationTitle("Versionsverlauf").toolbar {Button("Fertig"){showHistory=false}}}}
         .sheet(item:$selectedImage) {shot in ZStack(alignment:.topTrailing) {Color.black.ignoresSafeArea();AsyncImage(url:shot.imageURL){$0.resizable().scaledToFit()} placeholder:{ProgressView()};Button("Schließen"){selectedImage=nil}.padding().buttonStyle(.borderedProminent)}}
    }
    private func metadata(_ label:String,_ value:String)->some View {VStack(spacing:6) {Text(label).font(.system(size:9,weight:.medium)).tracking(1).foregroundStyle(.secondary);Text(value).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.8)}.frame(maxWidth:.infinity)}
    private func info(_ label:String,_ value:String)->some View {HStack(alignment:.top) {Text(label).foregroundStyle(.secondary);Spacer();Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)}.font(.caption).padding(.vertical,10)}
}

struct LibraryView: View {
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    @State private var showIPAImporter=false
    var body: some View {
        ScrollView {VStack(alignment:.leading,spacing:18) {
            Text("Meine Apps").font(.largeTitle.bold()).tracking(-1).padding(.top,10)
            Button {showIPAImporter=true} label:{Label("IPA importieren",systemImage:"square.and.arrow.down").font(.subheadline.bold())}.disabled(engine.busy)
            HStack {Label(engine.slotsText,systemImage:"square.grid.3x1").font(.caption).foregroundStyle(.secondary);Spacer();Button("Prüfen"){engine.inspectConnection(peer:connection.peer,port:connection.port)}.font(.caption)}
            VStack(alignment:.leading,spacing:16) {
                HStack {VStack(alignment:.leading,spacing:5) {Text("Deine Apps bleiben bereit").font(.headline);Text("DirectSide und \(engine.managed.filter{$0.id != "com.directside.app"}.count) weitere Apps").font(.caption).foregroundStyle(.secondary)};Spacer();if let days=engine.remainingDays {Text("\(days)").font(.largeTitle.bold())+Text(" Tage").font(.caption)}}
                Button {Task {await engine.renewAll(peer:connection.peer,port:connection.port)}} label:{Label("Alle Signaturen erneuern",systemImage:"arrow.clockwise").font(.subheadline.bold()).frame(maxWidth:.infinity).padding(.vertical,6)}.buttonStyle(.borderedProminent).disabled(engine.busy || !engine.loggedIn)
            }.padding(19).background(Style.accent.opacity(0.1),in:RoundedRectangle(cornerRadius:22))
            SectionTitle(title:"Updates \(engine.updates.isEmpty ? "":"\(engine.updates.count)")",action:engine.updates.isEmpty ? nil:"Alle aktualisieren",onAction:{Task {await engine.updateAll(peer:connection.peer,port:connection.port)}})
            if engine.updates.isEmpty {Label("Alles auf dem neuesten Stand",systemImage:"checkmark.circle").font(.subheadline).foregroundStyle(.secondary).padding(.vertical,12)}
            ForEach(engine.updates.map{CatalogEntry(app:$0.app,source:$0.source)}) {entry in VStack(alignment:.leading,spacing:10) {CatalogRow(app:entry.app,source:entry.source,connection:connection);if let notes=entry.app.latest?.localizedDescription {Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(4)};Label(entry.source.name,systemImage:"square.stack.3d.up").font(.caption2).foregroundStyle(.secondary)}.padding(16).background(Style.surface,in:RoundedRectangle(cornerRadius:21))}
            SectionTitle(title:"Installiert")
            NavigationLink {DeviceManagementView(connection:connection)} label:{Label("Apps auf diesem Gerät verwalten",systemImage:"trash").font(.subheadline)}
            HStack(spacing:12) {BrandIcon();VStack(alignment:.leading,spacing:4){Text("DirectSide").font(.subheadline.bold());Text(engine.selfExpirationText).font(.caption).foregroundStyle(.secondary)};Spacer();Button("Erneuern"){engine.refreshSelf(peer:connection.peer,port:connection.port)}.font(.caption.bold()).buttonStyle(.bordered).buttonBorderShape(.capsule).disabled(engine.busy || !engine.loggedIn || !engine.pairingReady)}.padding(.vertical,8)
            ForEach(engine.managed.filter{$0.id != "com.directside.app"}) {app in HStack(spacing:12) {Artwork(url:app.iconURL);VStack(alignment:.leading,spacing:4){Text(app.name).font(.subheadline.bold());Text(engine.expirationText(app)).font(.caption).foregroundStyle(.secondary)};Spacer();Menu {Button("Signatur erneuern"){engine.refresh(app,peer:connection.peer,port:connection.port)}} label:{Image(systemName:"ellipsis").padding(12)}}.padding(.vertical,8)}
        }.padding(21)}.background(Style.background).toolbar(.hidden,for:.navigationBar).refreshable{await engine.refreshSources()}.safeAreaInset(edge:.bottom){EngineProgress()}
        .fileImporter(isPresented:$showIPAImporter,allowedContentTypes:[UTType(filenameExtension:"ipa") ?? .data],allowsMultipleSelection:false) {result in
            switch result {
            case .success(let files):if let file=files.first {Task{await engine.importIPA(file)}}
            case .failure(let error):engine.fail(error.localizedDescription)
            }
        }
    }
}

struct SourcesView: View {
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    var addSource:()->Void
    var body: some View {
        ScrollView {VStack(alignment:.leading,spacing:16) {
            HStack {VStack(alignment:.leading,spacing:6){Text("DEIN APP-KATALOG").font(.caption2.weight(.semibold)).tracking(1.5).foregroundStyle(.secondary);Text("Quellen").font(.largeTitle.bold()).tracking(-1)};Spacer();Button(action:addSource){Image(systemName:"plus").font(.title3).padding(11).background(Style.surface,in:Circle())}.accessibilityLabel("Quelle hinzufügen")}
            Text("Deine Sammlungen. Immer aktuell.").font(.subheadline).foregroundStyle(.secondary)
            ForEach(engine.sources) {source in NavigationLink {SourceDetailView(source:source,connection:connection)} label:{VStack(alignment:.leading,spacing:14) {HStack(spacing:12){Artwork(url:source.iconURL,fallback:"square.stack.3d.up.fill");VStack(alignment:.leading,spacing:4){Text(source.name).font(.subheadline.bold()).foregroundStyle(.primary);Text(source.subtitle ?? source.sourceURL?.host ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(2)};Spacer();Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary)};HStack(spacing:16){Label("\(source.apps.count) Apps",systemImage:"square.grid.2x2");Label(engine.sourceFailures[source.id] == nil ? "Aktuell":"Nicht erreichbar",systemImage:engine.sourceFailures[source.id] == nil ? "checkmark":"exclamationmark.circle")}.font(.caption2).foregroundStyle(.secondary)}.padding(17).background(Style.surface,in:RoundedRectangle(cornerRadius:21))}.buttonStyle(.plain)}
            Button(action:addSource) {Label("Quelle per QR-Code hinzufügen",systemImage:"qrcode.viewfinder").font(.subheadline.weight(.medium)).frame(maxWidth:.infinity).padding(.vertical,24).background(RoundedRectangle(cornerRadius:21).strokeBorder(Style.accent.opacity(0.3),style:StrokeStyle(lineWidth:1,dash:[5,4])))}
            Button {Task {await engine.refreshSources()}} label:{Label(engine.refreshingSources ? "Quellen werden geprüft …":"Alle Quellen aktualisieren",systemImage:"arrow.clockwise").font(.subheadline).frame(maxWidth:.infinity).padding(15).background(Style.surface,in:RoundedRectangle(cornerRadius:15))}.disabled(engine.refreshingSources)
        }.padding(21)}.background(Style.background).toolbar(.hidden,for:.navigationBar).refreshable{await engine.refreshSources()}
    }
}

struct SourceDetailView:View {
    @EnvironmentObject var engine:Engine
    let source:SourceCatalog
    @ObservedObject var connection:Connection
    @Environment(\.dismiss) var dismiss
    @State private var confirmRemove=false
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:18){HStack(spacing:14){Artwork(url:source.iconURL,size:74,fallback:"square.stack.3d.up.fill");VStack(alignment:.leading,spacing:5){Text(source.name).font(.title2.bold());Text(source.subtitle ?? "\(source.apps.count) Apps").font(.subheadline).foregroundStyle(.secondary)}};if let text=source.description {Text(text).font(.subheadline).foregroundStyle(.secondary)};if let failure=engine.sourceFailures[source.id] {Label(failure,systemImage:"exclamationmark.circle").font(.caption).foregroundStyle(.orange)};ForEach(source.apps){CatalogRow(app:$0,source:source,connection:connection)};if let url=source.website,url.scheme=="https" {Link("Website der Quelle",destination:url)};Button("Quelle entfernen",role:.destructive){confirmRemove=true}.padding(.top,20)}.padding(21)}.background(Style.background).navigationTitle("Quelle").navigationBarTitleDisplayMode(.inline).confirmationDialog("Quelle entfernen?",isPresented:$confirmRemove,titleVisibility:.visible){Button("Quelle entfernen",role:.destructive){engine.removeSource(source);dismiss()}}message:{Text("Bereits installierte Apps bleiben erhalten.")}}
}
