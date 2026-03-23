import SwiftUI

struct MenuBarLabel: View {
    let isActive: Bool
    let modelCount: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isActive ? "brain.filled.head.profile" : "brain.head.profile")
                .symbolRenderingMode(.palette)
                .foregroundStyle(isActive ? .green : .secondary, .primary)
            if modelCount > 0 {
                Text("\(modelCount)")
                    .font(.caption2.monospacedDigit())
            }
        }
    }
}
