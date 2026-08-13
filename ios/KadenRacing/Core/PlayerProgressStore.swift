import Combine
import Foundation

/// Central progression, currency, unlocks. Persisted locally; swap backing store for Firebase later.
final class PlayerProgressStore: ObservableObject {
    private let defaults = UserDefaults.standard

    /// Fresh-install garage — earn everything else with credits or career.
    static let starterCarIds: Set<String> = [
        "civic", "mustang", "camaro",
    ]

    private static let economyVersionKey = "krc.garage.economy.v2"

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

    /// Completed career mission count (0…CareerMissions.all.count).
    @Published private(set) var careerTierCompleted: Int {
        didSet { defaults.set(careerTierCompleted, forKey: Keys.careerTier) }
    }

    @Published var adsRemoved: Bool {
        didSet { defaults.set(adsRemoved, forKey: Keys.adsRemoved) }
    }

    @Published var premiumActive: Bool {
        didSet { defaults.set(premiumActive, forKey: Keys.premium) }
    }

    /// Calendar day key for daily challenge (`yyyyMMdd`).
    @Published private(set) var dailyChallengeDayKey: Int {
        didSet { defaults.set(dailyChallengeDayKey, forKey: Keys.dailyDay) }
    }

    @Published private(set) var dailyBestMs: Int64 {
        didSet { defaults.set(dailyBestMs, forKey: Keys.dailyBest) }
    }

    @Published private(set) var dailyStreak: Int {
        didSet { defaults.set(dailyStreak, forKey: Keys.dailyStreak) }
    }

    @Published private(set) var dailyClaimedDayKey: Int {
        didSet { defaults.set(dailyClaimedDayKey, forKey: Keys.dailyClaimed) }
    }

    /// Highest Hot Pursuit chapter index unlocked (0-based).
    @Published private(set) var pursuitChapterUnlocked: Int {
        didSet { defaults.set(pursuitChapterUnlocked, forKey: Keys.pursuitChapter) }
    }

    /// Lifetime courier deliveries (ladder XP).
    @Published private(set) var courierDeliveriesLifetime: Int {
        didSet { defaults.set(courierDeliveriesLifetime, forKey: Keys.courierDeliveries) }
    }

    /// Stickers collected (id → count) for the trophy row.
    @Published private(set) var stickerCounts: [String: Int] {
        didSet { defaults.set(stickerCounts, forKey: Keys.stickers) }
    }

    @Published private(set) var unlockedPaintIds: Set<String> {
        didSet { defaults.set(Array(unlockedPaintIds), forKey: Keys.paints) }
    }

    @Published private(set) var unlockedWrapIds: Set<String> {
        didSet { defaults.set(Array(unlockedWrapIds), forKey: Keys.wraps) }
    }

    @Published private(set) var racesFinishedCount: Int {
        didSet { defaults.set(racesFinishedCount, forKey: Keys.racesFinished) }
    }

    @Published private(set) var ownedToyIds: Set<String> {
        didSet { defaults.set(Array(ownedToyIds), forKey: Keys.toys) }
    }

    @Published private(set) var equippedToyIds: Set<String> {
        didSet { defaults.set(Array(equippedToyIds), forKey: Keys.equippedToys) }
    }

    @Published private(set) var ownedPlateIds: Set<String> {
        didSet { defaults.set(Array(ownedPlateIds), forKey: Keys.plates) }
    }

    @Published private(set) var equippedPlateId: String {
        didSet { defaults.set(equippedPlateId, forKey: Keys.equippedPlate) }
    }

    @Published private(set) var ownedHatIds: Set<String> {
        didSet { defaults.set(Array(ownedHatIds), forKey: Keys.hats) }
    }

    @Published private(set) var equippedHatId: String {
        didSet { defaults.set(equippedHatId, forKey: Keys.equippedHat) }
    }

    @Published private(set) var equippedHoodStickerId: String {
        didSet { defaults.set(equippedHoodStickerId, forKey: Keys.hoodSticker) }
    }

