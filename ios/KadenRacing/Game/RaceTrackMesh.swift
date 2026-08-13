import SceneKit
import simd
import UIKit

/// Smooth ribbon road along the track spline (web `buildRoadMesh` parity).
enum RaceTrackMesh {

    /// Three full driving lanes (each ~5.3 m wide in world units).
    static let laneCount: Float = 3
    /// Driving surface half-width (~28 m total road).
    static let halfWidth: Float = 14.0
    /// Minimum distance from track centerline to building footprint center.
    static let buildingSetback: Float = halfWidth + 18

    private struct Sample {
        var pos: SIMD3<Float>
        var right: SIMD3<Float>
        var tangent: SIMD3<Float>
    }

    /// Asphalt, lane markings, grass shoulders, and start line (minimal mode).
    static func buildMinimalVisible(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        grassMaterial: SCNMaterial,
        night: Bool = false
    ) {
        let samples = resample(track, count: 520)
        guard samples.count >= 3 else { return }
        let halfW = halfWidth
        let shoulderW: Float = 30
        let asphalt = MinimalRaceEnvironment.visibleAsphaltMaterial(night: night)
        let dashMat = dashMaterial(night: night)
        let laneLineMat = laneLineMaterial(night: night)
        let edgeMat = edgeMaterial(night: night)
        let rumbleRed = rumbleMaterial(red: true, night: night)
        let rumbleWhite = rumbleMaterial(red: false, night: night)

        var roadVerts: [SCNVector3] = []
        var roadIndices: [Int32] = []
        var dashVerts: [SCNVector3] = []
        var dashIndices: [Int32] = []
        var laneLineVerts: [SCNVector3] = []
        var laneLineIndices: [Int32] = []
        var edgeVerts: [SCNVector3] = []
        var edgeIndices: [Int32] = []
        var rumbleRedVerts: [SCNVector3] = []
        var rumbleRedIndices: [Int32] = []
        var rumbleWhiteVerts: [SCNVector3] = []
        var rumbleWhiteIndices: [Int32] = []
        var grassVerts: [SCNVector3] = []
        var grassIndices: [Int32] = []

        for i in 0..<(samples.count - 1) {
            let s0 = samples[i]
            let s1 = samples[i + 1]
            let y0 = s0.pos.y + 0.1
            let y1 = s1.pos.y + 0.1
            let yg0 = s0.pos.y + 0.02
            let yg1 = s1.pos.y + 0.02

            let tl0 = SCNVector3(s0.pos.x + s0.right.x * halfW, y0, s0.pos.z + s0.right.z * halfW)
            let tr0 = SCNVector3(s0.pos.x - s0.right.x * halfW, y0, s0.pos.z - s0.right.z * halfW)
            let bl0 = SCNVector3(s1.pos.x + s1.right.x * halfW, y1, s1.pos.z + s1.right.z * halfW)
            let br0 = SCNVector3(s1.pos.x - s1.right.x * halfW, y1, s1.pos.z - s1.right.z * halfW)
            let base = Int32(roadVerts.count)
            roadVerts.append(contentsOf: [tl0, tr0, bl0, br0])
            roadIndices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])

            for side: Float in [-1, 1] {
                let r0 = side > 0 ? s0.right : -s0.right
                let r1 = side > 0 ? s1.right : -s1.right
                let inner = halfW
                let outer = halfW + shoulderW
                let g0a = SCNVector3(s0.pos.x + r0.x * inner, yg0, s0.pos.z + r0.z * inner)
                let g0b = SCNVector3(s0.pos.x + r0.x * outer, yg0, s0.pos.z + r0.z * outer)
                let g1a = SCNVector3(s1.pos.x + r1.x * inner, yg1, s1.pos.z + r1.z * inner)
                let g1b = SCNVector3(s1.pos.x + r1.x * outer, yg1, s1.pos.z + r1.z * outer)
                let gBase = Int32(grassVerts.count)
                grassVerts.append(contentsOf: [g0a, g0b, g1a, g1b])
                grassIndices.append(contentsOf: [gBase, gBase + 1, gBase + 2, gBase + 1, gBase + 3, gBase + 2])
            }

            if (i / 2) % 4 < 2 {
                let yd0 = s0.pos.y + 0.17
                let yd1 = s1.pos.y + 0.17
                let dw: Float = 0.28
                let d0l = SCNVector3(s0.pos.x + s0.right.x * dw, yd0, s0.pos.z + s0.right.z * dw)
                let d0r = SCNVector3(s0.pos.x - s0.right.x * dw, yd0, s0.pos.z - s0.right.z * dw)
                let d1l = SCNVector3(s1.pos.x + s1.right.x * dw, yd1, s1.pos.z + s1.right.z * dw)
                let d1r = SCNVector3(s1.pos.x - s1.right.x * dw, yd1, s1.pos.z - s1.right.z * dw)
                let dBase = Int32(dashVerts.count)
                dashVerts.append(contentsOf: [d0l, d0r, d1l, d1r])
                dashIndices.append(contentsOf: [dBase, dBase + 1, dBase + 2, dBase + 1, dBase + 3, dBase + 2])
            }

