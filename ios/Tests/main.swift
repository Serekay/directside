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
