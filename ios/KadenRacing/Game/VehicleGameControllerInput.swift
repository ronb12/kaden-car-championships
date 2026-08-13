import GameController
import Foundation

/// MFi / PlayStation / Xbox controller support during races.
final class VehicleGameControllerInput {

    private var observer: NSObjectProtocol?

    func start(updating input: RaceInput) {
        stop()
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
        observer = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { _ in
            Self.applyFirstController(to: input)
        }
        Self.applyFirstController(to: input)
    }

    func stop() {
        GCController.stopWirelessControllerDiscovery()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    func poll(into input: RaceInput) {
        let scheme = ControlPreferences.scheme
        // On-screen touch / D-pad / tilt — never let a simulator ghost pad steer or accelerate.
        if scheme == .touch || scheme == .dpad || scheme == .tilt { return }
        guard let controller = GCController.controllers().first else { return }
        if let pad = controller.extendedGamepad {
            let steer = Float(pad.leftThumbstick.xAxis.value)
            let deadzone: Float = scheme == .wheel ? 0.06 : 0.14
            let touchScheme = scheme == .touch || scheme == .dpad
            if abs(steer) > deadzone && !(touchScheme && abs(steer) < 0.42) {
                input.steer = max(-1, min(1, steer))
                input.left = false
                input.right = false
            } else {
                input.steer = 0
            }
            let rt = Float(pad.rightTrigger.value)
            let lt = Float(pad.leftTrigger.value)
            // Ignore noisy idle triggers (common on simulator virtual pads) — do not stomp touch pedals.
            if rt > 0.12 {
                input.throttle = rt
                input.gas = rt > 0.2
            }
            if lt > 0.12 {
                input.brakeAmount = lt
                input.brake = lt > 0.2
            }
            if pad.buttonA.isPressed {
                input.gas = true
                input.throttle = max(input.throttle, 1)
            }
            if pad.buttonB.isPressed {
                input.brake = true
                input.brakeAmount = max(input.brakeAmount, 1)
            }
            let manualTrans = VehicleDrivingPreferences.isManualTransmission
            if manualTrans {
                if pad.leftShoulder.isPressed { input.shiftDown = true }
                if pad.rightShoulder.isPressed { input.shiftUp = true }
            } else {
                if pad.rightShoulder.isPressed { input.nitro = true }
            }
            if pad.buttonX.isPressed || (!manualTrans && pad.leftShoulder.isPressed) {
                input.handbrake = true
                input.handbrakeAmount = 1
            }
            if manualTrans, pad.buttonA.isPressed {
                input.nitro = true
            }
            // Dedicated reverse — D-pad down or button Y.
            input.reverse = pad.dpad.down.isPressed || pad.buttonY.isPressed
            return
        }
        if let pad = controller.microGamepad {
            let dx = Float(pad.dpad.xAxis.value)
            if abs(dx) > 0.15 {
                input.steer = max(-1, min(1, dx))
                input.left = false
                input.right = false
            } else {
                input.steer = 0
            }
            input.reverse = Float(pad.dpad.yAxis.value) < -0.35
            if pad.buttonA.isPressed {
                input.gas = true
                input.throttle = 1
            }
            if pad.buttonX.isPressed {
                input.brake = true
                input.brakeAmount = 1
            }
        }
    }

    private static func applyFirstController(to input: RaceInput) {
        _ = input
    }
}
