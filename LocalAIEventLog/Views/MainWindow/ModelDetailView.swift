import SwiftUI

struct ModelDetailView: View {
    let model: AIModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: model.runtimeType.iconSystemName)
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.displayName)
                            .font(.title.bold())
                        Text(model.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Divider()

                // Metadata Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    MetadataCell(label: "Runtime", value: model.runtimeType.displayName)
                    MetadataCell(label: "Parameters", value: model.parameterCount ?? "Unknown")
                    MetadataCell(label: "Quantization", value: model.quantization ?? "Unknown")
                    MetadataCell(label: "Context Length", value: model.contextLength.map { "\($0)" } ?? "Unknown")

                    if let fileSize = model.fileSize {
                        MetadataCell(label: "File Size", value: LAEIFormatters.memoryString(bytes: fileSize))
                    }
                    if let vramSize = model.vramSize {
                        MetadataCell(label: "VRAM Usage", value: LAEIFormatters.memoryString(bytes: vramSize))
                    }
                    if let loadedAt = model.loadedAt {
                        MetadataCell(label: "Loaded At", value: loadedAt.formatted(.dateTime.hour().minute()))
                    }
                }

                // Resource usage
                if let usage = model.resourceUsage {
                    Divider()
                    Text("Resource Usage")
                        .font(.headline)

                    VStack(spacing: 8) {
                        ResourceBar(label: "CPU", value: usage.cpuPercent, maxValue: 100, color: .blue, suffix: "%")
                        ResourceBar(
                            label: "RAM",
                            value: usage.residentMemoryMB,
                            maxValue: Double(SysctlBridge.systemMemorySize()) / 1_048_576,
                            color: .orange,
                            suffix: " MB",
                            displayValue: LAEIFormatters.memoryString(bytes: usage.residentMemoryBytes)
                        )
                    }
                }
            }
            .padding()
        }
    }
}

struct MetadataCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
