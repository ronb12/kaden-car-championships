import SceneKit
import UIKit

/// Orchestrates sky, lighting, track, ocean, nature, city decor, and post-processing.
enum RacingEnvironmentPipeline {

    struct BuiltScene {
        let trackRoot: SCNNode
        let cityRoot: SCNNode
        let lighting: EnvironmentLightingSystem.Handle
        let weather: EnvironmentLightingSystem.WeatherMode
        let quality: GraphicsQuality
    }

    static func build(
        scene: SCNScene,
        city: CityRuntimeConfig,
        nightOverride: Bool,
        cameraNode: SCNNode
    ) -> BuiltScene {
        if MinimalRaceEnvironment.isEnabled {
            return buildMinimal(scene: scene, city: city, nightOverride: nightOverride, cameraNode: cameraNode)
        }
        return buildFull(scene: scene, city: city, nightOverride: nightOverride, cameraNode: cameraNode)
    }

    // MARK: - Minimal (circuit only — no city / Kenney / palm scenery)

    private static func buildMinimal(
        scene: SCNScene,
        city: CityRuntimeConfig,
        nightOverride: Bool,
        cameraNode: SCNNode
    ) -> BuiltScene {
        let quality = EnvironmentGraphicsSettings.quality
        let preset = EnvironmentGraphicsSettings.preset(for: quality)
        let night = nightOverride || city.visualNight
        // Prefer sunset mood for golden / dusk cities so day tracks don't all share one blue sky.
        let weather: EnvironmentLightingSystem.WeatherMode = {
            if night { return .night }
            switch city.lightingProfile {
            case .duskOrange, .goldenHour: return .sunset
            default: return .day
            }
        }()

        MinimalRaceEnvironment.applyThemedSky(to: scene, city: city, night: night, weather: weather)
        let lighting = night
            ? MinimalRaceEnvironment.installNightLighting(into: scene)
            : MinimalRaceEnvironment.installLighting(into: scene)
        MinimalRaceEnvironment.applyThemedAtmosphere(to: scene, city: city, night: night, weather: weather)

        let trackRoot = SCNNode()
        trackRoot.name = "krcTrackRoot"
        scene.rootNode.addChildNode(trackRoot)

        MinimalRaceEnvironment.addGroundPlane(
            into: trackRoot,
            night: night,
            theme: city.definition.visualTheme,
            city: city
        )
        MinimalRaceEnvironment.buildRoad(
            into: trackRoot,
            track: city.track,
            definition: city.definition,
            night: night
        )
        if night {
            addTrackFloodlights(to: trackRoot, track: city.track)
            MinimalRaceEnvironment.addNeonRails(into: trackRoot, track: city.track)
        }
        MinimalRaceEnvironment.placeFarHorizon(
            into: trackRoot,
            track: city.track,
            city: city,
            night: night,
            weather: weather
        )
        TrackHillTunnelBuilder.build(
            into: trackRoot,
            track: city.track,
            city: city,
            night: night
        )
        TrackSceneryEnhancer.build(
            into: trackRoot,
            track: city.track,
            city: city,
            night: night,
            quality: quality
        )
        // Arcade dressing owns edge barriers / S-F props. Skip WorldPropsPlacer here —
        // it doubles lights, palms, billboards, and Kenney barriers on the minimal path.
        TrackArcadeDressing.dressTrack(
            into: trackRoot,
            track: city.track,
            city: city,
            night: night
        )
        let cityArt = CityEnvironmentArt.profile(for: city)
        if preset.oceanEnabled, cityArt.prefersOcean || city.trackProfile.prefersOcean {
            OceanEnvironmentBuilder.build(
                into: trackRoot,
                track: city.track,
                night: night,
                rainy: false,
                enabled: true
            )
        }
        if !city.themeId.hasPreviewCardPhoto {
            NatureEnvironmentBuilder.build(
                into: trackRoot,
                track: city.track,
                city: city,
                night: night,
                profile: city.trackProfile,
                mountainsEnabled: preset.mountainRingEnabled || city.trackProfile.prefersMountains
            )
        }
        MinimalRaceEnvironment.enableShadows(on: trackRoot)

        // Opaque Kenney/procedural roadside — off the racing line. Courier storefronts stay Courier-only.
        let cityRoot = SCNNode()
        cityRoot.name = "krcCityLayer"
        scene.rootNode.addChildNode(cityRoot)
        ProceduralCityDecor.buildRaceSafeLayer(into: cityRoot, city: city, night: night, quality: quality)

        if let cam = cameraNode.camera {
            cam.zNear = 0.35
            cam.zFar = max(Double(preset.maxDrawDistance) * 1.6, 1100)
            MinimalRaceEnvironment.configureCamera(cam, quality: quality, night: night)
        }

        return BuiltScene(
            trackRoot: trackRoot,
            cityRoot: cityRoot,
            lighting: lighting,
            weather: weather,
            quality: quality
        )
    }