            if (i / 2) % 6 < 2 {
                let laneDivider = halfW / laneCount
                let lw: Float = 0.15
                let yd0 = s0.pos.y + 0.17
                let yd1 = s1.pos.y + 0.17
                for offset: Float in [-laneDivider, laneDivider] {
                    let l0a = SCNVector3(s0.pos.x + s0.right.x * (offset - lw), yd0, s0.pos.z + s0.right.z * (offset - lw))
                    let l0b = SCNVector3(s0.pos.x + s0.right.x * (offset + lw), yd0, s0.pos.z + s0.right.z * (offset + lw))
                    let l1a = SCNVector3(s1.pos.x + s1.right.x * (offset - lw), yd1, s1.pos.z + s1.right.z * (offset - lw))
                    let l1b = SCNVector3(s1.pos.x + s1.right.x * (offset + lw), yd1, s1.pos.z + s1.right.z * (offset + lw))
                    let lBase = Int32(laneLineVerts.count)
                    laneLineVerts.append(contentsOf: [l0a, l0b, l1a, l1b])
                    laneLineIndices.append(contentsOf: [lBase, lBase + 1, lBase + 2, lBase + 1, lBase + 3, lBase + 2])
                }
            }

            let ye0 = s0.pos.y + 0.165
            let ye1 = s1.pos.y + 0.165
            let ew: Float = 0.10
            for edgeOff: Float in [halfW - 0.35, -halfW + 0.35] {
                let e0a = SCNVector3(s0.pos.x + s0.right.x * (edgeOff - ew), ye0, s0.pos.z + s0.right.z * (edgeOff - ew))
                let e0b = SCNVector3(s0.pos.x + s0.right.x * (edgeOff + ew), ye0, s0.pos.z + s0.right.z * (edgeOff + ew))
                let e1a = SCNVector3(s1.pos.x + s1.right.x * (edgeOff - ew), ye1, s1.pos.z + s1.right.z * (edgeOff - ew))
                let e1b = SCNVector3(s1.pos.x + s1.right.x * (edgeOff + ew), ye1, s1.pos.z + s1.right.z * (edgeOff + ew))
                let eBase = Int32(edgeVerts.count)
                edgeVerts.append(contentsOf: [e0a, e0b, e1a, e1b])
                edgeIndices.append(contentsOf: [eBase, eBase + 1, eBase + 2, eBase + 1, eBase + 3, eBase + 2])
            }

