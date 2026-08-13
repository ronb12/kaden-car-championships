import SceneKit
import UIKit

/// Caches **materials and light colors** per city theme to cut duplicate state and speed theme swaps.
enum AssetManager {

    private static var asphaltCache: [Int: UIColor] = [:]
    private static var groundCache: [Int: UIColor] = [:]
    private static var skyCache: [Int: UIColor] = [:]
    private static var materialCache: [String: SCNMaterial] = [:]

    static func asphalt(definition: CityThemeDefinition, night: Bool) -> UIColor {
        let k = definition.id.rawValue * 10 + (night ? 1 : 0)
        if let c = asphaltCache[k] { return c }
        // Keep asphalt dark but readable under HDR/shadows (near-zero albedo crushed to a void).
        #if targetEnvironment(simulator)
        let c = UIColor(
            red: night ? 0.12 : 0.18,
            green: night ? 0.12 : 0.18,
            blue: night ? 0.14 : 0.20,
            alpha: 1
        )
        #else
        let c = UIColor(
            red: night ? 0.055 : 0.085,
            green: night ? 0.055 : 0.085,
            blue: night ? 0.062 : 0.095,
            alpha: 1
        )
        #endif
        asphaltCache[k] = c
        return c
    }

    static func ground(definition: CityThemeDefinition, night: Bool) -> UIColor {
        let k = definition.id.rawValue * 10 + (night ? 3 : 2)
        if let c = groundCache[k] { return c }
        let art = CityEnvironmentArt.profile(themeId: definition.id, definition: definition)
        if !night, let custom = art.groundDay {
            groundCache[k] = custom
            return custom
        }
        let c: UIColor
        switch definition.terrain {
        case .coastal:
            c = UIColor(red: night ? 0.10 : 0.42, green: night ? 0.18 : 0.38, blue: night ? 0.08 : 0.22, alpha: 1)
        case .canyon, .rolling:
            c = UIColor(red: night ? 0.10 : 0.24, green: night ? 0.17 : 0.34, blue: night ? 0.08 : 0.16, alpha: 1)
        case .flat, .stepped:
            // Warm parkland — avoid blue PBR wash on shoulders (NFS-style neutral turf).
            c = UIColor(red: night ? 0.08 : 0.28, green: night ? 0.14 : 0.34, blue: night ? 0.06 : 0.12, alpha: 1)
        }
        groundCache[k] = c
        return c
    }

    static func sky(definition: CityThemeDefinition, night: Bool, sunset: Bool = false) -> UIColor {
        let k = definition.id.rawValue * 10 + (night ? 5 : 4) + (sunset ? 6 : 0)
        if let c = skyCache[k] { return c }
        let art = CityEnvironmentArt.profile(themeId: definition.id, definition: definition)
        if sunset, let custom = art.skyTopSunset { skyCache[k] = custom; return custom }
        if !night, let custom = art.skyTopDay { skyCache[k] = custom; return custom }
        let out: UIColor
        if night, definition.lighting == .dayClear || definition.lighting == .goldenHour {
            out = UIColor(red: 0.04, green: 0.07, blue: 0.15, alpha: 1)
        } else {
            switch definition.lighting {
            case .dayClear, .goldenHour:
                out = UIColor(red: 0.18, green: 0.42, blue: 0.78, alpha: 1)
            case .nightNeon, .nightSoft, .duskOrange:
                out = UIColor(red: 0.04, green: 0.07, blue: 0.15, alpha: 1)
            case .rainOvercast, .fogMist:
                out = UIColor(red: 0.38, green: 0.41, blue: 0.44, alpha: 1)
            }
        }
        skyCache[k] = out
        return out
    }

    static func skyHorizon(definition: CityThemeDefinition, night: Bool, sunset: Bool = false) -> UIColor {
        let art = CityEnvironmentArt.profile(themeId: definition.id, definition: definition)
        if sunset, let custom = art.skyHorizonSunset { return custom }
        if !night, let custom = art.skyHorizonDay { return custom }
        if night {
            return UIColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1)
        }
        switch definition.lighting {
        case .goldenHour:
            return UIColor(red: 0.72, green: 0.86, blue: 0.96, alpha: 1)
        case .rainOvercast, .fogMist:
            return UIColor(red: 0.68, green: 0.70, blue: 0.72, alpha: 1)
        default:
            return UIColor(red: 0.72, green: 0.86, blue: 0.96, alpha: 1)
        }
    }

    // MARK: - PBR materials (textured track surfaces)

    static func asphaltMaterial(definition: CityThemeDefinition, night: Bool, wet: Bool = false) -> SCNMaterial {
        _ = wet
        let key = "asphaltMat-v11-dry-\(definition.id.rawValue)-\(night ? 1 : 0)"
        if let m = materialCache[key] { return m.copy() as? SCNMaterial ?? m }
        let tint = asphalt(definition: definition, night: night)
        let m = SCNMaterial()
        // Lambert only — PBR / clearCoat on asphalt reads as a mirror under sky IBL.
        m.lightingModel = .lambert
        m.diffuse.contents = KRCProceduralTextures.asphalt(tint: tint, night: night)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(10, 10, 1)
        m.specular.contents = UIColor.black
        m.shininess = 0
        m.multiply.contents = UIColor(white: night ? 0.94 : 0.98, alpha: 1)
        m.emission.contents = night
            ? UIColor(red: 0.02, green: 0.02, blue: 0.025, alpha: 1)
            : UIColor.black
        m.isDoubleSided = false
        m.cullMode = .back
        m.readsFromDepthBuffer = true
        m.writesToDepthBuffer = true
        materialCache[key] = m
        return m.copy() as? SCNMaterial ?? m
    }

    static func runoffMaterial(definition: CityThemeDefinition, night: Bool) -> SCNMaterial {
        let key = "runoffMat-\(definition.id.rawValue)-\(night ? 1 : 0)"
        if let m = materialCache[key] { return m.copy() as? SCNMaterial ?? m }
        let tint = ground(definition: definition, night: night)
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = KRCProceduralTextures.runoffGravel(tint: tint, night: night)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(6, 6, 1)
        m.roughness.contents = 0.96
        m.metalness.contents = 0.0
        materialCache[key] = m
        return m.copy() as? SCNMaterial ?? m
    }

    static func grassMaterial(definition: CityThemeDefinition, night: Bool) -> SCNMaterial {
        let key = "grassMat-v2-\(definition.id.rawValue)-\(night ? 1 : 0)"
        if let m = materialCache[key] { return m.copy() as? SCNMaterial ?? m }
        let art = CityEnvironmentArt.profile(themeId: definition.id, definition: definition)
        let tint = art.foliage
        let m = SCNMaterial()
        m.lightingModel = .lambert
        m.diffuse.contents = KRCProceduralTextures.grass(tint: tint, night: night)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(12, 12, 1)
        m.isDoubleSided = false
        m.cullMode = .back
        materialCache[key] = m
        return m.copy() as? SCNMaterial ?? m
    }

    static func skyDomeMaterial(
        city: CityRuntimeConfig,
        night: Bool,
        weather: EnvironmentLightingSystem.WeatherMode
    ) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        if let photo = CitySkyBackdrop.image(for: city, night: night, weather: weather, kind: .skyDome) {
            m.diffuse.contents = photo
        } else {
            let sky = CityEnvironmentArt.skyGradient(for: city, night: night, weather: weather)
            m.diffuse.contents = KRCProceduralTextures.skyGradient(
                top: sky.top,
                bottom: sky.bottom,
                mid: sky.mid
            )
        }
        m.isDoubleSided = true
        m.cullMode = .front
        return m
    }
}
