import SceneKit
import simd
import UIKit

/// Road ribbon + curbs, barriers, tunnels, bridges, wet surface, skid marks.
enum RoadEnvironmentBuilder {

    static func build(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        city: CityRuntimeConfig,
        night: Bool,
        weather: EnvironmentLightingSystem.WeatherMode
    ) {
        addBoundedGround(into: parent, track: track, city: city, night: night)
        // Shoulder ribbon removed — RaceTrackMesh grass shoulders overlap at nearly the same height
        // and z-fight (shimmering) beside the asphalt when the car is stopped.

        RaceTrackMesh.build(
            into: parent,
            track: track,
            definition: city.definition,
            trackProfile: city.trackProfile,
            night: night,
            wet: false
        )

        if city.trackProfile == .coastalCityCircuit {
            addCoastalStructures(into: parent, track: track, night: night)
        }

        // Wet sheen plane removed — it z-fought with the road and read as a glitchy overlay.

        if night {
            addTunnelLighting(into: parent, track: track, profile: city.trackProfile)
        }
    }

    private static func addCoastalStructures(into parent: SCNNode, track: ClosedTrackSpline, night: Bool) {
        let pts = track.points
        let step = max(3, pts.count / 48)
        let barrierMat = EnvironmentMaterialLibrary.metalRailing(night: night)
        let concrete = EnvironmentMaterialLibrary.concrete(night: night)

        for i in stride(from: 0, to: pts.count, by: step) {
            let t = Float(i) / Float(pts.count)
            let sector = CoastalCityCircuitTrack.Sector.at(trackT: t)
            let base = track.position(at: t)
            let right = track.right(at: t)
            let yaw = atan2(right.x, right.z)

            switch sector {
            case .bridge:
                if let bridge = KenneyEnvironmentLoader.loadRoadPiece(named: "road-bridge") {
                    bridge.position = SCNVector3(base.x, base.y + 0.2, base.z)
                    bridge.eulerAngles.y = yaw
                    parent.addChildNode(bridge)
                } else {
                    addProceduralBridge(into: parent, at: base, yaw: yaw, mat: concrete)
                }
            case .tunnel:
                addTunnelPortal(into: parent, at: base, right: right, yaw: yaw, mat: concrete, night: night)
            case .oceanHighway:
                addGuardrailSegment(into: parent, base: base, right: right, side: 1, mat: barrierMat)
            default:
                break
            }
        }
    }

    private static func addProceduralBridge(into parent: SCNNode, at base: SIMD3<Float>, yaw: Float, mat: SCNMaterial) {
        let deck = SCNBox(width: 14, height: 0.35, length: 28, chamferRadius: 0.04)
        deck.materials = [mat]
        let deckNode = SCNNode(geometry: deck)
        deckNode.position = SCNVector3(base.x, base.y + 1.1, base.z)
        deckNode.eulerAngles.y = yaw
        parent.addChildNode(deckNode)

        for side: Float in [-1, 1] {
            let pillar = SCNCylinder(radius: 0.45, height: 3.2)
            pillar.materials = [mat]
            let p = SCNNode(geometry: pillar)
            let ox = sin(yaw) * TrackRoadsideClearance.poleMinLateral * side
            let oz = cos(yaw) * TrackRoadsideClearance.poleMinLateral * side
            p.position = SCNVector3(base.x + ox, base.y + 1.6, base.z + oz)
            parent.addChildNode(p)
        }
    }

    private static func addTunnelPortal(
        into parent: SCNNode,
        at base: SIMD3<Float>,
        right: SIMD3<Float>,
        yaw: Float,
        mat: SCNMaterial,
        night: Bool
    ) {
        let arch = SCNBox(width: 16, height: 5.5, length: 1.2, chamferRadius: 0.2)
        arch.materials = [mat]
        let node = SCNNode(geometry: arch)
        node.position = SCNVector3(base.x, base.y + 2.8, base.z)
        node.eulerAngles.y = yaw
        parent.addChildNode(node)

        if night {
            let spot = SCNLight()
            spot.type = .spot
            spot.intensity = 900
            spot.color = UIColor(red: 1, green: 0.95, blue: 0.82, alpha: 1)
            spot.spotInnerAngle = 40
            spot.spotOuterAngle = 65
            let light = SCNNode()
            light.light = spot
            light.position = SCNVector3(base.x, base.y + 5, base.z)
            light.eulerAngles = SCNVector3(-Float.pi / 2.2, yaw, 0)
            parent.addChildNode(light)
        }
    }

    private static func addGuardrailSegment(
        into parent: SCNNode,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        side: Float,
        mat: SCNMaterial
    ) {
        let rail = SCNBox(width: 0.12, height: 0.85, length: 8, chamferRadius: 0.02)
        rail.materials = [mat]
        let node = SCNNode(geometry: rail)
        let offset = right * ((RaceTrackMesh.halfWidth + 2.8) * side)
        node.position = SCNVector3(base.x + offset.x, base.y + 0.45, base.z + offset.z)
        parent.addChildNode(node)
    }

