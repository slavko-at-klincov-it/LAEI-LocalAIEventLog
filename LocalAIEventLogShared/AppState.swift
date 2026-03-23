import Foundation

struct AppState: Codable, Sendable {
    var runtimes: [AIRuntime]
    var totalCPU: Double
    var totalRAMBytes: UInt64
    var anyActive: Bool
    var activeModelCount: Int
    var systemAvailableMemoryBytes: UInt64
    var systemTotalMemoryBytes: UInt64
    var lastUpdated: Date

    static let empty = AppState(
        runtimes: [],
        totalCPU: 0,
        totalRAMBytes: 0,
        anyActive: false,
        activeModelCount: 0,
        systemAvailableMemoryBytes: 0,
        systemTotalMemoryBytes: 0,
        lastUpdated: .now
    )

    var totalRAMGB: Double {
        Double(totalRAMBytes) / 1_073_741_824
    }

    var systemTotalMemoryGB: Double {
        Double(systemTotalMemoryBytes) / 1_073_741_824
    }

    var memoryPressurePercent: Double {
        guard systemTotalMemoryBytes > 0 else { return 0 }
        let used = systemTotalMemoryBytes - systemAvailableMemoryBytes
        return Double(used) / Double(systemTotalMemoryBytes) * 100
    }
}
