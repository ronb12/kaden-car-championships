import Foundation
import UIKit

/// Stickers kids earn on every finish — slapped on the hood/door and the garage wall.
enum KidSticker: String, CaseIterable, Identifiable, Codable {
    case star
    case flame
    case cop
    case package
    case lightning
    case trophy
    case crystal
    case siren

    var id: String { rawValue }

    var title: String {
        switch self {
        case .star: return "Star"
        case .flame: return "Flame"
        case .cop: return "Badge"
        case .package: return "Package"
        case .lightning: return "Bolt"
        case .trophy: return "Trophy"
        case .crystal: return "Crystal"
        case .siren: return "Siren"
        }
    }

    var symbolName: String {
        switch self {
        case .star: return "star.fill"
        case .flame: return "flame.fill"
        case .cop: return "shield.fill"
        case .package: return "shippingbox.fill"
        case .lightning: return "bolt.fill"
        case .trophy: return "trophy.fill"
        case .crystal: return "diamond.fill"
        case .siren: return "antenna.radiowaves.left.and.right"
        }
    }

    var tint: UIColor {
        switch self {
        case .star: return UIColor(red: 1, green: 0.84, blue: 0.18, alpha: 1)
        case .flame: return UIColor(red: 1, green: 0.38, blue: 0.08, alpha: 1)
        case .cop: return UIColor(red: 0.18, green: 0.42, blue: 1, alpha: 1)
        case .package: return UIColor(red: 0.95, green: 0.62, blue: 0.18, alpha: 1)
        case .lightning: return UIColor(red: 0.35, green: 0.95, blue: 1, alpha: 1)
        case .trophy: return UIColor(red: 1, green: 0.78, blue: 0.12, alpha: 1)
        case .crystal: return UIColor(red: 0.55, green: 0.82, blue: 1, alpha: 1)
        case .siren: return UIColor(red: 1, green: 0.22, blue: 0.38, alpha: 1)
        }
    }

    static func forMode(_ mode: GameModeKind, place: Int) -> KidSticker {
        if place == 1 { return .trophy }
        switch mode {
        case .policeChase: return .cop
        case .courier: return .package
        case .timeTrial, .ghostDuel: return .lightning
        case .endless: return .crystal
        default: return place <= 3 ? .star : .flame
        }
    }

    func makeImage(size: CGFloat = 256) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        return renderer.image { _ in
            let rect = CGRect(x: size * 0.06, y: size * 0.06, width: size * 0.88, height: size * 0.88)
            let bubble = UIBezierPath(roundedRect: rect, cornerRadius: size * 0.22)
            UIColor.black.withAlphaComponent(0.55).setFill()
            bubble.fill()
            UIColor.white.withAlphaComponent(0.35).setStroke()
            bubble.lineWidth = size * 0.03
            bubble.stroke()
            let config = UIImage.SymbolConfiguration(pointSize: size * 0.42, weight: .black)
            let symbol = UIImage(systemName: symbolName, withConfiguration: config)?
                .withTintColor(tint, renderingMode: .alwaysOriginal)
            let symbolSize = symbol?.size ?? CGSize(width: size * 0.5, height: size * 0.5)
            let origin = CGPoint(
                x: (size - symbolSize.width) * 0.5,
                y: (size - symbolSize.height) * 0.48
            )
            symbol?.draw(in: CGRect(origin: origin, size: symbolSize))
        }
    }
}

/// One rare toy per mode — kids slap these on the car.
enum KidToy: String, CaseIterable, Identifiable, Codable {
    case lightBar
    case roofBox
    case flameTrail
    case horn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lightBar: return "Cop Lights"
        case .roofBox: return "Roof Box"
        case .flameTrail: return "Flame Trail"
        case .horn: return "Big Horn"
        }
    }

    var symbolName: String {
        switch self {
        case .lightBar: return "light.min"
        case .roofBox: return "shippingbox.fill"
        case .flameTrail: return "flame.fill"
        case .horn: return "speaker.wave.2.fill"
        }
    }

    var blurb: String {
        switch self {
        case .lightBar: return "Hot Pursuit rare"
        case .roofBox: return "Courier rare"
        case .flameTrail: return "Race rare"
        case .horn: return "Time trial rare"
        }
    }

    static func rareDrop(for mode: GameModeKind) -> KidToy {
        switch mode {
        case .policeChase: return .lightBar
        case .courier: return .roofBox
        case .timeTrial, .ghostDuel: return .horn
        default: return .flameTrail
        }
    }
}

