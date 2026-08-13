import ModelIO
import SceneKit
import SceneKit.ModelIO
import UIKit

/// Real-world vehicle sizing — aligned with NFS Heat / KRC web (`index.html` race cars ~4.5 m long).
enum KRCVehicleScale {
    /// Bumper-to-bumper target for sports / super cars (NFS uses ~1 m world units).
    static let targetLength: Float = 4.5
    static let rideHeightOffset: Float = 0.48

    /// Scale so the car’s **length** (horizontal span) matches `targetLength`, not overall bbox height.
    static func uniformScale(forBoundingSize size: SCNVector3, multiplier: Float = 1) -> Float {
        let horizontal = max(size.x, size.z)
        let span: Float
        if horizontal > size.y * 0.75 {
            span = max(horizontal, 0.001)
        } else {
            span = max(size.x, size.y, size.z, 0.001)
        }
        return (targetLength * multiplier) / span
    }
}

/// Loads the bundled car model (USDZ format, converted from GLTF 2.0 at build time).
/// SCNSceneSource supports USDZ natively on iOS 12+; GLB/GLTF is not supported by SceneKit directly.
enum GLBCarLoader {
    private static var cache: [String: SCNNode] = [:]

    /// Per-car USDZ basenames under `models/cars/` in the app bundle. Unmapped cars share `krc-camber-ss`.
    private static let perCarModelFiles: [String: String] = [
        "challenger":    "challenger-muscle",
        "falcon-gt":     "falcon-gt1973",
        "firebird-1970": "firebird-1970",
    ]

    static func bundledModelName(forCarId carId: String) -> String? {
        if let named = perCarModelFiles[carId] { return named }
        return "krc-camber-ss"
    }

    /// True when this car has its own USDZ instead of the shared Camber SS shell.
    static func hasUniqueMesh(forCarId carId: String) -> Bool {
        perCarModelFiles[carId] != nil
    }

    static func load(
        carId: String,
        bodyColor: UIColor,
        scale: Float = 1,
        applyLivery: Bool = true,
        isPlayer: Bool = false
    ) -> SCNNode? {
        guard let fileName = bundledModelName(forCarId: carId) else { return nil }

        let rawNode: SCNNode
        if let cached = cache[fileName] {
            rawNode = cached.clone()
        } else {
            // Copied into the app bundle by the Xcode "Copy garage-cars + models" run script.
            let url = Bundle.main.url(forResource: fileName, withExtension: "usdz", subdirectory: "models/cars")
                ?? Bundle.main.url(forResource: fileName, withExtension: "usdz", subdirectory: "models")
                ?? Bundle.main.url(forResource: fileName, withExtension: "usdz")

            guard let url else {
                NSLog("[GLBCarLoader] missing USDZ \(fileName) in models/cars (carId=\(carId))")
                return nil
            }
            guard let wrapper = loadUSDZWrapper(from: url) else {
                NSLog("[GLBCarLoader] failed to load \(url.lastPathComponent) (carId=\(carId))")
                return nil
            }
            cache[fileName] = wrapper
            rawNode = wrapper.clone()
            NSLog("[GLBCarLoader] loaded \(fileName).usdz for carId=\(carId)")
        }

        detachSharedGeometry(in: rawNode)

        let carNode = prepare(node: rawNode, carId: carId, bodyColor: bodyColor, scale: scale)

        let container = SCNNode()
        container.addChildNode(carNode)

        let meshForWheels = container.childNode(withName: "krcVehicleBody", recursively: true) ?? carNode
        WheelAssembly.prepareBundledWheels(carNode: meshForWheels, container: container, scale: scale, carId: carId)
        applyExteriorMaterials(on: container, bodyColor: bodyColor, carId: carId)

        if applyLivery {
            CarLivery.applyStripes(to: container, carId: carId, carNode: meshForWheels, scale: scale)
        }
        CarDecals.apply(to: meshForWheels, container: container, carId: carId, isPlayer: isPlayer, scale: scale)
        applyExteriorMaterials(on: container, bodyColor: bodyColor, carId: carId)

        return container
    }

