import SceneKit
import simd
import UIKit

enum RaceParticles {

    private static let nitroName = "nitroFx"
    private static let exhaustName = "exhaustFx"
    private static let exhaustKitName = "krcExhaustKitV3"
    private static let driftName = "driftFx"
    private static let brakeGlowName = "brakeGlowFx"

    /// Menu drive-in / idle — always local to the bumper tips so fumes never lag behind the car.
    static func prepareMenuCar(_ root: SCNNode) {
        root.enumerateHierarchy { node, _ in
            node.particleSystems?.forEach { node.removeParticleSystem($0) }
        }
        root.childNode(withName: "krcExhaustKit", recursively: true)?.removeFromParentNode()
        root.childNode(withName: exhaustKitName, recursively: true)?.removeFromParentNode()
        _ = ensureExhaustKit(on: root)
    }

    static func updateMenuExhaust(on root: SCNNode, active: Bool) {
        let tips = ensureExhaustKit(on: root)
        let rate: CGFloat = active ? 36 : 10
        for tip in tips {
            if let fx = tip.childNode(withName: "menuExhaustFx", recursively: false) {
                if let ps = fx.particleSystems?.first {
                    ps.birthRate = rate
                    ps.isLocal = true
                    ps.particleVelocity = 0.05
                    ps.emittingDirection = SCNVector3(0, 0.15, 0)
                }
                continue
            }
            let ps = SCNParticleSystem()
            ps.birthRate = rate
            ps.particleLifeSpan = 0.11
            ps.particleLifeSpanVariation = 0.03
            ps.emittingDirection = SCNVector3(0, 0.15, 0)
            ps.spreadingAngle = 14
            ps.particleSize = 0.04
            ps.particleSizeVariation = 0.012
            ps.particleVelocity = 0.05
            ps.particleVelocityVariation = 0.02
            ps.acceleration = SCNVector3Zero
            ps.particleColor = UIColor(red: 0.62, green: 0.64, blue: 0.66, alpha: 0.22)
            ps.blendMode = .additive
            ps.isLocal = true
            ps.isLightingEnabled = false
            ps.loops = true
            let fx = SCNNode()
            fx.name = "menuExhaustFx"
            fx.addParticleSystem(ps)
            tip.addChildNode(fx)
        }
    }

    static func updateEffects(
        on node: SCNNode,
        speed: Float,
        nitroActive: Bool,
        drifting: Bool,
        slip: Float = 0,
        braking: Bool = false,
        throttle: Float = 0
    ) {
        #if targetEnvironment(simulator)
        // Particle systems often smear into opaque white/orange slabs on Simulator Metal.
        _ = node; _ = speed; _ = nitroActive; _ = drifting; _ = slip; _ = braking; _ = throttle
        return
        #else
        updateNitro(on: node, active: nitroActive)
        updateExhaust(on: node, speed: speed, nitroActive: nitroActive, throttle: throttle, braking: braking)
        updateDrift(on: node, active: drifting && speed > 0.02, slip: slip)
        updateBrakeGlow(on: node, braking: braking && speed > 0.01, intensity: braking ? 1 : 0)
        #endif
    }

    private static func updateNitro(on node: SCNNode, active: Bool) {
        let tips = ensureExhaustKit(on: node)
        for tip in tips {
            if let flame = tip.childNode(withName: nitroName, recursively: false) {
                flame.isHidden = !active
                if active, let systems = flame.particleSystems {
                    systems.first?.birthRate = 220
                    systems.dropFirst().first?.birthRate = 140
                }
                continue
            }
            guard active else { continue }
            let outer = SCNParticleSystem()
            outer.birthRate = 220
            outer.particleLifeSpan = 0.07
            outer.particleLifeSpanVariation = 0.02
            outer.emittingDirection = SCNVector3(0, 0.2, 0)
            outer.spreadingAngle = 8
            outer.particleSize = 0.022
            outer.particleSizeVariation = 0.006
            outer.particleVelocity = 0.35
            outer.particleVelocityVariation = 0.08
            outer.particleColor = UIColor(red: 1.0, green: 0.42, blue: 0.08, alpha: 0.85)
            outer.blendMode = .additive
            outer.isLocal = true
            outer.isLightingEnabled = false
            outer.loops = true
            let core = SCNParticleSystem()
            core.birthRate = 140
            core.particleLifeSpan = 0.045
            core.emittingDirection = SCNVector3(0, 0.15, 0)
            core.spreadingAngle = 4
            core.particleSize = 0.012
            core.particleVelocity = 0.45
            core.particleColor = UIColor(red: 0.82, green: 0.94, blue: 1.0, alpha: 0.9)
            core.blendMode = .additive
            core.isLocal = true
            core.isLightingEnabled = false
            core.loops = true
            let flame = SCNNode()
            flame.name = nitroName
            flame.addParticleSystem(outer)
            flame.addParticleSystem(core)
            tip.addChildNode(flame)
        }
    }

