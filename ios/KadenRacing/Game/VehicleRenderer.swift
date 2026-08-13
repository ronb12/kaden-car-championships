import SceneKit
import simd
import UIKit

/// Central vehicle build pipeline — same USDZ / procedural path on device and Simulator
/// so App Store / QA visuals match the live phone.
enum VehicleRenderer {

    struct BuildRequest {
        let carId: String
        let bodyColor: UIColor
        var scale: Float = 1
        var isPlayer: Bool = true
        var applyLivery: Bool = true
        var category: VehicleCategory?
        var wheelStyleOverride: VehicleWheelStyle?
        var lod: VehicleLOD = .race
        var preferBundledMesh: Bool = true
        var paintContext: AutomotiveReflectionSystem.PaintContext?
    }

    enum VehicleLOD {
        case race
        case garage
        case opponent
    }

    static func build(into root: SCNNode, request: BuildRequest) {
        root.childNodes.forEach { $0.removeFromParentNode() }
        root.geometry = nil
        root.pivot = SCNMatrix4Identity
        root.scale = SCNVector3(1, 1, 1)
        root.eulerAngles = SCNVector3Zero

        let category = request.category ?? GameCatalog.vehicleCategory(for: request.carId)
        var profile = VehicleVisualProfile.profile(carId: request.carId)
        if let wheel = request.wheelStyleOverride {
            profile = VehicleVisualProfile(
                carId: profile.carId,
                bodyStyle: profile.bodyStyle,
                paintFinish: profile.paintFinish,
                wheelStyle: wheel,
                headlightStyle: profile.headlightStyle,
                dimensions: profile.dimensions,
                rideHeight: profile.rideHeight,
                usesBundledMesh: true,
                accentTrim: profile.accentTrim
            )
        }

        let scale = adjustedScale(request.scale, lod: request.lod)
        let paintContext = request.paintContext ?? AutomotiveReflectionSystem.paintContext(for: request.lod)
        let reflectionTier = paintContext.reflectionTier
        let preferBundled = request.preferBundledMesh
        var usedBundled = false

        let meshRoot: SCNNode
        if preferBundled,
           let usdz = GLBCarLoader.load(
            carId: request.carId,
            bodyColor: request.bodyColor,
            scale: scale,
            applyLivery: false,
            isPlayer: false
           ) {
            meshRoot = usdz
            usedBundled = true
        } else {
            meshRoot = VehicleBodyFactory.build(
                profile: profile,
                bodyColor: request.bodyColor,
                scale: scale,
                isPlayer: false
            )
        }
        meshRoot.name = usedBundled ? "krcBundledContainer" : "krcVehicleBody"

        let bodyContainer = SCNNode()
        bodyContainer.name = "krcVehicleRoot"
        bodyContainer.addChildNode(meshRoot)
        root.addChildNode(bodyContainer)

        if usedBundled {
            // Skip silhouette stretch on device — non-uniform Y scale was burying tires in asphalt.
            // Unique USDZ shells already differ; shared shells stay honest-sized.
        }
        if let carNode = findCarMeshNode(in: bodyContainer) {
            CarDecals.apply(
                to: carNode,
                container: root,
                carId: request.carId,
                isPlayer: request.isPlayer,
                scale: scale
            )
        }
        if request.isPlayer {
            GLBDriverLoader.attach(to: root, scale: scale)
        }
        if usedBundled {
            GLBCarLoader.applyExteriorMaterials(
                on: meshRoot,
                bodyColor: request.bodyColor,
                carId: request.carId,
                reflectionTier: reflectionTier
            )
        } else {
            refreshAutomotivePaint(
                on: meshRoot,
                paint: profile.paintDescriptor,
                bodyColor: request.bodyColor,
                carId: request.carId,
                reflectionTier: reflectionTier
            )
        }
        // Orient shell before lighting so lamps / hit-tests match the final pose.
        alignVehicleForward(on: root)
        seatOnContactPlane(root)
        VehicleLighting.install(on: root, isPlayer: request.isPlayer, allowFallbackLensGeometry: !usedBundled)
        VehicleLighting.installFillLighting(on: root, lod: request.lod)
        // Constant + emission — prior .replace/lambert pass made cars invisible on device.
        forceVisibleRaceShell(
            on: root,
            bodyColor: request.bodyColor,
            isPlayer: request.isPlayer,
            carId: request.carId
        )
        // Full-body vinyl wrap must run after solid paint so it replaces body materials.
        if request.applyLivery, let carNode = findCarMeshNode(in: bodyContainer) {
            CarLivery.applyStripes(to: root, carId: request.carId, carNode: carNode, scale: scale)
        }
        VehicleLighting.refreshLampMaterials(on: root)
        AutomotiveReflectionSystem.register(vehicleRoot: root, context: paintContext)
        _ = category
        root.enumerateHierarchy { node, _ in
            node.isHidden = false
            node.opacity = 1
            if node.geometry != nil { node.castsShadow = false }
        }
        // Drop any leftover debug windshield plate from older builds.
        root.childNode(withName: "krcFrontWindshieldAccent", recursively: true)?.removeFromParentNode()
    }

