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
    let assetID:Int
    let size:Int
    let sha256:String
}

