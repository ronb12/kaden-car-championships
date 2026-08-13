import UIKit

/// Per-city visual identity — sky, skyline, foliage, and decor tuned to match real locations (web `CITY_DEFS` parity).
enum CityEnvironmentArt {

    struct Profile {
        var cityLabel: String
        var skylineCount: Int
        var skylineHighRiseBias: Float
        var decorDensityMul: Float
        var prefersOcean: Bool
        var prefersPalms: Bool
        var sidewalkDay: UIColor
        var sidewalkNight: UIColor
        var foliage: UIColor
        var trunk: UIColor
        var fogDay: UIColor?
        var fogSunset: UIColor?
        var fogNight: UIColor?
        var skyTopDay: UIColor?
        var skyTopSunset: UIColor?
        var skyHorizonDay: UIColor?
        var skyHorizonSunset: UIColor?
        var groundDay: UIColor?
        var windowDay: UIColor
        var windowNight: UIColor
        var billboardColors: [UIColor]
    }

    /// Sky gradient for scene background + sky dome (per-city overrides from `applyOverrides`).
    static func skyGradient(
        for city: CityRuntimeConfig,
        night: Bool,
        weather: EnvironmentLightingSystem.WeatherMode
    ) -> (top: UIColor, bottom: UIColor, mid: UIColor?) {
        let art = profile(for: city)
        let def = city.definition

        if night {
            let top = AssetManager.sky(definition: def, night: true, sunset: false)
            let bottom = AssetManager.skyHorizon(definition: def, night: true, sunset: false)
            let mid = art.fogNight ?? UIColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1)
            return (top, bottom, mid)
        }

