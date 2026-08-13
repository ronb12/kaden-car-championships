import SwiftUI
import UIKit

struct CarChoice: Identifiable, Hashable {
    let id: String
    let name: String
    let uiColor: UIColor
    /// Index in `GameCatalog.cars` for garage image lookup.
    let garageIndex: Int

    var swiftUIColor: Color {
        Color(uiColor)
    }

    var colorUInt32: UInt32 {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (UInt32(r * 255) << 16) | (UInt32(g * 255) << 8) | UInt32(b * 255)
    }
}

/// Static catalog aligned with web `CARS` in `index.html` and `garage-cars/` assets.
enum GameCatalog {
    /// Every entry uses a unique body paint hex (no duplicates). Includes hot-pink Apex One.
    static let cars: [CarChoice] = [
        car("f40", "KRC VELOCE 40", 0xe10600, 0),           // rosso red
        car("lambo", "KRC BULLSTORM", 0xff8a00, 1),         // arancio
        car("gtr", "KRC NIGHT R35", 0x1e3a8a, 2),           // midnight indigo
        car("911", "KRC NINE-ONE", 0xffd100, 3),            // racing yellow
        car("mclaren", "KRC AERO 720", 0x9aa3ad, 4),        // titanium silver
        car("bugatti", "KRC ROYAL W16", 0x0f1f5c, 5),       // french navy
        car("amg", "KRC BLACKLINE GT", 0x101010, 6),        // matte black
        car("m4", "KRC M-STRIKE", 0x0077c8, 7),             // bmw blue
        car("rx7", "KRC ROTARY 7", 0x00b4d8, 8),            // rotary cyan
        car("supra", "KRC STREET KING", 0xff2a4a, 9),       // street crimson
        car("r34", "KRC SKY R34", 0x2a8f8f, 10),            // sky teal
        car("evo", "KRC RALLY EVO", 0xf0f2f5, 11),          // pearl white
        car("viper", "KRC VENOM V10", 0x6a0008, 12),        // venom maroon
        car("koenigsegg", "KRC APEX ONE", 0xff2db8, 13),    // hot pink
        car("mustang", "KRC STALLION GT", 0x003da5, 14),    // ford blue
        car("camaro", "KRC CAMBER SS", 0xffb400, 15),       // bumblebee amber
        car("challenger", "KRC OUTLAW WIDE", 0x7a2e0a, 16), // burnt brown
        car("corvette", "KRC STING ZR", 0x00a090, 17),      // daytona teal
        car("charger", "KRC PURSUIT RT", 0x3e4248, 18),     // charcoal
        car("nsx", "KRC NOVA X", 0xff5c00, 19),             // nova orange
        car("s2000", "KRC ROADSTER S2", 0x6ec1ff, 20),      // soft sky blue
        car("sti", "KRC RALLY X", 0x0a4db3, 21),            // rally blue
        car("civic", "KRC TYPE RUSH", 0x2480ff, 22),        // type-r blue
        car("audi-r8", "KRC V10 RUSH", 0xd4a017, 23),       // vegas gold
        car("rs7", "KRC EXECUTIVE RS", 0x6e747c, 24),       // nardo grey
        car("gt500", "KRC SUPER STALLION", 0x8b1c1c, 25),   // candy red
        car("r35-nismo", "KRC NIGHT R35-R", 0xc8102e, 26),  // nismo red
        car("huracan", "KRC HURRICANE EVO", 0x0090ff, 27),  // electric blue
        car("senna", "KRC AERO S", 0xff3a00, 28),           // papaya blaze
        car("police", "KRC INTERCEPTOR", 0x0c0e12, 29),     // black interceptor + white accents
        car("jesko", "KRC JETSTREAM", 0x00e5ff, 30),        // hyper cyan
        car("falcon-gt", "FALCON GT 1973", 0xcc5500, 0),    // copper orange
        car("camaro-1970", "CAMARO PRO 1970", 0x5a1fa8, 0), // deep purple
        car("firebird-1970", "FIREBIRD T/A 1970", 0x2e8b57, 0), // forest green
    ]

    private static func car(_ id: String, _ name: String, _ hex: UInt32, _ index: Int) -> CarChoice {
        CarChoice(id: id, name: name, uiColor: UIColor(rgb: hex), garageIndex: index)
    }

    /// Rear license plate text (player car vs garage / AI).
    static func plateLabel(carId: String, isPlayer: Bool) -> String {
        _ = carId
        if isPlayer { return KidShowOffLoadout.live.plate.shortText }
        return "KRC"
    }

    static func vehicleCategory(for carId: String) -> VehicleCategory {
        statProfiles.first { $0.id == carId }?.category ?? .sports
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        let r = CGFloat((rgb >> 16) & 0xff) / 255
        let g = CGFloat((rgb >> 8) & 0xff) / 255
        let b = CGFloat(rgb & 0xff) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
