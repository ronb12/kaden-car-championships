import SceneKit
import UIKit

/// Builds the full track + city scene on the track-select screen so gameplay does not hitch.
enum RaceEnvironmentPreloader {

    struct Prepared {
        let scene: SCNScene
        let trackRoot: SCNNode
        let cityRoot: SCNNode
        let lighting: EnvironmentLightingSystem.Handle
        let weather: EnvironmentLightingSystem.WeatherMode
        let quality: GraphicsQuality
    }

    private static var cache: [String: Prepared] = [:]
    private static var warmedKeys = Set<String>()
    private static var inFlightKey: String?
    private static var pendingCompletions: [String: [(Prepared?) -> Void]] = [:]
    private static let buildQueue = DispatchQueue(label: "krc.env.preloader", qos: .userInitiated)

    static var isPreparing: Bool { inFlightKey != nil }

    static func cacheKey(city: CityRuntimeConfig, nightOverride: Bool) -> String {
        let night = nightOverride || city.visualNight
        let idx = city.catalogTrackIndex ?? -1
        return "\(city.themeId.rawValue)-\(idx)-\(city.seed)-\(night ? 1 : 0)"
    }

    static func prepared(for key: String) -> Prepared? { cache[key] }

    /// Removes a prepared world from the cache for live use — avoids `clone()` pop-in and frustum glitches.
    static func takePrepared(for key: String) -> Prepared? {
        guard let hit = cache.removeValue(forKey: key) else { return nil }
        warmedKeys.remove(key)
        stripWarmupCameras(from: hit.scene)
        return hit
    }

    static func isReady(for key: String) -> Bool {
        cache[key] != nil && warmedKeys.contains(key)
    }

    /// Build (if needed), warm GPU shaders, then call `completion` on the main queue.
    static func ensureReady(
        city: CityRuntimeConfig,
        nightOverride: Bool,
        completion: @escaping () -> Void
    ) {
        let key = cacheKey(city: city, nightOverride: nightOverride)
        if isReady(for: key) {
            DispatchQueue.main.async(execute: completion)
            return
        }
        prepare(city: city, nightOverride: nightOverride) { prepared in
            guard let prepared else {
                completion()
                return
            }
            warmUp(prepared: prepared, key: key, completion: completion)
        }
    }

    static func prepare(
        city: CityRuntimeConfig,
        nightOverride: Bool,
        completion: ((Prepared?) -> Void)? = nil
    ) {
        let key = cacheKey(city: city, nightOverride: nightOverride)
        if let hit = cache[key] {
            completion?(hit)
            return
        }
        if inFlightKey == key {
            if let completion {
                pendingCompletions[key, default: []].append(completion)
            }
            return
        }
        inFlightKey = key
        if let completion {
            pendingCompletions[key, default: []].append(completion)
        }

        let finishOnMain: (Prepared) -> Void = { prepared in
            let apply = {
                cache[key] = prepared
                inFlightKey = nil
                let waiters = pendingCompletions.removeValue(forKey: key) ?? []
                for waiter in waiters { waiter(prepared) }
            }
            if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
        }

        let buildScene: () -> Prepared = {
            if !MinimalRaceEnvironment.isEnabled {
                KenneyEnvironmentLoader.prewarm()
            }
            let camera = SCNNode()
            camera.camera = SCNCamera()
            let scene = SCNScene()
            let built = RacingEnvironmentPipeline.build(
                scene: scene,
                city: city,
                nightOverride: nightOverride,
                cameraNode: camera
            )
            return Prepared(
                scene: scene,
                trackRoot: built.trackRoot,
                cityRoot: built.cityRoot,
                lighting: built.lighting,
                weather: built.weather,
                quality: built.quality
            )
        }

        // SceneKit geometry/materials are not reliably thread-safe — circuit-only builds on main.
        if MinimalRaceEnvironment.isEnabled {
            let run = { finishOnMain(buildScene()) }
            if Thread.isMainThread { run() } else { DispatchQueue.main.async(execute: run) }
        } else {
            buildQueue.async {
                let prepared = buildScene()
                finishOnMain(prepared)
            }
        }
    }

    /// Precompile SceneKit shaders on the main thread so the first race frame is not a hitch.
    private static func warmUp(prepared: Prepared, key: String, completion: @escaping () -> Void) {
        if warmedKeys.contains(key) {
            completion()
            return
        }
        DispatchQueue.main.async {
            let view = SCNView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
            view.scene = prepared.scene
            view.isPlaying = true
            SceneKitMobileTuning.apply(to: view)
            let warmCam = SCNNode()
            warmCam.name = "krcWarmupCamera"
            warmCam.camera = SCNCamera()
            warmCam.position = SCNVector3(0, 28, 72)
            warmCam.look(at: SCNVector3(0, 4, 0))
            prepared.scene.rootNode.addChildNode(warmCam)
            view.pointOfView = warmCam
            var nodes: [SCNNode] = []
            prepared.scene.rootNode.enumerateChildNodes { node, _ in
                nodes.append(node)
            }
            nodes.append(prepared.scene.rootNode)
            if nodes.isEmpty {
                warmedKeys.insert(key)
                completion()
                return
            }
            view.prepare(nodes) { _ in
                DispatchQueue.main.async {
                    warmCam.removeFromParentNode()
                    warmedKeys.insert(key)
                    completion()
                }
            }
        }
    }

    static func stripWarmupCameras(from scene: SCNScene) {
        scene.rootNode.childNodes
            .filter { $0.name == "krcWarmupCamera" }
            .forEach { $0.removeFromParentNode() }
    }

    static func evictAll() {
        cache.removeAll()
        warmedKeys.removeAll()
        inFlightKey = nil
        pendingCompletions.removeAll()
    }

    /// Copies sky, fog, and IBL from a prepared scene — cloning root children alone drops atmosphere.
    static func adoptAtmosphere(from source: SCNScene, to target: SCNScene) {
        target.background.contents = source.background.contents
        if let env = source.lightingEnvironment.contents {
            target.lightingEnvironment.contents = env
            target.lightingEnvironment.intensity = source.lightingEnvironment.intensity
        }
        target.fogStartDistance = source.fogStartDistance
        target.fogEndDistance = source.fogEndDistance
        target.fogColor = source.fogColor
        target.fogDensityExponent = source.fogDensityExponent
    }

    /// Legacy clone path — prefer `takePrepared` so the race uses the same scene graph that was warmed.
    static func mountPreparedWorld(_ prepared: Prepared, into target: SCNScene) {
        adoptAtmosphere(from: prepared.scene, to: target)
        for child in prepared.scene.rootNode.childNodes {
            target.rootNode.addChildNode(child.clone())
        }
    }
}
