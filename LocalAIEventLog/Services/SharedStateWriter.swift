import Foundation
import WidgetKit

enum SharedStateWriter {
    static func write(_ state: AppState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        AppGroupConstants.sharedDefaults.set(data, forKey: AppGroupConstants.stateKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