    private static func updateExhaust(
        on node: SCNNode,
        speed: Float,
        nitroActive: Bool,
        throttle: Float,
        braking: Bool
    ) {
        let tips = ensureExhaustKit(on: node)
        let load = max(0, min(1, throttle))
        let moving = max(0, min(1, abs(speed) * 8))
        // Heat at the tip only — never a world-space trail behind the bumper.
        let rate: CGFloat
        if nitroActive || braking || load < 0.08 {
            rate = 0
        } else {
            rate = CGFloat(6 + load * moving * 22)
        }
        for tip in tips {
            if let fx = tip.childNode(withName: exhaustName, recursively: false) {
                fx.isHidden = rate < 0.5
                if let ps = fx.particleSystems?.first {
                    ps.birthRate = rate
                    ps.isLocal = true
                    ps.particleVelocity = 0.08
                    ps.emittingDirection = SCNVector3(0, 0.2, 0)
                }
                continue
            }
            guard rate >= 0.5 else { continue }
            let ps = SCNParticleSystem()
            ps.birthRate = rate
            ps.particleLifeSpan = 0.05
            ps.particleLifeSpanVariation = 0.015
            ps.emittingDirection = SCNVector3(0, 0.2, 0)
            ps.spreadingAngle = 10
            ps.particleSize = 0.018
            ps.particleSizeVariation = 0.006
            ps.particleVelocity = 0.08
            ps.particleVelocityVariation = 0.03
            ps.acceleration = SCNVector3(0, 0, 0)
            ps.particleColor = UIColor(red: 0.70, green: 0.72, blue: 0.74, alpha: 0.18)
            ps.blendMode = .additive
            ps.isLocal = true
            ps.isLightingEnabled = false
            ps.loops = true
            let fx = SCNNode()
            fx.name = exhaustName
            fx.addParticleSystem(ps)
            tip.addChildNode(fx)
        }
    }

    private static func exhaustHost(on node: SCNNode) -> SCNNode {
        node.childNode(withName: "krcVehicleRoot", recursively: false)
            ?? node.childNode(withName: "krcBundledContainer", recursively: true)
            ?? node.childNode(withName: "krcVehicleBody", recursively: true)
            ?? node
    }

