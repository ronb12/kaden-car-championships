import SceneKit
import UIKit

/// License plates, police kit, and rear badges — parented to the car body so they move with the mesh.
enum CarDecals {

    static func apply(to carNode: SCNNode, container: SCNNode, carId: String, isPlayer: Bool, scale: Float) {
        carNode.childNode(withName: "krcLicensePlate", recursively: false)?.removeFromParentNode()
        carNode.childNode(withName: "krcPoliceKit", recursively: false)?.removeFromParentNode()
        carNode.childNode(withName: "krcPoliceMarkings", recursively: false)?.removeFromParentNode()

        if carId == "police" {
            applyPoliceKit(to: carNode, scale: scale)
        }

        let layout = rearPlateLayout(carNode: carNode, scale: scale)
        let label = GameCatalog.plateLabel(carId: carId, isPlayer: isPlayer)
        licensePlate(
            to: carNode,
            text: label,
            position: SCNVector3(0, layout.y, layout.z),
            yaw: layout.yaw,
            planeW: layout.width * (carId == "police" ? 0.85 : 1),
            planeH: layout.height,
            darkPlate: carId == "police"
        )
    }

    /// Rear bumper placement in the car mesh node's local space.
    private static func rearPlateLayout(carNode: SCNNode, scale: Float) -> (y: Float, z: Float, yaw: Float, width: Float, height: Float) {
        let (minB, maxB) = carNode.boundingBox
        let u = carNode.scale.x
        let height = maxB.y - minB.y
        let widthX = maxB.x - minB.x

        let rearIsMinZ = minB.z < maxB.z
        let rearEdge = rearIsMinZ ? minB.z : maxB.z
        let lengthZ = maxB.z - minB.z
        // Sit on the bumper — tiny inset avoids z-fighting without floating off the body.
        let flushInset = lengthZ * 0.006
        let z = rearIsMinZ ? (rearEdge + flushInset) : (rearEdge - flushInset)
        let yaw: Float = rearIsMinZ ? .pi : 0

        let y = minB.y + height * 0.38
        // Sized for the rear bumper plate recess (not full body width).
        let plateW = max(widthX * u * 0.22, 0.52 * scale)
        let plateH = plateW * 0.28
        return (y, z, yaw, plateW, plateH)
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
        planeW: Float,
        planeH: Float,
        darkPlate: Bool = false
    ) {
        let image = renderLicensePlate(text: text, canvasW: 1024, canvasH: 360, darkPlate: darkPlate)

        let mount = SCNNode()
        mount.name = "krcLicensePlate"
        mount.position = position
        mount.eulerAngles.y = yaw

        let framePad: CGFloat = 0.018
        let depth: CGFloat = 0.014
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
        faceMat.lightingModel = darkPlate ? .constant : .physicallyBased
        faceMat.diffuse.contents = image
        if darkPlate {
            faceMat.emission.contents = UIColor(white: 0.08, alpha: 1)
        } else {
            faceMat.metalness.contents = 0.28
            faceMat.roughness.contents = 0.18
            faceMat.specular.contents = UIColor(white: 0.85, alpha: 1)
        }
        faceMat.isDoubleSided = true
        faceMat.writesToDepthBuffer = true
        faceMat.readsFromDepthBuffer = true

        let plane = SCNPlane(width: CGFloat(planeW), height: CGFloat(planeH))
        plane.cornerRadius = CGFloat(planeH) * 0.11
        plane.materials = [faceMat]
        let faceNode = SCNNode(geometry: plane)
        faceNode.name = darkPlate ? "krcPolicePlateFace" : "krcPlateFace"
        let forward: Float = 0.0008
        faceNode.position.z = yaw > 1.5 ? -forward : forward
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
            let cg = ctx.cgContext
            let outer = CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6)
            let framePath = UIBezierPath(roundedRect: outer, cornerRadius: 22)

