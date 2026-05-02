import SwiftUI
import UIKit

struct CarChoice: Identifiable, Hashable {
    let id: String
    let name: String
    let uiColor: UIColor

    var swiftUIColor: Color {
        Color(uiColor)
    }
}

/// Static catalog (native — no web assets).
enum GameCatalog {
    static let cars: [CarChoice] = [
        CarChoice(id: "f40", name: "FERRARI F40", uiColor: UIColor(red: 0.8, green: 0, blue: 0, alpha: 1)),
        CarChoice(id: "lambo", name: "LAMBORGHINI", uiColor: UIColor(red: 0.87, green: 0.53, blue: 0, alpha: 1)),
        CarChoice(id: "gtr", name: "NISSAN GT-R", uiColor: UIColor(red: 0.13, green: 0.27, blue: 0.53, alpha: 1)),
        CarChoice(id: "911", name: "PORSCHE 911", uiColor: UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1)),
        CarChoice(id: "mclaren", name: "McLAREN 720S", uiColor: UIColor(red: 1, green: 0.4, blue: 0, alpha: 1)),
        CarChoice(id: "bugatti", name: "BUGATTI CHIRON", uiColor: UIColor(red: 0.07, green: 0.07, blue: 0.15, alpha: 1))
    ]

    static let tracks: [(name: String, lapsDefault: Int)] = [
        ("Sunset City Circuit", 5),
        ("Harbor Express", 5),
        ("Mountain Pass GP", 3)
    ]
}
