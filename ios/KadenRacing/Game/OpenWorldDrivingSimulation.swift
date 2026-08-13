import Foundation
import simd

/// NFS-style free-roam driving — world XZ + heading (`sin`/`cos` integration; steer +1 = turn right).
struct OpenWorldDrivingSimulation {

    /// World units/sec → HUD km/h.
    /// Lower than the old 5.7 so a ~220 km/h readout still means fast track travel
    /// (Palm City circuits are large; 5.7 made 200 km/h look like a cruise).
    static let worldUnitsToKmh: Float = 3.15

    struct Config {
        let stats: CarRuntimeStats
        let difficultyGripMul: Float
        let category: VehicleCategory
        let trackGrip: Float
        let maxWorldSpeed: Float
        var clampProfile: TrackWorldQuery.ClampProfile = .circuit
    }

    struct InputSample {
        var throttle: Float
        var brake: Float
        var steer: Float
        var handbrake: Float
        var nitro: Bool
        var shiftUp: Bool
        var shiftDown: Bool
        /// Explicit reverse pedal (1 = held).
        var reverse: Float = 0
    }

    struct State {
        var worldX: Float = 0
        var worldZ: Float = 0
        var heading: Float = 0
        var speed: Float = 0
        var driftYaw: Float = 0
        var bodyRoll: Float = 0
        var bodyPitch: Float = 0
        var suspension = SIMD4<Float>(repeating: 0)
        var rpm: Float = 0.35
        var gear: Int = 1
        var wheelSpin: Float = 0
        var driftMultiplier: Float = 1
        var driftScoreRate: Float = 0
        var brakeGlow: Float = 0
        var isDrifting = false
        var slipAmount: Float = 0
        var impactImpulse: Float = 0
        var trackT: Float = 0
    }

    private var smoothedSteer: Float = 0
    private var smoothedThrottle: Float = 0
    private var smoothedBrake: Float = 0
    private var brakeHeat: Float = 0
    /// Brake held at standstill before engaging reverse (arcade: stop first, then R).
    private var reverseEngageTimer: Float = 0
    private var transmission = VehicleTransmission()

    var shiftNotice: String? { transmission.displayNotice }
    var isShiftZone: Bool { transmission.isShiftZone }

    mutating func reset(at position: SIMD3<Float>, heading: Float, speed: Float = 0) {
        smoothedSteer = 0
        smoothedThrottle = 0
        smoothedBrake = 0
        brakeHeat = 0
        reverseEngageTimer = 0
        transmission.reset()
    }