    @Published private(set) var equippedDoorStickerId: String {
        didSet { defaults.set(equippedDoorStickerId, forKey: Keys.doorSticker) }
    }

    @Published private(set) var lifetimeCrystals: Int {
        didSet { defaults.set(lifetimeCrystals, forKey: Keys.crystals) }
    }

    @Published private(set) var trophyWins: Int {
        didSet { defaults.set(trophyWins, forKey: Keys.trophies) }
    }

    init() {
        let savedCredits = Int64(defaults.integer(forKey: Keys.credits))
        credits = savedCredits == 0 && defaults.object(forKey: Keys.credits) == nil
            ? 2_500
            : max(0, savedCredits)

        if let arr = defaults.array(forKey: Keys.unlockedCars) as? [String], !arr.isEmpty {
            unlockedCarIds = Set(arr)
        } else {
            unlockedCarIds = Self.starterCarIds
        }

        if let data = defaults.data(forKey: Keys.upgrades),
           let decoded = try? JSONDecoder().decode([String: CarUpgradeState].self, from: data) {
            upgrades = decoded
        } else {
            upgrades = [:]
        }

        careerTierCompleted = min(
            max(0, defaults.integer(forKey: Keys.careerTier)),
            CareerMissions.all.count
        )
        adsRemoved = defaults.bool(forKey: Keys.adsRemoved)
        premiumActive = defaults.bool(forKey: Keys.premium)
        dailyChallengeDayKey = defaults.integer(forKey: Keys.dailyDay)
        dailyBestMs = Int64(defaults.integer(forKey: Keys.dailyBest))
        dailyStreak = max(0, defaults.integer(forKey: Keys.dailyStreak))
        dailyClaimedDayKey = defaults.integer(forKey: Keys.dailyClaimed)
        pursuitChapterUnlocked = min(
            max(0, defaults.integer(forKey: Keys.pursuitChapter)),
            max(0, PursuitCampaign.chapters.count - 1)
        )
        courierDeliveriesLifetime = max(0, defaults.integer(forKey: Keys.courierDeliveries))
        stickerCounts = (defaults.dictionary(forKey: Keys.stickers) as? [String: Int]) ?? [:]
        if let arr = defaults.array(forKey: Keys.paints) as? [String], !arr.isEmpty {
            unlockedPaintIds = Set(arr)
        } else {
            unlockedPaintIds = Set(KidPlayLoop.starterPaints.map(\.rawValue))
        }
        if let arr = defaults.array(forKey: Keys.wraps) as? [String], !arr.isEmpty {
            unlockedWrapIds = Set(arr)
        } else {
            unlockedWrapIds = Set(KidPlayLoop.starterWraps.map(\.rawValue))
        }
        racesFinishedCount = max(0, defaults.integer(forKey: Keys.racesFinished))
        if let arr = defaults.array(forKey: Keys.toys) as? [String] {
            ownedToyIds = Set(arr)
        } else {
            ownedToyIds = []
        }
        if let arr = defaults.array(forKey: Keys.equippedToys) as? [String] {
            equippedToyIds = Set(arr)
        } else {
            equippedToyIds = []
        }
        let plates: Set<String>
        if let arr = defaults.array(forKey: Keys.plates) as? [String], !arr.isEmpty {
            plates = Set(arr)
        } else {
            plates = Set(KidPlayLoop.starterPlates.map(\.rawValue))
        }
        ownedPlateIds = plates
        let savedPlate = defaults.string(forKey: Keys.equippedPlate) ?? KidPlate.krc.rawValue
        equippedPlateId = plates.contains(savedPlate) ? savedPlate : KidPlate.krc.rawValue
        if let arr = defaults.array(forKey: Keys.hats) as? [String] {
            ownedHatIds = Set(arr)
        } else {
            ownedHatIds = []
        }
        equippedHatId = defaults.string(forKey: Keys.equippedHat) ?? ""
        equippedHoodStickerId = defaults.string(forKey: Keys.hoodSticker) ?? ""
        equippedDoorStickerId = defaults.string(forKey: Keys.doorSticker) ?? ""
        lifetimeCrystals = max(0, defaults.integer(forKey: Keys.crystals))
        trophyWins = max(0, defaults.integer(forKey: Keys.trophies))
        migrateGarageEconomyIfNeeded()
        migrateKidCollectionIfNeeded()
        rollDailyIfNeeded()
        loadWeekly()
        applyCourierRankUnlocks()
        syncShowOff()
    }

