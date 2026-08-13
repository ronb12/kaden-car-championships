import Foundation
import simd
import UIKit

/// Fully resolved city for one race — **one** `ClosedTrackSpline` + tuning + decor metadata.
struct CityRuntimeConfig {
    let themeId: CityThemeID
    let definition: CityThemeDefinition
    let seed: UInt64
    let track: ClosedTrackSpline
    let moduleRing: [RoadModuleKind]
    let displayName: String
    let trafficScale: Float
    let policeScale: Float
    let decorBatchCount: Int
    let trackProfile: EnvironmentTrackProfile
    let catalogTrackIndex: Int?

    var visualNight: Bool { definition.lighting.forceNightGeometry }
    var lightingProfile: LightingProfile { definition.lighting }
    var environment: EnvironmentalEffect { definition.environment }
}

// MARK: - Factory

enum CityRuntimeConfigFactory {

    static func make(theme: CityThemeID, seed: UInt64, catalogTrackIndex: Int? = nil) -> CityRuntimeConfig {
        let profile = EnvironmentTrackProfile.from(catalogTrackIndex: catalogTrackIndex)
        let def = CityThemeCatalog.definition(for: theme)
        let track: ClosedTrackSpline = {
            if let idx = catalogTrackIndex, idx >= 0, idx < GameCatalog.activeTracks.count {
                return CatalogTrackGenerator.makeTrack(index: idx)
            }
            return ModularTrackGenerator.makeTrack(definition: def, seed: seed)
        }()
        let ring = ModularTrackGenerator.moduleRing(
            definition: def,
            seed: seed,
            segmentCount: max(32, def.trackResolution / 4)
        )
        return CityRuntimeConfig(
            themeId: theme,
            definition: def,
            seed: seed,
            track: track,
            moduleRing: ring,
            displayName: theme.displayName,
            trafficScale: 0.75 + def.trafficDensity * 0.35,
            policeScale: 0.7 + def.policeDifficulty * 0.45,
            decorBatchCount: min(
                36,
                max(8, Int(Float(def.trackResolution / 6) * profile.decorDensityMultiplier))
            ),
            trackProfile: profile,
            catalogTrackIndex: catalogTrackIndex
        )
    }
}
