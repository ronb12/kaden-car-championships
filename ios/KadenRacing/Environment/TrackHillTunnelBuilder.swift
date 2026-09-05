import SceneKit
import simd
import UIKit

/// Tunnels = hollow walls/roof off the racing line. Hills are the road spline itself.
enum TrackHillTunnelBuilder {

    static func build(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        city: CityRuntimeConfig,
        night: Bool
    ) {
        if let span = tunnelSpan(for: city) {
            buildTunnel(into: parent, track: track, span: span, night: night)
        }
    }

    // MARK: - Tunnel

    private static func wantsTunnel(_ profile: EnvironmentTrackProfile) -> Bool {
        switch profile {
        case .speedwayOval: return false
        case .alpineRidge, .coastalCityCircuit, .urbanNight, .technicalCircuit, .stormHarbor, .desertHighway:
            return true
        default: return true
        }
    }

    private struct Span {
        var start: Float
        var end: Float
    }

    private static func tunnelSpan(for city: CityRuntimeConfig) -> Span? {
        guard wantsTunnel(city.trackProfile) else { return nil }
        if city.trackProfile == .coastalCityCircuit {
            return Span(start: 0.58, end: 0.72)
        }
        let track = city.track
        var peakT: Float = 0.45
        var peakY: Float = -1
        for i in 0..<48 {
            let t = Float(i) / 48
            let y = track.position(at: t).y
            if y > peakY {
                peakY = y
                peakT = t
            }
        }
        // Flat ovals skip tunnels — a tube on level ground looks like a hallway on the grass.
        if peakY < 2.2, city.trackProfile == .standard { return nil }
        let half: Float = city.trackProfile == .alpineRidge ? 0.07 : 0.055
        return Span(start: peakT - half, end: peakT + half)
    }

    private static func buildTunnel(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        span: Span,
        night: Bool
    ) {
        let root = SCNNode()
        root.name = "krcTunnel"
        let concrete = tunnelConcrete(night: night)
        let wallInner = RaceTrackMesh.halfWidth + 2.8
        let wallThick: Float = 1.4
        let wallCenter = wallInner + wallThick * 0.5
        let clearHeight: Float = 8.2
        let roofThick: Float = 1.1
        let samples = 18
        let lengthT = wrappedDelta(span.start, span.end)

        for i in 0..<samples {
            let t0 = wrap01(span.start + lengthT * Float(i) / Float(samples))
            let t1 = wrap01(span.start + lengthT * Float(i + 1) / Float(samples))
            let p0 = track.position(at: t0)
            let p1 = track.position(at: t1)
            let mid = (p0 + p1) * 0.5
            let delta = p1 - p0
            let segLen = max(1.2, simd_length(SIMD2(delta.x, delta.z)))
            let yaw = atan2(delta.x, delta.z)
            let right = track.right(at: t0)

            for side: Float in [-1, 1] {
                let wall = SCNBox(
                    width: CGFloat(wallThick),
                    height: CGFloat(clearHeight),
                    length: CGFloat(segLen + 0.15),
                    chamferRadius: 0.08
                )
                wall.materials = [concrete]
                let node = SCNNode(geometry: wall)
                let off = right * (wallCenter * side)
                node.position = SCNVector3(mid.x + off.x, mid.y + clearHeight * 0.5, mid.z + off.z)
                node.eulerAngles.y = yaw
                node.castsShadow = false
                root.addChildNode(node)
            }

            let roofW = wallCenter * 2 + wallThick
            let roof = SCNBox(
                width: CGFloat(roofW),
                height: CGFloat(roofThick),
                length: CGFloat(segLen + 0.15),
                chamferRadius: 0.06
            )
            roof.materials = [concrete]
            let roofNode = SCNNode(geometry: roof)
            roofNode.position = SCNVector3(mid.x, mid.y + clearHeight + roofThick * 0.5, mid.z)
            roofNode.eulerAngles.y = yaw
            roofNode.castsShadow = false
            root.addChildNode(roofNode)

            if i % 3 == 0 {
                addCeilingLight(into: root, at: mid, y: mid.y + clearHeight - 0.35, yaw: yaw, night: night, alwaysOn: true)
            }
        }

        addPortal(into: root, track: track, t: wrap01(span.start), wallCenter: wallCenter, clearHeight: clearHeight, concrete: concrete, night: night, entrance: true)
        addPortal(into: root, track: track, t: wrap01(span.end), wallCenter: wallCenter, clearHeight: clearHeight, concrete: concrete, night: night, entrance: false)

        parent.addChildNode(root)
    }

