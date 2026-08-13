import SceneKit
import simd
import UIKit

/// Circuit-only race scene: asphalt, markings, edge rails, simple sky/lighting.
/// Full city/Kenney/palm scenery stays in the full pipeline and can be re-enabled later.
enum MinimalRaceEnvironment {

    /// When false, races use the full themed pipeline (sky, ocean, city decor, PBR road).
    /// On: photo sky + occlusion-safe Kenney roadside. Courier storefronts stay Courier-only.
    static let isEnabled = true

    /// Per-city sky: card photo when available, else themed gradient.
    static func applyThemedSky(
        to scene: SCNScene,
        city: CityRuntimeConfig,
        night: Bool,
        weather: EnvironmentLightingSystem.WeatherMode
    ) {
        scene.rootNode.childNodes.filter { $0.name == "krcMinimalSkyDome" }.forEach { $0.removeFromParentNode() }

        let contents: Any
        if let photo = CitySkyBackdrop.image(for: city, night: night, weather: weather, kind: .skyDome) {
            contents = photo
            scene.background.contents = CitySkyBackdrop.image(
                for: city, night: night, weather: weather, kind: .sceneBackground
            ) ?? photo
        } else {
            let g = CityEnvironmentArt.skyGradient(for: city, night: night, weather: weather)
            let gradient = KRCProceduralTextures.skyGradient(top: g.top, bottom: g.bottom, mid: g.mid)
            contents = gradient
            scene.background.contents = gradient
        }

        let dome = SCNSphere(radius: 640)
        dome.segmentCount = 48
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = contents
        if night {
            mat.emission.contents = UIColor(red: 0.03, green: 0.05, blue: 0.12, alpha: 1)
        }
        mat.cullMode = .front
        mat.writesToDepthBuffer = false
        dome.materials = [mat]
        let node = SCNNode(geometry: dome)
        node.name = "krcMinimalSkyDome"
        node.renderingOrder = -100
        scene.rootNode.addChildNode(node)
    }

    /// Fog + IBL tint from city art so horizons don't all wash the same blue-grey.
    static func applyThemedAtmosphere(
        to scene: SCNScene,
        city: CityRuntimeConfig,
        night: Bool,
        weather: EnvironmentLightingSystem.WeatherMode
    ) {
        let art = CityEnvironmentArt.profile(for: city)
        let sky = CityEnvironmentArt.skyGradient(for: city, night: night, weather: weather)
        let fog: UIColor
        if night {
            fog = art.fogNight ?? sky.mid ?? sky.bottom
        } else if weather == .sunset {
            fog = art.fogSunset ?? sky.mid ?? sky.bottom
        } else {
            fog = art.fogDay ?? sky.mid ?? sky.bottom
        }
        scene.fogColor = fog
        switch city.definition.environment {
        case .heavyFog, .oceanMist:
            scene.fogStartDistance = night ? 120 : 160
            scene.fogEndDistance = night ? 520 : 640
        case .lightRain, .dust, .heatHaze:
            scene.fogStartDistance = night ? 160 : 220
            scene.fogEndDistance = night ? 580 : 760
        case .none:
            scene.fogStartDistance = night ? 220 : 300
            scene.fogEndDistance = night ? 720 : 980
        }

        let ground = art.groundDay ?? groundTint(for: city.definition.visualTheme, night: night)
        scene.lightingEnvironment.contents = KRCSceneKitHelpers.environmentGradientMap(
            sky: sky.top,
            horizon: sky.bottom,
            ground: night ? ground.withAlphaComponent(1) : ground
        )
        scene.lightingEnvironment.intensity = night ? 0.85 : (weather == .sunset ? 1.15 : 1.35)
    }

    /// Distant landmark ring — photos as horizon mattes, never on the racing line.
    static func placeFarHorizon(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        city: CityRuntimeConfig,
        night: Bool,
        weather _: EnvironmentLightingSystem.WeatherMode = .day
    ) {
        var center = SIMD3<Float>(0, 0, 0)
        for p in track.points { center += p }
        center /= Float(max(1, track.points.count))
        let trackOuter = track.points.map { simd_length(SIMD2<Float>($0.x - center.x, $0.z - center.z)) }.max() ?? 80

        if city.themeId.hasPreviewCardPhoto {
            placeRegionalKit(into: parent, track: track, city: city, night: night)
            return
        }
        placeSilhouetteSkyline(into: parent, track: track, city: city, night: night, center: center, trackOuter: trackOuter)
        placeRegionalKit(into: parent, track: track, city: city, night: night)
    }

