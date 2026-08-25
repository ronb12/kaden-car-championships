import Combine
import Foundation
import SceneKit
import simd
import SwiftUI
import UIKit

final class RaceInput {
    var gas = false
    var brake = false
    var nitro = false
    var handbrake = false
    /// Dedicated reverse pedal / D-pad down / gamepad d-pad down.
    var reverse = false
    var left = false
    var right = false
    /// Analog steer from tilt or gamepad (-1…1). Touch buttons use `left`/`right` when near zero.
    var steer: Float = 0
    var throttle: Float = 0
    var brakeAmount: Float = 0
    var handbrakeAmount: Float = 0
    var shiftUp = false
    var shiftDown = false

    var effectiveSteer: Float {
        let digital: Float = (right ? 1 : 0) - (left ? 1 : 0)
        if abs(digital) > 0.01 {
            return max(-1, min(1, digital * VehicleDrivingPreferences.steerSensitivity))
        }
        if abs(steer) > 0.02 {
            return max(-1, min(1, steer))
        }
        return 0
    }

    var effectiveThrottle: Float {
        max(throttle, gas ? 1 : 0)
    }

    var effectiveBrake: Float {
        max(brakeAmount, brake ? 1 : 0)
    }

    var effectiveHandbrake: Float {
        max(handbrakeAmount, handbrake ? 1 : 0)
    }

    var effectiveReverse: Float {
        reverse ? 1 : 0
    }
}

final class RaceSessionHost: ObservableObject {
    let input = RaceInput()
    let engine: NativeRaceEngine
    private var engineBag: AnyCancellable?

