import SceneKit
import simd
import UIKit

/// Ocean plane, coastal haze, and wet shoreline for coastal tracks.
enum OceanEnvironmentBuilder {

    static func build(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        night: Bool,
        rainy: Bool,
        enabled: Bool
    ) {
        guard enabled else { return }

        let bounds = trackBounds(track)
        let oceanY: Float = -1.4
        let width = max(bounds.maxX - bounds.minX, 200) + 160
        let depth = max(bounds.maxZ - bounds.minZ, 200) + 120

        let plane = SCNPlane(width: CGFloat(width), height: CGFloat(depth))
        plane.materials = [EnvironmentMaterialLibrary.oceanSurface(night: night, wetWeather: rainy)]
        let ocean = SCNNode(geometry: plane)
        ocean.name = "krcOcean"
        ocean.eulerAngles.x = -Float.pi / 2
        ocean.position = SCNVector3(bounds.centerX, oceanY, bounds.centerZ - depth * 0.22)
        ocean.castsShadow = false
        ocean.renderingOrder = -25
        parent.addChildNode(ocean)

        let shore = SCNPlane(width: CGFloat(width * 0.92), height: 14)
        shore.materials = [EnvironmentMaterialLibrary.shoreFoam(night: night, rainy: rainy)]
        let shoreNode = SCNNode(geometry: shore)
        shoreNode.name = "krcShoreFoam"
        shoreNode.eulerAngles.x = -Float.pi / 2
        shoreNode.position = SCNVector3(bounds.centerX, oceanY + 0.04, bounds.minZ + 12)
        shoreNode.renderingOrder = -6
        parent.addChildNode(shoreNode)
    }

    private struct Bounds {
        var minX: Float, maxX: Float, minZ: Float, maxZ: Float
        var centerX: Float { (minX + maxX) * 0.5 }
        var centerZ: Float { (minZ + maxZ) * 0.5 }
    }

    private static func trackBounds(_ track: ClosedTrackSpline) -> Bounds {
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude
        for i in 0..<64 {
            let p = track.position(at: Float(i) / 64)
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minZ = min(minZ, p.z); maxZ = max(maxZ, p.z)
        }
        return Bounds(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ)
    }
}
