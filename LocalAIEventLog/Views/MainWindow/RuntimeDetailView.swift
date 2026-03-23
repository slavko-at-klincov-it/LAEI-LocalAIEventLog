import SwiftUI

struct RuntimeDetailView: View {
    let runtime: AIRuntime
    @Binding var selectedModel: AIModel?

    var body: some View {
        List(selection: $selectedModel) {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: runtime.type.iconSystemName)
                                .font(.title2)
                            Text(runtime.type.displayName)
                                .font(.title.bold())
                        }
                        if let version = runtime.version {
                            Text("Version \(version)")
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            Text("PID \(runtime.processID)")
                                .font(.caption.monospacedDigit())
                            if let endpoint = runtime.endpoint {
                                Text(endpoint.absoluteString)
                                    .font(.caption.monospacedDigit())
                            }
                        }
                        .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    StatusIndicator(isActive: runtime.isResponding)
                }
            }

            Section("Resources") {
                ResourceBar(label: "CPU", value: runtime.resourceUsage.cpuPercent, maxValue: 100, color: .blue, suffix: "%")
                ResourceBar(
                    label: "RAM",
                    value: runtime.resourceUsage.residentMemoryMB,
                    maxValue: Double(SysctlBridge.systemMemorySize()) / 1_048_576,
                    color: .orange,
                    suffix: " MB",
                    displayValue: LAEIFormatters.memoryString(bytes: runtime.resourceUsage.residentMemoryBytes)
                )
                HStack {
                    Text("Threads")
                    Spacer()
                    Text("\(runtime.resourceUsage.threadCount)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Section("Loaded Models (\(runtime.loadedModels.count))") {
                if runtime.loadedModels.isEmpty {
                    Text("No models currently loaded")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(runtime.loadedModels) { model in
                        ModelRow(model: model)
                            .tag(model)
                    }
                }
            }
        }
    }
}

struct ModelRow: View {
    let model: AIModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.body.bold())
                HStack(spacing: 8) {
                    if let params = model.parameterCount {
                        Text(params)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.15), in: Capsule())
                    }
                    if let quant = model.quantization {
                        Text(quant)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.purple.opacity(0.15), in: Capsule())
                    }
                }
                .font(.caption)
            }

            Spacer()

            if let vram = model.vramSize {
                Text(LAEIFormatters.memoryString(bytes: vram))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