            // Asphalt-style red kerb ticks along the ribbon edge.
            if i % 5 == 0 {
                let yr0 = s0.pos.y + 0.14
                let yr1 = s1.pos.y + 0.14
                let rw: Float = 0.28
                let rumbleOff = halfW - 0.22
                for off: Float in [rumbleOff, -rumbleOff] {
                    let r0a = SCNVector3(s0.pos.x + s0.right.x * (off - rw), yr0, s0.pos.z + s0.right.z * (off - rw))
                    let r0b = SCNVector3(s0.pos.x + s0.right.x * (off + rw), yr0, s0.pos.z + s0.right.z * (off + rw))
                    let r1a = SCNVector3(s1.pos.x + s1.right.x * (off - rw), yr1, s1.pos.z + s1.right.z * (off - rw))
                    let r1b = SCNVector3(s1.pos.x + s1.right.x * (off + rw), yr1, s1.pos.z + s1.right.z * (off + rw))
                    let rBase = Int32(rumbleRedVerts.count)
                    rumbleRedVerts.append(contentsOf: [r0a, r0b, r1a, r1b])
                    rumbleRedIndices.append(contentsOf: [rBase, rBase + 1, rBase + 2, rBase + 1, rBase + 3, rBase + 2])
                }
            }
        }

        addMesh(to: parent, vertices: roadVerts, indices: roadIndices, material: asphalt, name: "road")
        addMesh(to: parent, vertices: dashVerts, indices: dashIndices, material: dashMat, name: "dash")
        addMesh(to: parent, vertices: laneLineVerts, indices: laneLineIndices, material: laneLineMat, name: "laneLines")
        // Soft edge + muted kerb only — bright white outer paint was too distracting in chase cam.
        addMesh(to: parent, vertices: edgeVerts, indices: edgeIndices, material: edgeMat, name: "edgeLines")
        addMesh(to: parent, vertices: rumbleRedVerts, indices: rumbleRedIndices, material: rumbleRed, name: "rumbleRed")
        // Skip white rumble halves (keep red kerb ticks only).
        _ = rumbleWhiteVerts
        _ = rumbleWhiteIndices
        addMesh(to: parent, vertices: grassVerts, indices: grassIndices, material: grassMaterial, name: "grassShoulder")
        addMinimalStartFinish(parent: parent, samples: samples, halfW: halfW)
        addMinimalEdgeRails(parent: parent, samples: samples, halfW: halfW)
    }

    /// Low edge rails at the asphalt boundary — gameplay read without city clutter.
    private static func addMinimalEdgeRails(parent: SCNNode, samples: [Sample], halfW: Float) {
        let railMat = SCNMaterial()
        railMat.lightingModel = .physicallyBased
        railMat.diffuse.contents = UIColor(red: 0.28, green: 0.30, blue: 0.32, alpha: 1)
        railMat.metalness.contents = 0.45
        railMat.roughness.contents = 0.55

        for i in stride(from: 0, to: samples.count - 1, by: 10) {
            let s0 = samples[i]
            let s1 = samples[min(i + 4, samples.count - 1)]
            let mid = (s0.pos + s1.pos) * 0.5
            let delta = s1.pos - s0.pos
            let len = max(1.2, simd_length(delta))
            let yaw = atan2(delta.x, delta.z)
            let perp = simd_normalize(SIMD3<Float>(-delta.z, 0, delta.x))

            for side: Float in [-1, 1] {
                let rail = SCNBox(width: 0.22, height: 0.72, length: CGFloat(len), chamferRadius: 0.04)
                let railY: Float = 0.36
                rail.materials = [railMat]
                let railNode = SCNNode(geometry: rail)
                let railOff = perp * (halfW + 0.55) * side
                railNode.position = SCNVector3(mid.x + railOff.x, mid.y + railY, mid.z + railOff.z)
                railNode.eulerAngles.y = yaw
                railNode.castsShadow = true
                parent.addChildNode(railNode)
            }
        }
    }

    /// Flat checkered paint on the road + low posts (no chunky 3D blocks).
    private static func addMinimalStartFinish(parent: SCNNode, samples: [Sample], halfW: Float) {
        guard samples.count >= 2 else { return }
        let s0 = samples[0]
        let s1 = samples[1]
        let forward = SIMD3<Float>(s1.pos.x - s0.pos.x, 0, s1.pos.z - s0.pos.z)
        let fwdLen = max(0.001, simd_length(forward))
        let fwd = forward / fwdLen
        let y = s0.pos.y + 0.115
        let squareW: Float = 0.72
        let depth: Float = 0.55
        let cols = Int((halfW * 2) / squareW)
        let blackMat = SCNMaterial()
        blackMat.lightingModel = .constant
        blackMat.diffuse.contents = UIColor(white: 0.06, alpha: 1)
        let whiteMat = SCNMaterial()
        whiteMat.lightingModel = .constant
        whiteMat.diffuse.contents = UIColor(white: 0.58, alpha: 1)

        var blackVerts: [SCNVector3] = []
        var blackIdx: [Int32] = []
        var whiteVerts: [SCNVector3] = []
        var whiteIdx: [Int32] = []

        for col in 0..<cols {
            let lat = Float(col) * squareW - halfW + squareW * 0.5
            let center = SIMD3<Float>(
                s0.pos.x + s0.right.x * lat,
                y,
                s0.pos.z + s0.right.z * lat
            )
            let r = s0.right
            let halfD = depth * 0.5
            let tl = SCNVector3(center.x - fwd.x * halfD + r.x * squareW * 0.5, y, center.z - fwd.z * halfD + r.z * squareW * 0.5)
            let tr = SCNVector3(center.x + fwd.x * halfD + r.x * squareW * 0.5, y, center.z + fwd.z * halfD + r.z * squareW * 0.5)
            let bl = SCNVector3(center.x - fwd.x * halfD - r.x * squareW * 0.5, y, center.z - fwd.z * halfD - r.z * squareW * 0.5)
            let br = SCNVector3(center.x + fwd.x * halfD - r.x * squareW * 0.5, y, center.z + fwd.z * halfD - r.z * squareW * 0.5)
            if col % 2 == 0 {
                let base = Int32(blackVerts.count)
                blackVerts.append(contentsOf: [tl, tr, bl, br])
                blackIdx.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
            } else {
                let base = Int32(whiteVerts.count)
                whiteVerts.append(contentsOf: [tl, tr, bl, br])
                whiteIdx.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
            }
        }
        addMesh(to: parent, vertices: blackVerts, indices: blackIdx, material: blackMat, name: "startBlack")
        addMesh(to: parent, vertices: whiteVerts, indices: whiteIdx, material: whiteMat, name: "startWhite")

        let postMat = SCNMaterial()
        postMat.lightingModel = .physicallyBased
        postMat.diffuse.contents = UIColor(white: 0.58, alpha: 1)
        postMat.metalness.contents = 0.45
        postMat.roughness.contents = 0.45
        for side: Float in [-1, 1] {
            let postOff = s0.right * (halfW + 1.1) * side
            let post = SCNBox(width: 0.22, height: 2.8, length: 0.22, chamferRadius: 0.04)
            post.materials = [postMat]
            let postNode = SCNNode(geometry: post)
            postNode.position = SCNVector3(s0.pos.x + postOff.x, y + 1.4, s0.pos.z + postOff.z)
            postNode.castsShadow = true
            parent.addChildNode(postNode)
        }
    }

    /// Asphalt ribbon only — no curbs, lines, or barriers.
    static func buildAsphaltOnly(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        definition: CityThemeDefinition,
        night: Bool
    ) {
        let samples = resample(track, count: 520)
        guard samples.count >= 3 else { return }
        let asphalt = EnvironmentMaterialLibrary.asphalt(definition: definition, night: night, wet: false)
        var roadVerts: [SCNVector3] = []
        var roadIndices: [Int32] = []
        let halfW = halfWidth

        for i in 0..<(samples.count - 1) {
            let s0 = samples[i]
            let s1 = samples[i + 1]
            let y0 = s0.pos.y + 0.082
            let y1 = s1.pos.y + 0.082
            let tl0 = SCNVector3(s0.pos.x + s0.right.x * halfW, y0, s0.pos.z + s0.right.z * halfW)
            let tr0 = SCNVector3(s0.pos.x - s0.right.x * halfW, y0, s0.pos.z - s0.right.z * halfW)
            let bl0 = SCNVector3(s1.pos.x + s1.right.x * halfW, y1, s1.pos.z + s1.right.z * halfW)
            let br0 = SCNVector3(s1.pos.x - s1.right.x * halfW, y1, s1.pos.z - s1.right.z * halfW)
            let base = Int32(roadVerts.count)
            roadVerts.append(contentsOf: [tl0, tr0, bl0, br0])
            roadIndices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
        }
        addMesh(to: parent, vertices: roadVerts, indices: roadIndices, material: asphalt, name: "road")
    }

    static func build(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        definition: CityThemeDefinition,
        trackProfile: EnvironmentTrackProfile = .standard,
        night: Bool,
        wet: Bool = false
    ) {
        let samples = resample(track, count: 520)
        guard samples.count >= 3 else { return }

        let halfW = halfWidth
        let asphalt = EnvironmentMaterialLibrary.asphalt(definition: definition, night: night, wet: wet)
        let curbRed = curbMaterial(red: true)
        let curbWhite = curbMaterial(red: false)
        let dashMat = dashMaterial(night: night)
        let laneLineMat = laneLineMaterial(night: night)
        let edgeMat = edgeMaterial(night: night)
        let runOffMat = AssetManager.runoffMaterial(definition: definition, night: night)
        let grassMat = EnvironmentMaterialLibrary.grassTerrain(definition: definition, night: night)
        let barrierMat = PalmCityEnvironment.isActive
            ? palmCityBarrierMaterial(night: night)
            : barrierMaterial(night: night)
        let rumbleRed = rumbleMaterial(red: true, night: night)
        let rumbleWhite = rumbleMaterial(red: false, night: night)

        var roadVerts: [SCNVector3] = []
        var roadIndices: [Int32] = []
        var curbRedVerts: [SCNVector3] = []
        var curbRedIndices: [Int32] = []
        var curbWhiteVerts: [SCNVector3] = []
        var curbWhiteIndices: [Int32] = []
        var dashVerts: [SCNVector3] = []
        var dashIndices: [Int32] = []
        var laneLineVerts: [SCNVector3] = []
        var laneLineIndices: [Int32] = []
        var edgeVerts: [SCNVector3] = []
        var edgeIndices: [Int32] = []
        var rumbleRedVerts: [SCNVector3] = []
        var rumbleRedIndices: [Int32] = []
        var rumbleWhiteVerts: [SCNVector3] = []
        var rumbleWhiteIndices: [Int32] = []
        var grassVerts: [SCNVector3] = []
        var grassIndices: [Int32] = []
        let shoulderW: Float = 22

        for i in 0..<(samples.count - 1) {
            let s0 = samples[i]
            let s1 = samples[i + 1]
            let y0 = s0.pos.y + 0.082
            let y1 = s1.pos.y + 0.082

            let tl0 = SCNVector3(s0.pos.x + s0.right.x * halfW, y0, s0.pos.z + s0.right.z * halfW)
            let tr0 = SCNVector3(s0.pos.x - s0.right.x * halfW, y0, s0.pos.z - s0.right.z * halfW)
            let bl0 = SCNVector3(s1.pos.x + s1.right.x * halfW, y1, s1.pos.z + s1.right.z * halfW)
            let br0 = SCNVector3(s1.pos.x - s1.right.x * halfW, y1, s1.pos.z - s1.right.z * halfW)

            let base = Int32(roadVerts.count)
            roadVerts.append(contentsOf: [tl0, tr0, bl0, br0])
            roadIndices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])

            let yg0 = s0.pos.y + 0.02
            let yg1 = s1.pos.y + 0.02
            for side: Float in [-1, 1] {
                let r0 = side > 0 ? s0.right : -s0.right
                let r1 = side > 0 ? s1.right : -s1.right
                let inner = halfW + 1.2
                let outer = halfW + shoulderW
                let g0a = SCNVector3(s0.pos.x + r0.x * inner, yg0, s0.pos.z + r0.z * inner)
                let g0b = SCNVector3(s0.pos.x + r0.x * outer, yg0, s0.pos.z + r0.z * outer)
                let g1a = SCNVector3(s1.pos.x + r1.x * inner, yg1, s1.pos.z + r1.z * inner)
                let g1b = SCNVector3(s1.pos.x + r1.x * outer, yg1, s1.pos.z + r1.z * outer)
                let gBase = Int32(grassVerts.count)
                grassVerts.append(contentsOf: [g0a, g0b, g1a, g1b])
                grassIndices.append(contentsOf: [gBase, gBase + 1, gBase + 2, gBase + 1, gBase + 3, gBase + 2])
            }

            if i % 5 == 0 {
                let curbW: Float = 1.05
                let curbH: Float = 0.14
                let redStripe = (i / 3) % 2 == 0
                for side: Float in [-1, 1] {
                    let r0 = side > 0 ? s0.right : -s0.right
                    let r1 = side > 0 ? s1.right : -s1.right
                    let inner0 = halfW + 0.02
                    let outer0 = halfW + curbW
                    let c0 = SCNVector3(s0.pos.x + r0.x * inner0, y0, s0.pos.z + r0.z * inner0)
                    let c1 = SCNVector3(s0.pos.x + r0.x * outer0, y0 + curbH, s0.pos.z + r0.z * outer0)
                    let c2 = SCNVector3(s1.pos.x + r1.x * inner0, y1, s1.pos.z + r1.z * inner0)
                    let c3 = SCNVector3(s1.pos.x + r1.x * outer0, y1 + curbH, s1.pos.z + r1.z * outer0)
                    if redStripe {
                        let base = Int32(curbRedVerts.count)
                        curbRedVerts.append(contentsOf: [c0, c1, c2, c3])
                        curbRedIndices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
                    } else {
                        let base = Int32(curbWhiteVerts.count)
                        curbWhiteVerts.append(contentsOf: [c0, c1, c2, c3])
                        curbWhiteIndices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
                    }
                }
            }

            // Dashed center line
            if (i / 2) % 4 < 2 {
                let yd0 = s0.pos.y + 0.19
                let yd1 = s1.pos.y + 0.19
                let dw: Float = 0.26
                let d0l = SCNVector3(s0.pos.x + s0.right.x * dw, yd0, s0.pos.z + s0.right.z * dw)
                let d0r = SCNVector3(s0.pos.x - s0.right.x * dw, yd0, s0.pos.z - s0.right.z * dw)
                let d1l = SCNVector3(s1.pos.x + s1.right.x * dw, yd1, s1.pos.z + s1.right.z * dw)
                let d1r = SCNVector3(s1.pos.x - s1.right.x * dw, yd1, s1.pos.z - s1.right.z * dw)
                let base = Int32(dashVerts.count)
                dashVerts.append(contentsOf: [d0l, d0r, d1l, d1r])
                dashIndices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
            }

            // Dashed lane dividers
            if (i / 2) % 6 < 2 {
                let laneDivider = halfW / laneCount
                let lw: Float = 0.15
                let yd0 = s0.pos.y + 0.19
                let yd1 = s1.pos.y + 0.19
                for offset: Float in [-laneDivider, laneDivider] {
                    let l0a = SCNVector3(s0.pos.x + s0.right.x * (offset - lw), yd0, s0.pos.z + s0.right.z * (offset - lw))
                    let l0b = SCNVector3(s0.pos.x + s0.right.x * (offset + lw), yd0, s0.pos.z + s0.right.z * (offset + lw))
                    let l1a = SCNVector3(s1.pos.x + s1.right.x * (offset - lw), yd1, s1.pos.z + s1.right.z * (offset - lw))
                    let l1b = SCNVector3(s1.pos.x + s1.right.x * (offset + lw), yd1, s1.pos.z + s1.right.z * (offset + lw))
                    let base = Int32(laneLineVerts.count)
                    laneLineVerts.append(contentsOf: [l0a, l0b, l1a, l1b])
                    laneLineIndices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
                }
            }

            // Solid white edge lines
            let ye0 = s0.pos.y + 0.185
            let ye1 = s1.pos.y + 0.185
            let ew: Float = 0.18
            for edgeOff: Float in [halfW - 0.55, -halfW + 0.55] {
                let e0a = SCNVector3(s0.pos.x + s0.right.x * (edgeOff - ew), ye0, s0.pos.z + s0.right.z * (edgeOff - ew))
                let e0b = SCNVector3(s0.pos.x + s0.right.x * (edgeOff + ew), ye0, s0.pos.z + s0.right.z * (edgeOff + ew))
                let e1a = SCNVector3(s1.pos.x + s1.right.x * (edgeOff - ew), ye1, s1.pos.z + s1.right.z * (edgeOff - ew))
                let e1b = SCNVector3(s1.pos.x + s1.right.x * (edgeOff + ew), ye1, s1.pos.z + s1.right.z * (edgeOff + ew))
                let base = Int32(edgeVerts.count)
                edgeVerts.append(contentsOf: [e0a, e0b, e1a, e1b])
                edgeIndices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
            }

            // Rumble strips (alternating red/white at shoulder) — sparse so shoulders stay clean
            if i % 8 == 0 {
                let yr0 = s0.pos.y + 0.13
                let yr1 = s1.pos.y + 0.13
                let rw: Float = 0.32
                let rumbleOff = halfW - 0.35
                let redRumble = (i / 2) % 2 == 0
                for off: Float in [rumbleOff, -rumbleOff] {
                    let r0a = SCNVector3(s0.pos.x + s0.right.x * (off - rw), yr0, s0.pos.z + s0.right.z * (off - rw))
                    let r0b = SCNVector3(s0.pos.x + s0.right.x * (off + rw), yr0, s0.pos.z + s0.right.z * (off + rw))
                    let r1a = SCNVector3(s1.pos.x + s1.right.x * (off - rw), yr1, s1.pos.z + s1.right.z * (off - rw))
                    let r1b = SCNVector3(s1.pos.x + s1.right.x * (off + rw), yr1, s1.pos.z + s1.right.z * (off + rw))
                    if redRumble {
                        let base = Int32(rumbleRedVerts.count)
                        rumbleRedVerts.append(contentsOf: [r0a, r0b, r1a, r1b])
                        rumbleRedIndices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
                    } else {
                        let base = Int32(rumbleWhiteVerts.count)
                        rumbleWhiteVerts.append(contentsOf: [r0a, r0b, r1a, r1b])
                        rumbleWhiteIndices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
                    }
                }
            }

        }

        addMesh(to: parent, vertices: roadVerts, indices: roadIndices, material: asphalt, name: "road", renderingOrder: 0)
        addMesh(to: parent, vertices: curbRedVerts, indices: curbRedIndices, material: curbRed, name: "curbRed", renderingOrder: 1)
        addMesh(to: parent, vertices: curbWhiteVerts, indices: curbWhiteIndices, material: curbWhite, name: "curbWhite", renderingOrder: 1)
        addMesh(to: parent, vertices: dashVerts, indices: dashIndices, material: dashMat, name: "dash", renderingOrder: 2)
        addMesh(to: parent, vertices: laneLineVerts, indices: laneLineIndices, material: laneLineMat, name: "laneLines", renderingOrder: 2)
        addMesh(to: parent, vertices: edgeVerts, indices: edgeIndices, material: edgeMat, name: "edgeLines", renderingOrder: 2)
        addMesh(to: parent, vertices: rumbleRedVerts, indices: rumbleRedIndices, material: rumbleRed, name: "rumbleRed", renderingOrder: 2)
        addMesh(to: parent, vertices: rumbleWhiteVerts, indices: rumbleWhiteIndices, material: rumbleWhite, name: "rumbleWhite", renderingOrder: 2)
        addMesh(to: parent, vertices: grassVerts, indices: grassIndices, material: grassMat, name: "grassShoulder", renderingOrder: -1)

        addRunoffAndBarriers(parent: parent, samples: samples, halfW: halfW, runOff: runOffMat, barrier: barrierMat)
        addStartFinish(parent: parent, samples: samples, halfW: halfW, night: night)
    }

    private static func resample(_ track: ClosedTrackSpline, count: Int) -> [Sample] {
        var out: [Sample] = []
        out.reserveCapacity(count + 1)
        for i in 0..<count {
            let t = Float(i) / Float(count)
            out.append(Sample(
                pos: track.position(at: t),
                right: track.right(at: t),
                tangent: track.tangent(t)
            ))
        }
        if let first = out.first { out.append(first) }
        return out
    }

    private static func addMesh(
        to parent: SCNNode,
        vertices: [SCNVector3],
        indices: [Int32],
        material: SCNMaterial,
        name: String,
        renderingOrder: Int = 0
    ) {
        guard !vertices.isEmpty, !indices.isEmpty else { return }
        let normals = computeNormals(vertices: vertices, indices: indices)
        let src = SCNGeometrySource(vertices: vertices)
        let normSrc = SCNGeometrySource(normals: normals)
        let elem = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [src, normSrc], elements: [elem])
        let mat = material.copy() as? SCNMaterial ?? material
        mat.readsFromDepthBuffer = true
        mat.writesToDepthBuffer = true
        geo.materials = [mat]
        let node = SCNNode(geometry: geo)
        node.name = name
        node.renderingOrder = renderingOrder
        node.castsShadow = false
        parent.addChildNode(node)
    }

    /// Per-triangle normals so PBR asphalt does not blow out to flat white.
    private static func computeNormals(vertices: [SCNVector3], indices: [Int32]) -> [SCNVector3] {
        var accum = Array(repeating: SIMD3<Float>(0, 0, 0), count: vertices.count)
        var i = 0
        while i + 2 < indices.count {
            let i0 = Int(indices[i])
            let i1 = Int(indices[i + 1])
            let i2 = Int(indices[i + 2])
            guard i0 < vertices.count, i1 < vertices.count, i2 < vertices.count else {
                i += 3
                continue
            }
            let v0 = SIMD3<Float>(vertices[i0].x, vertices[i0].y, vertices[i0].z)
            let v1 = SIMD3<Float>(vertices[i1].x, vertices[i1].y, vertices[i1].z)
            let v2 = SIMD3<Float>(vertices[i2].x, vertices[i2].y, vertices[i2].z)
            let face = simd_cross(v1 - v0, v2 - v0)
            accum[i0] += face
            accum[i1] += face
            accum[i2] += face
            i += 3
        }
        return accum.map { n in
            let len = simd_length(n)
            if len < 1e-6 { return SCNVector3(0, 1, 0) }
            let u = n / len
            return SCNVector3(u.x, u.y, u.z)
        }
    }

    private static func addRunoffAndBarriers(
        parent: SCNNode,
        samples: [Sample],
        halfW: Float,
        runOff: SCNMaterial,
        barrier: SCNMaterial
    ) {
        for i in stride(from: 0, to: samples.count - 1, by: 14) {
            let s0 = samples[i]
            let s1 = samples[min(i + 5, samples.count - 1)]
            let mid = (s0.pos + s1.pos) * 0.5
            let delta = s1.pos - s0.pos
            let len = max(1, simd_length(delta))
            let yaw = atan2(delta.x, delta.z)
            let perp = simd_normalize(SIMD3<Float>(-delta.z, 0, delta.x))
            let y = mid.y

            for side: Float in [-1, 1] {
                let apron = SCNBox(width: 5.2, height: 0.14, length: CGFloat(len), chamferRadius: 0.05)
                apron.materials = [runOff]
                let apronNode = SCNNode(geometry: apron)
                let off = perp * (halfW + 5.8) * side
                apronNode.position = SCNVector3(mid.x + off.x, y + 0.03, mid.z + off.z)
                apronNode.eulerAngles.y = yaw
                parent.addChildNode(apronNode)

                let rail = SCNBox(width: 0.28, height: 0.82, length: CGFloat(len), chamferRadius: 0.05)
                rail.materials = [barrier]
                let railNode = SCNNode(geometry: rail)
                let railOff = perp * (halfW + 8.2) * side
                // Sit rails on local track height so they don't float/clip through asphalt.
                railNode.position = SCNVector3(mid.x + railOff.x, mid.y + 0.41, mid.z + railOff.z)
                railNode.eulerAngles.y = yaw
                railNode.castsShadow = true
                parent.addChildNode(railNode)
            }
        }
    }

    private static func addStartFinish(parent: SCNNode, samples: [Sample], halfW: Float, night: Bool) {
        guard samples.count >= 2 else { return }
        let s0 = samples[0]
        let yaw = atan2(s0.tangent.x, s0.tangent.z)
        let y = s0.pos.y + 0.085
        let squareW: CGFloat = 0.85
        let cols = Int((halfW * 2) / Float(squareW))
        for col in 0..<cols {
            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased
            mat.diffuse.contents = col % 2 == 0 ? UIColor.black : UIColor.white
            mat.roughness.contents = 0.45
            let sq = SCNBox(width: squareW, height: 0.025, length: squareW, chamferRadius: 0)
            sq.materials = [mat]
            let node = SCNNode(geometry: sq)
            let lat = Float(col) * Float(squareW) - halfW + Float(squareW) * 0.5
            node.position = SCNVector3(
                s0.pos.x + s0.right.x * lat,
                y,
                s0.pos.z + s0.right.z * lat
            )
            node.eulerAngles.y = yaw
            parent.addChildNode(node)
        }

        // Start/finish gantry
        let postMat = SCNMaterial()
        postMat.lightingModel = .physicallyBased
        postMat.diffuse.contents = UIColor(white: night ? 0.45 : 0.62, alpha: 1)
        postMat.metalness.contents = 0.55
        postMat.roughness.contents = 0.42
        let bannerMat = SCNMaterial()
        bannerMat.lightingModel = .physicallyBased
        // Dark carbon gantry — bright red read as a HUD strip under the status bar at spawn.
        bannerMat.diffuse.contents = UIColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1)
        bannerMat.metalness.contents = 0.72
        bannerMat.roughness.contents = 0.38
        bannerMat.emission.contents = night
            ? UIColor(red: 0.95, green: 0.45, blue: 0.08, alpha: 0.22)
            : UIColor(red: 1, green: 0.55, blue: 0.12, alpha: 0.08)

        for side: Float in [-1, 1] {
            let postOff = s0.right * (halfW + 1.4) * side
            let post = SCNBox(width: 0.32, height: 5.6, length: 0.32, chamferRadius: 0.06)
            post.materials = [postMat]
            let postNode = SCNNode(geometry: post)
            postNode.position = SCNVector3(s0.pos.x + postOff.x, y + 2.8, s0.pos.z + postOff.z)
            postNode.castsShadow = true
            parent.addChildNode(postNode)
        }
        let banner = SCNBox(width: CGFloat(halfW * 2 + 2.8), height: 0.42, length: 0.2, chamferRadius: 0.04)
        banner.materials = [bannerMat]
        let bannerNode = SCNNode(geometry: banner)
        // Place ahead of the start line so chase cam at spawn doesn't frame it as a red HUD bar.
        let ahead = s0.pos + s0.tangent * 6.5
        bannerNode.position = SCNVector3(ahead.x, y + 5.35, ahead.z)
        bannerNode.eulerAngles.y = yaw
        parent.addChildNode(bannerNode)
    }

    private static func duplicateMaterial(_ m: SCNMaterial) -> SCNMaterial {
        m.copy() as? SCNMaterial ?? m
    }

    private static func laneLineMaterial(night: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        // Soft off-white lane paint (Asphalt-style), no glow.
        m.diffuse.contents = UIColor(white: night ? 0.7 : 0.82, alpha: 1)
        m.emission.contents = UIColor.black
        m.isDoubleSided = true
        return m
    }

    private static func curbMaterial(red: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = red
            ? UIColor(red: 0.78, green: 0.12, blue: 0.10, alpha: 1)
            : UIColor(white: 0.72, alpha: 1)
        m.emission.contents = UIColor.black
        m.isDoubleSided = true
        return m
    }

    private static func dashMaterial(night: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        // Centerline — muted yellow like Real Racing / Asphalt.
        m.diffuse.contents = UIColor(red: 0.82, green: 0.72, blue: 0.22, alpha: 1)
        m.emission.contents = UIColor.black
        _ = night
        m.isDoubleSided = true
        return m
    }

    private static func edgeMaterial(night: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        // Thin dark edge — not glowing white outer ribbons.
        m.diffuse.contents = UIColor(white: night ? 0.28 : 0.34, alpha: 1)
        m.emission.contents = UIColor.black
        _ = night
        m.isDoubleSided = true
        return m
    }

    private static func rumbleMaterial(red: Bool, night: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        if red {
            // FIA-style red kerb, saturated but not emissive.
            m.diffuse.contents = UIColor(red: 0.78, green: 0.14, blue: 0.10, alpha: 1)
        } else {
            m.diffuse.contents = UIColor(white: 0.55, alpha: 1)
        }
        m.emission.contents = UIColor.black
        _ = night
        m.isDoubleSided = true
        return m
    }

    private static func barrierMaterial(night: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = KRCProceduralTextures.barrierStripe(night: night)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(4, 1, 1)
        m.metalness.contents = 0.15
        m.roughness.contents = 0.55
        return m
    }

    private static func palmCityBarrierMaterial(night: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = KRCProceduralTextures.jerseyBarrierChevron(night: night)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(3, 1, 1)
        m.metalness.contents = 0.06
        m.roughness.contents = 0.68
        return m
    }
}

