import Foundation
import simd

/// Spline-based AAA-style vehicle dynamics — torque curves, grip, drift, suspension visuals,
/// weight transfer, downforce, ABS/TCS, and wall interaction. Optimized for 60 Hz mobile.
struct VehicleDrivingSimulation {

    static let topLapSpeed: Float = 0.095
    static let kmhPerSpeedUnit: Float = 2600

    struct Config {
        let stats: CarRuntimeStats
        let difficultyGripMul: Float
        let category: VehicleCategory
        let surfaceGrip: Float
        let cornerSeverity: Float
        let maxLateral: Float
    }

    struct InputSample {
        var throttle: Float
        var brake: Float
        var steer: Float
        var handbrake: Float
        var nitro: Bool
    }

    struct State {
        var speed: Float = 0
        var lateral: Float = 0
        var lateralVelocity: Float = 0
        var yawOffset: Float = 0
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
        var absPulse: Float = 0
        var downforce: Float = 0
    }

    struct FrameOutput {
        let state: State
        let trackAdvance: Float
    }

    private var smoothedSteer: Float = 0
    private var smoothedThrottle: Float = 0
    private var smoothedBrake: Float = 0
    private var brakeHeat: Float = 0
    private var weightRear: Float = 0.5

    mutating func reset(lateral: Float = 0, speed: Float = 0) {
        smoothedSteer = 0
        smoothedThrottle = 0
        smoothedBrake = 0
        brakeHeat = 0
        weightRear = 0.5
    }

