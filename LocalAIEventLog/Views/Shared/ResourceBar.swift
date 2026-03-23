import SwiftUI

struct ResourceBar: View {
    let label: String
    let value: Double
    let maxValue: Double
    let color: Color
    var suffix: String = ""
    var displayValue: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.body)
                .frame(width: 40, alignment: .leading)

            ProgressView(value: min(value, maxValue), total: maxValue)
                .tint(color)

            Text(displayValue ?? String(format: "%.1f\(suffix)", value))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
    }
}
