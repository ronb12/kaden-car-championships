import UIKit
import simd

enum VehiclePaintFinish: String, CaseIterable {
    case gloss
    case metallic
    case matte
    case pearl
}

enum VehicleBodyStyle: String, CaseIterable {
    case hyperWedge
    case midEngineSuper
    case exoticWide
    case sportsCoupe
    case muscle
    case tuner
    case sedanGT
    case roadster
    case policeInterceptor
}

enum VehicleWheelStyle: String, CaseIterable {
    case sport5
    case deepDish
    case rally
    case hyper
    case muscle
    case chromeLux
}

enum VehicleHeadlightStyle {
    case quadRound
    case slimLED
    case aggressiveSplit
}

/// Per-car visual DNA — silhouette, paint, wheels, bundled mesh eligibility.
struct VehicleVisualProfile {
    let carId: String
    let bodyStyle: VehicleBodyStyle
    let paintFinish: VehiclePaintFinish
    let wheelStyle: VehicleWheelStyle
    let headlightStyle: VehicleHeadlightStyle
    let dimensions: SIMD3<Float>
    let rideHeight: Float
    let usesBundledMesh: Bool
    let accentTrim: UIColor?

    var paintDescriptor: VehicleMaterialLibrary.PaintDescriptor {
        let car = GameCatalog.cars.first { $0.id == carId }
        let color: UIColor
        if let car {
            color = GarageCustomization.bodyColor(for: car)
        } else {
            color = .red
        }
        var flake: Float = 0.3
        var clear: Float = 0.2
        switch paintFinish {
        case .gloss: flake = 0.06; clear = 1.0
        case .metallic: flake = 0.42; clear = 0.92
        case .matte: flake = 0; clear = 0
        case .pearl: flake = 0.52; clear = 0.98
        }
        return VehicleMaterialLibrary.PaintDescriptor(
            color: color,
            finish: paintFinish,
            flake: flake,
            clearCoat: clear
        )
    }

    static func profile(carId: String) -> VehicleVisualProfile {
        let category = GameCatalog.vehicleCategory(for: carId)
        let style = bodyStyle(for: carId, category: category)
        let rimOverride = GarageCustomization.style(for: carId).rim.wheelStyle
        return VehicleVisualProfile(
            carId: carId,
            bodyStyle: style,
            paintFinish: paintFinish(for: carId, style: style),
            wheelStyle: rimOverride ?? wheelStyle(for: carId, style: style),
            headlightStyle: headlightStyle(for: style),
            dimensions: dimensions(for: style, carId: carId),
            rideHeight: rideHeight(for: style),
            usesBundledMesh: true,
            accentTrim: accent(for: carId)
        )
    }

  private static func bodyStyle(for carId: String, category: VehicleCategory) -> VehicleBodyStyle {
        if carId == "police" { return .policeInterceptor }
        switch carId {
        case "bugatti", "koenigsegg", "jesko", "senna", "mclaren": return .hyperWedge
        case "lambo", "huracan": return .exoticWide
        case "f40", "corvette", "nsx", "audi-r8": return .midEngineSuper
        case "gtr", "supra", "rx7", "911", "m4", "r34", "r35-nismo": return .sportsCoupe
        case "mustang", "camaro", "challenger", "charger", "viper", "gt500": return .muscle
        case "evo", "sti", "civic": return .tuner
        case "amg", "rs7": return .sedanGT
        case "s2000": return .roadster
        default:
            switch category {
            case .hypercar: return .hyperWedge
            case .supercar: return .midEngineSuper
            case .muscle: return .muscle
            case .compact: return .tuner
            case .policeInterceptor: return .policeInterceptor
            case .sports: return .sportsCoupe
            }
        }
    }

    private static func paintFinish(for carId: String, style: VehicleBodyStyle) -> VehiclePaintFinish {
        switch carId {
        case "amg", "charger", "police": return .matte
        case "bugatti", "audi-r8", "rs7", "viper": return .metallic
        case "lambo", "huracan", "jesko", "koenigsegg": return .pearl
        default:
            switch style {
            case .hyperWedge, .exoticWide: return .pearl
            case .muscle: return .gloss
            case .tuner: return .gloss
            default: return .metallic
            }
        }
    }

    private static func wheelStyle(for carId: String, style: VehicleBodyStyle) -> VehicleWheelStyle {
        switch style {
        case .hyperWedge, .exoticWide: return .hyper
        case .muscle: return .muscle
        case .tuner: return .rally
        case .sedanGT: return .chromeLux
        case .roadster: return .sport5
        case .policeInterceptor: return .chromeLux
        default: return .sport5
        }
    }

    private static func headlightStyle(for style: VehicleBodyStyle) -> VehicleHeadlightStyle {
        switch style {
        case .hyperWedge, .exoticWide: return .slimLED
        case .muscle, .policeInterceptor: return .quadRound
        default: return .aggressiveSplit
        }
    }

    private static func dimensions(for style: VehicleBodyStyle, carId: String) -> SIMD3<Float> {
        switch style {
        case .hyperWedge: return SIMD3(1.88, 0.9, 4.62)
        case .exoticWide: return SIMD3(2.12, 0.96, 4.44)
        case .midEngineSuper: return SIMD3(1.94, 0.9, 4.32)
        case .sportsCoupe: return SIMD3(1.96, 0.9, 4.26)
        case .muscle: return SIMD3(2.14, 0.98, 4.68)
        case .tuner: return SIMD3(1.9, 0.88, 4.08)
        case .sedanGT: return SIMD3(2.02, 0.96, 4.78)
        case .roadster: return SIMD3(1.84, 0.8, 3.92)
        case .policeInterceptor: return SIMD3(2.1, 1.0, 4.72)
        }
    }

    private static func rideHeight(for style: VehicleBodyStyle) -> Float {
        switch style {
        case .hyperWedge, .midEngineSuper: return 0.34
        case .tuner: return 0.38
        case .sedanGT: return 0.4
        default: return 0.36
        }
    }

    private static func accent(for carId: String) -> UIColor? {
        switch carId {
        case "gtr", "r34", "r35-nismo": return UIColor(red: 0.9, green: 0.75, blue: 0.1, alpha: 1)
        case "police": return UIColor(white: 0.95, alpha: 1) // white trim accents on black body
        default: return nil
        }
    }
}
