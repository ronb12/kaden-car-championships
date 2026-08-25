import SceneKit
import simd
import UIKit

/// Smooth ribbon road along the track spline (web `buildRoadMesh` parity).
enum RaceTrackMesh {

    /// Gantry / ground sign text at the shared start–finish line.
    enum StartFinishSignPhase {
        case start
        case finish

        var title: String {
            switch self {
            case .start: return "START"
            case .finish: return "FINISH"
            }
        }
    }

    /// Three full driving lanes (each ~5.3 m wide in world units).
    static let laneCount: Float = 3
    /// Driving surface half-width (~28 m total road).
    static let halfWidth: Float = 14.0
    /// Minimum distance from track centerline to building footprint center.
    static let buildingSetback: Float = halfWidth + 18

    private static var cachedBannerTextures: [String: UIImage] = [:]
    private static var cachedGroundTextures: [String: UIImage] = [:]

    /// Swap START ↔ FINISH on gantry banners and the ground title once the field clears the line.
    static func setStartFinishSignPhase(_ phase: StartFinishSignPhase, in root: SCNNode) {
        let banner = bannerTexture(title: phase.title)
        let ground = groundTitleTexture(title: phase.title)
        root.enumerateChildNodes { node, _ in
            let name = node.name ?? ""
            guard let mat = node.geometry?.firstMaterial else { return }
            if name == "sfFinishBannerApproach" || name == "sfFinishBannerGrid" {
                mat.diffuse.contents = banner
                mat.emission.contents = banner
            } else if name == "sfGroundFinish" {
                mat.diffuse.contents = ground
                mat.emission.contents = ground
            }
        }
    }

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
        let grassW: Float = 6

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
                let outer = halfW + grassW
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
        addStartFinishComplex(parent: parent, samples: samples, halfW: halfW, night: night)
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

    /// Shared start/finish complex — deep checkers, approach chevrons, side boards, and a FINISH gantry.
    private static func addStartFinishComplex(
        parent: SCNNode,
        samples: [Sample],
        halfW: Float,
        night: Bool
    ) {
        guard samples.count >= 4 else { return }
        let s0 = samples[0]
        let fwd = simd_normalize(SIMD3<Float>(s0.tangent.x, 0, s0.tangent.z))
        let right = s0.right
        let yaw = atan2(fwd.x, fwd.z)
        let yPaint = s0.pos.y + 0.118
        let root = SCNNode()
        root.name = "krcStartFinish"
        parent.addChildNode(root)

        addCheckeredZone(
            into: root,
            origin: s0.pos,
            forward: fwd,
            right: right,
            halfW: halfW,
            y: yPaint,
            rows: 6,
            square: 1.15
        )
        addFinishGroundTitle(
            into: root,
            origin: s0.pos,
            forward: fwd,
            right: right,
            halfW: halfW,
            y: yPaint
        )
        addFinishApproachChevrons(
            into: root,
            samples: samples,
            halfW: halfW,
            y: yPaint
        )
        addFinishSideBoards(
            into: root,
            origin: s0.pos,
            forward: fwd,
            right: right,
            halfW: halfW,
            y: yPaint,
            night: night
        )
        addFinishGantry(
            into: root,
            origin: s0.pos,
            forward: fwd,
            right: right,
            halfW: halfW,
            y: yPaint,
            yaw: yaw,
            night: night,
            showBanner: true
        )
        // Depth gate past the line — checkered only so banners don't stack/z-fight.
        addFinishGantry(
            into: root,
            origin: s0.pos + fwd * 8.0,
            forward: fwd,
            right: right,
            halfW: halfW,
            y: yPaint,
            yaw: yaw,
            night: night,
            showBanner: false
        )
        addFinishApproachGates(
            into: root,
            samples: samples,
            halfW: halfW,
            y: yPaint,
            night: night
        )
    }

