import Foundation

enum AppGroupConstants {
    static let groupID = "group.com.laei.LocalAIEventLog"
    static let stateKey = "currentAppState"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }
}
