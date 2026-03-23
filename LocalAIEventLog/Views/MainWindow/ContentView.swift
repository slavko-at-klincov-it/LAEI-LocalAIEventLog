import SwiftUI

enum NavItem: Hashable {
    case dashboard
    case activityLog
    case runtime(UUID)
}

struct ContentView: View {
    @Environment(DetectionEngine.self) private var engine
    @State private var selectedNav: NavItem? = .dashboard
    @State private var selectedModel: AIModel?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedNav)
        } content: {
            Group {
                switch selectedNav {
                case .dashboard, .none:
                    DashboardView()
                case .activityLog:
                    ActivityLogView()
                case .runtime(let id):
                    if let runtime = engine.runtimes.first(where: { $0.id == id }) {
                        RuntimeDetailView(runtime: runtime, selectedModel: $selectedModel)
                    } else {
                        Text("Runtime not found")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } detail: {
            if let model = selectedModel {
                ModelDetailView(model: model)
            } else {
                ContentUnavailableView("Select a Model", systemImage: "cpu", description: Text("Choose a model from the list to see details"))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await engine.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
    }
}