// MARK: - Roadside scenery (keep palms/trees off the asphalt ribbon)

enum TrackRoadsideClearance {
    /// Trunk / pole center — just outside drivable asphalt + narrow shoulder.
    static let treeMinLateral: Float = RaceTrackMesh.halfWidth + 10
    /// Palms — fronds hang wide; match building setback.
    static let palmMinLateral: Float = RaceTrackMesh.buildingSetback

    static func footprintRadius(_ node: SCNNode) -> Float {
        let (minB, maxB) = node.boundingBox
        let sx = node.scale.x
        let sz = node.scale.z
        return max((maxB.x - minB.x) * sx, (maxB.z - minB.z) * sz) * 0.5
    }

    static func closestFrame(
        to pos: SIMD3<Float>,
        track: ClosedTrackSpline
    ) -> (t: Float, center: SIMD3<Float>, right: SIMD3<Float>) {
        let samples = 96
        var bestT: Float = 0
        var bestD = Float.greatestFiniteMagnitude
        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let p = track.position(at: t)
            let d = simd_distance(SIMD2(pos.x, pos.z), SIMD2(p.x, p.z))
            if d < bestD {
                bestD = d
                bestT = t
            }
        }
        return (bestT, track.position(at: bestT), track.right(at: bestT))
    }

    /// Push scenery so its footprint stays outside the road (handles Kenney anchors + curve chords).
    static func pushOutsideRoad(
        _ node: SCNNode,
        track: ClosedTrackSpline,
        minLateral: Float,
        extraFootprint: Float = 0
    ) {
        let footprint = max(footprintRadius(node), extraFootprint)
        let minCenterDist = minLateral + footprint

        let pos = SIMD3<Float>(node.position.x, 0, node.position.z)
        let (_, center, right) = closestFrame(to: pos, track: track)
        let delta = pos - SIMD3<Float>(center.x, 0, center.z)
        var lateral = simd_dot(SIMD2(delta.x, delta.z), SIMD2(right.x, right.z))

        if abs(lateral) < minCenterDist {
            lateral = lateral >= 0 ? minCenterDist : -minCenterDist
            node.position.x = center.x + right.x * lateral
            node.position.z = center.z + right.z * lateral
        }
    }
}