    /// Wide multi-row checkers so the line reads from chase cam and overhead grid views.
    private static func addCheckeredZone(
        into parent: SCNNode,
        origin: SIMD3<Float>,
        forward: SIMD3<Float>,
        right: SIMD3<Float>,
        halfW: Float,
        y: Float,
        rows: Int,
        square: Float
    ) {
        let blackMat = SCNMaterial()
        blackMat.lightingModel = .constant
        blackMat.diffuse.contents = UIColor(white: 0.05, alpha: 1)
        blackMat.emission.contents = UIColor(white: 0.04, alpha: 1)
        let whiteMat = SCNMaterial()
        whiteMat.lightingModel = .constant
        whiteMat.diffuse.contents = UIColor(white: 0.98, alpha: 1)
        whiteMat.emission.contents = UIColor(white: 0.55, alpha: 1)

        let cols = max(10, Int((halfW * 2) / square))
        let yaw = atan2(forward.x, forward.z)
        // Raised tiles — flat paint z-fights asphalt and vanishes in chase cam.
        for row in 0..<rows {
            let along = (Float(row) - Float(rows - 1) * 0.5) * square
            for col in 0..<cols {
                let lat = Float(col) * square - halfW + square * 0.5
                let center = origin + forward * along + right * lat
                let isBlack = (row + col) % 2 == 0
                let tile = SCNBox(
                    width: CGFloat(square * 0.96),
                    height: 0.08,
                    length: CGFloat(square * 0.96),
                    chamferRadius: 0
                )
                tile.materials = [isBlack ? blackMat : whiteMat]
                let node = SCNNode(geometry: tile)
                node.position = SCNVector3(center.x, y + 0.04, center.z)
                node.eulerAngles.y = yaw
                node.name = "sfCheckTile"
                parent.addChildNode(node)
            }
        }

        // Bright yellow lead-in stripe immediately before the checkers.
        let stripeMat = SCNMaterial()
        stripeMat.lightingModel = .constant
        stripeMat.diffuse.contents = UIColor(red: 1.0, green: 0.82, blue: 0.12, alpha: 1)
        stripeMat.emission.contents = UIColor(red: 1.0, green: 0.78, blue: 0.1, alpha: 0.7)
        let stripeDepth: Float = 1.1
        let stripeAlong = -Float(rows) * 0.5 * square - stripeDepth * 0.7
        let stripe = SCNBox(
            width: CGFloat(halfW * 2 - 0.2),
            height: 0.1,
            length: CGFloat(stripeDepth),
            chamferRadius: 0
        )
        stripe.materials = [stripeMat]
        let stripeNode = SCNNode(geometry: stripe)
        let stripePos = origin + forward * stripeAlong
        stripeNode.position = SCNVector3(stripePos.x, y + 0.05, stripePos.z)
        stripeNode.eulerAngles.y = yaw
        stripeNode.name = "sfLeadStripe"
        parent.addChildNode(stripeNode)

        // Fat white crossing bar — impossible to miss under the gantry.
        let barMat = SCNMaterial()
        barMat.lightingModel = .constant
        barMat.diffuse.contents = UIColor.white
        barMat.emission.contents = UIColor(white: 0.65, alpha: 1)
        let bar = SCNBox(width: CGFloat(halfW * 2), height: 0.12, length: 2.4, chamferRadius: 0)
        bar.materials = [barMat]
        let barNode = SCNNode(geometry: bar)
        barNode.position = SCNVector3(origin.x, y + 0.06, origin.z)
        barNode.eulerAngles.y = yaw
        barNode.name = "sfCrossBar"
        parent.addChildNode(barNode)
    }

    /// Giant flat FINISH word on the asphalt — readable from the overhead grid camera.
    private static func addFinishGroundTitle(
        into parent: SCNNode,
        origin: SIMD3<Float>,
        forward: SIMD3<Float>,
        right: SIMD3<Float>,
        halfW: Float,
        y: Float
    ) {
        let plane = SCNPlane(width: CGFloat(min(halfW * 1.6, 18)), height: 4.2)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        let tex = groundTitleTexture(title: StartFinishSignPhase.start.title)
        mat.diffuse.contents = tex
        mat.emission.contents = tex
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        plane.materials = [mat]
        let node = SCNNode(geometry: plane)
        // Sit just past the checkers so cars don't spawn on the letters.
        let pos = origin + forward * 5.5
        node.position = SCNVector3(pos.x, y + 0.04, pos.z)
        node.eulerAngles.x = -.pi / 2
        node.eulerAngles.y = atan2(forward.x, forward.z)
        node.renderingOrder = 4
        node.name = "sfGroundFinish"
        parent.addChildNode(node)
        _ = right
    }

