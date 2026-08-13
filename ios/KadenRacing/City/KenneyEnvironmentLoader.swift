import SceneKit
import UIKit

/// Loads **Kenney.nl** CC0 OBJ kits from `models/city/` in the app bundle.
enum KenneyEnvironmentLoader {

    private static let cacheLock = NSLock()
    private static var commercialCache: [String: SCNNode] = [:]
    private static var suburbanCache: [String: SCNNode] = [:]
    private static var roadsCache: [String: SCNNode] = [:]
    private static var treesCache: [String: SCNNode] = [:]

    private static var commercialCatalog: [String] = []
    private static var suburbanCatalog: [String] = []
    private static var roadsCatalog: [String] = []
    private static var treesCatalog: [String] = []

    static var hasBuildings: Bool {
        warmCatalog()
        return !commercialCatalog.isEmpty || !suburbanCatalog.isEmpty
    }

    static var hasSuburban: Bool {
        warmCatalog()
        return !suburbanCatalog.isEmpty
    }

    static var hasRoads: Bool {
        warmCatalog()
        return !roadsCatalog.isEmpty
    }

    static var hasTrees: Bool {
        warmCatalog()
        return !treesCatalog.isEmpty
    }

    /// Loads one model per kit on a background thread so the first race does not hitch.
    static func prewarm() {
        DispatchQueue.global(qos: .utility).async {
            warmCatalog()
            cacheLock.lock()
            defer { cacheLock.unlock() }
            _ = commercialCatalog.first.flatMap { loadTemplateUnlocked(named: $0, subdirectory: "models/city/commercial", cache: &commercialCache) }
            _ = suburbanCatalog.first.flatMap { loadTemplateUnlocked(named: $0, subdirectory: "models/city/suburban", cache: &suburbanCache) }
            _ = roadsCatalog.first.flatMap { loadTemplateUnlocked(named: $0, subdirectory: "models/city/roads", cache: &roadsCache) }
            _ = treesCatalog.first.flatMap { loadTemplateUnlocked(named: $0, subdirectory: "models/city/trees", cache: &treesCache) }
        }
    }

    // MARK: - Buildings

    static func loadBuilding(
        kind: BuildingBlockKind,
        targetHeight: Float,
        night: Bool,
        rng: inout SeededRandom
    ) -> SCNNode? {
        warmCatalog()
        switch kind {
        case .highRise, .neonTower:
            break
        default:
            if hasSuburban, let suburban = loadSuburbanBuilding(kind: kind, targetHeight: targetHeight, night: night, rng: &rng) {
                return suburban
            }
        }
        let pool = commercialCatalog.filter { matchesCommercial($0, kind: kind) }
        guard !pool.isEmpty else { return nil }
        let name = pool[rng.int(in: 0...(pool.count - 1))]
        guard let template = loadTemplate(named: name, subdirectory: "models/city/commercial", cache: &commercialCache) else {
            return nil
        }
        let node = template.clone()
        fit(node, targetHeight: targetHeight)
        if night { applyNightGlow(to: node) }
        return node
    }

    static func loadSuburbanBuilding(
        kind: BuildingBlockKind,
        targetHeight: Float,
        night: Bool,
        rng: inout SeededRandom
    ) -> SCNNode? {
        warmCatalog()
        let pool = suburbanCatalog.filter { matchesSuburban($0, kind: kind) }
        guard !pool.isEmpty else { return nil }
        let name = pool[rng.int(in: 0...(pool.count - 1))]
        guard let template = loadTemplate(named: name, subdirectory: "models/city/suburban", cache: &suburbanCache) else {
            return nil
        }
        let node = template.clone()
        fit(node, targetHeight: targetHeight)
        if night { applyNightGlow(to: node) }
        return node
    }

    static func alignBuildingToGround(_ node: SCNNode, groundY: Float) {
        let (minVec, _) = node.boundingBox
        node.position.y = groundY - minVec.y
    }

    // MARK: - Roads & props

    static func loadStreetLight(night: Bool) -> SCNNode? {
        // Kenney lamp arms hang over the racing line; use a centered solid pole.
        makeSolidLampPole(night: night)
    }

