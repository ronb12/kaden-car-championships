import Foundation

// MARK: - Game modes (expandable; wire Firebase / MP per mode)

enum GameModeKind: String, Codable, CaseIterable, Identifiable {
    /// Standard lap race (former “quick race”).
    case circuit
    /// Three-track tour (existing championship flow).
    case championshipSerie
    /// NFS-style pursuit — aggressive cops, heat system.
    case policeChase
    /// Long survival run — score + drift combo.
    case endless
    /// Best lap focus.
    case timeTrial
    /// Placeholder: ghost replay async — leaderboard hooks ready.
    case ghostDuel
    /// Career ladder placeholder — missions JSON later.
    case career

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .circuit: return "Circuit Race"
        case .championshipSerie: return "Championship"
        case .policeChase: return "Hot Pursuit"
        case .endless: return "Endless Run"
        case .timeTrial: return "Time Trial"
        case .ghostDuel: return "Ghost Duel"
        case .career: return "Career"
        }
    }

    var subtitle: String {
        switch self {
        case .circuit: return "Classic arcade laps"
        case .championshipSerie: return "3 venues · cumulative time"
        case .policeChase: return "Escape the chase · heat rises"
        case .endless: return "One long session · chase score"
        case .timeTrial: return "Pure pace · minimal traffic"
        case .ghostDuel: return "Beat leaderboard ghosts"
        case .career: return "Structured progression"
        }
    }

    func defaultLaps() -> Int {
        switch self {
        case .circuit: return 5
        case .championshipSerie: return 5
        case .policeChase: return 5
        case .endless: return 999
        case .timeTrial: return 3
        case .ghostDuel: return 5
        case .career: return 4
        }
    }

    var enablesPolice: Bool {
        switch self {
        case .policeChase, .endless, .career: return true
        default: return false
        }
    }

    var enablesTraffic: Bool {
        switch self {
        case .circuit, .championshipSerie, .policeChase, .endless, .career: return true
        case .timeTrial, .ghostDuel: return false
        }
    }
}

// MARK: - Car stats & upgrades

struct CarUpgradeState: Codable, Equatable {
    var engine: Int
    var nitro: Int
    var tires: Int

    static let baseline = CarUpgradeState(engine: 0, nitro: 0, tires: 0)
}

enum VehicleCategory: String, Codable, CaseIterable {
    case compact
    case sports
    case muscle
    case supercar
    case hypercar
    case policeInterceptor
}

struct CarStatProfile: Codable, Equatable {
    let id: String
    let speed: Int
    let acceleration: Int
    let handling: Int
    let nitroEfficiency: Int
    let durability: Int
    let category: VehicleCategory
    let unlockCostCredits: Int64
    let premiumSKU: String?
}

struct CarRuntimeStats: Equatable {
    let topSpeedMul: Float
    let accelMul: Float
    let gripMul: Float
    let nitroCapacityMul: Float
    let nitroRefillMul: Float
    /// Structural toughness — feeds damage resistance / top-speed bleed-off hooks.
    let durabilityMul: Float
}

enum ControlScheme: String, Codable, CaseIterable, Identifiable {
    case touch
    case tilt

    var id: String { rawValue }

    var label: String {
        switch self {
        case .touch: return "Touch"
        case .tilt: return "Tilt steer"
        }
    }
}

struct CareerProgressSnapshot {
    var missionTier: Int
}
