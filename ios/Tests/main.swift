import Foundation

func check(_ condition:@autoclosure ()->Bool,_ message:String) {if !condition() {fatalError(message)}}
let classic="""
{"name":"Classic","apps":[{"name":"Test","bundleIdentifier":"example.test","version":"1.0","downloadURL":"https://example.com/a.ipa","screenshots":["https://example.com/a.png"]}]}
""".data(using:.utf8)!
let decoded=try JSONDecoder().decode(SourceCatalog.self,from:classic)
check(decoded.apps[0].latest?.version=="1.0","Classic source version")
check(decoded.apps[0].screenshots?.all.count==1,"String screenshot")
let modern="""
{"name":"Modern","apps":[{"name":"Test","bundleIdentifier":"example.test","versions":[{"version":"3.0","downloadURL":"https://example.com/beta.ipa","beta":true},{"version":"2.0","downloadURL":"https://example.com/new.ipa"},{"version":"1.0","downloadURL":"https://example.com/old.ipa"}],"screenshots":{"iphone":[{"imageURL":"https://example.com/phone.png","width":393,"height":852}],"ipad":[{"imageURL":"https://example.com/ipad.png","width":1668,"height":2388}]}}]}
""".data(using:.utf8)!
let source=try JSONDecoder().decode(SourceCatalog.self,from:modern)
check(source.apps[0].latest?.version=="2.0","Select first non-beta source version")
check(source.apps[0].screenshots?.all.first?.width==393,"Structured screenshots")
let wrapped=try SourceURL.parse("directside://source?url=https%3A%2F%2Fexample.com%2Fsource.json")
check(wrapped.absoluteString=="https://example.com/source.json","QR URL wrapper")
let localHTTP=try SourceURL.parse("http://192.168.1.10:8080/source.json")
check(localHTTP.scheme=="http","Local HTTP source")
for invalid in ["file:///private/test", "ftp://example.com/source.json","https://user:pass@example.com/source.json"] {
    do {_=try SourceURL.parse(invalid);fatalError("Accepted invalid source URL")} catch {}
}
let roundtrip=try JSONDecoder().decode(SourceCatalog.self,from:JSONEncoder().encode(source))
check(roundtrip.apps.count==1,"Persist sources")
print("Source decoding, screenshots, version order, URL validation and persistence: passed")
let translations=["Einstellungen":"Settings","Signatur noch %@ Tage gültig":"Signature valid for %@ more days"]
check(AppLocalization.translate("Einstellungen",language:"en",table:translations)=="Settings","English UI")
check(AppLocalization.translate("Einstellungen",language:"de",table:translations)=="Einstellungen","German UI")
check(AppLocalization.translate("Signatur noch 7 Tage gültig",language:"en",table:translations)=="Signature valid for 7 more days","Dynamic English UI")
check(AppLocalization.translate("My own app",language:"en",table:translations)=="My own app","Source names are preserved")
print("English/German text and interpolated status translation: passed")
check(SourceURL.isCancellation(CancellationError()),"Swift cancellation is not a server failure")
check(SourceURL.isCancellation(URLError(.cancelled)),"URLSession cancellation is not a server failure")
check(!SourceURL.isCancellation(URLError(.cannotConnectToHost)),"A real connection failure must remain visible")
let now=Date(timeIntervalSince1970:1000000)
check(SignatureStatus.days(until:now.addingTimeInterval(-10),now:now)==0,"Expired signature")
check(SignatureStatus.days(until:now.addingTimeInterval(86401),now:now)==2,"Round signature days up")
check(SignatureStatus.days(until:nil,now:now)==nil,"Unknown expiry is not invented")
check(SignatureStatus.tone(days:0)=="critical" && SignatureStatus.tone(days:1)=="critical","Critical signature warning")
check(SignatureStatus.tone(days:2)=="warning" && SignatureStatus.tone(days:3)=="warning","Signature warning")
check(SignatureStatus.tone(days:4)=="ok" && SignatureStatus.tone(days:nil)=="unknown","Healthy and unknown signatures")

