import Foundation
import Darwin

actor ResourceMonitor {
    private var previousCPUSamples: [pid_t: (total: UInt64, timestamp: Date)] = [:]

    func sample(pid: pid_t) -> ResourceUsage {
        guard let taskInfo = LibProcBridge.processTaskInfo(pid: pid) else {
            return .zero
        }

        let totalCPUTime = taskInfo.ptinfo.pti_total_user + taskInfo.ptinfo.pti_total_system
        let now = Date()

        var cpuPercent: Double = 0
        if let previous = previousCPUSamples[pid] {
            let timeDelta = now.timeIntervalSince(previous.timestamp)
            if timeDelta > 0 {
                let cpuDelta = Double(totalCPUTime - previous.total) / 1_000_000_000.0
                let coreCount = Double(ProcessInfo.processInfo.processorCount)
                cpuPercent = (cpuDelta / timeDelta / coreCount) * 100.0
                cpuPercent = max(0, min(cpuPercent, 100.0 * coreCount))
            }
        }
        previousCPUSamples[pid] = (totalCPUTime, now)

        return ResourceUsage(
            cpuPercent: cpuPercent,
            residentMemoryBytes: taskInfo.ptinfo.pti_resident_size,
            virtualMemoryBytes: taskInfo.ptinfo.pti_virtual_size,
            gpuMemoryBytes: nil,
            threadCount: taskInfo.ptinfo.pti_threadnum,
            timestamp: now
        )
    }

    func systemAvailableMemory() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return SysctlBridge.systemMemorySize() / 2 // fallback
        }
        let pageSize = UInt64(getpagesize())
        let free = UInt64(stats.free_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        return free + inactive
    }

    func systemTotalMemory() -> UInt64 {
        SysctlBridge.systemMemorySize()
    }

    func cleanup(activePIDs: Set<pid_t>) {
        for pid in previousCPUSamples.keys {
            if !activePIDs.contains(pid) {
                previousCPUSamples.removeValue(forKey: pid)
            }
        }
    }
}
