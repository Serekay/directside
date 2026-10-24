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
        AsyncImage(url:url.map{["http","https"].contains($0.scheme ?? "")} == true ? url:nil) { image in image.resizable().scaledToFill() } placeholder: {
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
        HStack { Text(L(title)).font(.title3.bold()); Spacer(); if let action { Button(L(action)) { onAction?() }.font(.subheadline.weight(.medium)) } }.padding(.top,10)
    }
}

struct EngineProgress: View {
    @EnvironmentObject var engine:Engine
    var body: some View {
        if engine.busy {
            VStack(alignment:.leading,spacing:7) { ProgressView(value:engine.progress); Text(L(engine.message)).font(.caption).foregroundStyle(.secondary) }
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
                HStack(spacing:13) { Artwork(url:app.iconURL); VStack(alignment:.leading,spacing:4) { Text(L(app.name)).font(.subheadline.weight(.semibold)).foregroundStyle(.primary); Text(L(app.subtitle ?? app.developerName ?? source.name)).font(.caption).foregroundStyle(.secondary).lineLimit(2) } }
            }.buttonStyle(.plain)
            Spacer(minLength:4)
            CatalogInstallAction(app:app,source:source,connection:connection)
        }.padding(.vertical,10)
    }

}

struct CatalogInstallAction:View {
    @EnvironmentObject var engine:Engine
    let app:CatalogApp
    let source:SourceCatalog
    @ObservedObject var connection:Connection
    @State private var showContainerSetup=false
    var body:some View {
        Menu {
            Button {if let installed=engine.installed(app),!engine.hasUpdate(app) {engine.refresh(installed,peer:connection.peer,port:connection.port)}else{Task{await engine.install(app,source:source,peer:connection.peer,port:connection.port)}}} label:{Label(L("Auf diesem Gerät"),systemImage:"iphone")}
            Button {if LiveContainerBridge.available {LiveContainerBridge.importApp(app,engine:engine)}else{showContainerSetup=true}} label:{Label(L("In LiveContainer"),systemImage:"square.stack.3d.up")}
        }label:{
            if let installed=engine.installed(app),!engine.hasUpdate(app) {SignatureLabel(expiresAt:installed.expiresAt)}
            else {Text(L(engine.hasUpdate(app) ? "Aktualisieren":"Laden")).font(.caption.bold()).padding(.horizontal,15).padding(.vertical,9).background(Style.accent.opacity(0.12),in:Capsule())}
        }
        .foregroundStyle(Style.accent).disabled(engine.busy || app.latest==nil)
        .sheet(isPresented:$showContainerSetup){NavigationStack{LiveContainerSettings(connection:connection).toolbar{Button(L("Fertig")){showContainerSetup=false}}}.safeAreaInset(edge:.top){VPNStatusView(connection:connection)}}
    }
}

