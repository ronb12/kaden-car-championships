import SceneKit
import UIKit

extension SCNNode {
    /// Depth-first visit of this node and all descendants (SceneKit has no built-in helper on all OS versions).
    func enumerateHierarchy(_ block: (SCNNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        func visit(_ node: SCNNode) {
            guard !stop.boolValue else { return }
            block(node, &stop)
            guard !stop.boolValue else { return }
            for child in node.childNodes {
                visit(child)
            }
        }
        visit(self)
    }
}

extension SCNVector3 {
    func lerped(to target: SCNVector3, alpha: Float) -> SCNVector3 {
        let t = min(1, max(0, alpha))
        return SCNVector3(
            x + (target.x - x) * t,
            y + (target.y - y) * t,
            z + (target.z - z) * t
        )
    }
}

enum KRCSceneKitHelpers {
    static func environmentGradientMap(sky: UIColor, horizon: UIColor, ground: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 256))
        return renderer.image { ctx in
            let colors: [CGColor] = [sky.cgColor, horizon.cgColor, ground.cgColor]
            let locs: [CGFloat] = [0, 0.45, 1]
            let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: locs
            )!
            ctx.cgContext.drawLinearGradient(
                grad,
                start: .zero,
                end: CGPoint(x: 0, y: 256),
                options: []
            )
        }
    }

    static func studioEnvironmentMap() -> UIImage {
        let w = 512, h = 256
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let colors: [CGColor] = [
                UIColor(red: 0.18, green: 0.19, blue: 0.21, alpha: 1).cgColor,
                UIColor(red: 0.22, green: 0.23, blue: 0.25, alpha: 1).cgColor,
                UIColor(red: 0.08, green: 0.085, blue: 0.09, alpha: 1).cgColor,
                UIColor(white: 0.02, alpha: 1).cgColor,
            ]
            let locs: [CGFloat] = [0, 0.38, 0.68, 1]
            let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: locs
            )!
            ctx.cgContext.drawLinearGradient(
                grad,
                start: .zero,
                end: CGPoint(x: 0, y: CGFloat(h)),
                options: []
            )
        }
    }

    static func reflectiveFloor(radius: CGFloat = 6, opacity: CGFloat = 0.55) -> SCNNode {
        let floor = SCNFloor()
        floor.reflectivity = opacity
        floor.reflectionFalloffEnd = 3.5
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(white: 0.06, alpha: 1)
        mat.metalness.contents = 0.85
        mat.roughness.contents = 0.22
        floor.materials = [mat]
        let node = SCNNode(geometry: floor)
        node.position.y = -0.02
        return node
    }

    /// Y of the top surface — seat car bounding-box min Y here in garage preview.
    static let garagePlatformTopY: Float = 0.15

    /// Circular showroom podium for the garage 3D car spin.
    static func garageShowroomPlatform(radius: CGFloat = 2.45) -> SCNNode {
        let podium = SCNNode()
        podium.name = "garageShowroomPlatform"

        let baseH: CGFloat = 0.11
        let capH: CGFloat = 0.038
        let topY = CGFloat(garagePlatformTopY)

        func podiumMaterial(diffuse: UIColor, metal: CGFloat, rough: CGFloat) -> SCNMaterial {
            let mat = SCNMaterial()
            mat.lightingModel = .physicallyBased
            mat.diffuse.contents = diffuse
            mat.metalness.contents = metal
            mat.roughness.contents = rough
            if #available(iOS 13.0, *) {
                mat.clearCoat.contents = 0.12
                mat.clearCoatRoughness.contents = 0.35
            }
            return mat
        }

        let baseGeo = SCNCylinder(radius: radius, height: baseH)
        baseGeo.materials = [
            podiumMaterial(
                diffuse: UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1),
                metal: 0.55,
                rough: 0.48
            ),
        ]
        let base = SCNNode(geometry: baseGeo)
        base.position.y = Float(baseH * 0.5)
        podium.addChildNode(base)

        let capGeo = SCNCylinder(radius: radius * 0.94, height: capH)
        capGeo.materials = [
            podiumMaterial(
                diffuse: UIColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1),
                metal: 0.78,
                rough: 0.26
            ),
        ]
        let cap = SCNNode(geometry: capGeo)
        cap.position.y = Float(topY - capH * 0.5)
        podium.addChildNode(cap)

        let ringGeo = SCNTorus(ringRadius: radius * 0.97, pipeRadius: 0.028)
        ringGeo.materials = [
            podiumMaterial(
                diffuse: UIColor(red: 0.0, green: 0.72, blue: 0.88, alpha: 1),
                metal: 0.9,
                rough: 0.18
            ),
        ]
        let ring = SCNNode(geometry: ringGeo)
        ring.eulerAngles.x = .pi / 2
        ring.position.y = Float(topY - 0.004)
        podium.addChildNode(ring)

        return podium
    }

            // Soft elliptical ground plate for menu / hero car staging (works over a clear UI background).
    static func menuHeroGroundPlate(width: CGFloat = 3.4, depth: CGFloat = 1.35) -> SCNNode {
        let plate = SCNNode()
        plate.name = "menuHeroGround"

        let shadow = SCNPlane(width: width, height: depth)
        let shadowMat = SCNMaterial()
        shadowMat.lightingModel = .constant
        shadowMat.diffuse.contents = UIColor(white: 0, alpha: 0.38)
        shadowMat.transparency = 0.62
        shadowMat.isDoubleSided = true
        shadowMat.writesToDepthBuffer = false
        shadowMat.blendMode = .alpha
        shadow.materials = [shadowMat]
        let shadowNode = SCNNode(geometry: shadow)
        shadowNode.eulerAngles.x = -.pi / 2
        shadowNode.position.y = 0.002
        shadowNode.renderingOrder = -2
        plate.addChildNode(shadowNode)

        let sheen = SCNPlane(width: width * 0.78, height: depth * 0.55)
        let sheenMat = SCNMaterial()
        sheenMat.lightingModel = .physicallyBased
        sheenMat.diffuse.contents = UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 0.4)
        sheenMat.metalness.contents = 0.88
        sheenMat.roughness.contents = 0.22
        sheenMat.isDoubleSided = true
        sheenMat.writesToDepthBuffer = false
        sheen.materials = [sheenMat]
        let sheenNode = SCNNode(geometry: sheen)
        sheenNode.eulerAngles.x = -.pi / 2
        sheenNode.position.y = 0.005
        sheenNode.renderingOrder = -1
        plate.addChildNode(sheenNode)

        return plate
    }
}