enum KidPlate: String, CaseIterable, Identifiable, Codable {
    case krc
    case star
    case cop
    case box
    case hot
    case ace
    case kid
    case win

    var id: String { rawValue }

    var title: String { shortText }

    var shortText: String {
        switch self {
        case .krc: return "KRC"
        case .star: return "STAR"
        case .cop: return "COP"
        case .box: return "BOX"
        case .hot: return "HOT"
        case .ace: return "ACE"
        case .kid: return "KID"
        case .win: return "WIN"
        }
    }

    static func drop(for mode: GameModeKind, place: Int) -> KidPlate {
        if place == 1 { return .win }
        switch mode {
        case .policeChase: return .cop
        case .courier: return .box
        case .timeTrial, .ghostDuel: return .ace
        case .endless: return .hot
        default: return place <= 3 ? .star : .kid
        }
    }
}

enum KidHat: String, CaseIterable, Identifiable, Codable {
    case racing
    case cop
    case courier
    case champ

    var id: String { rawValue }

    var title: String {
        switch self {
        case .racing: return "Racing Cap"
        case .cop: return "Cop Cap"
        case .courier: return "Courier Cap"
        case .champ: return "Champ Crown"
        }
    }

    var symbolName: String {
        switch self {
        case .racing: return "person.crop.circle.fill"
        case .cop: return "shield.fill"
        case .courier: return "shippingbox.fill"
        case .champ: return "star.circle.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .racing: return UIColor(red: 0.86, green: 0.12, blue: 0.16, alpha: 1)
        case .cop: return UIColor(red: 0.12, green: 0.22, blue: 0.48, alpha: 1)
        case .courier: return UIColor(red: 0.42, green: 0.28, blue: 0.14, alpha: 1)
        case .champ: return UIColor(red: 0.92, green: 0.74, blue: 0.16, alpha: 1)
        }
    }

    static func drop(for mode: GameModeKind, place: Int) -> KidHat {
        if place == 1 { return .champ }
        switch mode {
        case .policeChase: return .cop
        case .courier: return .courier
        default: return .racing
        }
    }
}

struct KidShowOffLoadout: Equatable {
    var hoodSticker: KidSticker?
    var doorSticker: KidSticker?
    var toys: Set<KidToy>
    var plate: KidPlate
    var hat: KidHat?
    var ownedStickers: [KidSticker]
    var stickerCounts: [KidSticker: Int]

    static let starter = KidShowOffLoadout(
        hoodSticker: nil,
        doorSticker: nil,
        toys: [],
        plate: .krc,
        hat: nil,
        ownedStickers: [],
        stickerCounts: [:]
    )

    /// Snapshot read by the 3D car / garage wall.
    static var live = KidShowOffLoadout.starter

    var appearanceKey: String {
        let toysKey = toys.map(\.rawValue).sorted().joined(separator: ".")
        let stick = ownedStickers.map(\.rawValue).joined(separator: ".")
        return "\(hoodSticker?.rawValue ?? "-")-\(doorSticker?.rawValue ?? "-")-\(toysKey)-\(plate.rawValue)-\(hat?.rawValue ?? "-")-\(stick)"
    }
}

struct KidPrizeTeaser: Equatable {
    var line: String
    var carName: String?
    var racesLeft: Int
}

struct KidLootDrop: Equatable {
    var sticker: KidSticker
    var paint: GaragePaintSwatch?
    var wrap: GarageWrapStyle?
    var toy: KidToy?
    var plate: KidPlate?
    var hat: KidHat?
    var crystals: Int
    var trophy: Bool
    var bonusCredits: Int64
    var headline: String
}

/// Kid retention helpers — next-car prize, Play routing, post-race loot.
enum KidPlayLoop {
    static let starterPaints: [GaragePaintSwatch] = [.stock, .racingRed, .electricBlue, .hotPink]
    static let starterWraps: [GarageWrapStyle] = [.none]
    static let starterPlates: [KidPlate] = [.krc]

