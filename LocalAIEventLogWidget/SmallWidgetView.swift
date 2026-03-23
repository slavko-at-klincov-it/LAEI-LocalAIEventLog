import SwiftUI

struct SmallWidgetView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: state.anyActive ? "brain.filled.head.profile" : "brain.head.profile")
                .font(.title)
                .foregroundStyle(state.anyActive ? .green : .secondary)

            Spacer()

            Text("\(state.activeModelCount)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text(state.activeModelCount == 1 ? "model running" : "models running")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(String(format: "RAM %.1f GB", state.totalRAMGB))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