    private func migrateKidCollectionIfNeeded() {
        guard !defaults.bool(forKey: Keys.kidCollection) else { return }
        defaults.set(true, forKey: Keys.kidCollection)
        var paints = unlockedPaintIds.union(KidPlayLoop.starterPaints.map(\.rawValue))
        var wraps = unlockedWrapIds.union(KidPlayLoop.starterWraps.map(\.rawValue))
        for car in GameCatalog.cars {
            let style = GarageCustomization.style(for: car.id)
            paints.insert(style.paint.rawValue)
            wraps.insert(style.wrap.rawValue)
        }
        unlockedPaintIds = paints
        unlockedWrapIds = wraps
    }

    func ownsPaint(_ paint: GaragePaintSwatch) -> Bool {
        unlockedPaintIds.contains(paint.rawValue)
    }

    func ownsWrap(_ wrap: GarageWrapStyle) -> Bool {
        wrap == .none || unlockedWrapIds.contains(wrap.rawValue)
    }

    /// Apply a post-race loot drop. Returns the same drop with credits already granted.
    @discardableResult
    func grantKidLoot(_ drop: KidLootDrop) -> KidLootDrop {
        stickerCounts[drop.sticker.rawValue, default: 0] += 1
        if equippedHoodStickerId.isEmpty {
            equippedHoodStickerId = drop.sticker.rawValue
        } else if equippedDoorStickerId.isEmpty {
            equippedDoorStickerId = drop.sticker.rawValue
        }
        if let paint = drop.paint {
            unlockedPaintIds.insert(paint.rawValue)
        }
        if let wrap = drop.wrap {
            unlockedWrapIds.insert(wrap.rawValue)
        }
        if let toy = drop.toy {
            ownedToyIds.insert(toy.rawValue)
            equippedToyIds.insert(toy.rawValue)
        }
        if let plate = drop.plate {
            ownedPlateIds.insert(plate.rawValue)
            equippedPlateId = plate.rawValue
        }
        if let hat = drop.hat {
            ownedHatIds.insert(hat.rawValue)
            equippedHatId = hat.rawValue
        }
        if drop.crystals > 0 {
            lifetimeCrystals += drop.crystals
        }
        if drop.trophy {
            trophyWins += 1
        }
        if drop.bonusCredits > 0 {
            creditsMutation(drop.bonusCredits)
        }
        racesFinishedCount += 1
        syncShowOff()
        return drop
    }

    var trophyStickers: [KidSticker] {
        KidSticker.allCases.filter { (stickerCounts[$0.rawValue] ?? 0) > 0 }
    }

    var albumSubtitle: String {
        let stickers = trophyStickers.count
        return "\(stickers) stickers · \(lifetimeCrystals) crystals · \(trophyWins) trophies"
    }

    func ownsToy(_ toy: KidToy) -> Bool { ownedToyIds.contains(toy.rawValue) }
    func ownsPlate(_ plate: KidPlate) -> Bool { ownedPlateIds.contains(plate.rawValue) }
    func ownsHat(_ hat: KidHat) -> Bool { ownedHatIds.contains(hat.rawValue) }
    func ownsSticker(_ sticker: KidSticker) -> Bool { (stickerCounts[sticker.rawValue] ?? 0) > 0 }

    func equipHoodSticker(_ sticker: KidSticker?) {
        equippedHoodStickerId = sticker?.rawValue ?? ""
        syncShowOff()
    }

    func equipDoorSticker(_ sticker: KidSticker?) {
        equippedDoorStickerId = sticker?.rawValue ?? ""
        syncShowOff()
    }

