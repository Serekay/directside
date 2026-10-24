import Foundation
import Combine

@MainActor final class Connection: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published var peer = UserDefaults.standard.string(forKey:"peer") ?? "10.7.0.1"
    @Published var port = UserDefaults.standard.integer(forKey:"port")
    @Published var status = "LocalDevVPN verbinden, dann Port suchen."
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    private var timeout: Timer?
    override init() { super.init(); browser.delegate=self }
    func discover() {
        browser.stop(); services=[]; status="Remote-Pairing-Dienst suchen …"
        browser.searchForServices(ofType:"_remotepairing._tcp.",inDomain:"local.")
        timeout?.invalidate()
        timeout=Timer.scheduledTimer(withTimeInterval:12,repeats:false) { [weak self] _ in Task { @MainActor in
            guard let self else { return }; self.browser.stop()
            if self.services.isEmpty { self.status="Kein Dienst gefunden. LocalDevVPN und lokales Netzwerk prüfen." }
        } }
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service); service.delegate=self; service.resolve(withTimeout:8)
    }
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard sender.port>0 && sender.port<=65535 else { return }
        port=sender.port; save(); status="Port \(port) gefunden. Das Pairing wird beim Installieren geprüft."
        browser.stop(); timeout?.invalidate()
    }
    func save() { UserDefaults.standard.set(peer,forKey:"peer"); UserDefaults.standard.set(port,forKey:"port") }
}
