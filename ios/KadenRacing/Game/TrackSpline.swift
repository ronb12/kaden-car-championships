import Foundation
import simd

struct ClosedTrackSpline {
    let points: [SIMD3<Float>]

    init(points: [SIMD3<Float>]) {
        var pts = points.count >= 2 ? points : [
            SIMD3<Float>(-40, 0, -40),
            SIMD3<Float>(40, 0, -40),
            SIMD3<Float>(40, 0, 40),
            SIMD3<Float>(-40, 0, 40)
        ]
        // Valleys stay above the ground disc so the ribbon can climb and drop without clipping.
        let minY = pts.map(\.y).min() ?? 0
        if minY < 0.4 {
            let lift = 0.4 - minY
            for i in pts.indices { pts[i].y += lift }
        }
        self.points = pts
    }

    func sample(_ t: Float) -> SIMD3<Float> {
        let u = normalized(t) * Float(points.count)
        let i0 = Int(floor(u)) % points.count
        let i1 = (i0 + 1) % points.count
        let f = u - floor(u)
        return simd_mix(points[i0], points[i1], SIMD3<Float>(repeating: f))
    }

    func tangent(_ t: Float) -> SIMD3<Float> {
        let p0 = sample(t - 0.002)
        let p1 = sample(t + 0.002)
        let d = p1 - p0
        let len = simd_length(d)
        return len > 0.0001 ? d / len : SIMD3<Float>(0, 0, 1)
    }

    func position(at t: Float) -> SIMD3<Float> {
        sample(t)
    }

    func right(at t: Float) -> SIMD3<Float> {
        let forward = tangent(t)
        let side = SIMD3<Float>(forward.z, 0, -forward.x)
        let len = simd_length(side)
        return len > 0.0001 ? side / len : SIMD3<Float>(1, 0, 0)
    }

    private func normalized(_ t: Float) -> Float {
        var v = t.truncatingRemainder(dividingBy: 1)
        if v < 0 { v += 1 }
        return v
    }
}
