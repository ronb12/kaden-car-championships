import Foundation
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

    static func reset() {
        smoothedSteer = 0
        drivenT = 0
        hasDrivenT = false
        raceTime = 0
        lineBias = 0
    }

    /// **Off by default.** Autopilot runs ONLY when explicitly opted in:
    /// - launch argument `-qaDrive`, or
    /// - environment `RACE_QA_DRIVE=1` (and not a sticky env on other `-qa*` launches)
    ///
    /// Normal play, Quick Race, `-qaRace`, and `-qaTapTest -qaRace` are always manual.
    /// `RACE_QA_DRIVE=0` always forces off.
    static var enabled: Bool {
        let env = ProcessInfo.processInfo.environment["RACE_QA_DRIVE"]
        if env == "0" { return false }

        let args = ProcessInfo.processInfo.arguments
        // Exact arg only — never treat `-qaRace` / `-qaTapTest` as drive.
        if args.contains("-qaDrive") { return true }

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

        // Late turn-in: aim at *current* tangent. Only a tiny nose-ahead blend once the
        // corner is under the car — never steer toward a bend that is still far ahead.
        let lookaheadT = imminentCorner > 0.1
            ? (0.003 + imminentCorner * 0.006)
            : 0.002
        let lookT = (tNorm + lookaheadT).truncatingRemainder(dividingBy: 1)
        let lookTan = track.tangent(lookT)
        let lookHeading = atan2(lookTan.x, lookTan.z)
        let previewBlend = imminentCorner > 0.14
            ? min(0.28, imminentCorner * 0.55)
            : 0
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

        // Follow track heading; lane-center only when scraping. Dead-zone tiny heading errors.
        let steerGain = 0.85 + imminentCorner * 0.7
        var steerAim = max(-1, min(1, headingErr * steerGain))
        if abs(headingErr) < 0.04 { steerAim = 0 }
        let centerGain = 0.55 + wallPressure * 1.1
        let steerCenter = max(-1, min(1, -latErr * centerGain))
        let centerBlend = wallPressure > 0.05
            ? min(0.75, 0.25 + wallPressure * 0.55)
            : (imminentCorner > 0.18 ? 0.15 : 0.08)
        var steerTarget = max(-1, min(1, steerAim * (1 - centerBlend) + steerCenter * centerBlend))
        // Hard gate: on a straight with a corner still ahead, keep hands nearly straight.
        if imminentCorner < 0.1 && entryCorner < 0.16 {
            steerTarget *= 0.2
            if abs(latErr) < 0.4 { steerTarget = max(-0.15, min(0.15, steerTarget)) }
        }
        let steerAlpha = min(1, dt * (3.6 + imminentCorner * 3))
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
        input.nitro = false
        _ = farCorner

        if state.speed < maxSpeed * 0.12 {
            let crawl = maxSpeed * 0.22
            if state.speed < crawl {
                state.speed += (crawl - state.speed) * min(1, dt * 1.8)
            }
        }
    }
}
#endif
