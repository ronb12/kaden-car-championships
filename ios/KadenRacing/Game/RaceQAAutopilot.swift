import Foundation
import SceneKit
import simd

#if DEBUG
/// Simulator / CI helper — follows the track spline in the **race direction** (+t, same as CPU racers).
/// Disable with env `RACE_QA_DRIVE=0`; force on device with `RACE_QA_DRIVE=1` or `-qaDrive`.
enum RaceQAAutopilot {

    private static var smoothedSteer: Float = 0
    /// Forward-integrated lap parameter (nearest-point projection can jump backward on loops).
    private static var drivenT: Float = 0
    private static var hasDrivenT = false
    private static var raceTime: Float = 0
    /// Preferred lateral offset on the racing line (weaves / apex cuts).
    private static var lineBias: Float = 0
    private static var tipPhase: Int = 0
    private static var tipPhaseTimer: Float = 0
    private static var tipLogged = false

    static func reset() {
        smoothedSteer = 0
        drivenT = 0
        hasDrivenT = false
        raceTime = 0
        lineBias = 0
        tipPhase = 0
        tipPhaseTimer = 0
        tipLogged = false
    }

    /// `-qaNitroTest` — drive + engage N2O for a few seconds so we can confirm boost/drain.
    static var nitroTest: Bool {
        ProcessInfo.processInfo.arguments.contains("-qaNitroTest")
    }

    /// `-qaCourierTip` — snap through one real pickup→drop to verify Customer Tip Moments.
    static var tipProbe: Bool {
        ProcessInfo.processInfo.arguments.contains("-qaCourierTip")
    }

    /// **Off by default.** Autopilot runs ONLY when explicitly opted in:
    /// - launch argument `-qaDrive`, or
    /// - launch argument `-qaNitroTest`, or
    /// - launch argument `-qaCourierTip`, or
    /// - environment `RACE_QA_DRIVE=1` (and not a sticky env on other `-qa*` launches)
    ///
    /// Normal play, Quick Race, `-qaRace`, and `-qaTapTest -qaRace` are always manual.
    /// `RACE_QA_DRIVE=0` always forces off.
    static var enabled: Bool {
        let env = ProcessInfo.processInfo.environment["RACE_QA_DRIVE"]
        if env == "0" { return false }

        let args = ProcessInfo.processInfo.arguments
        // Exact arg only — never treat `-qaRace` / `-qaTapTest` as drive.
        if args.contains("-qaDrive") || args.contains("-qaNitroTest") || args.contains("-qaCourierTip") {
            return true
        }

        if env == "1" {
            // Sticky simctl `setenv RACE_QA_DRIVE=1` must not auto-drive `-qaRace` sessions.
            let hasOtherQaFlags = args.contains { $0.hasPrefix("-qa") && $0 != "-qaDrive" }
            return !hasOtherQaFlags
        }
        return false
    }

