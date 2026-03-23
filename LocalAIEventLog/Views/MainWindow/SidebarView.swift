import SwiftUI

struct SidebarView: View {
    @Environment(DetectionEngine.self) private var engine
    @Binding var selection: NavItem?

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Dashboard", systemImage: "gauge.medium")
                    .tag(NavItem.dashboard)
                Label("Activity Log", systemImage: "clock.arrow.circlepath")
                    .tag(NavItem.activityLog)
            }

            Section("Runtimes (\(engine.runtimes.count))") {
                if engine.runtimes.isEmpty {
                    Text("No AI runtimes detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(engine.runtimes) { runtime in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(runtime.isResponding ? .green : .gray)
                                .frame(width: 8, height: 8)
                            Image(systemName: runtime.type.iconSystemName)
                                .frame(width: 16)
                                .foregroundStyle(runtime.isResponding ? .primary : .secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(runtime.type.displayName)
                                    .font(.body.bold())
                                Text("\(runtime.loadedModels.count) model\(runtime.loadedModels.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(NavItem.runtime(runtime.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
    }
}