    private static func addPortal(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        t: Float,
        wallCenter: Float,
        clearHeight: Float,
        concrete: SCNMaterial,
        night: Bool,
        entrance: Bool
    ) {
        let p = track.position(at: t)
        let right = track.right(at: t)
        let tan = track.tangent(t)
        let yaw = atan2(tan.x, tan.z)
        let lintel = SCNBox(width: CGFloat(wallCenter * 2 + 2.2), height: 1.4, length: 2.2, chamferRadius: 0.12)
        lintel.materials = [concrete]
        let lintelNode = SCNNode(geometry: lintel)
        lintelNode.position = SCNVector3(p.x, p.y + clearHeight + 0.2, p.z)
        lintelNode.eulerAngles.y = yaw
        parent.addChildNode(lintelNode)

        // Bright candy stripe portal ring — reads as a tunnel entrance from chase cam.
        let stripe = SCNBox(width: CGFloat(wallCenter * 2 + 2.6), height: 0.55, length: 0.35, chamferRadius: 0.04)
        let stripeMat = SCNMaterial()
        stripeMat.lightingModel = .constant
        stripeMat.diffuse.contents = entrance
            ? UIColor(red: 1, green: 0.55, blue: 0.08, alpha: 1)
            : UIColor(red: 0.15, green: 0.85, blue: 1.0, alpha: 1)
        stripeMat.emission.contents = entrance
            ? UIColor(red: night ? 0.9 : 0.45, green: night ? 0.4 : 0.2, blue: 0.05, alpha: 1)
            : UIColor(red: 0.05, green: night ? 0.7 : 0.35, blue: night ? 0.9 : 0.45, alpha: 1)
        stripe.materials = [stripeMat]
        let stripeNode = SCNNode(geometry: stripe)
        stripeNode.position = SCNVector3(p.x, p.y + clearHeight + 0.85, p.z)
        stripeNode.eulerAngles.y = yaw
        parent.addChildNode(stripeNode)

        for side: Float in [-1, 1] {
            let pillar = SCNBox(width: 1.8, height: CGFloat(clearHeight + 0.4), length: 2.2, chamferRadius: 0.1)
            pillar.materials = [concrete]
            let node = SCNNode(geometry: pillar)
            let off = right * ((wallCenter + 0.2) * side)
            node.position = SCNVector3(p.x + off.x, p.y + (clearHeight + 0.4) * 0.5, p.z + off.z)
            node.eulerAngles.y = yaw
            parent.addChildNode(node)

            // Side glow strips on pillars.
            let glow = SCNBox(width: 0.22, height: CGFloat(clearHeight * 0.85), length: 0.18, chamferRadius: 0.03)
            let gMat = SCNMaterial()
            gMat.lightingModel = .constant
            gMat.diffuse.contents = stripeMat.diffuse.contents
            gMat.emission.contents = stripeMat.emission.contents
            glow.materials = [gMat]
            let glowNode = SCNNode(geometry: glow)
            glowNode.position = SCNVector3(p.x + off.x * 0.92, p.y + clearHeight * 0.45, p.z)
            glowNode.eulerAngles.y = yaw
            parent.addChildNode(glowNode)
        }

        // Always-on portal lights (day and night) so tunnels never look like dark holes.
        let light = SCNLight()
        light.type = .omni
        light.intensity = night ? 720 : 420
        light.color = UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 1)
        light.attenuationStartDistance = 2
        light.attenuationEndDistance = 22
        let lamp = SCNNode()
        lamp.light = light
        lamp.position = SCNVector3(p.x, p.y + clearHeight * 0.7, p.z)
        parent.addChildNode(lamp)
    }

    private static func addCeilingLight(
        into parent: SCNNode,
        at mid: SIMD3<Float>,
        y: Float,
        yaw: Float,
        night: Bool,
        alwaysOn: Bool = false
    ) {
        let lamp = SCNBox(width: 2.4, height: 0.12, length: 0.45, chamferRadius: 0.02)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        let glow = UIColor(red: 1, green: 0.94, blue: 0.78, alpha: 1)
        mat.diffuse.contents = glow
        mat.emission.contents = glow
        lamp.materials = [mat]
        let node = SCNNode(geometry: lamp)
        node.position = SCNVector3(mid.x, y, mid.z)
        node.eulerAngles.y = yaw
        parent.addChildNode(node)
        if night || alwaysOn {
            let light = SCNLight()
            light.type = .omni
            light.intensity = night ? 420 : 260
            light.attenuationStartDistance = 2
            light.attenuationEndDistance = 18
            light.color = glow
            let l = SCNNode()
            l.light = light
            l.position = SCNVector3(0, -0.4, 0)
            node.addChildNode(l)
        }
    }

    // MARK: - Materials / math

    private static func tunnelConcrete(night: Bool) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(
            red: night ? 0.22 : 0.42,
            green: night ? 0.22 : 0.41,
            blue: night ? 0.21 : 0.38,
            alpha: 1
        )
        mat.roughness.contents = 0.88
        mat.metalness.contents = 0.04
        VehicleMaterialLibrary.configureFullyOpaque(mat)
        return mat
    }

    private static func wrap01(_ t: Float) -> Float {
        var v = t.truncatingRemainder(dividingBy: 1)
        if v < 0 { v += 1 }
        return v
    }

    private static func wrappedDelta(_ start: Float, _ end: Float) -> Float {
        var d = end - start
        if d < 0 { d += 1 }
        return d
    }
}
