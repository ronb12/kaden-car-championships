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
        track("Harbor Loop", "Bay City", 3),
        track("Sunset Oval", "Speedway", 3),
        track("Alpine Ridge", "Elevation", 3),
        track("Nova Ring", "Circuit", 3),
        track("Pulse GP", "Technical", 3),
        track("Trident Run", "Tri-lobe", 3),
        track("Thunder Dome", "Woven", 3),
        track("Coastal Sweep", "Asymmetric", 3),
        track("Desert Mile", "Long", 3),
        track("Glacier Tech", "Tight", 3),
        track("Infinity Eight", "Figure-8", 3),
        track("Riverside", "Flow", 3),
        track("Canyon Raid", "Aggressive", 3),
        track("Iron Peak", "Mountain", 3),
        track("Velocity Bay", "Hybrid", 3),
        track("Neon Circuit", "Night", 3),
        track("Storm Harbor", "Dynamic", 3),
        track("Grand Prix Ring", "Pro", 3),
        track("Midnight Sprint", "Short", 3),
        track("KRC Showdown", "Finals", 3),
        track("Coastal City Circuit", "Showcase", 3),
        track("Marina Crown", "Bay City", 3),
        track("Turbine Loop", "Speedway", 3),
        track("Summit Pass", "Elevation", 3),
        track("Orbit Prime", "Circuit", 3),
        track("Apex Complex", "Technical", 3),
        track("Vortex Clover", "Tri-lobe", 3),
        track("Lightning Hept", "Woven", 3),
        track("Bayfront Arc", "Asymmetric", 3),
        track("Sahara Run", "Long", 3),
        track("Frost Box", "Tight", 3),
        track("Crossfire Eight", "Figure-8", 3),
        track("Delta Flow", "Flow", 3),
        track("Mesa Fury", "Aggressive", 3),
        track("Granite Spire", "Mountain", 3),
        track("Hybrid Coast", "Hybrid", 3),
        track("Prism Night", "Night", 3),
        track("Tempest Dock", "Dynamic", 3),
        track("Proving Ground", "Pro", 3),
        track("Twilight Kart", "Short", 3),
        track("Title Clash", "Finals", 3),
        track("Coral Reef Run", "Coastal", 3),
        track("Dune Striker", "Desert", 3),
        track("Cliffhanger GP", "Alpine", 3),
        track("Oval of Fire", "Speedway", 3),
        track("Gridlock Circuit", "Urban", 3),
        track("Monsoon Bay", "Storm", 3),
        track("Chicane Masters", "Technical", 3),
        track("Starburst Loop", "Star", 3),
        track("Dragon's Tail", "Signature", 3),
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