    mutating func step(
        state: inout State,
        input: InputSample,
        config: Config,
        dt: Float
    ) -> FrameOutput {
        let dtClamped = min(1 / 30, max(0.0001, dt))
        let prefs = VehicleDrivingPreferences.self
        let manual = prefs.manualControl

        // —— Input smoothing — lighter in manual mode for direct NFS-style response ——
        let steerTarget = max(-1, min(1, input.steer))
        let steerAlpha = min(1, dtClamped * ((manual ? 14 : 8) + abs(steerTarget) * (manual ? 6 : 4)))
        smoothedSteer += (steerTarget - smoothedSteer) * steerAlpha

        let throttleTarget = max(0, min(1, input.throttle))
        let brakeTarget = max(0, min(1, input.brake))
        let inputRate = manual ? 18.0 : 10.0
        smoothedThrottle += (throttleTarget - smoothedThrottle) * min(1, dtClamped * Float(inputRate))
        smoothedBrake += (brakeTarget - smoothedBrake) * min(1, dtClamped * Float(inputRate + 4))

        let handbrake = max(0, min(1, input.handbrake))

        let nitroMul: Float = input.nitro ? 1.22 : 1
        let topSpeed = Self.topLapSpeed * config.stats.topSpeedMul * nitroMul
        let reverseCap = topSpeed * 0.34
        let speedRatio = min(1, abs(state.speed) / max(0.001, topSpeed))
        let movingForward = state.speed >= 0

        // —— Longitudinal: torque curve + wheelspin + braking + drag ——
        let categoryAccel = categoryAccelBoost(config.category)
        let torque = torqueCurve(speedRatio: speedRatio) * config.stats.accelMul * categoryAccel

        var driveForce = smoothedThrottle * torque * 0.078
        if smoothedThrottle > 0.2 && speedRatio < 0.22 {
            state.wheelSpin = min(1, state.wheelSpin + dtClamped * 3.2)
            let spinLoss = state.wheelSpin * (1 - prefs.tractionControl * 0.65)
            driveForce *= max(0.35, 1 - spinLoss * 0.55)
        } else {
            state.wheelSpin = max(0, state.wheelSpin - dtClamped * 4.5)
        }

        if prefs.tractionControl > 0.05 && speedRatio > 0.55 && abs(smoothedSteer) > 0.35 {
            driveForce *= max(0.82, 1 - prefs.tractionControl * 0.12 * speedRatio)
        }

        var brakeForce = smoothedBrake * (0.11 + prefs.brakeAssist * 0.018)
        brakeHeat = min(1, brakeHeat + smoothedBrake * dtClamped * 0.9)
        brakeHeat = max(0, brakeHeat - dtClamped * 0.35)
        let fade = max(0.72, 1 - brakeHeat * 0.28)
        brakeForce *= fade

        // ABS pulse under hard braking
        if smoothedBrake > 0.65 && speedRatio > 0.08 {
            state.absPulse = 0.5 + 0.5 * sin(Float(Date().timeIntervalSinceReferenceDate) * 42)
            brakeForce *= 0.88 + state.absPulse * 0.1
        } else {
            state.absPulse = max(0, state.absPulse - dtClamped * 6)
        }

        weightRear += (smoothedThrottle - smoothedBrake) * dtClamped * 2.4
        weightRear = max(0.38, min(0.62, weightRear))

        let nearStop = abs(state.speed) < topSpeed * 0.05
        let wantsReverse: Bool
        if state.speed < -0.001 {
            wantsReverse = smoothedBrake > 0.08 && smoothedThrottle < 0.28
        } else {
            wantsReverse = nearStop && smoothedBrake > 0.22 && smoothedThrottle < 0.12
        }

        if wantsReverse && smoothedBrake > 0.08 {
            let reverseForce = smoothedBrake * torque * 0.048
            state.speed -= reverseForce * dtClamped
        } else {
            state.speed += (driveForce - brakeForce) * dtClamped
        }

        let drag = 0.0065 + speedRatio * speedRatio * 0.014
        if movingForward || state.speed > 0 {
            state.speed -= drag * dtClamped
        } else {
            state.speed += drag * dtClamped
        }
        state.downforce = speedRatio * speedRatio * 0.42
        state.speed = min(max(state.speed, -reverseCap), topSpeed * (1 + state.downforce * 0.02))

        // —— Lateral: grip, drift, steering assist, downforce stability ——
        let gripBase = config.stats.gripMul * config.difficultyGripMul * config.surfaceGrip
        let downforceGrip = 1 + state.downforce * 0.48
        var grip = gripBase * downforceGrip * (1 - config.cornerSeverity * 0.16)

        let speedSteerScale = max(manual ? 0.56 : 0.32, 1 - speedRatio * (manual ? 0.38 : 0.66))
        var steerAuthority = smoothedSteer * (manual ? 8.8 : 7.2) * speedSteerScale * grip

        if prefs.steeringAssist > 0.01 {
            let centering = -state.lateral * prefs.steeringAssist * (0.9 + speedRatio * 0.4)
            steerAuthority += centering * min(1, dtClamped * 5)
        }

        state.lateralVelocity += steerAuthority * dtClamped
        state.lateralVelocity -= state.lateralVelocity * min(1, dtClamped * (2.7 + grip * 1.75))

        let slip = min(1, abs(state.lateralVelocity) / max(0.02, state.speed + 0.04))
        state.slipAmount = slip

        let driftThreshold: Float = handbrake > 0.12 ? 0.18 : 0.38
        let handbrakeDrift = handbrake > 0.15 && speedRatio > 0.08
        let steerDrift = abs(smoothedSteer) > 0.32 && speedRatio > 0.22
        let wantsDrift = handbrakeDrift || (steerDrift && slip > driftThreshold)
        if wantsDrift && (handbrakeDrift || slip > driftThreshold) {
            let assist = prefs.driftAssist
            let hbMul = handbrakeDrift ? (0.38 + handbrake * 0.35) : 1
            grip *= max(0.32, 1 - slip * (0.62 - assist * 0.2) * hbMul)
            state.isDrifting = true
            let yawRate: Float = handbrakeDrift
                ? (1.6 + handbrake * 2.2 + assist)
                : (1.8 + assist)
            state.yawOffset += smoothedSteer * max(slip, handbrake * 0.45) * dtClamped * yawRate
            state.driftMultiplier = min(5, state.driftMultiplier + dtClamped * 0.85)
            state.driftScoreRate = 42 * state.driftMultiplier * max(slip, handbrake * 0.35)
        } else {
            state.isDrifting = false
            state.driftMultiplier = max(1, state.driftMultiplier - dtClamped * 1.15)
            state.driftScoreRate = 0
            state.yawOffset *= max(0, 1 - dtClamped * 4.5)
        }
        state.yawOffset = max(-0.55, min(0.55, state.yawOffset))

        state.lateral += state.lateralVelocity * dtClamped

        // —— Wall / barrier interaction ——
        let wallStart = config.maxLateral * 0.88
        if abs(state.lateral) > wallStart {
            let over = abs(state.lateral) - wallStart
            let sign: Float = state.lateral > 0 ? 1 : -1
            state.lateral = sign * wallStart
            state.lateralVelocity *= max(0, 1 - over * 8 * dtClamped)
            let scrape = min(1, over * 3.5)
            state.speed *= max(0.88, 1 - scrape * 0.06 * dtClamped * 60)
            state.impactImpulse = max(state.impactImpulse, scrape * 0.65)
        }
        state.impactImpulse = max(0, state.impactImpulse - dtClamped * 2.8)

        state.lateral = max(-config.maxLateral, min(config.maxLateral, state.lateral))

        // —— Body / suspension visuals ——
        let latNorm = state.lateral / max(1, config.maxLateral)
        let targetRoll = -latNorm * 0.16 - smoothedSteer * 0.055 * speedRatio
        let targetPitch = smoothedBrake * 0.09 - smoothedThrottle * 0.048 + config.cornerSeverity * 0.035
        state.bodyRoll += (targetRoll - state.bodyRoll) * min(1, dtClamped * 10)
        state.bodyPitch += (targetPitch - state.bodyPitch) * min(1, dtClamped * 9)

        let time = Float(Date().timeIntervalSinceReferenceDate)
        let bump = sin(time * 13) * 0.0022 * (0.4 + speedRatio * 0.35)
        let compress = smoothedBrake * 0.03 + smoothedThrottle * 0.018 + slip * 0.016
        state.suspension.x = compress + bump
        state.suspension.y = compress * 0.9 - bump * 0.5
        state.suspension.z = compress + bump * 0.8
        state.suspension.w = compress * 0.85 - bump * 0.4

        state.brakeGlow = max(smoothedBrake, min(1, brakeForce * 4 + state.absPulse * 0.25))

        // —— RPM / gear for audio ——
        updatePowertrain(state: &state, speedRatio: speedRatio, throttle: smoothedThrottle, nitro: input.nitro)

        return FrameOutput(state: state, trackAdvance: state.speed * dtClamped)
    }

