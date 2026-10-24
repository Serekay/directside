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
for invalid in ["file:///private/test", "http://example.com/source.json","https://user:pass@example.com/source.json"] {
    do {_=try SourceURL.parse(invalid);fatalError("Accepted invalid source URL")} catch {}
}
let roundtrip=try JSONDecoder().decode(SourceCatalog.self,from:JSONEncoder().encode(source))
check(roundtrip.apps.count==1,"Persist sources")
print("Source decoding, screenshots, version order, URL validation and persistence: passed")
