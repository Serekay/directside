import SwiftUI

@main struct DirectSideApp: App {
    @StateObject private var engine = Engine()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(engine).tint(.cyan)
                .onOpenURL { url in Task {
                    if url.isFileURL && url.pathExtension.lowercased()=="ipa" {await engine.importIPA(url)}
                    else if url.scheme=="directside" && (url.host ?? "").isEmpty && url.query==nil {return}
                    else {await engine.previewSource(url.absoluteString)}
                } }
        }
    }
}
