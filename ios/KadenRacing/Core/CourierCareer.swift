import Foundation
import UIKit

/// Courier ladder — lifetime deliveries unlock pay, cargo capacity, night license, and a van.
enum CourierCareer {
    struct Rank: Identifiable, Equatable {
        let id: Int
        let title: String
        let blurb: String
        let deliveriesRequired: Int
        let payoutMul: Float
        let cargoCapacity: Int
        let nightLicense: Bool
        let unlockCarId: String?
        let timeBonusSeconds: TimeInterval
    }

    static let ranks: [Rank] = [
        Rank(
            id: 0,
            title: "Rookie Runner",
            blurb: "Learn the beams. One package at a time.",
            deliveriesRequired: 0,
            payoutMul: 1.0,
            cargoCapacity: 1,
            nightLicense: false,
            unlockCarId: nil,
            timeBonusSeconds: 0
        ),
        Rank(
            id: 1,
            title: "Street Courier",
            blurb: "+10% pay · Night shifts unlocked.",
            deliveriesRequired: 8,
            payoutMul: 1.10,
            cargoCapacity: 1,
            nightLicense: true,
            unlockCarId: nil,
            timeBonusSeconds: 15
        ),
        Rank(
            id: 2,
            title: "Express Pro",
            blurb: "+20% pay · Carry 2 packages · +20s shift.",
            deliveriesRequired: 22,
            payoutMul: 1.20,
            cargoCapacity: 2,
            nightLicense: true,
            unlockCarId: nil,
            timeBonusSeconds: 20
        ),
        Rank(
            id: 3,
            title: "District Ace",
            blurb: "+32% pay · Unlock Executive RS van · +35s.",
            deliveriesRequired: 45,
            payoutMul: 1.32,
            cargoCapacity: 2,
            nightLicense: true,
            unlockCarId: "rs7",
            timeBonusSeconds: 35
        ),
        Rank(
            id: 4,
            title: "Night Legend",
            blurb: "+45% pay · Triple cargo · +50s.",
            deliveriesRequired: 80,
            payoutMul: 1.45,
            cargoCapacity: 3,
            nightLicense: true,
            unlockCarId: nil,
            timeBonusSeconds: 50
        ),
    ]

    static func rank(forDeliveries n: Int) -> Rank {
        var best = ranks[0]
        for r in ranks where n >= r.deliveriesRequired {
            best = r
        }
        return best
    }

    static func nextRank(afterDeliveries n: Int) -> Rank? {
        ranks.first { $0.deliveriesRequired > n }
    }
}

enum CourierPackageKind: String, CaseIterable, Identifiable, Equatable {
    case standard
    case fragile
    case rush
    case heavy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "STANDARD"
        case .fragile: return "FRAGILE"
        case .rush: return "RUSH"
        case .heavy: return "HEAVY"
        }
    }

    var blurb: String {
        switch self {
        case .standard: return "Solid pay · no tricks"
        case .fragile: return "No crashes · big tip"
        case .rush: return "Short timer · huge tip"
        case .heavy: return "Slows the car · fat purse"
        }
    }

    var payoutMul: Float {
        switch self {
        case .standard: return 1.0
        case .fragile: return 1.35
        case .rush: return 1.55
        case .heavy: return 1.4
        }
    }

    var speedMul: Float {
        switch self {
        case .heavy: return 0.86
        default: return 1.0
        }
    }

    var accentUIColor: UIColor {
        switch self {
        case .standard: return UIColor(red: 1.0, green: 0.52, blue: 0.08, alpha: 1)
        case .fragile: return UIColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 1)
        case .rush: return UIColor(red: 1.0, green: 0.25, blue: 0.35, alpha: 1)
        case .heavy: return UIColor(red: 0.75, green: 0.55, blue: 1.0, alpha: 1)
        }
    }
}

/// Customer-style shift rating (1–5★), like real courier apps.
enum CourierShiftGrade: Int, Equatable, Comparable {
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5

    var stars: Int { rawValue }

    var bonusMul: Float {
        switch self {
        case .five: return 1.35
        case .four: return 1.2
        case .three: return 1.08
        case .two: return 1.0
        case .one: return 0.9
        }
    }

    /// Compact strip value, e.g. "★★★★☆".
    var glyph: String {
        String(repeating: "★", count: stars) + String(repeating: "☆", count: 5 - stars)
    }

    /// Short label for medals / toasts.
    var shortLabel: String { "\(stars)★" }

    var blurb: String {
        switch self {
        case .five: return "LEGENDARY"
        case .four: return "EXCELLENT"
        case .three: return "SOLID"
        case .two: return "OKAY"
        case .one: return "ROUGH"
        }
    }

    var title: String { "\(glyph) · \(blurb)" }

    static func < (lhs: CourierShiftGrade, rhs: CourierShiftGrade) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func fromScore(_ score: Int) -> CourierShiftGrade {
        switch score {
        case 95...: return .five
        case 80..<95: return .four
        case 62..<80: return .three
        case 45..<62: return .two
        default: return .one
        }
    }
}
