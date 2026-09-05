import SceneKit
import simd
import UIKit

/// Kid-arcade track dressing: candy barriers, grandstands, crowds, landmarks, tire stacks.
enum TrackArcadeDressing {

    static func dressTrack(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        city: CityRuntimeConfig,
        night: Bool
    ) {
        addCandyStripeBarriers(into: parent, track: track, night: night)
        addStartFinishGrandstands(into: parent, track: track, night: night)
        addLandmark(into: parent, track: track, city: city, night: night)
        addTireStacks(into: parent, track: track, city: city)
        addHillGuardrails(into: parent, track: track, night: night)
    }

    // MARK: - Candy-stripe edge barriers

    /// Continuous red/white jersey walls just outside the racing line.
    static func addCandyStripeBarriers(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        night: Bool
    ) {
        let root = SCNNode()
        root.name = "krcCandyBarriers"
        let halfW = RaceTrackMesh.halfWidth
        // Short blocks well past the curb — long walls on tight Harbor bends used to
        // chord onto the asphalt and read as poles in the lane.
        let sampleCount = max(100, track.points.count)
        let step = 2
        let segLen: Float = 1.55
        let wallLateral = halfW + 6.2
        let red = stripeMaterial(red: true, night: night)
        let white = stripeMaterial(red: false, night: night)

        for i in stride(from: 0, to: sampleCount, by: step) {
            let t = Float(i) / Float(sampleCount)
            let p = track.position(at: t)
            let tan = track.tangent(t)
            let yaw = atan2(tan.x, tan.z)
            let right = track.right(at: t)
            let mat = ((i / step) % 2 == 0) ? red : white

            for side: Float in [-1, 1] {
                let wall = SCNBox(width: 0.34, height: 0.85, length: CGFloat(segLen), chamferRadius: 0.04)
                wall.materials = [mat]
                let node = SCNNode(geometry: wall)
                let off = right * (wallLateral * side)
                node.position = SCNVector3(p.x + off.x, p.y + 0.42, p.z + off.z)
                node.eulerAngles.y = yaw
                node.castsShadow = false
                // Do NOT pushOutsideRoad here — on folded loops closest-point can
                // yank a correct shoulder wall onto a neighboring ribbon centerline.
                root.addChildNode(node)
            }
        }
        parent.addChildNode(root)
    }

    // MARK: - Grandstands + crowds

    static func addStartFinishGrandstands(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        night: Bool
    ) {
        let root = SCNNode()
        root.name = "krcGrandstands"
        let s0 = track.position(at: 0)
        let fwd = track.tangent(0)
        let right = track.right(at: 0)
        let yaw = atan2(fwd.x, fwd.z)
        let halfW = RaceTrackMesh.halfWidth

        for (sideIndex, side) in ([-1.0, 1.0] as [Float]).enumerated() {
            let stand = makeGrandstand(night: night, seed: UInt64(sideIndex + 3))
            let lat = (halfW + 11.5) * side
            let pos = s0 + right * lat - fwd * 4.5
            stand.position = SCNVector3(pos.x, s0.y, pos.z)
            stand.eulerAngles.y = yaw + (side > 0 ? 0 : Float.pi)
            root.addChildNode(stand)
        }

        // Extra bleachers a bit past the line for depth.
        let stand2 = makeGrandstand(night: night, seed: 11, tiers: 3, width: 14)
        let pos2 = s0 + right * (halfW + 12) + fwd * 10
        stand2.position = SCNVector3(pos2.x, s0.y, pos2.z)
        stand2.eulerAngles.y = yaw
        root.addChildNode(stand2)

        parent.addChildNode(root)
    }

