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

    /// Coarse paint buckets so navy / cyan / sky all count as "blue".
    private enum PaintFamily: String, CaseIterable {
        case red, orange, yellow, green, blue, purple, pink, white, dark, brown
    }

    /// Fallback paints when a car's stock color collides with someone already on the grid.
    private static let uniquePaints: [(PaintFamily, UIColor)] = [
        (.red, UIColor(red: 0.86, green: 0.08, blue: 0.10, alpha: 1)),
        (.orange, UIColor(red: 1.00, green: 0.45, blue: 0.06, alpha: 1)),
        (.yellow, UIColor(red: 0.98, green: 0.82, blue: 0.08, alpha: 1)),
        (.green, UIColor(red: 0.12, green: 0.72, blue: 0.28, alpha: 1)),
        (.blue, UIColor(red: 0.08, green: 0.42, blue: 0.95, alpha: 1)),
        (.purple, UIColor(red: 0.52, green: 0.18, blue: 0.85, alpha: 1)),
        (.pink, UIColor(red: 1.00, green: 0.22, blue: 0.68, alpha: 1)),
        (.white, UIColor(red: 0.92, green: 0.93, blue: 0.95, alpha: 1)),
        (.dark, UIColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1)),
        (.brown, UIColor(red: 0.48, green: 0.28, blue: 0.12, alpha: 1)),
    ]

    static func planOpponents(
        playerCarIndex: Int,
        count: Int,
        seed: UInt64 = 0x4B52435F_41495F47,
        playerBodyColor: UIColor? = nil
    ) -> [OpponentSlot] {
        let playerCar = GameCatalog.cars[playerCarIndex]
        let playerPaint = playerBodyColor ?? GarageCustomization.bodyColor(for: playerCar)
        var rng = SeededRandom(seed: seed ^ UInt64(playerCarIndex))
        var pool = GameCatalog.cars.enumerated().filter { $0.element.id != playerCar.id && $0.element.id != "police" }
        pool.shuffle(using: &rng)
        let n = min(count, pool.count, aiNames.count)
        var usedCarIds = Set<String>([playerCar.id])
        var usedFamilies = Set<PaintFamily>([paintFamily(of: playerPaint)])
        var slots: [OpponentSlot] = []

        for i in 0..<n {
            let pickIndex = pool.firstIndex { !usedCarIds.contains($0.element.id) } ?? (i % pool.count)
            let pick = pool[pickIndex]
            usedCarIds.insert(pick.element.id)
            let profile = VehicleVisualProfile.profile(carId: pick.element.id)
            let bodyColor = reservedUniquePaint(stock: pick.element.uiColor, used: &usedFamilies)

            let personality = AIPersonality.allCases[i % AIPersonality.allCases.count]
            slots.append(OpponentSlot(
                name: aiNames[i],
                carId: profile.carId,
                catalogIndex: pick.offset,
                bodyColor: bodyColor,
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
        // Interceptor is black — keep suspects off that dark family too.
        var usedFamilies = Set<PaintFamily>([.dark])
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
                bodyColor: reservedUniquePaint(stock: pick.element.uiColor, used: &usedFamilies),
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

    private static func reservedUniquePaint(stock: UIColor, used: inout Set<PaintFamily>) -> UIColor {
        let stockFamily = paintFamily(of: stock)
        if !used.contains(stockFamily) {
            used.insert(stockFamily)
            return stock
        }
        if let (family, color) = uniquePaints.first(where: { !used.contains($0.0) }) {
            used.insert(family)
            return color
        }
        return stock
    }

    private static func paintFamily(of color: UIColor) -> PaintFamily {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if s < 0.16 {
            return b > 0.72 ? .white : .dark
        }
        let deg = h * 360
        if b < 0.38, deg >= 12, deg < 55 { return .brown }
        if deg >= 345 || deg < 12 { return .red }
        if deg < 45 { return .orange }
        if deg < 72 { return .yellow }
        if deg < 155 { return .green }
        if deg < 255 { return .blue }
        if deg < 290 { return .purple }
        return .pink
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
