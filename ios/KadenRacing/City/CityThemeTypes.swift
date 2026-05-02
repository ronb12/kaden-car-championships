import Foundation

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

// MARK: - 30 global cities (data-only identities)

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

    /// Display names avoid trademarked city brands; evoke geography only.
    var displayName: String {
        switch self {
        case .libertyMetro: return "Liberty Metro"
        case .pacificTerrace: return "Pacific Terrace"
        case .gulfSpires: return "Gulf Spires"
        case .thamesHollow: return "Thames Hollow"
        case .sunsetStripBay: return "Sunset Strip Bay"
        case .coralNeonShores: return "Coral Neon Shores"
        case .bayGraniteHills: return "Bay Granite Hills"
        case .sugarloafCoastal: return "Sugarloaf Coastal"
        case .desertLuxStrip: return "Desert Lux Strip"
        case .greatLakesWorks: return "Great Lakes Works"
        case .capitolGrid: return "Capitol Grid"
        case .emeraldRainBay: return "Emerald Rain Bay"
        case .volcanoRing: return "Volcano Ring"
        case .monolithFoundry: return "Monolith Foundry"
        case .redRockRun: return "Red Rock Run"
        case .frostHarbor: return "Frost Harbor"
        case .rioGrandeDust: return "Rio Grande Dust"
        case .alpinePassRing: return "Alpine Pass Ring"
        case .harborPearlDelta: return "Harbor Pearl Delta"
        case .saigonRiverArc: return "Saigon River Arc"
        case .sydneyHarborLoop: return "Sydney Harbor Loop"
        case .frostKremlinRun: return "Frost Kremlin Run"
        case .berlinVelocityLoop: return "Berlin Velocity Loop"
        case .parisBelleGrande: return "Paris Belle Grande"
        case .cairoSandCircuit: return "Cairo Sand Circuit"
        case .lagosPulseBay: return "Lagos Pulse Bay"
        case .seoulVoltageGrid: return "Seoul Voltage Grid"
        case .mumbaiMonsoonMaze: return "Mumbai Monsoon Maze"
        case .johannesburgRidge: return "Johannesburg Ridge"
        case .aucklandBreezeCoast: return "Auckland Breeze Coast"
        }
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