    mutating func step(
        state: inout State,
        input: InputSample,
        config: Config,
        trackQuery: TrackWorldQuery,
        dt: Float
    ) {
        let dtClamped = min(1 / 30, max(0.0001, dt))
        let prefs = VehicleDrivingPreferences.self
        let manual = prefs.manualControl

        let steerTarget = max(-1, min(1, input.steer))
        let steerAlpha = min(1, dtClamped * ((manual ? 14 : 8) + abs(steerTarget) * (manual ? 6 : 4)))
        smoothedSteer += (steerTarget - smoothedSteer) * steerAlpha

        smoothedThrottle += (max(0, min(1, input.throttle)) - smoothedThrottle) * min(1, dtClamped * 16)
        smoothedBrake += (max(0, min(1, input.brake)) - smoothedBrake) * min(1, dtClamped * 20)
        let handbrake = max(0, min(1, input.handbrake))

        // Mild nitro — NFS/GT-style boost.
        let nitroMul: Float = input.nitro ? 1.18 : 1
        let topSpeed = config.maxWorldSpeed * config.stats.topSpeedMul * nitroMul
        let reverseCap = topSpeed * 0.32

        let drive = transmission.tick(
            dt: dtClamped,
            speed: state.speed,
            maxTopSpeed: topSpeed,
            throttle: smoothedThrottle,
            shiftUp: input.shiftUp,
            shiftDown: input.shiftDown,
            mode: VehicleDrivingPreferences.transmissionMode
        )
        let impulse = transmission.consumeShiftImpulse()
        state.speed += impulse.speedDelta
        state.gear = drive.gear

        let effectiveTop = max(0.001, drive.effectiveTopSpeed)
        let speedRatio = min(1, abs(state.speed) / effectiveTop)

        let grip = config.stats.gripMul * config.difficultyGripMul * config.trackGrip

        // Longitudinal — punchy launch so the car reaches the higher world top quickly.
        let torque = torqueCurve(speedRatio: speedRatio) * config.stats.accelMul * categoryAccel(config.category) * drive.accelMul
        var driveForce = smoothedThrottle * torque * effectiveTop * 0.34
        if prefs.tractionControl > 0.05 && speedRatio > 0.55 && abs(smoothedSteer) > 0.35 {
            driveForce *= max(0.82, 1 - prefs.tractionControl * 0.12 * speedRatio)
        }

        var brakeForce = smoothedBrake * effectiveTop * (0.24 + prefs.brakeAssist * 0.032)
        brakeHeat = min(1, brakeHeat + smoothedBrake * dtClamped * 0.9)
        brakeHeat = max(0, brakeHeat - dtClamped * 0.35)
        brakeForce *= max(0.72, 1 - brakeHeat * 0.28)

        let stopEpsilon = effectiveTop * 0.012
        let throttlePriority = smoothedThrottle > 0.18
        let reverseHeld = input.reverse > 0.35 && !throttlePriority

        if reverseHeld {
            // Dedicated R: stop forward motion, then back up immediately.
            reverseEngageTimer = 0
            if state.speed > stopEpsilon {
                state.speed = max(0, state.speed - brakeForce * 1.35 * dtClamped)
            } else {
                let reverseAccel = max(0.45, input.reverse) * torque * effectiveTop * 0.1
                state.speed = max(-reverseCap, state.speed - reverseAccel * dtClamped)
            }
        } else if throttlePriority {
            reverseEngageTimer = 0
            state.speed += (driveForce - brakeForce * 0.35) * dtClamped
        } else if smoothedBrake > 0.08 {
            if state.speed > stopEpsilon {
                reverseEngageTimer = 0
                state.speed = max(0, state.speed - brakeForce * dtClamped)
            } else if state.speed < -stopEpsilon {
                reverseEngageTimer = 0
                let reverseAccel = smoothedBrake * torque * effectiveTop * 0.07
                state.speed = max(-reverseCap, state.speed - reverseAccel * dtClamped)
            } else {
                state.speed = 0
                // Legacy: hold brake at standstill to creep into R.
                if smoothedBrake > 0.55 {
                    reverseEngageTimer += dtClamped
                } else {
                    reverseEngageTimer = 0
                }
                if reverseEngageTimer > 0.22 {
                    let reverseAccel = smoothedBrake * torque * effectiveTop * 0.07
                    state.speed = max(-reverseCap, state.speed - reverseAccel * dtClamped)
                }
            }
        } else {
            reverseEngageTimer = 0
            state.speed += driveForce * dtClamped
        }

        let drag = effectiveTop * (0.008 + speedRatio * speedRatio * 0.018)
        if smoothedBrake <= 0.08 && smoothedThrottle <= 0.08 {
            if state.speed > 0 {
                state.speed = max(0, state.speed - drag * dtClamped)
            } else if state.speed < 0 {
                state.speed = min(0, state.speed + drag * dtClamped)
            }
        }
        state.speed = min(max(state.speed, -reverseCap), effectiveTop)

        // Steering + drift yaw (arcade)
        let absSpd = abs(state.speed)
        let lowSpeedSteer = max(0.7, absSpd / max(0.35, effectiveTop * 0.08))
        let steerFactor = min(1, lowSpeedSteer) * (state.speed < 0 ? -1 : 1)
        // High-speed lockout — cars get heavier to turn as speed rises (sim-cade).
        let speedSteerAtten = max(0.42, 1 - speedRatio * 0.48)
        let turnRate: Float = 2.85 * steerFactor * grip * speedSteerAtten * (manual ? 1.08 : 1.0)
        // Positive steer = turn right (heading increases with sin/cos integration below).
        state.heading += turnRate * smoothedSteer * dtClamped

        let steerLeft = max(0, -smoothedSteer)
        let steerRight = max(0, smoothedSteer)
        state.driftYaw += (steerRight - steerLeft) * min(1, absSpd / max(0.001, effectiveTop) * 5) * 2.6 * dtClamped * (1.3 - grip * 0.35)
        state.driftYaw *= pow(0.9, dtClamped * 55)
        state.driftYaw = max(-0.48, min(0.48, state.driftYaw))

        let handbrakeDrift = handbrake > 0.15 && speedRatio > 0.08
        if handbrakeDrift {
            state.driftYaw += smoothedSteer * handbrake * dtClamped * 3.2
            state.isDrifting = true
            state.driftMultiplier = min(5, state.driftMultiplier + dtClamped * 0.9)
            state.driftScoreRate = 42 * state.driftMultiplier * max(abs(state.driftYaw), handbrake * 0.35)
        } else if abs(state.driftYaw) > 0.12 && speedRatio > 0.22 {
            state.isDrifting = true
            state.driftMultiplier = min(5, state.driftMultiplier + dtClamped * 0.7)
            state.driftScoreRate = 38 * state.driftMultiplier * abs(state.driftYaw)
        } else {
            state.isDrifting = false
            state.driftMultiplier = max(1, state.driftMultiplier - dtClamped * 1.1)
            state.driftScoreRate = 0
        }

        state.heading += state.driftYaw * dtClamped * 2.35
        state.slipAmount = min(1, abs(state.driftYaw) * 2.2 + abs(smoothedSteer) * 0.35 * speedRatio)

        // Integrate position along facing
        state.worldX += sin(state.heading) * state.speed * dtClamped
        state.worldZ += cos(state.heading) * state.speed * dtClamped

        var impact: Float = 0
        let clamped = trackQuery.clampToTrack(
            x: state.worldX,
            z: state.worldZ,
            speed: state.speed,
            driftYaw: &state.driftYaw,
            profile: config.clampProfile
        )
        let softGuided = config.clampProfile == .district
            && (clamped.x != state.worldX || clamped.z != state.worldZ || clamped.speed < state.speed)
        if clamped.hit || softGuided {
            state.worldX = clamped.x
            state.worldZ = clamped.z
            state.speed = clamped.speed
            if clamped.hit {
                impact = 0.35
            }
        }
        state.impactImpulse = max(0, impact - dtClamped * 2.5)

        let projection = trackQuery.project(x: state.worldX, z: state.worldZ)
        state.trackT = projection.trackT

        // Body visuals
        let targetRoll = -smoothedSteer * 0.09 * speedRatio
        let targetPitch = smoothedBrake * 0.06 - smoothedThrottle * 0.035
        state.bodyRoll += (targetRoll - state.bodyRoll) * min(1, dtClamped * 9)
        state.bodyPitch += (targetPitch - state.bodyPitch) * min(1, dtClamped * 8)

        // Low-amplitude ride motion for wheel visuals only — not applied 1:1 to chassis height.
        let time = Float(Date().timeIntervalSinceReferenceDate)
        let bump = speedRatio > 0.03
            ? sin(time * 11) * 0.0012 * (0.35 + speedRatio * 0.25)
            : 0
        let compress = smoothedBrake * 0.022 + smoothedThrottle * 0.014 + state.slipAmount * 0.012
        state.suspension = SIMD4<Float>(
            compress + bump,
            compress * 0.9 - bump * 0.5,
            compress + bump * 0.8,
            compress * 0.85 - bump * 0.4
        )
        state.brakeGlow = max(smoothedBrake, min(1, smoothedBrake * 4))

        smoothPowertrainRpm(state: &state, targetRpm: drive.rpm, speedRatio: speedRatio, throttle: smoothedThrottle, nitro: input.nitro)
    }

