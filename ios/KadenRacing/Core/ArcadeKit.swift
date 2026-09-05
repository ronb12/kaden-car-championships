import Foundation

// MARK: - Game modes (expandable; wire Firebase / MP per mode)

enum GameModeKind: String, Codable, CaseIterable, Identifiable, Hashable {
    /// Standard lap race (former “quick race”).
    case circuit
    /// Three-track tour (existing championship flow).
    case championshipSerie
    /// NFS/GT-style Hot Pursuit — player is the interceptor; bust fleeing suspects.
    case policeChase
    /// Long survival run — score + drift combo.
    case endless
    /// Best lap focus.
    case timeTrial
    /// Race a local personal-best ghost (+ translucent pace cars).
    case ghostDuel
    /// Career ladder — structured missions with unlock rewards.
    case career
    /// City apron package run — free-district drive between pickup/drop zones.
    case courier

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
        case .courier: return "Courier Run"
        }
    }

    var subtitle: String {
        switch self {
        case .circuit: return "Classic arcade laps"
        case .championshipSerie: return "4 rounds · cumulative time"
        case .policeChase: return "90-second busts · sirens · tickets"
        case .endless: return "One long session · chase score"
        case .timeTrial: return "Pure pace · minimal traffic"
        case .ghostDuel: return "Race your PB ghost + pace cars"
        case .career: return "Structured progression"
        case .courier: return "3 packages · pick a job · follow the road"
        }
    }

    func defaultLaps() -> Int {
        switch self {
        case .circuit: return 3
        case .championshipSerie: return 3
        case .policeChase: return 3
        case .endless: return 999
        case .timeTrial: return 3
        case .ghostDuel: return 3
        case .career: return 3
        case .courier: return 1
        }
    }

    var enablesPolice: Bool {
        switch self {
        case .policeChase, .endless: return true
        default: return false
        }
    }

    var enablesTraffic: Bool {
        switch self {
        case .circuit, .championshipSerie, .policeChase, .endless, .career: return true
        case .timeTrial, .ghostDuel, .courier: return false
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
    /// Career missions completed required before purchase (0 = always buyable when locked).
    var minCareerTiers: Int = 0
    let premiumSKU: String?

    var unlockTierLabel: String {
        switch category {
        case .compact: return "ROOKIE"
        case .muscle: return unlockCostCredits >= 10_000 ? "PRO" : "STREET"
        case .sports: return unlockCostCredits >= 10_000 ? "PRO" : "STREET"
        case .supercar: return "ELITE"
        case .hypercar: return "LEGEND"
        case .policeInterceptor: return "SPECIAL"
        }
    }

    var formattedUnlockCost: String {
        if unlockCostCredits <= 0 { return "STARTER" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: unlockCostCredits)) ?? "\(unlockCostCredits)") CR"
    }
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
    case dpad
    case tilt
    case wheel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .touch: return "Touch buttons"
        case .dpad: return "D-pad + face buttons"
        case .tilt: return "Tilt steer"
        case .wheel: return "Steering wheel"
        }
    }
}

struct CareerProgressSnapshot {
    var missionTier: Int
}
