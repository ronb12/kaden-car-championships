import Foundation
import SceneKit
import SwiftUI
import UIKit

final class RaceInput {
    var gas = false
    var brake = false
    var nitro = false
    var left = false
    var right = false
}

final class RaceSessionHost: ObservableObject {
    let input = RaceInput()
    let engine: NativeRaceEngine

    init(
        carColor: UIColor,
        lapCount: Int,
        mode: GameModeKind,
        stats: CarRuntimeStats,
        city: CityRuntimeConfig,
        nightOverride: Bool,
        vehicleCategory: VehicleCategory
    ) {
        engine = NativeRaceEngine(
            input: input,
            carColor: carColor,
            lapCount: lapCount,
            mode: mode,
            stats: stats,
            city: city,
            nightOverride: nightOverride,
            vehicleCategory: vehicleCategory
        )
    }
}

final class NativeRaceEngine: NSObject, ObservableObject, SCNSceneRendererDelegate {
    private let input: RaceInput
    private let mode: GameModeKind
    private let stats: CarRuntimeStats
    private let city: CityRuntimeConfig
    private let nightOverride: Bool
    private let vehicleCategory: VehicleCategory
    private let carColor: UIColor
    private let audio = RaceAudioController()

    private weak var view: SCNView?
    private var scene = SCNScene()
    private var carNode = SCNNode()
    private var cameraNode = SCNNode()
    private var trackT: Float = 0
    private var lateral: Float = 0
    private var speed: Float = 0
    private var lastTime: TimeInterval = 0
    private var startTime = Date()
    private var paused = false
    private var finished = false
    private var nitro: Float = 1
    private var heat: Float = 0
    private var driftMultiplier: Float = 1

    @Published var elapsedTime: TimeInterval = 0
    @Published var displayLapIndex = 1
    @Published var driftScore: Int64 = 0
    let lapGoal: Int
    var onRaceFinished: ((TimeInterval) -> Void)?

    init(
        input: RaceInput,
        carColor: UIColor,
        lapCount: Int,
        mode: GameModeKind,
        stats: CarRuntimeStats,
        city: CityRuntimeConfig,
        nightOverride: Bool,
        vehicleCategory: VehicleCategory
    ) {
        self.input = input
        self.carColor = carColor
        self.lapGoal = max(1, lapCount)
        self.mode = mode
        self.stats = stats
        self.city = city
        self.nightOverride = nightOverride
        self.vehicleCategory = vehicleCategory
        super.init()
    }

    func attach(to view: SCNView) {
        self.view = view
        scene = SCNScene()
        view.scene = scene
        view.delegate = self
        view.pointOfView = cameraNode
        buildScene()
        audio.configure(cityThemeId: city.themeId)
        audio.prepare()
        startTime = Date()
    }

