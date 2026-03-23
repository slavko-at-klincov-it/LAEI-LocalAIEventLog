import SwiftUI

struct ResourceGaugeView: View {
    let usage: ResourceUsage

    var body: some View {
        VStack(spacing: 12) {
            ResourceBar(label: "CPU", value: usage.cpuPercent, maxValue: 100, color: .blue, suffix: "%")
            ResourceBar(
                label: "RAM",
                value: usage.residentMemoryMB,
                maxValue: 32768,
                color: .orange,
                suffix: " MB",
                displayValue: LAEIFormatters.memoryString(bytes: usage.residentMemoryBytes)
            )
            HStack {
                Text("Threads")
                    .frame(width: 40, alignment: .leading)
                Spacer()
                Text("\(usage.threadCount)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
        }
    }
}
