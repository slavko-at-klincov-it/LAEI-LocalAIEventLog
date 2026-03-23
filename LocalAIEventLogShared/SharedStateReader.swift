import Foundation

struct SharedStateReader {
    func read() -> AppState {
        guard let data = AppGroupConstants.sharedDefaults.data(forKey: AppGroupConstants.stateKey),
              let state = try? JSONDecoder().decode(AppState.self, from: data)
        else { return .empty }
        return state
    }
}
