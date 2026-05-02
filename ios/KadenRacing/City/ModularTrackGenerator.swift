import Foundation
import simd

/// Builds a **single closed centerline** from a theme + seed (no 30 hand-made tracks).
/// Uses frequency-shaped oval distortion + optional elevation — `ClosedTrackSpline` stays the source of truth for racing.
enum ModularTrackGenerator {

    static func makeTrack(definition: CityThemeDefinition, seed: UInt64) -> ClosedTrackSpline {
        var rng = SeededRandom(seed: seed)
        let n = max(64, min(192, definition.trackResolution))
        let a = definition.semiMajor * rng.float(in: 0.9...1.1)
        let b = definition.semiMinor * rng.float(in: 0.9...1.1)

        var phases: [Float] = []
        phases.reserveCapacity(definition.curvatureComplexity)
        for i in 0..<definition.curvatureComplexity {
            phases.append(rng.float(in: 0...(2 * Float.pi)) + Float(i) * 0.35)
        }
        var amps: [Float] = []
        for i in 0..<definition.curvatureComplexity {
            let decay = 1 / Float(i + 1)
            amps.append(0.02 * decay * rng.float(in: 0.35...1.4))
        }

        var points: [SIMD3<Float>] = []
        points.reserveCapacity(n)
        for i in 0..<n {
            let u = Float(i) / Float(n) * 2 * Float.pi
            var rip: Float = 0
            for k in 0..<definition.curvatureComplexity {
                let w = Float(k + 1)
                rip += amps[k] * cos(w * u + phases[k])
            }
            let er = 1 + rip
            var x = cos(u) * a * er
            var z = sin(u) * b * er
            if definition.terrain == .coastal {
                x += 0.08 * a * sin(2.1 * u)
            }
            let y = elevationY(u: u, definition: definition)
            points.append(SIMD3<Float>(x, y, z))
        }
        return ClosedTrackSpline(points: points)
    }

    private static func elevationY(u: Float, definition: CityThemeDefinition) -> Float {
        let s = definition.elevationScale
        switch definition.terrain {
        case .flat:
            return s * 0.02 * sin(3 * u)
        case .rolling:
            return s * (0.12 * sin(2 * u) + 0.05 * sin(5 * u + 0.3))
        case .stepped:
            return s * 0.15 * floor(0.5 + 0.5 * sin(1.7 * u))
        case .coastal:
            return s * 0.08 * sin(1.2 * u) * sin(0.5 * u)
        case .canyon:
            return s * (0.18 * sin(1.4 * u) - 0.04 * sin(4.2 * u))
        }
    }

    /// Produces a **module ring** for metadata (decor batching, future nav graphs) — same seed as track.
    static func moduleRing(definition: CityThemeDefinition, seed: UInt64, segmentCount: Int) -> [RoadModuleKind] {
        var rng = SeededRandom(seed: seed &+ 0x0D15F1D0D15F1D0)
        let kinds = definition.sortedRoadKindsByWeight()
        var out: [RoadModuleKind] = []
        out.reserveCapacity(segmentCount)
        for _ in 0..<segmentCount {
            let roll = rng.unitFloat()
            var acc: Float = 0
            let total: Float = kinds.reduce(0) { $0 + definition.roadWeights[$1, default: 0] }
            var chosen = kinds.first ?? .straight
            for k in kinds {
                acc += definition.roadWeights[k, default: 0] / max(total, 1e-4)
                if roll <= acc {
                    chosen = k
                    break
                }
            }
            out.append(chosen)
        }
        return out
    }
}

private extension CityThemeDefinition {
    func sortedRoadKindsByWeight() -> [RoadModuleKind] {
        roadWeights.keys.sorted { (roadWeights[$0] ?? 0) > (roadWeights[$1] ?? 0) }
    }
}
