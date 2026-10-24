import Foundation

/// Shared, view-independent refresh. A disappearing/cancelled SwiftUI refresh
/// waiter must not cancel the request or start a second request for all sources.
@MainActor final class SourceRefreshCoordinator {
    private var running:Task<Void,Never>?
    func run(_ operation:@escaping @MainActor () async->Void) async {
        if let running {await running.value;return}
        let task=Task {await operation()}
        running=task
        await task.value
        running=nil
    }
}
