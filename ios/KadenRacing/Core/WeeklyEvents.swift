import Foundation

/// Rotating weekly contracts — retention loop beyond daily challenge.
struct WeeklyContract: Identifiable, Hashable {
    let id: String
    let title: String
    let blurb: String
    let target: Int
    let rewardCredits: Int64
    let kind: Kind

    enum Kind: String, Hashable {
        case finishRaces
        case collectCrystals
        case bustSuspects
        case driftScore
        case winPodium
    }
}

enum WeeklyEvents {
    static func weekKey(from date: Date = Date()) -> Int {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let w = cal.component(.weekOfYear, from: date)
        return y * 100 + w
    }

    static func contracts(forWeekKey key: Int) -> [WeeklyContract] {
        var rng = SeededRandom(seed: UInt64(key) &* 0x9E3779B97F4A7C15)
        let pool: [WeeklyContract] = [
            WeeklyContract(id: "w-races", title: "Grid Grinder", blurb: "Finish 5 races this week.", target: 5, rewardCredits: 900, kind: .finishRaces),
            WeeklyContract(id: "w-crystals", title: "Crystal Rush", blurb: "Collect 40 crystals.", target: 40, rewardCredits: 750, kind: .collectCrystals),
            WeeklyContract(id: "w-busts", title: "Dragnet Duty", blurb: "Issue 8 Hot Pursuit busts.", target: 8, rewardCredits: 1_100, kind: .bustSuspects),
            WeeklyContract(id: "w-drift", title: "Style Week", blurb: "Bank 12,000 drift score.", target: 12_000, rewardCredits: 850, kind: .driftScore),
            WeeklyContract(id: "w-podium", title: "Podium Push", blurb: "Finish top 3 three times.", target: 3, rewardCredits: 1_000, kind: .winPodium),
        ]
        // Pick 3 stable contracts for the week.
        var picks: [WeeklyContract] = []
        var remaining = pool
        for _ in 0..<3 where !remaining.isEmpty {
            let idx = Int(rng.unitFloat() * Float(remaining.count)) % remaining.count
            picks.append(remaining.remove(at: idx))
        }
        return picks
    }
}
