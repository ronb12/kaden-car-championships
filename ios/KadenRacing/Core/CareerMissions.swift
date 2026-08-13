import Foundation

/// Career ladder — missions that unlock the next tier and teach each mode.
struct CareerMission: Identifiable, Hashable {
    enum WinCondition: Hashable {
        case finish
        case finishTop(Int)
        case bustsAtLeast(Int)
        case driftAtLeast(Int64)
        case dailyComplete
    }

    let id: String
    let title: String
    let blurb: String
    let trackIndex: Int
    let laps: Int
    let nightPreferred: Bool
    let rewardCredits: Int64
    let unlockCarId: String?
    let win: WinCondition
    /// Optional mode override; nil keeps default career circuit.
    let modeOverride: GameModeKind?
}

enum CareerMissions {
    static let all: [CareerMission] = [
        CareerMission(
            id: "c01-rookie",
            title: "Rookie Circuit",
            blurb: "Finish 3 laps. Earn your first purse.",
            trackIndex: 0,
            laps: 3,
            nightPreferred: false,
            rewardCredits: 800,
            unlockCarId: "s2000",
            win: .finish,
            modeOverride: nil
        ),
        CareerMission(
            id: "c02-podium",
            title: "Podium Pressure",
            blurb: "Finish top 3 against a full grid.",
            trackIndex: 0,
            laps: 3,
            nightPreferred: false,
            rewardCredits: 950,
            unlockCarId: "rx7",
            win: .finishTop(3),
            modeOverride: nil
        ),
        CareerMission(
            id: "c03-night",
            title: "Neon Night Run",
            blurb: "Race under the lights. Keep it clean.",
            trackIndex: 1,
            laps: 3,
            nightPreferred: true,
            rewardCredits: 1_100,
            unlockCarId: "gtr",
            win: .finish,
            modeOverride: nil
        ),
        CareerMission(
            id: "c04-courier",
            title: "First Dispatch",
            blurb: "Complete a Courier Run with at least 3 deliveries.",
            trackIndex: 1,
            laps: 1,
            nightPreferred: false,
            rewardCredits: 1_200,
            unlockCarId: "evo",
            win: .bustsAtLeast(3),
            modeOverride: .courier
        ),
        CareerMission(
            id: "c05-pursuit",
            title: "Interceptor Trial",
            blurb: "Bust at least 2 fleeing racers.",
            trackIndex: 2,
            laps: 3,
            nightPreferred: true,
            rewardCredits: 1_400,
            unlockCarId: "police",
            win: .bustsAtLeast(2),
            modeOverride: .policeChase
        ),
        CareerMission(
            id: "c06-lockdown",
            title: "City Lockdown",
            blurb: "Hot Pursuit — clear 3 busts.",
            trackIndex: 2,
            laps: 3,
            nightPreferred: true,
            rewardCredits: 1_550,
            unlockCarId: "challenger",
            win: .bustsAtLeast(3),
            modeOverride: .policeChase
        ),
        CareerMission(
            id: "c07-ghost",
            title: "Ghost Mirror",
            blurb: "Race your pace against translucent rivals.",
            trackIndex: 3,
            laps: 3,
            nightPreferred: false,
            rewardCredits: 1_600,
            unlockCarId: "911",
            win: .finish,
            modeOverride: .ghostDuel
        ),
        CareerMission(
            id: "c08-time",
            title: "Stopwatch Spec",
            blurb: "Time Trial focus — finish clean.",
            trackIndex: 3,
            laps: 3,
            nightPreferred: false,
            rewardCredits: 1_700,
            unlockCarId: "supra",
            win: .finish,
            modeOverride: .timeTrial
        ),
        CareerMission(
            id: "c09-daily",
            title: "Daily Contract",
            blurb: "Complete today's seeded challenge.",
            trackIndex: 0,
            laps: 3,
            nightPreferred: false,
            rewardCredits: 1_800,
            unlockCarId: "amg",
            win: .dailyComplete,
            modeOverride: .timeTrial
        ),
        CareerMission(
            id: "c10-top2",
            title: "Silver Scythe",
            blurb: "Finish 2nd or better.",
            trackIndex: 4,
            laps: 4,
            nightPreferred: false,
            rewardCredits: 1_950,
            unlockCarId: "nsx",
            win: .finishTop(2),
            modeOverride: nil
        ),
        CareerMission(
            id: "c11-night2",
            title: "Midnight Gate",
            blurb: "Night circuit under pressure.",
            trackIndex: 4,
            laps: 4,
            nightPreferred: true,
            rewardCredits: 2_050,
            unlockCarId: "f40",
            win: .finish,
            modeOverride: nil
        ),
        CareerMission(
            id: "c12-drift2",
            title: "Style Points",
            blurb: "Bank 4,000 drift score.",
            trackIndex: 5,
            laps: 3,
            nightPreferred: false,
            rewardCredits: 2_150,
            unlockCarId: "corvette",
            win: .driftAtLeast(4_000),
            modeOverride: .endless
        ),
        CareerMission(
            id: "c13-pursuit2",
            title: "Dragnet Ace",
            blurb: "Interceptor — bust 4 suspects.",
            trackIndex: 5,
            laps: 3,
            nightPreferred: true,
            rewardCredits: 2_300,
            unlockCarId: "lambo",
            win: .bustsAtLeast(4),
            modeOverride: .policeChase
        ),
        CareerMission(
            id: "c14-ghost2",
            title: "Phantom Duel",
            blurb: "Beat the ghost field on pace alone.",
            trackIndex: 6,
            laps: 3,
            nightPreferred: false,
            rewardCredits: 2_400,
            unlockCarId: "mclaren",
            win: .finishTop(2),
            modeOverride: .ghostDuel
        ),
        CareerMission(
            id: "c15-finale",
            title: "Championship Gate",
            blurb: "Finish 1st. Prove you belong.",
            trackIndex: 7,
            laps: 4,
            nightPreferred: false,
            rewardCredits: 3_000,
            unlockCarId: "jesko",
            win: .finishTop(1),
            modeOverride: nil
        ),
    ]

    static func mission(atTier tier: Int) -> CareerMission {
        let i = min(max(tier, 0), all.count - 1)
        return all[i]
    }

    static func meetsWin(
        _ mission: CareerMission,
        position: Int,
        busts: Int,
        driftScore: Int64,
        dailyJustCompleted: Bool
    ) -> Bool {
        switch mission.win {
        case .finish:
            return true
        case .finishTop(let n):
            return position <= max(1, n)
        case .bustsAtLeast(let n):
            return busts >= n
        case .driftAtLeast(let n):
            return driftScore >= n
        case .dailyComplete:
            return dailyJustCompleted
        }
    }
}
