import Foundation
import Combine
import Network
import UIKit

@MainActor final class Connection: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published var peer = UserDefaults.standard.string(forKey:"peer") ?? "10.7.0.1"
    @Published var port = UserDefaults.standard.integer(forKey:"port")
    @Published var status = "LocalDevVPN verbinden, dann Port suchen."
    @Published var vpnReachable=false
    private var monitor:Timer?
    private var probe:NWConnection?
    private var probeID:UUID?
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []
    private var timeout: Timer?
    override init() { super.init(); browser.delegate=self }
    func startMonitoring() {
        monitor?.invalidate();checkVPN()
        monitor=Timer.scheduledTimer(withTimeInterval:5,repeats:true){[weak self] _ in Task{@MainActor in self?.checkVPN()}}
        discover()
    }
    func stopMonitoring() {
        monitor?.invalidate();monitor=nil;probeID=nil;probe?.cancel();probe=nil;vpnReachable=false
        browser.stop();timeout?.invalidate()
    }
    func checkVPN() {
        guard probe==nil else {return}
        guard port>0,port<=65535,let endpoint=NWEndpoint.Port(rawValue:UInt16(port)) else {vpnReachable=false;return}
        let id=UUID();probeID=id
        let connection=NWConnection(host:NWEndpoint.Host(peer),port:endpoint,using:.tcp);probe=connection
        connection.stateUpdateHandler={[weak self] state in Task{@MainActor in
            guard let self,self.probeID==id else {return}
            switch state {
            case .ready:self.finishProbe(id,reachable:true)
            case .failed,.waiting:self.finishProbe(id,reachable:false)
            default:break
            }
        }}
        connection.start(queue:.global(qos:.utility))
        Task {try? await Task.sleep(for:.seconds(3));finishProbe(id,reachable:false)}
    }
    private func finishProbe(_ id:UUID,reachable:Bool) {
        guard probeID==id else {return}
        vpnReachable=reachable;probeID=nil;probe?.cancel();probe=nil
    }
    var vpnInstalled:Bool {UIApplication.shared.canOpenURL(URL(string:"localdevvpn://")!)}
    func openVPN() {
        guard vpnInstalled else {status="LocalDevVPN ist nicht installiert.";return}
        // Official LocalDevVPN enable/callback route; returns to DirectSide.
        UIApplication.shared.open(URL(string:"localdevvpn://enable?scheme=directside")!)
    }
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
        checkVPN()
        browser.stop(); timeout?.invalidate()
    }
    func save() { UserDefaults.standard.set(peer,forKey:"peer"); UserDefaults.standard.set(port,forKey:"port") }
}
