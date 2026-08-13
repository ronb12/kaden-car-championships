import SceneKit
import simd
import UIKit

/// Cinematic chase / hood / cockpit cameras with speed FOV, drift tilt, and impact shake.
struct EnvironmentCameraRig {

    enum Mode: String, CaseIterable {
        case chase
        case hood
        case cockpit
    }

    var mode: Mode = .chase
    private var smoothedEye = SCNVector3Zero
    private var smoothedFocus = SCNVector3Zero
    private var shakePhase: Float = 0
    var initialized = false
    /// 1 = starting-grid wide shot, 0 = chase. Blends out after lights out.
    private var introBlend: Float = 1
    private var introOrbit: Float = 0

    mutating func update(
        cameraNode: SCNNode,
        carPosition: SIMD3<Float>,
        forward: SIMD3<Float>,
        speedRatio: Float,
        portrait: Bool,
        dt: Float,
        viewBounds: CGSize,
        driftTilt: Float = 0,
        impactImpulse: Float = 0,
        lateralVelocity: Float = 0,
        shakeScale: Float = 1,
        gridIntro: Bool = false,
        packCenter: SIMD3<Float>? = nil,
        packRadius: Float = 8
    ) {
        let flatForward = simd_normalize(SIMD3<Float>(forward.x, 0, forward.z))
        let right = SIMD3<Float>(flatForward.z, 0, -flatForward.x)
        var (eye, focus, baseFOV) = targets(
            carPosition: carPosition,
            forward: flatForward,
            speedRatio: speedRatio,
            portrait: portrait
        )
        if KRCAccessibility.reduceMotion {
            introBlend = 0
        } else if gridIntro {
            introBlend = 1
            introOrbit += dt * 0.28
        } else {
            introBlend = max(0, introBlend - dt * 0.95)
        }
        if introBlend > 0.01 {
            let pack = packCenter ?? carPosition
            let (gEye, gFocus, gFOV) = gridTargets(
                packCenter: pack,
                forward: flatForward,
                packRadius: packRadius,
                portrait: portrait,
                orbit: introOrbit
            )
            let u = introBlend
            eye = gEye * u + eye * (1 - u)
            focus = gFocus * u + focus * (1 - u)
            baseFOV = gFOV * CGFloat(u) + baseFOV * CGFloat(1 - u)
        }

        let driftRoll = driftTilt * 0.36
        eye += right * lateralVelocity * 0.05
        focus += right * lateralVelocity * 0.025

        if !initialized {
            smoothedEye = SCNVector3(eye.x, eye.y, eye.z)
            smoothedFocus = SCNVector3(focus.x, focus.y, focus.z)
            initialized = true
        }

        // Snap when parked — except while blending out of the grid intro shot.
        #if targetEnvironment(simulator)
        let smoothAlpha = (speedRatio < 0.03 && introBlend < 0.02) ? 1 : min(1, dt * (mode == .cockpit ? 14 : 11))
        #else
        let smoothAlpha = (speedRatio < 0.03 && introBlend < 0.02) ? 1 : min(1, dt * (mode == .cockpit ? 10 : 6.5))
        #endif
        smoothedEye = smoothedEye.lerped(to: SCNVector3(eye.x, eye.y, eye.z), alpha: smoothAlpha)
        smoothedFocus = smoothedFocus.lerped(to: SCNVector3(focus.x, focus.y, focus.z), alpha: smoothAlpha)

        if speedRatio > 0.28, shakeScale > 0.01 {
            shakePhase += dt * (7 + speedRatio * 7)
            let shake = sin(shakePhase) * 0.009 * speedRatio * shakeScale
            smoothedEye.y += shake
            smoothedEye.x += cos(shakePhase * 1.3) * 0.004 * speedRatio * shakeScale
        }

        if impactImpulse > 0.05 {
            let kick = impactImpulse * 0.72
            smoothedEye.x += right.x * kick * (driftTilt >= 0 ? 1 : -1)
            smoothedEye.y += kick * 0.7
        }

        aim(cameraNode: cameraNode, eye: smoothedEye, focus: smoothedFocus, roll: driftRoll)

        if let cam = cameraNode.camera {
            // Punchier speed FOV bloom — sells arcade velocity in the first seconds.
            let speedFOV = CGFloat(speedRatio) * (portrait ? CGFloat(32) : CGFloat(36))
            cam.fieldOfView = min(112, baseFOV + speedFOV)
        }
    }