    init(
        carColor: UIColor,
        carId: String,
        lapCount: Int,
        mode: GameModeKind,
        stats: CarRuntimeStats,
        city: CityRuntimeConfig,
        nightOverride: Bool,
        vehicleCategory: VehicleCategory,
        difficultyGripMul: Float = 1,
        difficultyIndex: Int = 1,
        playerCarIndex: Int = 0,
        onlineContext: RaceOnlineContext? = nil,
        pursuitSuspectCount: Int? = nil,
        pursuitTimeLimit: TimeInterval? = nil,
        pursuitRoadblocks: Bool = false,
        ghostTrackKey: String? = nil,
        courierConfig: CourierSessionConfig = CourierSessionConfig()
    ) {
        engine = NativeRaceEngine(
            input: input,
            carColor: carColor,
            carId: carId,
            lapCount: lapCount,
            mode: mode,
            stats: stats,
            city: city,
            nightOverride: nightOverride,
            vehicleCategory: vehicleCategory,
            difficultyGripMul: difficultyGripMul,
            difficultyIndex: difficultyIndex,
            playerCarIndex: playerCarIndex,
            onlineContext: onlineContext,
            pursuitSuspectCount: pursuitSuspectCount,
            pursuitTimeLimit: pursuitTimeLimit,
            pursuitRoadblocks: pursuitRoadblocks,
            ghostTrackKey: ghostTrackKey,
            courierConfig: courierConfig
        )
        // Forward engine @Published changes so SwiftUI (dispatch board, HUD) actually refreshes.
        engineBag = engine.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

struct RaceOnlineContext {
    let carId: String
    let carName: String
    let colorInt: UInt32
    let cityThemeIndex: Int
    let trackIndex: Int
    let trackKey: String
    let mode: String
}

struct CourierSessionConfig {
    var careerMul: Float = 1
    var cargoCapacity: Int = 1
    var nightPremium: Bool = false
    var timeBonus: TimeInterval = 0
    var jobGoal: Int = 3
    var timeLimit: TimeInterval = 120
    var autoPickFirst: Bool = true

    static func from(progress: PlayerProgressStore, nightRace: Bool) -> CourierSessionConfig {
        let rank = progress.courierRank
        return CourierSessionConfig(
            careerMul: rank.payoutMul,
            cargoCapacity: rank.cargoCapacity,
            nightPremium: nightRace,
            timeBonus: rank.timeBonusSeconds,
            jobGoal: 3,
            timeLimit: 120,
            autoPickFirst: true
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
    private let difficultyGripMul: Float
    private let difficultyIndex: Int
    private let playerCarIndex: Int
    private let carColor: UIColor
    private let carId: String
    private var opponents: RaceOpponentController?
    private let onlineContext: RaceOnlineContext?
    private let audio = RaceAudioController()

    private weak var view: SCNView?
    private var scene = SCNScene()
    private var carNode = SCNNode()
    private var cameraNode = SCNNode()
    private var rearCameraNode = SCNNode()
    /// Player mesh only — rear-view camera excludes this bit so the bumper doesn't fill the mirror.
    static let playerVisualCategory = 1 << 1
    private var trackQuery: TrackWorldQuery!
    private var openWorld = OpenWorldDrivingSimulation.State()
    private var openWorldSim = OpenWorldDrivingSimulation()
    private var maxWorldSpeed: Float = 35
    /// Reference top speed (km/h) at `topSpeedMul == 1.0`. Car stats scale around this.
    private static let referenceTopSpeedKmh: Float = 232
    /// Hard HUD ceiling including nitro / arcade boosts.
    private static let hardCapTopSpeedKmh: Float = 288
    private var gameController = VehicleGameControllerInput()
    private var lastHapticImpact: Float = 0
    private var lastTime: TimeInterval = 0
    private var startTime = Date()
    private var countdownElapsed: Float = 0
    private var didReleaseStartGrid = false
    private var didShowFinishSign = false
    private var lightsRemaining = 3
    private var paused = false
    private var finished = false
    private var nitro: Float = 1
    private var wasNitroOn = false
    private var heat: Float = 0
    private var damage: Float = 0
    private var lastRewardBreakdown: (base: Int64, position: Int64, heat: Int64, arcade: Int64) = (0, 0, 0, 0)
    private var cameraRig = EnvironmentCameraRig()
    private var smoothedRideY: Float = 0
    private var smoothedBodyPitch: Float = 0
    private var smoothedBodyRoll: Float = 0
    private var raceWeather: EnvironmentLightingSystem.WeatherMode = .day
    private var raceQuality: GraphicsQuality = .high
    private var cameraPostConfigured = false
    private let arcadeFun = RaceArcadeFunSystem()
    private let courier = CourierDeliverySystem()
    private var _courierSnapshot = CourierDeliverySystem.Snapshot()
    private let ghostController = RaceGhostController()
    private let pursuitSuspectCountOverride: Int?
    private let pursuitTimeLimitOverride: TimeInterval?
    private let pursuitRoadblocksEnabled: Bool
    private let ghostTrackKey: String?
    private let courierConfig: CourierSessionConfig
    private var roadblockRoot: SCNNode?
    private var flashbackBuffer: [RaceGhostSample] = []
    private var flashbackSpeeds: [Float] = []
    private var flashbackLaps: [Int] = []
    private var flashbackCharges: Int = 3
    private let flashbackWindow: Float = 2.5
    /// Seconds spent anti-flow before WRONG WAY shows (and decays when corrected).
    private var wrongWayTimer: Float = 0
    private var _wrongWayLatched = false
    /// Hot Pursuit interceptor: seconds to bust all suspects.
    private static let hotPursuitTimeLimit: TimeInterval = 180

    @Published var elapsedTime: TimeInterval = 0
    /// 3…2…1…0 (GO)…-1 (green flag). Cars stay frozen on the grid until -1.
    @Published private(set) var startLight: Int = 3
    @Published var displayLapIndex = 1
    @Published var driftScore: Int64 = 0
    @Published var racePosition: Int = 1
    @Published var racerCount: Int = 1
    @Published var arcadeCrystals: Int = 0
    @Published var arcadeCrystalTotal: Int = 0
    @Published var arcadeObjective: String = ""
    @Published var arcadeObjectiveProgress: Float = 0
    @Published var arcadeObjectiveComplete: Bool = false
    @Published var arcadeToast: String? = nil
    @Published var arcadeDraftActive: Bool = false
    @Published var arcadeDriftZoneActive: Bool = false
    @Published var wrongWayActive: Bool = false
    @Published var pursuitBusts: Int = 0
    @Published var pursuitBustGoal: Int = 4
    @Published var catchTimeRemaining: TimeInterval = 180
    @Published var pursuitOutcome: String? = nil
    @Published var latestTicket: RaceOpponentController.SpeedingTicket? = nil
    @Published private(set) var issuedTickets: [RaceOpponentController.SpeedingTicket] = []
    @Published var courierDeliveries: Int = 0
    @Published var courierGoal: Int = 6
    @Published var courierTimeRemaining: TimeInterval = 210
    @Published var courierCarrying: Bool = false
    @Published var courierDistance: Float = 0
    @Published var courierBearing: Float = 0
    @Published var courierDwell: Float = 0
    @Published var courierInZone: Bool = false
    @Published var courierEarned: Int64 = 0
    @Published var courierNextPayout: Int64 = 0
    @Published var courierStreak: Int = 0
    @Published var courierUrgency: Bool = false
    @Published var courierAwaitingJobChoice: Bool = false
    @Published var courierJobOffers: [CourierDeliverySystem.JobOffer] = []
    @Published var courierPackageKind: CourierPackageKind = .standard
    @Published var courierRivalThreat: Float = 0
    @Published var courierCargoHeld: Int = 0
    @Published var courierCargoCapacity: Int = 1
    @Published var courierNightPremium: Bool = false
    @Published var courierShiftGrade: String = ""
    let lapGoal: Int
    var onRaceFinished: ((TimeInterval) -> Void)?
    private(set) var houseGhostDelta: TimeInterval?
    private(set) var hadHouseGhost = false

    // Backing vars mutated on the SceneKit render thread; flushed to @Published on main.
    private var _lapIndex: Int = 1
    private var _driftAccumulator: Int64 = 0
    private var _arcadeSnapshot = RaceArcadeFunSystem.Snapshot()

    init(
        input: RaceInput,
        carColor: UIColor,
        carId: String,
        lapCount: Int,
        mode: GameModeKind,
        stats: CarRuntimeStats,
        city: CityRuntimeConfig,
        nightOverride: Bool,
        vehicleCategory: VehicleCategory,
        difficultyGripMul: Float = 1,
        difficultyIndex: Int = 1,
        playerCarIndex: Int = 0,
        onlineContext: RaceOnlineContext? = nil,
        pursuitSuspectCount: Int? = nil,
        pursuitTimeLimit: TimeInterval? = nil,
        pursuitRoadblocks: Bool = false,
        ghostTrackKey: String? = nil,
        courierConfig: CourierSessionConfig = CourierSessionConfig()
    ) {
        self.input = input
        self.carColor = carColor
        self.carId = carId
        self.lapGoal = max(1, lapCount)
        self.mode = mode
        self.stats = stats
        self.city = city
        self.nightOverride = nightOverride
        self.vehicleCategory = vehicleCategory
        self.difficultyGripMul = difficultyGripMul
        self.difficultyIndex = min(max(difficultyIndex, 0), 2)
        self.playerCarIndex = playerCarIndex
        self.onlineContext = onlineContext
        self.pursuitSuspectCountOverride = pursuitSuspectCount
        self.pursuitTimeLimitOverride = pursuitTimeLimit
        self.pursuitRoadblocksEnabled = pursuitRoadblocks
        self.ghostTrackKey = ghostTrackKey
        self.courierConfig = courierConfig
        super.init()
    }

    func attach(to view: SCNView) {
        self.view = view
        buildScene()
        view.scene = scene
        view.delegate = self
        view.pointOfView = cameraNode
        audio.configure(cityThemeId: city.themeId, vehicleCategory: vehicleCategory)
        audio.prepare()
        audio.beginRaceIntro()
        startTime = Date()
        #if DEBUG
        if RaceQAAutopilot.enabled {
            startLight = -1
            lightsRemaining = -1
            didReleaseStartGrid = true
            didShowFinishSign = true
            RaceTrackMesh.setStartFinishSignPhase(.finish, in: scene.rootNode)
        } else {
            didShowFinishSign = false
            RaceTrackMesh.setStartFinishSignPhase(.start, in: scene.rootNode)
        }
        #else
        didShowFinishSign = false
        RaceTrackMesh.setStartFinishSignPhase(.start, in: scene.rootNode)
        #endif
    }

    func raceScene() -> SCNScene { scene }

    func rearViewPointOfView() -> SCNNode { rearCameraNode }

    private func installRearViewCamera() {
        carNode.enumerateHierarchy { node, _ in
            node.categoryBitMask = Self.playerVisualCategory
        }
        rearCameraNode.childNodes.forEach { $0.removeFromParentNode() }
        rearCameraNode.removeFromParentNode()
        let cam = SCNCamera()
        cam.fieldOfView = 62
        cam.zNear = 0.9
        cam.zFar = 240
        cam.categoryBitMask = ~Self.playerVisualCategory
        rearCameraNode.camera = cam
        rearCameraNode.name = "krcRearViewCamera"
        // Camera looks along local −Z, which is the car's rear after heading alignment.
        rearCameraNode.position = SCNVector3(0, 1.28, -0.42)
        rearCameraNode.eulerAngles = SCNVector3(0.1, 0, 0)
        carNode.addChildNode(rearCameraNode)
    }

    func setPaused(_ paused: Bool) {
        self.paused = paused
        if paused {
            audio.suspend()
            gameController.stop()
        } else {
            if audio.needsPrepare {
                audio.prepare()
            } else {
                audio.resume()
            }
            gameController.start(updating: input)
        }
    }

    /// GRID-style flashback — rewind ~2.5s using the live tape buffer.
    @discardableResult
    func performFlashback() -> Bool {
        guard flashbackCharges > 0, flashbackBuffer.count >= 8 else { return false }
        let targetElapsed = max(0, (flashbackBuffer.last?.elapsed ?? 0) - flashbackWindow)
        var idx = 0
        for i in flashbackBuffer.indices where flashbackBuffer[i].elapsed <= targetElapsed {
            idx = i
        }
        let sample = flashbackBuffer[idx]
        openWorld.worldX = sample.worldX
        openWorld.worldZ = sample.worldZ
        openWorld.heading = sample.heading
        openWorld.trackT = sample.trackT
        openWorld.speed = idx < flashbackSpeeds.count ? flashbackSpeeds[idx] * 0.55 : openWorld.speed * 0.4
        openWorld.driftYaw = 0
        openWorld.impactImpulse = 0
        if idx < flashbackLaps.count {
            _lapIndex = max(1, flashbackLaps[idx])
            DispatchQueue.main.async { [weak self] in
                self?.displayLapIndex = self?._lapIndex ?? 1
            }
        }
        carNode.position = SCNVector3(sample.worldX, sample.worldY, sample.worldZ)
        carNode.eulerAngles = SCNVector3(0, sample.heading, 0)
        flashbackCharges -= 1
        flashbackBuffer.removeAll(keepingCapacity: true)
        flashbackSpeeds.removeAll(keepingCapacity: true)
        flashbackLaps.removeAll(keepingCapacity: true)
        if KRCAudioPreferences.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        return true
    }

    func flashbackAvailable() -> Bool {
        flashbackCharges > 0 && flashbackBuffer.count >= 8
    }

    func flashbackChargesRemaining() -> Int { flashbackCharges }

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if lastTime == 0 { lastTime = time }
        let dt = min(1.0 / 30.0, max(0, time - lastTime))
        lastTime = time
        guard !paused, !finished else { return }
        AutomotiveReflectionSystem.update(renderer: renderer, atTime: time)
        let step = Float(dt)
        if holdStartGrid(dt: step) {
            placeCar(dt: step)
            syncOnlinePresence(dt: step)
            return
        }
        updatePhysics(dt: step)
    }

    /// Freeze every car on the start grid through 3-2-1-GO.
    private func holdStartGrid(dt: Float) -> Bool {
        guard lightsRemaining >= 0, !didReleaseStartGrid else { return false }
        openWorld.speed = 0
        resetRaceInput()
        countdownElapsed += dt
        let beat: Float = lightsRemaining == 0 ? 0.70 : 1.20
        if countdownElapsed >= beat {
            countdownElapsed = 0
            lightsRemaining -= 1
            let next = lightsRemaining
            let released = next < 0
            if released {
                didReleaseStartGrid = true
                startTime = Date()
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.startLight = next
                self.elapsedTime = 0
                if next >= 0 { KRCUISounds.playClick() }
                if released {
                    KRCMusicDirector.shared.play(.race, crossfade: 0.35)
                }
            }
        }
        return true
    }

    /// Gantry reads FINISH only after the whole field has cleared the start line — not at green flag.
    private func updateStartFinishSignIfNeeded() {
        guard !didShowFinishSign, didReleaseStartGrid else { return }
        let threshold = RaceOpponentController.startLineCrossThreshold
        let playerPast = _lapIndex > 1 || openWorld.trackT >= threshold
        guard playerPast else { return }
        if let opponents, !opponents.allGridCarsPastStartLine(playerLap: _lapIndex, playerTrackT: openWorld.trackT) {
            return
        }
        didShowFinishSign = true
        RaceTrackMesh.setStartFinishSignPhase(.finish, in: scene.rootNode)
    }

    func speedKmh() -> Int {
        Int(abs(openWorld.speed) * OpenWorldDrivingSimulation.worldUnitsToKmh)
    }

    func isReversing() -> Bool { openWorld.speed < -0.001 }
    func nitroMeter() -> Float { nitro }
    func heatMeter() -> Float { heat }
    func damageMeter() -> Float { damage }
    func isHotPursuitInterceptor() -> Bool { mode == .policeChase }
    func isCourierRun() -> Bool { mode == .courier }
    func catchTimeDisplay() -> TimeInterval {
        if mode == .courier { return max(0, courierTimeRemaining) }
        return max(0, catchTimeRemaining)
    }
    func ticketFinesTotal() -> Int64 {
        issuedTickets.reduce(0) { $0 + $1.fineCredits }
    }
    func driftMultiplierDisplay() -> Float { openWorld.driftMultiplier }
    func arcadeBonusCredits() -> Int64 {
        if mode == .courier {
            return courier.finishBonusCredits()
        }
        return arcadeFun.finishBonusCredits()
    }

    func selectCourierOffer(id: Int) {
        courier.selectOffer(id: id)
        let snap = courier.snapshot
        _courierSnapshot = snap
        if Thread.isMainThread {
            publishCourierSnapshot(snap)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.publishCourierSnapshot(snap)
            }
        }
    }

    func courierGradeLabel() -> String { _courierSnapshot.gradeLabel }
    func lastCreditsEarned() -> Int64 {
        lastRewardBreakdown.base + lastRewardBreakdown.position + lastRewardBreakdown.heat + lastRewardBreakdown.arcade
    }
    func rewardBreakdown() -> (base: Int64, position: Int64, heat: Int64, arcade: Int64) { lastRewardBreakdown }
    func rpmNormalized() -> Float { openWorld.rpm }
    func gearDisplay() -> Int { openWorld.gear }
    func isReversingGear() -> Bool { openWorld.gear == 0 }
    func shiftNotice() -> String? { openWorldSim.shiftNotice }
    func isShiftZone() -> Bool { openWorldSim.isShiftZone }
    func trackProgressNormalized() -> Float { openWorld.trackT }

    private func buildScene() {
        trackQuery = TrackWorldQuery(track: city.track)
        let envKey = RaceEnvironmentPreloader.cacheKey(city: city, nightOverride: nightOverride)
        if let prepared = RaceEnvironmentPreloader.takePrepared(for: envKey) {
            scene = prepared.scene
            raceWeather = prepared.weather
            raceQuality = prepared.quality
        } else {
            scene = SCNScene()
            let built = RacingEnvironmentPipeline.build(
                scene: scene,
                city: city,
                nightOverride: nightOverride,
                cameraNode: cameraNode
            )
            raceWeather = built.weather
            raceQuality = built.quality
        }
        cameraPostConfigured = false

        carNode = SCNNode()
        RaceCarGeometry.build(root: carNode, bodyColor: carColor, carId: carId, isPlayer: true, category: vehicleCategory)
        updateVehicleLights()
        carNode.castsShadow = false
        #if targetEnvironment(simulator)
        var geoCount = 0
        var visibleGeo = 0
        var bundled = false
        var sampleNames: [String] = []
        carNode.enumerateHierarchy { node, _ in
            node.castsShadow = false
            if node.name == "krcBundledContainer" { bundled = true }
            guard let geometry = node.geometry else { return }
            geoCount += 1
            // Keep race cars in the default render band — high renderingOrder was sorting
            // USDZ shells incorrectly against the road on Simulator Metal.
            node.renderingOrder = 0
            node.isHidden = false
            node.opacity = 1
            if !node.isHidden { visibleGeo += 1 }
            if sampleNames.count < 8 {
                let mat = geometry.materials.first?.name ?? "-"
                sampleNames.append("\(node.name ?? "?")/\(mat)")
            }
        }
        carNode.renderingOrder = 0
        carNode.isHidden = false
        carNode.opacity = 1
        carNode.scale = SCNVector3(1, 1, 1)
        // Sim Metal draws SCNBox/SCNSphere but drops nested USDZ triangle soups.
        // VehicleRenderer installs a Sketchfab-proportioned proxy from the loaded bounds.
        let (mn, mx) = carNode.boundingBox
        NSLog(
            "[NativeRaceEngine] player carId=%@ geos=%d visible=%d bundledUSDZ=%@ bbox=(%.2f,%.2f,%.2f)-(%.2f,%.2f,%.2f) samples=%@",
            carId, geoCount, visibleGeo, bundled ? "yes" : "no",
            mn.x, mn.y, mn.z, mx.x, mx.y, mx.z,
            sampleNames.joined(separator: ", ")
        )
        #else
        var geoCount = 0
        var visibleGeo = 0
        carNode.enumerateHierarchy { node, _ in
            node.isHidden = false
            node.opacity = 1
            node.castsShadow = false
            node.renderingOrder = 0
            guard let geometry = node.geometry else { return }
            geoCount += 1
            for mat in geometry.materials {
                // Hard guarantee: solid race materials stay opaque on device.
                if mat.transparency < 0.99 { mat.transparency = 1 }
                mat.blendMode = .alpha
                mat.transparent.contents = nil
            }
            if !node.isHidden { visibleGeo += 1 }
        }
        carNode.renderingOrder = 0
        carNode.isHidden = false
        carNode.opacity = 1
        carNode.scale = SCNVector3(1, 1, 1)
        let (mn, mx) = carNode.boundingBox
        NSLog(
            "[NativeRaceEngine] DEVICE player carId=%@ geos=%d visible=%d bbox=(%.2f,%.2f,%.2f)-(%.2f,%.2f,%.2f)",
            carId, geoCount, visibleGeo,
            mn.x, mn.y, mn.z, mx.x, mx.y, mx.z
        )
        #endif
        scene.rootNode.addChildNode(carNode)
        installRearViewCamera()
        AutomotiveReflectionSystem.bindScene(scene, to: carNode)

        if shouldSpawnOpponents {
            let slots: [VehicleSpawnPlanner.OpponentSlot]
            let pursuit: Bool
            let ghost: Bool
            switch mode {
            case .policeChase:
                let count = max(2, pursuitSuspectCountOverride ?? 4)
                slots = VehicleSpawnPlanner.planFleeingSuspects(count: count)
                pursuit = false
                ghost = false
            case .ghostDuel:
                slots = VehicleSpawnPlanner.planGhostRivals(playerCarIndex: playerCarIndex, count: 2)
                pursuit = false
                ghost = true
            case .career:
                slots = VehicleSpawnPlanner.planOpponents(playerCarIndex: playerCarIndex, count: 3, playerBodyColor: carColor)
                pursuit = false
                ghost = false
            case .courier:
                slots = VehicleSpawnPlanner.planOpponents(playerCarIndex: playerCarIndex, count: 2, playerBodyColor: carColor)
                pursuit = false
                ghost = false
            default:
                slots = VehicleSpawnPlanner.planOpponents(playerCarIndex: playerCarIndex, count: 4, playerBodyColor: carColor)
                pursuit = false
                ghost = false
            }
            let grid = RaceOpponentController(
                track: city.track,
                playerCarIndex: playerCarIndex,
                opponentCount: slots.count,
                slots: slots
            )
            grid.pursuitMode = pursuit
            grid.fleeMode = (mode == .policeChase)
            grid.ghostMode = ghost
            grid.spawn(into: scene.rootNode, playerCarIndex: playerCarIndex, count: slots.count)
            opponents = grid
            if mode == .policeChase {
                pursuitBustGoal = slots.count
                pursuitBusts = 0
                catchTimeRemaining = pursuitTimeLimitOverride ?? Self.hotPursuitTimeLimit
                issuedTickets = []
                latestTicket = nil
                if pursuitRoadblocksEnabled {
                    installPursuitRoadblocks()
                }
            }
        }

        // Local PB ghost for Ghost Duel / Time Trial. House ghost (last run on this device) on circuit / career.
        if mode == .ghostDuel || mode == .timeTrial {
            let key = ghostTrackKey
                ?? RaceGhostTape.trackKey(trackIndex: city.catalogTrackIndex ?? playerCarIndex, laps: lapGoal)
            let tape = RaceGhostStore.load(trackKey: key) ?? HouseGhostStore.load(trackKey: key)
            ghostController.attachPlaybackGhost(
                tape: tape,
                into: scene.rootNode,
                bodyColor: UIColor(red: 0.35, green: 0.9, blue: 1, alpha: 1)
            )
            ghostController.beginRecording()
        } else if mode == .circuit || mode == .career {
            let key = ghostTrackKey
                ?? RaceGhostTape.trackKey(trackIndex: city.catalogTrackIndex ?? playerCarIndex, laps: lapGoal)
            let tape = HouseGhostStore.load(trackKey: key)
            ghostController.attachPlaybackGhost(
                tape: tape,
                into: scene.rootNode,
                bodyColor: UIColor(red: 0.35, green: 0.9, blue: 1, alpha: 1)
            )
            ghostController.beginRecording()
        }

        let seed = SeededRandom.layoutSeed(theme: city.themeId, trackIndex: playerCarIndex, lapCount: lapGoal)
        if mode == .courier {
            courier.attach(
                to: scene.rootNode,
                track: city.track,
                seed: seed ^ 0xC0DE51,
                goal: courierConfig.jobGoal,
                timeLimit: courierConfig.timeLimit,
                careerMul: courierConfig.careerMul,
                cargoCapacity: courierConfig.cargoCapacity,
                nightPremium: courierConfig.nightPremium,
                timeBonus: courierConfig.timeBonus,
                autoPickFirst: courierConfig.autoPickFirst
            )
            courier.bindCar(carNode)
            _courierSnapshot = courier.snapshot
            publishCourierSnapshot(_courierSnapshot)
        } else {
            arcadeFun.attach(to: scene.rootNode, track: city.track, trackQuery: trackQuery, seed: seed)
            _arcadeSnapshot = arcadeFun.snapshot
        }

        Task { @MainActor in
            KRCOnlineService.shared.beginRaceSession(scene: scene, root: scene.rootNode)
            if let ctx = onlineContext, KRCPlayerProfile.onlinePlayEnabled {
                Task { @MainActor in
                    await KRCOnlineService.shared.recordGlobalPlayStart(
                        mode: ctx.mode,
                        trackKey: ctx.trackKey,
                        trackName: GameCatalog.track(at: ctx.trackIndex).name
                    )
                }
            }
        }

        if cameraNode.camera == nil {
            cameraNode.camera = SCNCamera()
        }
        scene.rootNode.addChildNode(cameraNode)
        cameraRig.initialized = false
        // Base world speed; each car's topSpeedMul spreads the roster (~210–250 km/h).
        // worldUnitsToKmh is tuned so this also *looks* fast on Palm City track scale.
        maxWorldSpeed = Self.referenceTopSpeedKmh / OpenWorldDrivingSimulation.worldUnitsToKmh
        logCarSpeedQA()
        _lapIndex = 1
        _driftAccumulator = 0
        wrongWayTimer = 0
        _wrongWayLatched = false
        DispatchQueue.main.async { [weak self] in
            self?.wrongWayActive = false
        }
        resetRaceInput()
        let startT: Float = 0
        let startP = city.track.sample(startT)
        let startTan = city.track.tangent(startT)
        let startRight = city.track.right(at: startT)
        let poleLane = -(RaceTrackMesh.halfWidth * 0.22)
        openWorld.worldX = startP.x + startRight.x * poleLane
        openWorld.worldZ = startP.z + startRight.z * poleLane
        openWorld.heading = atan2(startTan.x, startTan.z)
        openWorld.speed = 0
        openWorld.trackT = 0
        openWorldSim.reset(at: startP, heading: openWorld.heading)
        smoothedRideY = startP.y + 0.37
        smoothedBodyPitch = 0
        smoothedBodyRoll = 0
        #if DEBUG
        RaceQAAutopilot.reset()
        #endif
        gameController.start(updating: input)
        configureRaceCameraPost(speedRatio: 0)
        updateVehicleLights()
        placeCar(dt: 0)
        #if targetEnvironment(simulator)
        let cp = carNode.position
        let kp = cameraNode.position
        let (lmin, lmax) = carNode.boundingBox
        let c0 = carNode.convertPosition(SCNVector3(lmin.x, lmin.y, lmin.z), to: nil)
        let c1 = carNode.convertPosition(SCNVector3(lmax.x, lmax.y, lmax.z), to: nil)
        NSLog(
            "[NativeRaceEngine] place0 car=(%.2f,%.2f,%.2f) cam=(%.2f,%.2f,%.2f) worldY=[%.2f…%.2f] height=%.2f heading=%.2f",
            cp.x, cp.y, cp.z, kp.x, kp.y, kp.z,
            min(c0.y, c1.y), max(c0.y, c1.y), abs(c1.y - c0.y), openWorld.heading
        )
        #endif
    }

    private func configureRaceCameraPost(speedRatio: Float) {
        guard let cam = cameraNode.camera, !cameraPostConfigured else { return }
        let preset = EnvironmentGraphicsSettings.preset(for: raceQuality)
        cam.zNear = 0.35
        cam.zFar = max(Double(preset.maxDrawDistance) * 1.6, 1100)
        cam.categoryBitMask = Int.max
        if MinimalRaceEnvironment.isEnabled {
            MinimalRaceEnvironment.configureCamera(
                cam,
                quality: raceQuality,
                night: nightOverride || city.visualNight
            )
        } else {
            EnvironmentPostProcessing.configure(
                camera: cam,
                weather: raceWeather,
                quality: raceQuality,
                speedRatio: speedRatio
            )
        }
        cameraPostConfigured = true
    }

    /// Multi-car grid for standard race modes (not endless solo).
    /// Online ghosts are extra visuals — CPU still fills these slots.
    private var shouldSpawnOpponents: Bool {
        switch mode {
        case .endless:
            return false
        case .courier:
            return true
        default:
            return lapGoal < 500
        }
    }

    private func resetRaceInput() {
        input.gas = false
        input.brake = false
        input.nitro = false
        input.handbrake = false
        input.reverse = false
        input.left = false
        input.right = false
        input.steer = 0
        input.throttle = 0
        input.brakeAmount = 0
        input.handbrakeAmount = 0
        input.shiftUp = false
        input.shiftDown = false
    }

    private func updatePhysics(dt: Float) {
        guard trackQuery != nil else { return }
        #if DEBUG
        // Manual drive unless the process was launched with `-qaDrive` / RACE_QA_DRIVE=1.
        let qaDrive = RaceQAAutopilot.enabled
        #else
        let qaDrive = false
        #endif
        if !qaDrive {
            gameController.poll(into: input)
        }
        let nitroOn = input.nitro && nitro > 0.02
        let projection = trackQuery.project(x: openWorld.worldX, z: openWorld.worldZ)
        #if DEBUG
        if qaDrive {
            RaceQAAutopilot.apply(
                input: input,
                state: &openWorld,
                track: city.track,
                trackQuery: trackQuery,
                projection: projection,
                maxSpeed: maxWorldSpeed,
                dt: dt
            )
        }
        #endif

        let arcadeMods: (gripMul: Float, speedMul: Float, driftScoreMul: Float)
        if mode == .courier {
            courier.update(
                dt: dt,
                worldX: openWorld.worldX,
                worldZ: openWorld.worldZ,
                worldY: carNode.position.y,
                heading: openWorld.heading,
                speed: openWorld.speed,
                impact: openWorld.impactImpulse
            )
            _courierSnapshot = courier.snapshot
            arcadeMods = (1, _courierSnapshot.speedMul, 1)
        } else {
            arcadeMods = arcadeFun.update(
                dt: dt,
                worldX: openWorld.worldX,
                worldZ: openWorld.worldZ,
                heading: openWorld.heading,
                trackT: openWorld.trackT,
                speed: openWorld.speed,
                isDrifting: openWorld.isDrifting,
                nitro: &nitro,
                opponents: opponents
            )
            _arcadeSnapshot = arcadeFun.snapshot
            let bump = arcadeFun.consumeTrackBump()
            if bump > 0 {
                openWorld.trackT = (openWorld.trackT + bump).truncatingRemainder(dividingBy: 1)
                let sample = city.track.sample(openWorld.trackT)
                openWorld.worldX = sample.x
                openWorld.worldZ = sample.z
            }
        }

        var trackGrip = trackQuery.gripMultiplier(signedLateralDistance: projection.signedLateral)
        trackGrip *= VehicleSurfaceGrip.multiplier(
            terrain: city.definition.terrain,
            weather: raceWeather,
            lateral: projection.signedLateral,
            maxLateral: RaceTrackMesh.halfWidth
        )
        let corner = VehicleCornering.severity(track: city.track, t: openWorld.trackT)
        trackGrip *= max(0.74, 1 - corner * 0.22)
        trackGrip *= arcadeMods.gripMul
        let sample = OpenWorldDrivingSimulation.InputSample(
            throttle: input.effectiveThrottle,
            brake: input.effectiveBrake,
            steer: input.effectiveSteer,
            handbrake: input.effectiveHandbrake,
            nitro: nitroOn,
            shiftUp: input.shiftUp,
            shiftDown: input.shiftDown,
            reverse: input.effectiveReverse
        )
        let hardCapWorld = Self.hardCapTopSpeedKmh / OpenWorldDrivingSimulation.worldUnitsToKmh
        let config = OpenWorldDrivingSimulation.Config(
            stats: stats,
            difficultyGripMul: difficultyGripMul,
            category: vehicleCategory,
            trackGrip: trackGrip,
            maxWorldSpeed: min(maxWorldSpeed * arcadeMods.speedMul, hardCapWorld),
            clampProfile: mode == .courier ? .district : .circuit
        )
        let previousT = openWorld.trackT
        openWorldSim.step(
            state: &openWorld,
            input: sample,
            config: config,
            trackQuery: trackQuery,
            dt: dt
        )
        // Soft hard-cap so nitro can't blow past the race ceiling.
        let damageDrag = 1 - min(0.35, damage * 0.35 / max(0.5, stats.durabilityMul))
        // Endless escape heat bleeds speed; interceptor Hot Pursuit uses lock meter instead.
        let heatDrag: Float = (mode == .endless) ? (1 - heat * 0.12) : 1
        let cappedTop = hardCapWorld * damageDrag * heatDrag
        if openWorld.speed > cappedTop {
            openWorld.speed = cappedTop
        } else if openWorld.speed < -cappedTop * 0.32 {
            openWorld.speed = -cappedTop * 0.32
        }
        collideWithHumanRacers()
        // Impact damage — durability softens the hit.
        if openWorld.impactImpulse > 0.35 {
            let hit = openWorld.impactImpulse * 0.08 / max(0.55, stats.durabilityMul)
            damage = min(1, damage + hit)
            if mode == .endless {
                heat = min(1, heat + hit * 0.35)
            }
        }
        let shiftNitro = openWorldSim.consumeShiftNitroBoost()
        if shiftNitro > 0 {
            nitro = min(1, nitro + shiftNitro)
        }
        RaceCarGeometry.setBrakeLights(root: carNode, amount: openWorld.brakeGlow)
        updateVehicleLights()
        if nitroOn {
            if !wasNitroOn { KRCUISounds.playHorn() }
            nitro = max(0, nitro - 0.22 * dt * (1 / max(0.5, stats.nitroCapacityMul)))
        } else {
            nitro = min(1, nitro + 0.06 * stats.nitroRefillMul * dt)
        }
        wasNitroOn = nitroOn
        if mode == .endless {
            // Heat rises with speed and time — high heat bleeds top speed (see damageDrag/heatDrag).
            let speedHeat = min(1, abs(openWorld.speed) / max(0.001, maxWorldSpeed))
            heat = min(1, heat + (0.014 + speedHeat * 0.02) * dt * city.policeScale)
            if heat >= 0.98 {
                heat = 1
            }
        }
        _driftAccumulator += Int64(openWorld.driftScoreRate * dt * arcadeMods.driftScoreMul)

        let prevNorm = previousT.truncatingRemainder(dividingBy: 1)
        let currNorm = openWorld.trackT.truncatingRemainder(dividingBy: 1)
        let forwardOnTrack = trackQuery.isHeadingWithTrack(
            heading: openWorld.heading,
            projection: projection,
            speed: openWorld.speed
        )
        // Wrong-way cue — skip free-district courier (no circuit direction).
        if mode != .courier {
            let against = trackQuery.isHeadingAgainstTrack(
                heading: openWorld.heading,
                projection: projection,
                speed: openWorld.speed
            )
            if against {
                wrongWayTimer = min(2.5, wrongWayTimer + dt)
            } else {
                wrongWayTimer = max(0, wrongWayTimer - dt * 2.2)
            }
            _wrongWayLatched = wrongWayTimer > 0.7
        } else {
            wrongWayTimer = 0
            _wrongWayLatched = false
        }
        // Hot Pursuit / Courier end on objectives / timer — not lap count.
        if mode != .policeChase, mode != .courier, forwardOnTrack && prevNorm > 0.88 && currNorm < 0.12 {
            _lapIndex += 1
            if _lapIndex > lapGoal {
                finish()
                return
            }
        }
        placeCar(dt: dt)
        let elapsedNow = Float(Date().timeIntervalSince(startTime))
        ghostController.record(
            elapsed: elapsedNow,
            trackT: openWorld.trackT,
            worldX: openWorld.worldX,
            worldY: carNode.position.y,
            worldZ: openWorld.worldZ,
            heading: openWorld.heading,
            dt: dt
        )
        ghostController.updatePlayback(elapsed: elapsedNow)
        // Live flashback ring buffer (~2.5s).
        flashbackBuffer.append(
            RaceGhostSample(
                elapsed: elapsedNow,
                trackT: openWorld.trackT,
                worldX: openWorld.worldX,
                worldY: carNode.position.y,
                worldZ: openWorld.worldZ,
                heading: openWorld.heading
            )
        )
        flashbackSpeeds.append(openWorld.speed)
        flashbackLaps.append(_lapIndex)
        while let first = flashbackBuffer.first, elapsedNow - first.elapsed > flashbackWindow + 0.35 {
            flashbackBuffer.removeFirst()
            if !flashbackSpeeds.isEmpty { flashbackSpeeds.removeFirst() }
            if !flashbackLaps.isEmpty { flashbackLaps.removeFirst() }
        }
        opponents?.update(
            dt: dt,
            playerTrackT: openWorld.trackT,
            playerLap: _lapIndex,
            playerTopLapSpeed: maxWorldSpeed * stats.topSpeedMul,
            playerWorldSpeed: openWorld.speed,
            playerMaxWorldSpeed: maxWorldSpeed * stats.topSpeedMul,
            playerWorldX: openWorld.worldX,
            playerWorldZ: openWorld.worldZ,
            playerHeading: openWorld.heading,
            difficultyIndex: difficultyIndex,
            lapGoal: lapGoal,
            headlightLevel: VehicleLighting.headlightLevel(
                weather: raceWeather,
                nightOverride: nightOverride,
                visualNight: city.visualNight
            )
        )
        updateStartFinishSignIfNeeded()

        if mode == .policeChase {
            let newTickets = opponents?.processInterceptorBusts(
                playerWorldX: openWorld.worldX,
                playerWorldZ: openWorld.worldZ
            ) ?? []
            if !newTickets.isEmpty {
                let total = opponents?.bustCount ?? pursuitBusts
                let ticketFines = newTickets.reduce(Int64(0)) { $0 + $1.fineCredits }
                _driftAccumulator += Int64(newTickets.count) * 300
                let toast: String
                if let first = newTickets.last, newTickets.count == 1 {
                    toast = "\(first.headline)\n\(first.detail)"
                } else {
                    toast = "\(newTickets.count) TICKETS ISSUED · +\(ticketFines) CR"
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.pursuitBusts = total
                    self.issuedTickets = self.opponents?.issuedTickets ?? self.issuedTickets
                    self.latestTicket = newTickets.last
                    self.arcadeToast = toast
                }
                DispatchQueue.main.async {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            heat = opponents?.interceptorLockStrength(
                playerWorldX: openWorld.worldX,
                playerWorldZ: openWorld.worldZ
            ) ?? 0
            let remaining = max(
                0,
                (pursuitTimeLimitOverride ?? Self.hotPursuitTimeLimit) - Date().timeIntervalSince(startTime)
            )
            let busts = opponents?.bustCount ?? 0
            let goal = max(1, pursuitBustGoal)
            let ticketTotal = opponents?.issuedTickets.reduce(Int64(0)) { $0 + $1.fineCredits } ?? 0
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.catchTimeRemaining = remaining
                self.pursuitBusts = busts
                self.issuedTickets = self.opponents?.issuedTickets ?? []
                self.arcadeObjective = "BUSTS \(busts)/\(goal) · TIX \(ticketTotal)"
                self.arcadeObjectiveProgress = Float(busts) / Float(goal)
                self.arcadeObjectiveComplete = busts >= goal
            }
            if busts >= goal {
                DispatchQueue.main.async { [weak self] in self?.pursuitOutcome = "caught" }
                finish()
                return
            }
            if remaining <= 0 {
                DispatchQueue.main.async { [weak self] in self?.pursuitOutcome = "suspects-escaped" }
                finish()
                return
            }
        }

        if mode == .courier {
            let snap = _courierSnapshot
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Always publish the live courier snapshot so a queued frame can't
                // re-open the dispatch board after the player already picked a job.
                self._courierSnapshot = self.courier.snapshot
                self.publishCourierSnapshot(self.courier.snapshot)
            }
            if snap.sessionFinished {
                finish()
                return
            }
        }
        WheelAssembly.spinWheels(in: carNode, speed: openWorld.speed, dt: dt)
        RaceParticles.updateEffects(
            on: carNode,
            speed: openWorld.speed,
            nitroActive: nitroOn,
            drifting: openWorld.isDrifting,
            slip: openWorld.slipAmount,
            braking: input.effectiveBrake > 0.1,
            throttle: input.effectiveThrottle
        )
        VehicleEnvironmentEffects.update(
            on: carNode,
            weather: raceWeather,
            speed: openWorld.speed,
            onDirt: abs(projection.signedLateral) > RaceTrackMesh.halfWidth
        )
        if openWorld.impactImpulse > 0.55 {
            KRCUISounds.playHorn()
        }
        if openWorld.impactImpulse > 0.4 && lastHapticImpact < 0.2 {
            let intensity = CGFloat(min(1, openWorld.impactImpulse))
            DispatchQueue.main.async {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: intensity)
            }
        }
        lastHapticImpact = openWorld.impactImpulse
        syncOnlinePresence(dt: dt)
        let newPosition: Int
        let newRacerCount: Int
        if let opponents {
            newPosition = opponents.playerPosition(playerLap: _lapIndex, playerTrackT: openWorld.trackT)
            newRacerCount = opponents.activeRacerCount
        } else {
            newPosition = 1
            newRacerCount = 1
        }
        let newElapsed = Date().timeIntervalSince(startTime)
        let capturedLap = _lapIndex
        let capturedDrift = _driftAccumulator
        let arcadeSnap = _arcadeSnapshot
        let courierSnap = _courierSnapshot
        let wrongWayNow = _wrongWayLatched
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.elapsedTime = newElapsed
            self.displayLapIndex = capturedLap
            self.driftScore = capturedDrift
            self.racePosition = newPosition
            self.racerCount = newRacerCount + HumanRacerPoseCache.shared.snapshot().count
            self.wrongWayActive = wrongWayNow
            if self.mode != .courier {
                self.arcadeCrystals = arcadeSnap.crystalsCollected
                self.arcadeCrystalTotal = arcadeSnap.crystalsTotal
                self.arcadeObjective = arcadeSnap.objectiveLabel
                self.arcadeObjectiveProgress = arcadeSnap.objectiveProgress
                self.arcadeObjectiveComplete = arcadeSnap.objectiveComplete
                self.arcadeToast = arcadeSnap.toast
                self.arcadeDraftActive = arcadeSnap.draftActive
                self.arcadeDriftZoneActive = arcadeSnap.driftZoneActive
            } else {
                _ = courierSnap
            }
        }
        let topSpeed = max(0.001, maxWorldSpeed * stats.topSpeedMul)
        let forwardNorm = min(1, max(0, openWorld.speed / topSpeed))
        let forwardKmh = max(0, openWorld.speed) * OpenWorldDrivingSimulation.worldUnitsToKmh
        var passBy: Float = 0
        if let nearest = opponents?.closestRelativeSpeed(
            playerWorldX: openWorld.worldX,
            playerWorldZ: openWorld.worldZ,
            playerSpeed: openWorld.speed
        ) {
            passBy = nearest
        }
        audio.update(
            forwardSpeedKmh: forwardKmh,
            speedNorm: forwardNorm,
            throttle: input.effectiveThrottle,
            brake: input.effectiveBrake,
            gear: openWorld.gear,
            nitroActive: nitroOn,
            nitroTank: nitro,
            trackProgress: openWorld.trackT,
            steerAbs: max(abs(input.effectiveSteer), openWorld.slipAmount * 0.8),
            rpm: openWorld.rpm,
            passByIntensity: passBy
        )
        Task { @MainActor in
            KRCMusicDirector.shared.setRaceIntensity(forwardNorm)
        }
    }

