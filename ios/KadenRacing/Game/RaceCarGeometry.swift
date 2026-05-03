import SceneKit
import UIKit

/// Modern low-poly **supercar silhouette**: tapered fuselage, capsule canopy, flush lighting,
/// air blades — reads fast even with SceneKit primitives (not a stack of uniform boxes).
enum RaceCarGeometry {

    static func build(
        root: SCNNode,
        bodyColor: UIColor,
        scale: CGFloat = 1,
        isPlayer: Bool = true,
        category: VehicleCategory = .sports
    ) {
        let catMul = categoryScale(category)
        let s = Float(scale) * catMul

        let chrome = UIColor(white: 0.88, alpha: 1)
        let rubber = UIColor(white: 0.05, alpha: 1)
        let glass = UIColor(white: 0.72, alpha: 0.28)
        let dark = UIColor(white: 0.06, alpha: 1)
        let accent = bodyColor.withAlphaComponent(0.95)

        func applyCarPaint(_ m: SCNMaterial, rough: CGFloat = 0.35) {
            m.lightingModel = .physicallyBased
            m.diffuse.contents = accent
            m.metalness.contents = UIColor(white: 0.55, alpha: 1)
            m.roughness.contents = UIColor(white: rough, alpha: 1)
            m.specular.contents = UIColor(white: 0.35, alpha: 1)
        }

        // --- Main fuselage: wide chamfer wedge (low, aggressive) ---
        let fuselage = SCNBox(
            width: CGFloat(1.88 * s),
            height: CGFloat(0.52 * s),
            length: CGFloat(4.2 * s),
            chamferRadius: CGFloat(0.22 * s)
        )
        fuselage.materials = [SCNMaterial()]
        applyCarPaint(fuselage.materials[0], rough: 0.28)
        let fuselageNode = SCNNode(geometry: fuselage)
        fuselageNode.position = SCNVector3(0, 0.42 * s, -0.08 * s)
        fuselageNode.eulerAngles.z = -0.03
        fuselageNode.castsShadow = true
        root.addChildNode(fuselageNode)

        // --- Nose cone splitter stack (taper forward) ---
        let nose = SCNBox(
            width: CGFloat(1.72 * s),
            height: CGFloat(0.2 * s),
            length: CGFloat(1.35 * s),
            chamferRadius: CGFloat(0.14 * s)
        )
        nose.materials = [SCNMaterial()]
        applyCarPaint(nose.materials[0], rough: 0.22)
        let noseN = SCNNode(geometry: nose)
        noseN.position = SCNVector3(0, 0.21 * s, 1.42 * s)
        noseN.eulerAngles.x = -0.18
        noseN.castsShadow = true
        root.addChildNode(noseN)

        // --- Cabin: capsule bubble (modern greenhouse) ---
        let canopy = SCNCapsule(capRadius: CGFloat(0.72 * s), height: CGFloat(1.38 * s))
        let glassMat = SCNMaterial()
        glassMat.lightingModel = .physicallyBased
        glassMat.diffuse.contents = glass
        glassMat.metalness.contents = UIColor.white
        glassMat.roughness.contents = UIColor(white: 0.08, alpha: 1)
        glassMat.transparent.contents = UIColor.white
        glassMat.transparency = 0.32
        canopy.materials = [glassMat]
        let cab = SCNNode(geometry: canopy)
        cab.position = SCNVector3(0, 0.78 * s, -0.35 * s)
        cab.eulerAngles.x = Float.pi / 2
        cab.eulerAngles.z = Float.pi / 2
        cab.castsShadow = false
        root.addChildNode(cab)

        // --- Side air blades ---
        for sx in [-1.0, 1.0] as [CGFloat] {
            let blade = SCNBox(
                width: CGFloat(0.08 * s),
                height: CGFloat(0.22 * s),
                length: CGFloat(2.4 * s),
                chamferRadius: CGFloat(0.03 * s)
            )
            let bm = SCNMaterial()
            bm.lightingModel = .physicallyBased
            bm.diffuse.contents = dark
            bm.metalness.contents = UIColor(white: 0.7, alpha: 1)
            bm.roughness.contents = UIColor(white: 0.45, alpha: 1)
            blade.materials = [bm]
            let bn = SCNNode(geometry: blade)
            bn.position = SCNVector3(Float(sx) * 0.98 * s, 0.38 * s, -0.05 * s)
            bn.eulerAngles.y = Float(sx) * -0.08
            root.addChildNode(bn)
        }

        // --- Rear haunches (ellipsoid squash for hips) ---
        let hip = SCNSphere(radius: CGFloat(0.42 * s))
        hip.segmentCount = 18
        let hipMat = SCNMaterial()
        applyCarPaint(hipMat, rough: 0.32)
        hip.materials = [hipMat]
        for sx in [-1.0, 1.0] as [CGFloat] {
            let hn = SCNNode(geometry: hip)
            hn.position = SCNVector3(Float(sx) * 0.82 * s, 0.48 * s, -1.55 * s)
            hn.scale = SCNVector3(1.1, 0.62, 1.35)
            hn.castsShadow = true
            root.addChildNode(hn)
        }

        // --- LED headlamps (thin strips + inner glow) ---
        let headMat = SCNMaterial()
        headMat.lightingModel = .physicallyBased
        headMat.diffuse.contents = UIColor(white: 0.95, alpha: 1)
        headMat.emission.contents = UIColor(white: 0.55, alpha: 1)
        headMat.metalness.contents = UIColor.white
        headMat.roughness.contents = UIColor(white: 0.2, alpha: 1)
        let headGeo = SCNBox(
            width: CGFloat(0.52 * s),
            height: CGFloat(0.06 * s),
            length: CGFloat(0.12 * s),
            chamferRadius: CGFloat(0.02 * s)
        )
        headGeo.materials = [headMat]
        for sx in [-1.0, 1.0] as [CGFloat] {
            let hl = SCNNode(geometry: headGeo)
            hl.position = SCNVector3(Float(sx) * 0.58 * s, 0.36 * s, 1.98 * s)
            hl.eulerAngles.x = -0.12
            hl.castsShadow = false
            root.addChildNode(hl)
        }

        // --- Tail light bar ---
        let tailMat = SCNMaterial()
        tailMat.name = "krcTailLightMaterial"
        tailMat.diffuse.contents = UIColor(red: 0.95, green: 0.08, blue: 0.12, alpha: 1)
        tailMat.emission.contents = UIColor(red: 0.55, green: 0.02, blue: 0.05, alpha: 1)
        tailMat.lightingModel = .constant
        let tailGeo = SCNBox(
            width: CGFloat(1.65 * s),
            height: CGFloat(0.08 * s),
            length: CGFloat(0.1 * s),
            chamferRadius: CGFloat(0.03 * s)
        )
        tailGeo.materials = [tailMat]
        let tl = SCNNode(geometry: tailGeo)
        tl.position = SCNVector3(0, 0.46 * s, -2.22 * s)
        tl.eulerAngles.x = 0.06
        root.addChildNode(tl)

        let brakeMat = SCNMaterial()
        brakeMat.name = "krcBrakeLightMaterial"
        brakeMat.diffuse.contents = UIColor(red: 1, green: 0.03, blue: 0, alpha: 1)
        brakeMat.emission.contents = UIColor(red: 0.75, green: 0, blue: 0, alpha: 1)
        brakeMat.lightingModel = .constant
        let brakeGeo = SCNBox(
            width: CGFloat(0.34 * s),
            height: CGFloat(0.16 * s),
            length: CGFloat(0.08 * s),
            chamferRadius: CGFloat(0.03 * s)
        )
        brakeGeo.materials = [brakeMat]
        for sx in [-1.0, 1.0] as [CGFloat] {
            let outer = SCNNode(geometry: brakeGeo)
            outer.name = "krcBrakeLamp"
            outer.position = SCNVector3(Float(sx) * 0.72 * s, 0.5 * s, -2.28 * s)
            outer.castsShadow = false
            root.addChildNode(outer)

            let inner = SCNNode(geometry: brakeGeo.copy() as? SCNGeometry)
            inner.name = "krcBrakeLamp"
            inner.position = SCNVector3(Float(sx) * 0.42 * s, 0.5 * s, -2.28 * s)
            inner.castsShadow = false
            root.addChildNode(inner)

            let glow = SCNLight()
            glow.type = .omni
            glow.color = UIColor(red: 1, green: 0.03, blue: 0, alpha: 1)
            glow.intensity = 70
            glow.attenuationEndDistance = CGFloat(3.2 * s)
            let glowNode = SCNNode()
            glowNode.name = "krcBrakeGlow"
            glowNode.light = glow
            glowNode.position = SCNVector3(Float(sx) * 0.6 * s, 0.52 * s, -2.42 * s)
            root.addChildNode(glowNode)
        }

        // --- Wheels ---
        let tireR: CGFloat = 0.37 * CGFloat(s)
        let tireW: CGFloat = 0.28 * CGFloat(s)
        let tireGeo = SCNCylinder(radius: tireR, height: tireW)
        tireGeo.firstMaterial?.diffuse.contents = rubber
        tireGeo.firstMaterial?.roughness.contents = UIColor(white: 0.92, alpha: 1)

        let rimGeo = SCNCylinder(radius: tireR * 0.58, height: tireW * 0.5)
        let rimMat = SCNMaterial()
        rimMat.lightingModel = .physicallyBased
        rimMat.diffuse.contents = chrome
        rimMat.metalness.contents = UIColor.white
        rimMat.roughness.contents = UIColor(white: 0.18, alpha: 1)
        rimGeo.materials = [rimMat]

        let positions: [(Float, Float)] = [(0.94, 1.18), (-0.94, 1.18), (0.98, -1.22), (-0.98, -1.22)]
        for p in positions {
            let wg = SCNNode()
            let tire = SCNNode(geometry: tireGeo)
            tire.rotation = SCNVector4(0, 0, 1, Float.pi / 2)
            tire.position = SCNVector3(p.0 * s, Float(tireR), p.1 * s)
            tire.castsShadow = true
            wg.addChildNode(tire)
            let rim = SCNNode(geometry: rimGeo)
            rim.rotation = SCNVector4(0, 0, 1, Float.pi / 2)
            rim.position = tire.position
            wg.addChildNode(rim)
            root.addChildNode(wg)
            wg.name = "wheelGroup"
        }

        if category == .policeInterceptor {
            let bar = SCNBox(
                width: CGFloat(1.88 * s),
                height: CGFloat(0.07 * s),
                length: CGFloat(0.22 * s),
                chamferRadius: CGFloat(0.02 * s)
            )
            let pm = SCNMaterial()
            pm.diffuse.contents = UIColor(red: 0.12, green: 0.14, blue: 0.22, alpha: 1)
            bar.materials = [pm]
            let bn = SCNNode(geometry: bar)
            bn.position = SCNVector3(0, 0.76 * s, -0.18 * s)
            root.addChildNode(bn)
        }

        if isPlayer {
            let glow = SCNPlane(width: CGFloat(1.5 * scale), height: CGFloat(3.6 * scale))
            glow.firstMaterial?.diffuse.contents = UIColor(red: 0.15, green: 0.55, blue: 1, alpha: 0.28)
            glow.firstMaterial?.isDoubleSided = true
            glow.firstMaterial?.writesToDepthBuffer = false
            glow.firstMaterial?.blendMode = .add
            let gn = SCNNode(geometry: glow)
            gn.rotation = SCNVector4(1, 0, 0, -Float.pi / 2)
            gn.position = SCNVector3(0, 0.015 * s, -0.25 * s)
            gn.renderingOrder = -1
            root.addChildNode(gn)
        }
    }

    static func setBrakeLights(root: SCNNode, amount: Float) {
        let a = max(0, min(1, amount))
        root.enumerateChildNodes { node, _ in
            if node.name == "krcBrakeLamp" {
                node.geometry?.materials.forEach { material in
                    material.diffuse.contents = a > 0.05
                        ? UIColor(red: 1, green: 0.04, blue: 0, alpha: 1)
                        : UIColor(red: 0.55, green: 0.02, blue: 0.01, alpha: 1)
                    material.emission.contents = UIColor(red: CGFloat(0.35 + a * 0.65), green: 0, blue: 0, alpha: 1)
                }
            } else if node.name == "krcBrakeGlow", let light = node.light {
                light.intensity = CGFloat(45 + a * 260)
                light.attenuationEndDistance = CGFloat(2.5 + a * 2.5)
            }
        }
    }

    private static func categoryScale(_ c: VehicleCategory) -> Float {
        switch c {
        case .compact: return 0.9
        case .sports: return 0.98
        case .muscle: return 1.04
        case .supercar: return 1
        case .hypercar: return 1.02
        case .policeInterceptor: return 1.03
        }
    }
}
