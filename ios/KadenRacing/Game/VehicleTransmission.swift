import Foundation

/// Arcade auto / manual gearbox (parity with web `transmissionDrive` + `shiftManualGear`).
enum TransmissionMode: String, Codable, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: return "Automatic"
        case .manual: return "Manual"
        }
    }
}

struct VehicleTransmission {

    struct DriveParams {
        var gear: Int = 1
        var effectiveTopSpeed: Float = 1
        var accelMul: Float = 1
        var rpm: Float = 0.35
    }

    private static let gearTopFractions: [Float] = [0, 0.20, 0.38, 0.56, 0.73, 0.89, 1.0]
    private static let gearAccelMul: [Float] = [0, 1.34, 1.22, 1.10, 1.0, 0.92, 0.86]
    private static let autoShiftKmh: [Float] = [0, 48, 96, 148, 205, 262]

    private var playerGear = 1
    private var shiftLockout: Float = 0
    private var shiftBoost: Float = 0
    private var shiftPenalty: Float = 0
    private var shiftUpHeld = false
    private var shiftDownHeld = false

    private(set) var displayNotice: String?
    private var noticeTimer: Float = 0

    mutating func reset() {
        playerGear = 1
        shiftLockout = 0
        shiftBoost = 0
        shiftPenalty = 0
        shiftUpHeld = false
        shiftDownHeld = false
        displayNotice = nil
        noticeTimer = 0
    }

    mutating func tick(
        dt: Float,
        speed: Float,
        maxTopSpeed: Float,
        throttle: Float,
        shiftUp: Bool,
        shiftDown: Bool,
        mode: TransmissionMode
    ) -> DriveParams {
        if noticeTimer > 0 {
            noticeTimer = max(0, noticeTimer - dt)
            if noticeTimer <= 0 { displayNotice = nil }
        }
        shiftLockout = max(0, shiftLockout - dt)
        shiftBoost = max(0, shiftBoost - dt)
        shiftPenalty = max(0, shiftPenalty - dt)

        let kmh = abs(speed) * OpenWorldDrivingSimulation.worldUnitsToKmh
        let reversing = speed < -0.5

        if reversing {
            return DriveParams(
                gear: 0,
                effectiveTopSpeed: max(0.001, maxTopSpeed * 0.35),
                accelMul: 0.75,
                rpm: 0.32
            )
        }

        if mode == .manual, !reversing {
            if shiftUp, !shiftUpHeld { tryShift(direction: 1, kmh: kmh, speed: speed) }
            if shiftDown, !shiftDownHeld { tryShift(direction: -1, kmh: kmh, speed: speed) }
        }
        shiftUpHeld = shiftUp
        shiftDownHeld = shiftDown

        var gear: Int
        if reversing {
            gear = 0
        } else if mode == .manual {
            gear = playerGear
        } else {
            gear = Self.automaticGear(kmh: kmh)
            playerGear = gear
        }

        let drive = Self.driveParams(
            gear: max(1, min(6, gear)),
            speed: speed,
            maxTopSpeed: maxTopSpeed,
            throttle: throttle,
            manual: mode == .manual,
            shiftBoost: shiftBoost,
            shiftPenalty: shiftPenalty
        )
        storeRpmPct(drive.rpm * 100)
        return drive
    }

    private mutating func tryShift(direction: Int, kmh: Float, speed: Float) {
        guard shiftLockout <= 0 else { return }
        let old = playerGear
        let next = max(1, min(6, playerGear + direction))
        if next == old {
            displayNotice = direction > 0 ? "TOP GEAR" : "1ST GEAR"
            noticeTimer = 0.55
            return
        }
        playerGear = next
        shiftLockout = 0.12

        let rpmPct = lastRpmPct

        if direction > 0, rpmPct >= 76, rpmPct <= 94 {
            shiftBoost = 0.85
            shiftPenalty = 0
            pendingSpeedDelta = speed * 0.018
            pendingNitroDelta = 0.10
            displayNotice = "PERFECT SHIFT"
        } else if direction > 0, rpmPct < 52, kmh > 4 {
            shiftPenalty = 0.55
            pendingSpeedDelta = speed * -0.04
            pendingNitroDelta = 0
            displayNotice = "SHORT SHIFT"
        } else if direction < 0, rpmPct > 82, kmh > 7 {
            shiftPenalty = 0.75
            pendingSpeedDelta = speed * -0.10
            pendingNitroDelta = 0
            displayNotice = "OVER-REV"
        } else {
            pendingSpeedDelta = 0
            pendingNitroDelta = 0
            displayNotice = direction > 0 ? "UPSHIFT" : "DOWNSHIFT"
        }
        noticeTimer = 0.9
    }

    private var lastRpmPct: Float = 35
    private var pendingSpeedDelta: Float = 0
    private var pendingNitroDelta: Float = 0

    mutating func consumeShiftImpulse() -> (speedDelta: Float, nitroDelta: Float) {
        let s = pendingSpeedDelta
        let n = pendingNitroDelta
        pendingSpeedDelta = 0
        pendingNitroDelta = 0
        return (s, n)
    }

    private static func automaticGear(kmh: Float) -> Int {
        if kmh < 2 { return 1 }
        var g = 1
        for i in 1..<autoShiftKmh.count where kmh >= autoShiftKmh[i] {
            g = i + 1
        }
        return min(6, g)
    }

    private static func driveParams(
        gear: Int,
        speed: Float,
        maxTopSpeed: Float,
        throttle: Float,
        manual: Bool,
        shiftBoost: Float,
        shiftPenalty: Float
    ) -> DriveParams {
        let g = max(1, min(6, gear))
        let prevCap = g <= 1 ? 0 : maxTopSpeed * gearTopFractions[g - 1]
        let gearCap = max(3, maxTopSpeed * gearTopFractions[g])
        let band = max(1, gearCap - prevCap)
        let absSpd = abs(speed)
        let bandPct = max(0, min(1, (absSpd - prevCap) / band))
        let launchBog: Float = g > 1 && absSpd < prevCap * 0.56
            ? max(0.58, absSpd / max(1, prevCap * 0.56))
            : 1
        let redlineDrag: Float = manual && bandPct > 0.98 ? 0.82 : 1
        let boost: Float = shiftBoost > 0 ? 1.08 : 1
        let penalty: Float = shiftPenalty > 0 ? 0.78 : 1
        let accel = gearAccelMul[g] * launchBog * redlineDrag * boost * penalty
        let effectiveTop = manual ? min(maxTopSpeed, gearCap) : maxTopSpeed
        let rpm = max(0.1, min(1, (18 + bandPct * 82) / 100))
        return DriveParams(
            gear: g,
            effectiveTopSpeed: effectiveTop,
            accelMul: accel,
            rpm: rpm
        )
    }

    mutating func storeRpmPct(_ pct: Float) {
        lastRpmPct = pct
    }

    var isShiftZone: Bool {
        VehicleDrivingPreferences.transmissionMode == .manual
            && lastRpmPct >= 76
            && lastRpmPct <= 94
    }
}
