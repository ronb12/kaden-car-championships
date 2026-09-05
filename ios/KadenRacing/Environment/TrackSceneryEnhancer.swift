import SceneKit
import simd
import UIKit

/// Profile-aware roadside set dressing along the race spline (AAA density, off the asphalt).
enum TrackSceneryEnhancer {

    static func build(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        city: CityRuntimeConfig,
        night: Bool,
        quality: GraphicsQuality
    ) {
        let profile = city.trackProfile
        let art = CityEnvironmentArt.profile(for: city)
        var rng = SeededRandom(seed: city.seed ^ 0x5C3E4E52)
        let preset = EnvironmentGraphicsSettings.preset(for: quality)
        let sampleCount = max(160, track.points.count * 2)
        let step = max(2, sampleCount / densitySteps(for: profile, preset: preset))

        for i in stride(from: 0, to: sampleCount, by: step) {
            let t = Float(i) / Float(sampleCount)
            let base = track.position(at: t)
            let right = track.right(at: t)
            let yaw = atan2(right.x, right.z)

            switch profile {
            case .coastalOpen, .coastalCityCircuit, .stormHarbor:
                placeCoastalProps(into: parent, track: track, base: base, right: right, yaw: yaw, night: night, art: art, rng: &rng)
            case .desertHighway:
                placeDesertProps(into: parent, track: track, base: base, right: right, yaw: yaw, rng: &rng)
            case .alpineRidge:
                placeAlpineProps(into: parent, track: track, base: base, right: right, yaw: yaw, rng: &rng)
            case .speedwayOval:
                placeSpeedwayProps(into: parent, track: track, base: base, right: right, yaw: yaw, night: night, rng: &rng)
            case .urbanNight:
                placeUrbanProps(into: parent, track: track, base: base, right: right, yaw: yaw, night: night, rng: &rng)
            case .technicalCircuit, .standard:
                placeStandardProps(into: parent, track: track, base: base, right: right, yaw: yaw, night: night, art: art, rng: &rng)
            }
        }

    }

    private static func densitySteps(for profile: EnvironmentTrackProfile, preset: EnvironmentGraphicsSettings.Preset) -> Int {
        // Moderate roadside density — readable from chase cam without crowding the view.
        let base = max(32, Int(Float(preset.decorStepDivisor) * 0.75))
        switch profile {
        case .coastalCityCircuit: return max(40, base / 2)
        case .coastalOpen, .stormHarbor, .urbanNight: return max(48, Int(Float(base) / 1.7))
        case .desertHighway, .alpineRidge: return max(56, Int(Float(base) / 1.5))
        case .standard, .technicalCircuit: return max(56, Int(Float(base) / 1.55))
        default: return max(64, Int(Float(base) / 1.35))
        }
    }

    // MARK: - Profile placers

    private static func placeCoastalProps(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        night: Bool,
        art: CityEnvironmentArt.Profile,
        rng: inout SeededRandom
    ) {
        if art.prefersPalms, rng.unitFloat() < 0.72 {
            placeTree(into: parent, track: track, base: base, right: right, yaw: yaw, coastal: true, rng: &rng, lateral: TrackRoadsideClearance.palmMinLateral + rng.float(in: 2...12))
            if rng.unitFloat() < 0.28 {
                placeTree(
                    into: parent, track: track, base: base, right: right, yaw: yaw,
                    coastal: true, rng: &rng,
                    lateral: TrackRoadsideClearance.palmMinLateral + rng.float(in: 6...16)
                )
            }
        }
        if rng.unitFloat() < 0.18 {
            placeSandBerms(into: parent, base: base, right: right, yaw: yaw, rng: &rng)
        }
        if rng.unitFloat() < 0.18 {
            placeBollard(into: parent, track: track, base: base, right: right, yaw: yaw, night: night, rng: &rng)
        }
    }

