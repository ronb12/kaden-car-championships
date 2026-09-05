import SceneKit
import simd
import UIKit

enum RaceParticles {

    private static let nitroName = "nitroFx"
    private static let exhaustName = "exhaustFx"
    private static let exhaustKitName = "krcExhaustKitV5"
    private static let exhaustKitStaleNames = ["krcExhaustKit", "krcExhaustKitV3", "krcExhaustKitV4"]
    private static let driftName = "driftFx"
    private static let brakeGlowName = "brakeGlowFx"

    /// Menu drive-in / idle — always local to the bumper tips so fumes never lag behind the car.
    static func prepareMenuCar(_ root: SCNNode) {
        root.enumerateHierarchy { node, _ in
            node.particleSystems?.forEach { node.removeParticleSystem($0) }
        }
        stripExhaustKits(from: root)
        _ = ensureExhaustKit(on: root)
    }

    static func updateMenuExhaust(on root: SCNNode, active: Bool) {
        let tips = ensureExhaustKit(on: root)
        let emitDir = exhaustEmitDirection(outward: bumperTipPose(on: exhaustHost(on: root)).outward)
        let rate: CGFloat = active ? 36 : 10
        for tip in tips {
            if let fx = tip.childNode(withName: "menuExhaustFx", recursively: false) {
                if let ps = fx.particleSystems?.first {
                    ps.birthRate = rate
                    ps.isLocal = true
                    ps.particleVelocity = 0.05
                    ps.emittingDirection = emitDir
                }
                continue
            }
            let ps = SCNParticleSystem()
            ps.birthRate = rate
            ps.particleLifeSpan = 0.11
            ps.particleLifeSpanVariation = 0.03
            ps.emittingDirection = emitDir
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
        let outward = bumperTipPose(on: exhaustHost(on: node)).outward
        let outerDir = nitroEmitDirection(outward: outward, core: false)
        let coreDir = nitroEmitDirection(outward: outward, core: true)
        for tip in tips {
            if let flame = tip.childNode(withName: nitroName, recursively: false) {
                flame.isHidden = !active
                if active, let systems = flame.particleSystems {
                    systems.first?.birthRate = 260
                    systems.first?.emittingDirection = outerDir
                    systems.dropFirst().first?.birthRate = 180
                    systems.dropFirst().first?.emittingDirection = coreDir
                }
                continue
            }
            guard active else { continue }
            let outer = SCNParticleSystem()
            outer.birthRate = 260
            outer.particleLifeSpan = 0.09
            outer.particleLifeSpanVariation = 0.025
            outer.emittingDirection = outerDir
            outer.spreadingAngle = 10
            outer.particleSize = 0.028
            outer.particleSizeVariation = 0.008
            outer.particleVelocity = 0.55
            outer.particleVelocityVariation = 0.12
            outer.particleColor = UIColor(red: 1.0, green: 0.42, blue: 0.08, alpha: 0.9)
            outer.blendMode = .additive
            outer.isLocal = true
            outer.isLightingEnabled = false
            outer.loops = true
            let core = SCNParticleSystem()
            core.birthRate = 180
            core.particleLifeSpan = 0.06
            core.emittingDirection = coreDir
            core.spreadingAngle = 5
            core.particleSize = 0.016
            core.particleVelocity = 0.72
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
        let emitDir = exhaustEmitDirection(outward: bumperTipPose(on: exhaustHost(on: node)).outward)
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
                    ps.emittingDirection = emitDir
                }
                continue
            }
            guard rate >= 0.5 else { continue }
            let ps = SCNParticleSystem()
            ps.birthRate = rate
            ps.particleLifeSpan = 0.05
            ps.particleLifeSpanVariation = 0.015
            ps.emittingDirection = emitDir
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

    /// Dual chrome tips buried in the rear bumper — only a thin ring shows on the valence.
    @discardableResult
    private static func ensureExhaustKit(on node: SCNNode) -> [SCNNode] {
        let host = exhaustHost(on: node)
        stripExhaustKits(from: node, keepingOn: host)
        if let kit = host.childNode(withName: exhaustKitName, recursively: false) {
            return kit.childNodes.filter { $0.name?.hasPrefix("krcExhaustTip") == true }
        }

        let kit = SCNNode()
        kit.name = exhaustKitName
        let pose = bumperTipPose(on: host)
        // Dark bore disc only — no protruding pipe mesh (the old SCNTube read as a grey line in chase cam).
        let xOff = max(0.10, pose.width * 0.13)
        let bore = VehicleMaterialLibrary.makeVisibleSurface(
            color: UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1),
            metalness: 0.55,
            roughness: 0.42,
            emission: 0.04
        )
        var tips: [SCNNode] = []
        for (i, x) in [xOff, -xOff].enumerated() {
            let faceZ = pose.z

            let plug = SCNCylinder(radius: 0.012, height: 0.0015)
            plug.materials = [bore]
            let plugNode = SCNNode(geometry: plug)
            plugNode.name = "krcExhaustBore\(i)"
            plugNode.eulerAngles.x = .pi / 2
            plugNode.position = SCNVector3(x, pose.y, faceZ - pose.outward * 0.001)
            kit.addChildNode(plugNode)

            let emitter = SCNNode()
            emitter.name = "krcExhaustTip\(i)"
            emitter.position = SCNVector3(x, pose.y, faceZ + pose.outward * 0.003)
            kit.addChildNode(emitter)
            tips.append(emitter)
        }
        host.addChildNode(kit)
        return tips
    }