    private func targets(
        carPosition: SIMD3<Float>,
        forward: SIMD3<Float>,
        speedRatio: Float,
        portrait: Bool
    ) -> (SIMD3<Float>, SIMD3<Float>, CGFloat) {
        switch mode {
        case .chase:
            // NFS-style chase — low, fast FOV bloom, look-ahead sells speed.
            #if targetEnvironment(simulator)
            // Higher / farther chase so body+cabin+wheels read as an upright 3D car (not road cards).
            let dist: Float = portrait ? 9.2 + speedRatio * 1.6 : 8.4 + speedRatio * 1.8
            let height: Float = portrait ? 3.2 + speedRatio * 0.4 : 2.85 + speedRatio * 0.45
            let minAbove: Float = portrait ? 2.5 : 2.2
            let focusY: Float = portrait ? 1.0 : 1.1
            let lookAhead: Float = 1.2 + speedRatio * 1.8
            let fov: CGFloat = portrait ? 54 : 52
            let lateral: Float = portrait ? 1.2 : 1.5
            #else
            // Closer + wider FOV so world-speed reads as fast (not a distant cruise).
            let dist: Float = portrait ? 5.6 + speedRatio * 2.0 : 4.9 + speedRatio * 2.3
            let height: Float = portrait ? 2.05 + speedRatio * 0.4 : 1.72 + speedRatio * 0.46
            let minAbove: Float = portrait ? 1.6 : 1.32
            let focusY: Float = portrait ? 0.74 : 0.84
            let lookAhead: Float = 2.9 + speedRatio * 4.6
            let fov: CGFloat = portrait ? 70 : 68
            let lateral: Float = 0
            #endif
            let back = -forward * dist
            let right = SIMD3<Float>(forward.z, 0, -forward.x)
            var eye = carPosition + back + right * lateral + SIMD3<Float>(0, height, 0)
            eye.y = max(eye.y, carPosition.y + minAbove)
            let focus = carPosition + forward * lookAhead + SIMD3<Float>(0, focusY, 0)
            return (eye, focus, fov)
        case .hood:
            let eye = carPosition + SIMD3<Float>(forward.x * 0.38, 0.98, forward.z * 0.38)
            let focus = carPosition + forward * 20 + SIMD3<Float>(0, -0.02, 0)
            return (eye, focus, portrait ? 82 : 76)
        case .cockpit:
            let eye = carPosition + SIMD3<Float>(0, 0.74, 0.12)
            let focus = carPosition + forward * 26 + SIMD3<Float>(0, -0.04, 0)
            return (eye, focus, portrait ? 86 : 80)
        }
    }

    /// High 3/4 of the whole starting pack — not the chase bumper cam.
    private func gridTargets(
        packCenter: SIMD3<Float>,
        forward: SIMD3<Float>,
        packRadius: Float,
        portrait: Bool,
        orbit: Float
    ) -> (SIMD3<Float>, SIMD3<Float>, CGFloat) {
        let radius = max(6, packRadius)
        let dist: Float = max(14, radius * 1.85 + (portrait ? 9 : 8))
        let height: Float = max(8.5, radius * 1.15 + (portrait ? 8.2 : 7.0))
        let side: Float = max(14, radius * 1.35 + (portrait ? 11 : 12))
        let swing = sin(orbit) * 0.18
        let right = SIMD3<Float>(forward.z, 0, -forward.x)
        let sideNow = side * (0.92 + swing)
        var eye = packCenter - forward * dist + right * sideNow + SIMD3<Float>(0, height, 0)
        eye.y = max(eye.y, packCenter.y + 6.5)
        let focus = packCenter - forward * (radius * 0.08) + SIMD3<Float>(0, 0.25, 0)
        let fov: CGFloat = portrait ? 62 : 58
        return (eye, focus, fov)
    }

    private func aim(cameraNode: SCNNode, eye: SCNVector3, focus: SCNVector3, roll: Float) {
        let worldUp = SIMD3<Float>(0, 1, 0)
        let ex = SIMD3<Float>(eye.x, eye.y, eye.z)
        let fx = SIMD3<Float>(focus.x, focus.y, focus.z)
        var forward = fx - ex
        let fl = simd_length(forward)
        if fl < 0.0001 {
            forward = SIMD3<Float>(0, 0, -1)
        } else {
            forward /= fl
        }
        #if targetEnvironment(simulator)
        let minLookDown: Float = -0.35
        #else
        let minLookDown: Float = -0.42
        #endif
        if forward.y < minLookDown {
            forward.y = minLookDown
            forward = simd_normalize(forward)
        }
        var right = simd_cross(worldUp, forward)
        let rl = simd_length(right)
        if rl < 0.0001 {
            right = SIMD3<Float>(1, 0, 0)
        } else {
            right /= rl
        }
        var up = simd_normalize(simd_cross(forward, right))
        if abs(roll) > 0.001 {
            let cr = cos(roll)
            let sr = sin(roll)
            let rolledRight = right * cr + up * sr
            up = simd_normalize(simd_cross(forward, rolledRight))
            right = rolledRight
        }
        cameraNode.simdTransform = simd_float4x4(columns: (
            SIMD4<Float>(right.x, right.y, right.z, 0),
            SIMD4<Float>(up.x, up.y, up.z, 0),
            SIMD4<Float>(-forward.x, -forward.y, -forward.z, 0),
            SIMD4<Float>(ex.x, ex.y, ex.z, 1)
        ))
    }
}