    private func updateVehicleLights() {
        let pursuit = mode == .policeChase && carId == "police"
        let level = pursuit
            ? 1
            : VehicleLighting.headlightLevel(
                weather: raceWeather,
                nightOverride: nightOverride,
                visualNight: city.visualNight
            )
        let on = VehicleLighting.shouldEnableHeadlights(level: level) || pursuit
        // During Hot Pursuit the flasher pass owns headlight wig-wag — still enable spots first.
        VehicleLighting.setHeadlights(on: carNode, enabled: on, level: level, isPlayer: true)
        if carId == "police" {
            VehicleLighting.updatePoliceFlashers(
                on: carNode,
                time: Date().timeIntervalSince(startTime),
                fullShow: pursuit || mode == .policeChase
            )
        }
    }

    private func placeCar(dt: Float) {
        // Road ribbon at sample.y+0.1. After seatOnContactPlane, tires ≈ local y=0.10.
        // Add a hard safety lift so the chassis can never sit inside the asphalt.
        let roadSurface: Float = 0.12
        let rideClearance: Float = roadSurface + 0.32
        let targetY = city.track.sample(openWorld.trackT).y + rideClearance
        let rideAlpha = min(1, dt * 12)
        smoothedRideY += (targetY - smoothedRideY) * rideAlpha

        let suspAvg = (openWorld.suspension.x + openWorld.suspension.y + openWorld.suspension.z + openWorld.suspension.w) * 0.25
        // Only allow upward visual bounce — never pull tires through asphalt.
        let suspVisual = max(0, suspAvg * 0.2)

        carNode.position = SCNVector3(openWorld.worldX, smoothedRideY + suspVisual, openWorld.worldZ)
        carNode.isHidden = false
        carNode.opacity = 1

        let attitudeAlpha = min(1, dt * 7)
        smoothedBodyPitch += (openWorld.bodyPitch - smoothedBodyPitch) * attitudeAlpha
        smoothedBodyRoll += (openWorld.bodyRoll - smoothedBodyRoll) * attitudeAlpha
        // Grade on the root so hills read; roll/pitch on the vehicle child so tires stay planted.
        // Standing start / crawl: keep the shell dead-flat so grid cars never look nose-tipped.
        let standingStart = lightsRemaining >= 0 || abs(openWorld.speed) < 0.35
        let tan = city.track.tangent(openWorld.trackT)
        let horiz = max(0.001, simd_length(SIMD2(tan.x, tan.z)))
        let gradePitch = standingStart
            ? Float(0)
            : max(-0.26, min(0.26, -atan2(tan.y, horiz)))
        carNode.eulerAngles = SCNVector3(gradePitch, openWorld.heading, 0)
        if let body = carNode.childNode(withName: "krcVehicleRoot", recursively: false) {
            // Keep alignVehicleForward yaw; only layer suspension pitch/roll.
            let pitch = standingStart
                ? Float(0)
                : max(-0.35, min(0.35, smoothedBodyPitch * 0.5))
            let roll = standingStart
                ? Float(0)
                : max(-0.45, min(0.45, smoothedBodyRoll * 0.35))
            body.eulerAngles = SCNVector3(pitch, body.eulerAngles.y, roll)
        }
        WheelAssembly.applySuspension(in: carNode, compression: openWorld.suspension)

        let speedRatio = min(1, abs(openWorld.speed) / max(0.001, maxWorldSpeed * stats.topSpeedMul))
        let portrait = (view?.bounds.height ?? 0) > (view?.bounds.width ?? 1)
        let carForward = simd_normalize(SIMD3<Float>(sin(openWorld.heading), 0, cos(openWorld.heading)))
        let carCenter = SIMD3<Float>(
            carNode.position.x,
            carNode.position.y + 0.75,
            carNode.position.z
        )
        #if DEBUG
        let camShake: Float = RaceQAAutopilot.enabled ? 0.15 : 1
        #else
        let camShake: Float = 1
        #endif
        let camLateral = openWorld.driftYaw * openWorld.speed
        let showGrid = lightsRemaining >= 0 && !didReleaseStartGrid
        let pack = startingPackFrame(playerCenter: carCenter)
        cameraRig.update(
            cameraNode: cameraNode,
            carPosition: carCenter,
            forward: carForward,
            speedRatio: speedRatio,
            portrait: portrait,
            dt: dt,
            viewBounds: view?.bounds.size ?? CGSize(width: 390, height: 844),
            driftTilt: smoothedBodyRoll * 0.55,
            impactImpulse: openWorld.impactImpulse,
            lateralVelocity: camLateral,
            shakeScale: camShake,
            gridIntro: showGrid,
            packCenter: pack.center,
            packRadius: pack.radius
        )
    }

