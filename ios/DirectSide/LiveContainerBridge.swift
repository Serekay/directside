import UIKit
import Foundation

enum LiveContainerBridge {
    static var available:Bool {URL(string:"livecontainer://").map{UIApplication.shared.canOpenURL($0)} ?? false}
    @MainActor static func importApp(_ app:CatalogApp,engine:Engine) {
        guard available else {engine.error="LiveContainer ist noch nicht installiert. Du kannst die offizielle Standalone-IPA über DirectSide installieren. DirectSide und LiveContainer benötigen zusammen zwei der drei Plätze.";return}
        guard let latest=app.latest,latest.downloadURL.scheme=="https" else {engine.error="Keine geeignete IPA-Adresse vorhanden.";return}
        var url=URLComponents();url.scheme="livecontainer";url.host="install";url.queryItems=[URLQueryItem(name:"url",value:latest.downloadURL.absoluteString)]
        guard let destination=url.url else {return}
        UIApplication.shared.open(destination,options:[:]){success in Task{@MainActor in
            if success {engine.message="An LiveContainer übergeben. Installation dort bestätigen."}
            else {engine.error="LiveContainer konnte nicht geöffnet werden."}
        }}
    }
}
