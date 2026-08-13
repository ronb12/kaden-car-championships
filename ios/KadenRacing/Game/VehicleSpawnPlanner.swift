import UIKit

/// Assigns unique AI vehicles — no duplicate models in the same race grid.
enum VehicleSpawnPlanner {

    struct OpponentSlot {
        let name: String
        let carId: String
        let catalogIndex: Int
        let bodyColor: UIColor
        let wheelStyle: VehicleWheelStyle
        let personality: AIPersonality
        let baseSpeedMul: Float
    }

    enum AIPersonality: String, CaseIterable {
        case aggressive
        case balanced
        case technical
        case blocker
        case pursuit

        var speedBias: Float {
            switch self {
            case .aggressive: return 1.03
            case .balanced: return 1.0
            case .technical: return 0.97
            case .blocker: return 0.95
            case .pursuit: return 1.06
            }
        }

        var overtakeBiasRange: ClosedRange<Float> {
            switch self {
            case .aggressive: return 0.2...0.55
            case .balanced: return -0.25...0.35
            case .technical: return -0.15...0.2
            case .blocker: return -0.55...0.1
            case .pursuit: return -0.1...0.35
            }
        }
    }

    private static let aiNames = ["YAMAMOTO", "GARCIA", "MÜLLER", "CHEN", "RIVERA", "OKADA", "WEBB", "SANTOS"]

    static func planOpponents(
        playerCarIndex: Int,
        count: Int,
        seed: UInt64 = 0x4B52435F_41495F47
    ) -> [OpponentSlot] {
        let playerId = GameCatalog.cars[playerCarIndex].id
        let playerColor = GameCatalog.cars[playerCarIndex].colorUInt32
        var rng = SeededRandom(seed: seed ^ UInt64(playerCarIndex))
        var pool = GameCatalog.cars.enumerated().filter { $0.element.id != playerId && $0.element.id != "police" }
        pool.shuffle(using: &rng)
        let n = min(count, pool.count, aiNames.count)
        var usedStyles = Set<VehicleBodyStyle>()
        var usedCarIds = Set<String>()
        var usedColors = Set<UInt32>([playerColor])
        var slots: [OpponentSlot] = []

        for i in 0..<n {
            let pick: (Int, CarChoice)
            if i < pool.count {
                pick = pool[i]
            } else {
                pick = pool[i % pool.count]
            }
            var chosen = pick
            var profile = VehicleVisualProfile.profile(carId: chosen.1.id)
            if usedStyles.contains(profile.bodyStyle)
                || usedCarIds.contains(profile.carId)
                || usedColors.contains(chosen.1.colorUInt32),
               let alt = pool.first(where: {
                   let altProfile = VehicleVisualProfile.profile(carId: $0.element.id)
                   return !usedStyles.contains(altProfile.bodyStyle)
                       && !usedCarIds.contains($0.element.id)
                       && !usedColors.contains($0.element.colorUInt32)
               }) {
                chosen = alt
                profile = VehicleVisualProfile.profile(carId: alt.element.id)
            }
            usedStyles.insert(profile.bodyStyle)
            usedCarIds.insert(profile.carId)
            usedColors.insert(chosen.1.colorUInt32)

            let personality = AIPersonality.allCases[i % AIPersonality.allCases.count]
            slots.append(OpponentSlot(
                name: aiNames[i],
                carId: profile.carId,
                catalogIndex: chosen.0,
                bodyColor: chosen.1.uiColor,
                wheelStyle: profile.wheelStyle,
                personality: personality,
                baseSpeedMul: personality.speedBias
            ))
        }
        return slots
    }

    /// Hot Pursuit suspects — sports cars that flee the interceptor (player).
    static func planFleeingSuspects(count: Int = 4) -> [OpponentSlot] {
        let names = ["SUSPECT", "RUNNER", "FUGITIVE", "SPEEDER", "OUTLAW", "ROGUE"]
        let n = min(count, names.count)
        var used = Set<String>(["police"])
        var slots: [OpponentSlot] = []
        let personalities: [AIPersonality] = [.aggressive, .technical, .balanced, .aggressive]
        for i in 0..<n {
            let pool = GameCatalog.cars.enumerated().filter { !used.contains($0.element.id) }
            let pick = pool.randomElement() ?? GameCatalog.cars.enumerated().first!
            used.insert(pick.element.id)
            let profile = VehicleVisualProfile.profile(carId: pick.element.id)
            let personality = personalities[i % personalities.count]
            slots.append(OpponentSlot(
                name: "\(names[i]) \(i + 1)",
                carId: pick.element.id,
                catalogIndex: pick.offset,
                bodyColor: pick.element.uiColor,
                wheelStyle: profile.wheelStyle,
                personality: personality,
                baseSpeedMul: personality.speedBias + Float(i) * 0.015
            ))
        }
        return slots
    }

    /// Legacy helper — interceptor units (unused by player-as-cop Hot Pursuit).
    static func planPursuitCops(count: Int = 4) -> [OpponentSlot] {
        let names = ["UNIT 01", "UNIT 07", "UNIT 12", "UNIT 19", "UNIT 22", "UNIT 31"]
        let n = min(count, names.count)
        guard let police = GameCatalog.cars.first(where: { $0.id == "police" }),
              let policeIdx = GameCatalog.cars.firstIndex(where: { $0.id == "police" }) else {
            return planOpponents(playerCarIndex: 0, count: count)
        }
        let profile = VehicleVisualProfile.profile(carId: "police")
        return (0..<n).map { i in
            OpponentSlot(
                name: names[i],
                carId: "police",
                catalogIndex: policeIdx,
                bodyColor: police.uiColor,
                wheelStyle: profile.wheelStyle,
                personality: .pursuit,
                baseSpeedMul: 1.04 + Float(i) * 0.015
            )
        }
    }

    /// Ghost Duel rivals — translucent pace cars.
    static func planGhostRivals(playerCarIndex: Int, count: Int = 3) -> [OpponentSlot] {
        let base = planOpponents(playerCarIndex: playerCarIndex, count: count)
        return base.enumerated().map { i, slot in
            OpponentSlot(
                name: "GHOST \(i + 1)",
                carId: slot.carId,
                catalogIndex: slot.catalogIndex,
                bodyColor: UIColor(white: 0.75, alpha: 1),
                wheelStyle: slot.wheelStyle,
                personality: .technical,
                baseSpeedMul: slot.baseSpeedMul * 0.98
            )
        }
    }
}

private extension Array {
    mutating func shuffle(using rng: inout SeededRandom) {
        guard count > 1 else { return }
        for i in stride(from: count - 1, through: 1, by: -1) {
            let j = Int(rng.unitFloat() * Float(i + 1))
            swapAt(i, j)
        }
    }
}
