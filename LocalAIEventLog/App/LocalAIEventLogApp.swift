import SwiftUI
import SwiftData

@main
struct LocalAIEventLogApp: App {
    @State private var engine: DetectionEngine
    @State private var eventStore: EventStore
    @State private var alertManager = AlertManager()

    init() {
        let store = EventStore()
        let detectionEngine = DetectionEngine(eventStore: store)
        _engine = State(initialValue: detectionEngine)
        _eventStore = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup("Local AI Event Log", id: "main") {
            ContentView()
                .environment(engine)
                .environment(alertManager)
                .modelContainer(eventStore.modelContainer)
                .frame(minWidth: 700, minHeight: 450)
                .onAppear {
                    engine.start()
                    alertManager.requestPermission()
                    engine.onEvent = { event in
                        handleEvent(event)
                    }
                }
        }
        .defaultSize(width: 900, height: 600)

        MenuBarExtra {
            MenuBarView()
                .environment(engine)
        } label: {
            MenuBarLabel(isActive: engine.appState.anyActive, modelCount: engine.appState.activeModelCount)
        }
        .menuBarExtraStyle(.window)

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(alertManager)
        }
        #endif
    }

    private func handleEvent(_ event: DetectionEvent) {
        switch event {
        case .runtimeAppeared(let runtime):
            alertManager.notifyRuntimeAppeared(runtime)
            alertManager.checkThresholds(appState: engine.appState)
        case .modelLoaded(let runtime, let model):
            alertManager.notifyModelLoaded(model: model, runtime: runtime)
        default:
            break
        }

        // Write to widget
        SharedStateWriter.write(engine.appState)
    }
}
