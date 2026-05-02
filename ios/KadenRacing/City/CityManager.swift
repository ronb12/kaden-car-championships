import Foundation

/// Single entry for resolving **theme + seed → runtime spline + tuning**. Firebase/cloud can persist `(themeId, seed)` later.
final class CityManager {

    static let shared = CityManager()

    private init() {}

    /// Deterministic: same inputs ⇒ identical track geometry for replay / endless continuity.
    func resolve(theme: CityThemeID, seed: UInt64) -> CityRuntimeConfig {
        CityRuntimeConfigFactory.make(theme: theme, seed: seed)
    }

    /// Championship rounds ignore free-roam picks — locked layouts from `CityThemeCatalog`.
    func resolveChampionship(round: Int) -> CityRuntimeConfig {
        let theme = CityThemeCatalog.championshipTheme(round: round)
        let seed = CityThemeCatalog.championshipSeed(round: round)
        return CityRuntimeConfigFactory.make(theme: theme, seed: seed)
    }
}
