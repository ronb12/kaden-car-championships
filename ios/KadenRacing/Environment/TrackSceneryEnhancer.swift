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
        let base = preset.decorStepDivisor
        switch profile {
        case .coastalCityCircuit: return max(48, base / 2)
        case .coastalOpen, .stormHarbor, .urbanNight: return max(56, Int(Float(base) / 1.7))
        case .desertHighway, .alpineRidge: return max(64, Int(Float(base) / 1.5))
        case .standard, .technicalCircuit: return max(64, Int(Float(base) / 1.55))
        default: return max(72, Int(Float(base) / 1.35))
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
        if art.prefersPalms, rng.unitFloat() < 0.62 {
            placeTree(into: parent, track: track, base: base, right: right, yaw: yaw, coastal: true, rng: &rng, lateral: TrackRoadsideClearance.palmMinLateral + rng.float(in: 2...12))
        }
        if rng.unitFloat() < 0.28 {
            placeSandBerms(into: parent, base: base, right: right, yaw: yaw, rng: &rng)
        }
        if rng.unitFloat() < 0.18 {
            placeBollard(into: parent, base: base, right: right, yaw: yaw, night: night, rng: &rng)
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
        if rng.unitFloat() < 0.35 {
            let bush = SCNSphere(radius: CGFloat(rng.float(in: 0.35...0.75)))
            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased
            mat.diffuse.contents = UIColor(red: 0.42, green: 0.36, blue: 0.22, alpha: 1)
            mat.roughness.contents = 0.94
            bush.materials = [mat]
            let node = SCNNode(geometry: bush)
            let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
            let off = right * ((TrackRoadsideClearance.treeMinLateral + 4) * side)
            node.position = SCNVector3(base.x + off.x, base.y + 0.35, base.z + off.z)
            node.scale = SCNVector3(1.2, 0.65, 1.2)
            TrackRoadsideClearance.pushOutsideRoad(node, track: track, minLateral: TrackRoadsideClearance.treeMinLateral)
            parent.addChildNode(node)
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
        if rng.unitFloat() < 0.48 {
            placeTree(into: parent, track: track, base: base, right: right, yaw: yaw, coastal: false, rng: &rng, lateral: TrackRoadsideClearance.treeMinLateral + rng.float(in: 3...14))
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
            placeBollard(into: parent, base: base, right: right, yaw: yaw, night: true, rng: &rng)
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
            TrackRoadsideClearance.pushOutsideRoad(light, track: track, minLateral: TrackRoadsideClearance.treeMinLateral)
            parent.addChildNode(light)
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
        if rng.unitFloat() < 0.14, let light = KenneyEnvironmentLoader.loadStreetLight(night: night) {
            let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
            let off = right * ((TrackRoadsideClearance.treeMinLateral + 5) * side)
            light.position = SCNVector3(base.x + off.x, base.y, base.z + off.z)
            light.eulerAngles.y = yaw
            TrackRoadsideClearance.pushOutsideRoad(light, track: track, minLateral: TrackRoadsideClearance.treeMinLateral)
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
        rng: inout SeededRandom,
        lateral: Float
    ) {
        guard let tree = KenneyEnvironmentLoader.loadTree(
            targetHeight: rng.float(in: 5...10),
            coastal: coastal,
            rng: &rng
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
        let off = right * ((RaceTrackMesh.halfWidth + 7.5) * side)
        node.position = SCNVector3(base.x + off.x, base.y + 0.55, base.z + off.z)
        node.eulerAngles.y = yaw
        parent.addChildNode(node)
    }
}