struct DiscoverView: View {
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    var addSource:()->Void
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
                    VStack(alignment:.leading,spacing:5) { Text(L("DIRECTSIDE")).font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary); Text(L("Entdecken")).font(.largeTitle.bold()).tracking(-1) }
                }
                HStack(spacing:9) {Image(systemName:"magnifyingglass").foregroundStyle(.secondary); TextField(L("Apps, Entwickler und Quellen"),text:$query).font(.subheadline).autocorrectionDisabled()}.padding(12).background(Color(uiColor:.tertiarySystemFill),in:RoundedRectangle(cornerRadius:13))
                if query.isEmpty,let feature { featured(feature) }
                if categories.count>1 {
                    ScrollView(.horizontal,showsIndicators:false) { HStack(spacing:8) {ForEach(categories,id:\.self) { value in Button(L(categoryName(value))) {category=value}.font(.caption.weight(.medium)).padding(.horizontal,14).padding(.vertical,10).background(category==value ? Color.primary:Style.surface,in:RoundedRectangle(cornerRadius:11)).foregroundStyle(category==value ? Style.background:Color.primary) }} }
                }
                SectionTitle(title:query.isEmpty ? "Für dein iPhone":"Suchergebnisse")
                if entries.isEmpty {
                    ContentUnavailableView {Label(L("Dein eigener App-Katalog"),systemImage:"square.stack.3d.up")} description: {Text(L("Scanne eine Quelle oder füge ihre Adresse hinzu. Deine Apps erscheinen anschließend hier."))} actions: {Button(L("Erste Quelle hinzufügen"),action:addSource).buttonStyle(.borderedProminent)}
                } else if filtered.isEmpty {ContentUnavailableView.search(text:query)}
                else { VStack(spacing:0) {ForEach(filtered) {entry in CatalogRow(app:entry.app,source:entry.source,connection:connection); if entry.id != filtered.last?.id {Divider().padding(.leading,69)} }} }
                if query.isEmpty, let story=engine.sources.flatMap({$0.news ?? []}).first {
                    SectionTitle(title:"Aus deinen Quellen")
                    VStack(alignment:.leading,spacing:10) {
                        if let image=story.imageURL {AsyncImage(url:image){$0.resizable().scaledToFill()} placeholder:{Style.accent.opacity(0.1)}.frame(height:150).clipped().clipShape(RoundedRectangle(cornerRadius:15))}
                        Text(L(story.title)).font(.headline)
                        if let caption=story.caption {Text(L(caption)).font(.subheadline).foregroundStyle(.secondary)}
                        if let url=story.url,["http","https"].contains(url.scheme ?? "") {Link(L("Mehr erfahren"),destination:url).font(.subheadline.weight(.medium))}
                    }.padding(17).background(Style.surface,in:RoundedRectangle(cornerRadius:21))
                }
            }.padding(21)
        }.background(Style.background).toolbar(.hidden,for:.navigationBar)
         .refreshable {await engine.refreshSources()}.safeAreaInset(edge:.bottom) {EngineProgress()}
    }
    private func featured(_ entry:CatalogEntry)->some View {
        NavigationLink {AppDetailView(app:entry.app,source:entry.source,connection:connection)} label: {
            VStack(alignment:.leading,spacing:18) {
                Text(L("IM FOKUS · \(entry.source.name.uppercased())")).font(.system(size:10,weight:.bold)).tracking(1.6).foregroundStyle(.white.opacity(0.7))
                Text(L(entry.app.subtitle ?? entry.app.name)).font(.system(size:29,weight:.bold)).tracking(-0.8).lineLimit(3).frame(maxWidth:.infinity,alignment:.leading)
                Text(L(entry.app.developerName ?? entry.source.subtitle ?? entry.source.name)).font(.caption).foregroundStyle(.white.opacity(0.75))
                HStack(spacing:10) {Artwork(url:entry.app.iconURL,size:38); VStack(alignment:.leading,spacing:3){Text(L(entry.app.name)).font(.subheadline.bold());Text(L(entry.app.latest?.displayVersion ?? "App ansehen")).font(.caption2).foregroundStyle(.white.opacity(0.7))};Spacer();Image(systemName:"arrow.up.right").font(.headline).padding(12).background(.white.opacity(0.14),in:Circle())}
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
                    VStack(alignment:.leading,spacing:6) {Text(L(app.name)).font(.title2.bold());Text(L(app.developerName ?? source.name)).font(.subheadline).foregroundStyle(.secondary);CatalogInstallAction(app:app,source:source,connection:connection)}
                }
                HStack {metadata("VERSION",app.latest?.displayVersion ?? "–");Divider();metadata("GRÖSSE",app.latest?.size.map{ByteCountFormatter.string(fromByteCount:$0,countStyle:.file)} ?? "–");Divider();metadata("SYSTEM",app.latest?.minOSVersion.map{"iOS \($0)+"} ?? "iOS")}.frame(height:52).padding(.vertical,6)
                if let shots=app.screenshots?.all,!shots.isEmpty {
                    ScrollView(.horizontal,showsIndicators:false) {HStack(spacing:12) {ForEach(shots) { shot in Button {selectedImage=shot} label: {AsyncImage(url:["http","https"].contains(shot.imageURL.scheme ?? "") ? shot.imageURL:nil) {image in image.resizable().scaledToFit()} placeholder:{RoundedRectangle(cornerRadius:17).fill(Style.surface).overlay(ProgressView())}.frame(width:max(140,min(310,240*shot.aspectRatio)),height:240).clipShape(RoundedRectangle(cornerRadius:17))}.buttonStyle(.plain).accessibilityLabel(L("Screenshot vergrößern"))}}}
                }
                if let description=app.localizedDescription {SectionTitle(title:"Über diese App");Text(L(description)).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)}
                SectionTitle(title:"Das ist neu",action:"Versionsverlauf",onAction:{showHistory=true})
                if let latest=app.latest {HStack {Text(L(latest.displayVersion)).font(.subheadline.bold());Spacer();Text(L(latest.date.map{String($0.prefix(10))} ?? "")).font(.caption).foregroundStyle(.secondary)};Text(L(latest.localizedDescription ?? "Keine Versionshinweise vorhanden.")).font(.subheadline).foregroundStyle(.secondary)}
                if app.latest==nil {Label(L("Keine mit diesem iOS kompatible Version verfügbar."),systemImage:"info.circle").font(.subheadline).foregroundStyle(.secondary)}
                SectionTitle(title:"Informationen")
                VStack(spacing:0) {info("Entwickler",app.developerName ?? source.name);Divider();info("Kategorie",categoryName(app.category ?? "other"));Divider();info("Quelle",source.name);Divider();info("Bundle-ID",app.id)}.padding(16).background(Style.surface,in:RoundedRectangle(cornerRadius:17))
                if let permissions=app.appPermissions {
                    DisclosureGroup(L("App-Berechtigungen")) {VStack(alignment:.leading,spacing:12) {ForEach((permissions.privacy ?? [:]).keys.sorted(),id:\.self) {key in VStack(alignment:.leading,spacing:4){Text(L(key)).font(.caption.bold());Text(L(permissions.privacy?[key] ?? "")).font(.caption).foregroundStyle(.secondary)}};ForEach(permissions.entitlements ?? [],id:\.self){Text(L($0)).font(.caption).foregroundStyle(.secondary)}}.padding(.top,10)}.font(.subheadline)
                }
            }.padding(21)
        }.background(Style.background).navigationTitle(L(app.name)).navigationBarTitleDisplayMode(.inline).safeAreaInset(edge:.bottom){EngineProgress()}
         .sheet(isPresented:$showHistory) {NavigationStack {List(app.versions ?? [],id:\.displayVersion) {version in VStack(alignment:.leading,spacing:9) {Text(L(version.displayVersion)).font(.headline);Text(L(version.date ?? "")).font(.caption).foregroundStyle(.secondary);Text(L(version.localizedDescription ?? "Keine Versionshinweise.")).font(.subheadline)}}.navigationTitle(L("Versionsverlauf")).toolbar {Button(L("Fertig")){showHistory=false}}}}
         .sheet(item:$selectedImage) {shot in ZStack(alignment:.topTrailing) {Color.black.ignoresSafeArea();AsyncImage(url:shot.imageURL){$0.resizable().scaledToFit()} placeholder:{ProgressView()};Button(L("Schließen")){selectedImage=nil}.padding().buttonStyle(.borderedProminent)}}
    }
    private func metadata(_ label:String,_ value:String)->some View {VStack(spacing:6) {Text(L(label)).font(.system(size:9,weight:.medium)).tracking(1).foregroundStyle(.secondary);Text(L(value)).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.8)}.frame(maxWidth:.infinity)}
    private func info(_ label:String,_ value:String)->some View {HStack(alignment:.top) {Text(L(label)).foregroundStyle(.secondary);Spacer();Text(L(value)).multilineTextAlignment(.trailing).textSelection(.enabled)}.font(.caption).padding(.vertical,10)}
}

