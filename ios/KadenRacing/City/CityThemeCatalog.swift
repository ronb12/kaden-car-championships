import Foundation

/// All **30** global city configurations — modular rules only (no separate SceneKit scenes).
enum CityThemeCatalog {

    private static let themes: [CityThemeDefinition] = [
        T(.libertyMetro, .urbanDense, .nightNeon, .none, traffic: 0.92, police: 0.55, .flat,
          road: [.intersectionGrid: 0.35, .straight: 0.25, .curveEasy: 0.22, .curveTight: 0.18],
          build: [.highRise: 0.45, .lowRise: 0.3, .neonTower: 0.25],
          prop: [.streetLight: 0.45, .signage: 0.3, .barrier: 0.25],
          128, 78, 7, 0.25, 128),
        T(.pacificTerrace, .neonNight, .nightNeon, .none, traffic: 0.88, police: 0.48, .flat,
          road: [.curveTight: 0.3, .straight: 0.2, .highwaySweep: 0.25, .intersectionGrid: 0.25],
          build: [.neonTower: 0.5, .highRise: 0.35, .residential: 0.15],
          prop: [.gantry: 0.3, .streetLight: 0.4, .signage: 0.3],
          108, 86, 8, 0.2, 132),
        T(.gulfSpires, .desertHighway, .goldenHour, .heatHaze, traffic: 0.65, police: 0.4, .flat,
          road: [.highwaySweep: 0.5, .straight: 0.3, .bridgeSpan: 0.2],
          build: [.desertCompound: 0.4, .highRise: 0.45, .industrial: 0.15],
          prop: [.barrier: 0.4, .gantry: 0.35, .palm: 0.25],
          140, 70, 4, 0.12, 112),
        T(.thamesHollow, .historicNarrow, .rainOvercast, .lightRain, traffic: 0.78, police: 0.42, .flat,
          road: [.curveEasy: 0.35, .straight: 0.25, .intersectionGrid: 0.4],
          build: [.lowRise: 0.45, .residential: 0.35, .industrial: 0.2],
          prop: [.streetLight: 0.5, .barrier: 0.3, .trafficCone: 0.2],
          95, 82, 6, 0.08, 128),
        T(.sunsetStripBay, .luxuryBoulevard, .goldenHour, .heatHaze, traffic: 0.72, police: 0.38, .coastal,
          road: [.highwaySweep: 0.45, .coastalSweep: 0.35, .straight: 0.2],
          build: [.lowRise: 0.35, .coastalResort: 0.4, .neonTower: 0.25],
          prop: [.palm: 0.45, .signage: 0.35, .streetLight: 0.2],
          135, 68, 5, 0.1, 120),
        T(.coralNeonShores, .coastalNeon, .nightNeon, .oceanMist, traffic: 0.7, police: 0.44, .coastal,
          road: [.coastalSweep: 0.45, .curveEasy: 0.35, .straight: 0.2],
          build: [.coastalResort: 0.5, .neonTower: 0.35, .lowRise: 0.15],
          prop: [.palm: 0.5, .signage: 0.3, .streetLight: 0.2],
          118, 80, 6, 0.11, 124),
        T(.bayGraniteHills, .urbanDense, .dayClear, .none, traffic: 0.8, police: 0.46, .rolling,
          road: [.hillClimb: 0.35, .curveTight: 0.3, .straight: 0.2, .bridgeSpan: 0.15],
          build: [.highRise: 0.35, .residential: 0.4, .lowRise: 0.25],
          prop: [.barrier: 0.4, .trafficCone: 0.35, .streetLight: 0.25],
          105, 88, 7, 0.45, 136),
        T(.sugarloafCoastal, .tropical, .goldenHour, .oceanMist, traffic: 0.62, police: 0.35, .coastal,
          road: [.coastalSweep: 0.5, .curveTight: 0.25, .hillClimb: 0.25],
          build: [.coastalResort: 0.45, .lowRise: 0.35, .residential: 0.2],
          prop: [.palm: 0.55, .barrier: 0.25, .signage: 0.2],
          122, 74, 8, 0.22, 118),
        T(.desertLuxStrip, .desertHighway, .nightNeon, .dust, traffic: 0.58, police: 0.52, .flat,
          road: [.highwaySweep: 0.55, .straight: 0.3, .intersectionGrid: 0.15],
          build: [.neonTower: 0.45, .desertCompound: 0.35, .lowRise: 0.2],
          prop: [.signage: 0.45, .gantry: 0.35, .streetLight: 0.2],
          150, 62, 4, 0.08, 108),
        T(.greatLakesWorks, .industrialPort, .duskOrange, .heavyFog, traffic: 0.75, police: 0.48, .flat,
          road: [.straight: 0.35, .intersectionGrid: 0.35, .curveEasy: 0.3],
          build: [.industrial: 0.55, .lowRise: 0.25, .residential: 0.2],
          prop: [.barrier: 0.45, .trafficCone: 0.35, .gantry: 0.2],
          110, 84, 5, 0.06, 126),
        T(.capitolGrid, .urbanDense, .dayClear, .none, traffic: 0.85, police: 0.5, .flat,
          road: [.intersectionGrid: 0.45, .straight: 0.35, .curveEasy: 0.2],
          build: [.highRise: 0.4, .lowRise: 0.35, .residential: 0.25],
          prop: [.streetLight: 0.4, .signage: 0.35, .barrier: 0.25],
          120, 76, 5, 0.12, 122),
        T(.emeraldRainBay, .urbanDense, .rainOvercast, .lightRain, traffic: 0.68, police: 0.4, .rolling,
          road: [.curveEasy: 0.4, .bridgeSpan: 0.25, .straight: 0.35],
          build: [.lowRise: 0.5, .residential: 0.35, .industrial: 0.15],
          prop: [.streetLight: 0.45, .barrier: 0.35, .trafficCone: 0.2],
          102, 90, 6, 0.28, 130),
        T(.volcanoRing, .tropical, .goldenHour, .heatHaze, traffic: 0.55, police: 0.36, .canyon,
          road: [.hillClimb: 0.4, .curveTight: 0.35, .bridgeSpan: 0.25],
          build: [.lowRise: 0.45, .coastalResort: 0.35, .industrial: 0.2],
          prop: [.barrier: 0.45, .trafficCone: 0.3, .gantry: 0.25],
          98, 92, 9, 0.38, 140),
        T(.monolithFoundry, .industrialPort, .nightSoft, .heavyFog, traffic: 0.7, police: 0.55, .flat,
          road: [.straight: 0.4, .intersectionGrid: 0.35, .curveEasy: 0.25],
          build: [.industrial: 0.6, .highRise: 0.25, .lowRise: 0.15],
          prop: [.gantry: 0.4, .barrier: 0.35, .trafficCone: 0.25],
          115, 78, 5, 0.05, 116),
        T(.redRockRun, .desertHighway, .dayClear, .dust, traffic: 0.45, police: 0.33, .canyon,
          road: [.highwaySweep: 0.45, .hillClimb: 0.35, .curveEasy: 0.2],
          build: [.desertCompound: 0.55, .lowRise: 0.3, .industrial: 0.15],
          prop: [.barrier: 0.5, .signage: 0.3, .trafficCone: 0.2],
          132, 66, 6, 0.35, 114),
        T(.frostHarbor, .urbanDense, .fogMist, .heavyFog, traffic: 0.72, police: 0.41, .rolling,
          road: [.curveEasy: 0.45, .bridgeSpan: 0.3, .straight: 0.25],
          build: [.lowRise: 0.45, .highRise: 0.35, .residential: 0.2],
          prop: [.streetLight: 0.45, .barrier: 0.35, .trafficCone: 0.2],
          100, 86, 6, 0.24, 128),
        T(.rioGrandeDust, .desertHighway, .goldenHour, .dust, traffic: 0.5, police: 0.39, .flat,
          road: [.highwaySweep: 0.5, .straight: 0.35, .curveEasy: 0.15],
          build: [.desertCompound: 0.5, .lowRise: 0.35, .industrial: 0.15],
          prop: [.signage: 0.4, .barrier: 0.35, .gantry: 0.25],
          138, 72, 5, 0.1, 110),
        T(.alpinePassRing, .alpine, .dayClear, .none, traffic: 0.48, police: 0.37, .rolling,
          road: [.hillClimb: 0.45, .curveTight: 0.35, .bridgeSpan: 0.2],
          build: [.lowRise: 0.45, .residential: 0.35, .industrial: 0.2],
          prop: [.barrier: 0.45, .trafficCone: 0.35, .gantry: 0.2],
          94, 94, 9, 0.55, 144),
        T(.harborPearlDelta, .coastalNeon, .nightSoft, .oceanMist, traffic: 0.82, police: 0.47, .coastal,
          road: [.coastalSweep: 0.35, .highwaySweep: 0.35, .intersectionGrid: 0.3],
          build: [.highRise: 0.45, .neonTower: 0.35, .coastalResort: 0.2],
          prop: [.streetLight: 0.4, .signage: 0.35, .gantry: 0.25],
          124, 82, 6, 0.14, 126),
        T(.saigonRiverArc, .tropical, .duskOrange, .lightRain, traffic: 0.88, police: 0.52, .flat,
          road: [.curveTight: 0.35, .intersectionGrid: 0.4, .straight: 0.25],
          build: [.lowRise: 0.45, .neonTower: 0.35, .residential: 0.2],
          prop: [.streetLight: 0.45, .trafficCone: 0.3, .signage: 0.25],
          112, 84, 7, 0.16, 124),
        T(.sydneyHarborLoop, .coastalNeon, .goldenHour, .oceanMist, traffic: 0.68, police: 0.4, .coastal,
          road: [.coastalSweep: 0.5, .curveEasy: 0.3, .bridgeSpan: 0.2],
          build: [.coastalResort: 0.45, .highRise: 0.35, .lowRise: 0.2],
          prop: [.palm: 0.45, .barrier: 0.3, .streetLight: 0.25],
          118, 78, 6, 0.18, 120),
        T(.frostKremlinRun, .historicNarrow, .fogMist, .heavyFog, traffic: 0.74, police: 0.46, .flat,
          road: [.curveEasy: 0.35, .straight: 0.35, .intersectionGrid: 0.3],
          build: [.lowRise: 0.45, .highRise: 0.35, .residential: 0.2],
          prop: [.streetLight: 0.45, .barrier: 0.35, .signage: 0.2],
          104, 88, 6, 0.12, 130),
        T(.berlinVelocityLoop, .urbanDense, .dayClear, .none, traffic: 0.76, police: 0.49, .flat,
          road: [.highwaySweep: 0.45, .straight: 0.35, .curveEasy: 0.2],
          build: [.industrial: 0.35, .lowRise: 0.35, .highRise: 0.3],
          prop: [.gantry: 0.35, .streetLight: 0.4, .barrier: 0.25],
          130, 74, 5, 0.1, 118),
        T(.parisBelleGrande, .historicNarrow, .goldenHour, .none, traffic: 0.86, police: 0.43, .flat,
          road: [.curveTight: 0.35, .intersectionGrid: 0.35, .straight: 0.3],
          build: [.lowRise: 0.5, .residential: 0.35, .neonTower: 0.15],
          prop: [.streetLight: 0.45, .signage: 0.35, .barrier: 0.2],
          96, 86, 7, 0.1, 132),
        T(.cairoSandCircuit, .desertHighway, .goldenHour, .dust, traffic: 0.56, police: 0.41, .flat,
          road: [.straight: 0.45, .highwaySweep: 0.35, .curveEasy: 0.2],
          build: [.desertCompound: 0.55, .lowRise: 0.3, .industrial: 0.15],
          prop: [.barrier: 0.45, .signage: 0.35, .gantry: 0.2],
          142, 68, 4, 0.08, 106),
        T(.lagosPulseBay, .tropical, .rainOvercast, .heatHaze, traffic: 0.9, police: 0.54, .coastal,
          road: [.coastalSweep: 0.35, .curveTight: 0.35, .intersectionGrid: 0.3],
          build: [.lowRise: 0.45, .neonTower: 0.35, .industrial: 0.2],
          prop: [.streetLight: 0.4, .trafficCone: 0.35, .barrier: 0.25],
          116, 80, 7, 0.14, 122),
        T(.seoulVoltageGrid, .neonNight, .nightNeon, .none, traffic: 0.9, police: 0.51, .flat,
          road: [.intersectionGrid: 0.4, .curveTight: 0.3, .highwaySweep: 0.3],
          build: [.neonTower: 0.5, .highRise: 0.35, .residential: 0.15],
          prop: [.gantry: 0.4, .streetLight: 0.35, .signage: 0.25],
          112, 88, 8, 0.18, 134),
        T(.mumbaiMonsoonMaze, .monsoonWet, .rainOvercast, .lightRain, traffic: 0.94, police: 0.57, .flat,
          road: [.intersectionGrid: 0.45, .curveTight: 0.35, .straight: 0.2],
          build: [.lowRise: 0.45, .highRise: 0.4, .industrial: 0.15],
          prop: [.streetLight: 0.4, .barrier: 0.35, .trafficCone: 0.25],
          106, 86, 8, 0.12, 128),
        T(.johannesburgRidge, .urbanDense, .dayClear, .dust, traffic: 0.64, police: 0.45, .rolling,
          road: [.hillClimb: 0.35, .highwaySweep: 0.35, .curveEasy: 0.3],
          build: [.lowRise: 0.4, .residential: 0.35, .industrial: 0.25],
          prop: [.barrier: 0.4, .streetLight: 0.35, .signage: 0.25],
          126, 76, 7, 0.32, 120),
        T(.aucklandBreezeCoast, .coastalNeon, .dayClear, .oceanMist, traffic: 0.58, police: 0.34, .coastal,
          road: [.coastalSweep: 0.55, .curveEasy: 0.25, .straight: 0.2],
          build: [.coastalResort: 0.45, .lowRise: 0.4, .residential: 0.15],
          prop: [.palm: 0.5, .barrier: 0.25, .streetLight: 0.25],
          114, 76, 5, 0.14, 116)
    ]