        switch weather {
        case .night:
            let top = AssetManager.sky(definition: def, night: true, sunset: false)
            let bottom = AssetManager.skyHorizon(definition: def, night: true, sunset: false)
            let mid = art.fogNight ?? UIColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1)
            return (top, bottom, mid)
        case .sunset:
            let top = art.skyTopSunset
                ?? AssetManager.sky(definition: def, night: false, sunset: true)
            let bottom = art.skyHorizonSunset
                ?? AssetManager.skyHorizon(definition: def, night: false, sunset: true)
            let mid = art.fogSunset ?? UIColor(red: 0.78, green: 0.52, blue: 0.34, alpha: 1)
            return (top, bottom, mid)
        case .day:
            let top = art.skyTopDay
                ?? defaultSkyTop(visual: def.visualTheme, environment: def.environment)
            let bottom = art.skyHorizonDay
                ?? defaultSkyHorizon(visual: def.visualTheme, environment: def.environment)
            let mid = blendMid(top: top, bottom: bottom)
            return (top, bottom, mid)
        }
    }

    private static func defaultSkyTop(visual: CityVisualTheme, environment: EnvironmentalEffect) -> UIColor {
        switch visual {
        case .desertHighway:
            return rgb(0xE8C090)
        case .coastalNeon, .tropical:
            return rgb(0x48B8F0)
        case .alpine:
            return rgb(0x98B8D8)
        case .neonNight:
            return rgb(0x283858)
        case .historicNarrow:
            return rgb(0x90A0B0)
        case .industrialPort:
            return rgb(0x788898)
        case .luxuryBoulevard:
            return rgb(0x78C0E8)
        case .monsoonWet:
            return rgb(0x788890)
        case .urbanDense:
            return environment == .heavyFog ? rgb(0x98A8B8) : rgb(0x58A0D8)
        }
    }

    private static func defaultSkyHorizon(visual: CityVisualTheme, environment: EnvironmentalEffect) -> UIColor {
        switch visual {
        case .desertHighway:
            return rgb(0xF0D8A8)
        case .coastalNeon, .tropical:
            return rgb(0xC8E8F8)
        case .alpine:
            return rgb(0xD0DCE8)
        case .neonNight:
            return rgb(0x405078)
        case .historicNarrow:
            return rgb(0xB8C0C8)
        case .industrialPort:
            return rgb(0xA0A8B0)
        case .luxuryBoulevard:
            return rgb(0xF5DEB3)
        case .monsoonWet:
            return rgb(0x98A8A0)
        case .urbanDense:
            return environment == .heavyFog ? rgb(0xB0B8C0) : rgb(0xD8E8F8)
        }
    }

    private static func blendMid(top: UIColor, bottom: UIColor) -> UIColor {
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        top.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        bottom.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(
            red: tr * 0.45 + br * 0.55,
            green: tg * 0.45 + bg * 0.55,
            blue: tb * 0.45 + bb * 0.55,
            alpha: 1
        )
    }

    static func profile(for city: CityRuntimeConfig) -> Profile {
        if PalmCityEnvironment.isActive { return PalmCityEnvironment.palmCityArt() }
        var p = profile(themeId: city.themeId, definition: city.definition)
        p.foliage = city.trackProfile.foliageTint(definition: city.definition)
        p.decorDensityMul *= city.trackProfile.decorDensityMultiplier
        if city.trackProfile == .urbanNight {
            p.prefersOcean = false
            p.skyTopDay = UIColor(red: 0.08, green: 0.10, blue: 0.18, alpha: 1)
            p.skyHorizonDay = UIColor(red: 0.18, green: 0.14, blue: 0.28, alpha: 1)
        }
        if city.trackProfile == .desertHighway {
            p.prefersPalms = false
            p.groundDay = UIColor(red: 0.55, green: 0.46, blue: 0.32, alpha: 1)
        }
        if city.trackProfile.prefersOcean {
            p.prefersOcean = true
        }
        return p
    }

    static func profile(themeId: CityThemeID, definition: CityThemeDefinition) -> Profile {
        var p = baseProfile(
            visual: definition.visualTheme,
            terrain: definition.terrain,
            lighting: definition.lighting,
            environment: definition.environment
        )
        p.cityLabel = themeId.cityName.uppercased()
        applyOverrides(themeId: themeId, profile: &p)
        return p
    }

    // MARK: - Base by visual theme

    private static func baseProfile(
        visual: CityVisualTheme,
        terrain: TerrainVariant,
        lighting: LightingProfile,
        environment: EnvironmentalEffect
    ) -> Profile {
        let coastal = terrain == .coastal

        var p = Profile(
            cityLabel: "",
            skylineCount: visual == .urbanDense ? 22 : 18,
            skylineHighRiseBias: visual == .urbanDense || visual == .neonNight ? 0.72 : 0.48,
            decorDensityMul: visual == .urbanDense ? 1.05 : 0.92,
            prefersOcean: coastal,
            prefersPalms: coastal || visual == .tropical || visual == .luxuryBoulevard,
            sidewalkDay: UIColor(red: 0.48, green: 0.46, blue: 0.44, alpha: 1),
            sidewalkNight: UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1),
            foliage: UIColor(red: coastal ? 0.18 : 0.16, green: coastal ? 0.48 : 0.38, blue: coastal ? 0.14 : 0.18, alpha: 1),
            trunk: UIColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1),
            fogDay: nil,
            fogSunset: nil,
            fogNight: nil,
            skyTopDay: nil,
            skyTopSunset: nil,
            skyHorizonDay: nil,
            skyHorizonSunset: nil,
            groundDay: nil,
            windowDay: UIColor(red: 0.48, green: 0.58, blue: 0.68, alpha: 0.75),
            windowNight: UIColor(red: 0.88, green: 0.78, blue: 0.52, alpha: 0.9),
            billboardColors: defaultBillboards(for: visual)
        )

        switch visual {
        case .luxuryBoulevard:
            p.skylineHighRiseBias = 0.38
            p.skylineCount = 32
            p.foliage = UIColor(red: 0.20, green: 0.45, blue: 0.18, alpha: 1)
        case .desertHighway:
            p.skylineHighRiseBias = 0.35
            p.foliage = UIColor(red: 0.28, green: 0.38, blue: 0.16, alpha: 1)
            p.groundDay = UIColor(red: 0.62, green: 0.52, blue: 0.38, alpha: 1)
        case .coastalNeon, .tropical:
            p.prefersOcean = true
            p.prefersPalms = true
        case .industrialPort:
            p.skylineHighRiseBias = 0.55
            p.foliage = UIColor(red: 0.12, green: 0.28, blue: 0.14, alpha: 1)
        case .alpine:
            p.skylineCount = 24
            p.skylineHighRiseBias = 0.25
            p.foliage = UIColor(red: 0.14, green: 0.32, blue: 0.20, alpha: 1)
        case .neonNight:
            p.windowNight = UIColor(red: 0.62, green: 0.72, blue: 0.82, alpha: 0.9)
        case .historicNarrow:
            p.skylineCount = 28
            p.skylineHighRiseBias = 0.22
        case .monsoonWet:
            p.fogDay = UIColor(red: 0.68, green: 0.72, blue: 0.76, alpha: 1)
        case .urbanDense:
            break
        }

        if lighting == .goldenHour || lighting == .duskOrange {
            p.skyTopSunset = UIColor(red: 0.98, green: 0.55, blue: 0.32, alpha: 1)
            p.skyHorizonSunset = UIColor(red: 0.99, green: 0.78, blue: 0.58, alpha: 1)
            p.fogSunset = UIColor(red: 0.88, green: 0.72, blue: 0.58, alpha: 1)
        }
        if environment == .heatHaze {
            p.fogDay = UIColor(red: 0.82, green: 0.78, blue: 0.70, alpha: 1)
        }
        if environment == .oceanMist || environment == .heavyFog {
            p.fogDay = UIColor(red: 0.72, green: 0.78, blue: 0.82, alpha: 1)
            p.prefersOcean = true
        }

        return p
    }

    private static func defaultBillboards(for visual: CityVisualTheme) -> [UIColor] {
        let raw: [UIColor] = switch visual {
        case .luxuryBoulevard, .desertHighway:
            [rgb(0xC87840), rgb(0xB8A050), rgb(0xA85848), rgb(0x5088A0)]
        case .neonNight, .coastalNeon:
            [rgb(0x508898), rgb(0x986878), rgb(0x689068), rgb(0xA07050)]
        case .urbanDense, .industrialPort:
            [rgb(0xC8C8C8), rgb(0x989898), rgb(0xA85858), rgb(0x5870A0)]
        default:
            [rgb(0x5088A0), rgb(0xA87048), rgb(0x588858), rgb(0x886888)]
        }
        return raw.map { VisualTone.mute($0, amount: 0.18) }
    }

    // MARK: - Per-city overrides (indexed to match web CITY_DEFS)

    private static func applyOverrides(themeId: CityThemeID, profile: inout Profile) {
        switch themeId {
        case .libertyMetro:
            profile.skylineHighRiseBias = 0.78
            profile.skylineCount = 22
            profile.skyTopDay = rgb(0x7EB8E8)
            profile.skyHorizonDay = rgb(0xC8D8E8)
            profile.windowNight = rgb(0xFFE8A0)
        case .pacificTerrace:
            profile.skylineHighRiseBias = 0.82
            profile.decorDensityMul = 1.08
            profile.windowNight = rgb(0x88DDFF)
            profile.billboardColors = [rgb(0xFF2244), rgb(0x00CCFF), rgb(0xFFEE00), rgb(0xFFFFFF)]
        case .gulfSpires:
            profile.skylineHighRiseBias = 0.88
            profile.skylineCount = 44
            profile.groundDay = rgb(0xC4A86A)
            profile.fogDay = rgb(0xD8C8A0)
        case .thamesHollow:
            profile.fogDay = rgb(0x98A4B0)
            profile.skyTopDay = rgb(0x8AA0B8)
            profile.foliage = rgb(0x2A5A28)
        case .sunsetStripBay:
            profile.skylineHighRiseBias = 0.42
            profile.prefersPalms = true
            profile.prefersOcean = true
            profile.skyTopDay = rgb(0x6ABAED)
            profile.skyHorizonDay = rgb(0xF5DEB3)
            profile.skyTopSunset = rgb(0xFF7744)
            profile.skyHorizonSunset = rgb(0xFFCCAA)
            profile.fogSunset = rgb(0xFFCCAA)
            profile.foliage = rgb(0x2D7A20)
            profile.trunk = rgb(0x6B403F)
            profile.windowDay = rgb(0x55B8E8)
            profile.windowNight = rgb(0xFFE090)
        case .coralNeonShores:
            profile.prefersOcean = true
            profile.prefersPalms = true
            profile.skyTopDay = rgb(0x48B8F0)
            profile.windowNight = rgb(0xFF88CC)
        case .bayGraniteHills:
            profile.fogDay = rgb(0xA8B8C8)
            profile.skyTopDay = rgb(0x90A8C0)
            profile.foliage = rgb(0x2A6830)
        case .sugarloafCoastal:
            profile.prefersOcean = true
            profile.prefersPalms = true
            profile.foliage = rgb(0x1E8838)
        case .desertLuxStrip:
            profile.skylineHighRiseBias = 0.75
            profile.groundDay = rgb(0xB89868)
            profile.windowNight = rgb(0xFF6688)
        case .greatLakesWorks:
            profile.fogDay = rgb(0xB0B8C0)
            profile.skyTopDay = rgb(0x88A0C0)
        case .capitolGrid:
            profile.skylineCount = 40
            profile.skyTopDay = rgb(0x78A8D8)
        case .emeraldRainBay:
            profile.fogDay = rgb(0x88A098)
            profile.foliage = rgb(0x286830)
        case .volcanoRing:
            profile.prefersOcean = true
            profile.prefersPalms = true
            profile.skyTopDay = rgb(0x58C8F0)
        case .monolithFoundry:
            profile.fogDay = rgb(0x9098A0)
            profile.foliage = rgb(0x284820)
        case .redRockRun:
            profile.groundDay = rgb(0xB87850)
            profile.foliage = rgb(0x4A6830)
        case .frostHarbor:
            profile.fogDay = rgb(0x98A8B8)
            profile.skyTopDay = rgb(0x88A0B8)
            profile.foliage = rgb(0x2A5838)
        case .rioGrandeDust:
            profile.groundDay = rgb(0xA89070)
            profile.foliage = rgb(0x3A7028)
        case .alpinePassRing:
            profile.skylineCount = 22
            profile.skylineHighRiseBias = 0.28
            profile.foliage = rgb(0x2A6830)
        case .harborPearlDelta:
            profile.skylineHighRiseBias = 0.85
            profile.prefersOcean = true
            profile.windowNight = rgb(0xAADDFF)
        case .saigonRiverArc:
            profile.prefersPalms = true
            profile.foliage = rgb(0x2A8838)
        case .sydneyHarborLoop:
            profile.prefersOcean = true
            profile.skyTopDay = rgb(0x58B8F0)
        case .frostKremlinRun:
            profile.fogDay = rgb(0xA0A8B8)
            profile.foliage = rgb(0x385830)
        case .berlinVelocityLoop:
            profile.skyTopDay = rgb(0x90B0D0)
        case .parisBelleGrande:
            profile.skylineHighRiseBias = 0.35
            profile.skyHorizonDay = rgb(0xE8D8C8)
        case .cairoSandCircuit:
            profile.groundDay = rgb(0xC8B070)
            profile.fogDay = rgb(0xD8C898)
            profile.foliage = rgb(0x5A8838)
        case .lagosPulseBay:
            profile.prefersOcean = true
            profile.foliage = rgb(0x288830)
        case .seoulVoltageGrid:
            profile.skylineHighRiseBias = 0.80
            profile.windowNight = rgb(0x88CCFF)
        case .mumbaiMonsoonMaze:
            profile.fogDay = rgb(0x8898A8)
            profile.foliage = rgb(0x2A7830)
        case .johannesburgRidge:
            profile.groundDay = rgb(0xA89878)
            profile.foliage = rgb(0x3A6830)
        case .aucklandBreezeCoast:
            profile.prefersOcean = true
            profile.skyTopDay = rgb(0x68B8E8)
            profile.foliage = rgb(0x2A6838)
        }
    }

    static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
