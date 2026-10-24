import Foundation
import Security
import CryptoKit
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

/// The same Mac CoreADI build as Windows, interpreted locally without executable memory.
actor LocalAnisetteService {
    static let shared=LocalAnisetteService()
    private static let clientInfo="<MacBookPro13,2> <macOS;13.1;22C65> <com.apple.AuthKit/1 (com.apple.akd/1.0)>"
    private static let agent="akd/1.0 CFNetwork/1404.0.5 Darwin/22.3.0"
    private struct Identity:Codable {
        var host:Data;var device:String;var user:String;var serial:String;var store:Data
    }
    private var identity:Identity?
    private var handle:OpaquePointer?
    private var inFlight:Task<LocalAnisettePayload,Error>?
    private let runtimeOverride:URL?
    private let persistent:Bool
    private var urls:[String:String]=[:]
    private var retryAfter=Date.distantPast
    private lazy var session=URLSession(configuration: {
        let configuration=URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest=15
        configuration.timeoutIntervalForResource=45
        configuration.httpCookieStorage=nil
        configuration.urlCache=nil
        return configuration
    }(),delegate:AppleProvisioningTransport(),delegateQueue:nil)

    init(runtime:URL?=nil,persistent:Bool=true) {
        runtimeOverride=runtime;self.persistent=persistent
    }
    deinit {if let handle {adi_close(handle)}}

    /// Exercise the exact exported-store path used after a real application restart.
    func reloadInterpreter() throws {
        guard inFlight==nil else {throw LocalAnisetteError.message("Local authentication is still running.")}
        try persist()
        if let handle {adi_close(handle)}
        handle=nil
        try prepare()
    }

    func generate() async throws -> LocalAnisettePayload {
        if let inFlight {return try await inFlight.value}
        let task=Task {try await self.makePayload()};inFlight=task
        defer {inFlight=nil}
        return try await task.value
    }
    private func check(_ status:Int32) throws {
        guard status==0 else {
            var message=[CChar](repeating:0,count:512)
            _=adi_last_error(&message,message.count)
            throw LocalAnisetteError.message("Local Mac authentication: "+String(cString:message))
        }
    }
    private static func random(_ count:Int)throws->Data {
        var data=Data(count:count)
        let status=data.withUnsafeMutableBytes {SecRandomCopyBytes(kSecRandomDefault,count,$0.baseAddress!)}
        guard status==errSecSuccess else {throw LocalAnisetteError.message("Secure randomness is unavailable.")}
        return data
    }
    private static func hex(_ data:Data)->String {data.map{String(format:"%02X",$0)}.joined()}
    private func prepare() throws {
        if identity==nil {
            if persistent,let saved=try Self.readIdentity() {
                guard saved.count<=1_048_576 else {throw LocalAnisetteError.message("Local identity exceeds its size limit.")}
                identity=try JSONDecoder().decode(Identity.self,from:saved)
            } else {
                let alphabet=Array("0123456789ABCDEFGHJKLMNPQRSTUVWXYZ")
                identity=Identity(host:try Self.random(16),device:"00006000-"+(try Self.hex(Self.random(8))),user:try Self.hex(Self.random(16)),serial:"C02"+(try Self.random(9)).map{String(alphabet[Int($0)%alphabet.count])}.joined(),store:Data())
                if persistent {try Self.saveIdentity(JSONEncoder().encode(identity!))}
            }
        }
        guard let current=identity,current.host.count==16 else {throw LocalAnisetteError.message("Local identity is invalid.")}
        if handle==nil {
            guard let runtime=runtimeOverride ?? Bundle.main.url(forResource:"MacAnisetteRuntime",withExtension:nil) else {throw LocalAnisetteError.message("The local Mac authentication runtime is missing.")}
            let image=try Data(contentsOf:runtime.appendingPathComponent("CoreADI.mac"))
            guard Self.hex(Data(SHA256.hash(data:image))).lowercased()=="2eafc3c79c7f41a8afbfbeaaf23ee5dab5ad5bda55ec8e54dbc0ddf1d20ce630" else {throw LocalAnisetteError.message("Local authentication runtime checksum mismatch.")}
            var opened:OpaquePointer?
            try image.withUnsafeBytes {try check(adi_open($0.bindMemory(to:UInt8.self).baseAddress,image.count,&opened))}
            guard let opened else {throw LocalAnisetteError.message("Could not open local authentication.")}
            do {
                try current.host.withUnsafeBytes {try check(adi_set_host_uuid(opened,$0.bindMemory(to:UInt8.self).baseAddress))}
                if !current.store.isEmpty {try current.store.withUnsafeBytes {try check(adi_store_import(opened,$0.bindMemory(to:UInt8.self).baseAddress,current.store.count))}}
                handle=opened
            } catch {adi_close(opened);throw error}
        }
    }
    private func bytes(_ value:AdiBuf)throws->Data {
        guard value.len<=1_048_576 else {throw LocalAnisetteError.message("Local authentication response exceeds its size limit.")}
        guard let pointer=value.ptr else {
            if value.len==0 {return Data()}
            throw LocalAnisetteError.message("Invalid local authentication response.")
        }
        return Data(bytes:pointer,count:value.len)
    }
    private func persist() throws {
        guard let handle,var current=identity else {throw LocalAnisetteError.message("Local authentication is unavailable.")}
        var store=AdiBuf(ptr:nil,len:0);defer {adi_buf_free(store)}
        try check(adi_store_export(handle,&store));current.store=try bytes(store)
        if persistent {try Self.saveIdentity(JSONEncoder().encode(current))}
        identity=current
    }
    private func makePayload() async throws -> LocalAnisettePayload {
        try prepare()
        guard let handle,let current=identity else {throw LocalAnisetteError.message("Local authentication is unavailable.")}
        var mid=AdiBuf(ptr:nil,len:0),otp=AdiBuf(ptr:nil,len:0),routing:UInt64=0
        defer {adi_buf_free(mid);adi_buf_free(otp)}
        var status=adi_headers(handle,-2,&mid,&otp,&routing)
        if status == -2 {
            try await provision()
            status=adi_headers(handle,-2,&mid,&otp,&routing)
        }
        try check(status)
        let machine=try bytes(mid),password=try bytes(otp)
        guard !machine.isEmpty,!password.isEmpty else {throw LocalAnisetteError.message("Local authentication returned empty headers.")}
        try persist()
        let date=ISO8601DateFormatter().string(from:Date())
        return LocalAnisettePayload(headers:[
            "X-Apple-I-MD":password.base64EncodedString(),"X-Apple-I-MD-M":machine.base64EncodedString(),
            "X-Apple-I-MD-LU":Data(current.user.utf8).base64EncodedString(),"X-Mme-Device-Id":current.device,
            "X-Apple-I-MD-RINFO":String(routing),"X-Apple-I-SRL-NO":current.serial,
            "X-Apple-I-Client-Time":date,"X-Apple-I-TimeZone":"UTC","X-Apple-Locale":"en_US"
        ],client_info:Self.clientInfo,user_agent:Self.agent)
    }
    private func request(_ address:String,body:[String:Any]?=nil) async throws -> [String:Any] {
        guard Date()>=retryAfter else {throw LocalAnisetteError.message("Apple requested a cooldown. Try again later.")}
        guard let url=URL(string:address),AppleProvisioningTransport.allowed(url),let current=identity else {throw LocalAnisetteError.message("Invalid Apple provisioning endpoint.")}
        var request=URLRequest(url:url)
        request.setValue(Self.agent,forHTTPHeaderField:"User-Agent")
        request.setValue(Self.clientInfo,forHTTPHeaderField:"X-MMe-Client-Info")
        request.setValue(current.device,forHTTPHeaderField:"X-Mme-Device-Id")
        request.setValue(current.user,forHTTPHeaderField:"X-Apple-I-MD-LU")
        request.setValue(current.serial,forHTTPHeaderField:"X-Apple-I-SRL-NO")
        request.setValue("Setup",forHTTPHeaderField:"X-Apple-Client-App-Name")
        request.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type")
        if let body {
            request.httpMethod="POST"
            request.httpBody=try PropertyListSerialization.data(fromPropertyList:["Header":[:],"Request":body],format:.xml,options:0)
            request.setValue(ISO8601DateFormatter().string(from:Date()),forHTTPHeaderField:"X-Apple-I-Client-Time")
        }
        let (data,response)=try await session.data(for:request)
        guard let http=response as? HTTPURLResponse else {throw LocalAnisetteError.message("Invalid Apple provisioning response.")}
        if http.statusCode==429 {retryAfter=Date().addingTimeInterval(300)}
        guard http.statusCode==200 else {throw LocalAnisetteError.message("Apple provisioning failed (HTTP \(http.statusCode)).")}
        guard data.count<=1_048_576,let plist=try PropertyListSerialization.propertyList(from:data,format:nil) as? [String:Any] else {throw LocalAnisetteError.message("Invalid Apple provisioning data.")}
        return plist
    }
    private func loadBag() async throws {
        if urls.isEmpty {
            let bag=try await request("https://gsa.apple.com/grandslam/GsService2/lookup")
            guard let found=bag["urls"] as? [String:String] else {throw LocalAnisetteError.message("Apple provisioning URL bag is missing.")}
            urls=found
        }
    }
    private func post(_ name:String,_ body:[String:Any]) async throws -> [String:Any] {
        try await loadBag()
        guard let address=urls[name] else {throw LocalAnisetteError.message("Apple provisioning endpoint is missing: "+name)}
        let raw=try await request(address,body:body)
        guard let response=raw["Response"] as? [String:Any] else {throw LocalAnisetteError.message("Apple provisioning response is missing.")}
        if let status=response["Status"] as? [String:Any],let code=status["ec"] as? NSNumber,code.intValue != 0 {throw LocalAnisetteError.message("Apple provisioning rejected the request (code \(code.intValue)).")}
        return response
    }
    private func field(_ key:String,_ response:[String:Any]) throws -> Data {
        guard let string=response[key] as? String,let data=Data(base64Encoded:string),!data.isEmpty,data.count<=65536 else {throw LocalAnisetteError.message("Apple provisioning field is missing: "+key)}
        return data
    }
    private func provision() async throws {
        guard let handle else {throw LocalAnisetteError.message("Local authentication is unavailable.")}
        let started=try await post("midStartProvisioning",[:]);let spim=try field("spim",started)
        var cpim=AdiBuf(ptr:nil,len:0),sessionID:UInt32=0;defer {adi_buf_free(cpim)}
        try spim.withUnsafeBytes {try check(adi_provisioning_begin(handle,-2,$0.bindMemory(to:UInt8.self).baseAddress,spim.count,&cpim,&sessionID))}
        let finished=try await post("midFinishProvisioning",["cpim":try bytes(cpim).base64EncodedString()])
        let ptm=try field("ptm",finished),tk=try field("tk",finished)
        let routing=(finished["X-Apple-I-MD-RINFO"] as? NSNumber)?.uint64Value ?? UInt64(finished["X-Apple-I-MD-RINFO"] as? String ?? "") ?? 0
        guard routing>0 else {throw LocalAnisetteError.message("Apple provisioning routing information is missing.")}
        try ptm.withUnsafeBytes {p in try tk.withUnsafeBytes {t in
            try check(adi_provisioning_finish(handle,-2,sessionID,p.bindMemory(to:UInt8.self).baseAddress,ptm.count,t.bindMemory(to:UInt8.self).baseAddress,tk.count,routing))
        }}
        try persist()
    }
    func resync(_ encoded:String) async throws -> LocalAnisettePayload {
        if let inFlight {_=try await inFlight.value}
        try prepare()
        guard let handle,let sim=Data(base64Encoded:encoded),!sim.isEmpty,sim.count<=65536 else {throw LocalAnisetteError.message("Invalid local authentication synchronization request.")}
        var mid=AdiBuf(ptr:nil,len:0),srm=AdiBuf(ptr:nil,len:0);defer {adi_buf_free(mid);adi_buf_free(srm)}
        try sim.withUnsafeBytes {try check(adi_sync(handle,-2,$0.bindMemory(to:UInt8.self).baseAddress,sim.count,&mid,&srm))}
        let response=try await post("midSyncMachine",["srm":try bytes(srm).base64EncodedString(),"X-Apple-I-MD-M":try bytes(mid).base64EncodedString()])
        if let number=response["X-Apple-I-MD-RINFO"] as? NSNumber {try check(adi_update_routing(handle,-2,number.uint64Value))}
        try persist()
        return try await generate()
    }
    private static var query:[String:Any] {[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.directside.local-mac-anisette",kSecAttrAccount as String:"identity"]}
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

private final class AppleProvisioningTransport:NSObject,URLSessionDelegate,URLSessionTaskDelegate,@unchecked Sendable {
    static func allowed(_ url:URL)->Bool {
        guard url.scheme=="https",let host=url.host,url.user==nil,url.password==nil,url.port==nil || url.port==443 else {return false}
        return host=="apple.com" || host.hasSuffix(".apple.com")
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void) {
        completionHandler(request.url.map{Self.allowed($0)} == true ? request:nil)
    }
    func urlSession(_ session:URLSession,didReceive challenge:URLAuthenticationChallenge,completionHandler:@escaping(URLSession.AuthChallengeDisposition,URLCredential?)->Void) {
        guard challenge.protectionSpace.authenticationMethod==NSURLAuthenticationMethodServerTrust,
              let trust=challenge.protectionSpace.serverTrust,
              let url=URL(string:"https://"+challenge.protectionSpace.host),Self.allowed(url) else {completionHandler(.cancelAuthenticationChallenge,nil);return}
        if let path=Bundle.main.url(forResource:"apple_root",withExtension:"cer"),let data=try? Data(contentsOf:path),let root=SecCertificateCreateWithData(nil,data as CFData) {
            SecTrustSetAnchorCertificates(trust,[root] as CFArray)
            SecTrustSetAnchorCertificatesOnly(trust,false)
        }
        if SecTrustEvaluateWithError(trust,nil) {completionHandler(.useCredential,URLCredential(trust:trust))}
        else {completionHandler(.cancelAuthenticationChallenge,nil)}
    }
}

private final class AnisetteResultBox: @unchecked Sendable {
    var value="{\"error\":\"Local authentication did not complete.\"}"
}

private func blockingAnisette(_ sim:String?=nil)->UnsafeMutablePointer<CChar>? {
    guard !Thread.isMainThread else {return strdup("{\"error\":\"Local authentication cannot block the main thread.\"}")}
    let box=AnisetteResultBox();let signal=DispatchSemaphore(value:0)
    Task.detached {
        do {
            let payload:LocalAnisettePayload
            if let sim {payload=try await LocalAnisetteService.shared.resync(sim)}
            else {payload=try await LocalAnisetteService.shared.generate()}
            let bytes=try JSONEncoder().encode(payload);box.value=String(decoding:bytes,as:UTF8.self)
        } catch {
            let bytes=(try? JSONSerialization.data(withJSONObject:["error":error.localizedDescription])) ?? Data()
            box.value=String(decoding:bytes,as:UTF8.self)
        }
        signal.signal()
    }
    if signal.wait(timeout:.now()+180) != .success {return strdup("{\"error\":\"Local authentication timed out.\"}")}
    return box.value.withCString {strdup($0)}
}
@_cdecl("ds_swift_anisette_generate")
func ds_swift_anisette_generate()->UnsafeMutablePointer<CChar>? {blockingAnisette()}
@_cdecl("ds_swift_anisette_resync")
func ds_swift_anisette_resync(_ value:UnsafePointer<CChar>?)->UnsafeMutablePointer<CChar>? {
    guard let value else {return strdup("{\"error\":\"Missing synchronization request.\"}")}
    return blockingAnisette(String(cString:value))
}
@_cdecl("ds_swift_anisette_release")
func ds_swift_anisette_release(_ pointer:UnsafeMutablePointer<CChar>?) {free(pointer)}
