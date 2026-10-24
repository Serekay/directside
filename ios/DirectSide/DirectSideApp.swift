import SwiftUI

@main struct DirectSideApp: App {
    @StateObject private var engine = Engine()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(engine).tint(.cyan)
                .onOpenURL { url in Task { await engine.previewSource(url.absoluteString) } }
        }
    }
}
