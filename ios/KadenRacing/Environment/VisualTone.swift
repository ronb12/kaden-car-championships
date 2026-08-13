import UIKit

/// Global knobs to keep the race scene grounded and photographic rather than arcade-cartoon.
enum VisualTone {

    /// Desaturate a color toward gray while preserving luminance.
    static func mute(_ color: UIColor, amount: CGFloat = 0.28) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return color }
        return UIColor(hue: h, saturation: max(0, s * (1 - amount)), brightness: b * (1 - amount * 0.08), alpha: a)
    }
}