    private static func placeDesertProps(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        rng: inout SeededRandom
    ) {
        if rng.unitFloat() < 0.42 {
            placeRock(into: parent, track: track, base: base, right: right, yaw: yaw, rng: &rng, desert: true)
        }
        if rng.unitFloat() < 0.32 {
            placeCactus(into: parent, track: track, base: base, right: right, rng: &rng)
        }
        if rng.unitFloat() < 0.38 {
            placeSandBerms(into: parent, base: base, right: right, yaw: yaw, rng: &rng)
        }
    }

    private static func placeAlpineProps(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        rng: inout SeededRandom
    ) {
        if rng.unitFloat() < 0.62 {
            placeTree(
                into: parent, track: track, base: base, right: right, yaw: yaw,
                coastal: false, alpine: true, rng: &rng,
                lateral: TrackRoadsideClearance.treeMinLateral + rng.float(in: 3...16)
            )
        }
        if rng.unitFloat() < 0.36 {
            placeRock(into: parent, track: track, base: base, right: right, yaw: yaw, rng: &rng, desert: false)
        }
        if rng.unitFloat() < 0.28 {
            placeGuardrail(into: parent, track: track, base: base, right: right, yaw: yaw, rng: &rng)
        }
    }

    private static func placeSpeedwayProps(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        night: Bool,
        rng: inout SeededRandom
    ) {
        if rng.unitFloat() < 0.22, let barrier = KenneyEnvironmentLoader.loadRoadBarrier() {
            let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
            let off = right * ((TrackRoadsideClearance.treeMinLateral + 2) * side)
            barrier.position = SCNVector3(base.x + off.x, base.y, base.z + off.z)
            barrier.eulerAngles.y = yaw
            KenneyEnvironmentLoader.alignBuildingToGround(barrier, groundY: base.y)
            TrackRoadsideClearance.pushOutsideRoad(barrier, track: track, minLateral: TrackRoadsideClearance.treeMinLateral)
            parent.addChildNode(barrier)
        }
        if night, rng.unitFloat() < 0.12 {
            placeBollard(into: parent, track: track, base: base, right: right, yaw: yaw, night: true, rng: &rng)
        }
    }

    private static func placeUrbanProps(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        night: Bool,
        rng: inout SeededRandom
    ) {
        if rng.unitFloat() < 0.38, let light = KenneyEnvironmentLoader.loadStreetLight(night: night) {
            let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
            let off = right * ((TrackRoadsideClearance.treeMinLateral + 3) * side)
            light.position = SCNVector3(base.x + off.x, base.y, base.z + off.z)
            light.eulerAngles.y = yaw + (side > 0 ? Float.pi * 0.5 : -Float.pi * 0.5)
            TrackRoadsideClearance.secure(
                light, track: track,
                minLateral: TrackRoadsideClearance.poleMinLateral,
                extraFootprint: 1.2
            )
            parent.addChildNode(light)
        }
        if rng.unitFloat() < 0.16 {
            placeBillboard(into: parent, track: track, base: base, right: right, yaw: yaw, night: night, rng: &rng)
        }
    }

    private static func placeStandardProps(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        night: Bool,
        art: CityEnvironmentArt.Profile,
        rng: inout SeededRandom
    ) {
        if rng.unitFloat() < 0.32 {
            placeTree(into: parent, track: track, base: base, right: right, yaw: yaw, coastal: art.prefersPalms, rng: &rng, lateral: TrackRoadsideClearance.treeMinLateral + rng.float(in: 2...10))
        }
        if rng.unitFloat() < 0.14 {
            placeBillboard(into: parent, track: track, base: base, right: right, yaw: yaw, night: night, rng: &rng)
        }
        if rng.unitFloat() < 0.14, let light = KenneyEnvironmentLoader.loadStreetLight(night: night) {
            let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
            let off = right * ((TrackRoadsideClearance.treeMinLateral + 5) * side)
            light.position = SCNVector3(base.x + off.x, base.y, base.z + off.z)
            light.eulerAngles.y = yaw
            TrackRoadsideClearance.secure(
                light, track: track,
                minLateral: TrackRoadsideClearance.poleMinLateral,
                extraFootprint: 1.2
            )
            parent.addChildNode(light)
        }
    }