    // MARK: - Helpers

    private func torqueCurve(speedRatio: Float) -> Float {
        if speedRatio < 0.15 { return 1.12 }
        if speedRatio < 0.45 { return 1.05 - speedRatio * 0.2 }
        if speedRatio < 0.78 { return 0.88 - (speedRatio - 0.45) * 0.35 }
        return max(0.42, 0.72 - (speedRatio - 0.78) * 1.1)
    }

    private func categoryAccelBoost(_ cat: VehicleCategory) -> Float {
        switch cat {
        case .compact: return 1.02
        case .sports: return 1.06
        case .muscle: return 1.1
        case .supercar: return 1.08
        case .hypercar: return 1.12
        case .policeInterceptor: return 1.04
        }
    }

    private mutating func updatePowertrain(state: inout State, speedRatio: Float, throttle: Float, nitro: Bool) {
        let gearBands: [Float] = [0, 0.14, 0.28, 0.44, 0.62, 0.8]
        var g = 1
        for i in 1..<gearBands.count where speedRatio >= gearBands[i] { g = i + 1 }
        state.gear = min(6, g)

        let gearNorm = Float(state.gear) / 6
        let targetRPM = 0.25 + throttle * 0.55 + speedRatio * 0.35 + gearNorm * 0.08
        let rpmTarget = nitro ? min(1, targetRPM * 1.08) : targetRPM
        state.rpm += (rpmTarget - state.rpm) * 0.14
    }
}

enum VehicleSurfaceGrip {

    static func multiplier(
        terrain: TerrainVariant,
        weather: EnvironmentLightingSystem.WeatherMode,
        lateral: Float,
        maxLateral: Float
    ) -> Float {
        var g: Float = 1
        switch terrain {
        case .flat, .coastal, .stepped: g = 1
        case .rolling: g = 0.96
        case .canyon: g = 0.93
        }
        switch weather {
        case .night: g *= 0.97
        case .sunset: g *= 0.99
        case .day: break
        }
        let edge = abs(lateral) / max(1, maxLateral)
        if edge > 0.72 {
            let off = min(1, (edge - 0.72) / 0.28)
            g *= max(0.48, 1 - off * 0.52)
        }
        return g
    }
}

enum VehicleCornering {

    static func severity(track: ClosedTrackSpline, t: Float) -> Float {
        let t0 = t.truncatingRemainder(dividingBy: 1)
        let t1 = (t0 + 0.02).truncatingRemainder(dividingBy: 1)
        let tan1 = track.tangent(t0)
        let tan2 = track.tangent(t1)
        return max(0, min(1, 1 - simd_dot(simd_normalize(tan1), simd_normalize(tan2))))
    }
}