    private static func makeGrandstand(
        night: Bool,
        seed: UInt64,
        tiers: Int = 4,
        width: Float = 18
    ) -> SCNNode {
        var rng = SeededRandom(seed: seed &* 0xC40D ^ 0x57414E44)
        let stand = SCNNode()
        stand.name = "krcGrandstand"

        let frameMat = SCNMaterial()
        frameMat.lightingModel = .physicallyBased
        frameMat.diffuse.contents = UIColor(white: night ? 0.18 : 0.28, alpha: 1)
        frameMat.metalness.contents = 0.35
        frameMat.roughness.contents = 0.55

        let seatColors: [UIColor] = [
            UIColor(red: 0.92, green: 0.22, blue: 0.18, alpha: 1),
            UIColor(red: 0.12, green: 0.45, blue: 0.95, alpha: 1),
            UIColor(red: 0.98, green: 0.78, blue: 0.12, alpha: 1),
            UIColor(red: 0.18, green: 0.72, blue: 0.38, alpha: 1),
            UIColor(red: 0.95, green: 0.45, blue: 0.12, alpha: 1),
        ]

        for tier in 0..<tiers {
            let depth: Float = 2.2
            let h: Float = 0.55
            let y = Float(tier) * 0.85 + 0.35
            let z = Float(tier) * -1.15
            let seat = SCNBox(width: CGFloat(width), height: CGFloat(h), length: CGFloat(depth), chamferRadius: 0.04)
            let seatMat = SCNMaterial()
            seatMat.lightingModel = .physicallyBased
            seatMat.diffuse.contents = seatColors[tier % seatColors.count]
            seatMat.roughness.contents = 0.72
            seat.materials = [seatMat]
            let seatNode = SCNNode(geometry: seat)
            seatNode.position = SCNVector3(0, y, z)
            stand.addChildNode(seatNode)

            // Cartoon crowd silhouettes (billboard heads).
            let people = Int(width / 1.35)
            for p in 0..<people {
                if rng.unitFloat() < 0.18 { continue }
                let person = makeCrowdPerson(rng: &rng, night: night)
                let x = -width * 0.5 + 0.7 + Float(p) * 1.35 + rng.float(in: -0.15...0.15)
                person.position = SCNVector3(x, y + 0.85, z - 0.15)
                stand.addChildNode(person)
            }
        }

        let roof = SCNBox(width: CGFloat(width + 1.2), height: 0.18, length: 6.5, chamferRadius: 0.04)
        roof.materials = [frameMat]
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(0, Float(tiers) * 0.85 + 1.4, -1.2)
        stand.addChildNode(roofNode)

        if night {
            let light = SCNLight()
            light.type = .omni
            light.intensity = 380
            light.color = UIColor(red: 1, green: 0.92, blue: 0.75, alpha: 1)
            light.attenuationEndDistance = 28
            let lamp = SCNNode()
            lamp.light = light
            lamp.position = SCNVector3(0, Float(tiers) * 0.85 + 1.1, 0.5)
            stand.addChildNode(lamp)
        }

        return stand
    }

    private static func makeCrowdPerson(rng: inout SeededRandom, night: Bool) -> SCNNode {
        let node = SCNNode()
        let shirtColors: [UIColor] = [
            .systemOrange, .systemYellow, .systemTeal, .systemPink, .systemIndigo, .white, .systemGreen,
        ]
        let body = SCNCylinder(radius: 0.22, height: 0.85)
        let bodyMat = SCNMaterial()
        bodyMat.lightingModel = .constant
        bodyMat.diffuse.contents = shirtColors[rng.int(in: 0...(shirtColors.count - 1))]
        body.materials = [bodyMat]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position.y = 0.35
        node.addChildNode(bodyNode)

        let head = SCNSphere(radius: 0.2)
        head.segmentCount = 8
        let headMat = SCNMaterial()
        headMat.lightingModel = .constant
        let tone = 0.45 + rng.float(in: 0...0.4)
        headMat.diffuse.contents = UIColor(red: CGFloat(tone), green: CGFloat(tone * 0.78), blue: CGFloat(tone * 0.55), alpha: 1)
        if night { headMat.emission.contents = UIColor(white: 0.08, alpha: 1) }
        head.materials = [headMat]
        let headNode = SCNNode(geometry: head)
        headNode.position.y = 0.95
        node.addChildNode(headNode)
        return node
    }

    // MARK: - Landmarks

    static func addLandmark(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        city: CityRuntimeConfig,
        night: Bool
    ) {
        let root = SCNNode()
        root.name = "krcTrackLandmark"
        let t: Float = 0.12
        let base = track.position(at: t)
        let right = track.right(at: t)
        let fwd = track.tangent(t)
        let yaw = atan2(fwd.x, fwd.z)
        let side: Float = 1
        let pos = base + right * ((RaceTrackMesh.halfWidth + 14) * side)

        switch city.trackProfile {
        case .coastalOpen, .coastalCityCircuit, .stormHarbor:
            root.addChildNode(makeGiantTireLandmark(at: pos, yaw: yaw, night: night))
        case .desertHighway:
            root.addChildNode(makeArchLandmark(at: pos, yaw: yaw, night: night, desert: true))
        case .alpineRidge:
            root.addChildNode(makeArchLandmark(at: pos, yaw: yaw, night: night, desert: false))
        case .urbanNight:
            root.addChildNode(makeNeonLapSign(at: pos, yaw: yaw, night: true))
        case .speedwayOval:
            root.addChildNode(makeGiantTireLandmark(at: pos, yaw: yaw, night: night))
        default:
            root.addChildNode(makeNeonLapSign(at: pos, yaw: yaw, night: night))
        }
        parent.addChildNode(root)
    }

