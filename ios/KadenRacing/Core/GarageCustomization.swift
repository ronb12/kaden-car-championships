import Foundation
import UIKit

/// Player vanity options that change the car on track and in garage preview.
enum GaragePaintSwatch: String, CaseIterable, Identifiable, Codable {
    case stock
    case arcticWhite
    case midnight
    case racingRed
    case electricBlue
    case hotPink
    case venomGreen
    case sunsetOrange
    case goldLeaf
    case graphite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stock: return "Stock"
        case .arcticWhite: return "Arctic"
        case .midnight: return "Midnight"
        case .racingRed: return "Racing Red"
        case .electricBlue: return "Volt Blue"
        case .hotPink: return "Hot Pink"
        case .venomGreen: return "Venom"
        case .sunsetOrange: return "Sunset"
        case .goldLeaf: return "Gold"
        case .graphite: return "Graphite"
        }
    }

    var color: UIColor? {
        switch self {
        case .stock: return nil
        case .arcticWhite: return UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1)
        case .midnight: return UIColor(red: 0.06, green: 0.07, blue: 0.1, alpha: 1)
        case .racingRed: return UIColor(red: 0.86, green: 0.08, blue: 0.12, alpha: 1)
        case .electricBlue: return UIColor(red: 0.05, green: 0.45, blue: 1.0, alpha: 1)
        case .hotPink: return UIColor(red: 1.0, green: 0.18, blue: 0.72, alpha: 1)
        case .venomGreen: return UIColor(red: 0.12, green: 0.92, blue: 0.28, alpha: 1)
        case .sunsetOrange: return UIColor(red: 1.0, green: 0.42, blue: 0.08, alpha: 1)
        case .goldLeaf: return UIColor(red: 0.92, green: 0.72, blue: 0.18, alpha: 1)
        case .graphite: return UIColor(red: 0.28, green: 0.3, blue: 0.34, alpha: 1)
        }
    }
}

enum GarageWrapStyle: String, CaseIterable, Identifiable, Codable {
    case none
    case racing
    case stealth
    case neon
    case carbon
    case flame
    case circuit
    case pink
    case camouflage

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Clean"
        case .racing: return "Racing"
        case .stealth: return "Stealth"
        case .neon: return "Neon"
        case .carbon: return "Carbon"
        case .flame: return "Flame"
        case .circuit: return "Circuit"
        case .pink: return "Pink"
        case .camouflage: return "Camo"
        }
    }

    /// Primary preview color for garage chips.
    var previewColor: UIColor {
        switch self {
        case .none: return UIColor(white: 0.55, alpha: 1)
        case .racing: return UIColor(red: 1, green: 0.86, blue: 0.12, alpha: 1)
        case .stealth: return UIColor(white: 0.42, alpha: 1)
        case .neon: return UIColor(red: 0.15, green: 1, blue: 0.82, alpha: 1)
        case .carbon: return UIColor(white: 0.18, alpha: 1)
        case .flame: return UIColor(red: 1, green: 0.35, blue: 0.05, alpha: 1)
        case .circuit: return UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
        case .pink: return UIColor(red: 1, green: 0.35, blue: 0.72, alpha: 1)
        case .camouflage: return UIColor(red: 0.32, green: 0.42, blue: 0.22, alpha: 1)
        }
    }

    var secondaryPreviewColor: UIColor? {
        switch self {
        case .none: return nil
        case .racing: return UIColor.white
        case .stealth: return UIColor(white: 0.7, alpha: 1)
        case .neon: return UIColor(red: 1, green: 0.2, blue: 0.85, alpha: 1)
        case .carbon: return UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
        case .flame: return UIColor(red: 1, green: 0.82, blue: 0.1, alpha: 1)
        case .circuit: return UIColor(white: 0.08, alpha: 1)
        case .pink: return UIColor(red: 1, green: 0.78, blue: 0.9, alpha: 1)
        case .camouflage: return UIColor(red: 0.55, green: 0.48, blue: 0.28, alpha: 1)
        }
    }

    var forceLivery: Bool { self != .none }

    /// True vinyl skin (full body), not just stripe accents.
    var isFullBodyWrap: Bool { self != .none }
}

enum GarageRimStyle: String, CaseIterable, Identifiable, Codable {
    case stock
    case sport5
    case deepDish
    case hyper
    case chromeLux
    case muscle
    case blackChrome
    case bronze
    case candyRed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stock: return "Stock"
        case .sport5: return "Sport 5"
        case .deepDish: return "Deep Dish"
        case .hyper: return "Hyper"
        case .chromeLux: return "Chrome"
        case .muscle: return "Gold"
        case .blackChrome: return "Blackout"
        case .bronze: return "Bronze"
        case .candyRed: return "Candy"
        }
    }

    var previewColor: UIColor {
        switch self {
        case .stock: return UIColor(white: 0.16, alpha: 1)
        case .sport5: return UIColor(red: 0.62, green: 0.65, blue: 0.7, alpha: 1)
        case .deepDish: return UIColor(white: 0.08, alpha: 1)
        case .hyper: return UIColor(red: 0.78, green: 0.82, blue: 0.88, alpha: 1)
        case .chromeLux: return UIColor(white: 0.88, alpha: 1)
        case .muscle: return UIColor(red: 0.82, green: 0.62, blue: 0.18, alpha: 1)
        case .blackChrome: return UIColor(white: 0.12, alpha: 1)
        case .bronze: return UIColor(red: 0.62, green: 0.42, blue: 0.22, alpha: 1)
        case .candyRed: return UIColor(red: 0.85, green: 0.08, blue: 0.14, alpha: 1)
        }
    }

    var wheelStyle: VehicleWheelStyle? {
        switch self {
        case .stock: return nil
        case .sport5, .blackChrome: return .sport5
        case .deepDish, .bronze: return .deepDish
        case .hyper, .candyRed: return .hyper
        case .chromeLux: return .chromeLux
        case .muscle: return .muscle
        }
    }
}

struct GarageCarStyle: Codable, Equatable {
    var paint: GaragePaintSwatch = .stock
    var wrap: GarageWrapStyle = .none
    var rim: GarageRimStyle = .stock

    static let stock = GarageCarStyle()
}

enum GarageCustomization {
    private static let key = "krc.garage.styles.v1"
    private static var cache: [String: GarageCarStyle] = load()

    static func style(for carId: String) -> GarageCarStyle {
        cache[carId] ?? .stock
    }

    static func setStyle(_ style: GarageCarStyle, for carId: String) {
        cache[carId] = style
        persist()
    }

    static func setPaint(_ paint: GaragePaintSwatch, for carId: String) {
        var s = style(for: carId)
        s.paint = paint
        setStyle(s, for: carId)
    }

    static func setWrap(_ wrap: GarageWrapStyle, for carId: String) {
        var s = style(for: carId)
        s.wrap = wrap
        setStyle(s, for: carId)
    }

    static func setRim(_ rim: GarageRimStyle, for carId: String) {
        var s = style(for: carId)
        s.rim = rim
        setStyle(s, for: carId)
    }

    static func bodyColor(for car: CarChoice) -> UIColor {
        style(for: car.id).paint.color ?? car.uiColor
    }

    private static func load() -> [String: GarageCarStyle] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: GarageCarStyle].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func persist() {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
