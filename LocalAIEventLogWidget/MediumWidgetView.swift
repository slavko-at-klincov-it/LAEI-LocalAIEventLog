import SwiftUI

struct MediumWidgetView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: state.anyActive ? "brain.filled.head.profile" : "brain.head.profile")
                    .foregroundStyle(state.anyActive ? .green : .secondary)
                Text("\(state.activeModelCount) models running")
                    .font(.headline)
                Spacer()
                Text(String(format: "CPU %.0f%%", state.totalCPU))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Divider()

            let allModels = state.runtimes.flatMap { runtime in
                runtime.loadedModels.map { (model: $0, type: runtime.type) }
            }

            if allModels.isEmpty {
                Text("No models active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(allModels.prefix(3), id: \.model.id) { item in
                    HStack {
                        Text(item.model.displayName)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Spacer()
                        Text(item.type.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let vram = item.model.vramSize {
                            Text(String(format: "%.1f GB", Double(vram) / 1_073_741_824))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Text(String(format: "RAM %.1f GB", state.totalRAMGB))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }
}
