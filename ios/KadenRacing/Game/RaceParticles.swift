import SceneKit
import UIKit

enum RaceParticles {

    private static let nitroName = "nitroFx"
    private static let exhaustName = "exhaustFx"
    private static let driftName = "driftFx"
    private static let brakeGlowName = "brakeGlowFx"

    static func updateEffects(
        on node: SCNNode,
        speed: Float,
        nitroActive: Bool,
        drifting: Bool,
        slip: Float = 0,
        braking: Bool = false
    ) {
        #if targetEnvironment(simulator)
        // Particle systems often smear into opaque white/orange slabs on Simulator Metal.
        _ = node; _ = speed; _ = nitroActive; _ = drifting; _ = slip; _ = braking
        return
        #else
        updateNitro(on: node, active: nitroActive)
        updateExhaust(on: node, speed: speed, nitroActive: nitroActive, slip: slip)
        updateDrift(on: node, active: drifting && speed > 0.02, slip: slip)
        updateBrakeGlow(on: node, braking: braking && speed > 0.01, intensity: braking ? 1 : 0)
        #endif
    }

    private static func updateNitro(on node: SCNNode, active: Bool) {
        node.childNodes(passingTest: { child, _ in child.name == nitroName }).forEach { $0.removeFromParentNode() }
        guard active else { return }

        // Outer flame — hot orange/white cone
        let outer = SCNParticleSystem()
        outer.birthRate = 3200
        outer.particleLifeSpan = 0.48
        outer.particleLifeSpanVariation = 0.14
        outer.emittingDirection = SCNVector3(0, 0.1, -1)
        outer.spreadingAngle = 18
        outer.particleSize = 0.11
        outer.particleSizeVariation = 0.04
        outer.particleColor = UIColor(red: 1.0, green: 0.52, blue: 0.08, alpha: 1.0)
        outer.particleColorVariation = SCNVector4(0.08, 0.22, 0.05, 0.1)
        outer.blendMode = .additive
        outer.isLightingEnabled = false
        outer.loops = true

        // Inner core — electric blue-white (NFS heat signature)
        let core = SCNParticleSystem()
        core.birthRate = 1800
        core.particleLifeSpan = 0.28
        core.particleLifeSpanVariation = 0.08
        core.emittingDirection = SCNVector3(0, 0.06, -1)
        core.spreadingAngle = 7
        core.particleSize = 0.055
        core.particleSizeVariation = 0.015
        core.particleColor = UIColor(red: 0.72, green: 0.92, blue: 1.0, alpha: 1.0)
        core.blendMode = .additive
        core.isLightingEnabled = false
        core.loops = true

        let fx = SCNNode()
        fx.name = nitroName
        fx.position = SCNVector3(0, 0.25, 2.1)
        fx.addParticleSystem(outer)
        fx.addParticleSystem(core)
        node.addChildNode(fx)
    }

    private static func updateExhaust(on node: SCNNode, speed: Float, nitroActive: Bool, slip: Float) {
        if let existing = node.childNode(withName: exhaustName, recursively: false) {
            existing.isHidden = nitroActive
            if let ps = existing.particleSystems?.first {
                ps.birthRate = CGFloat(35 + min(220, speed * 1200) + slip * 80)
            }
            return
        }

        let ps = SCNParticleSystem()
        ps.birthRate = 80
        ps.particleLifeSpan = 0.55
        ps.particleLifeSpanVariation = 0.15
        ps.emittingDirection = SCNVector3(0, 0.05, -1)
        ps.spreadingAngle = 8
        ps.particleSize = 0.035
        ps.particleColor = UIColor(white: 0.55, alpha: 0.35)
        ps.blendMode = .additive
        ps.isLightingEnabled = false
        ps.loops = true

        let fx = SCNNode()
        fx.name = exhaustName
        fx.position = SCNVector3(0, 0.18, 2.0)
        fx.addParticleSystem(ps)
        node.addChildNode(fx)
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
        ps.isLightingEnabled = false
        ps.loops = true

        let fx = SCNNode()
        fx.name = driftName
        fx.position = SCNVector3(0, 0.05, -1.2)
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
