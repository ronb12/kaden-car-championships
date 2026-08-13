import Foundation
import simd

/// Hand-authored closed circuits — parity with web `TRACK_DEFS` / `buildClosedPoints`.
/// Each catalog index uses a **distinct** layout family (not the same radius-wobble oval).
enum CatalogTrackGenerator {

    private static let scale: Float = 1.45

    static func makeTrack(index: Int) -> ClosedTrackSpline {
        if PalmCityEnvironment.isActive, !MinimalRaceEnvironment.isEnabled {
            return PalmCityRacewayTracks.makeTrack(index: index)
        }
        let trackCount = GameCatalog.tracks.count
        let idx = ((index % trackCount) + trackCount) % trackCount
        if idx == EnvironmentTrackProfile.coastalCityCircuitTrackIndex {
            return CoastalCityCircuitTrack.makeTrack()
        }
        let segments = segmentCount(for: idx)
        var points: [SIMD3<Float>] = []
        points.reserveCapacity(segments)
        for i in 0..<segments {
            let t = Float(i) / Float(segments) * 2 * Float.pi
            let p = sample(index: idx, t: t)
            points.append(SIMD3<Float>(p.x * scale, 0, p.z * scale))
        }
        return ClosedTrackSpline(points: points)
    }

    private static func segmentCount(for index: Int) -> Int {
        switch index {
        case 3, 18, 24, 39, 44: return 64
        case 4, 9, 10, 15, 19, 25, 30, 31, 45, 47, 48: return 96
        case 5, 6, 12, 21, 26, 27, 42: return 90
        case 7, 11, 13, 16, 17, 28, 32, 33, 34, 35, 37, 41, 46, 49: return 88
        default: return 80
        }
    }

    private static func superellipse(t: Float, a: Float, b: Float, exp: Float) -> (x: Float, z: Float) {
        let c = cos(t)
        let s = sin(t)
        let x = a * (c >= 0 ? 1 : -1) * pow(abs(c), exp)
        let z = b * (s >= 0 ? 1 : -1) * pow(abs(s), exp)
        return (x, z)
    }

    private static func lemniscate(t: Float, a: Float, squeeze: Float = 1) -> (x: Float, z: Float) {
        let s = sin(t)
        let c = cos(t)
        let denom = 1 + squeeze * s * s
        return (a * c / denom, a * s * c / denom)
    }

