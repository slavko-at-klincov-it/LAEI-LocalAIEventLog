import Foundation
import Darwin

struct ProcessInfo_LP: Sendable {
    let pid: pid_t
    let name: String
    let path: String
    let arguments: [String]
}

enum LibProcBridge {
    static func listAllPIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(count))
        let actualCount = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * Int(count)))
        guard actualCount > 0 else { return [] }

        return Array(pids.prefix(Int(actualCount)))
    }

    static func processName(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXCOMLEN + 1))
        let result = proc_name(pid, &buffer, UInt32(buffer.count))
        guard result > 0 else { return nil }
        let end = buffer.firstIndex(of: 0) ?? buffer.endIndex
        return String(decoding: buffer[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    static func processPath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let result = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard result > 0 else { return nil }
        let end = buffer.firstIndex(of: 0) ?? buffer.endIndex
        return String(decoding: buffer[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    static func processTaskInfo(pid: pid_t) -> proc_taskallinfo? {
        var info = proc_taskallinfo()
        let size = MemoryLayout<proc_taskallinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, Int32(size))
        guard result == Int32(size) else { return nil }
        return info
    }

    static func getProcessInfo(pid: pid_t) -> ProcessInfo_LP? {
        guard let name = processName(pid: pid) else { return nil }
        let path = processPath(pid: pid) ?? ""
        let args = SysctlBridge.processArguments(pid: pid) ?? []
        return ProcessInfo_LP(pid: pid, name: name, path: path, arguments: args)
    }
}
