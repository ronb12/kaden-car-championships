import SceneKit
import simd
import UIKit

/// Headlights, running taillights, and brake lamps for player + AI cars (USDZ and procedural).
enum VehicleLighting {

    static func install(on root: SCNNode, isPlayer: Bool, allowFallbackLensGeometry: Bool = true) {
        let body = vehicleBody(in: root)
        VehicleAxes.ensureMarkers(on: body)
        guard let frame = VehicleAxes.frame(in: body) else { return }

        // Only strip the invisible spot/beam lights — keep existing lens geometry
        // so USDZ headlight meshes stay correctly placed on the car model.
        stripSpotNodes(from: body)
        stripBrakeGlowNodes(from: body)
        stripProtrudingFallbackLenses(from: body)
        tagLikelyBundledHeadlightMeshes(in: body, frame: frame)
        if allowFallbackLensGeometry, !hasHeadlightLens(in: body) {
            attachFallbackLensGeometry(to: body, frame: frame)
        }
        attachHeadlightSpots(to: body, frame: frame, isPlayer: isPlayer)

        pruneMisplacedLightNodes(in: body, frame: frame)

        refreshBundledLampMaterials(on: root)
        setRunningTailLights(on: root, nightLevel: 0.35)
        setHeadlights(on: root, enabled: true, level: 0.5, isPlayer: isPlayer)
        setBrakeLights(on: root, amount: 0)
    }

    /// Re-apply lamp materials after a shell paint pass.
    static func refreshLampMaterials(on root: SCNNode) {
        refreshBundledLampMaterials(on: root)
    }

    /// Local fill so PBR body paint reads clearly in fog/HDR (garage + race).
    static func installFillLighting(on root: SCNNode, lod: VehicleRenderer.VehicleLOD) {
        root.childNode(withName: "krcVehicleFill", recursively: true)?.removeFromParentNode()
        root.childNode(withName: "krcVehicleFillDir", recursively: true)?.removeFromParentNode()

        let showroom = lod == .garage
        // Race already has a 2600 sun — extra per-car fills were bleaching every body white.
        let omni = SCNNode()
        omni.name = "krcVehicleFill"
        omni.light = SCNLight()
        omni.light?.type = .omni
        omni.light?.intensity = showroom ? 900 : 160
        omni.light?.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1)
        omni.position = SCNVector3(0.8, 1.0, 2.2)
        root.addChildNode(omni)