check(UpdateVersion.newer("v0.2.0",than:"0.1.9"),"New release is offered")
check(!UpdateVersion.newer("0.1.0",than:"0.1.0"),"Same version is not an update")
check(!UpdateVersion.newer("0.0.9",than:"0.1.0"),"No downgrade")
for value in ["0.2.0-beta", "1.0", "1..0", "1.0.0.1", "1.0.-1", "1.0.a"] {
    check(UpdateVersion.parts(value)==nil,"Reject non-release version")
}
let legacyManaged="""
{"id":"example.app","name":"Example","cachedIPA":"/fixture.ipa","installedAt":0,"version":"1.0"}
""".data(using:.utf8)!
let legacyApp=try JSONDecoder().decode(ManagedApp.self,from:legacyManaged)
check(legacyApp.installedBundleID==nil,"Old managed records remain readable")
var signedApp=legacyApp;signedApp.installedBundleID="example.app.TEAM"
let restoredSignedApp=try JSONDecoder().decode(ManagedApp.self,from:JSONEncoder().encode(signedApp))
check(restoredSignedApp.installedBundleID=="example.app.TEAM","Persist real installed identifier")
print("Release version comparisons and installed identity migration: passed")

let publicAsset:[String:Any] = ["name":"DirectSide.ipa","state":"uploaded","size":100,
    "browser_download_url":"https://github.com/Serekay/directside/releases/download/v0.2.0/DirectSide.ipa",
    "digest":"sha256:"+String(repeating:"a",count:64)]
var publicRelease:[String:Any] = ["draft":false,"prerelease":false,"tag_name":"v0.2.0","assets":[publicAsset]]
let offered=try AppRelease.decode(publicRelease,installed:"0.1.0")
check(offered?.version=="0.2.0","Offer public release without GitHub credentials")
let alreadyInstalled=try AppRelease.decode(publicRelease,installed:"0.2.0")
check(alreadyInstalled==nil,"Do not offer installed release")
for invalidURL in ["http://github.com/Serekay/directside/releases/download/v0.2.0/DirectSide.ipa","https://github.com/other/project/releases/download/v0.2.0/DirectSide.ipa","https://example.com/DirectSide.ipa"] {
    var invalidAsset=publicAsset;invalidAsset["browser_download_url"]=invalidURL
    publicRelease["assets"]=[invalidAsset]
    do {_=try AppRelease.decode(publicRelease,installed:"0.1.0");fatalError("Accepted foreign update URL")}catch{}
}
var noDigest=publicAsset;noDigest.removeValue(forKey:"digest");publicRelease["assets"]=[noDigest]
do {_=try AppRelease.decode(publicRelease,installed:"0.1.0");fatalError("Accepted unverified update")}catch{}
let idRecord=try JSONDecoder().decode(RegisteredAppID.self,from:Data("{\"identifier\":\"example.app.TEST.Widget\",\"name\":\"Widget\",\"parent_name\":\"Example\",\"expires_at\":\"2026-10-30T12:00:00Z\"}".utf8))
check(idRecord.parent_name=="Example" && idRecord.expiration != nil,"Explain extension ownership and expiry")
print("Public release validation and registered App ID details: passed")


let buildSourceJSON="""
{"name":"Build updates","apps":[{"name":"Example","bundleIdentifier":"example.app","version":"1.0","buildVersion":"10","downloadURL":"https://example.com/app.ipa"}]}
""".data(using:.utf8)!
var buildSource=try JSONDecoder().decode(SourceCatalog.self,from:buildSourceJSON)
buildSource.sourceURL=URL(string:"https://example.com/source.json")
let candidate=buildSource.apps[0].latest!
check(candidate.buildVersion=="10","Classic source preserves build number")
var installed=ManagedApp(id:"example.app",name:"Example",cachedIPA:"fixture.ipa",installedAt:Date(),version:"1.0",buildVersion:"9")
check(CatalogUpdates.isNewer(candidate,than:installed),"Same bundle/version with newer numeric build is an update")
check(CatalogUpdates.entry(for:installed,in:[buildSource])?.source.id==buildSource.id,"Imported IPA without a source ID is matched by bundle ID")
installed.buildVersion="10"
check(!CatalogUpdates.isNewer(candidate,than:installed),"Installed update no longer produces an update badge")
installed.buildVersion="11"
check(!CatalogUpdates.isNewer(candidate,than:installed),"Older source builds are not offered as updates")
installed.version="v1.0.0";installed.buildVersion="10"
check(!CatalogUpdates.isNewer(candidate,than:installed),"Equivalent version spellings are not updates")
var alternative=buildSource;alternative.sourceURL=URL(string:"https://other.example/source.json")
check(CatalogUpdates.entry(for:installed,in:[buildSource,alternative])==nil,"Do not guess between competing sources")
installed.sourceID=buildSource.id
check(CatalogUpdates.entry(for:installed,in:[buildSource,alternative])?.source.id==buildSource.id,"Preserve explicit source association")
var unordered=buildSource.apps[0]
unordered.versions=[CatalogVersion(version:"1.0",downloadURL:URL(string:"https://example.com/old.ipa")!),CatalogVersion(version:"2.0",downloadURL:URL(string:"https://example.com/new.ipa")!)]
check(unordered.latest?.version=="2.0","Do not assume sources put the newest release first")
let sourceRequest=SourceURL.request(URL(string:"http://example.com/source.json")!)
check(sourceRequest.cachePolicy == .reloadIgnoringLocalCacheData && sourceRequest.value(forHTTPHeaderField:"Cache-Control")=="no-cache","Pull refresh revalidates source metadata")
let deviceVersion=try JSONDecoder().decode(DeviceApp.self,from:Data("{\"id\":\"example.app\",\"name\":\"Example\",\"developer\":true,\"version\":\"1.0\",\"buildVersion\":\"9\"}".utf8))
check(deviceVersion.version=="1.0" && deviceVersion.buildVersion=="9","Read installed versions for apps installed outside DirectSide")
print("Source update badges: build comparison, source matching, stale cache and installed version regression tests passed")


