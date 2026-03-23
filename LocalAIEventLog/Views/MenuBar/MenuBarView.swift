import SwiftUI

struct MenuBarView: View {
    @Environment(DetectionEngine.self) private var engine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Local AI Monitor")
                    .font(.headline)
                Spacer()
                Text(engine.appState.anyActive ? "Active" : "Idle")
                    .font(.caption)
                    .foregroundStyle(engine.appState.anyActive ? .green : .secondary)
            }

            if engine.runtimes.isEmpty {
                Text("No AI runtimes detected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                Text("\(engine.appState.activeModelCount) model\(engine.appState.activeModelCount == 1 ? "" : "s") running")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                ForEach(engine.runtimes) { runtime in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(runtime.isResponding ? .green : .gray)
                                .frame(width: 6, height: 6)
                            Text(runtime.type.displayName)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(LAEIFormatters.memoryString(bytes: runtime.resourceUsage.residentMemoryBytes))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        ForEach(runtime.loadedModels) { model in
                            HStack {
                                Text(model.displayName)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                if let vram = model.vramSize {
                                    Text(LAEIFormatters.memoryString(bytes: vram))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.leading, 14)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Label(LAEIFormatters.cpuString(engine.appState.totalCPU), systemImage: "cpu")
                Spacer()
                Label(LAEIFormatters.memoryString(bytes: engine.appState.totalRAMBytes), systemImage: "memorychip")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            Divider()

            Button("Open Local AI Event Log...") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 280)
    }
}