    /// Prefer Model I/O when available, then SCNSceneSource (same path on Simulator and device).
    private static func loadUSDZWrapper(from url: URL) -> SCNNode? {
        let asset = MDLAsset(url: url)
        asset.loadTextures()
        if asset.count > 0 {
            let scene = SCNScene(mdlAsset: asset)
            let wrapper = SCNNode()
            for child in scene.rootNode.childNodes {
                wrapper.addChildNode(child.clone())
            }
            if !wrapper.childNodes.isEmpty {
                NSLog("[GLBCarLoader] MDLAsset OK \(url.lastPathComponent)")
                return wrapper
            }
        }
        let options: [SCNSceneSource.LoadingOption: Any] = [
            .createNormalsIfAbsent: true,
            .checkConsistency: true,
        ]
        guard let source = SCNSceneSource(url: url, options: options),
              let scene = source.scene(options: options) else {
            return nil
        }
        let wrapper = SCNNode()
        for child in scene.rootNode.childNodes {
            wrapper.addChildNode(child.clone())
        }
        return wrapper.childNodes.isEmpty ? nil : wrapper
    }

    /// `SCNNode.clone()` reuses geometry objects — paint must be applied on per-car geometry copies.
    private static func detachSharedGeometry(in root: SCNNode) {
        root.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            let copied = geometry.copy() as? SCNGeometry ?? geometry
            copied.materials = geometry.materials.map { mat in
                (mat.copy() as? SCNMaterial) ?? mat
            }
            node.geometry = copied
        }
    }

    #if targetEnvironment(simulator)
    /// Bake prepared USDZ transforms into vertex data and parent under an identity container.
    private static func bakeSimulatorReadableMesh(from prepared: SCNNode, into container: SCNNode) {
        let body = SCNNode()
        body.name = "krcVehicleBody"
        var baked = 0
        var minV = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxV = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)

        // Manual matrix bake — `convertPosition` before scene insertion can be unreliable on Sim.
        func localToPrepared(_ p: SCNVector3, from node: SCNNode) -> SCNVector3 {
            var transform = node.simdTransform
            var current: SCNNode? = node.parent
            while let c = current, c !== prepared {
                transform = c.simdTransform * transform
                current = c.parent
            }
            // Include prepared's own scale/position (from prepare()).
            transform = prepared.simdTransform * transform
            let v = transform * SIMD4<Float>(p.x, p.y, p.z, 1)
            return SCNVector3(v.x, v.y, v.z)
        }

        prepared.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry,
                  let vertexSrc = geometry.sources(for: .vertex).first else { return }
            if node.isHidden { return }
            let count = vertexSrc.vectorCount
            guard count > 0 else { return }

            var bakedVerts = [SCNVector3](repeating: SCNVector3Zero, count: count)
            vertexSrc.data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                for i in 0..<count {
                    let ptr = base.advanced(by: vertexSrc.dataOffset + vertexSrc.dataStride * i)
                        .assumingMemoryBound(to: Float.self)
                    let local = SCNVector3(ptr[0], ptr[1], ptr[2])
                    let bakedV = localToPrepared(local, from: node)
                    bakedVerts[i] = bakedV
                    minV.x = min(minV.x, bakedV.x); minV.y = min(minV.y, bakedV.y); minV.z = min(minV.z, bakedV.z)
                    maxV.x = max(maxV.x, bakedV.x); maxV.y = max(maxV.y, bakedV.y); maxV.z = max(maxV.z, bakedV.z)
                }
            }

            var normals = [SCNVector3](repeating: SCNVector3(0, 1, 0), count: count)
            var indices = [Int32]()
            for el in geometry.elements where el.primitiveType == .triangles {
                let idxCount = el.primitiveCount * 3
                el.data.withUnsafeBytes { raw in
                    guard let base = raw.baseAddress else { return }
                    if el.bytesPerIndex == 2 {
                        let p = base.assumingMemoryBound(to: UInt16.self)
                        for i in 0..<idxCount { indices.append(Int32(p[i])) }
                    } else if el.bytesPerIndex == 4 {
                        let p = base.assumingMemoryBound(to: UInt32.self)
                        for i in 0..<idxCount { indices.append(Int32(truncatingIfNeeded: p[i])) }
                    }
                }
            }
            guard !indices.isEmpty else { return }

            // Sim Metal silently drops large USDZ triangle soups; chunk into drawable batches.
            let maxIndicesPerBatch = 900 // 300 triangles
            var start = 0
            var partIndex = 0
            while start < indices.count {
                let end = min(indices.count, start + maxIndicesPerBatch)
                // Align to triangle boundary.
                let alignedEnd = end - ((end - start) % 3)
                if alignedEnd <= start { break }
                let slice = Array(indices[start..<alignedEnd])
                start = alignedEnd

                let mat = SCNMaterial()
                mat.lightingModel = .constant
                mat.diffuse.contents = UIColor(red: 1, green: 0.35, blue: 0.05, alpha: 1)
                mat.emission.contents = UIColor(red: 1, green: 0.35, blue: 0.05, alpha: 1)
                mat.isDoubleSided = true
                mat.transparency = 1
                mat.transparencyMode = .default
                mat.blendMode = .alpha
                mat.writesToDepthBuffer = true
                mat.readsFromDepthBuffer = true

                let rebuilt = SCNGeometry(
                    sources: [SCNGeometrySource(vertices: bakedVerts), SCNGeometrySource(normals: normals)],
                    elements: [SCNGeometryElement(indices: slice, primitiveType: .triangles)]
                )
                rebuilt.materials = [mat]
                let part = SCNNode(geometry: rebuilt)
                part.name = "\(node.name ?? "krcBakedPart")_\(partIndex)"
                part.isHidden = false
                part.opacity = 1
                part.castsShadow = false
                body.addChildNode(part)
                baked += 1
                partIndex += 1
            }
        }
        container.addChildNode(body)
        NSLog(
            "[GLBCarLoader] baked %d sim meshes bbox=(%.2f,%.2f,%.2f)-(%.2f,%.2f,%.2f)",
            baked, minV.x, minV.y, minV.z, maxV.x, maxV.y, maxV.z
        )
    }
    #endif

    private static func prepare(node: SCNNode, carId: String, bodyColor: UIColor, scale: Float) -> SCNNode {
        let (minVec, maxVec) = node.boundingBox
        let size = SCNVector3(maxVec.x - minVec.x, maxVec.y - minVec.y, maxVec.z - minVec.z)
        let uniform = KRCVehicleScale.uniformScale(forBoundingSize: size, multiplier: scale)
        node.scale = SCNVector3(uniform, uniform, uniform)
        node.position = SCNVector3(
            -(minVec.x + maxVec.x) * 0.5 * uniform,
            -minVec.y * uniform + KRCVehicleScale.rideHeightOffset * scale,
            -(minVec.z + maxVec.z) * 0.5 * uniform
        )
        node.name = "krcVehicleBody"
        hideInteriorMeshes(in: node)
        stripLooseWheelArt(in: node)
        VehicleAxes.ensureMarkers(on: node)
        return node
    }

    /// USDZ ships duplicate rim-spoke cubes/cylinders beside the real tire meshes — remove them entirely.
    private static func stripLooseWheelArt(in root: SCNNode) {
        var remove: [SCNNode] = []
        root.enumerateHierarchy { node, _ in
            let n = (node.name ?? "").lowercased()
            if n.contains("rim_spoke") || n.contains("visible_dark_rim") {
                remove.append(node)
            }
        }
        let sorted = remove.sorted { depth(of: $0, in: root) > depth(of: $1, in: root) }
        for node in sorted where node.parent != nil {
            node.removeFromParentNode()
        }
    }

    private static func depth(of node: SCNNode, in root: SCNNode) -> Int {
        var d = 0
        var current: SCNNode? = node
        while let p = current, p !== root {
            d += 1
            current = p.parent
        }
        return d
    }

    /// Replaces every USDZ material slot — the import keeps alpha textures (`T_Body`, `T red A`) that read as see-through / red panels.
    static func applyExteriorMaterials(
        on root: SCNNode,
        bodyColor: UIColor,
        carId: String,
        reflectionTier: AutomotivePaintShader.ReflectionTier = .race
    ) {
        let profile = VehicleVisualProfile.profile(carId: carId)
        let descriptor = profile.paintDescriptor
        let paintDescriptor = VehicleMaterialLibrary.PaintDescriptor(
            color: bodyColor,
            finish: descriptor.finish,
            flake: descriptor.flake,
            clearCoat: descriptor.clearCoat
        )
        let rimMat = VehicleMaterialLibrary.wheelRim(for: GarageCustomization.style(for: carId).rim)

        root.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            if node.isHidden { return }

            let nodeName = (node.name ?? "").lowercased()
            if skipsExteriorMaterialReplace(nodeName: nodeName) { return }

            let matName = (geometry.materials.first?.name ?? "").lowercased()

            #if targetEnvironment(simulator)
            // Keep wheels/lamps specialized; force every other shell slot to opaque body paint.
            // Glass heuristics + dual-layer transparency collapse the USDZ into black fragments on Simulator.
            if isWheelMesh(nodeName: nodeName, matName: matName) {
                if matName.contains("tire") || matName.contains("rubber") || nodeName.contains("tire") || nodeName.contains("rubber") {
                    geometry.materials = [VehicleMaterialLibrary.tireRubber()]
                } else {
                    geometry.materials = [rimMat]
                }
                node.castsShadow = true
                return
            }
            if isHeadlightMesh(nodeName: nodeName, matName: matName) {
                geometry.materials = [VehicleMaterialLibrary.headlightLens()]
                node.name = "krcHeadlightLens"
                node.renderingOrder = 6
                node.castsShadow = false
                return
            }
            if isTailLightMesh(nodeName: nodeName, matName: matName)
                || isBundledTailLampMesh(nodeName: nodeName, matName: matName, node: node, body: root) {
                geometry.materials = [VehicleMaterialLibrary.tailLight()]
                node.name = nodeName.contains("brake") ? "krcBrakeLamp" : "krcTailLamp"
                node.renderingOrder = 4
                node.castsShadow = false
                return
            }
            geometry.materials = [
                VehicleMaterialLibrary.bodyPaint(
                    paintDescriptor,
                    carId: carId,
                    reflectionTier: reflectionTier
                ),
            ]
            node.castsShadow = true
            node.renderingOrder = 0
            return
            #endif

            if isBodyPanelMaterial(matName: matName, nodeName: nodeName) {
                geometry.materials = [
                    VehicleMaterialLibrary.bodyPaint(
                        paintDescriptor,
                        carId: carId,
                        reflectionTier: reflectionTier
                    ),
                ]
                node.castsShadow = true
                node.renderingOrder = 0
                return
            }

            if isGlassMesh(node: node, nodeName: nodeName) {
                let glassMat = VehicleMaterialLibrary.glassMaterial(for: node, in: root)
                geometry.materials = geometry.materials.map { _ in glassMat }
                node.castsShadow = false
                node.renderingOrder = 8
                return
            }

            if isBundledTailLampMesh(nodeName: nodeName, matName: matName, node: node, body: root) {
                geometry.materials = [VehicleMaterialLibrary.tailLight()]
                node.name = nodeName.contains("brake") ? "krcBrakeLamp" : "krcTailLamp"
                node.renderingOrder = 4
                node.castsShadow = false
                return
            }

            if isRedAccentPanel(matName: matName), isMeshAtRear(node: node, body: root),
               !isValidLampShape(node: node, body: root) {
                node.isHidden = true
                return
            }

            if isRedAccentPanel(matName: matName) {
                geometry.materials = [
                    VehicleMaterialLibrary.bodyPaint(
                        paintDescriptor,
                        carId: carId,
                        reflectionTier: reflectionTier
                    ),
                ]
                node.castsShadow = true
                return
            }

            if isHeadlightMesh(nodeName: nodeName, matName: matName) {
                geometry.materials = [VehicleMaterialLibrary.headlightLens()]
                node.name = "krcHeadlightLens"
                node.renderingOrder = 6
                node.castsShadow = false
                return
            }

            if isWheelMesh(nodeName: nodeName, matName: matName) {
                if matName.contains("tire") || matName.contains("rubber") || nodeName.contains("tire") || nodeName.contains("rubber") {
                    geometry.materials = [VehicleMaterialLibrary.tireRubber()]
                } else {
                    geometry.materials = [rimMat]
                }
                node.castsShadow = true
                return
            }

            if isTrimMesh(matName: matName, nodeName: nodeName) {
                geometry.materials = [VehicleMaterialLibrary.carbonFiber()]
                return
            }

            geometry.materials = [
                VehicleMaterialLibrary.bodyPaint(
                    paintDescriptor,
                    carId: carId,
                    reflectionTier: reflectionTier
                ),
            ]
            node.castsShadow = true
            node.renderingOrder = 0
        }
    }

    private static func hideInteriorMeshes(in root: SCNNode) {
        root.enumerateHierarchy { node, _ in
            let nodeName = (node.name ?? "").lowercased()
            let matName = (node.geometry?.materials.first?.name ?? "").lowercased()
            if nodeName.contains("interior") || matName.contains("interior")
                || nodeName.contains("seat") || matName.contains("seat")
                || nodeName.contains("steering") || nodeName.contains("dashboard")
                || nodeName.contains("dash") || nodeName.contains("carpet") {
                node.isHidden = true
            }
        }
    }

    private static func isWheelMesh(nodeName: String, matName: String) -> Bool {
        if isTailLightMesh(nodeName: nodeName, matName: matName) { return false }
        if nodeName.contains("wheel") || nodeName.contains("tire") || nodeName.contains("rim")
            || nodeName.contains("spoke") || nodeName.contains("rubber") || nodeName.contains("helga_wheel")
            || nodeName.contains("visible_dark_rim") {
            return true
        }
        if nodeName.contains("brake") {
            return nodeName.contains("disc") || nodeName.contains("caliper") || nodeName.contains("pad")
                || nodeName.contains("rotor") || matName.contains("caliper") || matName.contains("disc")
        }
        return matName.contains("tire") || matName.contains("rubber") || matName.contains("rim")
            || matName.contains("spoke") || matName.contains("helga_wheel") || matName.contains("alloy_wheel")
    }

    /// Detects window/glass geometry (USDZ names like `Helga_Cristales`, material `KRC black tinted glass`).
    private static func isGlassMesh(node: SCNNode, nodeName: String) -> Bool {
        for base in node.geometry?.materials ?? [] {
            let matName = (base.name ?? "").lowercased()
            if isGlassIdentifier(nodeName: nodeName, matName: matName, material: base) { return true }
        }
        return isGlassIdentifier(nodeName: nodeName, matName: nodeName, material: nil)
    }

    /// USDZ body slots (`T_Body`, etc.) — painted opaque before any glass heuristic runs.
    private static func isBodyPanelMaterial(matName: String, nodeName: String) -> Bool {
        let n = nodeName + " " + matName
        if n.contains("t_body") || n.contains("t red") || n.contains("red a") || n.contains("tail_red") {
            return true
        }
        if matName.contains("body") || matName.contains("paint") || matName.contains("carroceria")
            || matName.contains("carrosserie") {
            return true
        }
        return false
    }

    private static func isGlassIdentifier(nodeName: String, matName: String, material: SCNMaterial?) -> Bool {
        let n = nodeName + " " + matName
        if n.contains("t_body") || n.contains("t red") || n.contains("body") || n.contains("paint")
            || n.contains("carroceria") || n.contains("carrosserie") {
            return false
        }
        if n.contains("glass") || n.contains("window") || n.contains("windshield") || n.contains("windscreen")
            || n.contains("glazing") || n.contains("cristal") || n.contains("cristales") || n.contains("vidrio")
            || n.contains("tinted glass") || n.contains("black tinted") || n.contains("black_tinted") {
            return true
        }
        _ = material
        return false
    }

    private static func isHeadlightMesh(nodeName: String, matName: String) -> Bool {
        let n = nodeName + " " + matName
        if n.contains("taillight") || n.contains("tail_light") || n.contains("rear_light")
            || n.contains("brake_light") || n.contains("stop_light") {
            return false
        }
        if n.contains("headlight") || n.contains("head_light") || n.contains("front_light")
            || n.contains("front_lamp") || n.contains("low_beam") || n.contains("high_beam")
            || n.contains("faro") || n.contains("scheinwerfer") || n.contains("phare") {
            return true
        }
        if (n.contains("lamp") || n.contains("light") || n.contains("lens"))
            && (n.contains("front") || n.contains("head") || n.contains("hl")) {
            return true
        }
        return false
    }

    private static func isTailLightMesh(nodeName: String, matName: String) -> Bool {
        if nodeName.contains("taillight") || nodeName.contains("tail_light") || nodeName.contains("brake_light")
            || nodeName.contains("rear_light") || nodeName.contains("rear_lamp") || nodeName.contains("stop_light") {
            return true
        }
        if matName.contains("taillight") || matName.contains("tail_light") || matName.contains("brake_light")
            || matName.contains("rear_light") {
            return true
        }
        if (nodeName.contains("lamp") || nodeName.contains("light"))
            && (nodeName.contains("rear") || nodeName.contains("tail") || nodeName.contains("brake")) {
            return true
        }
        return false
    }

    /// Only skip KRC helper nodes — never skip `krcVehicleBody` (the main shell carries USDZ geometry).
    private static func skipsExteriorMaterialReplace(nodeName: String) -> Bool {
        switch nodeName {
        case "krcaxlefront", "krcaxlerear", "krcheadlightspot", "krcbrakeglow",
             "krcheadlightlens", "krctailamp", "krcbrakelamp", "krcdriver",
             "krclicenseplate", "krcpolicekit", "krcclasskit",
             "krcstickerhood", "krcstickerdoor", "krckidtoykit", "krcdriverhat":
            return true
        default:
            return false
        }
    }

    /// USDZ `T red A` on the body sides (rear slices are handled as lamps via `isBundledTailLampMesh`).
    private static func isRedAccentPanel(matName: String) -> Bool {
        matName.contains("t red") || matName.contains("tail_red") || matName.contains("red a")
    }

    /// Built-in rear lamp geometry (named meshes or `T red A` at the bumper).
    private static func isBundledTailLampMesh(nodeName: String, matName: String, node: SCNNode, body: SCNNode) -> Bool {
        guard isMeshAtRear(node: node, body: body) else { return false }
        guard isValidLampShape(node: node, body: body) else { return false }
        if isTailLightMesh(nodeName: nodeName, matName: matName) { return true }
        return isRedAccentPanel(matName: matName)
    }

    /// Rejects flat ground slabs mis-tagged as tail lamps (the red rectangle on the asphalt).
    private static func isValidLampShape(node: SCNNode, body: SCNNode) -> Bool {
        guard let frame = VehicleAxes.frame(in: body) else { return true }
        let center = VehicleAxes.meshCenter(in: node, relativeTo: body)
        guard center.y >= frame.baseY + frame.height * 0.16 else { return false }
        let (minB, maxB) = node.boundingBox
        let h = maxB.y - minB.y
        let footprint = max(maxB.x - minB.x, maxB.z - minB.z)
        guard h > 0.002, footprint > 0.002 else { return false }
        return h >= footprint * 0.1
    }

    private static func isMeshAtRear(node: SCNNode, body: SCNNode) -> Bool {
        guard let frame = VehicleAxes.frame(in: body) else { return false }
        let z = VehicleAxes.meshCenter(in: node, relativeTo: body).z
        return frame.isNearRearLamp(z: z)
    }

    private static func isTrimMesh(matName: String, nodeName: String) -> Bool {
        if matName.contains("chrome") || matName.contains("exhaust") || matName.contains("grille")
            || matName.contains("satin_black") || matName.contains("aero") {
            return true
        }
        if nodeName.contains("chrome") || nodeName.contains("grille") || nodeName.contains("mirror")
            || nodeName.contains("details") {
            return true
        }
        return false
    }

}
