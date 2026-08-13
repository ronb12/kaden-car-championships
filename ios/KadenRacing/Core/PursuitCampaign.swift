import Foundation

/// Hot Pursuit chapter ladder — escalating interceptor fantasy without new art.
struct PursuitChapter: Identifiable, Hashable {
    let id: String
    let title: String
    let blurb: String
    let trackIndex: Int
    let suspectCount: Int
    let timeLimitSeconds: TimeInterval
    let nightPreferred: Bool
    let roadblocks: Bool
    let rewardBonus: Int64
}

enum PursuitCampaign {
    static let chapters: [PursuitChapter] = [
        PursuitChapter(
            id: "p01-rookies",
            title: "Rookie Sweep",
            blurb: "Bust 3 street racers before the clock runs out.",
            trackIndex: 0,
            suspectCount: 3,
            timeLimitSeconds: 150,
            nightPreferred: false,
            roadblocks: false,
            rewardBonus: 200
        ),
        PursuitChapter(
            id: "p02-neon",
            title: "Neon Night Shift",
            blurb: "Night intercept — 4 suspects, tighter timer.",
            trackIndex: 1,
            suspectCount: 4,
            timeLimitSeconds: 165,
            nightPreferred: true,
            roadblocks: true,
            rewardBonus: 320
        ),
        PursuitChapter(
            id: "p03-highway",
            title: "Coastal Dragnet",
            blurb: "Full grid. Roadblocks active. No mercy.",
            trackIndex: 2,
            suspectCount: 5,
            timeLimitSeconds: 180,
            nightPreferred: true,
            roadblocks: true,
            rewardBonus: 450
        ),
        PursuitChapter(
            id: "p04-blackout",
            title: "Blackout Pursuit",
            blurb: "Elite runners. Short fuse. Lights blazing.",
            trackIndex: 4,
            suspectCount: 5,
            timeLimitSeconds: 150,
            nightPreferred: true,
            roadblocks: true,
            rewardBonus: 600
        ),
        PursuitChapter(
            id: "p05-finale",
            title: "City Lockdown",
            blurb: "Clear the pack. Own the interceptor crown.",
            trackIndex: 5,
            suspectCount: 6,
            timeLimitSeconds: 200,
            nightPreferred: true,
            roadblocks: true,
            rewardBonus: 850
        ),
    ]

    static func chapter(at index: Int) -> PursuitChapter {
        let i = min(max(index, 0), chapters.count - 1)
        return chapters[i]
    }
}