    /// Centered opaque pole + lamp — origin at the base, no overhanging arm.
    static func makeSolidLampPole(night: Bool) -> SCNNode {
        let root = SCNNode()
        let poleMat = SCNMaterial()
        poleMat.lightingModel = .physicallyBased
        poleMat.diffuse.contents = UIColor(white: 0.22, alpha: 1)
        poleMat.roughness.contents = 0.7
        poleMat.transparency = 1
        poleMat.writesToDepthBuffer = true
        let pole = SCNCylinder(radius: 0.1, height: 6.4)
        pole.materials = [poleMat]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(0, 3.2, 0)
        root.addChildNode(poleNode)

        let lampMat = SCNMaterial()
        lampMat.lightingModel = .constant
        lampMat.diffuse.contents = UIColor(red: 1, green: 0.92, blue: 0.72, alpha: 1)
        lampMat.emission.contents = UIColor(red: 1, green: 0.86, blue: 0.5, alpha: night ? 0.85 : 0.4)
        lampMat.transparency = 1
        let lamp = SCNSphere(radius: 0.22)
        lamp.materials = [lampMat]
        let lampNode = SCNNode(geometry: lamp)
        lampNode.position = SCNVector3(0, 6.5, 0)
        root.addChildNode(lampNode)
        return root
    }

    static func loadRoadBarrier() -> SCNNode? {
        loadRoadProp(
            preferred: [
                "construction-barrier", "construction-cone",
                "road-barrier", "road-bend-barrier", "road-crossroad-barrier"
            ],
            targetHeight: 1.1,
            night: false,
            emissionBoost: 0
        )
    }

    static func loadHighwaySign(night: Bool) -> SCNNode? {
        loadRoadProp(
            preferred: ["sign-highway-detailed", "sign-highway"],
            targetHeight: 5.5,
            night: night,
            emissionBoost: night ? 0.22 : 0
        )
    }

    static func loadRoadPiece(named: String, targetHeight: Float = 5) -> SCNNode? {
        loadRoadProp(
            preferred: [named],
            targetHeight: targetHeight,
            night: false,
            emissionBoost: 0
        )
    }

    static func loadFence(targetLength: Float, rng: inout SeededRandom) -> SCNNode? {
        warmCatalog()
        let pool = suburbanCatalog.filter { $0.hasPrefix("fence-") }
        guard !pool.isEmpty else { return nil }
        let name = pool[rng.int(in: 0...(pool.count - 1))]
        guard let template = loadTemplate(named: name, subdirectory: "models/city/suburban", cache: &suburbanCache) else {
            return nil
        }
        let node = template.clone()
        let (minB, maxB) = node.boundingBox
        let len = max(maxB.x - minB.x, maxB.z - minB.z, 0.5)
        let scale = min(max(targetLength / len, 0.08), 8)
        node.scale = SCNVector3(scale, scale, scale)
        alignBuildingToGround(node, groundY: 0)
        return node
    }

    private static func loadRoadProp(
        preferred: [String],
        targetHeight: Float,
        night: Bool,
        emissionBoost: CGFloat
    ) -> SCNNode? {
        warmCatalog()
        let name = preferred.first(where: { roadsCatalog.contains($0) }) ?? roadsCatalog.first
        guard let name,
              let template = loadTemplate(named: name, subdirectory: "models/city/roads", cache: &roadsCache) else {
            return nil
        }
        let node = template.clone()
        fit(node, targetHeight: targetHeight)
        if night { applyNightGlow(to: node, emissionBoost: emissionBoost) }
        return node
    }

    // MARK: - Trees

    static func loadSuburbanTree(targetHeight: Float, rng: inout SeededRandom) -> SCNNode? {
        warmCatalog()
        let pool = suburbanCatalog.filter { $0.hasPrefix("tree-") }
        guard !pool.isEmpty else { return nil }
        let name = pool[rng.int(in: 0...(pool.count - 1))]
        guard let template = loadTemplate(named: name, subdirectory: "models/city/suburban", cache: &suburbanCache) else {
            return nil
        }
        let node = template.clone()
        fit(node, targetHeight: targetHeight)
        return node
    }

