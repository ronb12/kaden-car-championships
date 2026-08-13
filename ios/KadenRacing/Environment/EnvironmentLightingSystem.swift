import SceneKit
import UIKit

/// Day / sunset / night lighting for race scenes (rain disabled — dry black asphalt only).
enum EnvironmentLightingSystem {

    enum WeatherMode: Equatable {
        case day
        case sunset
        case night
    }

    struct Handle {
        let ambientNode: SCNNode
        let sunNode: SCNNode
        let fillNode: SCNNode
        let rimNode: SCNNode?
    }

    static func weatherMode(city: CityRuntimeConfig, nightOverride: Bool) -> WeatherMode {
        if nightOverride || city.visualNight { return .night }
        switch city.lightingProfile {
        case .duskOrange: return .sunset
        case .rainOvercast, .fogMist, .goldenHour, .dayClear:
            return .day
        default:
            return .day
        }
    }

    static func install(
        into scene: SCNScene,
        city: CityRuntimeConfig,
        profile: EnvironmentTrackProfile,
        nightOverride: Bool,
        quality: GraphicsQuality
    ) -> Handle {
        let weather = weatherMode(city: city, nightOverride: nightOverride)
        let preset = EnvironmentGraphicsSettings.preset(for: quality)
        let palette = paletteFor(weather: weather, city: city, profile: profile)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = palette.ambientIntensity
        ambient.color = palette.ambientColor
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = palette.sunIntensity
        sun.color = palette.sunColor
        sun.castsShadow = quality != .low
        sun.shadowRadius = preset.shadowRadius
        sun.shadowSampleCount = preset.shadowSampleCount
        sun.shadowColor = UIColor(white: 0, alpha: quality == .low ? 0.28 : 0.42)
        sun.shadowMode = quality == .low ? .forward : .deferred
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = palette.sunAngles
        scene.rootNode.addChildNode(sunNode)

        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = palette.fillIntensity
        fill.color = palette.fillColor
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.eulerAngles = SCNVector3(-Float.pi / 6, -Float.pi / 3, 0)
        scene.rootNode.addChildNode(fillNode)

        var rimNode: SCNNode?
        if PalmCityEnvironment.isActive {
            let rim = SCNLight()
            rim.type = .directional
            if PalmCityEnvironment.isNight {
                rim.intensity = 380
                rim.color = UIColor(red: 1.0, green: 0.28, blue: 0.58, alpha: 1)
                rimNode = addRimLight(rim, angles: SCNVector3(-0.35, Float.pi * 0.15, 0), to: scene)
            } else {
                rim.intensity = 320
                rim.color = UIColor(red: 0.72, green: 0.88, blue: 1.0, alpha: 1)
                rimNode = addRimLight(rim, angles: SCNVector3(-Float.pi / 3.4, Float.pi / 4.8, 0), to: scene)
            }
        } else if weather == .sunset {
            let rim = SCNLight()
            rim.type = .directional
            rim.intensity = 340
            rim.color = UIColor(red: 1, green: 0.48, blue: 0.18, alpha: 1)
            let node = SCNNode()
            node.light = rim
            node.eulerAngles = SCNVector3(-0.45, Float.pi * 0.85, 0)
            scene.rootNode.addChildNode(node)
            rimNode = node
        } else if weather == .night {
            let rim = SCNLight()
            rim.type = .directional
            rim.intensity = 180
            rim.color = UIColor(red: 0.30, green: 0.42, blue: 0.72, alpha: 1)
            rimNode = addRimLight(rim, angles: SCNVector3(-0.28, Float.pi * 0.20, 0), to: scene)
        }

        scene.lightingEnvironment.contents = palette.envMap
        scene.lightingEnvironment.intensity = palette.envIntensity

        // Match device fog on Simulator so race screenshots share the same look.
        scene.fogStartDistance = preset.fogNear * palette.fogNearMul
        scene.fogEndDistance = preset.fogFar * palette.fogFarMul
        scene.fogColor = palette.fogColor

        return Handle(ambientNode: ambientNode, sunNode: sunNode, fillNode: fillNode, rimNode: rimNode)
    }

    // MARK: - Palette

    private struct Palette {
        let ambientIntensity: CGFloat
        let ambientColor: UIColor
        let sunIntensity: CGFloat
        let sunColor: UIColor
        let sunAngles: SCNVector3
        let fillIntensity: CGFloat
        let fillColor: UIColor
        let fogColor: UIColor
        let fogNearMul: CGFloat
        let fogFarMul: CGFloat
        let envMap: Any?
        let envIntensity: CGFloat
    }