    private static func addWetSheen(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        definition: CityThemeDefinition,
        night: Bool
    ) {
        let mat = EnvironmentMaterialLibrary.asphalt(definition: definition, night: night, wet: true)
        mat.transparency = 0.35
        mat.transparencyMode = .aOne
        let plane = SCNPlane(width: 40, height: 40)
        plane.materials = [mat]
        let node = SCNNode(geometry: plane)
        node.name = "krcWetSheen"
        node.eulerAngles.x = -Float.pi / 2
        let c = track.position(at: 0)
        node.position = SCNVector3(c.x, c.y + 0.08, c.z)
        parent.addChildNode(node)
    }

    /// Local ground plane under the circuit — avoids infinite `SCNFloor` wash-out.
    private static func addBoundedGround(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        city: CityRuntimeConfig,
        night: Bool
    ) {
        var cx: Float = 0
        var cz: Float = 0
        for i in 0..<96 {
            let p = track.position(at: Float(i) / 96)
            cx += p.x
            cz += p.z
        }
        cx /= 96
        cz /= 96
        var outer: Float = 80
        for i in 0..<96 {
            let p = track.position(at: Float(i) / 96)
            outer = max(outer, simd_distance(SIMD2(p.x, p.z), SIMD2(cx, cz)))
        }
        let span = CGFloat(outer * 3.4 + 140)
        let plane = SCNPlane(width: span, height: span)
        let mat = SCNMaterial()
        mat.lightingModel = .lambert
        let art = CityEnvironmentArt.profile(for: city)
        let tint = city.trackProfile.groundTint(definition: city.definition, night: night)
        let openTerrain = city.trackProfile.prefersOcean
            || city.trackProfile == .desertHighway
            || city.trackProfile == .alpineRidge
        if openTerrain {
            mat.diffuse.contents = KRCProceduralTextures.runoffGravel(tint: tint, night: night)
            mat.diffuse.contentsTransform = SCNMatrix4MakeScale(14, 14, 1)
        } else {
            mat.diffuse.contents = KRCProceduralTextures.runoffGravel(
                tint: art.foliage.withAlphaComponent(0.85),
                night: night
            )
            mat.diffuse.contentsTransform = SCNMatrix4MakeScale(16, 16, 1)
        }
        mat.diffuse.wrapS = .repeat
        mat.diffuse.wrapT = .repeat
        mat.roughness.contents = 0.92
        mat.metalness.contents = 0
        plane.materials = [mat]
        let node = SCNNode(geometry: plane)
        node.name = "krcTrackGround"
        node.eulerAngles.x = -Float.pi / 2
        node.position = SCNVector3(cx, -0.08, cz)
        node.castsShadow = false
        node.renderingOrder = -20
        parent.addChildNode(node)
    }

    /// Gravel shoulder between asphalt and open terrain — hides bright ocean/void gaps.
    private static func addShoulderRibbon(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        city: CityRuntimeConfig,
        night: Bool
    ) {
        let segments = 200
        let inner = RaceTrackMesh.halfWidth + 1.2
        let outerW = RaceTrackMesh.halfWidth + (city.trackProfile.prefersOcean ? 11 : 8)
        let tint = city.trackProfile.groundTint(definition: city.definition, night: night)
        let mat: SCNMaterial = if city.trackProfile.prefersOcean || city.trackProfile == .desertHighway {
            EnvironmentMaterialLibrary.sandShoulder(night: night, tint: tint)
        } else if city.trackProfile == .alpineRidge {
            EnvironmentMaterialLibrary.grassTerrain(definition: city.definition, night: night)
        } else {
            EnvironmentMaterialLibrary.sidewalkShoulder(night: night)
        }

        for side: Float in [-1, 1] {
            var verts: [SCNVector3] = []
            var indices: [Int32] = []
            verts.reserveCapacity((segments + 1) * 2)
            indices.reserveCapacity(segments * 6)

            for i in 0...segments {
                let t = Float(i) / Float(segments)
                let p = track.position(at: t)
                let r = track.right(at: t)
                let y = p.y + 0.04
                let innerP = p + r * (inner * side)
                let outerP = p + r * (outerW * side)
                verts.append(SCNVector3(innerP.x, y, innerP.z))
                verts.append(SCNVector3(outerP.x, y, outerP.z))
            }
            for i in 0..<segments {
                let base = Int32(i * 2)
                indices.append(contentsOf: [base, base + 1, base + 2, base + 1, base + 3, base + 2])
            }
            let geo = SCNGeometry(
                sources: [SCNGeometrySource(vertices: verts)],
                elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
            )
            geo.materials = [mat]
            let node = SCNNode(geometry: geo)
            node.name = "krcShoulderRibbon"
            node.castsShadow = false
            node.renderingOrder = -8
            parent.addChildNode(node)
        }
    }

    private static func addTunnelLighting(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        profile: EnvironmentTrackProfile
    ) {
        guard profile == .coastalCityCircuit else { return }
        let pts = track.points
        let step = max(4, pts.count / 20)
        for i in stride(from: 0, to: pts.count, by: step) {
            let t = Float(i) / Float(pts.count)
            guard CoastalCityCircuitTrack.Sector.at(trackT: t) == .tunnel else { continue }
            let base = track.position(at: t)
            let spot = SCNLight()
            spot.type = .omni
            spot.intensity = 600
            spot.attenuationStartDistance = 2
            spot.attenuationEndDistance = 28
            let node = SCNNode()
            node.light = spot
            node.position = SCNVector3(base.x, base.y + 4.5, base.z)
            parent.addChildNode(node)
        }
    }
}
