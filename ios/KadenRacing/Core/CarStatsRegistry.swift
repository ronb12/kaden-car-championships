import UIKit

extension GameCatalog {

    /// Full stat profiles for garage & physics.
    static var statProfiles: [CarStatProfile] {
        [
            CarStatProfile(
                id: "f40", speed: 92, acceleration: 88, handling: 82, nitroEfficiency: 78,
                durability: 78, category: .supercar, unlockCostCredits: 0, premiumSKU: nil
            ),
            CarStatProfile(
                id: "lambo", speed: 94, acceleration: 93, handling: 79, nitroEfficiency: 85,
                durability: 74, category: .hypercar, unlockCostCredits: 8_000, premiumSKU: nil
            ),
            CarStatProfile(
                id: "gtr", speed: 89, acceleration: 86, handling: 94, nitroEfficiency: 80,
                durability: 86, category: .sports, unlockCostCredits: 0, premiumSKU: nil
            ),
            CarStatProfile(
                id: "911", speed: 87, acceleration: 84, handling: 96, nitroEfficiency: 82,
                durability: 84, category: .sports, unlockCostCredits: 6_500, premiumSKU: nil
            ),
            CarStatProfile(
                id: "mclaren", speed: 96, acceleration: 95, handling: 88, nitroEfficiency: 88,
                durability: 72, category: .hypercar, unlockCostCredits: 12_000, premiumSKU: nil
            ),
            CarStatProfile(
                id: "bugatti", speed: 99, acceleration: 99, handling: 76, nitroEfficiency: 90,
                durability: 70, category: .hypercar, unlockCostCredits: 25_000, premiumSKU: "com.kaden.racing.car.bugatti"
            )
        ]
    }

    static func profile(forCarIndex index: Int) -> CarStatProfile {
        let cars = GameCatalog.cars
        guard index >= 0, index < cars.count else { return statProfiles[0] }
        let id = cars[index].id
        return statProfiles.first { $0.id == id } ?? statProfiles[0]
    }

    static func runtimeStats(carIndex: Int, progress: PlayerProgressStore) -> CarRuntimeStats {
        let base = profile(forCarIndex: carIndex)
        let up = progress.upgrades[base.id] ?? .baseline
        let spd = 0.82 + Float(base.speed) / 100 * 0.22 + Float(up.engine) * 0.018
        let acc = 0.82 + Float(base.acceleration) / 100 * 0.22 + Float(up.engine) * 0.02
        let grip = 0.82 + Float(base.handling) / 100 * 0.2 + Float(up.tires) * 0.022
        let nitroCap = 0.9 + Float(base.nitroEfficiency) / 100 * 0.16 + Float(up.nitro) * 0.03
        let nitroRef = 0.85 + Float(up.nitro) * 0.04
        let dur = 0.9 + Float(base.durability) / 100 * 0.16
        return CarRuntimeStats(
            topSpeedMul: spd,
            accelMul: acc,
            gripMul: grip,
            nitroCapacityMul: nitroCap,
            nitroRefillMul: nitroRef,
            durabilityMul: dur
        )
    }
}
