import SceneKit
import UIKit

/// Central PBR material factory — asphalt, concrete, wet surfaces, glass, terrain.
enum EnvironmentMaterialLibrary {

    private static var cache: [String: SCNMaterial] = [:]

    static func asphalt(
        definition: CityThemeDefinition,
        night: Bool,
        wet: Bool
    ) -> SCNMaterial {
        let key = "env-asphalt-v10-\(definition.id.rawValue)-\(night)-\(wet)"
        if let m = cache[key] { return m.copy() as? SCNMaterial ?? m }

        let m = AssetManager.asphaltMaterial(definition: definition, night: night, wet: wet)
        cache[key] = m
        return m.copy() as? SCNMaterial ?? m
    }

    static func concrete(night: Bool) -> SCNMaterial {
        cached(key: "env-concrete-\(night)") {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor(
                red: night ? 0.22 : 0.58,
                green: night ? 0.22 : 0.56,
                blue: night ? 0.24 : 0.54,
                alpha: 1
            )
            m.roughness.contents = 0.78
            m.metalness.contents = 0.04
            return m
        }
    }

    static func paintedLine(white: Bool, night: Bool) -> SCNMaterial {
        cached(key: "env-line-\(white)-\(night)") {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = white
                ? UIColor(white: night ? 0.88 : 0.96, alpha: 1)
                : UIColor(red: 0.92, green: 0.12, blue: 0.1, alpha: 1)
            m.emission.contents = night ? m.diffuse.contents : UIColor.black
            m.roughness.contents = 0.55
            m.metalness.contents = 0.02
            return m
        }
    }

    static func metalRailing(night: Bool) -> SCNMaterial {
        cached(key: "env-metal-rail-\(night)") {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor(white: night ? 0.35 : 0.72, alpha: 1)
            m.metalness.contents = 0.88
            m.roughness.contents = 0.28
            return m
        }
    }

    static func oceanSurface(night: Bool, wetWeather: Bool) -> SCNMaterial {
        cached(key: "env-ocean-\(night)-\(wetWeather)") {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor(
                red: night ? 0.02 : 0.05,
                green: night ? 0.08 : 0.22,
                blue: night ? 0.14 : 0.38,
                alpha: 1
            )
            m.metalness.contents = wetWeather ? 0.35 : 0.18
            m.roughness.contents = wetWeather ? 0.28 : 0.42
            m.reflective.contents = UIColor(white: night ? 0.08 : 0.12, alpha: 1)
            m.reflective.wrapS = .clamp
            m.reflective.wrapT = .clamp
            m.isDoubleSided = true
            return m
        }
    }

    static func glassFacade(night: Bool) -> SCNMaterial {
        cached(key: "env-glass-\(night)") {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1)
            m.metalness.contents = 0.12
            m.roughness.contents = 0.08
            m.transparency = night ? 0.22 : 0.35
            m.transparencyMode = .rgbZero
            if night {
                m.emission.contents = UIColor(red: 0.35, green: 0.55, blue: 0.95, alpha: 0.4)
            }
            return m
        }
    }

    static func grassTerrain(definition: CityThemeDefinition, night: Bool) -> SCNMaterial {
        AssetManager.grassMaterial(definition: definition, night: night)
    }

    static func sidewalkShoulder(night: Bool) -> SCNMaterial {
        cached(key: "env-sidewalk-shoulder-\(night)") {
            let m = SCNMaterial()
            m.lightingModel = .lambert
            m.diffuse.contents = night
                ? UIColor(red: 0.22, green: 0.21, blue: 0.20, alpha: 1)
                : UIColor(red: 0.56, green: 0.53, blue: 0.48, alpha: 1)
            m.roughness.contents = 0.94
            m.metalness.contents = 0
            m.multiply.contents = UIColor(white: night ? 0.9 : 0.98, alpha: 1)
            return m
        }
    }

    static func sandShoulder(night: Bool, tint: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .lambert
        m.diffuse.contents = KRCProceduralTextures.runoffGravel(tint: tint, night: night)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(10, 10, 1)
        m.roughness.contents = 0.96
        m.metalness.contents = 0
        return m
    }

    static func dirt(night: Bool) -> SCNMaterial {
        cached(key: "env-dirt-\(night)") {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor(
                red: night ? 0.12 : 0.34,
                green: night ? 0.10 : 0.28,
                blue: night ? 0.08 : 0.18,
                alpha: 1
            )
            m.roughness.contents = 0.92
            m.metalness.contents = 0
            return m
        }
    }

    static func stone(night: Bool) -> SCNMaterial {
        cached(key: "env-stone-\(night)") {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor(white: night ? 0.18 : 0.42, alpha: 1)
            m.roughness.contents = 0.86
            m.metalness.contents = 0.02
            return m
        }
    }

    static func mountainRock(night: Bool) -> SCNMaterial {
        cached(key: "env-mtn-rock-\(night)") {
            let tint = UIColor(
                red: night ? 0.14 : 0.32,
                green: night ? 0.13 : 0.30,
                blue: night ? 0.12 : 0.28,
                alpha: 1
            )
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = KRCProceduralTextures.runoffGravel(tint: tint, night: night)
            m.diffuse.wrapS = .repeat
            m.diffuse.wrapT = .repeat
            m.diffuse.contentsTransform = SCNMatrix4MakeScale(4, 4, 1)
            m.roughness.contents = 0.9
            m.metalness.contents = 0.01
            return m
        }
    }

    static func shoreFoam(night: Bool, rainy: Bool) -> SCNMaterial {
        cached(key: "env-shore-foam-\(night)-\(rainy)") {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = UIColor(
                red: night ? 0.55 : 0.88,
                green: night ? 0.58 : 0.92,
                blue: night ? 0.62 : 0.95,
                alpha: 1
            )
            m.emission.contents = night
                ? UIColor(white: 0.25, alpha: rainy ? 0.35 : 0.2)
                : UIColor(white: rainy ? 0.45 : 0.28, alpha: 1)
            m.roughness.contents = 0.35
            m.metalness.contents = 0.02
            m.transparency = rainy ? 0.55 : 0.48
            m.transparencyMode = .aOne
            m.isDoubleSided = true
            return m
        }
    }

    private static func cached(key: String, make: () -> SCNMaterial) -> SCNMaterial {
        if let m = cache[key] { return m.copy() as? SCNMaterial ?? m }
        let m = make()
        cache[key] = m
        return m.copy() as? SCNMaterial ?? m
    }
}
