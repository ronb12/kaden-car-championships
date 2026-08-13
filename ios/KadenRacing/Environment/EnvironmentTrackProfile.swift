import UIKit

/// Authored environment presets tied to catalog tracks — ocean, terrain, and decor density.
enum EnvironmentTrackProfile: String, Codable, Equatable {
    case standard
    case coastalCityCircuit
    case coastalOpen
    case desertHighway
    case alpineRidge
    case speedwayOval
    case urbanNight
    case stormHarbor
    case technicalCircuit

    static let coastalCityCircuitTrackIndex = 20

    static func from(catalogTrackIndex: Int?) -> EnvironmentTrackProfile {
        guard let idx = catalogTrackIndex else { return .standard }
        if PalmCityEnvironment.isActive {
            return PalmCityRacewayTracks.layout(for: idx).prefersOcean ? .coastalOpen : .standard
        }
        if idx == coastalCityCircuitTrackIndex { return .coastalCityCircuit }
        if Self.coastalOpenIndices.contains(idx) { return .coastalOpen }
        if Self.desertHighwayIndices.contains(idx) { return .desertHighway }
        if Self.alpineRidgeIndices.contains(idx) { return .alpineRidge }
        if Self.speedwayOvalIndices.contains(idx) { return .speedwayOval }
        if Self.urbanNightIndices.contains(idx) { return .urbanNight }
        if Self.stormHarborIndices.contains(idx) { return .stormHarbor }
        if Self.technicalCircuitIndices.contains(idx) { return .technicalCircuit }
        return .standard
    }

    private static let coastalOpenIndices: Set<Int> = [
        0, 7, 11, 14, 21, 28, 32, 35, 41,
    ]
    private static let desertHighwayIndices: Set<Int> = [
        8, 12, 29, 36, 42,
    ]
    private static let alpineRidgeIndices: Set<Int> = [
        2, 9, 13, 23, 30, 34, 43,
    ]
    private static let speedwayOvalIndices: Set<Int> = [
        1, 3, 18, 22, 24, 39, 44,
    ]
    private static let urbanNightIndices: Set<Int> = [
        15, 19, 36, 40, 45,
    ]
    private static let stormHarborIndices: Set<Int> = [
        16, 37, 46,
    ]
    private static let technicalCircuitIndices: Set<Int> = [
        4, 5, 6, 10, 17, 25, 26, 27, 31, 33, 38, 47, 48,
    ]

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .coastalCityCircuit: return "Coastal City Circuit"
        case .coastalOpen: return "Coastal"
        case .desertHighway: return "Desert"
        case .alpineRidge: return "Alpine"
        case .speedwayOval: return "Speedway"
        case .urbanNight: return "Urban Night"
        case .stormHarbor: return "Storm Harbor"
        case .technicalCircuit: return "Technical"
        }
    }

    var prefersOcean: Bool {
        switch self {
        case .coastalCityCircuit, .coastalOpen, .stormHarbor: return true
        default: return false
        }
    }

    var prefersMountains: Bool {
        switch self {
        case .coastalCityCircuit, .alpineRidge, .stormHarbor: return true
        default: return false
        }
    }

    /// Subtle hill ring + peaks for depth on most outdoor circuits.
    var usesAtmosphericBackdrop: Bool {
        switch self {
        case .urbanNight: return false
        default: return true
        }
    }

    var decorDensityMultiplier: Float {
        switch self {
        case .coastalCityCircuit: return 1.12
        case .coastalOpen, .stormHarbor: return 1.06
        case .desertHighway, .alpineRidge: return 1.02
        case .urbanNight: return 1.10
        case .technicalCircuit: return 1.0
        default: return 0.94
        }
    }

    func foliageTint(definition: CityThemeDefinition) -> UIColor {
        switch self {
        case .coastalCityCircuit, .coastalOpen, .stormHarbor:
            return UIColor(red: 0.14, green: 0.46, blue: 0.20, alpha: 1)
        case .desertHighway:
            return UIColor(red: 0.42, green: 0.38, blue: 0.22, alpha: 1)
        case .alpineRidge:
            return UIColor(red: 0.20, green: 0.42, blue: 0.24, alpha: 1)
        case .urbanNight:
            return UIColor(red: 0.10, green: 0.28, blue: 0.14, alpha: 1)
        case .speedwayOval, .technicalCircuit, .standard:
            let coastal = definition.terrain == .coastal
            return UIColor(
                red: coastal ? 0.16 : 0.14,
                green: coastal ? 0.40 : 0.34,
                blue: coastal ? 0.16 : 0.18,
                alpha: 1
            )
        }
    }

    /// Default city theme when this track is selected (visual identity per circuit).
    var suggestedCityTheme: CityThemeID {
        switch self {
        case .coastalCityCircuit, .coastalOpen, .stormHarbor:
            return .sydneyHarborLoop
        case .desertHighway:
            return .redRockRun
        case .alpineRidge:
            return .alpinePassRing
        case .urbanNight:
            return .libertyMetro
        case .speedwayOval:
            return .gulfSpires
        case .technicalCircuit:
            return .berlinVelocityLoop
        case .standard:
            return .sunsetStripBay
        }
    }

    /// Base hue for track-select card art (each index offsets from this).
    var trackCardHueBase: CGFloat {
        switch self {
        case .coastalCityCircuit, .coastalOpen: return 0.54
        case .stormHarbor: return 0.58
        case .desertHighway: return 0.07
        case .alpineRidge: return 0.32
        case .urbanNight: return 0.78
        case .speedwayOval: return 0.11
        case .technicalCircuit: return 0.46
        case .standard: return 0.62
        }
    }

    func groundTint(definition: CityThemeDefinition, night: Bool) -> UIColor {
        switch self {
        case .desertHighway:
            return UIColor(red: 0.52, green: 0.44, blue: 0.30, alpha: 1)
        case .alpineRidge:
            return UIColor(red: 0.36, green: 0.40, blue: 0.38, alpha: 1)
        case .coastalCityCircuit, .coastalOpen, .stormHarbor:
            return UIColor(red: 0.46, green: 0.40, blue: 0.28, alpha: 1)
        case .urbanNight:
            return UIColor(red: 0.12, green: 0.14, blue: 0.16, alpha: 1)
        default:
            return AssetManager.ground(definition: definition, night: night)
        }
    }
}