    func toggleToy(_ toy: KidToy) {
        guard ownsToy(toy) else { return }
        if equippedToyIds.contains(toy.rawValue) {
            equippedToyIds.remove(toy.rawValue)
        } else {
            equippedToyIds.insert(toy.rawValue)
        }
        syncShowOff()
    }

    func equipPlate(_ plate: KidPlate) {
        guard ownsPlate(plate) else { return }
        equippedPlateId = plate.rawValue
        syncShowOff()
    }

    func equipHat(_ hat: KidHat?) {
        if let hat {
            guard ownsHat(hat) else { return }
            equippedHatId = hat.rawValue
        } else {
            equippedHatId = ""
        }
        syncShowOff()
    }

    func syncShowOff() {
        let owned = KidSticker.allCases.filter { (stickerCounts[$0.rawValue] ?? 0) > 0 }
        var counts: [KidSticker: Int] = [:]
        for sticker in owned {
            counts[sticker] = stickerCounts[sticker.rawValue] ?? 0
        }
        let toys = Set(KidToy.allCases.filter { equippedToyIds.contains($0.rawValue) })
        KidShowOffLoadout.live = KidShowOffLoadout(
            hoodSticker: KidSticker(rawValue: equippedHoodStickerId),
            doorSticker: KidSticker(rawValue: equippedDoorStickerId),
            toys: toys,
            plate: KidPlate(rawValue: equippedPlateId) ?? .krc,
            hat: KidHat(rawValue: equippedHatId),
            ownedStickers: owned,
            stickerCounts: counts
        )
    }

    /// Rebuild unlocks from starters + career rewards when moving off the free-garage era.
    private func migrateGarageEconomyIfNeeded() {
        guard !defaults.bool(forKey: Self.economyVersionKey) else { return }
        defaults.set(true, forKey: Self.economyVersionKey)
        var earned = Self.starterCarIds
        for i in 0..<careerTierCompleted {
            if let id = CareerMissions.mission(atTier: i).unlockCarId {
                earned.insert(id)
            }
        }
        // Keep any car that already has paid upgrades — player invested in it.
        for (carId, state) in upgrades where state.engine > 0 || state.nitro > 0 || state.tires > 0 {
            earned.insert(carId)
        }
        unlockedCarIds = earned
        // If selection points at a locked car, garage UI will block race until they unlock.
    }

