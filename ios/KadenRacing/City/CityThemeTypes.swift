import Foundation
import UIKit

// MARK: - Module taxonomy (used for rules + decoration — not 30 separate maps)

enum RoadModuleKind: String, Codable, CaseIterable {
    case straight
    case curveEasy
    case curveTight
    case intersectionGrid
    case highwaySweep
    case bridgeSpan
    case coastalSweep
    case hillClimb
}

enum BuildingBlockKind: String, Codable, CaseIterable {
    case lowRise
    case highRise
    case industrial
    case residential
    case neonTower
    case desertCompound
    case coastalResort
}

enum PropKind: String, Codable, CaseIterable {
    case streetLight
    case signage
    case barrier
    case trafficCone
    case palm
    case gantry
}

enum TerrainVariant: String, Codable, CaseIterable {
    case flat
    case rolling
    case stepped
    case coastal
    case canyon
}

enum CityVisualTheme: String, Codable, CaseIterable {
    case urbanDense
    case desertHighway
    case coastalNeon
    case industrialPort
    case alpine
    case tropical
    case neonNight
    case historicNarrow
    case luxuryBoulevard
    case monsoonWet
}

enum LightingProfile: String, Codable, CaseIterable {
    case dayClear
    case goldenHour
    case nightNeon
    case nightSoft
    case rainOvercast
    case fogMist
    case duskOrange

    var prefersDarkAmbient: Bool {
        switch self {
        case .nightNeon, .nightSoft, .duskOrange: return true
        default: return false
        }
    }

    var forceNightGeometry: Bool {
        switch self {
        case .nightNeon, .nightSoft: return true
        default: return false
        }
    }
}

enum EnvironmentalEffect: String, Codable, CaseIterable {
    case none
    case lightRain
    case heavyFog
    case heatHaze
    case oceanMist
    case dust
}

enum CityLayoutMode: Equatable {
    /// Procedural closed circuit from theme + seed.
    case procedural
    /// Fixed layout index for authored career routes (same seed + module order).
    case career(layoutIndex: Int)
}

// MARK: - 30 real-world cities (visual themes are geography-inspired, not official branding)

enum CityThemeID: Int, CaseIterable, Identifiable {
    case libertyMetro = 0
    case pacificTerrace
    case gulfSpires
    case thamesHollow
    case sunsetStripBay
    case coralNeonShores
    case bayGraniteHills
    case sugarloafCoastal
    case desertLuxStrip
    case greatLakesWorks
    case capitolGrid
    case emeraldRainBay
    case volcanoRing
    case monolithFoundry
    case redRockRun
    case frostHarbor
    case rioGrandeDust
    case alpinePassRing
    case harborPearlDelta
    case saigonRiverArc
    case sydneyHarborLoop
    case frostKremlinRun
    case berlinVelocityLoop
    case parisBelleGrande
    case cairoSandCircuit
    case lagosPulseBay
    case seoulVoltageGrid
    case mumbaiMonsoonMaze
    case johannesburgRidge
    case aucklandBreezeCoast

    var id: Int { rawValue }

    /// Real-world city name (inspired by geography; not official branding).
    var cityName: String {
        switch self {
        case .libertyMetro: return "New York City"
        case .pacificTerrace: return "Tokyo"
        case .gulfSpires: return "Dubai"
        case .thamesHollow: return "London"
        case .sunsetStripBay: return "Los Angeles"
        case .coralNeonShores: return "Miami"
        case .bayGraniteHills: return "San Francisco"
        case .sugarloafCoastal: return "Rio de Janeiro"
        case .desertLuxStrip: return "Las Vegas"
        case .greatLakesWorks: return "Chicago"
        case .capitolGrid: return "Washington, D.C."
        case .emeraldRainBay: return "Dublin"
        case .volcanoRing: return "Honolulu"
        case .monolithFoundry: return "Detroit"
        case .redRockRun: return "Phoenix"
        case .frostHarbor: return "Seattle"
        case .rioGrandeDust: return "Mexico City"
        case .alpinePassRing: return "Zurich"
        case .harborPearlDelta: return "Hong Kong"
        case .saigonRiverArc: return "Ho Chi Minh City"
        case .sydneyHarborLoop: return "Sydney"
        case .frostKremlinRun: return "Moscow"
        case .berlinVelocityLoop: return "Berlin"
        case .parisBelleGrande: return "Paris"
        case .cairoSandCircuit: return "Cairo"
        case .lagosPulseBay: return "Lagos"
        case .seoulVoltageGrid: return "Seoul"
        case .mumbaiMonsoonMaze: return "Mumbai"
        case .johannesburgRidge: return "Johannesburg"
        case .aucklandBreezeCoast: return "Auckland"
        }
    }

