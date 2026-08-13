import SceneKit
import UIKit

/// Bolt-on geometry on the bundled USDZ — class flavor without replacing the quality mesh.
enum VehicleClassKit {

    static func attach(to container: SCNNode, profile: VehicleVisualProfile, scale: Float) {
        guard let body = container.childNode(withName: "krcVehicleBody", recursively: true)
            ?? container.childNodes.first else { return }
        let kit = SCNNode()
        kit.name = "krcClassKit"
        body.childNode(withName: "krcClassKit", recursively: false)?.removeFromParentNode()

        let b = body.boundingBox
        let minB = b.min
        let maxB = b.max
        let cx = (minB.x + maxB.x) * 0.5
        let cy = minB.y
        let cz = (minB.z + maxB.z) * 0.5
        let spanX = max(0.5, maxB.x - minB.x)
        let spanY = max(0.3, maxB.y - minB.y)
        let spanZ = max(0.5, maxB.z - minB.z)
        let accent = profile.accentTrim ?? profile.paintDescriptor.color
        let carbon = VehicleMaterialLibrary.carbonFiber()
        let accentMat = accentMaterial(accent)

        switch profile.bodyStyle {
        case .hyperWedge:
            addBox(kit, carbon, spanX * 0.88, spanY * 0.04, spanZ * 0.14,
                   SCNVector3(cx, cy + spanY * 0.92, minB.z + spanZ * 0.12), rake: -0.22)
            addBox(kit, carbon, spanX * 0.72, spanY * 0.03, spanZ * 0.08,
                   SCNVector3(cx, cy + spanY * 0.14, maxB.z - spanZ * 0.04), rake: -0.15)
        case .exoticWide:
            for sx: Float in [-1, 1] {
                addBox(kit, carbon, spanX * 0.08, spanY * 0.22, spanZ * 0.42,
                       SCNVector3(cx + sx * spanX * 0.52, cy + spanY * 0.42, cz + spanZ * 0.04))
            }
            addBox(kit, carbon, spanX * 0.9, spanY * 0.05, spanZ * 0.12,
                   SCNVector3(cx, cy + spanY * 0.88, minB.z + spanZ * 0.18), rake: -0.28)
        case .midEngineSuper:
            addBox(kit, carbon, spanX * 0.55, spanY * 0.04, spanZ * 0.1,
                   SCNVector3(cx, cy + spanY * 0.88, minB.z + spanZ * 0.22), rake: 0.32)
            if profile.carId == "f40" {
                for sx: Float in [-1, 1] {
                    addBox(kit, bodyMat(profile), spanX * 0.04, spanY * 0.2, spanZ * 0.05,
                           SCNVector3(cx + sx * spanX * 0.46, cy + spanY * 0.78, minB.z + spanZ * 0.38))
                }
            }
        case .muscle:
            addBox(kit, accentMat, spanX * 0.06, spanY * 0.03, spanZ * 0.72,
                   SCNVector3(cx + spanX * 0.2, cy + spanY * 0.52, cz))
            addBox(kit, accentMat, spanX * 0.06, spanY * 0.03, spanZ * 0.72,
                   SCNVector3(cx - spanX * 0.2, cy + spanY * 0.52, cz))
            addBox(kit, carbon, spanX * 0.35, spanY * 0.08, spanZ * 0.18,
                   SCNVector3(cx, cy + spanY * 0.72, maxB.z - spanZ * 0.08), rake: 0.08)
            for sx: Float in [-1, 1] {
                addBox(kit, carbon, spanX * 0.05, spanY * 0.14, spanZ * 0.55,
                       SCNVector3(cx + sx * spanX * 0.54, cy + spanY * 0.18, cz - spanZ * 0.05))
            }
        case .tuner, .sportsCoupe:
            addBox(kit, carbon, spanX * 0.82, spanY * 0.06, spanZ * 0.12,
                   SCNVector3(cx, cy + spanY * 0.82, minB.z + spanZ * 0.14), rake: -0.18)
            if ["gtr", "r34", "r35-nismo", "evo", "sti"].contains(profile.carId) {
                for sx: Float in [-1, 1] {
                    addBox(kit, carbon, spanX * 0.04, spanY * 0.26, spanZ * 0.06,
                           SCNVector3(cx + sx * spanX * 0.44, cy + spanY * 0.58, minB.z + spanZ * 0.2))
                }
            }
        case .sedanGT:
            addBox(kit, VehicleMaterialLibrary.chrome(), spanX * 0.75, spanY * 0.04, spanZ * 0.08,
                   SCNVector3(cx, cy + spanY * 0.48, maxB.z - spanZ * 0.02))
        case .roadster:
            addBox(kit, carbon, spanX * 0.5, spanY * 0.04, spanZ * 0.1,
                   SCNVector3(cx, cy + spanY * 0.22, maxB.z - spanZ * 0.06), rake: -0.1)
        case .policeInterceptor:
            break
        }

        body.addChildNode(kit)
        _ = scale
    }

    private static func bodyMat(_ profile: VehicleVisualProfile) -> SCNMaterial {
        VehicleMaterialLibrary.bodyPaint(profile.paintDescriptor)
    }

    private static func accentMaterial(_ color: UIColor) -> SCNMaterial {
        VehicleMaterialLibrary.bodyPaint(
            VehicleMaterialLibrary.PaintDescriptor(color: color, finish: .gloss)
        )
    }

    private static func addBox(
        _ parent: SCNNode,
        _ mat: SCNMaterial,
        _ wx: Float, _ hy: Float, _ lz: Float,
        _ pos: SCNVector3,
        rake: Float = 0
    ) {
        let g = SCNBox(
            width: CGFloat(wx),
            height: CGFloat(hy),
            length: CGFloat(lz),
            chamferRadius: CGFloat(min(wx, hy, lz) * 0.12)
        )
        g.materials = [mat]
        let n = SCNNode(geometry: g)
        n.position = pos
        n.eulerAngles.x = rake
        n.castsShadow = true
        parent.addChildNode(n)
    }
}
