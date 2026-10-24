import Foundation

@main struct AnisetteProbe {
    static func main() async throws {
        guard CommandLine.arguments.count==2 else {throw LocalAnisetteError.message("Runtime path required.")}
        let runtime=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        let temporary=FileManager.default.temporaryDirectory.appendingPathComponent("DirectSide-probe-"+UUID().uuidString,isDirectory:true)
        defer {try? FileManager.default.removeItem(at:temporary)}
        let local=LocalAnisetteService(runtime:runtime,support:temporary,persistent:false)
        let first=try await local.generate()
        let second=try await local.generate()
        guard first.headers["X-Mme-Device-Id"]==second.headers["X-Mme-Device-Id"],
              !(first.headers["X-Apple-I-MD"]?.isEmpty ?? true),
              !(second.headers["X-Apple-I-MD-M"]?.isEmpty ?? true) else {throw LocalAnisetteError.message("Local identity or OTP verification failed.")}
        print("Local TCI provisioning and repeated OTP generation: PASS (no Apple ID; no headers logged)")
    }
}