    /// AABB-ish pack used to frame every grid car during 3-2-1.
    private func startingPackFrame(playerCenter: SIMD3<Float>) -> (center: SIMD3<Float>, radius: Float) {
        var points: [SIMD3<Float>] = [playerCenter]
        if let ops = opponents?.opponents {
            for opp in ops where !opp.node.isHidden && opp.node.name != "krcHumanRacer" {
                let p = opp.node.position
                points.append(SIMD3<Float>(p.x, p.y + 0.55, p.z))
            }
        }
        var sum = SIMD3<Float>.zero
        for p in points { sum += p }
        let center = sum / Float(max(1, points.count))
        var radius: Float = 5.5
        for p in points {
            radius = max(radius, simd_distance(p, center))
        }
        return (center, radius + 2.2)
    }

    private func logCarSpeedQA() {
        #if DEBUG
        // Use Swift string interpolation — never pass Swift String to NSLog `%s`
        // (that caused EXC_BAD_ACCESS / SIGSEGV when starting a race).
        let base = maxWorldSpeed * OpenWorldDrivingSimulation.worldUnitsToKmh
        let playerTop = base * stats.topSpeedMul
        print(
            "[SpeedQA] player=\(carId) top≈\(Int(playerTop.rounded())) km/h "
                + "(mul=\(String(format: "%.3f", stats.topSpeedMul)) "
                + "ref=\(Int(Self.referenceTopSpeedKmh)) hardCap=\(Int(Self.hardCapTopSpeedKmh)))"
        )
        var minK = Float.greatestFiniteMagnitude
        var maxK: Float = 0
        for (idx, car) in GameCatalog.cars.enumerated() {
            let profile = GameCatalog.profile(forCarIndex: idx)
            let mul = 0.72 + Float(profile.speed) / 100 * 0.40
            let kmh = base * mul
            minK = min(minK, kmh)
            maxK = max(maxK, kmh)
            if idx < 8 || car.id == carId || car.id == "911" || car.id == "camaro" {
                print("[SpeedQA] \(car.id) → \(Int(kmh.rounded())) km/h")
            }
        }
        print(
            "[SpeedQA] roster range \(Int(minK.rounded()))…\(Int(maxK.rounded())) km/h "
                + "across \(GameCatalog.cars.count) cars"
        )
        #endif
    }