    /// Steer along increasing track parameter (race direction); recover if facing backward.
    static func apply(
        input: RaceInput,
        state: inout OpenWorldDrivingSimulation.State,
        track: ClosedTrackSpline,
        trackQuery: TrackWorldQuery,
        projection: TrackWorldQuery.Projection,
        maxSpeed: Float,
        dt: Float
    ) {
        let speedRatio = min(1, state.speed / max(1, maxSpeed))
        let projT = projection.trackT.truncatingRemainder(dividingBy: 1)
        raceTime += dt
        // Autopilot should race, not hold a drift score — kill slide so chase cam stays road-aligned.
        state.driftYaw *= max(0, 1 - dt * 10)
        state.isDrifting = false
        state.driftScoreRate = 0
        state.driftMultiplier = 1
        state.slipAmount *= max(0, 1 - dt * 6)

        if !hasDrivenT {
            drivenT = projT
            hasDrivenT = true
        }

        let trackForward = simd_normalize(SIMD2<Float>(projection.tangent.x, projection.tangent.z))
        let trackHeading = atan2(projection.tangent.x, projection.tangent.z)

        let carForward = SIMD2<Float>(sin(state.heading), cos(state.heading))
        let alongTrack = simd_dot(carForward, trackForward)

        let trackLen = max(1, trackQuery.trackLength)
        if alongTrack > 0.2, state.speed > 0.5 {
            drivenT = (drivenT + state.speed * dt / trackLen).truncatingRemainder(dividingBy: 1)
        }
        let wrapDist = min(abs(drivenT - projT), 1 - abs(drivenT - projT))
        if wrapDist < 0.1 {
            drivenT = projT
        }

        let tNorm = alongTrack > 0.25 ? drivenT : projT

        // Near-term curvature only — far probes made the car turn/brake before the corner.
        func curvature(at t: Float, span: Float) -> Float {
            let tanA = track.tangent(t.truncatingRemainder(dividingBy: 1))
            let tanB = track.tangent((t + span).truncatingRemainder(dividingBy: 1))
            let a = simd_normalize(SIMD3<Float>(tanA.x, 0, tanA.z))
            let b = simd_normalize(SIMD3<Float>(tanB.x, 0, tanB.z))
            return max(0, min(1, 1 - simd_dot(a, b)))
        }
        let imminentCorner = curvature(at: tNorm, span: 0.008)
        let entryCorner = curvature(at: tNorm, span: 0.014)
        // Distant preview is informational only — never primary aim/brake trigger.
        let farCorner = curvature(at: tNorm, span: 0.04)

        // Aim further into bends so QA doesn't plow straight off the outside.
        let lookaheadT = 0.008 + imminentCorner * 0.018 + entryCorner * 0.01
        let lookT = (tNorm + lookaheadT).truncatingRemainder(dividingBy: 1)
        let lookTan = track.tangent(lookT)
        let lookHeading = atan2(lookTan.x, lookTan.z)
        let previewBlend = min(0.55, 0.16 + imminentCorner * 1.1 + entryCorner * 0.35)
        var aimHeading = trackHeading
        if previewBlend > 0 {
            var dh = lookHeading - trackHeading
            while dh > .pi { dh -= 2 * .pi }
            while dh < -.pi { dh += 2 * .pi }
            aimHeading += dh * previewBlend
        }
        if alongTrack < 0 {
            aimHeading = trackHeading + .pi
        }

        // Hold near centerline on straights; mild apex only at true turn entry.
        let desiredLine: Float = imminentCorner > 0.22
            ? -0.1 * imminentCorner
            : sin(raceTime * 0.18) * 0.06
        lineBias += (desiredLine - lineBias) * min(1, dt * 1.1)

        let halfW = max(1, RaceTrackMesh.halfWidth * 0.72)
        let lateralNorm = projection.signedLateral / halfW
        let targetLatNorm = lineBias
        let latErr = lateralNorm - targetLatNorm
        let wallPressure = min(1, max(0, abs(lateralNorm) - 0.55) / 0.45)
        // Lateral correction for walls only — don't yaw the car into an early apex cut.
        aimHeading -= latErr * (0.12 + wallPressure * 0.7)

        var headingErr = aimHeading - state.heading
        while headingErr > .pi { headingErr -= 2 * .pi }
        while headingErr < -.pi { headingErr += 2 * .pi }

        let wrongWay = alongTrack < -0.22
        if wrongWay || (state.speed < maxSpeed * 0.1 && alongTrack < 0.15) {
            aimHeading = trackHeading
            headingErr = aimHeading - state.heading
            while headingErr > .pi { headingErr -= 2 * .pi }
            while headingErr < -.pi { headingErr += 2 * .pi }
        }
        if wrongWay || state.speed < maxSpeed * 0.08 {
            state.heading = trackHeading
            headingErr = 0
            smoothedSteer = 0
        }

        // Follow track heading + lane center. Strong turn-in — Harbor Loop was running wide.
        let steerGain = 1.55 + imminentCorner * 1.4
        var steerAim = max(-1, min(1, headingErr * steerGain))
        if abs(headingErr) < 0.015 { steerAim = 0 }
        let centerGain = 1.05 + wallPressure * 1.2
        let steerCenter = max(-1, min(1, -latErr * centerGain))
        let centerBlend = wallPressure > 0.04
            ? min(0.85, 0.32 + wallPressure * 0.55)
            : (imminentCorner > 0.1 ? 0.34 : 0.16)
        var steerTarget = max(-1, min(1, steerAim * (1 - centerBlend) + steerCenter * centerBlend))
        // Bias toward the inside of the bend (cross of forward × look).
        if imminentCorner > 0.08 || entryCorner > 0.12 {
            let a = trackForward
            let b = simd_normalize(SIMD2<Float>(lookTan.x, lookTan.z))
            let cross = a.x * b.y - a.y * b.x
            let insideSign: Float = cross >= 0 ? -1 : 1
            steerTarget = max(-1, min(1, steerTarget + insideSign * min(0.35, imminentCorner * 0.9 + entryCorner * 0.45)))
        }
        // Only freeze hands on a true straight — never into an approaching bend.
        if imminentCorner < 0.045, entryCorner < 0.08, abs(latErr) < 0.2 {
            steerTarget = max(-0.1, min(0.1, steerTarget * 0.3))
        }
        let steerAlpha = min(1, dt * (6.5 + imminentCorner * 5.5))
        smoothedSteer += (steerTarget - smoothedSteer) * steerAlpha
        input.steer = smoothedSteer
        input.left = false
        input.right = false

        if wrongWay {
            input.gas = true
            input.throttle = 0.7
            input.brake = false
            input.brakeAmount = 0
            input.handbrake = false
            input.handbrakeAmount = 0
            input.nitro = false
            input.steer = 0
            drivenT = projT
            if state.speed < maxSpeed * 0.25 {
                state.speed = max(state.speed, maxSpeed * 0.28)
            }
            return
        }

        // Brake only for imminent/entry curvature — ignore farCorner so we don't scrub early.
        let hairpin = imminentCorner > 0.28 || entryCorner > 0.34
        let offLine = abs(latErr) > 0.45
        let againstWall = abs(lateralNorm) > 0.92
        let brakeForCorner = hairpin
            || (imminentCorner > 0.16 && speedRatio > 0.6)
            || (entryCorner > 0.22 && speedRatio > 0.72 && imminentCorner > 0.1)
            || (offLine && speedRatio > 0.5 && !againstWall && imminentCorner > 0.08)

        if againstWall {
            input.gas = true
            input.throttle = 0.55
            input.brake = false
            input.brakeAmount = 0
            if state.speed < maxSpeed * 0.18 {
                state.speed = max(state.speed, maxSpeed * 0.22)
            }
        } else {
            input.gas = !brakeForCorner
            input.throttle = brakeForCorner ? 0 : (hairpin ? 0.55 : (offLine ? 0.68 : 0.92))
            input.brake = brakeForCorner
            input.brakeAmount = brakeForCorner
                ? min(1, 0.32 + imminentCorner * 0.5 + abs(latErr) * 0.25)
                : 0
        }
        input.handbrake = false
        input.handbrakeAmount = 0
        // Nitro probe: keep road steering (above). Hold N2O; trail-brake into real corners.
        if nitroTest, raceTime > 2.0, raceTime < 7.0 {
            input.nitro = true
            if brakeForCorner {
                input.gas = imminentCorner < 0.22
                input.throttle = imminentCorner < 0.22 ? 0.45 : 0
            } else {
                input.gas = true
                input.throttle = 1
                input.brake = false
                input.brakeAmount = 0
            }
            if state.speed < maxSpeed * 0.4 {
                state.speed = max(state.speed, maxSpeed * 0.42)
            }
        } else {
            input.nitro = false
        }
        _ = farCorner

        if state.speed < maxSpeed * 0.12 {
            let crawl = maxSpeed * 0.22
            if state.speed < crawl {
                state.speed += (crawl - state.speed) * min(1, dt * 1.8)
            }
        }
    }

