import Foundation

/// How twisty / tight a circuit feels for younger drivers (Casual difficulty).
enum KidTrackTier: String, Hashable {
    case easy
    case standard
    case hard
}

struct TrackChoice: Hashable {
    let name: String
    let tag: String
    let lapsDefault: Int
    let kidTier: KidTrackTier
}

struct ChampionshipRound: Hashable {
    let name: String
    let laps: Int
    let trackIndex: Int
}

extension GameCatalog {
    /// Palm City Raceway — six circuits from the layout reference sheet.
    static let palmCityTracks: [TrackChoice] = [
        track("Harbor Run", "Waterfront", 4, tier: .hard),
        track("Downtown Loop", "Technical", 4, tier: .hard),
        track("Coastal Dash", "Coastal", 4, tier: .standard),
        track("Bayview Sprint", "Flow", 3, tier: .easy),
        track("Industrial Circuit", "Hairpins", 4, tier: .hard),
        track("Full Throttle", "Grand", 5, tier: .standard),
    ]

    /// Active track list (Palm City sheet when that environment is enabled).
    static var activeTracks: [TrackChoice] {
        PalmCityEnvironment.isActive ? palmCityTracks : tracks
    }

    /// Fifty authored circuits — each index maps to a distinct spline in `CatalogTrackGenerator`.
    static let tracks: [TrackChoice] = [
        track("Harbor Loop", "Bay City", 4, tier: .standard),
        track("Sunset Oval", "Speedway", 5, tier: .easy),
        track("Alpine Ridge", "Elevation", 4, tier: .hard),
        track("Nova Ring", "Circuit", 4, tier: .easy),
        track("Pulse GP", "Technical", 4, tier: .hard),
        track("Trident Run", "Tri-lobe", 4, tier: .hard),
        track("Thunder Dome", "Woven", 4, tier: .hard),
        track("Coastal Sweep", "Asymmetric", 4, tier: .standard),
        track("Desert Mile", "Long", 5, tier: .easy),
        track("Glacier Tech", "Tight", 4, tier: .hard),
        track("Infinity Eight", "Figure-8", 4, tier: .hard),
        track("Riverside", "Flow", 4, tier: .easy),
        track("Canyon Raid", "Aggressive", 4, tier: .hard),
        track("Iron Peak", "Mountain", 4, tier: .hard),
        track("Velocity Bay", "Hybrid", 4, tier: .standard),
        track("Neon Circuit", "Night", 4, tier: .hard),
        track("Storm Harbor", "Dynamic", 4, tier: .hard),
        track("Grand Prix Ring", "Pro", 5, tier: .hard),
        track("Midnight Sprint", "Short", 4, tier: .easy),
        track("KRC Showdown", "Finals", 5, tier: .standard),
        track("Coastal City Circuit", "Showcase", 4, tier: .hard),
        track("Marina Crown", "Bay City", 4, tier: .standard),
        track("Turbine Loop", "Speedway", 5, tier: .easy),
        track("Summit Pass", "Elevation", 4, tier: .hard),
        track("Orbit Prime", "Circuit", 4, tier: .easy),
        track("Apex Complex", "Technical", 4, tier: .hard),
        track("Vortex Clover", "Tri-lobe", 4, tier: .hard),
        track("Lightning Hept", "Woven", 4, tier: .hard),
        track("Bayfront Arc", "Asymmetric", 4, tier: .standard),
        track("Sahara Run", "Long", 5, tier: .easy),
        track("Frost Box", "Tight", 4, tier: .hard),
        track("Crossfire Eight", "Figure-8", 4, tier: .hard),
        track("Delta Flow", "Flow", 4, tier: .standard),
        track("Mesa Fury", "Aggressive", 4, tier: .hard),
        track("Granite Spire", "Mountain", 4, tier: .hard),
        track("Hybrid Coast", "Hybrid", 4, tier: .standard),
        track("Prism Night", "Night", 4, tier: .hard),
        track("Tempest Dock", "Dynamic", 4, tier: .hard),
        track("Proving Ground", "Pro", 5, tier: .hard),
        track("Twilight Kart", "Short", 4, tier: .easy),
        track("Title Clash", "Finals", 5, tier: .standard),
        track("Coral Reef Run", "Coastal", 4, tier: .standard),
        track("Dune Striker", "Desert", 5, tier: .standard),
        track("Cliffhanger GP", "Alpine", 4, tier: .hard),
        track("Oval of Fire", "Speedway", 5, tier: .easy),
        track("Gridlock Circuit", "Urban", 4, tier: .hard),
        track("Monsoon Bay", "Storm", 4, tier: .hard),
        track("Chicane Masters", "Technical", 4, tier: .hard),
        track("Starburst Loop", "Star", 4, tier: .hard),
        track("Dragon's Tail", "Signature", 4, tier: .hard),
    ]