    static func definition(for id: CityThemeID) -> CityThemeDefinition {
        themes[id.rawValue]
    }

    /// Championship uses **fixed** cities per round (deterministic career progression).
    static func championshipTheme(round: Int) -> CityThemeID {
        switch min(max(round, 0), 3) {
        case 0: return .sunsetStripBay
        case 1: return .pacificTerrace
        case 2: return .gulfSpires
        default: return .libertyMetro
        }
    }

    static func championshipSeed(round: Int) -> UInt64 {
        let trackIdx = GameCatalog.championshipRounds[min(max(round, 0), 3)].trackIndex
        let base: UInt64 = switch min(max(round, 0), 3) {
        case 0: 0xCAFE_F00D_C0DE_0001
        case 1: 0xCAFE_F00D_C0DE_0002
        case 2: 0xCAFE_F00D_C0DE_0003
        default: 0xCAFE_F00D_C0DE_0004
        }
        return base ^ UInt64(trackIdx &* 17_389)
    }
}

private extension CityThemeCatalog {

    /// Compact factory — keeps the 30 rows readable.
    static func T(
        _ id: CityThemeID,
        _ visual: CityVisualTheme,
        _ light: LightingProfile,
        _ env: EnvironmentalEffect,
        traffic: Float,
        police: Float,
        _ terrain: TerrainVariant,
        road: [RoadModuleKind: Float],
        build: [BuildingBlockKind: Float],
        prop: [PropKind: Float],
        _ semiMajor: Float,
        _ semiMinor: Float,
        _ curvature: Int,
        _ elevation: Float,
        _ resolution: Int
    ) -> CityThemeDefinition {
        CityThemeDefinition(
            id: id,
            visualTheme: visual,
            lighting: light,
            environment: env,
            trafficDensity: traffic,
            policeDifficulty: police,
            terrain: terrain,
            roadWeights: road,
            buildingWeights: build,
            propWeights: prop,
            semiMajor: semiMajor,
            semiMinor: semiMinor,
            curvatureComplexity: max(3, min(12, curvature)),
            elevationScale: elevation,
            trackResolution: resolution
        )
    }
}
