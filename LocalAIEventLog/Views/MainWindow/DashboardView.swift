import SwiftUI

struct DashboardView: View {
    @Environment(DetectionEngine.self) private var engine

    private var allModels: [(AIModel, AIRuntime)] {
        engine.runtimes.flatMap { runtime in
            runtime.loadedModels.map { ($0, runtime) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // System Overview
                Text("System Overview")
                    .font(.title2.bold())
                    .padding(.horizontal)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    ResourceCard(
                        title: "CPU",
                        value: LAEIFormatters.cpuString(engine.appState.totalCPU),
                        icon: "cpu",
                        color: .blue,
                        percent: min(engine.appState.totalCPU, 100)
                    )
                    ResourceCard(
                        title: "AI RAM",
                        value: LAEIFormatters.memoryString(bytes: engine.appState.totalRAMBytes),
                        icon: "memorychip",
                        color: .orange,
                        percent: engine.appState.systemTotalMemoryBytes > 0
                            ? Double(engine.appState.totalRAMBytes) / Double(engine.appState.systemTotalMemoryBytes) * 100
                            : 0
                    )
                    ResourceCard(
                        title: "System Memory",
                        value: LAEIFormatters.memoryString(bytes: engine.appState.systemTotalMemoryBytes),
                        icon: "memorychip.fill",
                        color: .purple,
                        percent: engine.appState.memoryPressurePercent
                    )
                }
                .padding(.horizontal)

                // Active Models
                HStack {
                    Text("Active Models")
                        .font(.title2.bold())
                    Spacer()
                    Text("\(engine.appState.activeModelCount) running")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                if allModels.isEmpty {
                    ContentUnavailableView(
                        "No Models Running",
                        systemImage: "brain.head.profile",
                        description: Text("Start an AI model with Ollama, LM Studio, or another local runtime")
                    )
                    .padding(.top, 20)
                } else {
                    ForEach(allModels, id: \.0.id) { model, runtime in
                        ActiveModelRow(model: model, runtime: runtime)
                            .padding(.horizontal)
                    }
                }

                // Runtimes
                if !engine.runtimes.isEmpty {
                    Text("Detected Runtimes")
                        .font(.title2.bold())
                        .padding(.horizontal)

                    ForEach(engine.runtimes) { runtime in
                        RuntimeSummaryRow(runtime: runtime)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Subviews

struct ResourceCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let percent: Double

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.monospacedDigit().bold())

            ProgressView(value: min(percent, 100), total: 100)
                .tint(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ActiveModelRow: View {
    let model: AIModel
    let runtime: AIRuntime

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: runtime.type.iconSystemName)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.body.bold())
                HStack(spacing: 8) {
                    Text(runtime.type.displayName)
                    if let params = model.parameterCount {
                        Text(params)
                    }
                    if let quant = model.quantization {
                        Text(quant)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let vram = model.vramSize {
                VStack(alignment: .trailing) {
                    Text(LAEIFormatters.memoryString(bytes: vram))
                        .font(.body.monospacedDigit())
                    Text("VRAM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct RuntimeSummaryRow: View {
    let runtime: AIRuntime

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(runtime.isResponding ? .green : .gray)
                .frame(width: 8, height: 8)

            Image(systemName: runtime.type.iconSystemName)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(runtime.type.displayName)
                        .font(.body.bold())
                    if let version = runtime.version {
                        Text("v\(version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("PID \(runtime.processID)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(LAEIFormatters.memoryString(bytes: runtime.resourceUsage.residentMemoryBytes))
                    .font(.body.monospacedDigit())
                Text(LAEIFormatters.cpuString(runtime.resourceUsage.cpuPercent) + " CPU")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}
