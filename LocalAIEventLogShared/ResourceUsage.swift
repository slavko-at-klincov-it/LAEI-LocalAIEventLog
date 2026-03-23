import Foundation

struct ResourceUsage: Codable, Hashable, Sendable {
    var cpuPercent: Double
    var residentMemoryBytes: UInt64
    var virtualMemoryBytes: UInt64
    var gpuMemoryBytes: UInt64?
    var threadCount: Int32
    var timestamp: Date

    static let zero = ResourceUsage(
        cpuPercent: 0,
        residentMemoryBytes: 0,
        virtualMemoryBytes: 0,
        gpuMemoryBytes: nil,
        threadCount: 0,
        timestamp: .now
    )

    var residentMemoryMB: Double {
        Double(residentMemoryBytes) / 1_048_576
    }

    var residentMemoryGB: Double {
        Double(residentMemoryBytes) / 1_073_741_824
    }

    var gpuMemoryMB: Double? {
        gpuMemoryBytes.map { Double($0) / 1_048_576 }
    }
}
