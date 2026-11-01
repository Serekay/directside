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
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("lc-recovery-test-"+UUID().uuidString,isDirectory:true)
        try! FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:folder)}
        var downloads=0
        let recovered=folder.appendingPathComponent("recovered.ipa")
        let expired=ManagedApp(id:"com.kdt.livecontainer",name:"LiveContainer",cachedIPA:"/previous-container/missing.ipa",installedAt:Date(),expiresAt:Date(timeIntervalSince1970:0))
        let package=try! await RenewalPackage.resolve(expired,support:folder){downloads+=1;try Data("fixture".utf8).write(to:recovered);return recovered}
        precondition(package==recovered && downloads==1,"An expired LiveContainer with no cached IPA must download a replacement without opening LiveContainer")
        var cached=expired;cached.cachedIPA="/previous-container/recovered.ipa"
        let reused=try! await RenewalPackage.resolve(cached,support:folder){downloads+=1;return recovered}
        precondition(reused==recovered && downloads==1,"Restored data-container paths must reuse the existing original package")
        let unrelated=ManagedApp(id:"example.other",name:"Other",cachedIPA:"missing.ipa",installedAt:Date())
        do {
            _=try await RenewalPackage.resolve(unrelated,support:folder){downloads+=1;return recovered}
            preconditionFailure("An unrelated app must not be replaced with LiveContainer")
        }catch{}
        precondition(downloads==1,"No recovery download for an unrelated app")
        print("Expired LiveContainer, missing IPA recovery and cached-path reuse: passed")
    }
}