            // Metal frame gradient
            cg.saveGState()
            framePath.addClip()
            let frameColors = darkPlate
                ? [UIColor(red: 0.32, green: 0.34, blue: 0.38, alpha: 1).cgColor,
                   UIColor(red: 0.14, green: 0.15, blue: 0.18, alpha: 1).cgColor]
                : [UIColor(red: 0.88, green: 0.89, blue: 0.91, alpha: 1).cgColor,
                   UIColor(red: 0.58, green: 0.60, blue: 0.64, alpha: 1).cgColor]
            if let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: frameColors as CFArray,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(grad, start: CGPoint(x: outer.minX, y: outer.minY),
                                      end: CGPoint(x: outer.maxX, y: outer.maxY), options: [])
            }
            cg.restoreGState()

            let inner = outer.insetBy(dx: 14, dy: 14)
            let platePath = UIBezierPath(roundedRect: inner, cornerRadius: 16)

            // Face fill + subtle reflective sheen
            cg.saveGState()
            platePath.addClip()
            if darkPlate {
                UIColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1).setFill()
            } else {
                let faceColors = [
                    UIColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1).cgColor,
                    UIColor(red: 0.90, green: 0.91, blue: 0.93, alpha: 1).cgColor,
                    UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1).cgColor,
                ]
                if let grad = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: faceColors as CFArray,
                    locations: [0, 0.55, 1]
                ) {
                    cg.drawLinearGradient(
                        grad,
                        start: CGPoint(x: inner.midX, y: inner.minY),
                        end: CGPoint(x: inner.midX, y: inner.maxY),
                        options: []
                    )
                }
            }
            platePath.fill()
            // Reflective streak
            UIColor(white: 1, alpha: darkPlate ? 0.06 : 0.22).setFill()
            UIBezierPath(
                roundedRect: CGRect(
                    x: inner.minX + inner.width * 0.08,
                    y: inner.minY + inner.height * 0.12,
                    width: inner.width * 0.84,
                    height: inner.height * 0.18
                ),
                cornerRadius: 8
            ).fill()
            cg.restoreGState()

            platePath.lineWidth = 2
            UIColor(white: darkPlate ? 0.35 : 0.72, alpha: 0.9).setStroke()
            platePath.stroke()

            drawPlateBolts(in: inner, dark: darkPlate)

            // Header strip (state-style)
            let headerH = inner.height * 0.22
            let headerRect = CGRect(x: inner.minX + 10, y: inner.minY + 8, width: inner.width - 20, height: headerH)
            let headerPath = UIBezierPath(roundedRect: headerRect, cornerRadius: 6)
            if darkPlate {
                UIColor(red: 0.12, green: 0.14, blue: 0.22, alpha: 1).setFill()
            } else {
                UIColor(red: 0.08, green: 0.22, blue: 0.52, alpha: 1).setFill()
            }
            headerPath.fill()
            if darkPlate {
                let accent = UIBezierPath(rect: CGRect(x: headerRect.minX, y: headerRect.maxY - 3,
                                                       width: headerRect.width, height: 3))
                UIColor(red: 0.85, green: 0.12, blue: 0.18, alpha: 1).setFill()
                accent.fill()
                UIBezierPath(rect: CGRect(x: headerRect.minX, y: headerRect.maxY - 6,
                                          width: headerRect.width * 0.48, height: 3)).fill()
                UIColor(red: 0.12, green: 0.35, blue: 0.92, alpha: 1).setFill()
                UIBezierPath(rect: CGRect(x: headerRect.minX + headerRect.width * 0.52,
                                          y: headerRect.maxY - 6, width: headerRect.width * 0.48, height: 3)).fill()
            }

            let headerFont = UIFont.systemFont(ofSize: 22, weight: .bold)
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor(white: 0.96, alpha: 1),
                .kern: 3.2,
            ]
            let headerText = darkPlate ? "EMERGENCY" : "KRC"
            let headerSize = (headerText as NSString).size(withAttributes: headerAttrs)
            (headerText as NSString).draw(
                at: CGPoint(x: headerRect.midX - headerSize.width / 2,
                            y: headerRect.midY - headerSize.height / 2),
                withAttributes: headerAttrs
            )

            drawPlateMainText(
                text: text.uppercased(),
                in: CGRect(
                    x: inner.minX + 12,
                    y: headerRect.maxY + 6,
                    width: inner.width - 24,
                    height: inner.maxY - headerRect.maxY - 14
                ),
                darkPlate: darkPlate
            )
        }
    }

    private static func drawPlateBolts(in rect: CGRect, dark: Bool) {
        let inset: CGFloat = 18
        let r: CGFloat = 5
        let points = [
            CGPoint(x: rect.minX + inset, y: rect.minY + inset),
            CGPoint(x: rect.maxX - inset, y: rect.minY + inset),
            CGPoint(x: rect.minX + inset, y: rect.maxY - inset),
            CGPoint(x: rect.maxX - inset, y: rect.maxY - inset),
        ]
        for p in points {
            let bolt = UIBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            UIColor(white: dark ? 0.28 : 0.55, alpha: 1).setFill()
            bolt.fill()
            UIColor(white: dark ? 0.12 : 0.32, alpha: 1).setStroke()
            bolt.lineWidth = 1.2
            bolt.stroke()
            UIColor(white: dark ? 0.42 : 0.78, alpha: 0.55).setFill()
            UIBezierPath(ovalIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)).fill()
        }
    }

    private static func drawPlateMainText(text: String, in rect: CGRect, darkPlate: Bool) {
        let lines: [String]
        if text.count > 14, text.contains(" ") {
            let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
            lines = parts.count == 2 ? parts : [text]
        } else if text.count > 16 {
            let mid = text.index(text.startIndex, offsetBy: text.count / 2)
            lines = [String(text[..<mid]), String(text[mid...])]
        } else {
            lines = [text]
        }

        let fontSize: CGFloat = lines.count > 1 ? 38 : (text.count > 12 ? 40 : 48)
        let font = UIFont(name: "Arial-BoldMT", size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize, weight: .black)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineSpacing = 2

        let fillColor = darkPlate
            ? UIColor(red: 0.94, green: 0.95, blue: 0.98, alpha: 1)
            : UIColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1)
        let shadowColor = darkPlate
            ? UIColor.black.withAlphaComponent(0.55)
            : UIColor.white.withAlphaComponent(0.85)
        let strokeColor = darkPlate
            ? UIColor.black.withAlphaComponent(0.65)
            : UIColor(white: 0.02, alpha: 0.9)

        let lineHeight = font.lineHeight + para.lineSpacing
        let totalH = lineHeight * CGFloat(lines.count) - para.lineSpacing
        var y = rect.midY - totalH / 2

        for line in lines {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: fillColor,
                .strokeColor: strokeColor,
                .strokeWidth: -2.8,
                .paragraphStyle: para,
            ]
            let str = NSAttributedString(string: line, attributes: attrs)
            let size = str.size()
            let textRect = CGRect(x: rect.minX, y: y, width: rect.width, height: size.height)

            let shadowAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: shadowColor,
                .paragraphStyle: para,
            ]
            let shadowRect = textRect.offsetBy(dx: 0, dy: darkPlate ? 2.5 : -2.5)
            NSAttributedString(string: line, attributes: shadowAttrs).draw(
                with: shadowRect, options: .usesLineFragmentOrigin, context: nil
            )
            str.draw(with: textRect, options: .usesLineFragmentOrigin, context: nil)
            y += lineHeight
        }
    }
}