    // MARK: - Full environment

    private static func buildFull(
        scene: SCNScene,
        city: CityRuntimeConfig,
        nightOverride: Bool,
        cameraNode: SCNNode
    ) -> BuiltScene {
        let quality = EnvironmentGraphicsSettings.quality
        let preset = EnvironmentGraphicsSettings.preset(for: quality)
        let night = nightOverride || city.visualNight || PalmCityEnvironment.forceNight
        let weather = PalmCityEnvironment.isActive
            ? (PalmCityEnvironment.isNight ? .night : .day)
            : EnvironmentLightingSystem.weatherMode(city: city, nightOverride: nightOverride)

        addSkyDome(scene: scene, city: city, night: night, weather: weather)
        EnvironmentPostProcessing.applyBackground(to: scene, city: city, night: night, weather: weather)
        let lighting = EnvironmentLightingSystem.install(
            into: scene,
            city: city,
            profile: city.trackProfile,
            nightOverride: nightOverride,
            quality: quality
        )

        let trackRoot = SCNNode()
        trackRoot.name = "krcTrackRoot"
        scene.rootNode.addChildNode(trackRoot)

        RoadEnvironmentBuilder.build(
            into: trackRoot,
            track: city.track,
            city: city,
            night: night,
            weather: weather
        )

        PalmCityRacewayBuilder.build(into: trackRoot, track: city.track, night: night)

        TrackSceneryEnhancer.build(
            into: trackRoot,
            track: city.track,
            city: city,
            night: night,
            quality: quality
        )

        let cityArt = CityEnvironmentArt.profile(for: city)
        let palmOcean = PalmCityEnvironment.isActive
            && PalmCityRacewayTracks.layout(for: city.catalogTrackIndex ?? 0).prefersOcean
        if preset.oceanEnabled,
           palmOcean || PalmCityEnvironment.prefersOcean
           || (!PalmCityEnvironment.isActive && (city.trackProfile.prefersOcean || cityArt.prefersOcean || city.trackProfile == .stormHarbor)) {
            OceanEnvironmentBuilder.build(
                into: trackRoot,
                track: city.track,
                night: night,
                rainy: false,
                enabled: true
            )
        }

        NatureEnvironmentBuilder.build(
            into: trackRoot,
            track: city.track,
            city: city,
            night: night,
            profile: city.trackProfile,
            mountainsEnabled: preset.mountainRingEnabled || city.trackProfile.prefersMountains
        )

        if night {
            addTrackFloodlights(to: trackRoot, track: city.track)
        }

        let cityRoot = SCNNode()
        cityRoot.name = "krcCityLayer"
        scene.rootNode.addChildNode(cityRoot)
        buildCityLayer(into: cityRoot, city: city, night: night, quality: quality)

        if let cam = cameraNode.camera {
            cam.zNear = 0.35
            cam.zFar = Double(preset.maxDrawDistance)
            EnvironmentPostProcessing.configure(camera: cam, weather: weather, quality: quality)
        }

        return BuiltScene(
            trackRoot: trackRoot,
            cityRoot: cityRoot,
            lighting: lighting,
            weather: weather,
            quality: quality
        )
    }

