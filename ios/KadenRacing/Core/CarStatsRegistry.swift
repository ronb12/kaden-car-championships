import UIKit

extension GameCatalog {

    private struct Row {
        let id: String
        let speed: Int
        let accel: Int
        let handling: Int
        let category: VehicleCategory
        let unlockCostCredits: Int64
        /// Career missions that must be completed before this car can be purchased.
        let minCareerTier: Int
        let premiumSKU: String?
    }

    /// Unlock prices scaled like top arcade racers — starters are free; legends take a full career.
    private static let rows: [Row] = [
        // Starters (cost 0) — also listed in PlayerProgressStore.starterCarIds
        Row(id: "civic", speed: 81, accel: 86, handling: 99, category: .compact, unlockCostCredits: 0, minCareerTier: 0, premiumSKU: nil),
        Row(id: "mustang", speed: 90, accel: 86, handling: 82, category: .muscle, unlockCostCredits: 0, minCareerTier: 0, premiumSKU: nil),
        Row(id: "camaro", speed: 89, accel: 87, handling: 83, category: .muscle, unlockCostCredits: 0, minCareerTier: 0, premiumSKU: nil),

        // Street — early buys
        Row(id: "s2000", speed: 82, accel: 80, handling: 100, category: .sports, unlockCostCredits: 2_800, minCareerTier: 0, premiumSKU: nil),
        Row(id: "rx7", speed: 85, accel: 84, handling: 96, category: .sports, unlockCostCredits: 3_400, minCareerTier: 0, premiumSKU: nil),
        Row(id: "evo", speed: 84, accel: 90, handling: 99, category: .compact, unlockCostCredits: 3_900, minCareerTier: 0, premiumSKU: nil),
        Row(id: "sti", speed: 83, accel: 88, handling: 97, category: .compact, unlockCostCredits: 4_200, minCareerTier: 0, premiumSKU: nil),
        Row(id: "charger", speed: 88, accel: 84, handling: 78, category: .muscle, unlockCostCredits: 4_800, minCareerTier: 0, premiumSKU: nil),
        Row(id: "falcon-gt", speed: 87, accel: 86, handling: 82, category: .muscle, unlockCostCredits: 5_200, minCareerTier: 0, premiumSKU: nil),
        Row(id: "challenger", speed: 91, accel: 84, handling: 76, category: .muscle, unlockCostCredits: 5_800, minCareerTier: 1, premiumSKU: nil),
        Row(id: "camaro-1970", speed: 88, accel: 87, handling: 80, category: .muscle, unlockCostCredits: 6_200, minCareerTier: 1, premiumSKU: nil),
        Row(id: "firebird-1970", speed: 86, accel: 88, handling: 81, category: .muscle, unlockCostCredits: 6_400, minCareerTier: 1, premiumSKU: nil),

        // Pro
        Row(id: "amg", speed: 94, accel: 88, handling: 90, category: .muscle, unlockCostCredits: 7_500, minCareerTier: 2, premiumSKU: nil),
        Row(id: "m4", speed: 90, accel: 86, handling: 94, category: .sports, unlockCostCredits: 8_200, minCareerTier: 2, premiumSKU: nil),
        Row(id: "supra", speed: 89, accel: 87, handling: 92, category: .sports, unlockCostCredits: 8_800, minCareerTier: 2, premiumSKU: nil),
        Row(id: "r34", speed: 91, accel: 88, handling: 93, category: .sports, unlockCostCredits: 9_500, minCareerTier: 3, premiumSKU: nil),
        Row(id: "gtr", speed: 92, accel: 85, handling: 95, category: .sports, unlockCostCredits: 10_500, minCareerTier: 3, premiumSKU: nil),
        Row(id: "911", speed: 88, accel: 82, handling: 98, category: .sports, unlockCostCredits: 11_200, minCareerTier: 3, premiumSKU: nil),
        Row(id: "rs7", speed: 92, accel: 90, handling: 86, category: .muscle, unlockCostCredits: 12_000, minCareerTier: 4, premiumSKU: nil),
        Row(id: "gt500", speed: 96, accel: 94, handling: 79, category: .muscle, unlockCostCredits: 12_800, minCareerTier: 4, premiumSKU: nil),
        Row(id: "police", speed: 94, accel: 92, handling: 86, category: .policeInterceptor, unlockCostCredits: 13_500, minCareerTier: 4, premiumSKU: nil),

        // Elite
        Row(id: "viper", speed: 97, accel: 92, handling: 80, category: .muscle, unlockCostCredits: 14_500, minCareerTier: 5, premiumSKU: nil),
        Row(id: "nsx", speed: 93, accel: 92, handling: 94, category: .supercar, unlockCostCredits: 16_000, minCareerTier: 5, premiumSKU: nil),
        Row(id: "corvette", speed: 96, accel: 94, handling: 89, category: .supercar, unlockCostCredits: 17_500, minCareerTier: 6, premiumSKU: nil),
        Row(id: "audi-r8", speed: 95, accel: 91, handling: 91, category: .supercar, unlockCostCredits: 19_000, minCareerTier: 6, premiumSKU: nil),
        Row(id: "f40", speed: 100, accel: 90, handling: 80, category: .supercar, unlockCostCredits: 21_000, minCareerTier: 7, premiumSKU: nil),
        Row(id: "r35-nismo", speed: 96, accel: 93, handling: 96, category: .sports, unlockCostCredits: 22_500, minCareerTier: 7, premiumSKU: nil),

        // Legend
        Row(id: "lambo", speed: 98, accel: 95, handling: 75, category: .hypercar, unlockCostCredits: 26_000, minCareerTier: 9, premiumSKU: nil),
        Row(id: "huracan", speed: 98, accel: 96, handling: 90, category: .hypercar, unlockCostCredits: 28_000, minCareerTier: 10, premiumSKU: nil),
        Row(id: "mclaren", speed: 100, accel: 98, handling: 88, category: .hypercar, unlockCostCredits: 30_000, minCareerTier: 11, premiumSKU: nil),
        Row(id: "senna", speed: 99, accel: 97, handling: 99, category: .hypercar, unlockCostCredits: 32_000, minCareerTier: 12, premiumSKU: nil),
        Row(id: "bugatti", speed: 100, accel: 100, handling: 78, category: .hypercar, unlockCostCredits: 34_000, minCareerTier: 13, premiumSKU: nil),
        Row(id: "koenigsegg", speed: 100, accel: 100, handling: 85, category: .hypercar, unlockCostCredits: 36_000, minCareerTier: 14, premiumSKU: nil),
        Row(id: "jesko", speed: 100, accel: 100, handling: 88, category: .hypercar, unlockCostCredits: 38_000, minCareerTier: 15, premiumSKU: nil),
    ]

