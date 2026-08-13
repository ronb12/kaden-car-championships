import CoreMotion
import Foundation
import UIKit

/// Smooth tilt steering — only active when `ControlPreferences.scheme == .tilt`.
final class TiltSteeringController {
    private let motion = CMMotionManager()

    func start(updating input: RaceInput) {
        guard ControlPreferences.scheme == .tilt else { return }
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        // xArbitraryZVertical works on all devices including iPad Wi-Fi (no compass required).
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { data, _ in
            guard let data else { return }
            // In landscape the tilt-left/right gesture maps to pitch; in portrait it maps to roll.
            let isLandscape = UIDevice.current.orientation.isLandscape
            let rawAngle = isLandscape ? -data.attitude.pitch : data.attitude.roll
            let dead: Double = 0.06
            let gain = Double(ControlPreferences.steerSensitivity) * 1.35
            let raw = max(-1, min(1, rawAngle * gain))
            if abs(raw) > dead {
                input.steer = Float(raw)
                input.left = false
                input.right = false
            } else {
                input.steer = 0
                input.left = false
                input.right = false
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }
}
