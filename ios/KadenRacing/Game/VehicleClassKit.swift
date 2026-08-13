import SceneKit
import simd
import UIKit

/// Deck-mounted kit only — side boxes never sit flush on a curved USDZ, so they are not used.
enum VehicleClassKit {

    static func attach(to container: SCNNode, profile: VehicleVisualProfile, scale: Float) {
        guard profile.bodyStyle != .policeInterceptor else { return }
        guard let body = container.childNode(withName: "krcVehicleBody", recursively: true)
            ?? container.childNodes.first else { return }
        body.childNode(withName: "krcClassKit", recursively: true)?.removeFromParentNode()

        let hull = bodyHull(in: body)
        let kit = SCNNode()
        kit.name = "krcClassKit"

        let cx = (hull.min.x + hull.max.x) * 0.5
        let minY = hull.min.y
        let minZ = hull.min.z
        let maxZ = hull.max.z
        let spanX = max(0.4, hull.max.x - hull.min.x)
        let spanY = max(0.25, hull.max.y - hull.min.y)
        let spanZ = max(0.4, maxZ - minZ)
        let carbon = VehicleMaterialLibrary.carbonFiber()

        switch profile.bodyStyle {
        case .hyperWedge, .exoticWide, .midEngineSuper, .tuner, .sportsCoupe:
            // Ducktail clipped into the trunk — y sits inside the deck, not hovering above it.
            addBox(
                kit, carbon,
                spanX * 0.58, spanY * 0.022, spanZ * 0.07,
                SCNVector3(cx, minY + spanY * 0.60, minZ + spanZ * 0.07),
                rake: -0.06
            )
        case .muscle:
            addBox(
                kit, carbon,
                spanX * 0.28, spanY * 0.028, spanZ * 0.09,
                SCNVector3(cx, minY + spanY * 0.58, minZ + spanZ * 0.06),
                rake: 0.02
            )
        case .sedanGT:
            addBox(
                kit, VehicleMaterialLibrary.chrome(),
                spanX * 0.48, spanY * 0.018, spanZ * 0.04,
                SCNVector3(cx, minY + spanY * 0.36, minZ + spanZ * 0.02)
            )
        case .roadster:
            addBox(
                kit, carbon,
                spanX * 0.36, spanY * 0.018, spanZ * 0.06,
                SCNVector3(cx, minY + spanY * 0.18, minZ + spanZ * 0.05),
                rake: -0.04
            )
        case .policeInterceptor:
            break
        }

        if kit.childNodes.isEmpty { return }
        body.addChildNode(kit)
        _ = scale
    }

    /// Painted-body hull, skipping wheels / glass / mirrors so kit pieces hug the shell.
    private static func bodyHull(in root: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
        var minV = SIMD3<Float>(repeating: Float.greatestFiniteMagnitude)
        var maxV = SIMD3<Float>(repeating: -Float.greatestFiniteMagnitude)
        var any = false
        root.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let n = ((node.name ?? "") + " " + (node.geometry?.materials.first?.name ?? "")).lowercased()
            if n.contains("wheel") || n.contains("tire") || n.contains("rubber")
                || n.contains("rim") || n.contains("brake") || n.contains("caliper")
                || n.contains("glass") || n.contains("window") || n.contains("windshield")
                || n.contains("mirror") || n.contains("wing_mirror") || n.contains("sidemirror")
                || n.contains("spoiler") || n.contains("wing")
                || n.contains("krcclasskit") || n.contains("krclicense") || n.contains("krcpolice")
                || n.contains("krcsticker") || n.contains("krckidtoy") || n.contains("krcdriverhat") {
                return
            }
            let (mn, mx) = node.boundingBox
            let corners = [
                SCNVector3(mn.x, mn.y, mn.z), SCNVector3(mx.x, mn.y, mn.z),
                SCNVector3(mn.x, mx.y, mn.z), SCNVector3(mx.x, mx.y, mn.z),
                SCNVector3(mn.x, mn.y, mx.z), SCNVector3(mx.x, mn.y, mx.z),
                SCNVector3(mn.x, mx.y, mx.z), SCNVector3(mx.x, mx.y, mx.z),
            ]
            for c in corners {
                let p = node.convertPosition(c, to: root)
                minV = simd_min(minV, SIMD3(p.x, p.y, p.z))
                maxV = simd_max(maxV, SIMD3(p.x, p.y, p.z))
                any = true
            }
        }
        if !any {
            let b = root.boundingBox
            return (b.min, b.max)
        }
        return (
            SCNVector3(minV.x, minV.y, minV.z),
            SCNVector3(maxV.x, maxV.y, maxV.z)
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
            chamferRadius: CGFloat(min(wx, hy, lz) * 0.08)
        )
        g.materials = [mat]
        let n = SCNNode(geometry: g)
        n.name = "krcClassKitPart"
        n.position = pos
        n.eulerAngles.x = rake
        n.castsShadow = false
        parent.addChildNode(n)
    }
}