    /// Full stat profiles for garage & physics (mirrors web car stats).
    static var statProfiles: [CarStatProfile] {
        rows.map {
            CarStatProfile(
                id: $0.id,
                speed: $0.speed,
                acceleration: $0.accel,
                handling: $0.handling,
                nitroEfficiency: min(99, ($0.speed + $0.accel) / 2),
                durability: min(99, 70 + $0.handling / 4),
                category: $0.category,
                unlockCostCredits: $0.unlockCostCredits,
                minCareerTiers: $0.minCareerTier,
                premiumSKU: $0.premiumSKU
            )
        }
    }

    static func profile(forCarIndex index: Int) -> CarStatProfile {
        let cars = GameCatalog.cars
        guard index >= 0, index < cars.count else { return statProfiles[0] }
        let id = cars[index].id
        return statProfiles.first { $0.id == id } ?? statProfiles[0]
    }

    static func profile(forCarId id: String) -> CarStatProfile? {
        statProfiles.first { $0.id == id }
    }

    static func runtimeStats(carIndex: Int, progress: PlayerProgressStore) -> CarRuntimeStats {
        let base = profile(forCarIndex: carIndex)
        let up = progress.upgrades[base.id] ?? .baseline
        let spd = 0.72 + Float(base.speed) / 100 * 0.40 + Float(up.engine) * 0.02
        let acc = 0.88 + Float(base.acceleration) / 100 * 0.28 + Float(up.engine) * 0.025
        let grip = 0.82 + Float(base.handling) / 100 * 0.2 + Float(up.tires) * 0.022
        let nitroCap = 0.9 + Float(base.nitroEfficiency) / 100 * 0.16 + Float(up.nitro) * 0.03
        let nitroRef = 0.85 + Float(up.nitro) * 0.04
        return CarRuntimeStats(
            topSpeedMul: spd,
            accelMul: acc,
            gripMul: grip,
            nitroCapacityMul: nitroCap,
            nitroRefillMul: nitroRef,
            durabilityMul: 0.9 + Float(base.durability) / 100 * 0.16
        )
    }

    /// Garage sort: owned → affordable → locked by career → expensive legends.
    static func garageSortIndex(forCarId id: String, progress: PlayerProgressStore) -> (Int, Int64, String) {
        let owned = progress.unlockedCarIds.contains(id)
        let profile = profile(forCarId: id)
        let cost = profile?.unlockCostCredits ?? 0
        let careerGate = profile?.minCareerTiers ?? 0
        let careerLocked = progress.careerTierCompleted < careerGate
        let tier: Int
        if owned { tier = 0 }
        else if careerLocked { tier = 2 }
        else { tier = 1 }
        return (tier, cost, id)
    }
}
