import Foundation

@main struct AnisetteProbe {
    static func main() async throws {
        guard CommandLine.arguments.count==2 else {throw LocalAnisetteError.message("Runtime path required.")}
        let runtime=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        let local=LocalAnisetteService(runtime:runtime,persistent:false)
        let first=try await local.generate()
        try await local.reloadInterpreter()
        let second=try await local.generate()
        guard first.headers["X-Mme-Device-Id"]==second.headers["X-Mme-Device-Id"],
              !(first.headers["X-Apple-I-MD"]?.isEmpty ?? true),
              !(second.headers["X-Apple-I-MD-M"]?.isEmpty ?? true) else {throw LocalAnisetteError.message("Local identity or OTP verification failed.")}
        print("Local Mac TCI provisioning, store restoration and repeated OTP generation: PASS (no Apple ID; no headers logged)")
    }
}