    private func finish() {
        finished = true
        gameController.stop()
        audio.stop()
        let elapsed = Date().timeIntervalSince(startTime)
        let key = ghostTrackKey
            ?? RaceGhostTape.trackKey(trackIndex: city.catalogTrackIndex ?? 0, laps: lapGoal)
        _ = ghostController.finishTape(trackKey: key, carId: carId, totalTime: Float(elapsed))
        houseGhostDelta = ghostController.lastHouseDelta
        hadHouseGhost = ghostController.racedHouseGhost
        let aiPosition = opponents?.playerPosition(playerLap: _lapIndex, playerTrackT: openWorld.trackT) ?? 1
        let aiRacerCount = opponents?.activeRacerCount ?? 1
        let finalDrift = _driftAccumulator
        Task { @MainActor in
            self.driftScore = finalDrift
            var position = aiPosition
            var racerCount = aiRacerCount
            if KRCPlayerProfile.onlinePlayEnabled, let ctx = onlineContext {
                if KRCOnlineService.shared.liveHumansEnabled,
                   let live = await KRCOnlineService.shared.submitLiveFinish(
                    finishMs: Int64(elapsed * 1000),
                    fallbackPosition: aiPosition
                ) {
                    // Prefer live lobby standing when other humans are present.
                    // CPU still fills the grid — mix human count into the field size.
                    if live.humanCount > 1 {
                        position = live.humanPosition
                        racerCount = max(aiRacerCount, live.humanCount)
                    }
                }
                await KRCOnlineService.shared.submitGlobalRaceFinish(
                    context: ctx,
                    totalMs: Int64(elapsed * 1000),
                    position: position,
                    racerCount: racerCount
                )
            }
            KRCOnlineService.shared.endRaceSession()
            self.racePosition = position
            self.racerCount = racerCount
            onRaceFinished?(elapsed)
        }
    }

