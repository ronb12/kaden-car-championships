import SceneKit
import UIKit

/// PBR material factory + mesh classification — tuned for reliable visibility in race fog/HDR.
enum VehicleMaterialLibrary {

    /// USDZ body slots often ship with alpha masks — force an opaque PBR shell after we replace materials.
    static func configureFullyOpaque(_ mat: SCNMaterial) {
        // SceneKit: 0 = invisible, 1 = opaque. Never use 0 for solid body paint.
        mat.transparency = 1
        mat.transparencyMode = .default
        // `.replace` + clearCoat crushed body paint to black fragments on Simulator.
        mat.blendMode = .alpha
        mat.multiply.contents = UIColor.white
        mat.transparent.contents = nil
        mat.fillMode = .fill
        mat.writesToDepthBuffer = true
        mat.readsFromDepthBuffer = true
    }

    /// Builds a material that stays visible under SceneKit fog and custom lighting (no transparency hacks).
    static func makeVisibleSurface(
        color: UIColor,
        metalness: CGFloat = 0.38,
        roughness: CGFloat = 0.34,
        emission: CGFloat = 0.10,
        constantLighting: Bool = false
    ) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = constantLighting ? .constant : .physicallyBased
        mat.diffuse.contents = color
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = true
        mat.readsFromDepthBuffer = true
        mat.fillMode = .fill
        configureFullyOpaque(mat)
        if constantLighting {
            // Constant lighting still benefits from a soft emission lift on Simulator.
            mat.emission.contents = color.withAlphaComponent(max(0.08, emission))
        } else {
            mat.metalness.contents = metalness
            mat.roughness.contents = roughness
            mat.emission.contents = color.withAlphaComponent(emission)
        }
        return mat
    }

    enum SurfaceKind: Equatable {
        case bodyPaint
        case glass
        case chrome
        case carbon
        case rubber
        case tire
        case caliper
        case headlight
        case tailLight
        case interior
        case grille
        case unknown
    }

    struct PaintDescriptor {
        let color: UIColor
        let finish: VehiclePaintFinish
        var flake: Float = 0.35
        var clearCoat: Float = 0.22
    }

    // MARK: - Apply to hierarchy

    static func fixMaterials(on root: SCNNode, paint: PaintDescriptor) {
        root.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            let nodeName = (node.name ?? "").lowercased()
            var primary: SurfaceKind = .bodyPaint
            geometry.materials = geometry.materials.map { base in
                let kind = classify(nodeName: nodeName, materialName: (base.name ?? "").lowercased(), material: base)
                primary = kind
                return material(for: kind, paint: paint, base: base)
            }
            node.castsShadow = primary != .glass && primary != .headlight
            node.renderingOrder = primary == .glass ? 5 : 0
        }
    }

    static func classify(nodeName: String, materialName: String, material: SCNMaterial) -> SurfaceKind {
        let n = nodeName + " " + materialName
        if n.contains("wheel") || n.contains("tire") || n.contains("rubber") { return .tire }
        if n.contains("brake") && !n.contains("light") { return .caliper }
        if n.contains("rim") || n.contains("spoke") || n.contains("alloy") { return .chrome }
        if n.contains("glass") || n.contains("window") || n.contains("windshield") ||
            n.contains("windscreen") || n.contains("glazing") || n.contains("cristal") ||
            n.contains("vidrio") || n.contains("tinted glass") || n.contains("black tinted") {
            return .glass
        }
        if n.contains("headlight") || n.contains("taillight") || n.contains("tail_light") { return .headlight }
        if n.contains("lamp") && (n.contains("front") || n.contains("rear") || n.contains("brake")) { return .headlight }
        if n.contains("tail") || n.contains("brake_light") { return .tailLight }
        if n.contains("chrome") || n.contains("trim") || n.contains("exhaust") { return .chrome }
        if n.contains("carbon") || n.contains("splitter") || n.contains("diffuser") ||
            n.contains("satin_black") || n.contains("aero") { return .carbon }
        if n.contains("grille") || n.contains("grill") { return .grille }
        if n.contains("interior") || n.contains("seat") || n.contains("dash") ||
            n.contains("steering") || n.contains("carpet") { return .interior }
        return .bodyPaint
    }

    static func material(for kind: SurfaceKind, paint: PaintDescriptor, base: SCNMaterial) -> SCNMaterial {
        switch kind {
        case .bodyPaint: return bodyPaint(paint)
        case .glass: return automotiveGlass()
        case .chrome: return chrome()
        case .carbon: return carbonFiber()
        case .rubber, .tire: return tireRubber()
        case .caliper: return brakeCaliper()
        case .headlight: return headlightLens()
        case .tailLight: return tailLight()
        case .interior: return interiorPlastic()
        case .grille: return grilleMesh()
        case .unknown: return bodyPaint(paint)
        }
    }

    // MARK: - Automotive paint (Gran Turismo–style PBR)

    /// GT uses vivid factory colors but not emissive tint — clamp UI picks into a photographic range.
    static func calibratePaintColor(_ color: UIColor) -> UIColor {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return color.withAlphaComponent(1)
        }
        // Keep interceptor / matte blacks dark. Raising brightness turned navy into solid blue.
        if b < 0.24 {
            return UIColor(
                hue: h,
                saturation: min(0.28, s),
                brightness: max(0.07, min(0.16, b)),
                alpha: a
            )
        }
        // Keep near-white pearls from blooming into chalk under race sun.
        if b > 0.88 && s < 0.12 {
            return UIColor(hue: h, saturation: s, brightness: min(0.72, b), alpha: a)
        }
        if s < 0.08 { s = 0.06 }
        else { s = min(0.88, max(0.22, s)) }
        b = min(0.70, max(0.22, b))
        return UIColor(hue: h, saturation: s, brightness: b, alpha: a)
    }

    /// @deprecated Use `calibratePaintColor` — kept for call-site compatibility.
    static func naturalizePaintColor(_ color: UIColor) -> UIColor { calibratePaintColor(color) }

    static func bodyPaint(
        _ paint: PaintDescriptor,
        carId: String? = nil,
        reflectionTier: AutomotivePaintShader.ReflectionTier = .race
    ) -> SCNMaterial {
        let brdf = AutomotiveBRDFLibrary.resolve(paint: paint, carId: carId)
        return AutomotivePaintShader.makeBodyPaintMaterial(brdf: brdf, tier: reflectionTier)
    }

    static func automotiveGlass() -> SCNMaterial {
        // Default cabin glass = privacy black (side/rear). Use `windshieldGlass()` for the front.
        return blackWindowGlass()
    }

    /// Front windshield — readable blue-grey glass (still opaque for stable race rendering).
    static func windshieldGlass() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.name = "krcWindshield"
        mat.lightingModel = .constant
        let tint = UIColor(red: 0.28, green: 0.36, blue: 0.44, alpha: 1)
        mat.diffuse.contents = tint
        mat.emission.contents = UIColor(red: 0.22, green: 0.28, blue: 0.34, alpha: 1)
        mat.ambient.contents = tint
        mat.specular.contents = UIColor(white: 0.85, alpha: 1)
        mat.shininess = 0.85
        mat.transparency = 1
        mat.blendMode = .alpha
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = true
        mat.readsFromDepthBuffer = true
        mat.fillMode = .fill
        mat.locksAmbientWithDiffuse = true
        return mat
    }

    /// Side / rear / quarter glass — solid black privacy tint.
    static func blackWindowGlass() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.name = "krcBlackGlass"
        mat.lightingModel = .constant
        let black = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        mat.diffuse.contents = black
        mat.emission.contents = UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)
        mat.ambient.contents = black
        mat.specular.contents = UIColor(white: 0.25, alpha: 1)
        mat.shininess = 0.55
        mat.transparency = 1
        mat.blendMode = .alpha
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = true
        mat.readsFromDepthBuffer = true
        mat.fillMode = .fill
        mat.locksAmbientWithDiffuse = true
        return mat
    }

    /// True when this glass slot should stay as the front windshield (not privacy black).
    static func isFrontWindshieldName(_ raw: String) -> Bool {
        let n = raw.lowercased()
        if n.contains("rear") || n.contains("back") || n.contains("side") || n.contains("door")
            || n.contains("quarter") || n.contains("lateral") || n.contains("opera")
            || n.contains("rear_window") || n.contains("backlight") {
            return false
        }
        return n.contains("windshield") || n.contains("windscreen") || n.contains("parabrisas")
            || n.contains("front_glass") || n.contains("frontglass") || n.contains("front window")
            || n.contains("frontwindow") || (n.contains("front") && (n.contains("glass") || n.contains("window") || n.contains("cristal")))
    }

    /// Side/rear privacy glass by name.
    static func isPrivacyGlassName(_ raw: String) -> Bool {
        let n = raw.lowercased()
        return n.contains("rear") || n.contains("back") || n.contains("side") || n.contains("door")
            || n.contains("quarter") || n.contains("lateral") || n.contains("opera")
            || n.contains("rear_window") || n.contains("backlight") || n.contains("tinted")
    }

    /// Pick windshield vs black glass using name, then proximity to the real front bumper.
    static func glassMaterial(for node: SCNNode, in body: SCNNode) -> SCNMaterial {
        let name = ((node.name ?? "") + " " + (node.geometry?.materials.first?.name ?? ""))
        if isFrontWindshieldName(name) { return windshieldGlass() }
        if isPrivacyGlassName(name) { return blackWindowGlass() }

        let center = VehicleAxes.meshCenter(in: node, relativeTo: body)
        if let frame = VehicleAxes.frame(in: body) {
            return frame.isNearFront(z: center.z) ? windshieldGlass() : blackWindowGlass()
        }
        let (bMin, bMax) = body.boundingBox
        let spanZ = max(0.001, bMax.z - bMin.z)
        let zNorm = (center.z - bMin.z) / spanZ
        return zNorm > 0.58 ? windshieldGlass() : blackWindowGlass()
    }

    static func chrome() -> SCNMaterial {
        makeVisibleSurface(
            color: UIColor(white: 0.82, alpha: 1),
            metalness: 0.92,
            roughness: 0.14,
            emission: 0.06
        )
    }

    static func wheelRimDark() -> SCNMaterial {
        makeVisibleSurface(
            color: UIColor(white: 0.12, alpha: 1),
            metalness: 0.68,
            roughness: 0.36,
            emission: 0.10
        )
    }

    /// Garage rim picker look for bundled USDZ alloys (geometry stays; finish changes).
    static func wheelRim(for style: GarageRimStyle) -> SCNMaterial {
        switch style {
        case .stock:
            return wheelRimDark()
        case .sport5:
            return makeVisibleSurface(
                color: UIColor(red: 0.62, green: 0.65, blue: 0.70, alpha: 1),
                metalness: 0.9,
                roughness: 0.26,
                emission: 0.12
            )
        case .deepDish:
            return makeVisibleSurface(
                color: UIColor(white: 0.07, alpha: 1),
                metalness: 0.58,
                roughness: 0.4,
                emission: 0.08
            )
        case .hyper:
            return makeVisibleSurface(
                color: UIColor(red: 0.82, green: 0.86, blue: 0.92, alpha: 1),
                metalness: 0.96,
                roughness: 0.14,
                emission: 0.16
            )
        case .chromeLux:
            return makeVisibleSurface(
                color: UIColor(white: 0.9, alpha: 1),
                metalness: 0.98,
                roughness: 0.1,
                emission: 0.18
            )
        case .muscle:
            return makeVisibleSurface(
                color: UIColor(red: 0.86, green: 0.66, blue: 0.18, alpha: 1),
                metalness: 0.92,
                roughness: 0.2,
                emission: 0.2
            )
        case .blackChrome:
            return makeVisibleSurface(
                color: UIColor(white: 0.14, alpha: 1),
                metalness: 0.95,
                roughness: 0.16,
                emission: 0.14
            )
        case .bronze:
            return makeVisibleSurface(
                color: UIColor(red: 0.66, green: 0.44, blue: 0.22, alpha: 1),
                metalness: 0.88,
                roughness: 0.28,
                emission: 0.14
            )
        case .candyRed:
            return makeVisibleSurface(
                color: UIColor(red: 0.9, green: 0.08, blue: 0.14, alpha: 1),
                metalness: 0.72,
                roughness: 0.24,
                emission: 0.22
            )
        }
    }

    static func rimAccent(for style: GarageRimStyle) -> SCNMaterial {
        switch style {
        case .stock, .deepDish, .blackChrome:
            return makeVisibleSurface(
                color: UIColor(white: 0.35, alpha: 1),
                metalness: 0.7,
                roughness: 0.35,
                emission: 0.08
            )
        case .sport5, .hyper, .chromeLux:
            return chrome()
        case .muscle, .bronze:
            return makeVisibleSurface(
                color: UIColor(red: 0.95, green: 0.78, blue: 0.28, alpha: 1),
                metalness: 0.9,
                roughness: 0.2,
                emission: 0.18
            )
        case .candyRed:
            return makeVisibleSurface(
                color: UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1),
                metalness: 0.85,
                roughness: 0.22,
                emission: 0.2
            )
        }
    }

    static func brakeCaliper(for style: GarageRimStyle) -> SCNMaterial {
        switch style {
        case .candyRed, .muscle:
            return makeVisibleSurface(
                color: UIColor(red: 0.95, green: 0.82, blue: 0.1, alpha: 1),
                metalness: 0.4,
                roughness: 0.4,
                emission: 0.12
            )
        case .chromeLux, .hyper, .sport5:
            return makeVisibleSurface(
                color: UIColor(red: 0.9, green: 0.08, blue: 0.06, alpha: 1),
                metalness: 0.4,
                roughness: 0.4,
                emission: 0.1
            )
        case .bronze:
            return makeVisibleSurface(
                color: UIColor(red: 0.2, green: 0.45, blue: 0.9, alpha: 1),
                metalness: 0.35,
                roughness: 0.42,
                emission: 0.1
            )
        default:
            return brakeCaliper()
        }
    }

    static func carbonFiber() -> SCNMaterial {
        makeVisibleSurface(
            color: UIColor(white: 0.10, alpha: 1),
            metalness: 0.32,
            roughness: 0.44,
            emission: 0.10
        )
    }

    static func tireRubber() -> SCNMaterial {
        makeVisibleSurface(
            color: UIColor(white: 0.07, alpha: 1),
            metalness: 0.02,
            roughness: 0.94,
            emission: 0.06
        )
    }

    static func brakeCaliper() -> SCNMaterial {
        makeVisibleSurface(
            color: UIColor(red: 0.85, green: 0.08, blue: 0.05, alpha: 1),
            metalness: 0.38,
            roughness: 0.42,
            emission: 0.22
        )
    }

    static func headlightLens() -> SCNMaterial {
        let mat = makeVisibleSurface(
            color: UIColor(white: 0.95, alpha: 1),
            metalness: 0.18,
            roughness: 0.14,
            emission: 0.22
        )
        return mat
    }

    static func tailLight() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor(red: 0.90, green: 0.06, blue: 0.06, alpha: 1)
        mat.emission.contents = UIColor(red: 0.72, green: 0.04, blue: 0.04, alpha: 1)
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = true
        return mat
    }

    static func interiorPlastic() -> SCNMaterial {
        makeVisibleSurface(
            color: UIColor(white: 0.14, alpha: 1),
            metalness: 0.06,
            roughness: 0.62,
            emission: 0.08
        )
    }

    static func grilleMesh() -> SCNMaterial {
        makeVisibleSurface(
            color: UIColor(white: 0.05, alpha: 1),
            metalness: 0.52,
            roughness: 0.46,
            emission: 0.08
        )
    }

    private static func kind(for node: SCNNode, in root: SCNNode) -> SurfaceKind {
        guard let geometry = node.geometry else { return .unknown }
        let nodeName = (node.name ?? "").lowercased()
        let matName = (geometry.materials.first?.name ?? "").lowercased()
        return classify(nodeName: nodeName, materialName: matName, material: geometry.materials.first ?? SCNMaterial())
    }
}
