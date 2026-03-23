import SwiftUI
import SwiftData

struct ActivityLogView: View {
    @Query(sort: \EventRecord.timestamp, order: .reverse)
    private var events: [EventRecord]

    @State private var filterEvent: String = "all"

    private var filteredEvents: [EventRecord] {
        if filterEvent == "all" { return events }
        return events.filter { $0.event == filterEvent }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Activity Log")
                    .font(.title2.bold())
                Spacer()
                Picker("Filter", selection: $filterEvent) {
                    Text("All Events").tag("all")
                    Text("Model Loaded").tag(ActivityEvent.modelLoaded.rawValue)
                    Text("Model Unloaded").tag(ActivityEvent.modelUnloaded.rawValue)
                    Text("Runtime Started").tag(ActivityEvent.runtimeStarted.rawValue)
                    Text("Runtime Stopped").tag(ActivityEvent.runtimeStopped.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
            }
            .padding()

            if filteredEvents.isEmpty {
                ContentUnavailableView(
                    "No Events",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Activity events will appear here as AI models start and stop")
                )
            } else {
                Table(filteredEvents) {
                    TableColumn("Time") { event in
                        Text(event.timestamp.formatted(.dateTime.month().day().hour().minute().second()))
                            .font(.caption.monospacedDigit())
                    }
                    .width(min: 120, ideal: 160)

                    TableColumn("Event") { event in
                        EventBadge(event: event.activityEvent ?? .runtimeStarted)
                    }
                    .width(min: 100, ideal: 130)

                    TableColumn("Model") { event in
                        Text(event.modelName)
                            .lineLimit(1)
                    }
                    .width(min: 120, ideal: 200)

                    TableColumn("Runtime") { event in
                        Text(event.runtime?.displayName ?? event.runtimeType)
                    }
                    .width(min: 80, ideal: 120)

                    TableColumn("RAM") { event in
                        if event.ramBytesAtEvent > 0 {
                            Text(LAEIFormatters.memoryString(bytes: event.ramBytesAtEvent))
                                .font(.caption.monospacedDigit())
                        } else {
                            Text("-")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .width(min: 60, ideal: 80)
                }
            }
        }
    }
}

struct EventBadge: View {
    let event: ActivityEvent

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(badgeColor)
                .frame(width: 6, height: 6)
            Text(badgeText)
                .font(.caption)
        }
    }

    private var badgeColor: Color {
        switch event {
        case .runtimeStarted, .modelLoaded: .green
        case .runtimeStopped, .modelUnloaded: .red
        case .memoryThresholdExceeded: .orange
        }
    }

    private var badgeText: String {
        switch event {
        case .runtimeStarted: "Started"
        case .runtimeStopped: "Stopped"
        case .modelLoaded: "Loaded"
        case .modelUnloaded: "Unloaded"
        case .memoryThresholdExceeded: "Memory Alert"
        }
    }
}
