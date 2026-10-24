import Foundation

struct SourceCatalog: Codable, Identifiable {
    var name: String
    var identifier: String?
    var subtitle: String?
    var description: String?
    var iconURL: URL?
    var headerURL: URL?
    var website: URL?
    var tintColor: String?
    var featuredApps: [String]?
    var news: [SourceNews]?
    var apps: [CatalogApp]
    var sourceURL: URL?
    var refreshedAt: Date?
    var id: String { sourceURL?.absoluteString ?? identifier ?? name }
}

struct CatalogApp: Codable, Identifiable {
    var name: String
    var bundleIdentifier: String
    var developerName: String?
    var subtitle: String?
    var localizedDescription: String?
    var iconURL: URL?
    var tintColor: String?
    var category: String?
    var screenshots: AppScreenshots?
    var appPermissions: AppPermissions?
    var versions: [CatalogVersion]?
    var version: String?
    var downloadURL: URL?
    var id: String { bundleIdentifier }
    var latest: CatalogVersion? {
        versions?.first(where: { $0.beta != true && $0.isCompatible }) ?? downloadURL.map { CatalogVersion(version: version ?? "?", downloadURL: $0, beta: false) }
    }
}

struct CatalogVersion: Codable {
    var version: String
    var downloadURL: URL
    var beta: Bool?
    var buildVersion: String?
    var marketingVersion: String?
    var date: String?
    var localizedDescription: String?
    var size: Int64?
    var minOSVersion: String?
    var maxOSVersion: String?
    var displayVersion: String { marketingVersion ?? version + (buildVersion.map { " (\($0))" } ?? "") }
    var isCompatible: Bool {
        let os=ProcessInfo.processInfo.operatingSystemVersion
        let current="\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        if let minOSVersion, current.compare(minOSVersion,options:.numeric) == .orderedAscending { return false }
        if let maxOSVersion, current.compare(maxOSVersion,options:.numeric) == .orderedDescending { return false }
        return true
    }
}

struct ManagedApp: Codable, Identifiable {
    var id: String
    var name: String
    var cachedIPA: String
    var installedAt: Date
    var version: String?
    var buildVersion: String?
    var sourceID: String?
    var iconURL: URL?
    var expiresAt: Date?
}

struct SourceNews: Codable,Identifiable {
    var title:String
    var identifier:String
    var caption:String?
    var date:String?
    var imageURL:URL?
    var url:URL?
    var appID:String?
    var id:String { identifier }
}

struct AppScreenshot: Codable,Identifiable {
    var imageURL:URL
    var width:Double?
    var height:Double?
    var id:String { imageURL.absoluteString }
    var aspectRatio:Double { guard let width,let height,height>0 else { return 393/852 }; return width/height }
    init(from decoder:Decoder) throws {
        let c=try decoder.singleValueContainer()
        if let raw=try? c.decode(String.self),let url=URL(string:raw) { imageURL=url;return }
        let o=try decoder.container(keyedBy:Keys.self)
        imageURL=try o.decode(URL.self,forKey:.imageURL); width=try o.decodeIfPresent(Double.self,forKey:.width); height=try o.decodeIfPresent(Double.self,forKey:.height)
    }
    enum Keys:String,CodingKey { case imageURL,width,height }
}
struct AppScreenshots: Codable {
    var iphone:[AppScreenshot]=[]
    var ipad:[AppScreenshot]=[]
    var all:[AppScreenshot] { iphone.isEmpty ? ipad:iphone }
    init(from decoder:Decoder) throws {
        let c=try decoder.singleValueContainer()
        if let flat=try? c.decode([AppScreenshot].self) { iphone=flat;return }
        let o=try decoder.container(keyedBy:Keys.self)
        iphone=try o.decodeIfPresent([AppScreenshot].self,forKey:.iphone) ?? []
        ipad=try o.decodeIfPresent([AppScreenshot].self,forKey:.ipad) ?? []
    }
    enum Keys:String,CodingKey { case iphone,ipad }
}
struct AppPermissions: Codable {
    var privacy:[String:String]?
    var entitlements:[String]?
    init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:Keys.self)
        privacy=(try? c.decode([String:String].self,forKey:.privacy)) ?? [:]
        entitlements=(try? c.decode([String].self,forKey:.entitlements)) ?? []
    }
    enum Keys:String,CodingKey { case privacy,entitlements }
}

struct Bootstrap: Codable { let udid: String; let name: String }

enum DirectSideError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let message) = self { return message }; return nil }
}

enum Paths {
    static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static var support: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DirectSide", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static var pairing: URL { support.appendingPathComponent("pairing.plist") }
    static var bootstrap: URL { support.appendingPathComponent("bootstrap.json") }
    static var original: URL { support.appendingPathComponent("DirectSide-original.ipa") }
    static var signing: URL { support.appendingPathComponent("signing-import.json") }
    static func importBootstrap() throws {
        for (source, target) in [("DirectSide-pairing.plist",pairing),("DirectSide-bootstrap.json",bootstrap),("DirectSide-original.ipa",original),("DirectSide-signing.json",signing)] {
            let from = documents.appendingPathComponent(source)
            guard FileManager.default.fileExists(atPath: from.path) else { continue }
            let bytes = try Data(contentsOf: from)
            try bytes.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            try FileManager.default.removeItem(at: from)
        }
    }
}

enum SourceURL {
    static func parse(_ raw: String) throws -> URL {
        guard let components = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw DirectSideError.message("Ungültige Quellen-Adresse.") }
        if ["directside", "altstore", "sidestore"].contains(components.scheme?.lowercased() ?? ""),
           let wrapped = components.queryItems?.first(where: { $0.name == "url" })?.value {
            return try parse(wrapped)
        }
        guard components.scheme?.lowercased() == "https", components.host != nil,
              components.user == nil, components.password == nil, let url = components.url else {
            throw DirectSideError.message("Bitte eine HTTPS-Adresse für die Quelle verwenden.")
        }
        return url
    }
}
