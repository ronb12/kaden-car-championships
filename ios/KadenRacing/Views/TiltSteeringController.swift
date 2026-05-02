import CoreMotion
import Foundation

/// Smooth tilt steering — only active when `ControlPreferences.scheme == .tilt`.
final class TiltSteeringController {
    private let motion = CMMotionManager()

    func start(updating input: RaceInput) {
        guard ControlPreferences.scheme == .tilt else { return }
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { data, _ in
            guard let roll = data?.attitude.roll else { return }
            let dead: Double = 0.08
            input.left = roll < -dead
            input.right = roll > dead
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }
}