    private func publishCourierSnapshot(_ snap: CourierDeliverySystem.Snapshot) {
        courierDeliveries = snap.deliveriesComplete
        courierGoal = snap.deliveryGoal
        courierTimeRemaining = snap.timeRemaining
        courierCarrying = snap.carryingPackage
        courierDistance = snap.distanceToTarget
        courierBearing = snap.bearingToTarget
        courierDwell = snap.dwellProgress
        courierInZone = snap.inZone
        courierEarned = snap.earnedCredits
        courierNextPayout = snap.nextPayout
        courierStreak = snap.streak
        courierUrgency = snap.urgency
        courierAwaitingJobChoice = snap.awaitingJobChoice
            && !snap.carryingPackage
            && !snap.routeLocked
            && snap.cargoHeld == 0
        courierJobOffers = (snap.awaitingJobChoice
            && !snap.carryingPackage
            && !snap.routeLocked
            && snap.cargoHeld == 0) ? snap.jobOffers : []
        courierPackageKind = snap.packageKind
        courierRivalThreat = snap.rivalThreat
        courierCargoHeld = snap.cargoHeld
        courierCargoCapacity = snap.cargoCapacity
        courierNightPremium = snap.nightPremium
        courierShiftGrade = snap.gradeLabel
        arcadeObjective = snap.objectiveLabel
        arcadeObjectiveProgress = snap.objectiveProgress
        arcadeObjectiveComplete = snap.objectiveComplete
        arcadeToast = snap.toast
        arcadeCrystals = snap.deliveriesComplete
        arcadeCrystalTotal = snap.deliveryGoal
    }

