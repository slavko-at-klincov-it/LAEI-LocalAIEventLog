import Foundation
import SwiftData

enum ActivityEvent: String, Codable, Sendable {
    case runtimeStarted
    case runtimeStopped
    case modelLoaded
    case modelUnloaded
    case memoryThresholdExceeded
}

@Model
final class EventRecord {
    var id: UUID
    var runtimeType: String
    var modelName: String
    var event: String
    var timestamp: Date
    var ramBytesAtEvent: UInt64
    var cpuAtEvent: Double

    init(
        runtimeType: RuntimeType,
        modelName: String,
        event: ActivityEvent,
        ramBytes: UInt64 = 0,
        cpu: Double = 0,
        timestamp: Date = .now
    ) {
        self.id = UUID()
        self.runtimeType = runtimeType.rawValue
        self.modelName = modelName
        self.event = event.rawValue
        self.timestamp = timestamp
        self.ramBytesAtEvent = ramBytes
        self.cpuAtEvent = cpu
    }

    var activityEvent: ActivityEvent? {
        ActivityEvent(rawValue: event)
    }

    var runtime: RuntimeType? {
        RuntimeType(rawValue: runtimeType)
    }
}
