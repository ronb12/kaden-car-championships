import Combine
import Foundation

/// Central progression, currency, unlocks. Persisted locally; swap backing store for Firebase later.
final class PlayerProgressStore: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published private(set) var credits: Int64 {
        didSet { defaults.set(credits, forKey: Keys.credits) }
    }

    @Published private(set) var unlockedCarIds: Set<String> {
        didSet { defaults.set(Array(unlockedCarIds), forKey: Keys.unlockedCars) }
    }

    @Published private(set) var upgrades: [String: CarUpgradeState] {
        didSet {
            if let data = try? JSONEncoder().encode(upgrades) {
                defaults.set(data, forKey: Keys.upgrades)
            }
        }
    }

    @Published var adsRemoved: Bool {
        didSet { defaults.set(adsRemoved, forKey: Keys.adsRemoved) }
    }

    @Published var premiumActive: Bool {
        didSet { defaults.set(premiumActive, forKey: Keys.premium) }
    }

    init() {
        let savedCredits = Int64(defaults.integer(forKey: Keys.credits))
        credits = savedCredits == 0 ? 2_500 : savedCredits

        if let arr = defaults.array(forKey: Keys.unlockedCars) as? [String] {
            unlockedCarIds = Set(arr)
        } else {
            unlockedCarIds = ["f40", "gtr"]
        }

        if let data = defaults.data(forKey: Keys.upgrades),
           let decoded = try? JSONDecoder().decode([String: CarUpgradeState].self, from: data) {
            upgrades = decoded
        } else {
            upgrades = [:]
        }

        adsRemoved = defaults.bool(forKey: Keys.adsRemoved)
        premiumActive = defaults.bool(forKey: Keys.premium)
    }

    func creditsMutation(_ delta: Int64) {
        credits = max(0, credits + delta)
    }

    func unlockCar(id: String, cost: Int64) -> Bool {
        guard credits >= cost, !unlockedCarIds.contains(id) else { return false }
        credits -= cost
        unlockedCarIds.insert(id)
        return true
    }

    func upgrade(carId: String, slot: UpgradeSlot, cost: Int64) -> Bool {
        guard credits >= cost else { return false }
        var st = upgrades[carId] ?? .baseline
        switch slot {
        case .engine: st.engine = min(5, st.engine + 1)
        case .nitro: st.nitro = min(5, st.nitro + 1)
        case .tires: st.tires = min(5, st.tires + 1)
        }
        credits -= cost
        upgrades[carId] = st
        return true
    }

    func upgradeCost(level: Int) -> Int64 {
        400 + Int64(level) * 220
    }

    enum UpgradeSlot {
        case engine, nitro, tires
    }

    private enum Keys {
        static let credits = "krc.credits"
        static let unlockedCars = "krc.unlocked"
        static let upgrades = "krc.upgrades"
        static let adsRemoved = "krc.adsRemoved"
        static let premium = "krc.premium"
    }
}