    /// Pull toward the active courier pad / dwell when `-qaDrive` is running a courier shift.
    static func applyCourierSeek(
        input: RaceInput,
        state: inout OpenWorldDrivingSimulation.State,
        bearing: Float,
        distance: Float,
        inZone: Bool,
        carrying: Bool,
        reverseHint: Bool,
        dt: Float
    ) {
        guard distance > 0.5 || inZone else { return }

        if inZone {
            // Stop in the bay; reverse briefly for reverse-park bonus when dropping.
            input.gas = false
            input.throttle = 0
            input.brake = true
            input.brakeAmount = 0.95
            input.nitro = false
            if reverseHint, carrying {
                input.reverse = true
                input.brake = false
                input.brakeAmount = 0
                input.gas = true
                input.throttle = 0.35
                state.speed = min(state.speed, 4)
            } else {
                input.reverse = false
                state.speed *= max(0, 1 - dt * 4)
            }
            return
        }

        // Blend toward pad when off the racing line (pads sit outside the apron).
        var headingErr = bearing
        let pi = Float.pi
        while headingErr > pi { headingErr -= 2 * pi }
        while headingErr < -pi { headingErr += 2 * pi }
        let pull: Float
        if distance < 55 {
            pull = 0.85
        } else if distance < 120 {
            pull = 0.55
        } else {
            pull = 0.28
        }
        let padSteer = max(Float(-1), min(Float(1), headingErr * 1.35))
        let steerBlend = min(Float(1), dt * (4 + pull * 4))
        smoothedSteer += (padSteer - smoothedSteer) * steerBlend
        let mixed = input.steer * (1 - pull) + smoothedSteer * pull
        input.steer = max(Float(-1), min(Float(1), mixed))

        if distance < 28 {
            input.gas = true
            input.throttle = 0.42
            let slowing = state.speed > 14
            input.brake = slowing
            input.brakeAmount = slowing ? 0.45 : 0
            input.nitro = false
        } else if distance < 70 {
            input.gas = true
            input.throttle = 0.7
            input.brake = false
            input.brakeAmount = 0
        }
    }