    static func nextPrize(progress: PlayerProgressStore) -> KidPrizeTeaser {
        if !progress.careerComplete {
            let start = progress.careerTierCompleted
            for i in start..<CareerMissions.all.count {
                let mission = CareerMissions.mission(atTier: i)
                guard let carId = mission.unlockCarId,
                      !progress.unlockedCarIds.contains(carId),
                      let car = GameCatalog.cars.first(where: { $0.id == carId })
                else { continue }
                let left = i - start + 1
                if left == 1 {
                    return KidPrizeTeaser(line: "Win this race → \(car.name)", carName: car.name, racesLeft: 1)
                }
                return KidPrizeTeaser(
                    line: "\(left) more races → \(car.name)",
                    carName: car.name,
                    racesLeft: left
                )
            }
            if let mission = progress.currentCareerMission {
                let left = CareerMissions.all.count - start
                return KidPrizeTeaser(
                    line: "\(mission.title) · \(left) left",
                    carName: nil,
                    racesLeft: max(1, left)
                )
            }
        }

        let locked = GameCatalog.cars.filter { !progress.unlockedCarIds.contains($0.id) }
        if let next = locked.first {
            return KidPrizeTeaser(line: "Earn credits → \(next.name)", carName: next.name, racesLeft: 0)
        }
        return KidPrizeTeaser(line: "Paint your car — then one more race", carName: nil, racesLeft: 0)
    }

    static func rollLoot(
        progress: PlayerProgressStore,
        mode: GameModeKind,
        place: Int,
        crystals: Int
    ) -> KidLootDrop {
        let sticker = KidSticker.forMode(mode, place: place)
        var paint: GaragePaintSwatch?
        var wrap: GarageWrapStyle?
        var toy: KidToy?
        var plate: KidPlate?
        var hat: KidHat?
        var bonus: Int64 = 0

        let rare = KidToy.rareDrop(for: mode)
        let won = place == 1
        if !progress.ownsToy(rare), won || Float.random(in: 0...1) < 0.22 {
            toy = rare
        }

        let plateDrop = KidPlate.drop(for: mode, place: place)
        if toy == nil, !progress.ownsPlate(plateDrop), won || Float.random(in: 0...1) < 0.28 {
            plate = plateDrop
        }

        let hatDrop = KidHat.drop(for: mode, place: place)
        if toy == nil, plate == nil, !progress.ownsHat(hatDrop), won || Float.random(in: 0...1) < 0.22 {
            hat = hatDrop
        }

        let lockedPaints = GaragePaintSwatch.allCases.filter { !progress.ownsPaint($0) }
        let lockedWraps = GarageWrapStyle.allCases.filter { $0 != .none && !progress.ownsWrap($0) }

        if toy == nil, plate == nil, hat == nil {
            if place <= 3, let next = lockedWraps.first {
                wrap = next
            } else if let next = lockedPaints.first {
                paint = next
            } else if let next = lockedWraps.first {
                wrap = next
            } else {
                bonus = place == 1 ? 120 : 60
            }
        }

        var headline = "New sticker: \(sticker.title)"
        if let toy {
            headline = "RARE TOY: \(toy.title)"
        } else if let hat {
            headline = "New hat: \(hat.title)"
        } else if let plate {
            headline = "New plate: \(plate.shortText)"
        } else if let wrap {
            headline = "New wrap: \(wrap.label)"
        } else if let paint, paint != .stock {
            headline = "New paint: \(paint.label)"
        } else if bonus > 0 {
            headline = "Bonus +\(bonus) CR"
        }

        return KidLootDrop(
            sticker: sticker,
            paint: paint,
            wrap: wrap,
            toy: toy,
            plate: plate,
            hat: hat,
            crystals: max(0, crystals),
            trophy: won,
            bonusCredits: bonus,
            headline: headline
        )
    }

    static func houseGhostLine(delta: TimeInterval?, hadGhost: Bool) -> String? {
        guard hadGhost, let delta else {
            return hadGhost ? nil : "House ghost saved — beat it next race"
        }
        if delta < -0.05 {
            return String(format: "You beat the house ghost by %.1fs", -delta)
        }
        if delta > 0.05 {
            return String(format: "Ghost still ahead by %.1fs — try again", delta)
        }
        return "Dead heat with the house ghost"
    }
}
