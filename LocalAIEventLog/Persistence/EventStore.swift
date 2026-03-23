import Foundation
import SwiftData

@MainActor
final class EventStore {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([EventRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    func log(runtimeType: RuntimeType, modelName: String, event: ActivityEvent, ramBytes: UInt64 = 0, cpu: Double = 0) {
        let record = EventRecord(
            runtimeType: runtimeType,
            modelName: modelName,
            event: event,
            ramBytes: ramBytes,
            cpu: cpu
        )
        modelContainer.mainContext.insert(record)
        try? modelContainer.mainContext.save()
    }

    func recentEvents(limit: Int = 50) -> [EventRecord] {
        let descriptor = FetchDescriptor<EventRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        var limitedDescriptor = descriptor
        limitedDescriptor.fetchLimit = limit
        return (try? modelContainer.mainContext.fetch(limitedDescriptor)) ?? []
    }

    func allEvents() -> [EventRecord] {
        let descriptor = FetchDescriptor<EventRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? modelContainer.mainContext.fetch(descriptor)) ?? []
    }
}
