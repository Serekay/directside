import Network
import Foundation

@MainActor final class InstallConnection {
    private var connection: NWConnection?
    private var continuation: CheckedContinuation<Bool,Never>?
    func reachable(peer: String, port: Int) async -> Bool {
        guard port > 0, port <= 65535, let endpoint = NWEndpoint.Port(rawValue: UInt16(port)) else { return false }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let connection = NWConnection(host: NWEndpoint.Host(peer), port: endpoint, using: .tcp)
            self.connection = connection
            connection.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready: self?.finish(true)
                    case .failed, .waiting: self?.finish(false)
                    default: break
                    }
                }
            }
            connection.start(queue: .global(qos: .utility))
            Task { try? await Task.sleep(for: .seconds(3)); self.finish(false) }
        }
    }
    private func finish(_ reachable: Bool) {
        let result = continuation; continuation = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel(); connection = nil
        result?.resume(returning: reachable)
    }
}
