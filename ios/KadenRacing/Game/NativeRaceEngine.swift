import QuartzCore
import SceneKit
import simd
import UIKit

// MARK: - Input

/// High-frequency control state read by `NativeRaceEngine` each frame.
/// **Not** `ObservableObject` — mutating this from `UIViewRepresentable` / UIKit would
/// trigger “Publishing changes from within view updates” if properties were `@Published`.
final class RaceInput {
    var gas = false
    var brake = false
    var left = false
    var right = false
    var nitro = false
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
            carColor: carColor,
            lapCount: lapCount,
            input: input,
            mode: mode,
            stats: stats,
            city: city,
            nightOverride: nightOverride,
            vehicleCategory: vehicleCategory
        )
    }
}

private enum AIBehavior {
    case rivalOrbit
    case policeChase
    case trafficSlow
}

/// High-speed arcade SceneKit loop: nitro, drift combo, heat / pursuit AI, day-night lighting.
final class NativeRaceEngine: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()

    private let track: ClosedTrackSpline
    private let city: CityRuntimeConfig
    private let mode: GameModeKind
    private let stats: CarRuntimeStats
    private let nightVisual: Bool
    private let vehicleCategory: VehicleCategory
    private var streamCoordinator: CityStreamingCoordinator?
    private let decorRoot = SCNNode()

    private let carRoot = SCNNode()
    private let cameraNode = SCNNode()
    private weak var scnView: SCNView?

    private var aiNodes: [SCNNode] = []
    private var aiT: [Float]
    private var aiLat: [Float]
    private var aiBehavior: [AIBehavior]

    private weak var sunNode: SCNNode?
    private weak var ambientLightNode: SCNNode?

    private var tParam: Float = 0
    private(set) var completedLaps: Int = 0
    private var lateral: Float = 0
    private var speed: Float = 0
    private var nitroLevel: Float = 1
    private var lastNitroVisual = false
    private var lastNearMissAt: TimeInterval = 0

    private var driftSlip: Float = 0
    private var driftMultiplier: Float = 1
    private(set) var driftScore: Int64 = 0
    private(set) var nearMissStreak: Int = 0

    private var heat: Float = 0

    private let totalLaps: Int
    private(set) var raceFinished = false
    private var raceClockStart: CFTimeInterval?
    private var lastRenderTime: CFTimeInterval?
    private var paused = false

    let input: RaceInput
    private let speedScale: Float = 5.7
    private(set) var elapsedTime: TimeInterval = 0
    var onRaceFinished: ((TimeInterval) -> Void)?

    private let audio = RaceAudioController()

    init(
        carColor: UIColor,
        lapCount: Int,
        input: RaceInput,
        mode: GameModeKind,
        stats: CarRuntimeStats,
        city: CityRuntimeConfig,
        nightOverride: Bool,
        vehicleCategory: VehicleCategory
    ) {
        self.mode = mode
        self.stats = stats
        self.city = city
        self.track = city.track
        self.vehicleCategory = vehicleCategory
        self.nightVisual = nightOverride || city.visualNight
        self.totalLaps = max(1, lapCount)
        self.input = input

        switch mode {
        case .policeChase, .endless, .career:
            aiBehavior = [.policeChase, .policeChase, .trafficSlow]
            aiT = [0.02, 0.055, 0.12]
            aiLat = [0.4, -0.55, 1.2]
        case .timeTrial, .ghostDuel:
            aiBehavior = [.rivalOrbit, .rivalOrbit, .rivalOrbit]
            aiT = [0.05, 0.09, 0.14]
            aiLat = [0, 0.6, -0.8]
        default:
            aiBehavior = [.rivalOrbit, .rivalOrbit, .rivalOrbit]
            aiT = [0.03, 0.07, 0.11]
            aiLat = [0.15, -0.4, 0.65]
        }

        super.init()
        nitroLevel = stats.nitroCapacityMul * 0.92
        buildWorld(carColor: carColor)
        audio.prepare()
        audio.configure(cityThemeId: city.themeId)
    }

    func attach(to view: SCNView) {
        scnView = view
        view.scene = scene
        view.pointOfView = cameraNode
        view.delegate = self
        view.isPlaying = true
        view.antialiasingMode = .multisampling4X
    }

    func setPaused(_ p: Bool) {
        paused = p
        scnView?.isPlaying = !p
        if !p { lastRenderTime = nil }
        if p { audio.stop() }
    }

    /// HUD meters
    func nitroMeter() -> Float { nitroLevel }
    func heatMeter() -> Float { min(1, heat / 5) }
    func driftMultiplierDisplay() -> Float { driftMultiplier }

    func resetRace() {
        tParam = 0
        lateral = 0
        speed = 0
        nitroLevel = stats.nitroCapacityMul * 0.92
        completedLaps = 0
        driftScore = 0
        driftMultiplier = 1
        driftSlip = 0
        heat = 0
        raceFinished = false
        raceClockStart = nil
        lastRenderTime = nil
        elapsedTime = 0
    }

    var displayLapIndex: Int {
        min(completedLaps + 1, totalLaps)
    }

    /// Goal laps for HUD (`totalLaps` is internal).
    var lapGoal: Int { totalLaps }

    // MARK: World

    private func buildWorld(carColor: UIColor) {
        scene.background.contents = AssetManager.sky(definition: city.definition, night: nightVisual)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(white: nightVisual ? 0.28 : 0.58, alpha: 1)
        let an = SCNNode()
        an.light = ambient
        scene.rootNode.addChildNode(an)
        ambientLightNode = an

        let sun = SCNLight()
        sun.type = .directional
        sun.castsShadow = true
        sun.shadowMode = .deferred
        sun.shadowSampleCount = nightVisual ? 8 : 12
        sun.maximumShadowDistance = 220
        sun.shadowRadius = nightVisual ? 6 : 4
        sun.color = UIColor(white: nightVisual ? 0.55 : 0.98, alpha: 1)
        let sn = SCNNode()
        sn.light = sun
        sn.eulerAngles = SCNVector3(nightVisual ? -0.85 : -1.05, nightVisual ? 0.55 : 0.78, 0)
        scene.rootNode.addChildNode(sn)
        sunNode = sn

        addSkyHemisphere()
        addGroundAndGrass()

        scene.rootNode.addChildNode(buildRoadRibbon())
        addCurbsAndCenterLine()

        decorRoot.name = "cityDecor"
        scene.rootNode.addChildNode(decorRoot)
        ProceduralCityDecor.buildLayer(into: decorRoot, city: city, night: nightVisual)
        streamCoordinator = CityStreamingCoordinator(decorRoot: decorRoot, trackPoints: track.points.count)

        RaceCarGeometry.build(root: carRoot, bodyColor: carColor, scale: 1, isPlayer: true, category: vehicleCategory)
        carRoot.position = SCNVector3(track.position(at: 0))
        scene.rootNode.addChildNode(carRoot)

        let palette: [UIColor] = mode.enablesPolice
            ? [
                UIColor(red: 0.12, green: 0.22, blue: 0.65, alpha: 1),
                UIColor(red: 0.12, green: 0.22, blue: 0.65, alpha: 1),
                UIColor(white: 0.55, alpha: 1)
            ]
            : [
                UIColor(red: 0.95, green: 0.75, blue: 0.1, alpha: 1),
                UIColor(red: 0.08, green: 0.28, blue: 0.85, alpha: 1),
                UIColor(red: 0.12, green: 0.58, blue: 0.28, alpha: 1)
            ]

        for i in 0..<3 {
            let node = SCNNode()
            let cat: VehicleCategory = (mode.enablesPolice && i < 2) ? .policeInterceptor : .sports
            RaceCarGeometry.build(
                root: node,
                bodyColor: palette[i],
                scale: mode.enablesPolice && i < 2 ? 0.92 : 0.94,
                isPlayer: false,
                category: cat
            )
            scene.rootNode.addChildNode(node)
            aiNodes.append(node)
        }

        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 650
        cameraNode.camera?.fieldOfView = nightVisual ? 54 : 52
        cameraNode.camera?.wantsHDR = true
        scene.rootNode.addChildNode(cameraNode)
    }

    private func addSkyHemisphere() {
        let sky = SCNSphere(radius: 580)
        sky.segmentCount = 28
        sky.firstMaterial?.diffuse.contents = AssetManager.sky(definition: city.definition, night: nightVisual)
        sky.firstMaterial?.lightingModel = .constant
        sky.firstMaterial?.isDoubleSided = true
        sky.firstMaterial?.writesToDepthBuffer = false
        let node = SCNNode(geometry: sky)
        node.position = SCNVector3(0, 120, 0)
        scene.rootNode.addChildNode(node)
    }

    private func addGroundAndGrass() {
        let ground = SCNNode(geometry: SCNPlane(width: 980, height: 980))
        ground.geometry?.firstMaterial?.diffuse.contents = AssetManager.ground(definition: city.definition, night: nightVisual)
        ground.geometry?.firstMaterial?.locksAmbientWithDiffuse = true
        ground.rotation = SCNVector4(1, 0, 0, -Float.pi / 2)
        ground.position = SCNVector3(0, -0.14, 0)
        scene.rootNode.addChildNode(ground)

        let turfStrip = SCNNode(geometry: SCNPlane(width: 980, height: 36))
        turfStrip.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.14, green: 0.38, blue: 0.16, alpha: 1)
        turfStrip.geometry?.firstMaterial?.locksAmbientWithDiffuse = true
        turfStrip.rotation = SCNVector4(1, 0, 0, -Float.pi / 2)
        turfStrip.position = SCNVector3(0, -0.13, 0)
        scene.rootNode.addChildNode(turfStrip)
    }

    private func buildRoadRibbon() -> SCNNode {
        let n = track.points.count
        let halfWidth: Float = 5.6
        let yRoad: Float = 0.07

        var positions: [Float] = []
        var normals: [Float] = []
        for i in 0..<n {
            let t = Float(i) / Float(n)
            let p = track.position(at: t)
            let right = track.right(at: t)
            let lift = SIMD3<Float>(0, yRoad, 0)
            let inner = p + right * (-halfWidth) + lift
            let outer = p + right * halfWidth + lift
            let up = simd_normalize(simd_cross(right, track.tangent(at: t)))
            let nrm = up.y > 0.2 ? up : SIMD3<Float>(0, 1, 0)
            positions.append(contentsOf: [inner.x, inner.y, inner.z, outer.x, outer.y, outer.z])
            normals.append(contentsOf: [nrm.x, nrm.y, nrm.z, nrm.x, nrm.y, nrm.z])
        }

        var indices: [UInt32] = []
        for i in 0..<n {
            let j = (i + 1) % n
            let i0 = UInt32(i * 2)
            let i1 = i0 + 1
            let i2 = UInt32(j * 2)
            let i3 = i2 + 1
            indices.append(contentsOf: [i0, i2, i1, i1, i2, i3])
        }

        let vCount = n * 2
        let posData = positions.withUnsafeBufferPointer { Data(buffer: $0) }
        let normData = normals.withUnsafeBufferPointer { Data(buffer: $0) }
        let idxData = indices.withUnsafeBufferPointer { Data(buffer: $0) }

        let vertexSource = SCNGeometrySource(
            data: posData,
            semantic: .vertex,
            vectorCount: vCount,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )
        let normalSource = SCNGeometrySource(
            data: normData,
            semantic: .normal,
            vectorCount: vCount,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )
        let element = SCNGeometryElement(
            data: idxData,
            primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )

        let geo = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        let asphalt = AssetManager.asphalt(definition: city.definition, night: nightVisual)
        geo.firstMaterial?.diffuse.contents = asphalt
        geo.firstMaterial?.specular.contents = UIColor(white: nightVisual ? 0.12 : 0.22, alpha: 1)
        geo.firstMaterial?.shininess = 0.28

        let node = SCNNode(geometry: geo)
        node.castsShadow = false
        return node
    }

    private func addCurbsAndCenterLine() {
        let n = track.points.count
        let halfWidth: Float = 5.6
        let yCurb: Float = 0.11
        let curbH: Float = 0.14
        let matRed = SCNMaterial()
        matRed.diffuse.contents = UIColor(red: 0.85, green: 0.08, blue: 0.1, alpha: 1)
        let matWht = SCNMaterial()
        matWht.diffuse.contents = UIColor(white: 0.92, alpha: 1)

        for i in stride(from: 0, to: n, by: 3) {
            let t = Float(i) / Float(n)
            let p = track.position(at: t)
            let tan = track.tangent(at: t)
            let right = track.right(at: t)
            let outward = right * (halfWidth + 0.35)
            let bx = p.x + outward.x
            let bz = p.z + outward.z
            let ang = atan2(tan.x, tan.z)
            let box = SCNBox(width: 0.55, height: CGFloat(curbH), length: 0.45, chamferRadius: 0.02)
            box.materials = [((i / 3) % 2 == 0) ? matRed : matWht]
            let cn = SCNNode(geometry: box)
            cn.position = SCNVector3(bx, p.y + yCurb + Float(curbH) * 0.5, bz)
            cn.eulerAngles.y = ang
            cn.castsShadow = true
            scene.rootNode.addChildNode(cn)
        }

        let dashMat = SCNMaterial()
        dashMat.diffuse.contents = UIColor(red: 0.95, green: 0.82, blue: 0.12, alpha: 1)
        for i in stride(from: 0, to: n, by: 6) {
            let t = Float(i) / Float(n)
            let p = track.position(at: t)
            let tan = track.tangent(at: t)
            let dash = SCNBox(width: 0.22, height: 0.03, length: 1.4, chamferRadius: 0.01)
            dash.materials = [dashMat]
            let dn = SCNNode(geometry: dash)
            dn.position = SCNVector3(p.x, p.y + yCurb + 0.02, p.z)
            dn.eulerAngles.y = atan2(tan.x, tan.z)
            dn.castsShadow = false
            scene.rootNode.addChildNode(dn)
        }
    }

    // MARK: Loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard !paused, !raceFinished else { return }
        let dtRaw = lastRenderTime.map { time - $0 } ?? (1.0 / 60.0)
        lastRenderTime = time
        let dt = Float(min(max(dtRaw, 1.0 / 240.0), 0.12))
        guard dt > 0 else { return }

        if raceClockStart == nil { raceClockStart = time }
        elapsedTime = time - (raceClockStart ?? time)

        integrate(dt: dt)
        syncTransforms()
        updateCamera(dt: dt)
        let steerBit = abs((input.left ? 1 : 0) - (input.right ? 1 : 0))
        audio.update(
            speedKmh: speedKmh(),
            gasActive: input.gas,
            nitroActive: input.nitro && nitroLevel > 0.02,
            nitroTank: nitroLevel,
            trackProgress: tParam,
            steerAbs: Float(steerBit)
        )

        streamCoordinator?.update(playerT: tParam)

        let nitroVis = input.nitro && nitroLevel > 0.05
        if nitroVis != lastNitroVisual {
            RaceParticles.attachExhaust(to: carRoot, nitroActive: nitroVis)
            lastNitroVisual = nitroVis
        }
    }

    private func integrate(dt: Float) {
        let gas = input.gas
        let brake = input.brake
        let steer: Float = (input.left ? 1 : 0) - (input.right ? 1 : 0)

        let grip = stats.gripMul
        let tankOk = nitroLevel > 0.02
        let nitroBoostActive = input.nitro && tankOk
        let maxSpeed: Float = 52 * stats.topSpeedMul * stats.durabilityMul * (nitroBoostActive ? 1.34 : 1)
        let accel: Float = 28 * stats.accelMul
        let nitroAccelMul: Float = (nitroBoostActive && gas) ? 1.24 : 1
        let braking: Float = 55
        let friction: Float = 12

        // Burn while boosting and (throttle OR already carrying speed) so nitro works on a hot lap.
        if input.nitro, nitroLevel > 0, gas || abs(speed) > 6 {
            let burn: Float = 0.4 * dt / stats.nitroRefillMul
            nitroLevel = max(0, nitroLevel - burn)
        } else if gas {
            nitroLevel = min(stats.nitroCapacityMul, nitroLevel + 0.08 * dt * stats.nitroRefillMul)
        } else if !input.nitro {
            nitroLevel = min(stats.nitroCapacityMul, nitroLevel + 0.03 * dt * stats.nitroRefillMul)
        }

        if gas {
            speed = min(maxSpeed, speed + accel * nitroAccelMul * dt * grip)
        } else if brake {
            speed = max(-maxSpeed * 0.28, speed - braking * dt)
        } else {
            if speed > 0 { speed = max(0, speed - friction * dt) }
            else if speed < 0 { speed = min(0, speed + friction * dt) }
        }

        let steerEff = steer * min(Float(1.35), speed / 20 + Float(0.38)) * grip
        lateral += steerEff * dt * 4.1
        lateral = max(-3.5, min(3.5, lateral))

        let driftActive = abs(steer) > 0.38 && speed > 16
        if driftActive {
            driftSlip += dt * abs(steer)
            driftMultiplier = min(5, driftMultiplier + dt * 0.65)
            let scoreTick = Double(driftMultiplier) * Double(speed) * Double(dt) * 12
            driftScore += Int64(scoreTick)
        } else {
            driftSlip = max(0, driftSlip - dt * 2)
            driftMultiplier = max(1, driftMultiplier - dt * 0.9)
        }

        let ds = speed * dt
        let oldT = tParam
        var nt = tParam + ds / track.totalLength
        if nt >= 1 { nt -= floor(nt) }
        if nt < 0 { nt += ceil(-nt) }

        if ds > 0, nt + 0.001 < oldT {
            completedLaps += 1
            if completedLaps >= totalLaps {
                raceFinished = true
                onRaceFinished?(elapsedTime)
            }
        }
        tParam = nt

        if mode.enablesPolice {
            heat = min(5, heat + dt * 0.06 * (speed / max(18, maxSpeed * 0.4)) * city.policeScale)
        }

        updateAI(dt: dt)
        pursuitNearMissCheck()
    }

    private func shortestTDelta(_ from: Float, _ to: Float) -> Float {
        var d = to - from
        if d > 0.5 { d -= 1 }
        if d < -0.5 { d += 1 }
        return d
    }

    private func updateAI(dt: Float) {
        let chaseBoost: Float = 1 + heat * 0.11 + (mode == .policeChase ? 0.18 : 0)
        let trafficMul = city.trafficScale
        let policeMul = city.policeScale
        for i in aiNodes.indices {
            switch aiBehavior[i] {
            case .rivalOrbit:
                let spd = (0.048 + Float(i) * 0.004) * dt * trafficMul
                aiT[i] += spd
                aiT[i] = aiT[i].truncatingRemainder(dividingBy: 1)
                let wobble = Float(sin(CACurrentMediaTime() * 0.7 + Double(i)))
                aiLat[i] += wobble * dt * 0.15
                aiLat[i] = max(-2.2, min(2.2, aiLat[i]))
            case .policeChase:
                let delta = shortestTDelta(aiT[i], tParam)
                let rate = (0.052 * chaseBoost * policeMul) * dt / max(0.35, abs(delta) + 0.12)
                aiT[i] += (delta >= 0 ? 1 : -1) * min(abs(delta), rate)
                aiT[i] = aiT[i].truncatingRemainder(dividingBy: 1)
                if aiT[i] < 0 { aiT[i] += 1 }
                let weave = Float(sin(CACurrentMediaTime() * 2.1 + Double(i))) * 1.1
                let latGoal = lateral + weave
                aiLat[i] += (latGoal - aiLat[i]) * min(1, dt * 3)
                aiLat[i] = max(-3.2, min(3.2, aiLat[i]))
            case .trafficSlow:
                aiT[i] += 0.022 * dt * trafficMul
                aiT[i] = aiT[i].truncatingRemainder(dividingBy: 1)
                aiLat[i] *= 0.995
            }
        }
    }

    private func pursuitNearMissCheck() {
        guard mode.enablesPolice else { return }
        var close = false
        for i in aiNodes.indices where aiBehavior[i] == .policeChase {
            let pt = aiNodes[i].presentation.worldPosition
            let px = carRoot.presentation.worldPosition
            let dx = pt.x - px.x
            let dz = pt.z - px.z
            if (dx * dx + dz * dz) < 28 {
                close = true
                break
            }
        }
        let now = CACurrentMediaTime()
        if close, now - lastNearMissAt > 1.1 {
            lastNearMissAt = now
            nearMissStreak += 1
            driftScore += 420
            heat = min(5, heat + 0.12)
        }
    }

    private func syncTransforms() {
        let tan = track.tangent(at: tParam)
        let right = track.right(at: tParam)
        let base = track.position(at: tParam)
        let pos = base + right * lateral + SIMD3<Float>(0, 0.44, 0)
        carRoot.position = SCNVector3(pos.x, pos.y, pos.z)
        carRoot.eulerAngles.y = atan2(tan.x, tan.z)

        for i in aiNodes.indices {
            let tt = aiT[i]
            let p = track.position(at: tt)
            let tg = track.tangent(at: tt)
            let rg = track.right(at: tt)
            let pp = p + rg * aiLat[i] + SIMD3<Float>(0, 0.44, 0)
            aiNodes[i].position = SCNVector3(pp.x, pp.y, pp.z)
            aiNodes[i].eulerAngles.y = atan2(tg.x, tg.z)
        }
    }

    private func updateCamera(dt: Float) {
        let tan = track.tangent(at: tParam)
        let back = SIMD3<Float>(-tan.x, 0, -tan.z)
        let p = carRoot.presentation.worldPosition
        let blurPull = min(1.2, Float(speedKmh()) / 220)
        let eye = SIMD3<Float>(p.x, p.y, p.z) + back * (12.5 + blurPull) + SIMD3<Float>(0, 4.1 + blurPull * 0.4, 0)
        cameraNode.position = SCNVector3(eye.x, eye.y, eye.z)
        let ahead = SIMD3<Float>(p.x, p.y, p.z) + tan * (7 + blurPull * 1.5) + SIMD3<Float>(0, 0.55, 0)
        cameraNode.look(at: SCNVector3(ahead.x, ahead.y, ahead.z))
    }

    func speedKmh() -> Int {
        Int(abs(speed) * speedScale)
    }
}
