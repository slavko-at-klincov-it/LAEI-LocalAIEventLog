import Foundation

actor ProcessScanner {
    func scan() -> [DetectedProcess] {
        let pids = LibProcBridge.listAllPIDs()
        var results: [DetectedProcess] = []

        for pid in pids {
            guard let procInfo = LibProcBridge.getProcessInfo(pid: pid) else { continue }
            guard let signature = ProcessSignatureDB.match(processInfo: procInfo) else { continue }

            results.append(DetectedProcess(
                pid: pid,
                runtimeType: signature.runtime,
                processName: procInfo.name,
                processPath: procInfo.path,
                arguments: procInfo.arguments,
                defaultPort: signature.defaultPort
            ))
        }

        return results
    }
}

struct DetectedProcess: Sendable {
    let pid: pid_t
    let runtimeType: RuntimeType
    let processName: String
    let processPath: String
    let arguments: [String]
    let defaultPort: UInt16?
}
