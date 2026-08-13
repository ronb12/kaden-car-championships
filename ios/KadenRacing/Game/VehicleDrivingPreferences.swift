import Foundation

/// Tunable driving assist and input scaling (persisted).
enum VehicleDrivingPreferences {
    private static let transmissionKey = "krc.drive.transmissionMode"
    private static let manualKey = "krc.drive.manualControl"
    private static let steerKey = "krc.control.sensitivity"
    private static let assistKey = "krc.drive.steeringAssist"
    private static let driftKey = "krc.drive.driftAssist"
    private static let brakeAssistKey = "krc.drive.brakeAssist"
    private static let tractionKey = "krc.drive.trractionControl"

    /// Gearbox mode — automatic upshifts by speed; manual uses player shift buttons.
    static var transmissionMode: TransmissionMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: transmissionKey),
                  let mode = TransmissionMode(rawValue: raw) else {
                return .automatic
            }
            return mode
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: transmissionKey) }
    }

    static var isManualTransmission: Bool { transmissionMode == .manual }

    /// When true, assists are off. Default is assists ON so kids stay on the road.
    static var manualControl: Bool {
        get {
            if UserDefaults.standard.object(forKey: manualKey) == nil { return false }
            return UserDefaults.standard.bool(forKey: manualKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: manualKey) }
    }

    /// Shared with Settings → Steer sensitivity (`ControlPreferences`).
    static var steerSensitivity: Float {
        get {
            if UserDefaults.standard.object(forKey: steerKey) == nil { return 1.0 }
            return UserDefaults.standard.float(forKey: steerKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: steerKey) }
    }

    /// Raw slider values for Settings (ignores manual override).
    static var storedSteeringAssist: Float { stored(assistKey, default: 0.58) }
    static var storedDriftAssist: Float { stored(driftKey, default: 0.62) }
    static var storedBrakeAssist: Float { stored(brakeAssistKey, default: 0.48) }
    static var storedTractionControl: Float { stored(tractionKey, default: 0.58) }

    static var steeringAssist: Float {
        get { manualControl ? 0 : storedSteeringAssist }
        set { UserDefaults.standard.set(newValue, forKey: assistKey) }
    }

    static var driftAssist: Float {
        get { manualControl ? 0 : storedDriftAssist }
        set { UserDefaults.standard.set(newValue, forKey: driftKey) }
    }

    static var brakeAssist: Float {
        get { manualControl ? 0 : storedBrakeAssist }
        set { UserDefaults.standard.set(newValue, forKey: brakeAssistKey) }
    }

    static var tractionControl: Float {
        get { manualControl ? 0 : storedTractionControl }
        set { UserDefaults.standard.set(newValue, forKey: tractionKey) }
    }

    private static func stored(_ key: String, default def: Float) -> Float {
        if UserDefaults.standard.object(forKey: key) == nil { return def }
        return UserDefaults.standard.float(forKey: key)
    }
}
