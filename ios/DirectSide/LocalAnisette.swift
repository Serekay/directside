import Foundation
import Security
import AnisetteKit
import Darwin

struct LocalAnisettePayload: Codable, Sendable {
    let headers: [String:String]
    let client_info: String
    let user_agent: String
}

enum LocalAnisetteError: LocalizedError {
    case message(String)
    var errorDescription:String? {if case .message(let value)=self{return value};return nil}
}

/// A local interpreter, bundled Apple libraries and a device-bound keychain identity.
/// No remoteODA metadata, remote provider or runtime library download is used.
actor LocalAnisetteService {
    static let shared=LocalAnisetteService()
    private struct Identity:Codable {var identifier:UUID;var blob:Data?;var routing:String?}
    private var identity:Identity?
    private var client:AnisetteClient?
    private var inFlight:Task<LocalAnisettePayload,Error>?
    private let runtimeOverride:URL?
    private let supportOverride:URL?
    private let persistent:Bool

    init(runtime:URL?=nil,support:URL?=nil,persistent:Bool=true) {
        runtimeOverride=runtime;supportOverride=support;self.persistent=persistent
    }
    func generate() async throws -> LocalAnisettePayload {
        if let inFlight {return try await inFlight.value}
        let task=Task {try await self.makePayload()};inFlight=task
        defer {inFlight=nil}
        return try await task.value
    }
    private func makePayload() async throws -> LocalAnisettePayload {
        AnisetteKitLogging.setLogging(false)
        let support=supportOverride ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("DirectSide/LocalAnisette",isDirectory:true)
        try FileManager.default.createDirectory(at:support,withIntermediateDirectories:true)
        var resourceValues=URLResourceValues();resourceValues.isExcludedFromBackup=true
        var protectedSupport=support;try protectedSupport.setResourceValues(resourceValues)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:support.path)
        #endif
        if identity==nil {
            if persistent,let saved=try Self.readIdentity() {identity=try JSONDecoder().decode(Identity.self,from:saved)}
            else {identity=Identity(identifier:UUID(),blob:nil,routing:nil)}
        }
        guard var current=identity else {throw LocalAnisetteError.message("Local authentication identity is unavailable.")}
        if client==nil {
            guard let runtime=runtimeOverride ?? Bundle.main.url(forResource:"AnisetteRuntime",withExtension:nil) else {throw LocalAnisetteError.message("The bundled local authentication runtime is missing.")}
            client=try AnisetteClient(provisioningDir:support,provider:UnicornAnisetteDataProvider(),libraryDirectoryResolver:{runtime})
        }
        guard let client else {throw LocalAnisetteError.message("Could not start local authentication.")}
        var overrides=AnisetteRequestHeaders()
        overrides.deviceID=current.identifier.uuidString.uppercased()
        overrides.routingInfo=current.routing
        let (headers,newBlob)=try await client.getAnisetteData(identifier:current.identifier,storage:.memory(existingBlob:current.blob),headers:overrides)
        for key in ["X-Apple-I-MD","X-Apple-I-MD-M","X-Mme-Device-Id","X-Apple-I-MD-LU","X-Apple-I-MD-RINFO"] {
            guard let value=headers[key],!value.isEmpty else {throw LocalAnisetteError.message("The local generator returned incomplete authentication data.")}
        }
        if let newBlob {current.blob=newBlob}
        current.routing=headers["X-Apple-I-MD-RINFO"]
        if persistent {try Self.saveIdentity(JSONEncoder().encode(current))}
        identity=current
        return LocalAnisettePayload(headers:headers,client_info:client.clientInfo,user_agent:client.userAgent)
    }
    private static var query:[String:Any] {[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.directside.local-anisette",kSecAttrAccount as String:"identity"]}
    private static func readIdentity() throws -> Data? {
        var request=query;request[kSecReturnData as String]=true
        var result:CFTypeRef?
        let status=SecItemCopyMatching(request as CFDictionary,&result)
        if status==errSecItemNotFound{return nil}
        guard status==errSecSuccess,let bytes=result as? Data else {throw LocalAnisetteError.message("Unlock the device to access local authentication.")}
        return bytes
    }
    private static func saveIdentity(_ bytes:Data) throws {
        let status=SecItemUpdate(query as CFDictionary,[kSecValueData as String:bytes] as CFDictionary)
        if status==errSecItemNotFound {
            var item=query;item[kSecValueData as String]=bytes;item[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary,nil)==errSecSuccess else {throw LocalAnisetteError.message("Could not save the local authentication identity.")}
        } else if status != errSecSuccess {throw LocalAnisetteError.message("Could not update the local authentication identity.")}
    }
}

private final class AnisetteResultBox: @unchecked Sendable {
    var value="{\"error\":\"Local authentication did not complete.\"}"
}

/// Called only from the Rust blocking worker, never from the UI thread.
@_cdecl("ds_swift_anisette_generate")
func ds_swift_anisette_generate()->UnsafeMutablePointer<CChar>? {
    guard !Thread.isMainThread else {return strdup("{\"error\":\"Local authentication cannot block the main thread.\"}")}
    let box=AnisetteResultBox();let signal=DispatchSemaphore(value:0)
    Task.detached {
        do {
            let payload=try await LocalAnisetteService.shared.generate()
            let bytes=try JSONEncoder().encode(payload)
            box.value=String(decoding:bytes,as:UTF8.self)
        } catch {
            let bytes=(try? JSONSerialization.data(withJSONObject:["error":error.localizedDescription])) ?? Data()
            box.value=String(decoding:bytes,as:UTF8.self)
        }
        signal.signal()
    }
    // The task retains its result box on timeout; it never writes to freed memory.
    if signal.wait(timeout:.now()+180) != .success {return strdup("{\"error\":\"Local authentication timed out.\"}")}
    return box.value.withCString {strdup($0)}
}

@_cdecl("ds_swift_anisette_release")
func ds_swift_anisette_release(_ pointer:UnsafeMutablePointer<CChar>?) {free(pointer)}
