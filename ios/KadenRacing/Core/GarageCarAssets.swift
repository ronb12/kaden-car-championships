import SwiftUI
import UIKit

/// Loads `garage-cars/*.png` from the app bundle (same files as the web game).
enum GarageCarAssets {
    /// Per-car top-down art (`car-00` … `car-30`) plus police override.
    static func imageName(for car: CarChoice) -> String {
        if car.id == "police" { return "car-police" }
        return String(format: "car-%02d", car.garageIndex)
    }

    static func uiImage(for car: CarChoice) -> UIImage? {
        let base = imageName(for: car)
        if let url = Bundle.main.url(forResource: base, withExtension: "png", subdirectory: "garage-cars"),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            return img
        }
        return UIImage(named: base)
    }
}

struct GarageCarImage: View {
    let car: CarChoice
    /// When set (or when garage paint exists), tint the PNG to match paint shop.
    var paintColor: UIColor? = nil

    private var tintColor: UIColor {
        paintColor ?? GarageCustomization.bodyColor(for: car)
    }

    var body: some View {
        ZStack {
            // Lifted studio floor — keeps dark paints readable on garage cards.
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.28),
                            Color(white: 0.14),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RadialGradient(
                colors: [Color(tintColor).opacity(0.28), .clear],
                center: .center,
                startRadius: 2,
                endRadius: 52
            )
            .blur(radius: 4)

            if let img = GarageCarAssets.uiImage(for: car) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .saturation(0.42)
                    .brightness(0.14)
                    .contrast(1.28)
                    .shadow(color: .white.opacity(0.22), radius: 1, y: -1)
                    .shadow(color: .black.opacity(0.45), radius: 5, y: 3)
                    .shadow(color: Color(tintColor).opacity(0.35), radius: 6, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(tintColor))
            }

            // Web parity: color blend (multiply was crushing dark cars to invisible).
            Color(tintColor)
                .opacity(0.5)
                .blendMode(.color)
        }
    }
}
