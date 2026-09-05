import SceneKit
import UIKit

/// Tire smoke and dust — layered on top of `RaceParticles` (rain disabled).
enum VehicleEnvironmentEffects {

    private static let rainName = "envRainFx"
    private static let worldRainName = "krcWorldRain"
    private static let dustName = "envDustFx"

    static func installWorldRain(on cameraNode: SCNNode, weather: EnvironmentLightingSystem.WeatherMode, quality: GraphicsQuality) {
        _ = weather
        _ = quality
        cameraNode.childNodes(passingTest: { child, _ in child.name == worldRainName }).forEach { $0.removeFromParentNode() }
    }

    static func update(
        on carNode: SCNNode,
        weather: EnvironmentLightingSystem.WeatherMode,
        speed: Float,
        onDirt: Bool
    ) {
        #if targetEnvironment(simulator)
        _ = weather
        clearRain(on: carNode)
        carNode.childNodes(passingTest: { child, _ in child.name == dustName }).forEach { $0.removeFromParentNode() }
        return
        #else
        _ = weather
        clearRain(on: carNode)
        updateDust(on: carNode, active: onDirt, speed: speed)
        #endif
    }

    private static func clearRain(on node: SCNNode) {
        node.childNodes(passingTest: { child, _ in child.name == rainName }).forEach { $0.removeFromParentNode() }
    }

    private static func updateDust(on node: SCNNode, active: Bool, speed: Float) {
        if !active || speed < 0.02 {
            node.childNodes(passingTest: { child, _ in child.name == dustName }).forEach { $0.removeFromParentNode() }
            return
        }
        if node.childNode(withName: dustName, recursively: false) != nil { return }

        let ps = SCNParticleSystem()
        ps.birthRate = CGFloat(40 + min(120, speed * 800))
        ps.particleLifeSpan = 0.6
        ps.emittingDirection = SCNVector3(0, 0.15, -1)
        ps.spreadingAngle = 28
        ps.particleSize = 0.12
        ps.particleColor = UIColor(red: 0.55, green: 0.48, blue: 0.38, alpha: 0.4)
        ps.blendMode = .alpha
        ps.isLightingEnabled = false
        ps.loops = true

        let fx = SCNNode()
        fx.name = dustName
        // Behind the rear axle — was z=+2.4 on the nose.
        fx.position = SCNVector3(0, 0.1, -1.6)
        fx.addParticleSystem(ps)
        node.addChildNode(fx)
    }
}