let renewalSupport=FileManager.default.temporaryDirectory.appendingPathComponent("directside-renewal-"+UUID().uuidString,isDirectory:true)
try FileManager.default.createDirectory(at:renewalSupport,withIntermediateDirectories:true)
defer {try? FileManager.default.removeItem(at:renewalSupport)}
let currentPackage=renewalSupport.appendingPathComponent("saved-app.ipa")
try Data("fixture".utf8).write(to:currentPackage)
let stalePath="/previous-data-container/Application Support/DirectSide/saved-app.ipa"
check(RenewalPackage.cachedURL(stalePath,support:renewalSupport)==currentPackage,"Resolve saved IPA filename after data-container relocation")
check(RenewalPackage.cachedURL("/outside/private.key",support:renewalSupport)==nil,"Never use a private key as a renewal package")
check(RenewalPackage.cachedURL("/outside/missing.ipa",support:renewalSupport)==nil,"Missing renewal cache is explicit")
check(RenewalPackage.isLiveContainer("com.kdt.livecontainer") && RenewalPackage.isLiveContainer("com.kdt.livecontainer.TESTTEAM01"),"LiveContainer missing-cache recovery is available for signed and unsigned IDs")
check(!RenewalPackage.isLiveContainer("com.kdt.livecontainer.other") && !RenewalPackage.isLiveContainer("unrelated.app"),"Do not recover an unrelated application as LiveContainer")
let outside=FileManager.default.temporaryDirectory.appendingPathComponent("outside-"+UUID().uuidString+".ipa")
try Data("outside fixture".utf8).write(to:outside)
defer {try? FileManager.default.removeItem(at:outside)}
try FileManager.default.createSymbolicLink(at:renewalSupport.appendingPathComponent("escape.ipa"),withDestinationURL:outside)
check(RenewalPackage.cachedURL("escape.ipa",support:renewalSupport)==nil,"Renewal cache cannot escape its support directory through symlinks")
print("Renewal package relocation, missing cache and application identity regressions: passed")

check(LocalConnectionStatus.resolve(installed:true,reachable:false,wifi:false) == .noWiFi,"No Wi-Fi must not be reported as VPN switched off")
check(LocalConnectionStatus.resolve(installed:true,reachable:true,wifi:false) == .connected,"A working local route takes precedence over physical Wi-Fi")
check(LocalConnectionStatus.resolve(installed:true,reachable:false,wifi:true) == .unreachable,"Wi-Fi plus a failed probe is unreachable, not proof that VPN is off")
check(LocalConnectionStatus.resolve(installed:true,reachable:false,wifi:nil) == .checking,"Unknown network state is still checking")
check(LocalConnectionStatus.resolve(installed:false,reachable:false,wifi:true) == .missingVPN,"Missing VPN application stays distinct")

let reminderNow=Date(timeIntervalSince1970:2_000_000_000)
let reminderApp=RenewalReminderApp(id:"example.app",name:"Example",expiresAt:reminderNow.addingTimeInterval(7*86400))
let reminderPlan=RenewalReminderPlan.make(apps:[reminderApp],now:reminderNow)
check(reminderPlan.count==2 && reminderPlan.map(\.days)==[2,1],"Two expiry reminders per application")
check(reminderPlan.map(\.date)==[5,6].map{reminderNow.addingTimeInterval(Double($0)*86400)},"Reminders are exactly two days and one day before expiry")
var renewedReminderApp=reminderApp;renewedReminderApp.expiresAt=reminderNow.addingTimeInterval(9*86400)
let renewedPlan=RenewalReminderPlan.make(apps:[reminderApp,renewedReminderApp],now:reminderNow)
check(renewedPlan.count==2 && renewedPlan.map(\.id)==reminderPlan.map(\.id),"Renewal replaces requests instead of duplicating them")
check(RenewalReminderPlan.make(apps:[reminderApp],now:reminderApp.expiresAt).isEmpty,"Never schedule notifications in the past")
check(RenewalReminderPlan.make(apps:[reminderApp],now:reminderNow,limit:1).first?.days==2,"Keep earliest reminders when reaching the notification limit")