    /// Rotate shell so the hood faces +Z (matches race heading / AI placement).
    private static func alignVehicleForward(on root: SCNNode) {
        let bodyContainer = root.childNode(withName: "krcVehicleRoot", recursively: false)
            ?? root.childNodes.first
        guard let bodyContainer else { return }
        let mesh = findCarMeshNode(in: bodyContainer) ?? bodyContainer
        guard let frame = VehicleAxes.frame(in: mesh) else { return }
        guard frame.frontZ < frame.rearZ - 0.05 else { return }

        bodyContainer.eulerAngles.y += Float.pi
        // Re-center after yaw flip so seatOnContactPlane plants tires evenly.
        let (minB, maxB) = bodyContainer.boundingBox
        bodyContainer.position.x -= (minB.x + maxB.x) * 0.5
        bodyContainer.position.z -= (minB.z + maxB.z) * 0.5
        if let carMesh = findCarMeshNode(in: bodyContainer) {
            VehicleAxes.ensureMarkers(on: carMesh)
        }
        NSLog("[VehicleRenderer] alignVehicleForward yawπ car facing was −Z")
    }

    /// Solid chase-cam-readable body — black privacy glass on sides/rear, lighter front windshield.
    private static func forceVisibleRaceShell(
        on root: SCNNode,
        bodyColor: UIColor,
        isPlayer: Bool,
        carId: String
    ) {
        let isPolice = carId == "police"
        // Black interceptor body — white accents from CarDecals/CarLivery provide contrast on asphalt.
        let paint: UIColor
        if isPolice {
            paint = UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1)
        } else {
            var tuned = VehicleMaterialLibrary.calibratePaintColor(bodyColor)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            if tuned.getHue(&h, saturation: &s, brightness: &b, alpha: &a), b >= 0.24 {
                s = max(0.52, min(0.95, s))
                b = max(0.58, min(0.96, b))
                tuned = UIColor(hue: h, saturation: s, brightness: b, alpha: 1)
            }
            paint = tuned
        }
        let tire = UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
        let rimMat = VehicleMaterialLibrary.wheelRim(for: GarageCustomization.style(for: carId).rim)
        let rim = rimMat.diffuse.contents as? UIColor
            ?? UIColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1)
        let windshield = UIColor(red: 0.30, green: 0.38, blue: 0.46, alpha: 1)
        let blackGlass = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)

        let bodyRef = root.childNode(withName: "krcVehicleRoot", recursively: false) ?? root

        root.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            let name = ((node.name ?? "") + " " + (geometry.materials.first?.name ?? "")).lowercased()
            // Keep police light-bar, plates, and class kits — don't repaint them body-blue.
            if name.contains("krcpolicekit")
                || name.contains("krclicenseplate")
                || name.contains("krcclasskit")
                || name.contains("krcstripe")
                || name.contains("krclivery")
                || name.contains("krcpolicemarkings")
                || name.contains("krcpolicedoor")
                || name.contains("krcpoliceroof")
                || name.contains("krcpolicechin")
                || name.contains("krcpolicerear")
                || name.contains("krcheadlightlens")
                || name.contains("krctailamp")
                || name.contains("krcbrakelamp")
                || name.contains("krclivery")
                || name.contains("krcstripe")
                || name.contains("krcrimaccent")
                || name.contains("krcrimface")
                || nodeHasAncestorNamed(node, names: [
                    "krcPoliceKit", "krcLicensePlate", "krcClassKit", "krcPoliceMarkings",
                ]) {
                return
            }
            node.isHidden = false
            node.opacity = 1

            let color: UIColor
            let emit: CGFloat
            let matName: String
            if name.contains("tire") || name.contains("rubber") {
                color = tire; emit = 0.12; matName = "krcRaceTire"
            } else if name.contains("wheel") || name.contains("rim") {
                color = rim; emit = 0.28; matName = "krcRaceRim"
            } else if name.contains("glass") || name.contains("cristal") || name.contains("window")
                || name.contains("windshield") || name.contains("windscreen") || name.contains("vidrio") {
                let useWindshield: Bool
                if VehicleMaterialLibrary.isFrontWindshieldName(name) {
                    useWindshield = true
                } else if VehicleMaterialLibrary.isPrivacyGlassName(name) {
                    useWindshield = false
                } else if let mesh = findCarMeshNode(in: bodyRef) ?? Optional(bodyRef),
                          let frame = VehicleAxes.frame(in: mesh) {
                    let center = VehicleAxes.meshCenter(in: node, relativeTo: mesh)
                    useWindshield = frame.isNearFront(z: center.z)
                } else {
                    let (bMin, bMax) = bodyRef.boundingBox
                    let spanZ = max(0.001, bMax.z - bMin.z)
                    let (nMin, nMax) = node.boundingBox
                    let local = SCNVector3(
                        (nMin.x + nMax.x) * 0.5,
                        (nMin.y + nMax.y) * 0.5,
                        (nMin.z + nMax.z) * 0.5
                    )
                    let inBody = node.convertPosition(local, to: bodyRef)
                    useWindshield = ((inBody.z - bMin.z) / spanZ) > 0.58
                }
                color = useWindshield ? windshield : blackGlass
                emit = useWindshield ? 0.32 : 0.08
                matName = useWindshield ? "krcWindshield" : "krcBlackGlass"
            } else if name.contains("head") && name.contains("light") {
                color = UIColor(red: 1, green: 0.96, blue: 0.78, alpha: 1); emit = 0.9; matName = "krcRaceHead"
            } else if name.contains("tail") || (name.contains("brake") && name.contains("lamp")) {
                color = UIColor(red: 1, green: 0.1, blue: 0.06, alpha: 1); emit = 0.8; matName = "krcRaceTail"
            } else {
                color = paint
                // Slight lift so black body isn't a void; white accents carry the silhouette.
                emit = isPolice ? (isPlayer ? 0.28 : 0.20) : (isPlayer ? 0.48 : 0.36)
                matName = "krcRaceVisible"
            }

            let mat = SCNMaterial()
            mat.name = matName
            mat.lightingModel = .constant
            mat.diffuse.contents = color
            if isPolice, matName == "krcRaceVisible" {
                mat.emission.contents = UIColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1)
            } else {
                mat.emission.contents = color
            }
            mat.ambient.contents = color
            mat.multiply.contents = UIColor.white
            mat.transparent.contents = nil
            mat.transparency = 1
            mat.transparencyMode = .default
            mat.blendMode = .alpha
            mat.isDoubleSided = true
            mat.writesToDepthBuffer = true
            mat.readsFromDepthBuffer = true
            mat.locksAmbientWithDiffuse = true
            mat.fillMode = .fill
            mat.shaderModifiers = nil
            mat.program = nil
            if !isPolice, emit > 0.25, isPlayer, matName == "krcRaceVisible" {
                var rh: CGFloat = 0, rs: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
                if color.getHue(&rh, saturation: &rs, brightness: &rb, alpha: &ra) {
                    mat.diffuse.contents = UIColor(hue: rh, saturation: rs, brightness: min(1, rb + 0.06), alpha: 1)
                }
            }
            geometry.materials = [mat]
            geometry.firstMaterial = mat
        }
    }

    private static func nodeHasAncestorNamed(_ node: SCNNode, names: [String]) -> Bool {
        var cur: SCNNode? = node.parent
        while let n = cur {
            if let name = n.name, names.contains(name) { return true }
            cur = n.parent
        }
        return false
    }

    /// Lift mesh so lowest point is just above local y=0; placeCar adds road offset.
    private static func seatOnContactPlane(_ root: SCNNode) {
        root.pivot = SCNMatrix4Identity
        root.scale = SCNVector3(1, 1, 1)

        let body = root.childNode(withName: "krcVehicleRoot", recursively: false)
            ?? root.childNodes.first
        guard let body else { return }
        body.pivot = SCNMatrix4Identity
        body.eulerAngles = SCNVector3Zero
        body.scale = SCNVector3(1, 1, 1)
        body.position = SCNVector3(body.position.x, 0, body.position.z)

        let (minB, maxB) = root.boundingBox
        guard minB.y.isFinite, maxB.y.isFinite, maxB.y > minB.y else { return }
        body.position.y = -minB.y + 0.05

        let (min2, max2) = root.boundingBox
        NSLog(
            "[VehicleRenderer] seatOnContactPlane bboxY=[%.3f…%.3f] → [%.3f…%.3f]",
            minB.y, maxB.y, min2.y, max2.y
        )
    }

    private static func applySilhouetteStretch(to container: SCNNode, profile: VehicleVisualProfile) {
        guard let mesh = findCarMeshNode(in: container) else { return }
        let ref = SIMD3<Float>(1.94, 0.9, KRCVehicleScale.targetLength)
        let d = profile.dimensions
        mesh.scale = SCNVector3(
            mesh.scale.x * (d.x / ref.x),
            mesh.scale.y * (d.y / ref.y),
            mesh.scale.z * (d.z / ref.z)
        )
        // Re-seat tires on the ground plane after non-uniform scale.
        // Without this, Y stretch leaves the prepared Y offset wrong and the car sinks into asphalt.
        let (minB, _) = mesh.boundingBox
        mesh.position.y = -minB.y * mesh.scale.y + KRCVehicleScale.rideHeightOffset
    }

    private static func findCarMeshNode(in container: SCNNode) -> SCNNode? {
        if let named = container.childNode(withName: "krcVehicleBody", recursively: true) {
            return named
        }
        var best: SCNNode?
        var bestVol: Float = 0
        container.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let (minB, maxB) = node.boundingBox
            let vol = (maxB.x - minB.x) * (maxB.y - minB.y) * (maxB.z - minB.z)
            if vol > bestVol {
                bestVol = vol
                best = node
            }
        }
        return best ?? container.childNodes.first
    }

    private static func refreshAutomotivePaint(
        on container: SCNNode,
        paint: VehicleMaterialLibrary.PaintDescriptor,
        bodyColor: UIColor,
        carId: String,
        reflectionTier: AutomotivePaintShader.ReflectionTier
    ) {
        let descriptor = VehicleMaterialLibrary.PaintDescriptor(
            color: bodyColor,
            finish: paint.finish,
            flake: paint.flake,
            clearCoat: paint.clearCoat
        )
        container.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            let name = geometry.materials.first?.name ?? ""
            guard name == "krcAutomotivePaint" || name == "krcAutomotivePaintMetal" else { return }
            geometry.materials = [
                VehicleMaterialLibrary.bodyPaint(descriptor, carId: carId, reflectionTier: reflectionTier),
            ]
        }
    }

    private static func adjustedScale(_ base: Float, lod: VehicleLOD) -> Float {
        switch lod {
        case .race: return base
        case .garage: return base * 0.98
        case .opponent: return base * 0.96
        }
    }
}
