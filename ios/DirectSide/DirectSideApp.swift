import SwiftUI
import UIKit

@MainActor private final class DirectSideAppDelegate:NSObject,UIApplicationDelegate {
    func application(_ application:UIApplication,didFinishLaunchingWithOptions launchOptions:[UIApplication.LaunchOptionsKey:Any]?=nil)->Bool {
        _ = RenewalNotifications.shared
        return true
    }
}

@main struct DirectSideApp: App {
    @UIApplicationDelegateAdaptor(DirectSideAppDelegate.self) private var appDelegate
    @StateObject private var engine = Engine()
    @StateObject private var updater = AppUpdater()
    @StateObject private var reminders = RenewalNotifications.shared
    @AppStorage("language") private var language="en"
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(engine).environmentObject(updater).environmentObject(reminders).environment(\.locale,Locale(identifier:language)).id(language).tint(.cyan)
                .onOpenURL { url in Task {
                    if url.isFileURL && url.pathExtension.lowercased()=="ipa" {await engine.importIPA(url)}
                    else if url.scheme=="directside" && (url.host ?? "").isEmpty && url.query==nil {return}
                    else {await engine.previewSource(url.absoluteString)}
                } }
        }
    }
}
