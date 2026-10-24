import Foundation

@main struct SourceRefreshTests {
    @MainActor static func main() async {
        let refresh=SourceRefreshCoordinator()
        var requests=0
        var completions=0
        let viewWaiter=Task {
            await refresh.run {
                requests+=1
                try? await Task.sleep(for:.milliseconds(40))
                completions+=1
            }
        }
        while requests==0 {await Task.yield()}
        viewWaiter.cancel()
        await refresh.run {requests+=100}
        await viewWaiter.value
        precondition(requests==1 && completions==1,"Cancelled view waiter must neither abort nor duplicate shared source loading")
        await refresh.run {requests+=1}
        precondition(requests==2,"A later refresh must start a fresh request")
        print("Shared source loading survives cancelled view waiters and coalesces refreshes: passed")
    }
}