    /// Painted chevrons on the approach so drivers see the line coming.
    private static func addFinishApproachChevrons(
        into parent: SCNNode,
        samples: [Sample],
        halfW: Float,
        y: Float
    ) {
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor(red: 1.0, green: 0.78, blue: 0.08, alpha: 1)
        mat.emission.contents = UIColor(red: 0.95, green: 0.7, blue: 0.05, alpha: 0.22)
        mat.isDoubleSided = true

        // Place chevrons on samples behind the line (negative lap progress ≈ last sector).
        let count = samples.count
        let steps = [12, 22, 34, 48]
        for step in steps {
            let idx = (count - step) % count
            let s = samples[idx]
            let fwd = simd_normalize(SIMD3<Float>(s.tangent.x, 0, s.tangent.z))
            let yaw = atan2(fwd.x, fwd.z)
            for lane: Float in [-0.55, 0, 0.55] {
                let lat = lane * (halfW * 0.42)
                let pos = s.pos + s.right * lat + fwd * 0.2
                let chevron = makeChevronPlane(width: 2.4, depth: 1.55)
                chevron.materials = [mat]
                let node = SCNNode(geometry: chevron)
                node.position = SCNVector3(pos.x, y + 0.012, pos.z)
                // Geometry is already on the XZ plane — yaw only to face travel direction.
                node.eulerAngles.y = yaw
                node.name = "sfChevron"
                parent.addChildNode(node)
            }
        }
    }

