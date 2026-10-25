import SwiftUI

@main struct DirectSideApp: App {
    @StateObject private var engine = Engine()
    @StateObject private var updater = AppUpdater()
    @AppStorage("language") private var language="en"
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(engine).environmentObject(updater).environment(\.locale,Locale(identifier:language)).id(language).tint(.cyan)
                .onOpenURL { url in Task {
                    if url.isFileURL && url.pathExtension.lowercased()=="ipa" {await engine.importIPA(url)}
                    else if url.scheme=="directside" && (url.host ?? "").isEmpty && url.query==nil {return}
                    else {await engine.previewSource(url.absoluteString)}
                } }
        }
    }
}
