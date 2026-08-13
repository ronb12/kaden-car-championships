import SceneKit
import simd
import UIKit

/// Street lights, billboards, signs, palms, construction zones along the circuit.
enum WorldPropsPlacer {

    static func build(
        into parent: SCNNode,
        city: CityRuntimeConfig,
        night: Bool,
        quality: GraphicsQuality
    ) {
        let preset = EnvironmentGraphicsSettings.preset(for: quality)
        let track = city.track
        let pts = track.points
        guard pts.count >= 8 else { return }

        let art = CityEnvironmentArt.profile(for: city)
        var rng = SeededRandom(seed: city.seed ^ 0x50524F50)
        let step = max(preset.streetLightStep, Int(Float(pts.count) / (Float(preset.decorStepDivisor) / art.decorDensityMul)))

        for i in stride(from: 0, to: pts.count, by: step) {
            let t = Float(i) / Float(pts.count)
            let base = track.position(at: t)
            let right = track.right(at: t)
            let yaw = atan2(right.x, right.z)

            for side: Float in [-1, 1] {
                if let light = KenneyEnvironmentLoader.loadStreetLight(night: night) {
                    let offset = right * (TrackRoadsideClearance.poleMinLateral * side)
                    light.position = SCNVector3(base.x + offset.x, base.y, base.z + offset.z)
                    light.eulerAngles.y = yaw + (side > 0 ? Float.pi * 0.5 : -Float.pi * 0.5)
                    TrackRoadsideClearance.pushOutsideRoad(
                        light, track: track,
                        minLateral: TrackRoadsideClearance.poleMinLateral,
                        extraFootprint: 1.2
                    )
                    parent.addChildNode(light)
                }
            }

            if PalmCityEnvironment.isActive, i % (step * 3) == 0 {
                addPalmCityNeonBillboard(into: parent, at: base, right: right, night: night)
            } else if rng.unitFloat() < 0.22 * city.trackProfile.decorDensityMultiplier {
                addBillboard(into: parent, at: base, right: right, side: 1, night: night, art: art, rng: &rng)
            }

            if art.prefersPalms, rng.unitFloat() < (PalmCityEnvironment.isActive ? 0.55 : 0.35) {
                if let palm = KenneyEnvironmentLoader.loadTree(targetHeight: rng.float(in: 5...9), coastal: true, rng: &rng) {
                    let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
                    let dist = TrackRoadsideClearance.palmMinLateral + rng.float(in: 2...10)
                    let offset = right * (dist * side)
                    palm.position = SCNVector3(base.x + offset.x, base.y, base.z + offset.z)
                    KenneyEnvironmentLoader.alignBuildingToGround(palm, groundY: base.y)
                    TrackRoadsideClearance.pushOutsideRoad(
                        palm, track: track, minLateral: TrackRoadsideClearance.palmMinLateral
                    )
                    parent.addChildNode(palm)
                }
            }

            if rng.unitFloat() < 0.08, let barrier = KenneyEnvironmentLoader.loadRoadBarrier() {
                let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
                let offset = right * ((RaceTrackMesh.halfWidth + 3) * side)
                barrier.position = SCNVector3(base.x + offset.x, base.y, base.z + offset.z)
                barrier.eulerAngles.y = yaw
                parent.addChildNode(barrier)
            }
        }
    }

    private static func addPalmCityNeonBillboard(
        into parent: SCNNode,
        at base: SIMD3<Float>,
        right: SIMD3<Float>,
        night: Bool
    ) {
        let plane = SCNPlane(width: 8, height: 4)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = KRCProceduralTextures.neonRacewaySign()
        mat.emission.contents = UIColor(red: 1, green: 0.3, blue: 0.6, alpha: night ? 0.75 : 0.4)
        plane.materials = [mat]
        let board = SCNNode(geometry: plane)
        let offset = right * (RaceTrackMesh.halfWidth + 26)
        board.position = SCNVector3(base.x + offset.x, base.y + 6, base.z + offset.z)
        board.eulerAngles.y = atan2(-right.x, -right.z)
        parent.addChildNode(board)
    }

    private static func addBillboard(
        into parent: SCNNode,
        at base: SIMD3<Float>,
        right: SIMD3<Float>,
        side: Float,
        night: Bool,
        art: CityEnvironmentArt.Profile,
        rng: inout SeededRandom
    ) {
        let plane = SCNPlane(width: 7, height: 3.6)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        let colors = art.billboardColors
        let muteAmt: CGFloat = night ? 0.16 : 0.32
        let baseColor = VisualTone.mute(colors[rng.int(in: 0...(max(0, colors.count - 1)))], amount: muteAmt)
        mat.diffuse.contents = baseColor
        if night {
            mat.emission.contents = baseColor.withAlphaComponent(0.52)
        }
        mat.metalness.contents = 0.1
        mat.roughness.contents = 0.55
        plane.materials = [mat]

        let board = SCNNode(geometry: plane)
        let offset = right * ((RaceTrackMesh.halfWidth + 22) * side)
        board.position = SCNVector3(base.x + offset.x, base.y + 5.5, base.z + offset.z)
        board.eulerAngles.y = atan2(-right.x * side, -right.z * side)
        parent.addChildNode(board)

        let pole = SCNCylinder(radius: 0.08, height: 5.5)
        pole.materials = [EnvironmentMaterialLibrary.metalRailing(night: night)]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(board.position.x, base.y + 2.75, board.position.z)
        parent.addChildNode(poleNode)
    }
}