    private static func stripExhaustKits(from root: SCNNode, keepingOn host: SCNNode? = nil) {
        var names = exhaustKitStaleNames
        if host == nil {
            names.append(exhaustKitName)
        }
        for name in names {
            while let n = root.childNode(withName: name, recursively: true) {
                n.removeFromParentNode()
            }
        }
        if let host, host !== root {
            while let n = root.childNode(withName: exhaustKitName, recursively: false) {
                n.removeFromParentNode()
            }
        }
    }

    /// Bumper-face opening in host space (same hull as the plate), inset into the valence.
    private static func bumperTipPose(on host: SCNNode) -> (y: Float, z: Float, outward: Float, width: Float) {
        let mesh = host.childNode(withName: "krcBundledContainer", recursively: false)
            ?? host.childNode(withName: "krcVehicleBody", recursively: true)
            ?? host
        let hull = VehicleAxes.paintedHull(in: mesh)
        let frame = VehicleAxes.frame(in: mesh)
        let frontIsMaxZ = (frame?.frontZ ?? hull.max.z) >= (frame?.rearZ ?? hull.min.z)
        let rearLocalZ = frontIsMaxZ ? hull.min.z : hull.max.z
        let outward: Float = frontIsMaxZ ? -1 : 1
        let rear = host.convertPosition(SCNVector3(0, 0, rearLocalZ), from: mesh)
        let base = host.convertPosition(SCNVector3(0, hull.min.y, 0), from: mesh)
        let height = max(0.25, hull.max.y - hull.min.y)
        let width = max(0.6, hull.max.x - hull.min.x)
        // In the bumper valence, under the plate — not hanging under the car.
        let y = base.y + height * 0.20
        // Recessed into the same rear face the plate uses.
        let z = rear.z - outward * 0.055
        return (y, z, outward, width)
    }

    /// Rearward puff from each bumper tip — slight lift so flames read from chase cam.
    private static func exhaustEmitDirection(outward: Float) -> SCNVector3 {
        SCNVector3(0, 0.05, outward * 0.97)
    }

    private static func nitroEmitDirection(outward: Float, core: Bool) -> SCNVector3 {
        if core {
            return SCNVector3(0, 0.02, outward * 1.0)
        }
        return SCNVector3(0, 0.04, outward * 0.98)
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
        // Rear bumper — was z=+2.05 (nose), which read as junk stuck out the front.
        fx.position = SCNVector3(0, 0.25, -1.85)
        fx.addParticleSystem(ps)
        node.addChildNode(fx)
    }
}