    private static func sample(index: Int, t: Float) -> (x: Float, z: Float) {
        let s = sin(t)
        let c = cos(t)
        switch index {
        case 0:
            return (s * 85 + sin(2 * t) * 28, c * 62 + cos(3 * t) * 16)
        case 1:
            return (s * 108, c * 48)
        case 2:
            return (s * 48, c * 102)
        case 3:
            let r: Float = 78
            return (s * r, c * r)
        case 4:
            return superellipse(t: t, a: 92, b: 52, exp: 0.34)
        case 5:
            return (70 * c + 36 * cos(3 * t), 70 * s - 36 * sin(3 * t))
        case 6:
            return (74 * c + 32 * cos(5 * t), 74 * s + 32 * sin(5 * t))
        case 7:
            return (s * 88 + 14 * sin(3 * t), c * 58 * (1 + 0.42 * sin(2 * t)))
        case 8:
            return (s * 128, c * 44)
        case 9:
            return superellipse(t: t, a: 58, b: 58, exp: 0.22)
        case 10:
            return lemniscate(t: t, a: 105)
        case 11:
            return (s * 72, s * 2 * 38 + c * 34)
        case 12:
            return (78 * c + 30 * cos(6 * t), 78 * s + 30 * sin(6 * t))
        case 13:
            return (s * (68 + 24 * cos(5 * t)) + 22 * sin(7 * t), c * (74 + 16 * sin(4 * t)))
        case 14:
            return (85 * c + 28 * cos(3 * t), 56 * s)
        case 15:
            return (85 * c * abs(c), 85 * s * abs(s))
        case 16:
            return (s * 90 + cos(3 * t) * 20, c * 55 + sin(5 * t) * 12)
        case 17:
            return (s * 92, c * 68 + sin(6 * t) * 14)
        case 18:
            return (s * 54, c * 50)
        case 19:
            return (s * 102 + sin(2 * t) * 22, c * 72 + cos(3 * t) * 20)
        case 21:
            return (72 * c + 22 * cos(4 * t) + 14 * sin(7 * t), 70 * s + 20 * sin(5 * t))
        case 22:
            return (115 * c + 14 * cos(8 * t), 42 * s + 8 * sin(8 * t))
        case 23:
            return (s * (55 + 30 * cos(4 * t)), c * (95 + 12 * sin(3 * t)))
        case 24:
            return (65 * c + 35 * cos(2 * t), 65 * s + 35 * sin(2 * t))
        case 25:
            return superellipse(t: t, a: 88, b: 88, exp: 0.28)
        case 26:
            return (68 * c + 40 * cos(4 * t), 68 * s - 40 * sin(4 * t))
        case 27:
            return (70 * c + 34 * cos(7 * t), 70 * s + 34 * sin(7 * t))
        case 28:
            return (90 * c + 35 * cos(2 * t), 50 * s * (1 + 0.5 * c))
        case 29:
            return (s * 135, c * 40)
        case 30:
            return superellipse(t: t, a: 52, b: 52, exp: 0.18)
        case 31:
            return lemniscate(t: t, a: 88, squeeze: 0.8)
        case 32:
            return (75 * c + 45 * cos(3 * t + Float.pi / 6), 60 * s + 25 * sin(2 * t))
        case 33:
            return (s * (80 + 28 * abs(sin(4 * t))), c * (65 + 20 * cos(5 * t)))
        case 34:
            return (60 * c + 25 * sin(8 * t), 88 * s + 18 * cos(6 * t))
        case 35:
            return (78 * c + 32 * cos(2 * t), 62 * s + 24 * sin(4 * t))
        case 36:
            return (80 * c * abs(c) + 20 * sin(4 * t), 80 * s * abs(s) + 20 * cos(4 * t))
        case 37:
            return (s * 82 + 30 * sin(5 * t) + 15 * cos(7 * t), c * 60 + 22 * sin(3 * t))
        case 38:
            return (s * 98, c * 62 + 28 * sin(8 * t))
        case 39:
            return (s * 48, c * 44)
        case 40:
            return (s * 95 + 25 * sin(3 * t), c * 78 + 20 * cos(4 * t))
        case 41:
            return (s * 80 + 35 * sin(2 * t), c * 55 + 25 * cos(4 * t))
        case 42:
            return (s * 118 + 20 * cos(3 * t), c * 38 + 10 * sin(2 * t))
        case 43:
            return (s * 52 + 18 * sin(6 * t), c * 98 + 14 * cos(5 * t))
        case 44:
            return (s * 112, c * 42 + 6 * sin(4 * t))
        case 45:
            return superellipse(t: t, a: 70, b: 48, exp: 0.25)
        case 46:
            return (s * 88 + 24 * cos(4 * t), c * 52 + 18 * sin(6 * t))
        case 47:
            return (92 * c + 18 * cos(9 * t), 48 * s + 14 * sin(9 * t))
        case 48:
            return (68 * c + 36 * cos(8 * t), 68 * s + 36 * sin(8 * t))
        case 49:
            return (88 * c + 22 * cos(5 * t), 70 * s + 40 * sin(2 * t) + 20 * cos(3 * t))
        default:
            let phase = Float(index) * 0.61
            let lobes = 3 + (index % 5)
            return (
                75 * c + 28 * cos(Float(lobes) * t + phase),
                75 * s + 28 * sin(Float(lobes + 1) * t - phase)
            )
        }
    }
}
