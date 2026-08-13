import SceneKit
import UIKit

/// License plates, police kit, and rear badges — parented to the car body so they move with the mesh.
enum CarDecals {

    static func apply(to carNode: SCNNode, container: SCNNode, carId: String, isPlayer: Bool, scale: Float) {
        carNode.childNode(withName: "krcLicensePlate", recursively: true)?.removeFromParentNode()
        container.childNode(withName: "krcLicensePlate", recursively: true)?.removeFromParentNode()
        carNode.childNode(withName: "krcPoliceKit", recursively: true)?.removeFromParentNode()
        carNode.childNode(withName: "krcPoliceMarkings", recursively: true)?.removeFromParentNode()

        if carId == "police" {
            applyPoliceKit(to: carNode, scale: scale)
        }

        let host = container.childNode(withName: "krcVehicleRoot", recursively: false) ?? carNode
        let layout = rearPlateLayout(carNode: host, scale: scale)
        let label = GameCatalog.plateLabel(carId: carId, isPlayer: isPlayer)
        licensePlate(
            to: host,
            text: label,
            position: SCNVector3(0, layout.y, layout.z),
            yaw: layout.yaw,
            pitch: layout.pitch,
            planeW: layout.width * (carId == "police" ? 0.9 : 1),
            planeH: layout.height,
            darkPlate: carId == "police"
        )

        if isPlayer {
            applyKidShowOff(to: host, container: container, carId: carId, scale: scale)
        }
    }

    private static func applyKidShowOff(to carNode: SCNNode, container: SCNNode, carId: String, scale: Float) {
        carNode.childNode(withName: "krcStickerHood", recursively: true)?.removeFromParentNode()
        carNode.childNode(withName: "krcStickerDoor", recursively: true)?.removeFromParentNode()
        carNode.childNode(withName: "krcKidToyKit", recursively: true)?.removeFromParentNode()
        container.childNode(withName: "krcDriverHat", recursively: true)?.removeFromParentNode()
        carNode.childNode(withName: "krcFlameToy", recursively: true)?.removeFromParentNode()

        let loadout = KidShowOffLoadout.live
        let hull = VehicleAxes.paintedHull(in: carNode)
        let frame = VehicleAxes.frame(in: carNode)
        let frontIsMaxZ = (frame?.frontZ ?? hull.max.z) >= (frame?.rearZ ?? hull.min.z)
        let spanX = max(0.4, hull.max.x - hull.min.x)
        let spanY = max(0.25, hull.max.y - hull.min.y)
        let spanZ = max(0.4, hull.max.z - hull.min.z)
        let cx = (hull.min.x + hull.max.x) * 0.5
        let cz = (hull.min.z + hull.max.z) * 0.5
        let frontZ = frontIsMaxZ ? hull.max.z : hull.min.z
        let towardFront: Float = frontIsMaxZ ? 1 : -1

        if let sticker = loadout.hoodSticker {
            let size = min(spanX, spanZ) * 0.28
            slapSticker(
                sticker,
                named: "krcStickerHood",
                onto: carNode,
                position: SCNVector3(
                    cx,
                    hull.max.y + 0.012 * scale,
                    cz + towardFront * spanZ * 0.18
                ),
                euler: SCNVector3(-Float.pi / 2, 0, 0),
                width: size,
                height: size
            )
        }
        if let sticker = loadout.doorSticker {
            let size = min(spanY, spanZ) * 0.32
            slapSticker(
                sticker,
                named: "krcStickerDoor",
                onto: carNode,
                position: SCNVector3(
                    hull.max.x + 0.014 * scale,
                    hull.min.y + spanY * 0.52,
                    cz
                ),
                euler: SCNVector3(0, Float.pi / 2, 0),
                width: size,
                height: size
            )
        }

        let kit = SCNNode()
        kit.name = "krcKidToyKit"
        if loadout.toys.contains(.lightBar), carId != "police" {
            let barW = spanX * 0.46
            let barGeo = SCNBox(
                width: CGFloat(barW),
                height: CGFloat(0.07 * scale),
                length: CGFloat(0.18 * scale),
                chamferRadius: 0.015
            )
            let barMat = SCNMaterial()
            barMat.lightingModel = .constant
            barMat.diffuse.contents = UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1)
            barGeo.materials = [barMat]
            let bar = SCNNode(geometry: barGeo)
            bar.name = "krcKidLightBar"
            bar.position = SCNVector3(cx, hull.max.y + 0.04 * scale, cz + towardFront * spanZ * 0.08)
            kit.addChildNode(bar)
            let lenses: [(Float, UIColor)] = [
                (-0.38, UIColor(red: 1, green: 0.08, blue: 0.14, alpha: 1)),
                (0, UIColor(red: 0.12, green: 0.48, blue: 1, alpha: 1)),
                (0.38, UIColor(red: 1, green: 0.08, blue: 0.14, alpha: 1)),
            ]
            for (nx, color) in lenses {
                let lens = SCNBox(width: CGFloat(0.12 * scale), height: CGFloat(0.05 * scale), length: CGFloat(0.12 * scale), chamferRadius: 0.01)
                let mat = SCNMaterial()
                mat.lightingModel = .constant
                mat.diffuse.contents = color
                mat.emission.contents = color
                lens.materials = [mat]
                let node = SCNNode(geometry: lens)
                node.name = "krcKidLightLens"
                node.position = SCNVector3(cx + nx * barW * 0.5, hull.max.y + 0.07 * scale, cz + towardFront * spanZ * 0.08)
                kit.addChildNode(node)
            }
        }
        if loadout.toys.contains(.roofBox) {
            let box = SCNBox(
                width: CGFloat(spanX * 0.42),
                height: CGFloat(0.16 * scale),
                length: CGFloat(spanZ * 0.28),
                chamferRadius: 0.03
            )
            let mat = SCNMaterial()
            mat.lightingModel = .lambert
            mat.diffuse.contents = UIColor(red: 0.82, green: 0.55, blue: 0.16, alpha: 1)
            mat.emission.contents = UIColor(red: 0.82, green: 0.55, blue: 0.16, alpha: 0.18)
            box.materials = [mat]
            let node = SCNNode(geometry: box)
            node.name = "krcKidRoofBox"
            node.position = SCNVector3(cx, hull.max.y + 0.12 * scale, cz - towardFront * spanZ * 0.08)
            kit.addChildNode(node)
        }
        if loadout.toys.contains(.flameTrail) {
            for sx: Float in [-1, 1] {
                let cone = SCNCone(topRadius: 0.01, bottomRadius: CGFloat(0.045 * scale), height: CGFloat(0.22 * scale))
                let mat = SCNMaterial()
                mat.lightingModel = .constant
                mat.diffuse.contents = UIColor(red: 1, green: 0.42, blue: 0.08, alpha: 1)
                mat.emission.contents = UIColor(red: 1, green: 0.55, blue: 0.12, alpha: 1)
                cone.materials = [mat]
                let node = SCNNode(geometry: cone)
                node.name = "krcFlameToy"
                node.eulerAngles.x = Float.pi / 2
                let rearZ = frontIsMaxZ ? hull.min.z : hull.max.z
                node.position = SCNVector3(
                    cx + sx * spanX * 0.18,
                    hull.min.y + spanY * 0.22,
                    rearZ - towardFront * 0.06 * scale
                )
                kit.addChildNode(node)
            }
        }
        if !kit.childNodes.isEmpty {
            carNode.addChildNode(kit)
        }