    // MARK: - Primitives

    private static func placeTree(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        coastal: Bool,
        alpine: Bool = false,
        rng: inout SeededRandom,
        lateral: Float
    ) {
        guard let tree = KenneyEnvironmentLoader.loadTree(
            targetHeight: alpine ? rng.float(in: 7...13) : rng.float(in: 5...10),
            coastal: coastal,
            rng: &rng,
            alpine: alpine
        ) else { return }
        let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
        let off = right * (lateral * side)
        tree.position = SCNVector3(base.x + off.x, base.y, base.z + off.z)
        KenneyEnvironmentLoader.alignBuildingToGround(tree, groundY: base.y)
        tree.eulerAngles.y = yaw + rng.float(in: -0.35...0.35)
        TrackRoadsideClearance.pushOutsideRoad(tree, track: track, minLateral: coastal ? TrackRoadsideClearance.palmMinLateral : TrackRoadsideClearance.treeMinLateral)
        tree.castsShadow = true
        parent.addChildNode(tree)
    }

    private static func placeSandBerms(
        into parent: SCNNode,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        rng: inout SeededRandom
    ) {
        let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(red: 0.62, green: 0.54, blue: 0.38, alpha: 1)
        mat.roughness.contents = 0.94
        let berm = SCNBox(width: 3.2, height: 0.45, length: 5.5, chamferRadius: 0.08)
        berm.materials = [mat]
        let node = SCNNode(geometry: berm)
        let off = right * ((RaceTrackMesh.halfWidth + 9) * side)
        node.position = SCNVector3(base.x + off.x, base.y + 0.18, base.z + off.z)
        node.eulerAngles.y = yaw + rng.float(in: -0.1...0.1)
        parent.addChildNode(node)
    }

    private static func placeBollard(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        night: Bool,
        rng: inout SeededRandom
    ) {
        let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
        let pole = SCNCylinder(radius: 0.07, height: 1.1)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(white: night ? 0.55 : 0.72, alpha: 1)
        mat.metalness.contents = 0.7
        pole.materials = [mat]
        let node = SCNNode(geometry: pole)
        let off = right * (TrackRoadsideClearance.poleMinLateral * side)
        node.position = SCNVector3(base.x + off.x, base.y + 0.55, base.z + off.z)
        node.eulerAngles.y = yaw
        TrackRoadsideClearance.pushOutsideRoad(
            node, track: track, minLateral: TrackRoadsideClearance.poleMinLateral
        )
        parent.addChildNode(node)
    }

