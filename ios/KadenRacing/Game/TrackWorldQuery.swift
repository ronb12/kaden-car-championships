import Foundation
import simd

/// Projects world XZ positions onto the race circuit for open-world driving (lap timing, grip, barriers).
struct TrackWorldQuery {

    struct Projection {
        var center: SIMD3<Float>
        var right: SIMD3<Float>
        var tangent: SIMD3<Float>
        var signedLateral: Float
        var trackT: Float
        var segmentIndex: Int
    }

    private let points: [SIMD3<Float>]
    private let length: Float

    init(track: ClosedTrackSpline, sampleCount: Int = 360) {
        var pts: [SIMD3<Float>] = []
        pts.reserveCapacity(sampleCount)
        for i in 0..<sampleCount {
            let t = Float(i) / Float(sampleCount)
            pts.append(track.sample(t))
        }
        points = pts
        var total: Float = 0
        for i in 0..<pts.count {
            let j = (i + 1) % pts.count
            total += simd_distance(pts[i], pts[j])
        }
        length = max(total, 1)
    }

    var trackLength: Float { length }

    func project(x: Float, z: Float) -> Projection {
        var bestIdx = 0
        var bestDist = Float.greatestFiniteMagnitude
        for i in points.indices {
            let p = points[i]
            let dx = p.x - x
            let dz = p.z - z
            let d = dx * dx + dz * dz
            if d < bestDist {
                bestDist = d
                bestIdx = i
            }
        }

        let i0 = bestIdx
        let i1 = (bestIdx + 1) % points.count
        let p0 = points[i0]
        let p1 = points[i1]
        let seg = p1 - p0
        let segLen = max(0.001, simd_length(SIMD2(seg.x, seg.z)))
        let ux = seg.x / segLen
        let uz = seg.z / segLen
        let vx = x - p0.x
        let vz = z - p0.z
        let along = max(0, min(segLen, vx * ux + vz * uz))
        let cx = p0.x + ux * along
        let cz = p0.z + uz * along
        let rx = -uz
        let rz = ux
        let signedLat = (x - cx) * rx + (z - cz) * rz
        let t = (Float(i0) + along / segLen) / Float(points.count)

        return Projection(
            center: SIMD3<Float>(cx, p0.y, cz),
            right: SIMD3<Float>(rx, 0, rz),
            tangent: SIMD3<Float>(ux, 0, uz),
            signedLateral: signedLat,
            trackT: t.truncatingRemainder(dividingBy: 1),
            segmentIndex: i0
        )
    }

    /// Soft barrier at track edge — returns adjusted position and speed scrub.
    enum ClampProfile {
        /// Stay on the asphalt ribbon.
        case circuit
        /// Leave the racing line into the city apron (courier / free-district).
        case district

        var softEdge: Float {
            switch self {
            case .circuit: return RaceTrackMesh.halfWidth - 1.6
            case .district: return RaceTrackMesh.halfWidth + 42
            }
        }

        var hardEdge: Float {
            switch self {
            case .circuit: return RaceTrackMesh.halfWidth + 0.6
            case .district: return RaceTrackMesh.halfWidth + 64
            }
        }
    }

    func clampToTrack(
        x: Float,
        z: Float,
        speed: Float,
        driftYaw: inout Float,
        profile: ClampProfile = .circuit
    ) -> (x: Float, z: Float, speed: Float, hit: Bool) {
        // Circuit: keep cars on asphalt. District: soft outer bound so courier can leave the ribbon.
        let softEdge = profile.softEdge
        let hardEdge = profile.hardEdge
        let pr = project(x: x, z: z)
        let lat = abs(pr.signedLateral)
        guard lat > softEdge else {
            return (x, z, speed, false)
        }
        let side: Float = pr.signedLateral < 0 ? -1 : 1
        let targetLat = lat > hardEdge ? hardEdge : softEdge
        let nx = pr.center.x + pr.right.x * side * targetLat
        let nz = pr.center.z + pr.right.z * side * targetLat
        let penetration = max(0, lat - softEdge)
        let scrub = max(0.88, 1 - penetration * 0.04)
        if lat > hardEdge {
            driftYaw *= 0.5
        }
        // Only hard scrapes count as impacts — soft edge guidance used to always set hit=true
        // (hardEdge*0.55 < softEdge), which pinned cars against walls with constant speed scrub.
        let hit = lat > hardEdge * 0.92
        return (nx, nz, speed * scrub, hit)
    }

    func gripMultiplier(signedLateralDistance: Float) -> Float {
        let half = RaceTrackMesh.halfWidth
        let d = abs(signedLateralDistance)
        if d <= half { return 1 }
        let off = min(1, (d - half) / 16)
        return max(0.35, 1 - off * 0.68)
    }

    func isHeadingWithTrack(heading: Float, projection: Projection, speed: Float) -> Bool {
        guard abs(speed) > 0.002 else { return true }
        let fx = sin(heading)
        let fz = cos(heading)
        let dot = fx * projection.tangent.x + fz * projection.tangent.z
        return dot >= 0
    }

    /// Strong anti-flow alignment while moving — used for WRONG WAY HUD.
    func isHeadingAgainstTrack(heading: Float, projection: Projection, speed: Float) -> Bool {
        guard abs(speed) > 3.5 else { return false }
        let fx = sin(heading)
        let fz = cos(heading)
        let dot = fx * projection.tangent.x + fz * projection.tangent.z
        return dot < -0.28
    }
}
