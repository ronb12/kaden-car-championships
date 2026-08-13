import SceneKit
import UIKit

/// Global Palm City Raceway environments (reference art). Mode picks night vs coastal day per race seed.
enum PalmCityEnvironment {

    enum Mode: Equatable {
        case nightHighway
        case dayCoastal

        var assetName: String {
            switch self {
            case .nightHighway: return "PalmCityEnvironment"
            case .dayCoastal: return "PalmCityCoastalDay"
            }
        }

        var displayName: String {
            switch self {
            case .nightHighway: return "Palm City Raceway"
            case .dayCoastal: return "Palm City Coastal"
            }
        }
    }

    /// When true, all races use a Palm City environment (mode alternates by seed).
    /// Off: use catalog themes + ProceduralCityDecor buildings (same readable path as Courier).
    static let isActive = false

    /// Set during `adapt(_:)` from the race seed.
    private(set) static var currentMode: Mode = .dayCoastal

    static let theme: CityThemeID = .coralNeonShores

    static var isNight: Bool { currentMode == .nightHighway }
    static var forceNight: Bool { isActive && isNight }
    static var forceWetRoad: Bool { isActive && isNight }
    static var prefersOcean: Bool { isActive && currentMode == .dayCoastal }

    static var displayName: String { currentMode.displayName }

    static var referenceBackdrop: UIImage? {
        UIImage(named: currentMode.assetName)
    }

    static func mode(for seed: UInt64) -> Mode {
        // Alternate day/night; track layout comes from catalog index via PalmCityRacewayTracks.
        seed % 2 == 0 ? .dayCoastal : .nightHighway
    }

    static func trackLayoutName(for catalogIndex: Int) -> String {
        PalmCityRacewayTracks.layout(for: catalogIndex).displayName
    }

    static func adapt(_ config: CityRuntimeConfig) -> CityRuntimeConfig {
        guard isActive else { return config }
        currentMode = mode(for: config.seed)
        let def = CityThemeCatalog.definition(for: theme)
        let trackLabel = config.catalogTrackIndex.map { PalmCityRacewayTracks.layout(for: $0).displayName }
        let fullName = trackLabel.map { "\(displayName) — \($0)" } ?? displayName
        return CityRuntimeConfig(
            themeId: theme,
            definition: def,
            seed: config.seed,
            track: config.track,
            moduleRing: config.moduleRing,
            displayName: fullName,
            trafficScale: config.trafficScale,
            policeScale: config.policeScale,
            decorBatchCount: config.decorBatchCount,
            trackProfile: config.trackProfile,
            catalogTrackIndex: config.catalogTrackIndex
        )
    }

    static func palmCityArt() -> CityEnvironmentArt.Profile {
        switch currentMode {
        case .nightHighway: return palmCityNightArt()
        case .dayCoastal: return palmCityDayArt()
        }
    }

    private static func palmCityNightArt() -> CityEnvironmentArt.Profile {
        var p = CityEnvironmentArt.profile(themeId: theme, definition: CityThemeCatalog.definition(for: theme))
        p.cityLabel = "PALM CITY"
        p.skylineCount = 56
        p.skylineHighRiseBias = 0.88
        p.decorDensityMul = 1.35
        p.prefersOcean = false
        p.prefersPalms = true
        p.fogNight = rgb(0x0A0814)
        p.fogDay = rgb(0x181420)
        p.groundDay = rgb(0x0C0A10)
        p.windowNight = rgb(0x88AAFF)
        p.billboardColors = [rgb(0xFF2A88), rgb(0xFF66AA), rgb(0x44CCFF), rgb(0xFFE040)]
        return p
    }

    private static func palmCityDayArt() -> CityEnvironmentArt.Profile {
        var p = CityEnvironmentArt.profile(themeId: theme, definition: CityThemeCatalog.definition(for: theme))
        p.cityLabel = "PALM CITY"
        p.skylineCount = 64
        p.skylineHighRiseBias = 0.92
        p.decorDensityMul = 1.28
        p.prefersOcean = true
        p.prefersPalms = true
        p.skyTopDay = rgb(0x4A9EE8)
        p.skyHorizonDay = rgb(0xB8D8F0)
        p.fogDay = rgb(0xA8C8E0)
        p.groundDay = rgb(0x1A2830)
        p.windowDay = rgb(0x1E3344)
        p.windowNight = rgb(0xAADDFF)
        p.foliage = rgb(0x2A8838)
        p.billboardColors = [rgb(0xFF2A88), rgb(0xC45A28), rgb(0x48A8E8), rgb(0xF0D040)]
        return p
    }

    static func skyDomeMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        if let img = referenceBackdrop {
            m.diffuse.contents = img
        } else if isNight {
            m.diffuse.contents = KRCProceduralTextures.skyGradient(
                top: rgb(0x0A0818),
                bottom: rgb(0x1A1028),
                mid: rgb(0xFF3388)
            )
        } else {
            m.diffuse.contents = KRCProceduralTextures.skyGradient(
                top: rgb(0x58B8F0),
                bottom: rgb(0xC8E0F0),
                mid: rgb(0x88C8F8)
            )
        }
        m.isDoubleSided = true
        m.cullMode = .front
        return m
    }

    static func sceneBackground() -> Any? {
        if let img = referenceBackdrop { return img }
        if isNight {
            return KRCProceduralTextures.skyGradient(
                top: rgb(0x0A0818),
                bottom: rgb(0x281028),
                mid: rgb(0x883366)
            )
        }
        return KRCProceduralTextures.skyGradient(
            top: rgb(0x58B8F0),
            bottom: rgb(0xD0E8F8),
            mid: rgb(0x98D0F0)
        )
    }

    private static func rgb(_ hex: UInt32) -> UIColor {
        CityEnvironmentArt.rgb(hex)
    }
}
