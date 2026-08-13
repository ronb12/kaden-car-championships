import Foundation
import CoreGraphics

enum ControlPreferences {
    private static let schemeKey = "krc.controlScheme"
    private static let sizeKey = "krc.control.size"
    private static let opacityKey = "krc.control.opacity"
    private static let sensitivityKey = "krc.control.sensitivity"

    static var scheme: ControlScheme {
        get {
            guard let raw = UserDefaults.standard.string(forKey: schemeKey),
                  let s = ControlScheme(rawValue: raw) else { return .dpad }
            return s
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: schemeKey) }
    }

    static var controlScale: CGFloat {
        get {
            // UserDefaults stores NSNumber — never cast directly to CGFloat.
            if UserDefaults.standard.object(forKey: sizeKey) == nil { return 1 }
            return CGFloat(UserDefaults.standard.double(forKey: sizeKey))
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: sizeKey) }
    }

    static var effectiveControlScale: CGFloat {
        min(1.35, controlScale * KRCAccessibility.controlScaleBoost)
    }

    static var controlOpacity: CGFloat {
        get {
            if UserDefaults.standard.object(forKey: opacityKey) == nil { return 0.88 }
            return CGFloat(UserDefaults.standard.double(forKey: opacityKey))
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: opacityKey) }
    }

    static var steerSensitivity: Float {
        get {
            if UserDefaults.standard.object(forKey: sensitivityKey) == nil { return 1 }
            return UserDefaults.standard.float(forKey: sensitivityKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: sensitivityKey)
            VehicleDrivingPreferences.steerSensitivity = newValue
        }
    }
}