    /// Mirrors web `CHAMP_TRACKS` (4 elimination rounds).
    static let championshipRounds: [ChampionshipRound] = [
        ChampionshipRound(name: "QUALIFIER", laps: 3, trackIndex: 0),
        ChampionshipRound(name: "QUARTERFINAL", laps: 4, trackIndex: 3),
        ChampionshipRound(name: "SEMIFINAL", laps: 5, trackIndex: 7),
        ChampionshipRound(name: "FINAL", laps: 6, trackIndex: 12),
    ]

    static let palmCityChampionshipRounds: [ChampionshipRound] = [
        ChampionshipRound(name: "QUALIFIER", laps: 3, trackIndex: 3),
        ChampionshipRound(name: "QUARTERFINAL", laps: 4, trackIndex: 2),
        ChampionshipRound(name: "SEMIFINAL", laps: 5, trackIndex: 5),
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

    static func kidTier(at index: Int) -> KidTrackTier {
        track(at: index).kidTier
    }

    /// Tracks shown in Casual / kid picker — no figure-8s, hairpins, or technical weaves.
    static var kidPickableTrackIndices: [Int] {
        Array(activeTracks.indices.filter { activeTracks[$0].kidTier != .hard })
    }

    static func isKidFriendlyTrackIndex(_ index: Int) -> Bool {
        kidTier(at: index) != .hard
    }

    /// When Casual mode assigns a hard circuit (career, daily, championship), swap to a gentler layout.
    static func kidFriendlyTrackIndex(for index: Int) -> Int {
        let clamped = min(max(index, 0), activeTracks.count - 1)
        guard activeTracks[clamped].kidTier == .hard else { return clamped }
        if PalmCityEnvironment.isActive {
            return palmCityKidAlternative(for: clamped)
        }
        return mainCatalogKidAlternative(for: clamped)
    }

    private static func mainCatalogKidAlternative(for hardIndex: Int) -> Int {
        if let alt = kidAlternatives[hardIndex], alt < activeTracks.count {
            return alt
        }
        return 11 // Riverside — smooth flow default
    }

    private static func palmCityKidAlternative(for hardIndex: Int) -> Int {
        switch hardIndex {
        case 0, 1, 4: return 3 // Bayview Sprint
        default: return min(3, activeTracks.count - 1)
        }
    }

    /// Hard catalog index → smoother substitute (same theme family where possible).
    private static let kidAlternatives: [Int: Int] = [
        2: 1,   // Alpine Ridge → Sunset Oval
        4: 11,  // Pulse GP → Riverside
        5: 11,  // Trident Run → Riverside
        6: 1,   // Thunder Dome → Sunset Oval
        9: 3,   // Glacier Tech → Nova Ring
        10: 11, // Infinity Eight → Riverside
        12: 8,  // Canyon Raid → Desert Mile
        13: 0,  // Iron Peak → Harbor Loop
        15: 0,  // Neon Circuit → Harbor Loop
        16: 0,  // Storm Harbor → Harbor Loop
        17: 1,  // Grand Prix Ring → Sunset Oval
        20: 11, // Coastal City Circuit → Riverside
        23: 7,  // Summit Pass → Coastal Sweep
        25: 11, // Apex Complex → Riverside
        26: 11, // Vortex Clover → Riverside
        27: 1,  // Lightning Hept → Sunset Oval
        30: 3,  // Frost Box → Nova Ring
        31: 11, // Crossfire Eight → Riverside
        33: 8,  // Mesa Fury → Desert Mile
        34: 7,  // Granite Spire → Coastal Sweep
        36: 0,  // Prism Night → Harbor Loop
        37: 0,  // Tempest Dock → Harbor Loop
        38: 1,  // Proving Ground → Sunset Oval
        43: 7,  // Cliffhanger GP → Coastal Sweep
        45: 0,  // Gridlock Circuit → Harbor Loop
        46: 0,  // Monsoon Bay → Harbor Loop
        47: 11, // Chicane Masters → Riverside
        48: 1,  // Starburst Loop → Sunset Oval
        49: 11, // Dragon's Tail → Riverside
    ]

    private static func track(_ name: String, _ tag: String, _ laps: Int, tier: KidTrackTier = .standard) -> TrackChoice {
        TrackChoice(name: name, tag: tag, lapsDefault: laps, kidTier: tier)
    }
}