    var countryName: String {
        switch self {
        case .libertyMetro, .sunsetStripBay, .coralNeonShores, .bayGraniteHills, .desertLuxStrip,
             .greatLakesWorks, .capitolGrid, .volcanoRing, .monolithFoundry, .redRockRun, .frostHarbor:
            return "United States"
        case .pacificTerrace: return "Japan"
        case .gulfSpires: return "United Arab Emirates"
        case .thamesHollow, .emeraldRainBay: return "United Kingdom"
        case .sugarloafCoastal: return "Brazil"
        case .alpinePassRing: return "Switzerland"
        case .harborPearlDelta: return "China"
        case .saigonRiverArc: return "Vietnam"
        case .sydneyHarborLoop, .aucklandBreezeCoast: return "Australia"
        case .frostKremlinRun: return "Russia"
        case .berlinVelocityLoop: return "Germany"
        case .parisBelleGrande: return "France"
        case .cairoSandCircuit: return "Egypt"
        case .lagosPulseBay: return "Nigeria"
        case .seoulVoltageGrid: return "South Korea"
        case .mumbaiMonsoonMaze: return "India"
        case .johannesburgRidge: return "South Africa"
        case .rioGrandeDust: return "Mexico"
        }
    }

    /// Short atmosphere line for menus.
    var localeTagline: String {
        switch self {
        case .libertyMetro: return "Midtown grid · neon nights"
        case .pacificTerrace: return "Shibuya lights · tight streets"
        case .gulfSpires: return "Desert towers · golden heat"
        case .thamesHollow: return "River bends · grey rain"
        case .sunsetStripBay: return "Pacific coast · palm highways"
        case .coralNeonShores: return "Ocean drive · art-deco glow"
        case .bayGraniteHills: return "Bay bridges · steep grades"
        case .sugarloafCoastal: return "Harbor curves · tropical hills"
        case .desertLuxStrip: return "Casino strip · desert night"
        case .greatLakesWorks: return "Lakefront industry · dusk fog"
        case .capitolGrid: return "Monument avenues · clear grid"
        case .emeraldRainBay: return "Coastal rain · rolling lanes"
        case .volcanoRing: return "Island ring · volcanic coast"
        case .monolithFoundry: return "Factory skyline · night haze"
        case .redRockRun: return "Canyon heat · red dust"
        case .frostHarbor: return "Puget mist · wet asphalt"
        case .rioGrandeDust: return "High plateau · dusty avenues"
        case .alpinePassRing: return "Mountain pass · crisp air"
        case .harborPearlDelta: return "Victoria Harbour · neon rain"
        case .saigonRiverArc: return "River delta · scooter flow"
        case .sydneyHarborLoop: return "Opera coast · golden hour"
        case .frostKremlinRun: return "Wide boulevards · winter fog"
        case .berlinVelocityLoop: return "Spree banks · modern grid"
        case .parisBelleGrande: return "Seine curves · limestone glow"
        case .cairoSandCircuit: return "Nile edge · desert sun"
        case .lagosPulseBay: return "Atlantic coast · humid streets"
        case .seoulVoltageGrid: return "Gangnam grid · electric night"
        case .mumbaiMonsoonMaze: return "Monsoon lanes · dense traffic"
        case .johannesburgRidge: return "Highveld ridges · gold dusk"
        case .aucklandBreezeCoast: return "Waitematā breeze · harbours"
        }
    }

    var displayName: String { "\(cityName), \(countryName)" }

    /// Asset catalog name for bundled skyline photo (`CityCard*.imageset`).
    var previewCardAssetName: String {
        Self.previewCardAssetNames[rawValue]
    }

    var hasPreviewCardPhoto: Bool {
        UIImage(named: previewCardAssetName) != nil
    }

    /// Card backdrop colors (parity with web `CITY_DEFS[].previewGrad`).
    var previewCardColors: [UIColor] {
        Self.previewGradients[rawValue]
    }

    var previewShowsNightSky: Bool {
        switch self {
        case .libertyMetro, .pacificTerrace, .desertLuxStrip, .monolithFoundry,
             .harborPearlDelta, .seoulVoltageGrid:
            return true
        default:
            return false
        }
    }

    var previewShowsSunset: Bool {
        switch self {
        case .gulfSpires, .coralNeonShores, .saigonRiverArc, .sydneyHarborLoop,
             .parisBelleGrande, .johannesburgRidge:
            return true
        default:
            return false
        }
    }

    private static let previewCardAssetNames: [String] = [
        "CityCardLibertyMetro", "CityCardPacificTerrace", "CityCardGulfSpires",
        "CityCardThamesHollow", "CityCardSunsetStripBay", "CityCardCoralNeonShores",
        "CityCardBayGraniteHills", "CityCardSugarloafCoastal", "CityCardDesertLuxStrip",
        "CityCardGreatLakesWorks", "CityCardCapitolGrid", "CityCardEmeraldRainBay",
        "CityCardVolcanoRing", "CityCardMonolithFoundry", "CityCardRedRockRun",
        "CityCardFrostHarbor", "CityCardRioGrandeDust", "CityCardAlpinePassRing",
        "CityCardHarborPearlDelta", "CityCardSaigonRiverArc", "CityCardSydneyHarborLoop",
        "CityCardFrostKremlinRun", "CityCardBerlinVelocityLoop", "CityCardParisBelleGrande",
        "CityCardCairoSandCircuit", "CityCardLagosPulseBay", "CityCardSeoulVoltageGrid",
        "CityCardMumbaiMonsoonMaze", "CityCardJohannesburgRidge", "CityCardAucklandBreezeCoast"
    ]