    private static func paletteFor(
        weather: WeatherMode,
        city: CityRuntimeConfig,
        profile: EnvironmentTrackProfile
    ) -> Palette {
        if PalmCityEnvironment.isActive {
            return PalmCityEnvironment.isNight ? palmCityNightPalette() : palmCityDayPalette()
        }
        let art = CityEnvironmentArt.profile(for: city)
        // Neutral studio IBL for PBR road/grass — blue sky gradient is scene.background only.
        let envMap = KRCSceneKitHelpers.studioEnvironmentMap()

        switch weather {
        case .day:
            return Palette(
                ambientIntensity: profile == .coastalCityCircuit ? 520 : 460,
                ambientColor: UIColor(red: 0.78, green: 0.76, blue: 0.72, alpha: 1),
                sunIntensity: 2400,
                sunColor: UIColor(red: 1.0, green: 0.99, blue: 0.96, alpha: 1),
                sunAngles: SCNVector3(-Float.pi / 3.1, Float.pi / 5.5, 0),
                fillIntensity: 520,
                fillColor: UIColor(red: 0.62, green: 0.70, blue: 0.82, alpha: 1),
                fogColor: art.fogDay ?? UIColor(red: 0.55, green: 0.62, blue: 0.72, alpha: 1),
                fogNearMul: 1.15,
                fogFarMul: 1.25,
                envMap: envMap,
                envIntensity: 0.85
            )
        case .sunset:
            return Palette(
                ambientIntensity: 380,
                ambientColor: UIColor(red: 0.82, green: 0.64, blue: 0.48, alpha: 1),
                sunIntensity: 2200,
                sunColor: UIColor(red: 1.0, green: 0.62, blue: 0.28, alpha: 1),
                sunAngles: SCNVector3(-Float.pi / 4.5, Float.pi / 4, 0),
                fillIntensity: 130,
                fillColor: UIColor(red: 0.48, green: 0.52, blue: 0.72, alpha: 1),
                fogColor: art.fogSunset ?? UIColor(red: 0.88, green: 0.72, blue: 0.58, alpha: 1),
                fogNearMul: 0.9,
                fogFarMul: 1.05,
                envMap: envMap,
                envIntensity: 0.38
            )
        case .night:
            return Palette(
                ambientIntensity: 380,
                ambientColor: UIColor(red: 0.28, green: 0.34, blue: 0.52, alpha: 1),
                sunIntensity: 920,
                sunColor: UIColor(red: 0.48, green: 0.54, blue: 0.78, alpha: 1),
                sunAngles: SCNVector3(-Float.pi / 3.8, Float.pi / 6, 0),
                fillIntensity: 90,
                fillColor: UIColor(red: 0.18, green: 0.22, blue: 0.38, alpha: 1),
                fogColor: art.fogNight ?? UIColor(red: 0.04, green: 0.05, blue: 0.12, alpha: 1),
                fogNearMul: 0.75,
                fogFarMul: 0.92,
                envMap: envMap,
                envIntensity: 0.35
            )
        }
    }

    private static func palmCityNightPalette() -> Palette {
        let skyTop = UIColor(red: 0.06, green: 0.05, blue: 0.12, alpha: 1)
        let skyHorizon = UIColor(red: 0.45, green: 0.12, blue: 0.32, alpha: 1)
        let ground = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        let envMap = KRCSceneKitHelpers.environmentGradientMap(sky: skyTop, horizon: skyHorizon, ground: ground)
        return Palette(
            ambientIntensity: 240,
            ambientColor: UIColor(red: 0.32, green: 0.28, blue: 0.42, alpha: 1),
            sunIntensity: 520,
            sunColor: UIColor(red: 0.55, green: 0.52, blue: 0.68, alpha: 1),
            sunAngles: SCNVector3(-Float.pi / 3.5, Float.pi / 5.2, 0),
            fillIntensity: 140,
            fillColor: UIColor(red: 1.0, green: 0.72, blue: 0.38, alpha: 1),
            fogColor: UIColor(red: 0.06, green: 0.05, blue: 0.10, alpha: 1),
            fogNearMul: 0.68,
            fogFarMul: 0.88,
            envMap: envMap,
            envIntensity: 0.78
        )
    }

    private static func palmCityDayPalette() -> Palette {
        let skyTop = UIColor(red: 0.42, green: 0.68, blue: 0.92, alpha: 1)
        let skyHorizon = UIColor(red: 0.78, green: 0.88, blue: 0.96, alpha: 1)
        let ground = UIColor(red: 0.14, green: 0.20, blue: 0.26, alpha: 1)
        let envMap = KRCSceneKitHelpers.environmentGradientMap(sky: skyTop, horizon: skyHorizon, ground: ground)
        return Palette(
            ambientIntensity: 420,
            ambientColor: UIColor(red: 0.78, green: 0.84, blue: 0.90, alpha: 1),
            sunIntensity: 2100,
            sunColor: UIColor(red: 1.0, green: 0.98, blue: 0.92, alpha: 1),
            sunAngles: SCNVector3(-Float.pi / 2.8, Float.pi / 5.0, 0),
            fillIntensity: 160,
            fillColor: UIColor(red: 0.82, green: 0.90, blue: 0.98, alpha: 1),
            fogColor: UIColor(red: 0.72, green: 0.82, blue: 0.92, alpha: 1),
            fogNearMul: 1.05,
            fogFarMul: 1.35,
            envMap: envMap,
            envIntensity: 0.92
        )
    }

    private static func addRimLight(_ rim: SCNLight, angles: SCNVector3, to scene: SCNScene) -> SCNNode {
        let node = SCNNode()
        node.light = rim
        node.eulerAngles = angles
        scene.rootNode.addChildNode(node)
        return node
    }
}
