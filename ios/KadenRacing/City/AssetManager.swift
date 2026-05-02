import SceneKit
import UIKit

/// Caches **materials and light colors** per city theme to cut duplicate state and speed theme swaps.
enum AssetManager {

    private static var asphaltCache: [Int: UIColor] = [:]
    private static var groundCache: [Int: UIColor] = [:]
    private static var skyCache: [Int: UIColor] = [:]

    static func asphalt(definition: CityThemeDefinition, night: Bool) -> UIColor {
        let k = definition.id.rawValue * 10 + (night ? 1 : 0)
        if let c = asphaltCache[k] { return c }
        let base: (CGFloat, CGFloat, CGFloat) = {
            switch definition.visualTheme {
            case .desertHighway: return (0.12, 0.11, 0.1)
            case .coastalNeon, .tropical, .monsoonWet: return (0.1, 0.12, 0.11)
            case .industrialPort: return (0.11, 0.1, 0.1)
            case .alpine: return (0.1, 0.11, 0.12)
            case .neonNight: return (0.07, 0.08, 0.1)
            case .urbanDense, .luxuryBoulevard, .historicNarrow: return (0.1, 0.1, 0.12)
            }
        }()
        let m: CGFloat = night ? 0.75 : 1
        let c = UIColor(red: base.0 * m, green: base.1 * m, blue: base.2 * m, alpha: 1)
        asphaltCache[k] = c
        return c
    }

    static func ground(definition: CityThemeDefinition, night: Bool) -> UIColor {
        let k = definition.id.rawValue * 10 + (night ? 3 : 2)
        if let c = groundCache[k] { return c }
        let c: UIColor
        switch definition.terrain {
        case .coastal:
            c = UIColor(red: night ? 0.07 : 0.16, green: night ? 0.2 : 0.44, blue: night ? 0.12 : 0.22, alpha: 1)
        case .canyon, .rolling:
            c = UIColor(red: night ? 0.1 : 0.2, green: night ? 0.18 : 0.38, blue: night ? 0.08 : 0.16, alpha: 1)
        case .flat, .stepped:
            c = UIColor(red: night ? 0.08 : 0.18, green: night ? 0.18 : 0.46, blue: night ? 0.1 : 0.2, alpha: 1)
        }
        groundCache[k] = c
        return c
    }

    static func sky(definition: CityThemeDefinition, night: Bool) -> UIColor {
        let k = definition.id.rawValue * 10 + (night ? 5 : 4)
        if let c = skyCache[k] { return c }
        let out: UIColor
        if night, definition.lighting == .dayClear || definition.lighting == .goldenHour {
            out = UIColor(red: 0.04, green: 0.07, blue: 0.15, alpha: 1)
        } else {
            switch definition.lighting {
            case .dayClear, .goldenHour:
                out = UIColor(red: 0.45, green: 0.72, blue: 0.98, alpha: 1)
            case .nightNeon, .nightSoft, .duskOrange:
                out = UIColor(red: 0.04, green: 0.07, blue: 0.15, alpha: 1)
            case .rainOvercast, .fogMist:
                out = UIColor(red: 0.25, green: 0.28, blue: 0.32, alpha: 1)
            }
        }
        skyCache[k] = out
        return out
    }
}