    private func installPursuitRoadblocks() {
        roadblockRoot?.removeFromParentNode()
        let root = SCNNode()
        root.name = "krcPursuitRoadblocks"
        let count = 6
        for i in 0..<count {
            let t = (Float(i) + 0.55) / Float(count)
            let p = city.track.sample(t)
            let tan = city.track.tangent(t)
            let right = SIMD3<Float>(tan.z, 0, -tan.x)
            for side in [-1, 1] as [Float] {
                let box = SCNBox(width: 1.1, height: 1.15, length: 0.45, chamferRadius: 0.04)
                let mat = SCNMaterial()
                mat.lightingModel = .constant
                mat.diffuse.contents = UIColor(red: 0.95, green: 0.55, blue: 0.08, alpha: 1)
                mat.emission.contents = UIColor(red: 1, green: 0.35, blue: 0.05, alpha: 0.55)
                box.materials = [mat]
                let node = SCNNode(geometry: box)
                let lateral = right * side * (RaceTrackMesh.halfWidth - 1.4)
                node.position = SCNVector3(p.x + lateral.x, p.y + 0.55, p.z + lateral.z)
                node.eulerAngles.y = atan2(tan.x, tan.z)
                root.addChildNode(node)

                let stripe = SCNBox(width: 1.05, height: 0.18, length: 0.48, chamferRadius: 0.02)
                let stripeMat = SCNMaterial()
                stripeMat.lightingModel = .constant
                stripeMat.diffuse.contents = UIColor.black
                stripe.materials = [stripeMat]
                let stripeNode = SCNNode(geometry: stripe)
                stripeNode.position.y = 0.2
                node.addChildNode(stripeNode)
            }
        }
        scene.rootNode.addChildNode(root)
        roadblockRoot = root
    }

