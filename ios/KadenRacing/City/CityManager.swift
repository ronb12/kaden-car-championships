import Foundation

/// Single entry for resolving **theme + seed → runtime spline + tuning**. Firebase/cloud can persist `(themeId, seed)` later.
final class CityManager {

    static let shared = CityManager()

    private init() {}

    /// Deterministic: same inputs ⇒ identical track geometry for replay / endless continuity.
    func resolve(theme: CityThemeID, seed: UInt64, catalogTrackIndex: Int?) -> CityRuntimeConfig {
        let config = CityRuntimeConfigFactory.make(theme: theme, seed: seed, catalogTrackIndex: catalogTrackIndex)
        return PalmCityEnvironment.adapt(config)
    }

    /// Championship rounds ignore free-roam picks — locked layouts from `CityThemeCatalog`.
    func resolveChampionship(round: Int) -> CityRuntimeConfig {
        let rounds = GameCatalog.activeChampionshipRounds
        let r = min(max(round, 0), rounds.count - 1)
        let theme = CityThemeCatalog.championshipTheme(round: round)
        let seed = CityThemeCatalog.championshipSeed(round: round)
        let trackIndex = rounds[r].trackIndex
        let config = CityRuntimeConfigFactory.make(theme: theme, seed: seed, catalogTrackIndex: trackIndex)
        return PalmCityEnvironment.adapt(config)
    }
}