    static func todayDayKey(from date: Date = Date()) -> Int {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 2026) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)
    }

    /// Reset daily best when the calendar day changes; keep streak until a miss is detected on claim.
    func rollDailyIfNeeded(now: Date = Date()) {
        let today = Self.todayDayKey(from: now)
        if dailyChallengeDayKey != today {
            dailyChallengeDayKey = today
            dailyBestMs = 0
        }
    }

    var dailyCompletedToday: Bool {
        rollDailyIfNeeded()
        return dailyClaimedDayKey == dailyChallengeDayKey && dailyBestMs > 0
    }

    var dailySubtitle: String {
        rollDailyIfNeeded()
        if dailyBestMs > 0 {
            let sec = Double(dailyBestMs) / 1000
            let streakBit = dailyStreak > 1 ? " · \(dailyStreak)-day streak" : ""
            return String(format: "Best %.1fs%@", sec, streakBit)
        }
        let streakBit = dailyStreak > 0 ? " · streak \(dailyStreak)" : ""
        return "Seeded time trial · resets daily\(streakBit)"
    }

    /// Record a daily challenge finish. Returns bonus credits to fold into the race purse (does not mutate balance).
    @discardableResult
    func registerDailyChallengeFinish(time: TimeInterval) -> Int64 {
        rollDailyIfNeeded()
        let ms = Int64(time * 1000)
        let improved = dailyBestMs == 0 || ms < dailyBestMs
        if improved {
            dailyBestMs = ms
        }
        // Already claimed today — small improvement tip only (paid via race purse).
        guard dailyClaimedDayKey != dailyChallengeDayKey else {
            return improved ? 80 : 0
        }
        let yesterday = Self.todayDayKey(from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        if dailyClaimedDayKey == yesterday {
            dailyStreak += 1
        } else {
            dailyStreak = 1
        }
        dailyClaimedDayKey = dailyChallengeDayKey
        // First completion of the day — streak bonus paid once via race purse.
        return Int64(min(400, 120 + dailyStreak * 40))
    }

    func unlockNextPursuitChapter() {
        pursuitChapterUnlocked = min(PursuitCampaign.chapters.count - 1, pursuitChapterUnlocked + 1)
    }

    var courierRank: CourierCareer.Rank {
        CourierCareer.rank(forDeliveries: courierDeliveriesLifetime)
    }

    var courierRankSubtitle: String {
        let rank = courierRank
        if let next = CourierCareer.nextRank(afterDeliveries: courierDeliveriesLifetime) {
            let left = next.deliveriesRequired - courierDeliveriesLifetime
            return "\(rank.title) · \(left) to \(next.title)"
        }
        return "\(rank.title) · MAX"
    }

    /// Record a finished courier shift. Returns newly unlocked car name if any.
    @discardableResult
    func registerCourierShift(deliveries: Int) -> String? {
        guard deliveries > 0 else { return nil }
        let before = courierRank
        courierDeliveriesLifetime += deliveries
        applyCourierRankUnlocks()
        let after = courierRank
        if after.id > before.id, let carId = after.unlockCarId, grantCar(id: carId),
           let car = GameCatalog.cars.first(where: { $0.id == carId }) {
            return car.name
        }
        return nil
    }

    private func applyCourierRankUnlocks() {
        for rank in CourierCareer.ranks where courierDeliveriesLifetime >= rank.deliveriesRequired {
            if let carId = rank.unlockCarId {
                _ = grantCar(id: carId)
            }
        }
    }

    // MARK: - Weekly contracts

    @Published private(set) var weeklyKey: Int = 0
    @Published private(set) var weeklyProgress: [String: Int] = [:]
    @Published private(set) var weeklyClaimed: Set<String> = []

    func rollWeeklyIfNeeded(now: Date = Date()) {
        let key = WeeklyEvents.weekKey(from: now)
        if weeklyKey != key {
            weeklyKey = key
            weeklyProgress = [:]
            weeklyClaimed = []
            defaults.set(weeklyKey, forKey: Keys.weeklyKey)
            defaults.set([:], forKey: Keys.weeklyProgress)
            defaults.set([], forKey: Keys.weeklyClaimed)
        }
    }

    var weeklySubtitle: String {
        rollWeeklyIfNeeded()
        let contracts = WeeklyEvents.contracts(forWeekKey: weeklyKey)
        let done = contracts.filter { weeklyClaimed.contains($0.id) }.count
        return "\(done)/\(contracts.count) contracts · week \(weeklyKey % 100)"
    }

    func noteWeeklyProgress(
        racesFinished: Int = 0,
        crystals: Int = 0,
        busts: Int = 0,
        drift: Int = 0,
        podium: Bool = false
    ) {
        rollWeeklyIfNeeded()
        func bump(_ id: String, by amount: Int) {
            guard amount > 0 else { return }
            weeklyProgress[id, default: 0] += amount
        }
        for c in WeeklyEvents.contracts(forWeekKey: weeklyKey) {
            switch c.kind {
            case .finishRaces: bump(c.id, by: racesFinished)
            case .collectCrystals: bump(c.id, by: crystals)
            case .bustSuspects: bump(c.id, by: busts)
            case .driftScore: bump(c.id, by: drift)
            case .winPodium: bump(c.id, by: podium ? 1 : 0)
            }
        }
        persistWeekly()
    }

    @discardableResult
    func claimWeeklyContract(_ id: String) -> Int64 {
        rollWeeklyIfNeeded()
        guard !weeklyClaimed.contains(id),
              let contract = WeeklyEvents.contracts(forWeekKey: weeklyKey).first(where: { $0.id == id }),
              weeklyProgress[id, default: 0] >= contract.target
        else { return 0 }
        weeklyClaimed.insert(id)
        creditsMutation(contract.rewardCredits)
        persistWeekly()
        return contract.rewardCredits
    }

    private func persistWeekly() {
        defaults.set(weeklyKey, forKey: Keys.weeklyKey)
        defaults.set(weeklyProgress, forKey: Keys.weeklyProgress)
        defaults.set(Array(weeklyClaimed), forKey: Keys.weeklyClaimed)
    }

    private func loadWeekly() {
        weeklyKey = defaults.integer(forKey: Keys.weeklyKey)
        weeklyProgress = (defaults.dictionary(forKey: Keys.weeklyProgress) as? [String: Int]) ?? [:]
        if let arr = defaults.array(forKey: Keys.weeklyClaimed) as? [String] {
            weeklyClaimed = Set(arr)
        } else {
            weeklyClaimed = []
        }
        rollWeeklyIfNeeded()
    }

    var currentCareerMission: CareerMission? {
        guard careerTierCompleted < CareerMissions.all.count else { return nil }
        return CareerMissions.mission(atTier: careerTierCompleted)
    }

    var careerComplete: Bool {
        careerTierCompleted >= CareerMissions.all.count
    }

    func creditsMutation(_ delta: Int64) {
        credits = max(0, credits + delta)
    }

    /// Unlock without spending credits (career rewards, grants).
    @discardableResult
    func grantCar(id: String) -> Bool {
        guard !unlockedCarIds.contains(id) else { return false }
        unlockedCarIds.insert(id)
        return true
    }

    func unlockCar(id: String, cost: Int64) -> Bool {
        guard !unlockedCarIds.contains(id) else { return false }
        guard canPurchaseCar(id: id) else { return false }
        let price = GameCatalog.profile(forCarId: id)?.unlockCostCredits ?? cost
        guard price > 0, credits >= price else { return false }
        credits -= price
        unlockedCarIds.insert(id)
        return true
    }

    /// True when career gate is cleared and the car isn't free-starter-only locked wrongly.
    func canPurchaseCar(id: String) -> Bool {
        guard let profile = GameCatalog.profile(forCarId: id) else { return false }
        guard profile.unlockCostCredits > 0 else { return false }
        return careerTierCompleted >= profile.minCareerTiers
    }

    func unlockStatus(forCarId id: String) -> CarUnlockStatus {
        if unlockedCarIds.contains(id) { return .owned }
        guard let profile = GameCatalog.profile(forCarId: id) else { return .locked(reason: "Unavailable") }
        if profile.unlockCostCredits <= 0 {
            // Should already be owned as starter — grant defensively.
            _ = grantCar(id: id)
            return .owned
        }
        if careerTierCompleted < profile.minCareerTiers {
            return .careerGated(tiersNeeded: profile.minCareerTiers)
        }
        if credits < profile.unlockCostCredits {
            return .needCredits(cost: profile.unlockCostCredits)
        }
        return .purchasable(cost: profile.unlockCostCredits)
    }

    enum CarUnlockStatus: Equatable {
        case owned
        case purchasable(cost: Int64)
        case needCredits(cost: Int64)
        case careerGated(tiersNeeded: Int)
        case locked(reason: String)
    }

    func upgrade(carId: String, slot: UpgradeSlot, cost: Int64) -> Bool {
        guard credits >= cost else { return false }
        var st = upgrades[carId] ?? .baseline
        switch slot {
        case .engine:
            guard st.engine < 5 else { return false }
            st.engine += 1
        case .nitro:
            guard st.nitro < 5 else { return false }
            st.nitro += 1
        case .tires:
            guard st.tires < 5 else { return false }
            st.tires += 1
        }
        credits -= cost
        upgrades[carId] = st
        return true
    }

    func upgradeCost(level: Int) -> Int64 {
        400 + Int64(level) * 220
    }

    /// Advance one career tier and grant mission rewards. Returns unlock car id if newly granted.
    @discardableResult
    func completeCareerMission() -> (credits: Int64, unlockedCarId: String?) {
        guard let mission = currentCareerMission else { return (0, nil) }
        creditsMutation(mission.rewardCredits)
        var unlocked: String?
        if let carId = mission.unlockCarId, grantCar(id: carId) {
            unlocked = carId
        }
        careerTierCompleted = min(CareerMissions.all.count, careerTierCompleted + 1)
        return (mission.rewardCredits, unlocked)
    }

    func resetAllProgress() {
        credits = 2_500
        unlockedCarIds = Self.starterCarIds
        upgrades = [:]
        careerTierCompleted = 0
        adsRemoved = false
        premiumActive = false
        dailyChallengeDayKey = Self.todayDayKey()
        dailyBestMs = 0
        dailyStreak = 0
        dailyClaimedDayKey = 0
        pursuitChapterUnlocked = 0
        stickerCounts = [:]
        unlockedPaintIds = Set(KidPlayLoop.starterPaints.map(\.rawValue))
        unlockedWrapIds = Set(KidPlayLoop.starterWraps.map(\.rawValue))
        racesFinishedCount = 0
        ownedToyIds = []
        equippedToyIds = []
        ownedPlateIds = Set(KidPlayLoop.starterPlates.map(\.rawValue))
        equippedPlateId = KidPlate.krc.rawValue
        ownedHatIds = []
        equippedHatId = ""
        equippedHoodStickerId = ""
        equippedDoorStickerId = ""
        lifetimeCrystals = 0
        trophyWins = 0
        syncShowOff()
        weeklyKey = WeeklyEvents.weekKey()
        weeklyProgress = [:]
        weeklyClaimed = []
        persistWeekly()
    }

    enum UpgradeSlot {
        case engine, nitro, tires

        var shortTitle: String {
            switch self {
            case .engine: return "ENGINE"
            case .nitro: return "NITRO"
            case .tires: return "TIRES"
            }
        }

        /// What this upgrade path improves overall.
        var benefitHeadline: String {
            switch self {
            case .engine: return "Top speed & acceleration"
            case .nitro: return "Boost tank & recharge"
            case .tires: return "Grip & cornering"
            }
        }

        /// Per-level gain shown before purchase (matches runtimeStats multipliers).
        var nextLevelGain: String {
            switch self {
            case .engine: return "Next: +2% speed · +2.5% accel"
            case .nitro: return "Next: +3% tank · +4% refill"
            case .tires: return "Next: +2.2% grip"
            }
        }
    }

    private enum Keys {
        static let credits = "krc.credits"
        static let unlockedCars = "krc.unlocked"
        static let upgrades = "krc.upgrades"
        static let adsRemoved = "krc.adsRemoved"
        static let premium = "krc.premium"
        static let careerTier = "krc.career.tier"
        static let dailyDay = "krc.daily.day"
        static let dailyBest = "krc.daily.best"
        static let dailyStreak = "krc.daily.streak"
        static let dailyClaimed = "krc.daily.claimed"
        static let pursuitChapter = "krc.pursuit.chapter"
        static let courierDeliveries = "krc.courier.deliveries"
        static let stickers = "krc.kid.stickers"
        static let paints = "krc.kid.paints"
        static let wraps = "krc.kid.wraps"
        static let racesFinished = "krc.kid.races"
        static let kidCollection = "krc.kid.collection.v1"
        static let toys = "krc.kid.toys"
        static let equippedToys = "krc.kid.toys.eq"
        static let plates = "krc.kid.plates"
        static let equippedPlate = "krc.kid.plate.eq"
        static let hats = "krc.kid.hats"
        static let equippedHat = "krc.kid.hat.eq"
        static let hoodSticker = "krc.kid.sticker.hood"
        static let doorSticker = "krc.kid.sticker.door"
        static let crystals = "krc.kid.crystals"
        static let trophies = "krc.kid.trophies"
        static let weeklyKey = "krc.weekly.key"
        static let weeklyProgress = "krc.weekly.progress"
        static let weeklyClaimed = "krc.weekly.claimed"
    }
}