    private static func makeGiantTireLandmark(at pos: SIMD3<Float>, yaw: Float, night: Bool) -> SCNNode {
        let node = SCNNode()
        node.position = SCNVector3(pos.x, pos.y, pos.z)
        node.eulerAngles.y = yaw
        let tire = SCNTorus(ringRadius: 3.2, pipeRadius: 0.85)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(white: 0.08, alpha: 1)
        mat.roughness.contents = 0.92
        mat.metalness.contents = 0.05
        tire.materials = [mat]
        let tireNode = SCNNode(geometry: tire)
        tireNode.eulerAngles.x = .pi / 2
        tireNode.position.y = 3.4
        node.addChildNode(tireNode)

        let badge = SCNBox(width: 2.4, height: 1.1, length: 0.2, chamferRadius: 0.06)
        let badgeMat = SCNMaterial()
        badgeMat.lightingModel = .constant
        badgeMat.diffuse.contents = UIColor(red: 1, green: 0.55, blue: 0.08, alpha: 1)
        badgeMat.emission.contents = night
            ? UIColor(red: 0.7, green: 0.3, blue: 0.05, alpha: 1)
            : UIColor(red: 0.35, green: 0.15, blue: 0.02, alpha: 1)
        badge.materials = [badgeMat]
        let badgeNode = SCNNode(geometry: badge)
        badgeNode.position = SCNVector3(0, 3.4, 1.1)
        node.addChildNode(badgeNode)
        return node
    }

    private static func makeArchLandmark(at pos: SIMD3<Float>, yaw: Float, night: Bool, desert: Bool) -> SCNNode {
        let node = SCNNode()
        node.position = SCNVector3(pos.x, pos.y, pos.z)
        node.eulerAngles.y = yaw
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = desert
            ? UIColor(red: 0.72, green: 0.48, blue: 0.22, alpha: 1)
            : UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
        mat.roughness.contents = 0.7
        for x: Float in [-4.5, 4.5] {
            let pillar = SCNBox(width: 1.4, height: 9.5, length: 1.4, chamferRadius: 0.12)
            pillar.materials = [mat]
            let p = SCNNode(geometry: pillar)
            p.position = SCNVector3(x, 4.75, 0)
            node.addChildNode(p)
        }
        let top = SCNBox(width: 11.5, height: 1.3, length: 1.6, chamferRadius: 0.1)
        top.materials = [mat]
        let topNode = SCNNode(geometry: top)
        topNode.position.y = 10.0
        node.addChildNode(topNode)

        let neon = SCNBox(width: 8.5, height: 0.9, length: 0.25, chamferRadius: 0.04)
        let neonMat = SCNMaterial()
        neonMat.lightingModel = .constant
        neonMat.diffuse.contents = UIColor(red: 0.1, green: 0.9, blue: 1.0, alpha: 1)
        neonMat.emission.contents = night
            ? UIColor(red: 0.2, green: 0.85, blue: 1.0, alpha: 1)
            : UIColor(red: 0.05, green: 0.35, blue: 0.45, alpha: 1)
        neon.materials = [neonMat]
        let neonNode = SCNNode(geometry: neon)
        neonNode.position = SCNVector3(0, 10.0, 0.95)
        node.addChildNode(neonNode)
        return node
    }

    private static func makeNeonLapSign(at pos: SIMD3<Float>, yaw: Float, night: Bool) -> SCNNode {
        let node = SCNNode()
        node.position = SCNVector3(pos.x, pos.y, pos.z)
        node.eulerAngles.y = yaw

        let pole = SCNCylinder(radius: 0.18, height: 7.2)
        let poleMat = SCNMaterial()
        poleMat.lightingModel = .physicallyBased
        poleMat.diffuse.contents = UIColor(white: 0.25, alpha: 1)
        poleMat.metalness.contents = 0.6
        pole.materials = [poleMat]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position.y = 3.6
        node.addChildNode(poleNode)

        let board = SCNBox(width: 7.5, height: 2.4, length: 0.35, chamferRadius: 0.08)
        let boardMat = SCNMaterial()
        boardMat.lightingModel = .constant
        boardMat.diffuse.contents = UIColor(red: 0.05, green: 0.08, blue: 0.14, alpha: 1)
        board.materials = [boardMat]
        let boardNode = SCNNode(geometry: board)
        boardNode.position.y = 6.4
        node.addChildNode(boardNode)

        let glow = SCNBox(width: 6.8, height: 1.6, length: 0.12, chamferRadius: 0.04)
        let glowMat = SCNMaterial()
        glowMat.lightingModel = .constant
        glowMat.diffuse.contents = UIColor(red: 1, green: 0.35, blue: 0.05, alpha: 1)
        glowMat.emission.contents = night
            ? UIColor(red: 1, green: 0.45, blue: 0.08, alpha: 1)
            : UIColor(red: 0.55, green: 0.2, blue: 0.04, alpha: 1)
        glow.materials = [glowMat]
        let glowNode = SCNNode(geometry: glow)
        glowNode.position = SCNVector3(0, 6.4, 0.22)
        node.addChildNode(glowNode)
        return node
    }