    /// Dual chrome tips seated in the rear bumper valence — short lip, not hanging pipes.
    @discardableResult
    private static func ensureExhaustKit(on node: SCNNode) -> [SCNNode] {
        let host = exhaustHost(on: node)
        for stale in ["krcExhaustKit", "krcExhaustKitV3"] {
            if host !== node {
                node.childNode(withName: stale, recursively: false)?.removeFromParentNode()
            }
        }
        if let kit = host.childNode(withName: exhaustKitName, recursively: false) {
            return kit.childNodes.filter { $0.name?.hasPrefix("krcExhaustTip") == true }
        }
        host.childNode(withName: "krcExhaustKit", recursively: false)?.removeFromParentNode()

        let kit = SCNNode()
        kit.name = exhaustKitName
        let pose = bumperTipPose(on: host)
        let tipLen: Float = 0.034
        let xOff = max(0.10, pose.width * 0.12)
        let chrome = VehicleMaterialLibrary.chrome()
        let bore = VehicleMaterialLibrary.makeVisibleSurface(
            color: UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1),
            metalness: 0.55,
            roughness: 0.42,
            emission: 0.04
        )
        var tips: [SCNNode] = []
        for (i, x) in [xOff, -xOff].enumerated() {
            let tube = SCNTube(innerRadius: 0.015, outerRadius: 0.024, height: CGFloat(tipLen))
            tube.materials = [chrome]
            let pipeNode = SCNNode(geometry: tube)
            pipeNode.name = "krcExhaustPipe\(i)"
            pipeNode.eulerAngles.x = .pi / 2
            pipeNode.position = SCNVector3(x, pose.y, pose.z)
            kit.addChildNode(pipeNode)

            let plug = SCNCylinder(radius: 0.015, height: 0.003)
            plug.materials = [bore]
            let plugNode = SCNNode(geometry: plug)
            plugNode.name = "krcExhaustBore\(i)"
            plugNode.eulerAngles.x = .pi / 2
            plugNode.position = SCNVector3(x, pose.y, pose.z - pose.outward * (tipLen * 0.4))
            kit.addChildNode(plugNode)

            let emitter = SCNNode()
            emitter.name = "krcExhaustTip\(i)"
            // Open end of the tip — on the bumper face, not behind the car.
            emitter.position = SCNVector3(x, pose.y, pose.z + pose.outward * (tipLen * 0.48))
            kit.addChildNode(emitter)
            tips.append(emitter)
        }
        host.addChildNode(kit)
        return tips
    }

    /// Rear valence in host space, pulled a few cm into the bumper so fumes sit on the tips.
    private static func bumperTipPose(on host: SCNNode) -> (y: Float, z: Float, outward: Float, width: Float) {
        let mesh = host.childNode(withName: "krcBundledContainer", recursively: false)
            ?? host.childNode(withName: "krcVehicleBody", recursively: true)
            ?? host
        let hull = bumperHull(in: mesh)
        let frame = VehicleAxes.frame(in: mesh)
        let rearLocalZ = frame?.rearZ ?? hull.min.z
        let frontLocalZ = frame?.frontZ ?? hull.max.z
        let outward: Float = rearLocalZ <= frontLocalZ ? -1 : 1
        let rear = host.convertPosition(SCNVector3(0, 0, rearLocalZ), from: mesh)
        let base = host.convertPosition(SCNVector3(0, frame?.baseY ?? hull.min.y, 0), from: mesh)
        let height = frame?.height ?? max(0.25, hull.max.y - hull.min.y)
        let width = frame?.width ?? max(0.6, hull.max.x - hull.min.x)
        let y = base.y + height * 0.11
        // 6 cm toward the car center from the rear face.
        let z = rear.z - outward * 0.06
        return (y, z, outward, width)
    }

    /// Painted bumper hull — skip wheels, glass, wings, and plates so tips sit on the valence.
    private static func bumperHull(in root: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
        var minV = SIMD3<Float>(repeating: Float.greatestFiniteMagnitude)
        var maxV = SIMD3<Float>(repeating: -Float.greatestFiniteMagnitude)
        var any = false
        root.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let n = ((node.name ?? "") + " " + (node.geometry?.materials.first?.name ?? "")).lowercased()
            if n.contains("wheel") || n.contains("tire") || n.contains("rubber")
                || n.contains("rim") || n.contains("brake") || n.contains("caliper")
                || n.contains("glass") || n.contains("window") || n.contains("windshield")
                || n.contains("spoiler") || n.contains("wing")
                || n.contains("krcclasskit") || n.contains("krclicense")
                || n.contains("krcpolice") || n.contains("krcexhaust")
                || n.contains("krcplate") {
                return
            }
            let (mn, mx) = node.boundingBox
            let corners = [
                SCNVector3(mn.x, mn.y, mn.z), SCNVector3(mx.x, mn.y, mn.z),
                SCNVector3(mn.x, mx.y, mn.z), SCNVector3(mx.x, mx.y, mn.z),
                SCNVector3(mn.x, mn.y, mx.z), SCNVector3(mx.x, mn.y, mx.z),
                SCNVector3(mn.x, mx.y, mx.z), SCNVector3(mx.x, mx.y, mx.z),
            ]
            for c in corners {
                let p = node.convertPosition(c, to: root)
                minV = simd_min(minV, SIMD3(p.x, p.y, p.z))
                maxV = simd_max(maxV, SIMD3(p.x, p.y, p.z))
                any = true
            }
        }
        if !any {
            let b = root.boundingBox
            return (b.min, b.max)
        }
        return (
            SCNVector3(minV.x, minV.y, minV.z),
            SCNVector3(maxV.x, maxV.y, maxV.z)
        )
    }

    private static func updateDrift(on node: SCNNode, active: Bool, slip: Float) {
        if !active {
            node.childNodes(passingTest: { child, _ in child.name == driftName }).forEach { $0.removeFromParentNode() }
            return
        }
        if let existing = node.childNode(withName: driftName, recursively: false),
           let ps = existing.particleSystems?.first {
            ps.birthRate = CGFloat(550 + slip * 900)
            return
        }

        let ps = SCNParticleSystem()
        ps.birthRate = CGFloat(600 + slip * 800)
        ps.particleLifeSpan = 0.85
        ps.particleLifeSpanVariation = 0.25
        ps.emittingDirection = SCNVector3(0, 0.06, 0)
        ps.spreadingAngle = 72
        ps.particleSize = 0.20
        ps.particleSizeVariation = 0.06
        ps.particleColor = UIColor(white: 0.96, alpha: 0.68)
        ps.blendMode = .additive
        ps.isLocal = true
        ps.isLightingEnabled = false
        ps.loops = true

        let fx = SCNNode()
        fx.name = driftName
        fx.position = SCNVector3(0, 0.05, -0.2)
        fx.addParticleSystem(ps)
        node.addChildNode(fx)
    }

    private static func updateBrakeGlow(on node: SCNNode, braking: Bool, intensity: Float) {
        node.childNode(withName: brakeGlowName, recursively: false)?.isHidden = !braking
        guard braking else { return }
        if node.childNode(withName: brakeGlowName, recursively: false) != nil { return }

        let ps = SCNParticleSystem()
        ps.birthRate = CGFloat(200 + intensity * 280)
        ps.particleLifeSpan = 0.18
        ps.particleLifeSpanVariation = 0.06
        ps.emittingDirection = SCNVector3(0, 0.05, -1)
        ps.spreadingAngle = 32
        ps.particleSize = 0.07
        ps.particleSizeVariation = 0.02
        ps.particleColor = UIColor(red: 1, green: 0.22, blue: 0.04, alpha: 0.82)
        ps.blendMode = .additive
        ps.isLightingEnabled = false
        ps.loops = true

        let fx = SCNNode()
        fx.name = brakeGlowName
        fx.position = SCNVector3(0, 0.2, 2.05)
        fx.addParticleSystem(ps)
        node.addChildNode(fx)
    }
}