    /// Teleport / drive inputs for the tip probe (call BEFORE courier.update).
    static func applyCourierTipProbe(
        input: RaceInput,
        state: inout OpenWorldDrivingSimulation.State,
        carNode: SCNNode?,
        pad: (x: Float, z: Float, y: Float)?,
        carrying: Bool,
        deliveries: Int,
        tipsEarned: Int64,
        lastTip: Int64,
        tipFlash: Float,
        inZone: Bool,
        dt: Float
    ) {
        guard tipProbe else { return }
        tipPhaseTimer += dt
        input.nitro = false
        input.steer = 0
        input.left = false
        input.right = false
        _ = carrying
        _ = deliveries
        _ = tipsEarned
        _ = lastTip
        _ = tipFlash
        _ = inZone

        if tipPhase == 0 {
            guard let pad else { return }
            state.worldX = pad.x
            state.worldZ = pad.z
            state.speed = 0
            input.gas = false
            input.throttle = 0
            input.brake = true
            input.brakeAmount = 1
            input.reverse = false
            carNode?.position.y = pad.y + 0.35
            return
        }

        if tipPhase == 1 {
            state.worldX += 28 * dt
            state.worldZ += 18 * dt
            state.speed = 10
            input.gas = true
            input.throttle = 0.5
            input.brake = false
            input.brakeAmount = 0
            input.reverse = false
            return
        }

        if tipPhase == 2 {
            guard let pad else { return }
            state.worldX = pad.x
            state.worldZ = pad.z
            state.speed = -2.2
            input.gas = true
            input.throttle = 0.35
            input.brake = false
            input.brakeAmount = 0
            input.reverse = true
            carNode?.position.y = pad.y + 0.35
            return
        }

        // tipPhase 3 — hold for screenshot
        state.speed = 0
        input.gas = false
        input.throttle = 0
        input.brake = true
        input.brakeAmount = 1
        input.reverse = false
    }

    /// Advance tip-probe phases using the snapshot AFTER courier.update.
    static func advanceCourierTipProbe(
        carrying: Bool,
        deliveries: Int,
        tipsEarned: Int64,
        lastTip: Int64,
        tipFlash: Float,
        dt: Float
    ) {
        guard tipProbe else { return }
        if tipPhase == 0, carrying {
            tipPhase = 1
            tipPhaseTimer = 0
            print("[QATip] loaded — clearing grace")
            return
        }
        if tipPhase == 1, tipPhaseTimer >= 1.2 {
            tipPhase = 2
            tipPhaseTimer = 0
            print("[QATip] rolling to drop")
            return
        }
        if tipPhase == 2, deliveries >= 1 || (lastTip > 0 && tipFlash > 0.2) {
            tipPhase = 3
            tipPhaseTimer = 0
            print("[QATip] drop complete tipsEarned=\(tipsEarned) lastTip=\(lastTip) flash=\(tipFlash)")
            return
        }
        if tipPhase == 3 {
            tipPhaseTimer += dt
            if !tipLogged, tipsEarned > 0, lastTip > 0 {
                tipLogged = true
                print("[QATip] PASS customer tip moment tipsTotal=\(tipsEarned) last=+\(lastTip)")
            } else if !tipLogged, tipPhaseTimer > 4, tipsEarned == 0 {
                tipLogged = true
                print("[QATip] FAIL no tip credited after drop")
            }
        }
    }
}
#endif
