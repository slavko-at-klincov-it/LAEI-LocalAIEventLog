import SwiftUI

struct LargeWidgetView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Image(systemName: "brain.filled.head.profile")
                    .foregroundStyle(state.anyActive ? .green : .secondary)
                Text("Local AI Monitor")
                    .font(.headline)
            }

            Text("\(state.activeModelCount) model\(state.activeModelCount == 1 ? "" : "s") running")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            if state.runtimes.isEmpty {
                Text("No AI runtimes detected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                // Per-runtime sections
                ForEach(state.runtimes) { runtime in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(runtime.type.displayName)
                                .font(.caption.bold())
                            Spacer()
                            Text(runtime.isResponding ? "responding" : "not responding")
                                .font(.caption2)
                                .foregroundStyle(runtime.isResponding ? .green : .red)
                        }

                        ForEach(runtime.loadedModels) { model in
                            HStack {
                                Text("  \(model.displayName)")
                                    .font(.caption2)
                                    .lineLimit(1)
                                Spacer()
                                if let params = model.parameterCount {
                                    Text(params)
                                        .font(.caption2.monospacedDigit())
                                }
                                if let vram = model.vramSize {
                                    Text(String(format: "%.1fG", Double(vram) / 1_073_741_824))
                                        .font(.caption2.monospacedDigit())
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Divider()

            // Totals
            HStack {
                Text(String(format: "CPU %.0f%%", state.totalCPU))
                Text("|")
                Text(String(format: "RAM %.1f GB", state.totalRAMGB))
            }
            .font(.caption.monospacedDigit().bold())

            Text("Updated \(state.lastUpdated.formatted(.dateTime.hour().minute()))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