    /// Returns nitro boost from a perfect manual shift (applied by caller).
    mutating func consumeShiftNitroBoost() -> Float {
        transmission.consumeShiftImpulse().nitroDelta
    }

    private func torqueCurve(speedRatio: Float) -> Float {
        // Progressive pull — strong but not rocket launch; softens near top speed.
        if speedRatio < 0.18 { return 1.05 }
        if speedRatio < 0.45 { return 1.0 - (speedRatio - 0.18) * 0.25 }
        if speedRatio < 0.78 { return 0.9 - (speedRatio - 0.45) * 0.45 }
        return max(0.38, 0.72 - (speedRatio - 0.78) * 1.2)
    }

    private func categoryAccel(_ cat: VehicleCategory) -> Float {
        switch cat {
        case .compact: return 0.96
        case .sports: return 1.0
        case .muscle: return 1.04
        case .supercar: return 1.06
        case .hypercar: return 1.1
        case .policeInterceptor: return 1.0
        }
    }

    private mutating func smoothPowertrainRpm(
        state: inout State,
        targetRpm: Float,
        speedRatio: Float,
        throttle: Float,
        nitro: Bool
    ) {
        var target = targetRpm + throttle * 0.08
        if nitro { target = min(1, target * 1.06) }
        let rpmAlpha: Float = (speedRatio < 0.12 && throttle > 0.05) ? 0.24 : 0.14
        state.rpm += (target - state.rpm) * rpmAlpha
    }
}