        if let hat = loadout.hat {
            let driver = container.childNode(withName: "krcDriver", recursively: true)
            let host = driver ?? carNode
            let brim = SCNCylinder(radius: CGFloat(0.09 * scale), height: CGFloat(0.025 * scale))
            let brimMat = SCNMaterial()
            brimMat.lightingModel = .constant
            brimMat.diffuse.contents = hat.color
            brimMat.emission.contents = hat.color.withAlphaComponent(0.25)
            brim.materials = [brimMat]
            let hatNode = SCNNode(geometry: brim)
            hatNode.name = "krcDriverHat"
            if driver != nil {
                hatNode.position = SCNVector3(0, 0.42, 0)
            } else {
                hatNode.position = SCNVector3(cx, hull.max.y + 0.08 * scale, cz + towardFront * spanZ * 0.12)
            }
            host.addChildNode(hatNode)

            let crownH: Float = hat == .champ ? 0.07 : 0.05
            let crown = SCNCylinder(radius: CGFloat(0.055 * scale), height: CGFloat(crownH * scale))
            crown.materials = [brimMat]
            let crownNode = SCNNode(geometry: crown)
            crownNode.name = "krcDriverHatCrown"
            crownNode.position.y = 0.03 * scale
            hatNode.addChildNode(crownNode)
        }
        _ = frontZ
    }

    private static func slapSticker(
        _ sticker: KidSticker,
        named name: String,
        onto parent: SCNNode,
        position: SCNVector3,
        euler: SCNVector3,
        width: Float,
        height: Float
    ) {
        let plane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
        let mat = SCNMaterial()
        let image = sticker.makeImage()
        mat.lightingModel = .constant
        mat.diffuse.contents = image
        mat.emission.contents = image
        mat.emission.intensity = 0.85
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = true
        plane.materials = [mat]
        let node = SCNNode(geometry: plane)
        node.name = name
        node.position = position
        node.eulerAngles = euler
        node.renderingOrder = 130
        parent.addChildNode(node)
    }

    /// Rear bumper face of the painted hull — inset so the plate sits on the valence, not the spoiler AABB.
    private static func rearPlateLayout(carNode: SCNNode, scale: Float) -> (y: Float, z: Float, yaw: Float, pitch: Float, width: Float, height: Float) {
        let hull = VehicleAxes.paintedHull(in: carNode)
        let widthX = max(0.4, hull.max.x - hull.min.x)
        let bodyH = max(0.25, hull.max.y - hull.min.y)
        let frame = VehicleAxes.frame(in: carNode)
        let frontIsMaxZ = (frame?.frontZ ?? hull.max.z) >= (frame?.rearZ ?? hull.min.z)
        let rearZ = frontIsMaxZ ? hull.min.z : hull.max.z
        let outward: Float = frontIsMaxZ ? -1 : 1
        // Pull into the bumper so the frame back kisses the shell (not floating on kit/exhaust bounds).
        let z = rearZ - outward * (0.022 * max(0.6, scale))
        let yaw: Float = outward < 0 ? .pi : 0
        // Bumper band, above exhaust tips (~11% height).
        let y = hull.min.y + bodyH * 0.33
        let plateW = max(0.62 * scale, widthX * 0.30)
        let plateH = plateW * 0.34
        return (y, z, yaw, 0, plateW, plateH)
    }

    private static func applyPoliceKit(to carNode: SCNNode, scale: Float) {
        let (minB, maxB) = carNode.boundingBox
        let widthX = maxB.x - minB.x
        let lengthZ = maxB.z - minB.z
        // Sit on top of the roof mesh — height*0.88 buried the bar inside the cabin.
        let roofY = maxB.y + 0.035 * scale
        let roofZ = minB.z + lengthZ * 0.55
        let barWidth = max(0.62 * scale, widthX * 0.48)
        let frontZ = maxB.z - lengthZ * 0.02
        let rearZ = minB.z + lengthZ * 0.02
        let bumperY = minB.y + (maxB.y - minB.y) * 0.42

        let kit = SCNNode()
        kit.name = "krcPoliceKit"

        let barGeo = SCNBox(
            width: CGFloat(barWidth),
            height: CGFloat(0.08 * scale),
            length: CGFloat(0.20 * scale),
            chamferRadius: 0.02
        )
        let barMat = SCNMaterial()
        barMat.lightingModel = .constant
        barMat.diffuse.contents = UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1)
        barGeo.materials = [barMat]
        let bar = SCNNode(geometry: barGeo)
        bar.name = "krcPoliceLightBar"
        bar.position = SCNVector3(0, roofY, roofZ)
        kit.addChildNode(bar)

        let red = UIColor(red: 1, green: 0.05, blue: 0.12, alpha: 1)
        let blue = UIColor(red: 0.08, green: 0.45, blue: 1, alpha: 1)
        let white = UIColor(red: 1, green: 0.96, blue: 0.88, alpha: 1)

        // Full roof bar: R W B W R pattern so the whole bar reads as active.
        let roofLenses: [(Float, UIColor, String)] = [
            (-0.42, red, "Red"),
            (-0.21, white, "WhiteL"),
            (0.00, blue, "Blue"),
            (0.21, white, "WhiteR"),
            (0.42, red, "Red2"),
        ]
        for (nx, color, side) in roofLenses {
            addPoliceLens(
                to: kit,
                nameSuffix: side,
                color: color,
                position: SCNVector3(nx * barWidth * 0.5, roofY + 0.035 * scale, roofZ),
                size: SIMD3(0.16 * scale, 0.05 * scale, 0.13 * scale),
                lightRange: 9.0 * scale
            )
        }

        // Grill / chin flashers — visible from chase cam ahead.
        for (sx, color, side): (Float, UIColor, String) in [
            (-1, red, "GrillRed"),
            (1, blue, "GrillBlue"),
        ] {
            addPoliceLens(
                to: kit,
                nameSuffix: side,
                color: color,
                position: SCNVector3(sx * widthX * 0.28, bumperY, frontZ),
                size: SIMD3(0.14 * scale, 0.06 * scale, 0.08 * scale),
                lightRange: 7.0 * scale
            )
        }

        // Rear deck flashers.
        for (sx, color, side): (Float, UIColor, String) in [
            (-1, blue, "RearBlue"),
            (1, red, "RearRed"),
        ] {
            addPoliceLens(
                to: kit,
                nameSuffix: side,
                color: color,
                position: SCNVector3(sx * widthX * 0.22, roofY - 0.02 * scale, rearZ + lengthZ * 0.08),
                size: SIMD3(0.12 * scale, 0.045 * scale, 0.08 * scale),
                lightRange: 6.5 * scale
            )
        }

        carNode.addChildNode(kit)
    }

    private static func addPoliceLens(
        to kit: SCNNode,
        nameSuffix: String,
        color: UIColor,
        position: SCNVector3,
        size: SIMD3<Float>,
        lightRange: Float
    ) {
        let lensGeo = SCNBox(
            width: CGFloat(size.x),
            height: CGFloat(size.y),
            length: CGFloat(size.z),
            chamferRadius: 0.015
        )
        let lensMat = SCNMaterial()
        lensMat.name = "krcPoliceLensMat\(nameSuffix)"
        lensMat.lightingModel = .constant
        lensMat.diffuse.contents = color
        lensMat.emission.contents = color
        lensGeo.materials = [lensMat]
        let lens = SCNNode(geometry: lensGeo)
        lens.name = "krcPoliceLens\(nameSuffix)"
        lens.position = position
        kit.addChildNode(lens)

        let light = SCNLight()
        light.type = .omni
        light.color = color
        light.intensity = 0
        light.attenuationEndDistance = CGFloat(lightRange)
        let lightNode = SCNNode()
        lightNode.name = "krcPoliceFlash\(nameSuffix)"
        lightNode.light = light
        lightNode.position = SCNVector3(position.x, position.y + size.y * 0.6, position.z)
        kit.addChildNode(lightNode)
    }

    private static func licensePlate(
        to parent: SCNNode,
        text: String,
        position: SCNVector3,
        yaw: Float,
        pitch: Float = 0,
        planeW: Float,
        planeH: Float,
        darkPlate: Bool = false
    ) {
        let image = renderLicensePlate(text: text, canvasW: 2048, canvasH: 640, darkPlate: darkPlate)

        let mount = SCNNode()
        mount.name = "krcLicensePlate"
        mount.position = position
        mount.eulerAngles = SCNVector3(pitch, yaw, 0)

        let framePad: CGFloat = 0.012
        let depth: CGFloat = 0.008
        let frameGeo = SCNBox(
            width: CGFloat(planeW) + framePad,
            height: CGFloat(planeH) + framePad,
            length: depth,
            chamferRadius: CGFloat(planeH) * 0.06
        )
        let frameMat = SCNMaterial()
        frameMat.name = darkPlate ? "krcPolicePlateFrameMat" : "krcPlateFrameMat"
        frameMat.lightingModel = darkPlate ? .constant : .physicallyBased
        frameMat.diffuse.contents = darkPlate
            ? UIColor(red: 0.22, green: 0.24, blue: 0.28, alpha: 1)
            : UIColor(red: 0.72, green: 0.74, blue: 0.78, alpha: 1)
        if darkPlate {
            frameMat.emission.contents = UIColor(red: 0.15, green: 0.16, blue: 0.2, alpha: 1)
        } else {
            frameMat.metalness.contents = 0.88
            frameMat.roughness.contents = 0.24
        }
        frameGeo.materials = [frameMat]
        let frameNode = SCNNode(geometry: frameGeo)
        frameNode.name = darkPlate ? "krcPolicePlateFrame" : "krcPlateFrame"
        mount.addChildNode(frameNode)

        let faceMat = SCNMaterial()
        faceMat.name = darkPlate ? "krcPolicePlateFaceMat" : "krcPlateFaceMat"
        faceMat.lightingModel = .constant
        faceMat.diffuse.contents = image
        faceMat.diffuse.magnificationFilter = .linear
        faceMat.diffuse.minificationFilter = .linear
        faceMat.diffuse.mipFilter = .none
        faceMat.diffuse.wrapS = .clamp
        faceMat.diffuse.wrapT = .clamp
        faceMat.emission.contents = image
        faceMat.emission.intensity = 1.55
        faceMat.ambient.contents = image
        faceMat.isDoubleSided = true
        faceMat.writesToDepthBuffer = true
        faceMat.readsFromDepthBuffer = true
        faceMat.locksAmbientWithDiffuse = true

        let plane = SCNPlane(width: CGFloat(planeW), height: CGFloat(planeH))
        plane.cornerRadius = CGFloat(planeH) * 0.08
        plane.materials = [faceMat]
        let faceNode = SCNNode(geometry: plane)
        faceNode.name = darkPlate ? "krcPolicePlateFace" : "krcPlateFace"
        // SCNPlane faces local +Z — sit it on the outward face of the frame, not inside it.
        faceNode.position.z = Float(depth) * 0.5 + 0.002
        faceNode.renderingOrder = 121
        mount.addChildNode(faceNode)

        if darkPlate {
            // Flank LEDs beside the plate — flash with the pursuit cycle.
            let red = UIColor(red: 1, green: 0.05, blue: 0.12, alpha: 1)
            let blue = UIColor(red: 0.08, green: 0.45, blue: 1, alpha: 1)
            let ledW = planeW * 0.08
            let ledH = planeH * 0.72
            for (sx, color, side): (Float, UIColor, String) in [
                (-1, red, "PlateRed"),
                (1, blue, "PlateBlue"),
            ] {
                let ledGeo = SCNBox(
                    width: CGFloat(ledW),
                    height: CGFloat(ledH),
                    length: 0.012,
                    chamferRadius: 0.004
                )
                let ledMat = SCNMaterial()
                ledMat.name = "krcPoliceLensMat\(side)"
                ledMat.lightingModel = .constant
                ledMat.diffuse.contents = color
                ledMat.emission.contents = color
                ledGeo.materials = [ledMat]
                let led = SCNNode(geometry: ledGeo)
                led.name = "krcPoliceLens\(side)"
                led.position = SCNVector3(
                    sx * (planeW * 0.5 + ledW * 0.65),
                    0,
                    yaw > 1.5 ? -0.01 : 0.01
                )
                mount.addChildNode(led)

                let light = SCNLight()
                light.type = .omni
                light.color = color
                light.intensity = 0
                light.attenuationEndDistance = 4.5
                let lightNode = SCNNode()
                lightNode.name = "krcPoliceFlash\(side)"
                lightNode.light = light
                lightNode.position = SCNVector3(led.position.x, led.position.y, led.position.z)
                mount.addChildNode(lightNode)
            }
        }

        mount.renderingOrder = 120
        parent.addChildNode(mount)
    }

    private static func renderLicensePlate(text: String, canvasW: Int, canvasH: Int, darkPlate: Bool) -> UIImage {
        let size = CGSize(width: canvasW, height: canvasH)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Mirror X so chase-cam (yaw π) reads "KRC" left-to-right.
            ctx.cgContext.translateBy(x: size.width, y: 0)
            ctx.cgContext.scaleBy(x: -1, y: 1)
            let outer = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
            let framePath = UIBezierPath(roundedRect: outer, cornerRadius: 28)
            (darkPlate
                ? UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1)
                : UIColor(red: 0.18, green: 0.18, blue: 0.2, alpha: 1)
            ).setFill()
            framePath.fill()

            let inner = outer.insetBy(dx: 18, dy: 18)
            let platePath = UIBezierPath(roundedRect: inner, cornerRadius: 18)
            // High-contrast face — yellow reads at chase-cam distance.
            if darkPlate {
                UIColor(red: 1, green: 0.92, blue: 0.18, alpha: 1).setFill()
            } else {
                UIColor(red: 1, green: 0.94, blue: 0.22, alpha: 1).setFill()
            }
            platePath.fill()

            drawPlateMainText(
                text: text,
                in: inner.insetBy(dx: 20, dy: 16),
                darkPlate: false
            )
        }
    }

    private static func drawPlateMainText(text: String, in rect: CGRect, darkPlate: Bool) {
        let line = text.replacingOccurrences(of: "  ", with: " ")
        let para = NSMutableParagraphStyle()
        para.alignment = .center

        var fontSize = min(rect.height * 0.88, 360)
        var font = UIFont(name: "Arial-Black", size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize, weight: .black)
        while fontSize > 40 {
            font = UIFont(name: "Arial-Black", size: fontSize)
                ?? UIFont.systemFont(ofSize: fontSize, weight: .black)
            let measured = (line as NSString).size(withAttributes: [.font: font])
            if measured.width <= rect.width && measured.height <= rect.height { break }
            fontSize -= 4
        }

        let fill = UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: fill,
            .kern: 2,
            .paragraphStyle: para,
            .strokeColor: UIColor.black,
            .strokeWidth: -4,
        ]
        let str = NSAttributedString(string: line, attributes: attrs)
        let size = str.size()
        let textRect = CGRect(
            x: rect.minX,
            y: rect.midY - size.height / 2,
            width: rect.width,
            height: size.height
        )
        str.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        _ = darkPlate
    }
}