let noticeURL=URL(string:"https://example.test/app.ipa")!
let noticeSourceURL=URL(string:"https://example.test/source.json")!
let noticeOldApp=CatalogApp(name:"Example",bundleIdentifier:"example.app",version:"1.0",downloadURL:noticeURL)
var noticeNewApp=noticeOldApp;noticeNewApp.version="1.1"
let noticeOldSource=SourceCatalog(name:"Example source",apps:[noticeOldApp],sourceURL:noticeSourceURL)
var noticeNewSource=noticeOldSource;noticeNewSource.apps=[noticeNewApp]
let versionNotices=SourceVersionChanges.updating(previous:noticeOldSource,current:noticeNewSource,pending:[])
check(versionNotices.count==1,"Source versions are visible even without native installed-app metadata")
check(SourceVersionChanges.updating(previous:noticeNewSource,current:noticeNewSource,pending:versionNotices).count==1,"An unchanged refresh keeps the pending source notice")
check(SourceVersionChanges.updating(previous:noticeNewSource,current:noticeOldSource,pending:versionNotices).isEmpty,"A rolled-back source version removes the outdated notice")
check(SourceVersionChanges.updating(previous:noticeOldSource,current:noticeOldSource,pending:[]).isEmpty,"No fake update for an unchanged source")
var installedNoticeApp=ManagedApp(id:"example.app",name:"Example",cachedIPA:"",installedAt:reminderNow,version:"1.0")
check(SourceVersionChanges.acknowledging(installed:installedNoticeApp,pending:versionNotices).count==1,"Installing an older IPA must not clear the newer source version")
installedNoticeApp.version="1.1"
check(SourceVersionChanges.acknowledging(installed:installedNoticeApp,pending:versionNotices).isEmpty,"Installing the available version clears its source notice")
check(CatalogUpdates.matchesInstalledID("example.app.TESTTEAM01",bundle:"example.app"),"Source matching works before opening certificate settings")
check(!CatalogUpdates.matchesInstalledID("example.app.extension",bundle:"example.app"),"Do not match an arbitrary extension as the parent app")
print("Connection states, expiry reminder plans and source version indicators: passed")

let guestOld=LiveContainerGuest(hostID:"com.kdt.livecontainer.TESTTEAM01",bundleID:"example.app",name:"Example",version:"1.0",buildVersion:"10")
let guestHost=LiveContainerHostInventory(hostID:guestOld.hostID,state:"ready",apps:[guestOld])
let guestsRead=LiveContainerInventory.reconcile(previous:[],hosts:[guestHost],now:reminderNow)
check(guestsRead.count==1 && guestsRead[0].readAt==reminderNow,"Read the installed LiveContainer guest version")
check(LiveContainerInventory.candidates(for:guestsRead[0],sources:[noticeNewSource]).count==1,"An old guest shows an update even if the source cache already contains that version")
var guestNew=guestOld;guestNew.version="1.1";guestNew.buildVersion="11"
let guestRenewed=LiveContainerInventory.reconcile(previous:guestsRead,hosts:[LiveContainerHostInventory(hostID:guestOld.hostID,state:"ready",apps:[guestNew])],now:reminderNow)
check(guestRenewed.count==1 && guestRenewed[0].version=="1.1","A verified complete snapshot replaces the old guest version")
check(LiveContainerInventory.candidates(for:guestRenewed[0],sources:[noticeNewSource]).isEmpty,"Clear the update only after reading the installed new version")
let guestUnavailable=LiveContainerHostInventory(hostID:guestOld.hostID,state:"unavailable",apps:[])
check(LiveContainerInventory.reconcile(previous:guestsRead,hosts:[guestUnavailable],now:reminderNow)==guestsRead,"Failed inventory reads preserve last known data instead of claiming no outdated apps")
check(LiveContainerInventory.reconcile(previous:guestsRead,hosts:[],now:reminderNow).isEmpty,"A verified absent LiveContainer removes its cached inventory")
let twoVersions=LiveContainerHostInventory(hostID:guestOld.hostID,state:"ready",apps:[guestOld,guestNew])
check(LiveContainerInventory.reconcile(previous:[],hosts:[twoVersions],now:reminderNow).count==2,"Keep different installed guest versions separate")
print("LiveContainer installed-version comparison, successful update and failed-read regressions: passed")
