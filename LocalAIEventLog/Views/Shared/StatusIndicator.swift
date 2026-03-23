import SwiftUI

struct StatusIndicator: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? .green : .gray)
                .frame(width: 10, height: 10)
                .shadow(color: isActive ? .green.opacity(0.5) : .clear, radius: 4)
            Text(isActive ? "Active" : "Inactive")
                .font(.caption)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
    }
}
