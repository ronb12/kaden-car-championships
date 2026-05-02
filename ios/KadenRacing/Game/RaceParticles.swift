import SceneKit
import UIKit

enum RaceParticles {

    /// Exhaust / nitro burst — optimized particle count for mobile.
    static func attachExhaust(to node: SCNNode, nitroActive: Bool) {
        node.childNodes(passingTest: { child, _ in child.name == "nitroFx" }).forEach { $0.removeFromParentNode() }
        guard nitroActive else { return }

        let ps = SCNParticleSystem()
        ps.birthRate = 900
        ps.particleLifeSpan = 0.35
        ps.particleLifeSpanVariation = 0.12
        ps.emittingDirection = SCNVector3(0, 0.2, -1)
        ps.spreadingAngle = 12
        ps.particleSize = 0.055
        ps.particleSizeVariation = 0.02
        ps.particleColor = UIColor(red: 1, green: 0.45, blue: 0.08, alpha: 0.85)
        ps.particleColorVariation = SCNVector4(0.15, 0.2, 0.1, 0.2)
        ps.blendMode = .additive
        ps.isLightingEnabled = false
        ps.loops = true
        ps.warmupDuration = 0.1

        let fx = SCNNode()
        fx.name = "nitroFx"
        fx.position = SCNVector3(0, 0.2, 2.0)
        fx.addParticleSystem(ps)
        node.addChildNode(fx)
    }
}
