import Foundation
import simd

/// **Coastal City Circuit** — ocean highway, skyline straights, mountain esses, tunnel-friendly layout.
enum CoastalCityCircuitTrack {

    private static let scale: Float = 2.5

    static func makeTrack() -> ClosedTrackSpline {
        let segments = 160
        var points: [SIMD3<Float>] = []
        points.reserveCapacity(segments)

        for i in 0..<segments {
            let t = Float(i) / Float(segments) * 2 * Float.pi
            let p = sample(t: t)
            points.append(SIMD3<Float>(p.x * scale, p.y * 1.6, p.z * scale))
        }
        return ClosedTrackSpline(points: points)
    }

    /// Ocean-side highway loop with downtown straight, mountain esses, and bridge-friendly sweep.
    private static func sample(t: Float) -> (x: Float, y: Float, z: Float) {
        let s = sin(t)
        let c = cos(t)

        // Horseshoe coastal leg + long waterfront straight (z-dominant sweep).
        let x = s * 92 + sin(2 * t) * 22 + cos(3 * t) * 8
        let z = c * 68 * (1 + 0.38 * sin(2 * t)) + sin(4 * t) * 10

        // Road itself climbs and drops — no extra dirt mounds.
        let y = 8.5 * sin(t - 0.4) + 3.2 * sin(2.15 * t) + 1.4 * cos(3.05 * t)

        return (x, y, z)
    }

    /// Normalized 0…1 sectors for tunnel / bridge / downtown placement along the loop.
    enum Sector: CaseIterable {
        case oceanHighway
        case downtown
        case mountain
        case industrial
        case tunnel
        case bridge

        static func at(trackT: Float) -> Sector {
            let u = trackT - floor(trackT)
            switch u {
            case 0.05..<0.28: return .oceanHighway
            case 0.28..<0.42: return .downtown
            case 0.42..<0.58: return .mountain
            case 0.58..<0.72: return .tunnel
            case 0.72..<0.86: return .bridge
            default: return .industrial
            }
        }
    }
}