    private static let previewGradients: [[UIColor]] = [
        [rgb(0x050810), rgb(0x2244AA), rgb(0xFF2266)], // NYC
        [rgb(0x02030A), rgb(0x0044FF), rgb(0xFF00CC)], // Tokyo
        [rgb(0xE8642A), rgb(0xD4A040), rgb(0xC4A820)], // Dubai
        [rgb(0x8A9AAA), rgb(0xC0C8D0), rgb(0x4A6A38)], // London
        [rgb(0x6ABAED), rgb(0xF5DEB3), rgb(0x5A8A30)], // LA
        [rgb(0xFF7744), rgb(0xFFCCAA), rgb(0x2A6A20)], // Miami
        [rgb(0x6ABAED), rgb(0xF5DEB3), rgb(0x5A8A30)], // SF (LA palette)
        [rgb(0x5AC8EE), rgb(0xFFF0C0), rgb(0x4A9A38)], // Rio
        [rgb(0x0A0518), rgb(0xFF00CC), rgb(0xFFCC00)], // Vegas
        [rgb(0xA08060), rgb(0xC8B8A8), rgb(0x4A5A38)], // Chicago
        [rgb(0x6ABAED), rgb(0xF5DEB3), rgb(0x5A8A30)], // DC
        [rgb(0x7A9A88), rgb(0xB8D0C0), rgb(0x3D6A32)], // Dublin
        [rgb(0x5AC8EE), rgb(0xFFF0C0), rgb(0x4A9A38)], // Honolulu
        [rgb(0x080A12), rgb(0x334455), rgb(0x8899BB)], // Detroit
        [rgb(0x88C8F0), rgb(0xFFE8B0), rgb(0xC8A858)], // Phoenix
        [rgb(0x98A8B8), rgb(0xD0DCE8), rgb(0x3A5A30)], // Seattle
        [rgb(0x9AC8E8), rgb(0xFFE0A0), rgb(0x8A9A48)], // Mexico City
        [rgb(0x78B8E8), rgb(0xF0F8FF), rgb(0x4A8A38)], // Zurich
        [rgb(0x040810), rgb(0x0088FF), rgb(0xFF0044)], // Hong Kong
        [rgb(0xCC8866), rgb(0xFFCCAA), rgb(0x3A7A28)], // Saigon
        [rgb(0xF08040), rgb(0xFFD8B0), rgb(0x4A8A30)], // Sydney
        [rgb(0x8898A8), rgb(0xD8E0E8), rgb(0x4A5A40)], // Moscow
        [rgb(0x72B0E8), rgb(0xFFF0D0), rgb(0x4A7A32)], // Berlin
        [rgb(0xE8A060), rgb(0xFFE0C0), rgb(0x5A8A38)], // Paris
        [rgb(0xA8D0F0), rgb(0xFFE8A8), rgb(0xC8B060)], // Cairo
        [rgb(0x88A8C8), rgb(0xC8D8E8), rgb(0x3A7A28)], // Lagos
        [rgb(0x03050C), rgb(0x00AAFF), rgb(0xFF00AA)], // Seoul
        [rgb(0x788898), rgb(0xB0C0C8), rgb(0x3A6A30)], // Mumbai
        [rgb(0xD87838), rgb(0xFFC8A0), rgb(0x6A8A38)], // Johannesburg
        [rgb(0x68B8E8), rgb(0xF0FAFF), rgb(0x4A9A38)]  // Auckland
    ]

    private static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Authoring data for one city — drives generator weights, not a baked map file.
struct CityThemeDefinition {
    let id: CityThemeID
    let visualTheme: CityVisualTheme
    let lighting: LightingProfile
    let environment: EnvironmentalEffect
    /// 0...1
    let trafficDensity: Float
    /// 0...1 police aggression scaler
    let policeDifficulty: Float
    let terrain: TerrainVariant
    /// Biased module picks for decor / future AI lanes.
    let roadWeights: [RoadModuleKind: Float]
    let buildingWeights: [BuildingBlockKind: Float]
    let propWeights: [PropKind: Float]
    /// Base oval scale (meters-ish in scene units).
    let semiMajor: Float
    let semiMinor: Float
    /// Fourier terms for track wobble; higher = more corners.
    let curvatureComplexity: Int
    /// Vertical exaggeration for hills.
    let elevationScale: Float
    /// Points sampled around the loop (96–160 typical).
    let trackResolution: Int
}
