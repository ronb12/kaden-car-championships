import SceneKit
import UIKit

/// Garage wraps = full body vinyl skins on paint materials.
/// Stock car stripes (wrap = Clean) stay as light hood accents only.
enum CarLivery {

    struct Spec {
        let stripeColor: UIColor
        let xOffsets: [Float]
        let stripeWidth: Float
        var hoodCoverage: Float = 0.42
        var deckCoverage: Float = 0.22
        var includeSideAccents: Bool = false
    }

    private static var textureCache: [String: UIImage] = [:]

    static func applyStripes(
        to container: SCNNode,
        carId: String,
        carNode: SCNNode,
        scale: Float
    ) {
        clearExisting(from: container)
        clearExisting(from: carNode)

        let wrap = GarageCustomization.style(for: carId).wrap
        if wrap != .none {
            applyBodyWrap(wrap, onto: container)
            applyBodyWrap(wrap, onto: carNode)
        } else if let spec = livery(for: carId) {
            // Stock factory stripes only — not a garage wrap.
            applyClassicStripes(spec, onto: carNode)
        }
        _ = scale
    }

    // MARK: - Full-body vinyl wrap

    private static func applyBodyWrap(_ wrap: GarageWrapStyle, onto root: SCNNode) {
        let skin = wrapTexture(wrap)
        let tile = wrapTileScale(wrap)
        let emitBoost = wrapEmission(wrap)

        root.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            let nodeName = (node.name ?? "").lowercased()
            if shouldSkipWrapNode(nodeName) { return }

            var mats = geometry.materials
            var changed = false
            for i in 0..<mats.count {
                let matName = (mats[i].name ?? "").lowercased()
                if shouldSkipWrapMaterial(matName) { continue }
                // Body paint from forceVisibleRaceShell / exterior pass.
                let isBody = matName == "krcracevisible"
                    || matName.contains("body")
                    || matName.contains("paint")
                    || matName.contains("carpaint")
                    || matName.hasPrefix("krcbody")
                    || (mats.count == 1 && !isNonPaintMaterial(matName, nodeName: nodeName))
                guard isBody else { continue }

                let mat = mats[i]
                mat.name = "krcRaceVisible"
                mat.lightingModel = .constant
                mat.diffuse.contents = skin
                mat.diffuse.wrapS = .repeat
                mat.diffuse.wrapT = .repeat
                mat.diffuse.contentsTransform = SCNMatrix4MakeScale(tile, tile, 1)
                mat.emission.contents = skin
                mat.emission.intensity = CGFloat(emitBoost)
                mat.ambient.contents = skin
                mat.multiply.contents = UIColor.white
                mat.transparent.contents = nil
                mat.transparency = 1
                mat.isDoubleSided = true
                mat.writesToDepthBuffer = true
                mat.readsFromDepthBuffer = true
                mat.locksAmbientWithDiffuse = true
                mats[i] = mat
                changed = true
            }
            if changed {
                geometry.materials = mats
                geometry.firstMaterial = mats.first
            }
        }
    }

    private static func shouldSkipWrapNode(_ name: String) -> Bool {
        if name.hasPrefix("krclivery") || name.hasPrefix("krcstripe") { return true }
        if name.hasPrefix("krcrim") || name.contains("wheel") || name.contains("tire")
            || name.contains("rubber") || name.contains("glass") || name.contains("window")
            || name.contains("windshield") || name.contains("headlight") || name.contains("taillight")
            || name.contains("tailamp") || name.contains("brakelamp") || name.contains("driver")
            || name.contains("plate") || name.contains("interior") || name.contains("seat") {
            return true
        }
        return false
    }

    private static func shouldSkipWrapMaterial(_ name: String) -> Bool {
        if name.contains("tire") || name.contains("rubber") || name.contains("rim")
            || name.contains("wheel") || name.contains("glass") || name.contains("window")
            || name.contains("windshield") || name.contains("head") || name.contains("tail")
            || name.contains("brake") || name.contains("chrome") || name.contains("interior")
            || name.contains("krcblackglass") || name.contains("krcwindshield")
            || name.contains("krcracehead") || name.contains("krcracetail")
            || name.contains("krcracetire") || name.contains("krcracerim") {
            return true
        }
        return false
    }

    private static func isNonPaintMaterial(_ matName: String, nodeName: String) -> Bool {
        shouldSkipWrapMaterial(matName) || shouldSkipWrapNode(nodeName)
    }

    private static func wrapTileScale(_ wrap: GarageWrapStyle) -> Float {
        switch wrap {
        case .none: return 1
        case .racing: return 1.2
        case .stealth: return 2.4
        case .neon: return 1.6
        case .carbon: return 4.5
        case .flame: return 1.4
        case .circuit: return 3.2
        case .pink: return 1.3
        case .camouflage: return 2.8
        }
    }

    private static func wrapEmission(_ wrap: GarageWrapStyle) -> Float {
        switch wrap {
        case .none: return 0.2
        case .racing: return 0.55
        case .stealth: return 0.28
        case .neon: return 0.85
        case .carbon: return 0.22
        case .flame: return 0.7
        case .circuit: return 0.5
        case .pink: return 0.62
        case .camouflage: return 0.3
        }
    }

    // MARK: - Procedural vinyl textures

    private static func wrapTexture(_ wrap: GarageWrapStyle) -> UIImage {
        let key = "wrap-\(wrap.rawValue)-v2"
        if let cached = textureCache[key] { return cached }
        let img: UIImage
        switch wrap {
        case .none:
            img = solidImage(UIColor(white: 0.5, alpha: 1))
        case .racing:
            img = racingWrapImage()
        case .stealth:
            img = stealthWrapImage()
        case .neon:
            img = neonWrapImage()
        case .carbon:
            img = carbonWrapImage()
        case .flame:
            img = flameWrapImage()
        case .circuit:
            img = circuitWrapImage()
        case .pink:
            img = pinkWrapImage()
        case .camouflage:
            img = camouflageWrapImage()
        }
        textureCache[key] = img
        return img
    }

    private static func solidImage(_ color: UIColor) -> UIImage {
        let size = CGSize(width: 8, height: 8)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// Black vinyl with bold dual yellow racing stripes down the length.
    private static func racingWrapImage() -> UIImage {
        let w = 512, h = 512
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
            UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let yellow = UIColor(red: 1, green: 0.84, blue: 0.08, alpha: 1)
            yellow.setFill()
            let stripeW = CGFloat(w) * 0.09
            let gap = CGFloat(w) * 0.045
            let cx = CGFloat(w) * 0.5
            ctx.fill(CGRect(x: cx - gap * 0.5 - stripeW, y: 0, width: stripeW, height: CGFloat(h)))
            ctx.fill(CGRect(x: cx + gap * 0.5, y: 0, width: stripeW, height: CGFloat(h)))
            // Nose bar
            ctx.fill(CGRect(x: CGFloat(w) * 0.28, y: CGFloat(h) * 0.04, width: CGFloat(w) * 0.44, height: CGFloat(h) * 0.06))
        }
    }

    /// Matte charcoal camo wrap.
    private static func stealthWrapImage() -> UIImage {
        let w = 512, h = 512
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
            let cg = ctx.cgContext
            UIColor(white: 0.14, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let tones: [UIColor] = [
                UIColor(white: 0.22, alpha: 1),
                UIColor(white: 0.10, alpha: 1),
                UIColor(white: 0.32, alpha: 1),
                UIColor(white: 0.18, alpha: 1),
            ]
            var seed: UInt64 = 0x57EA17
            for i in 0..<48 {
                seed = seed &* 1_103_515_245 &+ 12_345
                let x = CGFloat(seed % UInt64(w))
                seed = seed &* 1_103_515_245 &+ 12_345
                let y = CGFloat(seed % UInt64(h))
                seed = seed &* 1_103_515_245 &+ 12_345
                let rw = CGFloat(40 + seed % 90)
                seed = seed &* 1_103_515_245 &+ 12_345
                let rh = CGFloat(28 + seed % 70)
                tones[i % tones.count].setFill()
                cg.fillEllipse(in: CGRect(x: x - rw * 0.5, y: y - rh * 0.5, width: rw, height: rh))
            }
            // Soft highlight stripe
            UIColor(white: 0.4, alpha: 0.35).setFill()
            ctx.fill(CGRect(x: CGFloat(w) * 0.46, y: 0, width: CGFloat(w) * 0.08, height: CGFloat(h)))
        }
    }

    /// Dark wrap with cyan / magenta graphic bands.
    private static func neonWrapImage() -> UIImage {
        let w = 512, h = 512
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
            UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let cyan = UIColor(red: 0.1, green: 1, blue: 0.88, alpha: 1)
            let magenta = UIColor(red: 1, green: 0.15, blue: 0.78, alpha: 1)
            cyan.setFill()
            ctx.fill(CGRect(x: CGFloat(w) * 0.18, y: 0, width: CGFloat(w) * 0.07, height: CGFloat(h)))
            ctx.fill(CGRect(x: 0, y: CGFloat(h) * 0.62, width: CGFloat(w), height: CGFloat(h) * 0.04))
            magenta.setFill()
            ctx.fill(CGRect(x: CGFloat(w) * 0.75, y: 0, width: CGFloat(w) * 0.07, height: CGFloat(h)))
            ctx.fill(CGRect(x: 0, y: CGFloat(h) * 0.34, width: CGFloat(w), height: CGFloat(h) * 0.03))
            // Accent chevrons
            cyan.setStroke()
            let path = UIBezierPath()
            path.lineWidth = 6
            for i in 0..<5 {
                let y = CGFloat(h) * (0.15 + CGFloat(i) * 0.15)
                path.move(to: CGPoint(x: CGFloat(w) * 0.35, y: y))
                path.addLine(to: CGPoint(x: CGFloat(w) * 0.5, y: y - 18))
                path.addLine(to: CGPoint(x: CGFloat(w) * 0.65, y: y))
            }
            path.stroke()
        }
    }

    /// Tight carbon-fiber weave.
    private static func carbonWrapImage() -> UIImage {
        let w = 256, h = 256
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
            UIColor(white: 0.08, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let cell = 16
            for row in 0..<(h / cell) {
                for col in 0..<(w / cell) {
                    let dark = ((row + col) % 2 == 0)
                    let c = dark ? UIColor(white: 0.11, alpha: 1) : UIColor(white: 0.2, alpha: 1)
                    c.setFill()
                    ctx.fill(CGRect(x: col * cell, y: row * cell, width: cell, height: cell))
                    // Weave highlight
                    UIColor(white: dark ? 0.16 : 0.28, alpha: 0.55).setFill()
                    ctx.fill(CGRect(x: col * cell + 2, y: row * cell + 1, width: cell - 4, height: 2))
                    ctx.fill(CGRect(x: col * cell + 1, y: row * cell + 3, width: 2, height: cell - 5))
                }
            }
            // Silver edge fleck
            UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 0.25).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: h))
        }
    }

    /// Black wrap with flame tongues rising.
    private static func flameWrapImage() -> UIImage {
        let w = 512, h = 512
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.05, green: 0.04, blue: 0.04, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let hot = UIColor(red: 1, green: 0.25, blue: 0.02, alpha: 1)
            let mid = UIColor(red: 1, green: 0.55, blue: 0.05, alpha: 1)
            let tip = UIColor(red: 1, green: 0.88, blue: 0.2, alpha: 1)
            for i in 0..<9 {
                let cx = CGFloat(w) * (0.08 + CGFloat(i) * 0.105)
                let baseW = CGFloat(28 + (i % 3) * 10)
                let path = UIBezierPath()
                path.move(to: CGPoint(x: cx - baseW, y: CGFloat(h)))
                path.addCurve(
                    to: CGPoint(x: cx, y: CGFloat(h) * 0.15),
                    controlPoint1: CGPoint(x: cx - baseW * 0.4, y: CGFloat(h) * 0.55),
                    controlPoint2: CGPoint(x: cx - 8, y: CGFloat(h) * 0.3)
                )
                path.addCurve(
                    to: CGPoint(x: cx + baseW, y: CGFloat(h)),
                    controlPoint1: CGPoint(x: cx + 8, y: CGFloat(h) * 0.3),
                    controlPoint2: CGPoint(x: cx + baseW * 0.4, y: CGFloat(h) * 0.55)
                )
                path.close()
                let colors = i % 2 == 0 ? [hot, mid] : [mid, tip]
                cg.saveGState()
                path.addClip()
                let space = CGColorSpaceCreateDeviceRGB()
                let grad = CGGradient(
                    colorsSpace: space,
                    colors: [colors[0].cgColor, colors[1].cgColor] as CFArray,
                    locations: [0, 1]
                )!
                cg.drawLinearGradient(
                    grad,
                    start: CGPoint(x: cx, y: CGFloat(h)),
                    end: CGPoint(x: cx, y: CGFloat(h) * 0.1),
                    options: []
                )
                cg.restoreGState()
            }
        }
    }

    /// Full checkerboard race wrap.
    private static func circuitWrapImage() -> UIImage {
        let w = 256, h = 256
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
            let cells = 8
            let cw = CGFloat(w) / CGFloat(cells)
            let ch = CGFloat(h) / CGFloat(cells)
            for row in 0..<cells {
                for col in 0..<cells {
                    let light = (row + col) % 2 == 0
                    (light ? UIColor(white: 0.94, alpha: 1) : UIColor(white: 0.06, alpha: 1)).setFill()
                    ctx.fill(CGRect(x: CGFloat(col) * cw, y: CGFloat(row) * ch, width: cw + 0.5, height: ch + 0.5))
                }
            }
        }
    }

    /// Hot pink vinyl with soft pearl stripes.
    private static func pinkWrapImage() -> UIImage {
        let w = 512, h = 512
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
            let cg = ctx.cgContext
            let base = UIColor(red: 0.92, green: 0.12, blue: 0.58, alpha: 1)
            let deep = UIColor(red: 0.72, green: 0.04, blue: 0.42, alpha: 1)
            let pearl = UIColor(red: 1, green: 0.78, blue: 0.9, alpha: 1)
            let space = CGColorSpaceCreateDeviceRGB()
            let grad = CGGradient(
                colorsSpace: space,
                colors: [deep.cgColor, base.cgColor, UIColor(red: 1, green: 0.42, blue: 0.72, alpha: 1).cgColor] as CFArray,
                locations: [0, 0.45, 1]
            )!
            cg.drawLinearGradient(
                grad,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: CGFloat(w), y: CGFloat(h)),
                options: []
            )
            pearl.setFill()
            let stripeW = CGFloat(w) * 0.055
            ctx.fill(CGRect(x: CGFloat(w) * 0.28, y: 0, width: stripeW, height: CGFloat(h)))
            ctx.fill(CGRect(x: CGFloat(w) * 0.66, y: 0, width: stripeW * 0.7, height: CGFloat(h)))
            UIColor(red: 1, green: 0.55, blue: 0.82, alpha: 0.45).setFill()
            ctx.fill(CGRect(x: 0, y: CGFloat(h) * 0.42, width: CGFloat(w), height: CGFloat(h) * 0.08))
        }
    }

    /// Woodland / desert camo blotches.
    private static func camouflageWrapImage() -> UIImage {
        let w = 512, h = 512
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.28, green: 0.34, blue: 0.18, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let tones: [UIColor] = [
                UIColor(red: 0.18, green: 0.22, blue: 0.12, alpha: 1),
                UIColor(red: 0.42, green: 0.38, blue: 0.22, alpha: 1),
                UIColor(red: 0.55, green: 0.48, blue: 0.28, alpha: 1),
                UIColor(red: 0.12, green: 0.14, blue: 0.1, alpha: 1),
                UIColor(red: 0.36, green: 0.46, blue: 0.24, alpha: 1),
            ]
            var seed: UInt64 = 0xCA70F1A6
            for i in 0..<64 {
                seed = seed &* 1_103_515_245 &+ 12_345
                let x = CGFloat(seed % UInt64(w))
                seed = seed &* 1_103_515_245 &+ 12_345
                let y = CGFloat(seed % UInt64(h))
                seed = seed &* 1_103_515_245 &+ 12_345
                let rw = CGFloat(36 + seed % 110)
                seed = seed &* 1_103_515_245 &+ 12_345
                let rh = CGFloat(28 + seed % 95)
                tones[i % tones.count].setFill()
                // Irregular blob via overlapping ellipses
                cg.fillEllipse(in: CGRect(x: x - rw * 0.5, y: y - rh * 0.5, width: rw, height: rh))
                cg.fillEllipse(in: CGRect(x: x - rw * 0.2, y: y - rh * 0.35, width: rw * 0.7, height: rh * 0.65))
            }
        }
    }

    // MARK: - Stock factory stripes (Clean wrap only)

    private static func applyClassicStripes(_ spec: Spec, onto body: SCNNode) {
        let mat = stripeMaterial(spec.stripeColor)
        let front: Float = 0.36
        let rearHood = front - spec.hoodCoverage * 0.7
        let deckFront: Float = -0.05
        let deckRear = deckFront - spec.deckCoverage * 0.7
        for xOff in spec.xOffsets {
            paintTopBand(onto: body, material: mat, xFrac: xOff, widthFrac: spec.stripeWidth * 0.45, zFront: front, zRear: rearHood, samples: 9)
            if spec.deckCoverage > 0.05 {
                paintTopBand(onto: body, material: mat, xFrac: xOff, widthFrac: spec.stripeWidth * 0.4, zFront: deckFront, zRear: deckRear, samples: 5)
            }
        }
        if spec.includeSideAccents {
            paintSideBand(onto: body, material: mat, yFrac: 0.32, heightFrac: 0.04, zFront: 0.24, zRear: -0.15, samples: 6)
        }
    }

    private static func paintTopBand(
        onto body: SCNNode,
        material: SCNMaterial,
        xFrac: Float,
        widthFrac: Float,
        zFront: Float,
        zRear: Float,
        samples: Int
    ) {
        let (minB, maxB) = body.boundingBox
        let width = max(0.1, maxB.x - minB.x)
        let length = max(0.1, maxB.z - minB.z)
        let height = max(0.1, maxB.y - minB.y)
        let cx = (minB.x + maxB.x) * 0.5
        let cz = (minB.z + maxB.z) * 0.5
        let frontIsMaxZ = VehicleAxes.frame(in: body).map { $0.frontZ >= $0.rearZ } ?? true
        let x = cx + xFrac * width
        let tileW = max(0.04, width * widthFrac)
        let count = max(3, samples)

        for i in 0..<count {
            let t = Float(i) / Float(count - 1)
            let zFrac = zFront + (zRear - zFront) * t
            let z = frontIsMaxZ ? cz + length * zFrac : cz - length * zFrac
            let from = SCNVector3(x, maxB.y + height * 0.8, z)
            let to = SCNVector3(x, minB.y + height * 0.2, z)
            guard let hit = firstBodyHit(on: body, from: from, to: to) else { continue }
            let stepLen = abs(zFront - zRear) * length / Float(count) * 1.05
            placeFlushDecal(
                onto: body,
                hit: hit,
                width: tileW,
                height: max(0.028, stepLen),
                material: material,
                name: "krcLiveryHood",
                rayFromLocal: from
            )
        }
    }

    private static func paintSideBand(
        onto body: SCNNode,
        material: SCNMaterial,
        yFrac: Float,
        heightFrac: Float,
        zFront: Float,
        zRear: Float,
        samples: Int
    ) {
        let (minB, maxB) = body.boundingBox
        let width = max(0.1, maxB.x - minB.x)
        let length = max(0.1, maxB.z - minB.z)
        let height = max(0.1, maxB.y - minB.y)
        let cx = (minB.x + maxB.x) * 0.5
        let cz = (minB.z + maxB.z) * 0.5
        let frontIsMaxZ = VehicleAxes.frame(in: body).map { $0.frontZ >= $0.rearZ } ?? true
        let y = minB.y + height * yFrac
        let tileH = max(0.03, height * heightFrac)
        let count = max(3, samples)

        for sign: Float in [-1, 1] {
            for i in 0..<count {
                let t = Float(i) / Float(count - 1)
                let zFrac = zFront + (zRear - zFront) * t
                let z = frontIsMaxZ ? cz + length * zFrac : cz - length * zFrac
                let from = SCNVector3(cx + sign * width * 0.95, y, z)
                let to = SCNVector3(cx, y, z)
                guard let hit = firstBodyHit(on: body, from: from, to: to) else { continue }
                let stepLen = abs(zFront - zRear) * length / Float(count) * 1.05
                placeFlushDecal(
                    onto: body,
                    hit: hit,
                    width: max(0.028, stepLen),
                    height: tileH,
                    material: material,
                    name: "krcLiveryRocker",
                    rayFromLocal: from
                )
            }
        }
    }

    private static func firstBodyHit(on body: SCNNode, from: SCNVector3, to: SCNVector3) -> SCNHitTestResult? {
        let hits = body.hitTestWithSegment(from: from, to: to, options: nil)
        return hits.first { isValidBodyHit($0) }
    }

    private static func isValidBodyHit(_ hit: SCNHitTestResult) -> Bool {
        var node: SCNNode? = hit.node
        while let n = node {
            let name = (n.name ?? "").lowercased()
            if name.hasPrefix("krclivery") || name.hasPrefix("krcstripe") { return false }
            if name.hasPrefix("krcrim") || name.contains("wheel") || name.contains("tire")
                || name.contains("rubber") || name.contains("glass") || name.contains("window")
                || name.contains("windshield") || name.contains("headlight") || name.contains("tail")
                || name.contains("driver") || name.contains("plate") {
                return false
            }
            node = n.parent
        }
        return true
    }

    private static func placeFlushDecal(
        onto body: SCNNode,
        hit: SCNHitTestResult,
        width: Float,
        height: Float,
        material: SCNMaterial,
        name: String,
        rayFromLocal: SCNVector3
    ) {
        let plane = SCNPlane(
            width: CGFloat(max(0.015, width * 0.92)),
            height: CGFloat(max(0.015, height * 0.92))
        )
        let mat = material.copy() as? SCNMaterial ?? material
        plane.materials = [mat]
        let node = SCNNode(geometry: plane)
        node.name = name
        node.renderingOrder = 6
        node.castsShadow = false

        let p = body.convertPosition(hit.worldCoordinates, from: nil)
        var n = body.convertVector(hit.worldNormal, from: nil)
        let nLen = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
        if nLen > 0.001 {
            n.x /= nLen; n.y /= nLen; n.z /= nLen
        } else {
            n = SCNVector3(0, 1, 0)
        }
        let outward = SCNVector3(rayFromLocal.x - p.x, rayFromLocal.y - p.y, rayFromLocal.z - p.z)
        if n.x * outward.x + n.y * outward.y + n.z * outward.z < 0 {
            n = SCNVector3(-n.x, -n.y, -n.z)
        }
        let eps: Float = 0.0006
        node.position = SCNVector3(p.x + n.x * eps, p.y + n.y * eps, p.z + n.z * eps)
        let target = SCNVector3(node.position.x + n.x, node.position.y + n.y, node.position.z + n.z)
        let up: SCNVector3 = abs(n.y) > 0.85 ? SCNVector3(0, 0, 1) : SCNVector3(0, 1, 0)
        node.look(at: target, up: up, localFront: SCNVector3(0, 0, 1))
        body.addChildNode(node)
    }

    private static func stripeMaterial(_ color: UIColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.name = "krcLivery"
        mat.lightingModel = .constant
        mat.diffuse.contents = color
        mat.emission.contents = color.withAlphaComponent(0.7)
        mat.isDoubleSided = false
        mat.writesToDepthBuffer = true
        mat.readsFromDepthBuffer = true
        return mat
    }

    private static func clearExisting(from root: SCNNode) {
        var remove: [SCNNode] = []
        root.enumerateHierarchy { node, _ in
            guard let name = node.name else { return }
            if name.hasPrefix("krcLivery") || name.hasPrefix("krcStripe") {
                remove.append(node)
            }
        }
        for node in remove where node.parent != nil {
            node.removeFromParentNode()
        }
    }

    private static func livery(for id: String) -> Spec? {
        let white = UIColor.white
        let black = UIColor(white: 0.07, alpha: 1)
        let silver = UIColor(white: 0.78, alpha: 1)
        let red = UIColor(red: 0.90, green: 0.04, blue: 0.04, alpha: 1)
        let gold = UIColor(red: 0.90, green: 0.72, blue: 0.00, alpha: 1)
        let orange = UIColor(red: 1.00, green: 0.38, blue: 0.00, alpha: 1)
        let cyan = UIColor(red: 0.00, green: 0.85, blue: 1.00, alpha: 1)

        func dual(_ c: UIColor) -> Spec { Spec(stripeColor: c, xOffsets: [-0.1, 0.1], stripeWidth: 0.12) }
        func single(_ c: UIColor) -> Spec { Spec(stripeColor: c, xOffsets: [0], stripeWidth: 0.2, deckCoverage: 0.16) }
        func trio(_ c: UIColor) -> Spec { Spec(stripeColor: c, xOffsets: [-0.12, 0, 0.12], stripeWidth: 0.06, deckCoverage: 0.12) }
        func wide(_ c: UIColor) -> Spec { Spec(stripeColor: c, xOffsets: [-0.11, 0.11], stripeWidth: 0.15) }

        switch id {
        case "f40", "rx7", "koenigsegg", "mustang", "gt500", "senna": return dual(white)
        case "lambo", "mclaren", "911", "supra", "camaro", "corvette": return dual(black)
        case "audi-r8", "huracan": return dual(black)
        case "gtr", "r34": return dual(white)
        case "bugatti": return single(silver)
        case "amg", "nsx", "civic": return single(red)
        case "m4": return trio(white)
        case "evo": return dual(gold)
        case "viper": return dual(silver)
        case "challenger": return dual(orange)
        case "charger": return single(white)
        case "police": return Spec(stripeColor: white, xOffsets: [-0.12, 0.12], stripeWidth: 0.16)
        case "s2000": return single(UIColor(red: 0.05, green: 0.25, blue: 0.90, alpha: 1))
        case "sti": return wide(gold)
        case "rs7": return dual(silver)
        case "r35-nismo": return wide(red)
        case "jesko": return dual(cyan)
        default: return nil
        }
    }
}