    static func loadTree(targetHeight: Float, coastal: Bool, rng: inout SeededRandom, alpine: Bool = false) -> SCNNode? {
        warmCatalog()
        guard !treesCatalog.isEmpty else { return nil }
        let coastalPool = treesCatalog.filter { $0.contains("palm") }
        let pinePool = treesCatalog.filter { $0.contains("pine") }
        let pool: [String]
        if coastal, !coastalPool.isEmpty {
            pool = coastalPool
        } else if alpine, !pinePool.isEmpty {
            pool = pinePool
        } else {
            pool = treesCatalog
        }
        let name = pool[rng.int(in: 0...(pool.count - 1))]
        guard let template = loadTemplate(named: name, subdirectory: "models/city/trees", cache: &treesCache) else {
            return nil
        }
        let node = template.clone()
        fit(node, targetHeight: targetHeight)
        return node
    }

    // MARK: - Catalog

    private static func warmCatalog() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if commercialCatalog.isEmpty {
            commercialCatalog = listOBJ(in: "models/city/commercial")
        }
        if suburbanCatalog.isEmpty {
            suburbanCatalog = listOBJ(in: "models/city/suburban")
        }
        if roadsCatalog.isEmpty {
            roadsCatalog = listOBJ(in: "models/city/roads")
        }
        if treesCatalog.isEmpty {
            treesCatalog = listOBJ(in: "models/city/trees")
        }
    }

    private static func listOBJ(in subdirectory: String) -> [String] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "obj", subdirectory: subdirectory) else {
            return []
        }
        return urls
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { !$0.hasPrefix(".") }
            .sorted()
    }

    private static func matchesCommercial(_ assetName: String, kind: BuildingBlockKind) -> Bool {
        if assetName.contains("skyscraper") {
            return kind == .highRise || kind == .neonTower
        }
        switch kind {
        case .lowRise, .desertCompound:
            return ["building-a", "building-b", "building-c", "building-d"].contains(assetName)
        case .residential, .coastalResort:
            return ["building-e", "building-f", "building-g", "building-h"].contains(assetName)
        case .industrial:
            return ["building-i", "building-j", "building-k", "building-l"].contains(assetName)
        case .highRise, .neonTower:
            return assetName.contains("skyscraper") || ["building-m", "building-n"].contains(assetName)
        }
    }

    private static func matchesSuburban(_ assetName: String, kind: BuildingBlockKind) -> Bool {
        guard assetName.hasPrefix("building-type-") else { return false }
        let suffix = assetName.split(separator: "-").last.map(String.init) ?? ""
        switch kind {
        case .lowRise, .desertCompound:
            return ["a", "b", "c", "d", "e", "f", "g"].contains(suffix)
        case .residential, .coastalResort:
            return ["h", "i", "j", "k", "l", "m", "n"].contains(suffix)
        case .industrial:
            return ["o", "p", "q"].contains(suffix)
        case .highRise, .neonTower:
            return ["r", "s", "t"].contains(suffix)
        }
    }

    // MARK: - Loading

    private static func loadTemplate(
        named name: String,
        subdirectory: String,
        cache: inout [String: SCNNode]
    ) -> SCNNode? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return loadTemplateUnlocked(named: name, subdirectory: subdirectory, cache: &cache)
    }

    /// Caller must hold `cacheLock`.
    private static func loadTemplateUnlocked(
        named name: String,
        subdirectory: String,
        cache: inout [String: SCNNode]
    ) -> SCNNode? {
        if let cached = cache[name] { return cached }
        guard let node = loadOBJ(named: name, subdirectory: subdirectory) else { return nil }
        cache[name] = node
        return node
    }

    private static func loadOBJ(named name: String, subdirectory: String) -> SCNNode? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "obj", subdirectory: subdirectory) else {
            return nil
        }
        let options: [SCNSceneSource.LoadingOption: Any] = [
            .assetDirectoryURLs: [url.deletingLastPathComponent()],
            .checkConsistency: false,
            .convertToYUp: true,
            .convertUnitsToMeters: true
        ]
        guard let scene = try? SCNScene(url: url, options: options) else { return nil }

        let wrapper = SCNNode()
        if scene.rootNode.childNodes.isEmpty {
            wrapper.addChildNode(scene.rootNode.clone())
        } else {
            for child in scene.rootNode.childNodes {
                wrapper.addChildNode(child.clone())
            }
        }
        applyMaterials(to: wrapper, subdirectory: subdirectory)
        return wrapper
    }

    private static func applyMaterials(to root: SCNNode, subdirectory: String) {
        let useAtlas = !subdirectory.contains("trees")
        let colormap = useAtlas ? loadColormap(for: subdirectory) : nil

        root.enumerateChildNodes { node, _ in
            node.castsShadow = true
            guard let geo = node.geometry else { return }
            geo.materials = geo.materials.map { mat in
                let m = mat.copy() as? SCNMaterial ?? mat
                m.lightingModel = .physicallyBased
                m.isDoubleSided = true
                m.writesToDepthBuffer = true
                m.readsFromDepthBuffer = true
                m.transparent.contents = nil
                m.transparency = 1
                m.transparencyMode = .default
                if useAtlas {
                    m.blendMode = .replace
                    if let colormap {
                        m.diffuse.contents = opaqueImage(colormap)
                        m.diffuse.wrapS = .repeat
                        m.diffuse.wrapT = .repeat
                    } else if m.diffuse.contents == nil || isUntexturedWhite(m) {
                        m.diffuse.contents = UIColor(red: 0.38, green: 0.32, blue: 0.26, alpha: 1)
                    }
                } else {
                    m.blendMode = .alpha
                    if m.diffuse.contents == nil || isUntexturedWhite(m) {
                        m.diffuse.contents = UIColor(red: 0.38, green: 0.32, blue: 0.26, alpha: 1)
                    }
                }
                m.metalness.contents = 0.02
                m.roughness.contents = 0.88
                m.multiply.contents = UIColor(white: 0.52, alpha: 1)
                return m
            }
        }
    }

    private static func loadColormap(for subdirectory: String) -> UIImage? {
        let dirs = [
            subdirectory + "/Textures",
            subdirectory,
            "models/city/commercial/Textures",
            "models/city/roads/Textures",
            "models/city/suburban/Textures",
        ]
        for dir in dirs {
            if let url = Bundle.main.url(forResource: "colormap", withExtension: "png", subdirectory: dir) {
                if let img = UIImage(contentsOfFile: url.path) { return img }
            }
        }
        return nil
    }

    private static func opaqueImage(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            UIColor(red: 0.42, green: 0.41, blue: 0.39, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func isUntexturedWhite(_ mat: SCNMaterial) -> Bool {
        guard let color = mat.diffuse.contents as? UIColor else { return false }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return r > 0.92 && g > 0.92 && b > 0.92
    }

    private static func fit(_ node: SCNNode, targetHeight: Float) {
        let (minVec, maxVec) = node.boundingBox
        let h = maxVec.y - minVec.y
        guard h > 0.05 else { return }
        let raw = targetHeight / h
        let scale = min(max(raw, 0.08), 12)
        node.scale = SCNVector3(scale, scale, scale)
        let centerX = (minVec.x + maxVec.x) * 0.5 * scale
        let centerZ = (minVec.z + maxVec.z) * 0.5 * scale
        node.position.x -= centerX
        node.position.z -= centerZ
        node.position.y -= minVec.y * scale
    }

    private static func applyNightGlow(to root: SCNNode, emissionBoost: CGFloat = 1.0) {
        root.enumerateChildNodes { node, _ in
            guard let mat = node.geometry?.firstMaterial else { return }
            let name = (node.name ?? "").lowercased()
            if name.contains("window") || name.contains("glass") {
                let warm = UIColor(red: 0.95, green: 0.82, blue: 0.58, alpha: min(0.42, 0.28 + emissionBoost * 0.12))
                mat.emission.contents = warm
            }
        }
    }

    /// Race circuits must never show see-through Kenney glass / alpha holes on the racing line.
    static func forceOpaque(_ node: SCNNode) {
        node.opacity = 1
        node.enumerateHierarchy { child, _ in
            child.opacity = 1
            guard let geo = child.geometry else { return }
            for mat in geo.materials {
                mat.transparency = 1
                mat.transparencyMode = .default
                mat.blendMode = .alpha
                mat.isDoubleSided = true
                mat.writesToDepthBuffer = true
                mat.readsFromDepthBuffer = true
                mat.transparent.contents = nil
                if let img = mat.diffuse.contents as? UIImage {
                    mat.diffuse.contents = opaqueImage(img)
                } else if let color = mat.diffuse.contents as? UIColor {
                    mat.diffuse.contents = color.withAlphaComponent(1)
                }
            }
        }
    }
}
