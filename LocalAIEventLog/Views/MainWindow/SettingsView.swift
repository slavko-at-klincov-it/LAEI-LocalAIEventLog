import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(AlertManager.self) private var alertManager
    @State private var launchAtLogin = false
    @State private var ramThreshold: Double = 70.0

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        if newValue {
                            try? SMAppService.mainApp.register()
                        } else {
                            try? SMAppService.mainApp.unregister()
                        }
                    }
            }

            Section("Alerts") {
                HStack {
                    Text("RAM Threshold")
                    Slider(value: $ramThreshold, in: 30...95, step: 5)
                    Text("\(Int(ramThreshold))%")
                        .monospacedDigit()
                        .frame(width: 40)
                }
                .onChange(of: ramThreshold) { _, newValue in
                    alertManager.ramThresholdPercent = newValue
                }

                Text("Alert when AI models use more than \(Int(ramThreshold))% of system RAM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                HStack {
                    Text("Local AI Event Log")
                    Spacer()
                    Text("v1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding()
        .onAppear {
            ramThreshold = alertManager.ramThresholdPercent
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