    /// Stop audio and controller when navigating away mid-race (e.g. pause → Main Menu).
    func tearDown() {
        audio.stop()
        gameController.stop()
        arcadeFun.detach()
        courier.detach()
        Task { @MainActor in
            KRCOnlineService.shared.endRaceSession()
        }
    }

    /// Arcade bumper vs live humans — they race you, not SceneKit ghosts.
    private func collideWithHumanRacers() {
        let poses = HumanRacerPoseCache.shared.snapshot()
        guard !poses.isEmpty else { return }
        let minDist: Float = 2.35
        for pose in poses {
            let dx = openWorld.worldX - pose.x
            let dz = openWorld.worldZ - pose.z
            let dist = sqrt(dx * dx + dz * dz)
            guard dist > 0.05, dist < minDist else { continue }
            let inv = 1 / dist
            let push = (minDist - dist) * 0.9
            openWorld.worldX += dx * inv * push
            openWorld.worldZ += dz * inv * push
            openWorld.speed *= 0.78
            openWorld.impactImpulse = max(openWorld.impactImpulse, 0.5)
        }
    }

    private func syncOnlinePresence(dt: Float) {
        guard let ctx = onlineContext else { return }
        let snapshotBase = (
            carId: carId,
            carName: ctx.carName,
            colorInt: ctx.colorInt,
            cityThemeIndex: ctx.cityThemeIndex,
            trackIndex: ctx.trackIndex,
            trackKey: ctx.trackKey,
            mode: ctx.mode,
            x: openWorld.worldX,
            y: carNode.position.y,
            z: openWorld.worldZ,
            angle: openWorld.heading,
            speedKmh: speedKmh(),
            lap: displayLapIndex,
            progress: openWorld.trackT
        )
        Task { @MainActor in
            let snapshot = RaceOnlineSnapshot(
                carId: snapshotBase.carId,
                carName: snapshotBase.carName,
                colorInt: snapshotBase.colorInt,
                cityThemeIndex: snapshotBase.cityThemeIndex,
                trackIndex: snapshotBase.trackIndex,
                trackKey: snapshotBase.trackKey,
                mode: snapshotBase.mode,
                x: snapshotBase.x,
                y: snapshotBase.y,
                z: snapshotBase.z,
                angle: snapshotBase.angle,
                speedKmh: snapshotBase.speedKmh,
                lap: snapshotBase.lap,
                progress: snapshotBase.progress,
                lobbyId: KRCOnlineService.shared.lobbyId ?? ""
            )
            KRCOnlineService.shared.tick(scene: scene, dt: dt, snapshot: snapshot)
        }
    }

}
