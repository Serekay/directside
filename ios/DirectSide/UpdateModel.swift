import Foundation

enum UpdateVersion {
    static func parts(_ value:String)->[Int]? {
        let value=value.hasPrefix("v") ? String(value.dropFirst()):value
        let parts=value.split(separator:".",omittingEmptySubsequences:false)
        guard parts.count==3,parts.allSatisfy({!$0.isEmpty && $0.allSatisfy(\.isNumber)}),parts.allSatisfy({Int($0) != nil}) else {return nil}
        return parts.compactMap{Int($0)}
    }
    static func newer(_ candidate:String,than installed:String)->Bool {
        guard let candidate=parts(candidate),let installed=parts(installed) else {return false}
        return installed.lexicographicallyPrecedes(candidate)
    }
}

struct AppRelease:Identifiable {
    var id:String {version}
    let version:String
    let notes:String
    let downloadURL:URL
    let size:Int
    let sha256:String
    static func decode(_ metadata:[String:Any],installed:String) throws -> AppRelease? {
        guard metadata["draft"] as? Bool==false,metadata["prerelease"] as? Bool==false,let tag=metadata["tag_name"] as? String,UpdateVersion.parts(tag) != nil else {throw DirectSideError.message("Ungültige Updateantwort.")}
        guard UpdateVersion.newer(tag,than:installed) else {return nil}
        let expected="https://github.com/Serekay/directside/releases/download/\(tag)/DirectSide.ipa"
        guard let assets=metadata["assets"] as? [[String:Any]],let asset=assets.first(where:{$0["name"] as? String=="DirectSide.ipa"}),asset["state"] as? String=="uploaded",let size=asset["size"] as? Int,size>0,size<=500*1024*1024,asset["browser_download_url"] as? String==expected,let url=URL(string:expected),let digest=asset["digest"] as? String,digest.range(of:"^sha256:[a-fA-F0-9]{64}$",options:.regularExpression) != nil else {throw DirectSideError.message("Das iPhone-Update ist noch nicht vollständig veröffentlicht.")}
        return AppRelease(version:tag.hasPrefix("v") ? String(tag.dropFirst()):tag,notes:metadata["body"] as? String ?? "",downloadURL:url,size:size,sha256:String(digest.dropFirst(7)).lowercased())
    }
}

