import Foundation

enum LAEIFormatters {
    static func memoryString(bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    static func memoryString(bytes: Int64) -> String {
        memoryString(bytes: UInt64(max(0, bytes)))
    }

    static func cpuString(_ percent: Double) -> String {
        String(format: "%.0f%%", percent)
    }

    static func shortTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().second())
    }

    static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
