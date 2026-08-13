import SceneKit
import simd
import UIKit

/// Mountains, distant hills, grass blending, atmospheric depth ring.
enum NatureEnvironmentBuilder {

    static func build(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        city: CityRuntimeConfig,
        night: Bool,
        profile: EnvironmentTrackProfile,
        mountainsEnabled: Bool
    ) {
        if PalmCityEnvironment.isActive { return }
        let art = CityEnvironmentArt.profile(for: city)
        let wantsBackdrop = mountainsEnabled
            || profile.prefersMountains
            || profile.prefersOcean
            || profile.usesAtmosphericBackdrop
            || art.prefersOcean
        guard wantsBackdrop else { return }

        let center = trackCentroid(track)
        let outer = trackOuterRadius(track)
        let mat = EnvironmentMaterialLibrary.mountainRock(night: night)

        let peaks: Int = {
            if profile == .coastalCityCircuit || profile.prefersOcean { return 16 }
            if profile == .alpineRidge { return 14 }
            if profile == .desertHighway { return 10 }
            return profile.usesAtmosphericBackdrop ? 12 : 8
        }()
        var rng = SeededRandom(seed: UInt64(city.themeId.rawValue) ^ 0xA11CE)
        for i in 0..<peaks {
            let angle = (Float(i) / Float(peaks)) * 2 * Float.pi
            let radius = outer + 55 + rng.float(in: 0...40)
            let baseH: Float = profile == .alpineRidge ? 32 : (profile.prefersOcean ? 28 : 20)
            let h = baseH + rng.float(in: 4...22)
            let w = 22 + rng.float(in: 0...18)
            let cone = SCNCone(topRadius: 0, bottomRadius: CGFloat(w), height: CGFloat(h))
            cone.materials = [mat]
            let node = SCNNode(geometry: cone)
            node.position = SCNVector3(
                center.x + cos(angle) * radius,
                center.y + h * 0.5 - 2,
                center.z + sin(angle) * radius
            )
            node.castsShadow = false
            parent.addChildNode(node)
        }

        // Low hill ring for atmospheric depth.
        let ring = SCNTorus(ringRadius: CGFloat(outer + 90), pipeRadius: 8)
        let ringTint = city.trackProfile.groundTint(definition: city.definition, night: night)
        let ringMat = SCNMaterial()
        ringMat.lightingModel = .physicallyBased
        ringMat.diffuse.contents = KRCProceduralTextures.grass(tint: ringTint, night: night)
        ringMat.diffuse.wrapS = .repeat
        ringMat.diffuse.wrapT = .repeat
        ringMat.diffuse.contentsTransform = SCNMatrix4MakeScale(24, 24, 1)
        ringMat.roughness.contents = 0.94
        ringMat.metalness.contents = 0
        ring.materials = [ringMat]
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(center.x, center.y - 1.5, center.z)
        ringNode.scale = SCNVector3(1, 0.35, 1)
        ringNode.castsShadow = false
        parent.addChildNode(ringNode)
    }

    private static func trackCentroid(_ track: ClosedTrackSpline) -> SIMD3<Float> {
        var c = SIMD3<Float>(0, 0, 0)
        for p in track.points { c += p }
        return c / Float(max(1, track.points.count))
    }

    private static func trackOuterRadius(_ track: ClosedTrackSpline) -> Float {
        let c = trackCentroid(track)
        return track.points.reduce(0) { acc, p in
            max(acc, simd_length(SIMD2(p.x - c.x, p.z - c.z)))
        }
    }
}
