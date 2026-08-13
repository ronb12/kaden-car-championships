import Foundation

struct TrackChoice: Hashable {
    let name: String
    let tag: String
    let lapsDefault: Int
}

struct ChampionshipRound: Hashable {
    let name: String
    let laps: Int
    let trackIndex: Int
}

extension GameCatalog {
    /// Palm City Raceway — six circuits from the layout reference sheet.
    static let palmCityTracks: [TrackChoice] = PalmCityRacewayTracks.Layout.allCases.map { layout in
        TrackChoice(name: layout.displayName, tag: layout.lengthTag, lapsDefault: layout.defaultLaps)
    }

    /// Active track list (Palm City sheet when that environment is enabled).
    static var activeTracks: [TrackChoice] {
        PalmCityEnvironment.isActive ? palmCityTracks : tracks
    }

    /// Fifty authored circuits — each index maps to a distinct spline in `CatalogTrackGenerator`.
    static let tracks: [TrackChoice] = [
        track("Harbor Loop", "Bay City", 4),
        track("Sunset Oval", "Speedway", 5),
        track("Alpine Ridge", "Elevation", 4),
        track("Nova Ring", "Circuit", 4),
        track("Pulse GP", "Technical", 4),
        track("Trident Run", "Tri-lobe", 4),
        track("Thunder Dome", "Woven", 4),
        track("Coastal Sweep", "Asymmetric", 4),
        track("Desert Mile", "Long", 5),
        track("Glacier Tech", "Tight", 4),
        track("Infinity Eight", "Figure-8", 4),
        track("Riverside", "Flow", 4),
        track("Canyon Raid", "Aggressive", 4),
        track("Iron Peak", "Mountain", 4),
        track("Velocity Bay", "Hybrid", 4),
        track("Neon Circuit", "Night", 4),
        track("Storm Harbor", "Dynamic", 4),
        track("Grand Prix Ring", "Pro", 5),
        track("Midnight Sprint", "Short", 4),
        track("KRC Showdown", "Finals", 5),
        track("Coastal City Circuit", "Showcase", 4),
        track("Marina Crown", "Bay City", 4),
        track("Turbine Loop", "Speedway", 5),
        track("Summit Pass", "Elevation", 4),
        track("Orbit Prime", "Circuit", 4),
        track("Apex Complex", "Technical", 4),
        track("Vortex Clover", "Tri-lobe", 4),
        track("Lightning Hept", "Woven", 4),
        track("Bayfront Arc", "Asymmetric", 4),
        track("Sahara Run", "Long", 5),
        track("Frost Box", "Tight", 4),
        track("Crossfire Eight", "Figure-8", 4),
        track("Delta Flow", "Flow", 4),
        track("Mesa Fury", "Aggressive", 4),
        track("Granite Spire", "Mountain", 4),
        track("Hybrid Coast", "Hybrid", 4),
        track("Prism Night", "Night", 4),
        track("Tempest Dock", "Dynamic", 4),
        track("Proving Ground", "Pro", 5),
        track("Twilight Kart", "Short", 4),
        track("Title Clash", "Finals", 5),
        track("Coral Reef Run", "Coastal", 4),
        track("Dune Striker", "Desert", 5),
        track("Cliffhanger GP", "Alpine", 4),
        track("Oval of Fire", "Speedway", 5),
        track("Gridlock Circuit", "Urban", 4),
        track("Monsoon Bay", "Storm", 4),
        track("Chicane Masters", "Technical", 4),
        track("Starburst Loop", "Star", 4),
        track("Dragon's Tail", "Signature", 4),
    ]

    /// Mirrors web `CHAMP_TRACKS` (4 elimination rounds).
    static let championshipRounds: [ChampionshipRound] = [
        ChampionshipRound(name: "QUALIFIER", laps: 3, trackIndex: 0),
        ChampionshipRound(name: "QUARTERFINAL", laps: 4, trackIndex: 3),
        ChampionshipRound(name: "SEMIFINAL", laps: 5, trackIndex: 7),
        ChampionshipRound(name: "FINAL", laps: 6, trackIndex: 12),
    ]

    static let palmCityChampionshipRounds: [ChampionshipRound] = [
        ChampionshipRound(name: "QUALIFIER", laps: 3, trackIndex: 0),
        ChampionshipRound(name: "QUARTERFINAL", laps: 4, trackIndex: 1),
        ChampionshipRound(name: "SEMIFINAL", laps: 5, trackIndex: 2),
        ChampionshipRound(name: "FINAL", laps: 6, trackIndex: 5),
    ]

    static var activeChampionshipRounds: [ChampionshipRound] {
        PalmCityEnvironment.isActive ? palmCityChampionshipRounds : championshipRounds
    }

    static func track(at index: Int) -> TrackChoice {
        let list = activeTracks
        let i = min(max(index, 0), list.count - 1)
        return list[i]
    }

    private static func track(_ name: String, _ tag: String, _ laps: Int) -> TrackChoice {
        TrackChoice(name: name, tag: tag, lapsDefault: laps)
    }
}
