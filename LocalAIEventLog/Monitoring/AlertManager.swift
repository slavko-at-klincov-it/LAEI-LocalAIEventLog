import Foundation
import UserNotifications

@MainActor
@Observable
final class AlertManager {
    var ramThresholdPercent: Double = 70.0
    private var lastAlertTime: Date?
    private let minimumAlertInterval: TimeInterval = 60.0

    func checkThresholds(appState: AppState) {
        guard appState.systemTotalMemoryBytes > 0 else { return }

        let aiMemoryPercent = Double(appState.totalRAMBytes) / Double(appState.systemTotalMemoryBytes) * 100
        if aiMemoryPercent >= ramThresholdPercent {
            sendAlert(
                title: "High AI Memory Usage",
                body: String(format: "Local AI models are using %.1f GB (%.0f%% of system RAM)", appState.totalRAMGB, aiMemoryPercent)
            )
        }
    }

    func notifyRuntimeAppeared(_ runtime: AIRuntime) {
        sendAlert(
            title: "AI Runtime Detected",
            body: "\(runtime.type.displayName) started running"
        )
    }

    func notifyModelLoaded(model: AIModel, runtime: AIRuntime) {
        sendAlert(
            title: "Model Loaded",
            body: "\(model.displayName) loaded in \(runtime.type.displayName)"
        )
    }

    private func sendAlert(title: String, body: String) {
        // Rate limit alerts
        if let lastTime = lastAlertTime, Date().timeIntervalSince(lastTime) < minimumAlertInterval {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
        lastAlertTime = Date()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