    private static func makeChevronPlane(width: Float, depth: Float) -> SCNGeometry {
        // V pointing along +Z (travel direction when plane is laid flat via −90° pitch).
        let hw = width * 0.5
        let hd = depth * 0.5
        let verts: [SCNVector3] = [
            SCNVector3(0, 0, hd),
            SCNVector3(hw, 0, -hd),
            SCNVector3(hw * 0.35, 0, -hd),
            SCNVector3(0, 0, hd * 0.15),
            SCNVector3(-hw * 0.35, 0, -hd),
            SCNVector3(-hw, 0, -hd),
        ]
        let indices: [Int32] = [0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 5]
        let src = SCNGeometrySource(vertices: verts)
        let elem = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: [src], elements: [elem])
    }

    /// Tall red/white boards at both shoulders — finish wall cue from the side.
    private static func addFinishSideBoards(
        into parent: SCNNode,
        origin: SIMD3<Float>,
        forward: SIMD3<Float>,
        right: SIMD3<Float>,
        halfW: Float,
        y: Float,
        night: Bool
    ) {
        let boardH: Float = 3.2
        let boardL: Float = 5.2
        for side: Float in [-1, 1] {
            let base = origin + right * ((halfW + 1.55) * side)
            for i in 0..<8 {
                let along = (Float(i) - 3.5) * 0.95
                let red = (i % 2 == 0)
                let mat = SCNMaterial()
                mat.lightingModel = .constant
                if red {
                    mat.diffuse.contents = UIColor(red: 0.92, green: 0.08, blue: 0.08, alpha: 1)
                    mat.emission.contents = night
                        ? UIColor(red: 1.0, green: 0.18, blue: 0.12, alpha: 0.45)
                        : UIColor(red: 0.85, green: 0.1, blue: 0.08, alpha: 0.2)
                } else {
                    mat.diffuse.contents = UIColor(white: 0.97, alpha: 1)
                    mat.emission.contents = UIColor(white: night ? 0.35 : 0.15, alpha: 1)
                }
                let panel = SCNBox(width: 0.14, height: CGFloat(boardH), length: 0.9, chamferRadius: 0.02)
                panel.materials = [mat]
                let node = SCNNode(geometry: panel)
                let p = base + forward * along
                node.position = SCNVector3(p.x, y + boardH * 0.5, p.z)
                node.eulerAngles.y = atan2(forward.x, forward.z)
                node.castsShadow = true
                node.name = "sfSideBoard"
                parent.addChildNode(node)
            }
            // Tall checkered pillar — reads from overhead when the banner is edge-on.
            let pillar = SCNBox(width: 1.1, height: 6.5, length: 1.1, chamferRadius: 0.08)
            let pillarMat = SCNMaterial()
            pillarMat.lightingModel = .constant
            pillarMat.diffuse.contents = finishCheckeredTexture()
            pillarMat.emission.contents = UIColor(white: night ? 0.3 : 0.15, alpha: 1)
            pillar.materials = [pillarMat]
            let pillarNode = SCNNode(geometry: pillar)
            let pp = base - forward * 1.2
            pillarNode.position = SCNVector3(pp.x, y + 3.25, pp.z)
            pillarNode.castsShadow = true
            pillarNode.name = "sfPillar"
            parent.addChildNode(pillarNode)

            let flag = SCNPlane(width: 2.2, height: 1.5)
            let flagMat = SCNMaterial()
            flagMat.lightingModel = .constant
            flagMat.diffuse.contents = finishCheckeredTexture()
            flagMat.emission.contents = finishCheckeredTexture()
            flagMat.isDoubleSided = true
            flag.materials = [flagMat]
            let flagNode = SCNNode(geometry: flag)
            flagNode.position = SCNVector3(pp.x, y + 7.0, pp.z)
            flagNode.eulerAngles.y = atan2(forward.x, forward.z) + (side > 0 ? 0.4 : -0.4)
            flagNode.name = "sfSideFlag"
            parent.addChildNode(flagNode)
            _ = boardL
        }
    }

    /// Neon/orange portal rings on the final approach so the finish sector is obvious at speed.
    private static func addFinishApproachGates(
        into parent: SCNNode,
        samples: [Sample],
        halfW: Float,
        y: Float,
        night: Bool
    ) {
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor(red: 1.0, green: 0.45, blue: 0.05, alpha: 1)
        mat.emission.contents = UIColor(red: 1.0, green: 0.5, blue: 0.08, alpha: night ? 0.85 : 0.55)

        let count = samples.count
        for step in [18, 30, 42] {
            let idx = (count - step) % count
            let s = samples[idx]
            let fwd = simd_normalize(SIMD3<Float>(s.tangent.x, 0, s.tangent.z))
            let yaw = atan2(fwd.x, fwd.z)
            let span = halfW * 2 + 1.5
            let archH: Float = 5.2

            for side: Float in [-1, 1] {
                let post = SCNBox(width: 0.35, height: CGFloat(archH), length: 0.35, chamferRadius: 0.04)
                post.materials = [mat]
                let postNode = SCNNode(geometry: post)
                let off = s.right * ((halfW + 0.6) * side)
                postNode.position = SCNVector3(s.pos.x + off.x, y + archH * 0.5, s.pos.z + off.z)
                postNode.name = "sfApproachPost"
                parent.addChildNode(postNode)
            }
            let top = SCNBox(width: CGFloat(span), height: 0.35, length: 0.35, chamferRadius: 0.04)
            top.materials = [mat]
            let topNode = SCNNode(geometry: top)
            topNode.position = SCNVector3(s.pos.x, y + archH, s.pos.z)
            topNode.eulerAngles.y = yaw
            topNode.name = "sfApproachTop"
            parent.addChildNode(topNode)
        }
    }

    /// Overhead gantry with a large FINISH banner facing oncoming traffic.
    private static func addFinishGantry(
        into parent: SCNNode,
        origin: SIMD3<Float>,
        forward: SIMD3<Float>,
        right: SIMD3<Float>,
        halfW: Float,
        y: Float,
        yaw: Float,
        night: Bool,
        showBanner: Bool
    ) {
        let postMat = SCNMaterial()
        postMat.lightingModel = .physicallyBased
        postMat.diffuse.contents = UIColor(white: night ? 0.28 : 0.42, alpha: 1)
        postMat.metalness.contents = 0.62
        postMat.roughness.contents = 0.38

        let span = halfW * 2 + 4.5
        let postH: Float = 10.5
        for side: Float in [-1, 1] {
            let postOff = right * ((halfW + 2.0) * side)
            let post = SCNBox(width: 0.95, height: CGFloat(postH), length: 0.95, chamferRadius: 0.08)
            post.materials = [postMat]
            let postNode = SCNNode(geometry: post)
            postNode.position = SCNVector3(origin.x + postOff.x, y + postH * 0.5, origin.z + postOff.z)
            postNode.castsShadow = true
            postNode.name = "sfGantryPost"
            parent.addChildNode(postNode)

            // Fat checkered sleeve on each post — readable when the banner is edge-on.
            let sleeve = SCNBox(width: 1.25, height: CGFloat(postH * 0.72), length: 1.25, chamferRadius: 0.06)
            let sleeveMat = SCNMaterial()
            sleeveMat.lightingModel = .constant
            sleeveMat.diffuse.contents = finishCheckeredTexture()
            sleeveMat.emission.contents = UIColor(white: night ? 0.4 : 0.22, alpha: 1)
            sleeve.materials = [sleeveMat]
            let sleeveNode = SCNNode(geometry: sleeve)
            sleeveNode.position = SCNVector3(origin.x + postOff.x, y + postH * 0.42, origin.z + postOff.z)
            sleeveNode.name = "sfGantrySleeve"
            parent.addChildNode(sleeveNode)
        }

        let beam = SCNBox(width: CGFloat(span), height: 1.15, length: 0.9, chamferRadius: 0.06)
        beam.materials = [postMat]
        let beamNode = SCNNode(geometry: beam)
        beamNode.position = SCNVector3(origin.x, y + postH - 0.35, origin.z)
        beamNode.eulerAngles.y = yaw
        beamNode.castsShadow = true
        beamNode.name = "sfGantryBeam"
        parent.addChildNode(beamNode)

        // Checkered fringe under the beam.
        let fringe = SCNBox(width: CGFloat(span - 0.3), height: 1.8, length: 0.18, chamferRadius: 0)
        let fringeMat = SCNMaterial()
        fringeMat.lightingModel = .constant
        fringeMat.diffuse.contents = finishCheckeredTexture()
        fringeMat.emission.contents = UIColor(white: night ? 0.4 : 0.25, alpha: 1)
        fringeMat.isDoubleSided = true
        fringe.materials = [fringeMat]
        let fringeNode = SCNNode(geometry: fringe)
        fringeNode.position = SCNVector3(origin.x, y + postH - 1.55, origin.z)
        fringeNode.eulerAngles.y = yaw
        fringeNode.name = "sfGantryFringe"
        parent.addChildNode(fringeNode)

        guard showBanner else { return }

        // Two offset boards (grid side + approach side) so neither face reads mirrored.
        // Start as START — NativeRaceEngine flips to FINISH when the green flag drops.
        let bannerW = min(span - 0.5, 28)
        let bannerH: Float = 3.6
        let tex = bannerTexture(title: StartFinishSignPhase.start.title)
        for facingTraffic in [true, false] {
            let plane = SCNPlane(width: CGFloat(bannerW), height: CGFloat(bannerH))
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = tex
            mat.emission.contents = tex
            mat.isDoubleSided = false
            plane.materials = [mat]
            let node = SCNNode(geometry: plane)
            let along = facingTraffic ? -forward * 0.45 : forward * 0.45
            let p = origin + along
            node.position = SCNVector3(p.x, y + postH - 3.7, p.z)
            node.eulerAngles.y = facingTraffic ? (yaw + .pi) : yaw
            node.name = facingTraffic ? "sfFinishBannerApproach" : "sfFinishBannerGrid"
            parent.addChildNode(node)
        }

        if night {
            let light = SCNNode()
            light.light = SCNLight()
            light.light?.type = .spot
            light.light?.intensity = 900
            light.light?.color = UIColor(red: 1, green: 0.92, blue: 0.75, alpha: 1)
            light.light?.spotInnerAngle = 40
            light.light?.spotOuterAngle = 70
            light.light?.attenuationEndDistance = 28
            light.position = SCNVector3(origin.x, y + postH - 0.6, origin.z)
            light.eulerAngles.x = -.pi / 2
            light.name = "sfGantryLight"
            parent.addChildNode(light)
        }
    }

    private static func groundTitleTexture(title: String) -> UIImage {
        if let cached = cachedGroundTextures[title] { return cached }
        let size = CGSize(width: 1024, height: 280)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let stroke: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 168, weight: .black),
                .foregroundColor: UIColor.black,
                .strokeColor: UIColor.black,
                .strokeWidth: -12,
                .paragraphStyle: paragraph,
                .kern: 14,
            ]
            let fill: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 168, weight: .black),
                .foregroundColor: UIColor(red: 1, green: 0.85, blue: 0.1, alpha: 1),
                .paragraphStyle: paragraph,
                .kern: 14,
            ]
            let text = title as NSString
            let textRect = CGRect(x: 20, y: 40, width: size.width - 40, height: 200)
            text.draw(in: textRect, withAttributes: stroke)
            text.draw(in: textRect, withAttributes: fill)
        }
        cachedGroundTextures[title] = image
        return image
    }

    private static func bannerTexture(title: String) -> UIImage {
        if let cached = cachedBannerTextures[title] { return cached }
        let size = CGSize(width: 1024, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        let accent: UIColor = title == "START"
            ? UIColor(red: 0.2, green: 0.95, blue: 0.45, alpha: 1)
            : UIColor(red: 1, green: 0.82, blue: 0.1, alpha: 1)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1).setFill()
            ctx.fill(rect)

            // Checkered end caps.
            let cell: CGFloat = 32
            for row in 0..<Int(size.height / cell) {
                for col in 0..<4 {
                    if (row + col) % 2 == 0 {
                        UIColor.white.setFill()
                    } else {
                        UIColor.black.setFill()
                    }
                    ctx.fill(CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell))
                    ctx.fill(CGRect(
                        x: size.width - CGFloat(col + 1) * cell,
                        y: CGFloat(row) * cell,
                        width: cell,
                        height: cell
                    ))
                }
            }

            accent.setFill()
            ctx.fill(CGRect(x: 140, y: 18, width: size.width - 280, height: 10))
            ctx.fill(CGRect(x: 140, y: size.height - 28, width: size.width - 280, height: 10))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 128, weight: .black),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
                .kern: 10,
            ]
            let text = title as NSString
            let textRect = CGRect(x: 160, y: 48, width: size.width - 320, height: 160)
            text.draw(in: textRect, withAttributes: attrs)
        }
        cachedBannerTextures[title] = image
        return image
    }

    private static func finishCheckeredTexture() -> UIImage {
        let size = CGSize(width: 256, height: 160)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cell: CGFloat = 32
            for row in 0..<Int(ceil(size.height / cell)) {
                for col in 0..<Int(ceil(size.width / cell)) {
                    ((row + col) % 2 == 0 ? UIColor.white : UIColor.black).setFill()
                    ctx.fill(CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell))
                }
            }
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
        let shoulderW: Float = 8

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
        addStartFinishComplex(parent: parent, samples: samples, halfW: halfW, night: night)
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
    /// Opaque race buildings — well clear of the racing line.
    static let buildingMinLateral: Float = RaceTrackMesh.buildingSetback + 4
    /// Lamp poles — keep the whole mesh (arms included) off asphalt.
    static let poleMinLateral: Float = RaceTrackMesh.halfWidth + 8

    static func footprintRadius(_ node: SCNNode) -> Float {
        let (minB, maxB) = node.boundingBox
        let sx = abs(node.scale.x)
        let sz = abs(node.scale.z)
        return max((maxB.x - minB.x) * sx, (maxB.z - minB.z) * sz) * 0.5
    }

    /// Put the XZ origin at the mesh center so overhanging Kenney arms don't sit on the racing line.
    static func centerPivotOnXZ(_ node: SCNNode) {
        let (mn, mx) = node.boundingBox
        let cx = (mn.x + mx.x) * 0.5
        let cz = (mn.z + mx.z) * 0.5
        node.pivot = SCNMatrix4MakeTranslation(cx, 0, cz)
    }

    static func closestFrame(
        to pos: SIMD3<Float>,
        track: ClosedTrackSpline
    ) -> (t: Float, center: SIMD3<Float>, right: SIMD3<Float>) {
        let samples = 160
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
        let window: Float = 1.5 / Float(samples)
        for j in -12...12 {
            var t = bestT + Float(j) * window / 12
            t = t.truncatingRemainder(dividingBy: 1)
            if t < 0 { t += 1 }
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
        // Re-project after each move — tight curves otherwise leave one pole on asphalt.
        for _ in 0..<3 {
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

    static func secure(
        _ node: SCNNode,
        track: ClosedTrackSpline,
        minLateral: Float,
        extraFootprint: Float = 0
    ) {
        centerPivotOnXZ(node)
        pushOutsideRoad(node, track: track, minLateral: minLateral, extraFootprint: extraFootprint)
    }
}