    /// Build sidewalks, skyline, and roadside props before the race starts (no pop-in while driving).
    static func buildCityLayer(
        into cityRoot: SCNNode,
        city: CityRuntimeConfig,
        night: Bool,
        quality: GraphicsQuality
    ) {
        ProceduralCityDecor.buildLayer(into: cityRoot, city: city, night: night, quality: quality)
        WorldPropsPlacer.build(into: cityRoot, city: city, night: night, quality: quality)
    }

    /// Legacy async path — prefer `buildCityLayer` so the track is complete at green light.
    static func scheduleCityLayer(
        cityRoot: SCNNode,
        city: CityRuntimeConfig,
        night: Bool,
        quality: GraphicsQuality
    ) {
        buildCityLayer(into: cityRoot, city: city, night: night, quality: quality)
    }

    private static func addSkyDome(
        scene: SCNScene,
        city: CityRuntimeConfig,
        night: Bool,
        weather: EnvironmentLightingSystem.WeatherMode
    ) {
        let dome = SCNSphere(radius: 340)
        dome.segmentCount = 64
        if PalmCityEnvironment.isActive {
            dome.materials = [PalmCityEnvironment.skyDomeMaterial()]
        } else {
            dome.materials = [AssetManager.skyDomeMaterial(city: city, night: night, weather: weather)]
        }
        let node = SCNNode(geometry: dome)
        node.position = SCNVector3(0, 60, 0)
        scene.rootNode.addChildNode(node)
    }

    private static func addTrackFloodlights(to parent: SCNNode, track: ClosedTrackSpline) {
        let pts = track.points
        let step = max(4, pts.count / 24)
        let lateral = TrackRoadsideClearance.poleMinLateral
        for i in stride(from: 0, to: pts.count, by: step) {
            let t = Float(i) / Float(pts.count)
            let base = track.position(at: t)
            let right = track.right(at: t)
            for side: Float in [-1, 1] {
                let polePos = base + right * (lateral * side)
                addFloodlightPole(to: parent, track: track, base: polePos, groundY: base.y)
            }
        }
    }

    private static func addFloodlightPole(
        to parent: SCNNode,
        track: ClosedTrackSpline,
        base: SIMD3<Float>,
        groundY: Float
    ) {
        let poleH: Float = 14.0
        let poleMat = SCNMaterial()
        poleMat.lightingModel = .physicallyBased
        poleMat.diffuse.contents = UIColor(white: 0.35, alpha: 1)
        poleMat.metalness.contents = 0.7
        let pole = SCNCylinder(radius: 0.12, height: CGFloat(poleH))
        pole.materials = [poleMat]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(base.x, groundY + poleH * 0.5, base.z)
        TrackRoadsideClearance.pushOutsideRoad(
            poleNode, track: track,
            minLateral: TrackRoadsideClearance.poleMinLateral,
            extraFootprint: 0.4
        )
        poleNode.position.y = groundY + poleH * 0.5
        parent.addChildNode(poleNode)

        let spot = SCNLight()
        spot.type = .spot
        spot.intensity = 1150
        spot.color = UIColor(red: 1.0, green: 0.95, blue: 0.78, alpha: 1)
        spot.spotInnerAngle = 32
        spot.spotOuterAngle = 62
        spot.castsShadow = false
        spot.attenuationStartDistance = 6
        spot.attenuationEndDistance = 42
        let spotNode = SCNNode()
        spotNode.light = spot
        spotNode.position = SCNVector3(0, poleH, 0)
        spotNode.eulerAngles = SCNVector3(-Float.pi / 2.1, 0, 0)
        poleNode.addChildNode(spotNode)
    }
}