    private static func placeSilhouetteSkyline(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        city: CityRuntimeConfig,
        night: Bool,
        center: SIMD3<Float>,
        trackOuter: Float
    ) {
        var rng = SeededRandom(seed: city.seed ^ 0x51C1_1E01 ^ UInt64(city.themeId.rawValue) &* 1301)
        let art = CityEnvironmentArt.profile(for: city)
        let theme = city.definition.visualTheme
        let root = SCNNode()
        root.name = "krcFarHorizon"
        _ = track

        let count = min(28, max(14, art.skylineCount))
        let radius = trackOuter + 95
        for i in 0..<count {
            let angle = (Float(i) / Float(count)) * 2 * Float.pi + rng.float(in: -0.04...0.04)
            let tallBias = art.skylineHighRiseBias
            let h: Float
            let w: Float
            let d: Float
            switch theme {
            case .desertHighway:
                h = rng.float(in: 6...18); w = rng.float(in: 10...22); d = rng.float(in: 6...12)
            case .alpine:
                h = rng.float(in: 14...36); w = rng.float(in: 16...28); d = rng.float(in: 10...18)
            case .industrialPort:
                h = rng.float(in: 12...(rng.unitFloat() < 0.25 ? 48 : 28)); w = rng.float(in: 8...18); d = rng.float(in: 8...14)
            case .coastalNeon, .tropical, .luxuryBoulevard:
                h = rng.float(in: 16...(rng.unitFloat() < tallBias ? 42 : 26)); w = rng.float(in: 8...16); d = rng.float(in: 8...14)
            case .neonNight, .urbanDense:
                h = rng.float(in: 22...(rng.unitFloat() < tallBias ? 56 : 34)); w = rng.float(in: 7...14); d = rng.float(in: 7...12)
            case .historicNarrow:
                h = rng.float(in: 10...22); w = rng.float(in: 8...14); d = rng.float(in: 8...12)
            case .monsoonWet:
                h = rng.float(in: 18...(rng.unitFloat() < 0.5 ? 44 : 28)); w = rng.float(in: 8...15); d = rng.float(in: 8...13)
            }

            let color = horizonSilhouetteColor(theme: theme, night: night, rng: &rng)
            let box = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0.05)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = color
            if night {
                mat.emission.contents = color.withAlphaComponent(0.35)
            }
            box.materials = [mat]
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(
                center.x + cos(angle) * radius,
                center.y + h * 0.5,
                center.z + sin(angle) * radius
            )
            node.eulerAngles.y = angle + Float.pi
            node.castsShadow = false
            root.addChildNode(node)

            // Desert / alpine: occasional wider mesa / ridge slab.
            if (theme == .desertHighway || theme == .alpine), i % 4 == 0 {
                let ridgeH = theme == .alpine ? rng.float(in: 20...40) : rng.float(in: 4...10)
                let ridge = SCNBox(
                    width: CGFloat(rng.float(in: 28...48)),
                    height: CGFloat(ridgeH),
                    length: CGFloat(rng.float(in: 14...24)),
                    chamferRadius: 0.1
                )
                ridge.materials = [mat]
                let ridgeNode = SCNNode(geometry: ridge)
                ridgeNode.position = SCNVector3(
                    center.x + cos(angle + 0.08) * (radius + 18),
                    center.y + ridgeH * 0.45,
                    center.z + sin(angle + 0.08) * (radius + 18)
                )
                ridgeNode.castsShadow = false
                root.addChildNode(ridgeNode)
            }
        }
        parent.addChildNode(root)
    }

    /// Sparse regional props only — palms / pines / lamps. Never storefronts.
    private static func placeRegionalKit(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        city: CityRuntimeConfig,
        night: Bool
    ) {
        var rng = SeededRandom(seed: city.seed ^ 0xA11E_51DE ^ UInt64(city.themeId.rawValue) &* 4211)
        let theme = city.definition.visualTheme
        let root = SCNNode()
        root.name = "krcRegionalKit"
        let pts = track.points
        let step = max(6, pts.count / 18)
        var idx = 0
        for i in stride(from: 0, to: pts.count, by: step) {
            let t = Float(i) / Float(max(1, pts.count))
            let p = track.position(at: t)
            let right = track.right(at: t)
            let side: Float = idx % 2 == 0 ? 1 : -1
            let lateral = TrackRoadsideClearance.palmMinLateral + rng.float(in: 2...10)
            let pos = p + right * (lateral * side)
            switch theme {
            case .coastalNeon, .tropical, .luxuryBoulevard:
                root.addChildNode(makePalm(at: SCNVector3(pos.x, p.y, pos.z), rng: &rng))
            case .desertHighway:
                root.addChildNode(makeCactus(at: SCNVector3(pos.x, p.y, pos.z), rng: &rng))
            case .alpine:
                root.addChildNode(makePine(at: SCNVector3(pos.x, p.y, pos.z), rng: &rng))
            case .urbanDense, .neonNight, .historicNarrow, .monsoonWet:
                if idx % 2 == 0 {
                    let lamp = makeLampPole(at: SCNVector3(pos.x, p.y + 2.1, pos.z), night: night)
                    TrackRoadsideClearance.secure(
                        lamp, track: track,
                        minLateral: TrackRoadsideClearance.poleMinLateral,
                        extraFootprint: 1.2
                    )
                    root.addChildNode(lamp)
                }
            case .industrialPort:
                if idx % 2 == 0 {
                    let lamp = makeLampPole(at: SCNVector3(pos.x, p.y + 2.1, pos.z), night: night)
                    TrackRoadsideClearance.secure(
                        lamp, track: track,
                        minLateral: TrackRoadsideClearance.poleMinLateral,
                        extraFootprint: 1.2
                    )
                    root.addChildNode(lamp)
                }
            }
            idx += 1
        }
        parent.addChildNode(root)
    }

    private static func makePalm(at position: SCNVector3, rng: inout SeededRandom) -> SCNNode {
        let root = SCNNode()
        root.position = position
        let trunkH = CGFloat(5.2 + rng.float(in: 0...1.8))
        let trunk = SCNCylinder(radius: 0.18, height: trunkH)
        let tMat = SCNMaterial()
        tMat.lightingModel = .physicallyBased
        tMat.diffuse.contents = UIColor(red: 0.42, green: 0.30, blue: 0.16, alpha: 1)
        tMat.roughness.contents = 0.88
        trunk.materials = [tMat]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, Float(trunkH) * 0.5, 0)
        root.addChildNode(trunkNode)
        let frond = SCNSphere(radius: 1.45)
        frond.segmentCount = 10
        let fMat = SCNMaterial()
        fMat.lightingModel = .physicallyBased
        fMat.diffuse.contents = UIColor(red: 0.18, green: 0.52, blue: 0.26, alpha: 1)
        fMat.roughness.contents = 0.72
        frond.materials = [fMat]
        let frondNode = SCNNode(geometry: frond)
        frondNode.position = SCNVector3(0, Float(trunkH) + 0.15, 0)
        frondNode.scale = SCNVector3(1.0, 0.42, 1.0)
        root.addChildNode(frondNode)
        return root
    }

    private static func makeCactus(at position: SCNVector3, rng: inout SeededRandom) -> SCNNode {
        let root = SCNNode()
        root.position = position
        let h = CGFloat(1.8 + rng.float(in: 0...1.6))
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(red: 0.22, green: 0.42, blue: 0.24, alpha: 1)
        mat.roughness.contents = 0.78
        let trunk = SCNCylinder(radius: 0.16, height: h)
        trunk.materials = [mat]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, Float(h) * 0.5, 0)
        root.addChildNode(trunkNode)
        let arm = SCNCylinder(radius: 0.1, height: h * 0.45)
        arm.materials = [mat]
        let armNode = SCNNode(geometry: arm)
        armNode.position = SCNVector3(Float(h) * 0.22, Float(h) * 0.55, 0)
        armNode.eulerAngles.z = 1.1
        root.addChildNode(armNode)
        return root
    }

    private static func makePine(at position: SCNVector3, rng: inout SeededRandom) -> SCNNode {
        let root = SCNNode()
        root.position = position
        let h = CGFloat(7 + rng.float(in: 0...3))
        let trunk = SCNCylinder(radius: 0.16, height: h * 0.35)
        let tMat = SCNMaterial()
        tMat.lightingModel = .physicallyBased
        tMat.diffuse.contents = UIColor(red: 0.28, green: 0.18, blue: 0.1, alpha: 1)
        tMat.roughness.contents = 0.9
        trunk.materials = [tMat]
        let trunkNode = SCNNode(geometry: trunk)
        trunkNode.position = SCNVector3(0, Float(h) * 0.16, 0)
        root.addChildNode(trunkNode)
        let cone = SCNCone(topRadius: 0.05, bottomRadius: 1.6 + CGFloat(rng.float(in: 0...0.4)), height: h * 0.78)
        let cMat = SCNMaterial()
        cMat.lightingModel = .physicallyBased
        cMat.diffuse.contents = UIColor(red: 0.14, green: 0.32, blue: 0.18, alpha: 1)
        cMat.roughness.contents = 0.8
        cone.materials = [cMat]
        let coneNode = SCNNode(geometry: cone)
        coneNode.position = SCNVector3(0, Float(h) * 0.58, 0)
        root.addChildNode(coneNode)
        return root
    }

    private static func makeLampPole(at position: SCNVector3, night: Bool) -> SCNNode {
        let pole = SCNCylinder(radius: 0.08, height: 4.2)
        let poleMat = SCNMaterial()
        poleMat.lightingModel = .constant
        poleMat.diffuse.contents = UIColor(white: 0.22, alpha: 1)
        pole.materials = [poleMat]
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = position
        let lamp = SCNSphere(radius: 0.2)
        let lampMat = SCNMaterial()
        lampMat.lightingModel = .constant
        lampMat.diffuse.contents = UIColor(red: 1, green: 0.92, blue: 0.7, alpha: 1)
        lampMat.emission.contents = UIColor(red: 1, green: 0.85, blue: 0.45, alpha: night ? 0.9 : 0.45)
        lamp.materials = [lampMat]
        let lampNode = SCNNode(geometry: lamp)
        lampNode.position = SCNVector3(0, 2.15, 0)
        poleNode.addChildNode(lampNode)
        return poleNode
    }

    private static func horizonSilhouetteColor(
        theme: CityVisualTheme,
        night: Bool,
        rng: inout SeededRandom
    ) -> UIColor {
        if night {
            switch theme {
            case .neonNight:
                return [
                    UIColor(red: 0.08, green: 0.06, blue: 0.14, alpha: 1),
                    UIColor(red: 0.12, green: 0.05, blue: 0.18, alpha: 1),
                ][rng.int(in: 0...1)]
            case .desertHighway:
                return UIColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1)
            default:
                return UIColor(white: 0.06 + CGFloat(rng.unitFloat()) * 0.06, alpha: 1)
            }
        }
        switch theme {
        case .desertHighway:
            return UIColor(red: 0.42 + CGFloat(rng.unitFloat()) * 0.08, green: 0.28, blue: 0.16, alpha: 1)
        case .alpine:
            return UIColor(red: 0.28, green: 0.32 + CGFloat(rng.unitFloat()) * 0.06, blue: 0.34, alpha: 1)
        case .industrialPort:
            return UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1)
        case .coastalNeon, .tropical:
            return UIColor(red: 0.28, green: 0.24, blue: 0.20, alpha: 1)
        case .historicNarrow:
            return UIColor(red: 0.34, green: 0.24, blue: 0.20, alpha: 1)
        case .luxuryBoulevard:
            return UIColor(red: 0.30, green: 0.26, blue: 0.22, alpha: 1)
        default:
            return UIColor(red: 0.22, green: 0.24, blue: 0.28, alpha: 1)
        }
    }

    static func installLighting(into scene: SCNScene) -> EnvironmentLightingSystem.Handle {
        // Same lighting budget on Simulator and device so QA / store shots match the phone.
        let ambientIntensity: CGFloat = 780
        let sunIntensity: CGFloat = 2600
        let fillIntensity: CGFloat = 520
        let castShadows = true

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = ambientIntensity
        ambient.color = UIColor(red: 0.88, green: 0.90, blue: 0.94, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = sunIntensity
        sun.color = UIColor(red: 1, green: 0.98, blue: 0.94, alpha: 1)
        sun.castsShadow = castShadows
        if castShadows {
            sun.shadowRadius = 4
            sun.shadowSampleCount = 8
            sun.shadowMapSize = CGSize(width: 1024, height: 1024)
            sun.shadowMode = .forward
            sun.shadowColor = UIColor(white: 0, alpha: 0.22)
        }
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi / 2.6, Float.pi / 5.2, 0)
        scene.rootNode.addChildNode(sunNode)

        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = fillIntensity
        fill.color = UIColor(red: 0.82, green: 0.88, blue: 0.96, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.eulerAngles = SCNVector3(-Float.pi / 5.5, -Float.pi / 2.8, 0)
        scene.rootNode.addChildNode(fillNode)

        // Soft rim from behind-camera so car silhouettes separate from asphalt.
        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = 380
        rim.color = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1)
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.eulerAngles = SCNVector3(Float.pi / 7, Float.pi * 0.92, 0)
        scene.rootNode.addChildNode(rimNode)

        let sky = UIColor(red: 0.50, green: 0.72, blue: 0.94, alpha: 1)
        let horizon = UIColor(red: 0.88, green: 0.92, blue: 0.96, alpha: 1)
        let ground = UIColor(red: 0.18, green: 0.34, blue: 0.18, alpha: 1)
        scene.lightingEnvironment.contents = KRCSceneKitHelpers.environmentGradientMap(
            sky: sky,
            horizon: horizon,
            ground: ground
        )
        scene.lightingEnvironment.intensity = 1.35

        scene.fogStartDistance = 280
        scene.fogEndDistance = 720
        scene.fogColor = UIColor(red: 0.70, green: 0.80, blue: 0.90, alpha: 1)

        return EnvironmentLightingSystem.Handle(
            ambientNode: ambientNode,
            sunNode: sunNode,
            fillNode: fillNode,
            rimNode: rimNode
        )
    }

    static func installNightLighting(into scene: SCNScene) -> EnvironmentLightingSystem.Handle {
        let ambientIntensity: CGFloat = 280
        let moonIntensity: CGFloat = 1100
        let fillIntensity: CGFloat = 520
        let castShadows = true

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = ambientIntensity
        ambient.color = UIColor(red: 0.35, green: 0.42, blue: 0.62, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let moon = SCNLight()
        moon.type = .directional
        moon.intensity = moonIntensity
        moon.color = UIColor(red: 0.72, green: 0.82, blue: 1.0, alpha: 1)
        moon.castsShadow = castShadows
        if castShadows {
            moon.shadowRadius = 5
            moon.shadowSampleCount = 8
            moon.shadowMapSize = CGSize(width: 1024, height: 1024)
            moon.shadowMode = .forward
            moon.shadowColor = UIColor(white: 0, alpha: 0.45)
        }
        let sunNode = SCNNode()
        sunNode.light = moon
        sunNode.eulerAngles = SCNVector3(-Float.pi / 3.1, Float.pi / 4.5, 0)
        scene.rootNode.addChildNode(sunNode)

        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = fillIntensity
        fill.color = UIColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.eulerAngles = SCNVector3(-Float.pi / 6, -Float.pi / 2.4, 0)
        scene.rootNode.addChildNode(fillNode)

        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = 520
        rim.color = UIColor(red: 0.25, green: 0.85, blue: 1.0, alpha: 1)
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.eulerAngles = SCNVector3(Float.pi / 8, Float.pi * 0.9, 0)
        scene.rootNode.addChildNode(rimNode)

        let sky = UIColor(red: 0.06, green: 0.08, blue: 0.18, alpha: 1)
        let horizon = UIColor(red: 0.18, green: 0.16, blue: 0.32, alpha: 1)
        let ground = UIColor(red: 0.05, green: 0.08, blue: 0.06, alpha: 1)
        scene.lightingEnvironment.contents = KRCSceneKitHelpers.environmentGradientMap(
            sky: sky,
            horizon: horizon,
            ground: ground
        )
        scene.lightingEnvironment.intensity = 0.85

        scene.fogStartDistance = 160
        scene.fogEndDistance = 520
        scene.fogColor = UIColor(red: 0.05, green: 0.07, blue: 0.14, alpha: 1)

        return EnvironmentLightingSystem.Handle(
            ambientNode: ambientNode,
            sunNode: sunNode,
            fillNode: fillNode,
            rimNode: rimNode
        )
    }

    static func buildRoad(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        definition: CityThemeDefinition,
        night: Bool = false
    ) {
        RaceTrackMesh.buildMinimalVisible(
            into: parent,
            track: track,
            grassMaterial: grassShoulderMaterial(definition: definition, night: night),
            night: night
        )
    }

    static func grassShoulderMaterial(definition: CityThemeDefinition, night: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        let art = CityEnvironmentArt.profile(themeId: definition.id, definition: definition)
        m.diffuse.contents = KRCProceduralTextures.grass(
            tint: night ? shoulderTint(for: definition.visualTheme, night: true) : art.foliage,
            night: night
        )
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(10, 10, 1)
        m.roughness.contents = night ? 0.72 : 0.94
        m.metalness.contents = 0
        return m
    }

    private static func shoulderTint(for theme: CityVisualTheme, night: Bool) -> UIColor {
        if night {
            switch theme {
            case .desertHighway: return UIColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 1)
            case .alpine: return UIColor(red: 0.08, green: 0.16, blue: 0.12, alpha: 1)
            case .industrialPort, .neonNight: return UIColor(red: 0.06, green: 0.10, blue: 0.10, alpha: 1)
            case .coastalNeon, .tropical: return UIColor(red: 0.05, green: 0.18, blue: 0.14, alpha: 1)
            default: return UIColor(red: 0.04, green: 0.18, blue: 0.10, alpha: 1)
            }
        }
        switch theme {
        case .desertHighway: return UIColor(red: 0.55, green: 0.42, blue: 0.22, alpha: 1)
        case .alpine: return UIColor(red: 0.18, green: 0.38, blue: 0.22, alpha: 1)
        case .industrialPort: return UIColor(red: 0.22, green: 0.28, blue: 0.22, alpha: 1)
        case .neonNight: return UIColor(red: 0.12, green: 0.22, blue: 0.2, alpha: 1)
        case .coastalNeon, .tropical: return UIColor(red: 0.18, green: 0.48, blue: 0.32, alpha: 1)
        case .historicNarrow: return UIColor(red: 0.22, green: 0.36, blue: 0.18, alpha: 1)
        case .luxuryBoulevard: return UIColor(red: 0.14, green: 0.4, blue: 0.22, alpha: 1)
        case .monsoonWet: return UIColor(red: 0.08, green: 0.32, blue: 0.2, alpha: 1)
        case .urbanDense: return UIColor(red: 0.12, green: 0.36, blue: 0.16, alpha: 1)
        }
    }

    static func visibleAsphaltMaterial(night: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        // Asphalt Legends / Real Racing style: charcoal ribbon, not near-black void or flat mid-gray.
        m.lightingModel = .lambert
        if night {
            // Slight wet sheen under neon / floodlights.
            m.diffuse.contents = UIColor(red: 0.10, green: 0.11, blue: 0.15, alpha: 1)
            m.ambient.contents = UIColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 1)
            m.emission.contents = UIColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1)
            m.multiply.contents = UIColor(red: 0.92, green: 0.94, blue: 1.0, alpha: 1)
        } else {
            m.diffuse.contents = UIColor(red: 0.16, green: 0.17, blue: 0.19, alpha: 1)
            m.ambient.contents = UIColor(red: 0.14, green: 0.15, blue: 0.17, alpha: 1)
            m.multiply.contents = UIColor.white
        }
        // Double-sided so winding / normal flips never hide the ribbon.
        m.isDoubleSided = true
        m.cullMode = .back
        m.readsFromDepthBuffer = true
        m.writesToDepthBuffer = true
        return m
    }

    /// Flat green disc under the circuit so sky does not bleed through track gaps.
    static func addGroundPlane(into parent: SCNNode, night: Bool = false, theme: CityVisualTheme = .urbanDense, city: CityRuntimeConfig? = nil) {
        let ground = SCNCylinder(radius: 560, height: 0.4)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        if let city, let artGround = CityEnvironmentArt.profile(for: city).groundDay, !night {
            mat.diffuse.contents = artGround
        } else {
            mat.diffuse.contents = groundTint(for: theme, night: night)
        }
        mat.roughness.contents = 0.95
        mat.metalness.contents = 0
        ground.materials = [mat]
        let node = SCNNode(geometry: ground)
        node.name = "krcMinimalGround"
        node.position = SCNVector3(0, -0.25, 0)
        node.castsShadow = false
        parent.addChildNode(node)
    }

    private static func groundTint(for theme: CityVisualTheme, night: Bool) -> UIColor {
        if night {
            switch theme {
            case .desertHighway: return UIColor(red: 0.12, green: 0.08, blue: 0.05, alpha: 1)
            case .neonNight: return UIColor(red: 0.04, green: 0.06, blue: 0.1, alpha: 1)
            case .alpine: return UIColor(red: 0.05, green: 0.1, blue: 0.1, alpha: 1)
            default: return UIColor(red: 0.04, green: 0.12, blue: 0.08, alpha: 1)
            }
        }
        switch theme {
        case .desertHighway: return UIColor(red: 0.48, green: 0.38, blue: 0.22, alpha: 1)
        case .alpine: return UIColor(red: 0.16, green: 0.32, blue: 0.2, alpha: 1)
        case .industrialPort: return UIColor(red: 0.2, green: 0.24, blue: 0.2, alpha: 1)
        case .coastalNeon, .tropical: return UIColor(red: 0.14, green: 0.4, blue: 0.28, alpha: 1)
        case .neonNight: return UIColor(red: 0.1, green: 0.18, blue: 0.18, alpha: 1)
        default: return UIColor(red: 0.12, green: 0.34, blue: 0.14, alpha: 1)
        }
    }

    /// Soft neon edge markers for night races (readability without city scenery).
    static func addNeonRails(into parent: SCNNode, track: ClosedTrackSpline) {
        let pts = track.points
        let step = max(3, pts.count / 36)
        let cyan = UIColor(red: 0.15, green: 0.95, blue: 1.0, alpha: 1)
        let magenta = UIColor(red: 1.0, green: 0.25, blue: 0.75, alpha: 1)
        for (idx, i) in stride(from: 0, to: pts.count, by: step).enumerated() {
            let t = Float(i) / Float(max(1, pts.count))
            let base = track.position(at: t)
            let right = track.right(at: t)
            let color = idx % 2 == 0 ? cyan : magenta
            for side: Float in [-1, 1] {
                let pos = base + right * ((RaceTrackMesh.halfWidth + 1.2) * side)
                let box = SCNBox(width: 0.35, height: 0.18, length: 2.4, chamferRadius: 0.04)
                let mat = SCNMaterial()
                mat.lightingModel = .constant
                mat.diffuse.contents = color
                mat.emission.contents = color
                box.materials = [mat]
                let node = SCNNode(geometry: box)
                node.position = SCNVector3(pos.x, base.y + 0.22, pos.z)
                node.castsShadow = false
                parent.addChildNode(node)
            }
        }
    }

    // Race circuits stay clear of buildings. Courier mode owns stop storefronts
    // via CourierDeliverySystem.makeStopDressing — do not reintroduce roadside
    // shells here (see-through / on-road placement regressions).

    static func enableShadows(on root: SCNNode) {
        root.enumerateChildNodes { node, _ in
            guard node.geometry != nil else { return }
            let skip = node.name?.hasPrefix("krcHorizon") == true
                || node.parent?.name == "krcHorizonBackdrop"
            node.castsShadow = !skip
        }
    }

    static func configureCamera(_ camera: SCNCamera, quality: GraphicsQuality, night: Bool = false) {
        _ = quality
        let preset = EnvironmentGraphicsSettings.preset(for: quality)
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        // Stable look — no speed-reactive color crush / vignette tunnel.
        camera.bloomIntensity = night ? 0.22 : 0.12
        camera.bloomThreshold = night ? 0.88 : 0.96
        camera.bloomBlurRadius = night ? 3 : 2
        camera.motionBlurIntensity = 0
        camera.vignettingIntensity = 0
        camera.vignettingPower = 1.0
        camera.saturation = 1.0
        camera.contrast = night ? 1.08 : 1.04
        camera.zFar = max(camera.zFar, 1100)
        _ = preset
    }

    static func updateCameraPost(camera: SCNCamera, speedRatio: Float, quality: GraphicsQuality) {
        // Intentionally stable — do not tint / tunnel the frame with speed.
        _ = camera
        _ = speedRatio
        _ = quality
    }
}