    // MARK: - Tire stacks

    static func addTireStacks(into parent: SCNNode, track: ClosedTrackSpline, city: CityRuntimeConfig) {
        let root = SCNNode()
        root.name = "krcTireStacks"
        var rng = SeededRandom(seed: city.seed ^ 0x71BE5)
        let count = 8
        for i in 0..<count {
            let t = (Float(i) + 0.35) / Float(count)
            // Keep clear of start/finish cluster.
            if t < 0.06 || t > 0.94 { continue }
            let base = track.position(at: t)
            let right = track.right(at: t)
            let yaw = atan2(track.tangent(t).x, track.tangent(t).z)
            let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
            let stack = makeTireStack(count: rng.int(in: 2...4), rng: &rng)
            let off = right * ((RaceTrackMesh.halfWidth + 5.5 + rng.float(in: 0...2)) * side)
            stack.position = SCNVector3(base.x + off.x, base.y, base.z + off.z)
            stack.eulerAngles.y = yaw + rng.float(in: -0.2...0.2)
            root.addChildNode(stack)
        }
        parent.addChildNode(root)
    }

    private static func makeTireStack(count: Int, rng: inout SeededRandom) -> SCNNode {
        let node = SCNNode()
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(white: 0.07, alpha: 1)
        mat.roughness.contents = 0.95
        for i in 0..<count {
            let tire = SCNTorus(ringRadius: 0.55, pipeRadius: 0.22)
            tire.materials = [mat]
            let t = SCNNode(geometry: tire)
            t.eulerAngles.x = .pi / 2
            t.position = SCNVector3(
                rng.float(in: -0.05...0.05),
                0.28 + Float(i) * 0.48,
                rng.float(in: -0.05...0.05)
            )
            node.addChildNode(t)
        }
        return node
    }

    // MARK: - Hill guardrails

    static func addHillGuardrails(into parent: SCNNode, track: ClosedTrackSpline, night: Bool) {
        let root = SCNNode()
        root.name = "krcHillRails"
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(red: 0.78, green: 0.8, blue: 0.84, alpha: 1)
        mat.metalness.contents = 0.82
        mat.roughness.contents = 0.28
        if night {
            mat.emission.contents = UIColor(white: 0.08, alpha: 1)
        }

        let samples = 80
        for i in 0..<samples {
            let t = Float(i) / Float(samples)
            let p = track.position(at: t)
            guard p.y > 2.8 else { continue }
            let right = track.right(at: t)
            let tan = track.tangent(t)
            let yaw = atan2(tan.x, tan.z)
            // Outer side of the slope.
            let side: Float = abs(right.x) > abs(right.z) ? (right.x > 0 ? 1 : -1) : (right.z > 0 ? 1 : -1)
            let rail = SCNBox(width: 0.14, height: 0.7, length: 5.8, chamferRadius: 0.03)
            rail.materials = [mat]
            let node = SCNNode(geometry: rail)
            let off = right * ((RaceTrackMesh.halfWidth + 5.8) * side)
            node.position = SCNVector3(p.x + off.x, p.y + 0.55, p.z + off.z)
            node.eulerAngles.y = yaw
            root.addChildNode(node)
        }
        if !root.childNodes.isEmpty {
            parent.addChildNode(root)
        }
    }

    // MARK: - Materials

    private static func stripeMaterial(red: Bool, night: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        if red {
            m.diffuse.contents = UIColor(red: night ? 0.85 : 0.92, green: 0.12, blue: 0.1, alpha: 1)
        } else {
            m.diffuse.contents = UIColor(white: night ? 0.88 : 0.96, alpha: 1)
        }
        m.roughness.contents = 0.55
        m.metalness.contents = 0.08
        if night {
            m.emission.contents = red
                ? UIColor(red: 0.25, green: 0.04, blue: 0.03, alpha: 1)
                : UIColor(white: 0.12, alpha: 1)
        }
        return m
    }
}
