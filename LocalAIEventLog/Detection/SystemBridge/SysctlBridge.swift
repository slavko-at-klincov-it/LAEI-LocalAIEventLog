import Foundation
import Darwin

enum SysctlBridge {
    static func processArguments(pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: Int = 0

        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }

        // First 4 bytes = argc
        guard size > MemoryLayout<Int32>.size else { return nil }
        let argc: Int32 = buffer.withUnsafeBufferPointer { buf in
            buf.baseAddress!.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
        }
        guard argc > 0, argc < 256 else { return nil }

        // Skip argc (4 bytes), then the executable path (null-terminated)
        var offset = MemoryLayout<Int32>.size

        // Skip executable path
        while offset < size, buffer[offset] != 0 { offset += 1 }
        // Skip null terminators after path
        while offset < size, buffer[offset] == 0 { offset += 1 }

        // Parse argv strings
        var args: [String] = []
        var current = ""
        for i in offset..<size {
            if buffer[i] == 0 {
                if !current.isEmpty {
                    args.append(current)
                    if args.count >= argc { break }
                }
                current = ""
            } else {
                current.append(Character(UnicodeScalar(buffer[i])))
            }
        }

        return args.isEmpty ? nil : args
    }

    static func systemMemorySize() -> UInt64 {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &size, &len, nil, 0)
        return size
    }
}
