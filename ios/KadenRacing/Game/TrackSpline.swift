import simd

/// Closed-loop centerline in XZ (y up). Arc-length sampling for racing along \(t \in [0,1)\).
struct ClosedTrackSpline {
    let points: [SIMD3<Float>]
    private let segLens: [Float]
    let totalLength: Float

    init(points: [SIMD3<Float>]) {
        precondition(points.count >= 3)
        self.points = points
        var lens: [Float] = []
        lens.reserveCapacity(points.count)
        var total: Float = 0
        for i in 0..<points.count {
            let a = points[i]
            let b = points[(i + 1) % points.count]
            let dx = b.x - a.x
            let dz = b.z - a.z
            let len = sqrt(dx * dx + dz * dz)
            lens.append(len)
            total += len
        }
        self.segLens = lens
        self.totalLength = max(total, 1e-3)
    }

    static func oval(semiMajor: Float, semiMinor: Float, segments: Int) -> ClosedTrackSpline {
        var pts: [SIMD3<Float>] = []
        pts.reserveCapacity(segments)
        for i in 0..<segments {
            let u = Float(i) / Float(segments) * 2 * Float.pi
            let x = cos(u) * semiMajor
            let z = sin(u) * semiMinor
            pts.append(SIMD3<Float>(x, 0, z))
        }
        return ClosedTrackSpline(points: pts)
    }

    /// Unit tangent along the loop (uses full 3D delta so **hills** don’t fight camera / AI).
    func tangent(at t: Float) -> SIMD3<Float> {
        let wrapped = t - floor(t)
        let s = wrapped * totalLength
        let (i, _) = segment(atArcLength: s)
        let a = points[i]
        let b = points[(i + 1) % points.count]
        let d = b - a
        let len = simd_length(d)
        guard len > 1e-4 else { return SIMD3<Float>(0, 0, 1) }
        return d / len
    }

    func position(at t: Float) -> SIMD3<Float> {
        let wrapped = t - floor(t)
        let s = wrapped * totalLength
        let (i, frac) = segment(atArcLength: s)
        let a = points[i]
        let b = points[(i + 1) % points.count]
        return SIMD3<Float>(
            a.x + (b.x - a.x) * frac,
            0,
            a.z + (b.z - a.z) * frac
        )
    }

    func right(at t: Float) -> SIMD3<Float> {
        let tan = tangent(at: t)
        var up = SIMD3<Float>(0, 1, 0)
        if abs(tan.y) > 0.85 {
            up = simd_normalize(SIMD3<Float>(0, 0, 1))
        }
        var r = simd_cross(up, tan)
        if simd_length_squared(r) < 1e-8 {
            r = simd_cross(SIMD3<Float>(1, 0, 0), tan)
        }
        r = simd_normalize(r)
        if abs(r.x) < 1e-4, abs(r.y) < 1e-4, abs(r.z) < 1e-4 {
            return SIMD3<Float>(1, 0, 0)
        }
        return r
    }

    private func segment(atArcLength s: Float) -> (Int, Float) {
        var acc: Float = 0
        for i in 0..<segLens.count {
            let sl = segLens[i]
            if acc + sl >= s - 1e-5 {
                let local = sl > 1e-6 ? (s - acc) / sl : 0
                return (i, min(1, max(0, local)))
            }
            acc += sl
        }
        let last = segLens.count - 1
        return (last, 1)
    }
}