    private static func placeRock(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        rng: inout SeededRandom,
        desert: Bool
    ) {
        let w = rng.float(in: desert ? 1.6...3.8 : 2.2...5.2)
        let h = rng.float(in: desert ? 0.7...1.8 : 1.2...3.4)
        let d = rng.float(in: desert ? 1.4...3.2 : 1.8...4.4)
        let box = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: CGFloat(min(w, h, d) * 0.18))
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        if desert {
            mat.diffuse.contents = UIColor(red: 0.52, green: 0.38, blue: 0.22, alpha: 1)
        } else {
            mat.diffuse.contents = UIColor(red: 0.42, green: 0.44, blue: 0.46, alpha: 1)
        }
        mat.roughness.contents = 0.92
        mat.metalness.contents = 0.02
        box.materials = [mat]
        let node = SCNNode(geometry: box)
        let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
        let off = right * ((TrackRoadsideClearance.treeMinLateral + rng.float(in: 3...14)) * side)
        node.position = SCNVector3(base.x + off.x, base.y + h * 0.42, base.z + off.z)
        node.eulerAngles.y = yaw + rng.float(in: -0.4...0.4)
        node.eulerAngles.z = rng.float(in: -0.12...0.12)
        TrackRoadsideClearance.pushOutsideRoad(node, track: track, minLateral: TrackRoadsideClearance.treeMinLateral)
        parent.addChildNode(node)
    }

    private static func placeCactus(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        rng: inout SeededRandom
    ) {
        let h = rng.float(in: 1.6...3.4)
        let trunk = SCNCylinder(radius: CGFloat(rng.float(in: 0.12...0.2)), height: CGFloat(h))
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(red: 0.22, green: 0.42, blue: 0.24, alpha: 1)
        mat.roughness.contents = 0.78
        trunk.materials = [mat]
        let node = SCNNode(geometry: trunk)
        let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
        let off = right * ((TrackRoadsideClearance.treeMinLateral + rng.float(in: 4...12)) * side)
        node.position = SCNVector3(base.x + off.x, base.y + h * 0.5, base.z + off.z)
        if rng.unitFloat() < 0.7 {
            let arm = SCNCylinder(radius: 0.09, height: CGFloat(h * 0.42))
            arm.materials = [mat]
            let armNode = SCNNode(geometry: arm)
            armNode.position = SCNVector3(h * 0.18, h * 0.08, 0)
            armNode.eulerAngles.z = 1.15
            node.addChildNode(armNode)
        }
        TrackRoadsideClearance.pushOutsideRoad(node, track: track, minLateral: TrackRoadsideClearance.treeMinLateral)
        parent.addChildNode(node)
    }

    private static func placeGuardrail(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        rng: inout SeededRandom
    ) {
        let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
        let rail = SCNBox(width: 0.12, height: 0.55, length: 6.4, chamferRadius: 0.02)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(red: 0.62, green: 0.64, blue: 0.66, alpha: 1)
        mat.metalness.contents = 0.72
        mat.roughness.contents = 0.38
        rail.materials = [mat]
        let node = SCNNode(geometry: rail)
        let off = right * ((RaceTrackMesh.halfWidth + 7.2) * side)
        node.position = SCNVector3(base.x + off.x, base.y + 0.55, base.z + off.z)
        node.eulerAngles.y = yaw
        TrackRoadsideClearance.pushOutsideRoad(node, track: track, minLateral: RaceTrackMesh.halfWidth + 6.5)
        parent.addChildNode(node)
    }

    private static func placeBillboard(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        night: Bool,
        rng: inout SeededRandom
    ) {
        let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
        let colors: [UIColor] = [
            UIColor(red: 1, green: 0.35, blue: 0.05, alpha: 1),
            UIColor(red: 0.1, green: 0.75, blue: 1, alpha: 1),
            UIColor(red: 0.95, green: 0.2, blue: 0.55, alpha: 1),
            UIColor(red: 0.25, green: 0.9, blue: 0.4, alpha: 1),
            UIColor(red: 1, green: 0.85, blue: 0.1, alpha: 1),
        ]
        let board = SCNBox(width: 5.5, height: 2.8, length: 0.22, chamferRadius: 0.05)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        let c = colors[rng.int(in: 0...(colors.count - 1))]
        mat.diffuse.contents = c
        mat.emission.contents = night ? c.withAlphaComponent(0.55) : c.withAlphaComponent(0.15)
        board.materials = [mat]
        let node = SCNNode(geometry: board)
        let off = right * ((TrackRoadsideClearance.treeMinLateral + rng.float(in: 4...10)) * side)
        node.position = SCNVector3(base.x + off.x, base.y + 3.2, base.z + off.z)
        node.eulerAngles.y = yaw + (side > 0 ? 0.15 : -0.15)

        let pole = SCNCylinder(radius: 0.12, height: 3.2)
        let poleMat = SCNMaterial()
        poleMat.lightingModel = .physicallyBased
        poleMat.diffuse.contents = UIColor(white: 0.3, alpha: 1)
        pole.materials = [poleMat]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(0, -2.0, 0)
        node.addChildNode(poleNode)

        TrackRoadsideClearance.pushOutsideRoad(node, track: track, minLateral: TrackRoadsideClearance.treeMinLateral + 2)
        parent.addChildNode(node)
    }
}
