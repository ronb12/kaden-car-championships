import SceneKit
import simd
import UIKit

/// Hero set dressing for Palm City Raceway — neon sign, highway gantry, jersey barriers, fence.
enum PalmCityRacewayBuilder {

    static func build(into parent: SCNNode, track: ClosedTrackSpline, night: Bool) {
        guard PalmCityEnvironment.isActive else { return }

        addNeonRacewaySign(into: parent, track: track, night: night)
        addHighwayGantry(into: parent, track: track, night: night)
        addJerseyBarriers(into: parent, track: track, night: night)
        addChainLinkFence(into: parent, track: track, night: night)
        addPurpleBanners(into: parent, track: track)
    }

    private static func addNeonRacewaySign(into parent: SCNNode, track: ClosedTrackSpline, night: Bool) {
        let t: Float = 0.06
        let base = track.position(at: t)
        let right = track.right(at: t)
        let yaw = atan2(right.x, right.z)

        let board = SCNPlane(width: 18, height: 9)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = KRCProceduralTextures.neonRacewaySign()
        mat.emission.contents = UIColor(
            red: 1,
            green: 0.28,
            blue: 0.58,
            alpha: night ? 0.85 : 0.95
        )
        mat.isDoubleSided = true
        board.materials = [mat]

        let node = SCNNode(geometry: board)
        node.name = "palmCityNeonSign"
        let offset = right * (RaceTrackMesh.halfWidth + 24)
        node.position = SCNVector3(base.x + offset.x, base.y + 7.5, base.z + offset.z)
        node.eulerAngles.y = yaw + Float.pi * 0.5
        parent.addChildNode(node)

        // Sign pole
        let pole = SCNCylinder(radius: 0.14, height: 8)
        pole.materials = [metalPoleMaterial()]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(node.position.x, base.y + 4, node.position.z)
        parent.addChildNode(poleNode)
    }

    private static func addHighwayGantry(into parent: SCNNode, track: ClosedTrackSpline, night: Bool) {
        let t: Float = 0.22
        let base = track.position(at: t)
        let right = track.right(at: t)
        let yaw = atan2(right.x, right.z)
        let halfW = RaceTrackMesh.halfWidth + 2

        let beamMat = metalPoleMaterial()
        let span = SCNBox(width: CGFloat(halfW * 2 + 8), height: 0.35, length: 0.45, chamferRadius: 0.04)
        span.materials = [beamMat]
        let beam = SCNNode(geometry: span)
        beam.position = SCNVector3(base.x, base.y + 7.2, base.z)
        beam.eulerAngles.y = yaw
        parent.addChildNode(beam)

        for (route, dest, side) in [("WEST", "44", Float(-1)), ("WEST", "DOWNTOWN", Float(1))] {
            let panel = SCNPlane(width: 5.2, height: 2.6)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = KRCProceduralTextures.highwaySignPanel(route: route, destination: dest, night: night)
            mat.emission.contents = UIColor(white: night ? 0.15 : 0.05, alpha: 1)
            panel.materials = [mat]
            let sign = SCNNode(geometry: panel)
            let off = right * (halfW * 0.55 * side)
            sign.position = SCNVector3(base.x + off.x, base.y + 7.0, base.z + off.z)
            sign.eulerAngles.y = yaw
            parent.addChildNode(sign)
        }

        for side: Float in [-1, 1] {
            let post = SCNBox(width: 0.28, height: 7.5, length: 0.28, chamferRadius: 0.03)
            post.materials = [beamMat]
            let postNode = SCNNode(geometry: post)
            let off = right * (halfW + 1.8) * side
            postNode.position = SCNVector3(base.x + off.x, base.y + 3.75, base.z + off.z)
            postNode.eulerAngles.y = yaw
            parent.addChildNode(postNode)
        }
    }

    private static func addJerseyBarriers(into parent: SCNNode, track: ClosedTrackSpline, night: Bool) {
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = KRCProceduralTextures.jerseyBarrierChevron(night: night)
        mat.diffuse.wrapS = .repeat
        mat.diffuse.wrapT = .repeat
        mat.diffuse.contentsTransform = SCNMatrix4MakeScale(3, 1, 1)
        mat.roughness.contents = 0.72
        mat.metalness.contents = 0.04

        let pts = track.points
        let step = max(3, pts.count / 90)
        for i in stride(from: 0, to: pts.count, by: step) {
            let t = Float(i) / Float(pts.count)
            let base = track.position(at: t)
            let right = track.right(at: t)
            let yaw = atan2(right.x, right.z)
            let segLen: Float = 3.8

            for side: Float in [-1, 1] {
                let barrier = SCNBox(width: 0.95, height: 0.82, length: CGFloat(segLen), chamferRadius: 0.06)
                barrier.materials = [mat]
                let node = SCNNode(geometry: barrier)
                let off = right * ((RaceTrackMesh.halfWidth + 1.6) * side)
                node.position = SCNVector3(base.x + off.x, base.y + 0.42, base.z + off.z)
                node.eulerAngles.y = yaw
                node.castsShadow = false
                parent.addChildNode(node)
            }
        }
    }

    private static func addChainLinkFence(into parent: SCNNode, track: ClosedTrackSpline, night: Bool) {
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(white: night ? 0.18 : 0.35, alpha: 0.55)
        mat.metalness.contents = 0.75
        mat.roughness.contents = 0.35
        mat.transparency = 0.42
        mat.transparencyMode = .aOne
        mat.isDoubleSided = true

        let pts = track.points
        let step = max(4, pts.count / 70)
        for i in stride(from: 0, to: pts.count, by: step) {
            let t = Float(i) / Float(pts.count)
            let base = track.position(at: t)
            let right = track.right(at: t)
            let yaw = atan2(right.x, right.z)

            let panel = SCNPlane(width: 4.5, height: 3.2)
            panel.materials = [mat]
            let fence = SCNNode(geometry: panel)
            let off = right * (RaceTrackMesh.halfWidth + 10.5)
            fence.position = SCNVector3(base.x + off.x, base.y + 1.65, base.z + off.z)
            fence.eulerAngles.y = yaw + Float.pi * 0.5
            parent.addChildNode(fence)
        }
    }

    private static func addPurpleBanners(into parent: SCNNode, track: ClosedTrackSpline) {
        let t: Float = 0.05
        let base = track.position(at: t)
        let right = track.right(at: t)
        let yaw = atan2(right.x, right.z)

        for (i, side) in [(-1.0 as Float), (1.0 as Float)].enumerated() {
            let banner = SCNPlane(width: 1.4, height: 9)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = UIColor(red: 0.42, green: 0.12, blue: 0.72, alpha: 1)
            mat.emission.contents = UIColor(red: 0.55, green: 0.2, blue: 0.9, alpha: 0.35)
            banner.materials = [mat]
            let node = SCNNode(geometry: banner)
            let off = right * (RaceTrackMesh.halfWidth + 20 + Float(i) * 2.5) * side
            node.position = SCNVector3(base.x + off.x, base.y + 4.8, base.z + off.z)
            node.eulerAngles.y = yaw + Float.pi * 0.5
            parent.addChildNode(node)
        }
    }

    private static func metalPoleMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(white: 0.38, alpha: 1)
        m.metalness.contents = 0.82
        m.roughness.contents = 0.28
        return m
    }
}
