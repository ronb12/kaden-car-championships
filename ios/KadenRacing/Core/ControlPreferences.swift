import Foundation

enum ControlPreferences {
    private static let key = "krc.controlScheme"

    static var scheme: ControlScheme {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let s = ControlScheme(rawValue: raw) else { return .touch }
            return s
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