        let dir = SCNNode()
        dir.name = "krcVehicleFillDir"
        dir.light = SCNLight()
        dir.light?.type = .directional
        dir.light?.intensity = showroom ? 420 : 70
        dir.light?.color = UIColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 1)
        dir.eulerAngles = SCNVector3(-0.65, 0.35, 0)
        root.addChildNode(dir)
    }

    static func setHeadlights(on root: SCNNode, enabled: Bool, level: Float, isPlayer: Bool) {
        let on = enabled && level > 0.02
        let p = on ? max(0.15, min(1, level)) : 0
        let hiEmission = UIColor(red: 1, green: 0.94, blue: 0.67, alpha: 1)
        let loEmission = UIColor(red: 0.55, green: 0.62, blue: 0.78, alpha: 1)
        let offDiffuse = UIColor(white: 0.82, alpha: 1)

        let body = vehicleBody(in: root)
        let frame = VehicleAxes.frame(in: body)

        root.enumerateHierarchy { node, _ in
            if node.name == "krcHeadlightLens" {
                node.geometry?.materials.forEach { mat in
                    if on {
                        let bright = node.renderingOrder >= 6
                        mat.diffuse.contents = UIColor(white: 0.98, alpha: 1)
                        mat.emission.contents = bright ? hiEmission : loEmission
                    } else {
                        mat.diffuse.contents = offDiffuse
                        mat.emission.contents = UIColor(white: 0.12, alpha: 1)
                    }
                }
            } else if node.name == "krcHeadlightSpot", let light = node.light {
                let spotBase: CGFloat = isPlayer ? 2400 : 1200
                light.intensity = on ? spotBase * CGFloat(max(0.25, p)) : 0
                node.isHidden = !on
                if on, let frame {
                    let side = headlightSideSign(for: node, body: body)
                    alignHeadlightSpot(node, frame: frame, sideSign: side)
                }
            }
        }
        if on {
            setRunningTailLights(on: root, nightLevel: level)
        }
    }

    static func setBrakeLights(on root: SCNNode, amount: Float) {
        let a = max(0, min(1, amount))
        let brakeDiffuse = UIColor(red: 1, green: 0.04, blue: 0, alpha: 1)
        let idleDiffuse = UIColor(red: 0.55, green: 0.02, blue: 0.01, alpha: 1)
        let brakeEmit = UIColor(red: CGFloat(0.35 + a * 0.65), green: 0, blue: 0, alpha: 1)

        root.enumerateHierarchy { node, _ in
            if node.name == "krcBrakeLamp" || node.name == "krcTailLamp" {
                guard !node.isHidden else { return }
                node.geometry?.materials.forEach { mat in
                    mat.lightingModel = .constant
                    mat.diffuse.contents = a > 0.05 ? brakeDiffuse : idleDiffuse
                    mat.emission.contents = brakeEmit
                }
            }
        }
        setRunningTailLights(on: root, nightLevel: 0, brakeBoost: a)
    }

    /// Pursuit light show — roof bar, grill, rear deck, plus headlight/tail wig-wags.
    static func updatePoliceFlashers(on root: SCNNode, time: TimeInterval, fullShow: Bool = true) {
        guard root.childNode(withName: "krcPoliceKit", recursively: true) != nil else { return }

        // Fast chase cadence (~12 Hz half-steps).
        let beat = Int(floor(time * 12)) % 4
        let redPhase = beat == 0 || beat == 1
        let bluePhase = beat == 2 || beat == 3
        let whitePhase = beat == 0 || beat == 2
        let leftHead = beat == 0 || beat == 1
        let rightHead = beat == 2 || beat == 3

        let redBright = UIColor(red: 1, green: 0.08, blue: 0.14, alpha: 1)
        let blueBright = UIColor(red: 0.12, green: 0.55, blue: 1, alpha: 1)
        let whiteBright = UIColor(red: 1, green: 0.97, blue: 0.9, alpha: 1)
        let redDim = UIColor(red: 0.22, green: 0.02, blue: 0.04, alpha: 1)
        let blueDim = UIColor(red: 0.02, green: 0.07, blue: 0.2, alpha: 1)
        let whiteDim = UIColor(red: 0.25, green: 0.24, blue: 0.22, alpha: 1)

        func paintLens(named name: String, on: Bool, bright: UIColor, dim: UIColor) {
            root.enumerateHierarchy { node, _ in
                guard node.name == name else { return }
                node.geometry?.materials.forEach { mat in
                    mat.lightingModel = .constant
                    mat.diffuse.contents = on ? bright : dim
                    mat.emission.contents = on ? bright : UIColor.black
                }
            }
        }

        func setFlash(named name: String, on: Bool, color: UIColor, intensity: CGFloat = 2600) {
            root.enumerateHierarchy { node, _ in
                guard node.name == name, let light = node.light else { return }
                light.intensity = on ? intensity : 0
                light.color = color
                node.isHidden = !on
            }
        }

        // Roof + grill + rear — every named police lens flashes.
        let redNames = ["Red", "Red2", "GrillRed", "RearRed", "PlateRed"]
        let blueNames = ["Blue", "GrillBlue", "RearBlue", "PlateBlue"]
        let whiteNames = ["WhiteL", "WhiteR"]

        for suffix in redNames {
            paintLens(named: "krcPoliceLens\(suffix)", on: redPhase, bright: redBright, dim: redDim)
            setFlash(named: "krcPoliceFlash\(suffix)", on: redPhase, color: redBright)
        }
        for suffix in blueNames {
            paintLens(named: "krcPoliceLens\(suffix)", on: bluePhase, bright: blueBright, dim: blueDim)
            setFlash(named: "krcPoliceFlash\(suffix)", on: bluePhase, color: blueBright)
        }
        for suffix in whiteNames {
            paintLens(named: "krcPoliceLens\(suffix)", on: whitePhase, bright: whiteBright, dim: whiteDim)
            setFlash(named: "krcPoliceFlash\(suffix)", on: whitePhase, color: whiteBright, intensity: 2200)
        }

        // Legacy two-lens kit still works if present.
        paintLens(named: "krcPoliceLensRed", on: redPhase, bright: redBright, dim: redDim)
        paintLens(named: "krcPoliceLensBlue", on: bluePhase, bright: blueBright, dim: blueDim)
        setFlash(named: "krcPoliceFlashRed", on: redPhase, color: redBright)
        setFlash(named: "krcPoliceFlashBlue", on: bluePhase, color: blueBright)

        // Plate frame / face strobe with the pursuit cycle (rear bumper light-up).
        let plateOnColor = redPhase ? redBright : blueBright
        let plateFrameIdle = UIColor(red: 0.22, green: 0.24, blue: 0.28, alpha: 1)
        let plateFaceEmit = (redPhase || bluePhase)
            ? plateOnColor.withAlphaComponent(0.7)
            : UIColor(white: 0.05, alpha: 1)
        root.enumerateHierarchy { node, _ in
            if node.name == "krcPolicePlateFrame" {
                node.geometry?.materials.forEach { mat in
                    mat.lightingModel = .constant
                    mat.diffuse.contents = redPhase || bluePhase ? plateOnColor : plateFrameIdle
                    mat.emission.contents = redPhase || bluePhase ? plateOnColor : UIColor(white: 0.08, alpha: 1)
                }
            } else if node.name == "krcPolicePlateFace" {
                node.geometry?.materials.forEach { mat in
                    mat.lightingModel = .constant
                    mat.emission.contents = plateFaceEmit
                }
            } else if node.name == "krcLicensePlate" {
                // Soft omni wash behind the plate so the whole bumper area flashes.
                if node.childNode(withName: "krcPolicePlateWash", recursively: false) == nil {
                    let wash = SCNLight()
                    wash.type = .omni
                    wash.intensity = 0
                    wash.attenuationEndDistance = 3.5
                    let washNode = SCNNode()
                    washNode.name = "krcPolicePlateWash"
                    washNode.light = wash
                    washNode.position = SCNVector3(0, 0, 0.08)
                    node.addChildNode(washNode)
                }
            } else if node.name == "krcPolicePlateWash", let light = node.light {
                light.intensity = redPhase || bluePhase ? 2000 : 0
                light.color = plateOnColor
                node.isHidden = false
            }
        }

        guard fullShow else { return }

        // Headlight wig-wag (left / right).
        let body = vehicleBody(in: root)
        let hiOn = UIColor(red: 1, green: 0.95, blue: 0.75, alpha: 1)
        let hiOff = UIColor(red: 0.2, green: 0.22, blue: 0.28, alpha: 1)
        root.enumerateHierarchy { node, _ in
            if node.name == "krcHeadlightLens" {
                let side = headlightSideSign(for: node, body: body)
                let on = side < 0 ? leftHead : rightHead
                node.geometry?.materials.forEach { mat in
                    mat.lightingModel = .constant
                    mat.diffuse.contents = on ? UIColor.white : UIColor(white: 0.35, alpha: 1)
                    mat.emission.contents = on ? hiOn : hiOff
                }
            } else if node.name == "krcHeadlightSpot", let light = node.light {
                let side = headlightSideSign(for: node, body: body)
                let on = side < 0 ? leftHead : rightHead
                light.intensity = on ? 3200 : 0
                light.color = hiOn
                node.isHidden = !on
            }
        }

        // Tail / brake lamps pulse with the red phase so the rear also strobes.
        let tailOn = redPhase
        let tailEmit = tailOn
            ? UIColor(red: 1, green: 0.05, blue: 0.05, alpha: 1)
            : UIColor(red: 0.2, green: 0.02, blue: 0.02, alpha: 1)
        root.enumerateHierarchy { node, _ in
            guard node.name == "krcTailLamp" || node.name == "krcBrakeLamp" else { return }
            node.geometry?.materials.forEach { mat in
                mat.lightingModel = .constant
                mat.diffuse.contents = UIColor(red: 0.95, green: 0.05, blue: 0.05, alpha: 1)
                mat.emission.contents = tailEmit
            }
        }
    }

    private static func setRunningTailLights(on root: SCNNode, nightLevel: Float = 0, brakeBoost: Float = 0) {
        let glow = max(nightLevel, brakeBoost * 0.35)
        let r = CGFloat(0.72 + glow * 0.22 + brakeBoost * 0.28)
        let baseEmit = UIColor(red: min(1, r), green: 0.04, blue: 0.04, alpha: 1)
        root.enumerateHierarchy { node, _ in
            guard (node.name == "krcTailLamp" || node.name == "krcBrakeLamp"), !node.isHidden else { return }
            node.geometry?.materials.forEach { mat in
                mat.lightingModel = .constant
                mat.diffuse.contents = UIColor(red: 0.90, green: 0.06, blue: 0.06, alpha: 1)
                mat.emission.contents = baseEmit
            }
        }
    }

    static func headlightLevel(weather: EnvironmentLightingSystem.WeatherMode, nightOverride: Bool, visualNight: Bool) -> Float {
        if nightOverride || visualNight { return 1 }
        if PalmCityEnvironment.isActive && PalmCityEnvironment.isNight { return 1 }
        switch weather {
        case .night: return 1
        case .sunset: return 0.55
        case .day: return 0.12
        }
    }

    static func shouldEnableHeadlights(level: Float) -> Bool { level > 0.02 }

    /// Re-apply lamp materials after install (geometry copies can reset emission).
    private static func refreshBundledLampMaterials(on root: SCNNode) {
        root.enumerateHierarchy { node, _ in
            guard let name = node.name else { return }
            switch name {
            case "krcTailLamp", "krcBrakeLamp":
                node.geometry?.materials = [VehicleMaterialLibrary.tailLight()]
                node.isHidden = false
            case "krcHeadlightLens":
                node.geometry?.materials = [VehicleMaterialLibrary.headlightLens()]
            default:
                break
            }
        }
    }

    // MARK: - Headlight helpers

    private static func hasHeadlightLens(in body: SCNNode) -> Bool {
        var found = false
        body.enumerateHierarchy { node, stop in
            if node.name == "krcHeadlightLens" { found = true; stop.pointee = true }
        }
        return found
    }

    private static func attachHeadlightSpots(to body: SCNNode, frame: VehicleAxes.Frame, isPlayer: Bool) {
        let lenses = headlightLensesBySide(in: body, frame: frame)
        let frontAnchor = body.childNode(withName: "krcAxleFront", recursively: true)
        // Recess into the bumper / lamp pocket — never hang past the nose.
        let insetZ = frame.towardCenterFromFront * frame.length * 0.055
        let fallbackLampY: Float? = frontAnchor.map {
            frame.baseY + frame.height * 0.36 - $0.position.y
        }

        for sx: Float in [-1, 1] {
            let lens = sx < 0 ? lenses.left : lenses.right
            let spotNode = SCNNode()
            spotNode.name = "krcHeadlightSpot"
            spotNode.light = makeHeadlightSpotLight(isPlayer: isPlayer)

            if let lens {
                lens.addChildNode(spotNode)
                // Pull the beam origin slightly into the housing so it doesn't flare from outside the nose.
                spotNode.position = SCNVector3(0, 0, frame.towardCenterFromFront * frame.length * 0.01)
            } else if let frontAnchor, let lampY = fallbackLampY {
                spotNode.position = SCNVector3(sx * frame.width * 0.30, lampY, insetZ)
                frontAnchor.addChildNode(spotNode)
            } else {
                continue
            }
            alignHeadlightSpot(spotNode, frame: frame, sideSign: sx)
        }
    }

    private static func makeHeadlightSpotLight(isPlayer: Bool) -> SCNLight {
        let spot = SCNLight()
        spot.type = .spot
        spot.color = UIColor(red: 0.92, green: 0.96, blue: 1.0, alpha: 1)
        spot.intensity = 0
        spot.spotInnerAngle = 18
        spot.spotOuterAngle = isPlayer ? 44 : 36
        spot.castsShadow = false
        spot.attenuationStartDistance = 0
        spot.attenuationEndDistance = isPlayer ? 65 : 44
        return spot
    }

    /// Front-most lens per side (USDZ meshes or procedural `krcHeadlightLens` boxes).
    private static func headlightLensesBySide(in body: SCNNode, frame: VehicleAxes.Frame) -> (left: SCNNode?, right: SCNNode?) {
        var left: [SCNNode] = []
        var right: [SCNNode] = []
        let xThreshold = frame.width * 0.05
        body.enumerateHierarchy { node, _ in
            guard node.name == "krcHeadlightLens" else { return }
            let x = VehicleAxes.meshCenter(in: node, relativeTo: body).x
            if x < -xThreshold { left.append(node) }
            else if x > xThreshold { right.append(node) }
            else if x < 0 { left.append(node) }
            else { right.append(node) }
        }
        let frontIsMaxZ = frame.frontZ > frame.rearZ
        func pickFront(from nodes: [SCNNode]) -> SCNNode? {
            guard !nodes.isEmpty else { return nil }
            return nodes.max { a, b in
                let za = VehicleAxes.meshCenter(in: a, relativeTo: body).z
                let zb = VehicleAxes.meshCenter(in: b, relativeTo: body).z
                return frontIsMaxZ ? za < zb : za > zb
            }
        }
        return (pickFront(from: left), pickFront(from: right))
    }

    private static func headlightSideSign(for spotNode: SCNNode, body: SCNNode) -> Float {
        if let lens = spotNode.parent, lens.name == "krcHeadlightLens" {
            return VehicleAxes.meshCenter(in: lens, relativeTo: body).x >= 0 ? 1 : -1
        }
        let local = body.convertPosition(SCNVector3Zero, from: spotNode)
        return local.x >= 0 ? 1 : -1
    }

    private static func attachFallbackLensGeometry(to body: SCNNode, frame: VehicleAxes.Frame) {
        guard let frontAnchor = body.childNode(withName: "krcAxleFront", recursively: true) else { return }
        let headMat = VehicleMaterialLibrary.headlightLens()
        let lampY = frame.baseY + frame.height * 0.36 - frontAnchor.position.y
        // Seat flush in the lamp pocket — boxes at z=0 on the front axle hung past the bumper.
        let insetZ = frame.towardCenterFromFront * frame.length * 0.07

        for sx: Float in [-1, 1] {
            let lens = SCNBox(
                width: CGFloat(frame.width * 0.14),
                height: CGFloat(frame.height * 0.055),
                length: CGFloat(frame.length * 0.018),
                chamferRadius: 0.012
            )
            lens.materials = [headMat]
            let n = SCNNode(geometry: lens)
            n.name = "krcHeadlightLens"
            n.renderingOrder = 6
            n.position = SCNVector3(sx * frame.width * 0.30, lampY, insetZ)
            frontAnchor.addChildNode(n)
        }
    }

    /// Tag USDZ lamp glass near the front corners when names are ambiguous.
    private static func tagLikelyBundledHeadlightMeshes(in body: SCNNode, frame: VehicleAxes.Frame) {
        if hasHeadlightLens(in: body) { return }
        var candidates: [SCNNode] = []
        body.enumerateHierarchy { node, _ in
            guard node.geometry != nil, !node.isHidden else { return }
            let n = ((node.name ?? "") + " " + (node.geometry?.materials.first?.name ?? "")).lowercased()
            if n.hasPrefix("krc") { return }
            if n.contains("wheel") || n.contains("tire") || n.contains("rubber") { return }
            if n.contains("tail") || n.contains("brake") || n.contains("rear") { return }
            let center = VehicleAxes.meshCenter(in: node, relativeTo: body)
            guard frame.isNearFront(z: center.z) else { return }
            guard abs(center.x) > frame.width * 0.12 else { return }
            let (mn, mx) = node.boundingBox
            let size = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
            guard size > 0.02, size < frame.width * 0.45 else { return }
            let looksLikeLamp = n.contains("lamp") || n.contains("light") || n.contains("lens")
                || n.contains("glass") || n.contains("cristal") || n.contains("faro")
                || n.contains("beam") || n.contains("hl") || n.contains("schein")
            if looksLikeLamp {
                candidates.append(node)
            }
        }
        for node in candidates {
            node.name = "krcHeadlightLens"
            node.renderingOrder = 6
        }
    }

    /// Remove older fallback boxes that were left hanging past the nose.
    private static func stripProtrudingFallbackLenses(from body: SCNNode) {
        guard let frame = VehicleAxes.frame(in: body) else { return }
        var remove: [SCNNode] = []
        body.enumerateHierarchy { node, _ in
            guard node.name == "krcHeadlightLens" else { return }
            // Only strip synthetic boxes we parented under the front axle.
            guard node.parent?.name == "krcAxleFront", node.geometry is SCNBox else { return }
            let z = VehicleAxes.meshCenter(in: node, relativeTo: body).z
            let noseGap = abs(z - frame.frontZ)
            if noseGap < frame.length * 0.02 {
                remove.append(node)
            }
        }
        for node in remove where node.parent != nil {
            node.removeFromParentNode()
        }
    }

    private static func alignHeadlightSpot(_ spotNode: SCNNode, frame: VehicleAxes.Frame, sideSign: Float) {
        // Spot default axis is -Z; flip when the hood faces +Z so beams project forward, not through the cabin.
        spotNode.eulerAngles = SCNVector3(-0.14, frame.headlightSpotYaw + sideSign * 0.03, 0)
    }

    // Only strip invisible light/beam nodes; leave lens geometry intact so USDZ models keep their headlight meshes.
    private static func stripSpotNodes(from body: SCNNode) {
        var remove: [SCNNode] = []
        body.enumerateHierarchy { node, _ in
            guard let name = node.name else { return }
            if name == "krcHeadlightSpot" || name == "krcHeadlightBeam" {
                remove.append(node)
            }
        }
        for node in remove where node.parent != nil {
            node.removeFromParentNode()
        }
    }

    /// Procedural brake omni lights sit on the road — not used for USDZ cars.
    private static func stripBrakeGlowNodes(from body: SCNNode) {
        var remove: [SCNNode] = []
        body.enumerateHierarchy { node, _ in
            if node.name == "krcBrakeGlow" { remove.append(node) }
        }
        for node in remove where node.parent != nil {
            node.removeFromParentNode()
        }
    }

    private static func vehicleBody(in root: SCNNode) -> SCNNode {
        if let named = root.childNode(withName: "krcVehicleBody", recursively: true) {
            return named
        }
        if let bundled = root.childNode(withName: "krcBundledContainer", recursively: true) {
            return bundled
        }
        if let vehicleRoot = root.childNode(withName: "krcVehicleRoot", recursively: false) {
            return vehicleRoot.childNodes.first ?? vehicleRoot
        }
        return root
    }

    private static func pruneMisplacedLightNodes(in body: SCNNode, frame: VehicleAxes.Frame) {
        var remove: [SCNNode] = []
        body.enumerateHierarchy { node, _ in
            guard let name = node.name else { return }
            let z = VehicleAxes.meshCenter(in: node, relativeTo: body).z
            switch name {
            case "krcHeadlightSpot", "krcHeadlightBeam":
                if !frame.isNearFront(z: z) { remove.append(node) }
            case "krcHeadlightLens", "krcBrakeLamp", "krcTailLamp":
                break
            default:
                break
            }
        }
        for node in remove where node.parent != nil {
            node.removeFromParentNode()
        }
    }
}