struct SourcesView:View {
    @EnvironmentObject var engine:Engine
    @ObservedObject var connection:Connection
    var addSource:()->Void
    var body:some View {
        List {
            HStack {
                Text(L("Quellen")).font(.largeTitle.bold()).tracking(-1)
                Spacer()
                Button(action:addSource){Image(systemName:"plus").font(.title3.weight(.semibold)).padding(11).background(Style.surface,in:Circle())}.accessibilityLabel(L("Quelle hinzufügen"))
            }.listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top:14,leading:21,bottom:18,trailing:21))
            ForEach(engine.sources) {source in
                NavigationLink {SourceDetailView(source:source,connection:connection)}label:{
                    HStack(spacing:13) {
                        Artwork(url:source.iconURL,fallback:"square.stack.3d.up.fill")
                        VStack(alignment:.leading,spacing:7) {
                            Text(source.name).font(.subheadline.bold()).foregroundStyle(.primary)
                            HStack(spacing:10) {
                                Text(L("\(source.apps.count) Apps"))
                                if engine.refreshingSources {ProgressView().controlSize(.mini);Text(L("Aktualisieren …"))}
                                else {Label(L(engine.sourceFailures[source.id] != nil ? "Nicht erreichbar":source.refreshedAt == nil ? "Nicht geprüft":"Aktuell"),systemImage:engine.sourceFailures[source.id] != nil ? "exclamationmark.circle":"checkmark.circle")}
                            }.font(.caption2).foregroundStyle(engine.sourceFailures[source.id] != nil ? Color.orange:Color.secondary)
                        }
                    }.padding(.vertical,10)
                }.listRowBackground(Style.surface)
                .swipeActions(edge:.trailing,allowsFullSwipe:true) {
                    Button(role:.destructive){withAnimation{engine.removeSource(source)}}label:{Label(L("Quelle entfernen"),systemImage:"trash")}
                }
            }
        }.listStyle(.plain).scrollContentBackground(.hidden).background(Style.background).toolbar(.hidden,for:.navigationBar)
        .refreshable {await engine.refreshSources()}
    }
}

struct SourceDetailView:View {
    @EnvironmentObject var engine:Engine
    let source:SourceCatalog
    @ObservedObject var connection:Connection
    var body:some View {ScrollView {VStack(alignment:.leading,spacing:18){HStack(spacing:14){Artwork(url:source.iconURL,size:74,fallback:"square.stack.3d.up.fill");VStack(alignment:.leading,spacing:5){Text(L(source.name)).font(.title2.bold());Text(L(source.subtitle ?? "\(source.apps.count) Apps")).font(.subheadline).foregroundStyle(.secondary)}};if let text=source.description {Text(L(text)).font(.subheadline).foregroundStyle(.secondary)};if let failure=engine.sourceFailures[source.id] {Label(L(failure),systemImage:"exclamationmark.circle").font(.caption).foregroundStyle(.orange)};ForEach(source.apps){CatalogRow(app:$0,source:source,connection:connection)};if let url=source.website,["http","https"].contains(url.scheme ?? "") {Link(L("Website der Quelle"),destination:url)}}.padding(21)}.background(Style.background).navigationTitle(L("Quelle")).navigationBarTitleDisplayMode(.inline)}
}