    func setPaused(_ paused: Bool) {
        self.paused = paused
        if paused { audio.stop() }
    }

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if lastTime == 0 { lastTime = time }
        let dt = min(1.0 / 30.0, max(0, time - lastTime))
        lastTime = time
        guard !paused, !finished else { return }
        updatePhysics(dt: Float(dt))
    }

    func speedKmh() -> Int { Int(max(0, speed) * 155) }
    func nitroMeter() -> Float { nitro }
    func heatMeter() -> Float { heat }
    func driftMultiplierDisplay() -> Float { driftMultiplier }

    private func buildScene() {
        scene.background.contents = AssetManager.sky(definition: city.definition, night: nightOverride || city.visualNight)
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = nightOverride || city.visualNight ? 380 : 760
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = nightOverride || city.visualNight ? 550 : 1150
        sun.castsShadow = true
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sunNode)

        buildTrack()
        ProceduralCityDecor.buildLayer(into: scene.rootNode, city: city, night: nightOverride || city.visualNight)

        carNode = SCNNode()
        RaceCarGeometry.build(root: carNode, bodyColor: carColor, isPlayer: true, category: vehicleCategory)
        scene.rootNode.addChildNode(carNode)

        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 68
        scene.rootNode.addChildNode(cameraNode)
        placeCar()
    }

    private func buildTrack() {
        let parent = SCNNode()
        let mat = SCNMaterial()
        mat.diffuse.contents = AssetManager.asphalt(definition: city.definition, night: nightOverride || city.visualNight)
        for i in 0..<city.track.points.count {
            let a = city.track.points[i]
            let b = city.track.points[(i + 1) % city.track.points.count]
            let mid = (a + b) * 0.5
            let delta = b - a
            let len = max(1, simd_length(delta))
            let road = SCNBox(width: 9, height: 0.08, length: CGFloat(len), chamferRadius: 0.2)
            road.materials = [mat]
            let n = SCNNode(geometry: road)
            n.position = SCNVector3(mid.x, mid.y - 0.04, mid.z)
            n.eulerAngles.y = atan2(delta.x, delta.z)
            parent.addChildNode(n)
        }
        scene.rootNode.addChildNode(parent)
    }

    private func updatePhysics(dt: Float) {
        let throttle: Float = input.gas ? 1 : 0
        let brake: Float = input.brake ? 1 : 0
        let steer: Float = (input.right ? 1 : 0) - (input.left ? 1 : 0)
        RaceCarGeometry.setBrakeLights(root: carNode, amount: brake)
        let nitroOn = input.nitro && nitro > 0.02
        let topSpeed: Float = 0.105 * stats.topSpeedMul * (nitroOn ? 1.26 : 1)
        speed += throttle * 0.06 * stats.accelMul * dt
        speed -= brake * 0.09 * dt
        speed -= 0.018 * dt
        speed = min(max(speed, 0), topSpeed)
        lateral = max(-3.5, min(3.5, lateral + steer * 5.2 * dt * stats.gripMul))
        lateral *= max(0, 1 - 1.8 * dt)
        if nitroOn { nitro = max(0, nitro - 0.22 * dt) } else { nitro = min(1, nitro + 0.06 * stats.nitroRefillMul * dt) }
        if mode.enablesPolice { heat = min(1, heat + 0.018 * dt * city.policeScale) }
        if abs(steer) > 0.5 && speed > topSpeed * 0.45 {
            driftMultiplier = min(5, driftMultiplier + 0.7 * dt)
            driftScore += Int64(40 * driftMultiplier * dt)
        } else {
            driftMultiplier = max(1, driftMultiplier - 1.2 * dt)
        }

        let previousT = trackT
        trackT += speed * dt
        if previousT > 0.88 && trackT.truncatingRemainder(dividingBy: 1) < 0.12 {
            displayLapIndex += 1
            if displayLapIndex > lapGoal {
                finish()
                return
            }
        }
        let progressT = trackT.truncatingRemainder(dividingBy: 1)
        placeCar()
        elapsedTime = Date().timeIntervalSince(startTime)
        audio.update(
            speedKmh: speedKmh(),
            gasActive: input.gas,
            nitroActive: nitroOn,
            nitroTank: nitro,
            trackProgress: progressT,
            steerAbs: abs(steer)
        )
    }

    private func placeCar() {
        let t = trackT.truncatingRemainder(dividingBy: 1)
        let p = city.track.sample(t)
        let forward = city.track.tangent(t)
        let right = SIMD3<Float>(forward.z, 0, -forward.x)
        let pos = p + right * lateral
        carNode.position = SCNVector3(pos.x, pos.y + 0.35, pos.z)
        carNode.eulerAngles.y = atan2(forward.x, forward.z)

        let camBack = SIMD3<Float>(-forward.x * 12, 5.2, -forward.z * 12)
        let camPos = pos + camBack
        cameraNode.position = SCNVector3(camPos.x, camPos.y, camPos.z)
        cameraNode.look(at: SCNVector3(pos.x + forward.x * 8, pos.y + 1.1, pos.z + forward.z * 8))
        RaceParticles.attachExhaust(to: carNode, nitroActive: input.nitro && nitro > 0.02)
    }

    private func finish() {
        finished = true
        audio.stop()
        onRaceFinished?(Date().timeIntervalSince(startTime))
    }
}
