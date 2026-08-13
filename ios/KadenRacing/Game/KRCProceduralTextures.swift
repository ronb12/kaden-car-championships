import UIKit

/// Cached procedural bitmaps for asphalt, grass, and road markings (PBR-friendly).
enum KRCProceduralTextures {

    private static var cache: [String: UIImage] = [:]

    static func asphalt(tint: UIColor, night: Bool) -> UIImage {
        let key = "asphalt-v6-black-\(tint.hexKey)-\(night ? 1 : 0)"
        if let img = cache[key] { return img }
        let w = 512, h = 512
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let img = renderer.image { ctx in
            var r: CGFloat = 0.11, g: CGFloat = 0.11, b: CGFloat = 0.12, a: CGFloat = 1
            tint.getRed(&r, green: &g, blue: &b, alpha: &a)
            // True black asphalt base with subtle grain on top.
            let baseR: CGFloat = night ? 0.008 : 0.012
            let baseG: CGFloat = night ? 0.008 : 0.012
            let baseB: CGFloat = night ? 0.010 : 0.014
            let mix: CGFloat = 0.008
            let br = baseR * (1 - mix) + r * mix
            let bg = baseG * (1 - mix) + g * mix
            let bb = baseB * (1 - mix) + b * mix
            UIColor(red: br, green: bg, blue: bb, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            // Subtle lane-wear bands (rubber staining)
            for band in 0..<5 {
                let y = CGFloat(band) * CGFloat(h) / 5 + CGFloat.random(in: -8...8)
                UIColor(red: 14 / 255, green: 14 / 255, blue: 16 / 255, alpha: night ? 0.08 : 0.06).setFill()
                ctx.fill(CGRect(x: 0, y: y, width: CGFloat(w), height: CGFloat.random(in: 18...32)))
            }
            // Aggregate speckle (very dark grains — keeps road black at distance)
            for _ in 0..<1200 {
                let px = CGFloat.random(in: 0...CGFloat(w))
                let py = CGFloat.random(in: 0...CGFloat(h))
                let v = CGFloat.random(in: 3...7) / 255
                UIColor(
                    red: v,
                    green: v,
                    blue: min(1, v + 1 / 255),
                    alpha: CGFloat.random(in: 0.04...0.12)
                ).setFill()
                ctx.fill(CGRect(x: px, y: py, width: CGFloat.random(in: 0.8...2.2), height: CGFloat.random(in: 0.8...2.2)))
            }
            // Oil / patch wear (darker patches)
            for _ in 0..<18 {
                let cx = CGFloat.random(in: 0...CGFloat(w))
                let cy = CGFloat.random(in: 0...CGFloat(h))
                let rad = CGFloat.random(in: 12...48)
                UIColor(red: 12 / 255, green: 14 / 255, blue: 16 / 255, alpha: CGFloat.random(in: 0.06...0.12)).setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: cx - rad, y: cy - rad * 0.6, width: rad * 2, height: rad * 1.2))
            }
            // Seam lines (very subtle, not bright white)
            for _ in 0..<16 {
                let y = CGFloat.random(in: 0...CGFloat(h))
                UIColor(white: night ? 0.12 : 0.18, alpha: 0.12).setStroke()
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: CGFloat(w), y: y + CGFloat.random(in: -10...10)))
                path.lineWidth = CGFloat.random(in: 0.6...1.8)
                path.stroke()
            }
        }
        cache[key] = img
        return img
    }

    static func runoffGravel(tint: UIColor, night: Bool) -> UIImage {
        let key = "gravel-\(tint.hexKey)-\(night ? 1 : 0)"
        if let img = cache[key] { return img }
        let w = 128, h = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let img = renderer.image { ctx in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            tint.getRed(&r, green: &g, blue: &b, alpha: &a)
            let base = UIColor(red: r * 0.85, green: g * 0.82, blue: b * 0.78, alpha: 1)
            base.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            for _ in 0..<420 {
                let px = CGFloat.random(in: 0...CGFloat(w))
                let py = CGFloat.random(in: 0...CGFloat(h))
                let grain = CGFloat.random(in: -0.06...0.06)
                UIColor(
                    red: min(1, max(0, r + grain)),
                    green: min(1, max(0, g + grain)),
                    blue: min(1, max(0, b + grain)),
                    alpha: CGFloat.random(in: 0.35...0.75)
                )
                    .setFill()
                ctx.fill(CGRect(x: px, y: py, width: CGFloat.random(in: 1...3), height: CGFloat.random(in: 1...3)))
            }
        }
        cache[key] = img
        return img
    }

    static func barrierStripe(night: Bool) -> UIImage {
        let key = "barrier-\(night ? 1 : 0)"
        if let img = cache[key] { return img }
        let w = 64, h = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let img = renderer.image { ctx in
            let stripe = 8
            for row in 0..<stripe {
                for col in 0..<stripe {
                    let red = (row + col) % 2 == 0
                    (red ? UIColor(red: 0.72, green: 0.14, blue: 0.10, alpha: 1) : UIColor(white: night ? 0.82 : 0.90, alpha: 1)).setFill()
                    ctx.fill(CGRect(x: col * w / stripe, y: row * h / stripe, width: w / stripe, height: h / stripe))
                }
            }
        }
        cache[key] = img
        return img
    }

    /// Concrete jersey barrier with yellow/black chevrons (Palm City highway).
    static func jerseyBarrierChevron(night: Bool) -> UIImage {
        let key = "jersey-\(night ? 1 : 0)"
        if let img = cache[key] { return img }
        let w = 128, h = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let img = renderer.image { ctx in
            UIColor(white: night ? 0.22 : 0.32, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let chevronH = CGFloat(h) * 0.55
            for i in 0..<6 {
                let x = CGFloat(i) * (CGFloat(w) / 5.5)
                let yellow = i % 2 == 0
                let c = yellow
                    ? UIColor(red: 0.92, green: 0.78, blue: 0.12, alpha: 1)
                    : UIColor(white: 0.08, alpha: 1)
                c.setFill()
                let path = UIBezierPath()
                path.move(to: CGPoint(x: x, y: CGFloat(h) - chevronH))
                path.addLine(to: CGPoint(x: x + CGFloat(w) / 10, y: CGFloat(h)))
                path.addLine(to: CGPoint(x: x + CGFloat(w) / 5, y: CGFloat(h)))
                path.addLine(to: CGPoint(x: x + CGFloat(w) / 7, y: CGFloat(h) - chevronH))
                path.close()
                path.fill()
            }
        }
        cache[key] = img
        return img
    }

    static func highwaySignPanel(route: String, destination: String, night: Bool) -> UIImage {
        let key = "hwy-\(route)-\(destination)-\(night ? 1 : 0)"
        if let img = cache[key] { return img }
        let w = 256, h = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let img = renderer.image { _ in
            UIColor(red: 0.08, green: 0.38, blue: 0.16, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 4, y: 4, width: w - 8, height: h - 8), cornerRadius: 6).fill()
            UIColor(white: 0.95, alpha: 1).setStroke()
            let border = UIBezierPath(roundedRect: CGRect(x: 6, y: 6, width: w - 12, height: h - 12), cornerRadius: 4)
            border.lineWidth = 2
            border.stroke()
            let routeFont = UIFont.boldSystemFont(ofSize: 22)
            let destFont = UIFont.boldSystemFont(ofSize: 28)
            let routeAttrs: [NSAttributedString.Key: Any] = [.font: routeFont, .foregroundColor: UIColor.white]
            let destAttrs: [NSAttributedString.Key: Any] = [.font: destFont, .foregroundColor: UIColor.white]
            (route as NSString).draw(at: CGPoint(x: 14, y: 12), withAttributes: routeAttrs)
            (destination as NSString).draw(at: CGPoint(x: 14, y: 52), withAttributes: destAttrs)
        }
        cache[key] = img
        return img
    }

    static func neonRacewaySign() -> UIImage {
        let key = "neon-palm-city"
        if let img = cache[key] { return img }
        let w = 512, h = 256
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let img = renderer.image { ctx in
            ctx.cgContext.setShadow(offset: .zero, blur: 18, color: UIColor(red: 1, green: 0.2, blue: 0.55, alpha: 0.9).cgColor)
            let pink = UIColor(red: 1, green: 0.25, blue: 0.62, alpha: 1)
            pink.setStroke()
            let frame = UIBezierPath(roundedRect: CGRect(x: 8, y: 8, width: w - 16, height: h - 16), cornerRadius: 10)
            frame.lineWidth = 5
            frame.stroke()
            let titleFont = UIFont.boldSystemFont(ofSize: 36)
            let subFont = UIFont.boldSystemFont(ofSize: 52)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: pink,
                .strokeColor: UIColor(red: 1, green: 0.6, blue: 0.78, alpha: 1),
                .strokeWidth: -2
            ]
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: subFont,
                .foregroundColor: UIColor(red: 1, green: 0.45, blue: 0.72, alpha: 1),
                .strokeColor: UIColor.white,
                .strokeWidth: -1.5
            ]
            ("PALM CITY" as NSString).draw(at: CGPoint(x: 28, y: 36), withAttributes: titleAttrs)
            ("RACEWAY" as NSString).draw(at: CGPoint(x: 28, y: 88), withAttributes: subAttrs)
            // Neon palm accents
            pink.withAlphaComponent(0.85).setFill()
            for px: CGFloat in [380, 420, 460] {
                ctx.cgContext.fillEllipse(in: CGRect(x: px, y: 40, width: 18, height: 18))
                ctx.fill(CGRect(x: px + 7, y: 56, width: 4, height: 70))
            }
        }
        cache[key] = img
        return img
    }

    static func grass(tint: UIColor, night: Bool) -> UIImage {
        let key = "grass-\(tint.hexKey)-\(night ? 1 : 0)"
        if let img = cache[key] { return img }
        let w = 128, h = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let img = renderer.image { ctx in
            tint.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            for _ in 0..<900 {
                let px = CGFloat.random(in: 0...CGFloat(w))
                let py = CGFloat.random(in: 0...CGFloat(h))
                UIColor(
                    white: CGFloat.random(in: night ? 0.05...0.18 : 0.12...0.28),
                    alpha: CGFloat.random(in: 0.2...0.5)
                ).setFill()
                ctx.fill(CGRect(x: px, y: py, width: 1, height: CGFloat.random(in: 2...5)))
            }
        }
        cache[key] = img
        return img
    }

    static func skyGradient(top: UIColor, bottom: UIColor, mid: UIColor? = nil) -> UIImage {
        let midKey = mid?.hexKey ?? "none"
        let key = "sky-v2-\(top.hexKey)-\(midKey)-\(bottom.hexKey)"
        if let img = cache[key] { return img }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 256))
        let img = renderer.image { ctx in
            if let mid {
                let colors = [top.cgColor, mid.cgColor, bottom.cgColor] as CFArray
                let grad = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: [0, 0.42, 1]
                )!
                ctx.cgContext.drawLinearGradient(
                    grad,
                    start: .zero,
                    end: CGPoint(x: 0, y: 256),
                    options: []
                )
            } else {
                let colors = [top.cgColor, bottom.cgColor] as CFArray
                let grad = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: [0, 1]
                )!
                ctx.cgContext.drawLinearGradient(
                    grad,
                    start: .zero,
                    end: CGPoint(x: 0, y: 256),
                    options: []
                )
            }
        }
        cache[key] = img
        return img
    }

    // MARK: - Automotive paint (GT-style metallic flake micro-detail)

    /// Spatial metalness variation — aluminum flake in the base coat (metallic / pearl).
    static func automotiveFlakeMetalness(intensity: Float, baseMetal: CGFloat) -> UIImage {
        // Keep base metalness low so pigment color stays visible; flakes are bright sparks only.
        let cappedBase = min(baseMetal, 0.16)
        let key = "flake-metal-v3-\(Int(intensity * 100))-\(Int(cappedBase * 100))"
        if let img = cache[key] { return img }
        let w = 256, h = 256
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let img = renderer.image { ctx in
            let base = cappedBase
            UIColor(white: base, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let count = Int(120 + intensity * 320)
            for _ in 0..<count {
                let px = CGFloat.random(in: 0...CGFloat(w))
                let py = CGFloat.random(in: 0...CGFloat(h))
                let spark = CGFloat.random(in: 0.42...0.62)
                UIColor(white: spark, alpha: CGFloat.random(in: 0.18...0.55)).setFill()
                let s = CGFloat.random(in: 0.6...2.4)
                ctx.fill(CGRect(x: px, y: py, width: s, height: s))
            }
        }
        cache[key] = img
        return img
    }

    /// Micro-roughness breakup so flake sparkles under moving specular (Disney PBR).
    static func automotiveFlakeRoughness(intensity: Float, baseRough: CGFloat) -> UIImage {
        let key = "flake-rough-\(Int(intensity * 100))-\(Int(baseRough * 100))"
        if let img = cache[key] { return img }
        let w = 256, h = 256
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let img = renderer.image { ctx in
            let base = CGFloat(baseRough)
            UIColor(white: base, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let count = Int(120 + intensity * 380)
            for _ in 0..<count {
                let px = CGFloat.random(in: 0...CGFloat(w))
                let py = CGFloat.random(in: 0...CGFloat(h))
                let v = CGFloat.random(in: max(0.04, base - 0.22)...min(0.92, base + 0.08))
                UIColor(white: v, alpha: CGFloat.random(in: 0.25...0.7)).setFill()
                let s = CGFloat.random(in: 0.8...2.8)
                ctx.fill(CGRect(x: px, y: py, width: s, height: s))
            }
        }
        cache[key] = img
        return img
    }

    /// Subtle normal perturbation for flake glitter at glancing angles.
    static func automotiveFlakeNormal(intensity: Float) -> UIImage {
        let key = "flake-norm-\(Int(intensity * 100))"
        if let img = cache[key] { return img }
        let w = 128, h = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let img = renderer.image { ctx in
            UIColor(red: 0.5, green: 0.5, blue: 1, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let count = Int(80 + intensity * 220)
            for _ in 0..<count {
                let px = Int.random(in: 0..<w)
                let py = Int.random(in: 0..<h)
                let nx = CGFloat.random(in: 0.42...0.58)
                let ny = CGFloat.random(in: 0.42...0.58)
                UIColor(red: nx, green: ny, blue: 0.92, alpha: 1).setFill()
                ctx.fill(CGRect(x: px, y: py, width: 2, height: 2))
            }
        }
        cache[key] = img
        return img
    }

    /// Unique card backdrop per catalog index (50 circuits — not 6 recycled palettes).
    static func trackCardGradient(seed: Int) -> [UIColor] {
        let profile = EnvironmentTrackProfile.from(catalogTrackIndex: seed)
        let idx = abs(seed)
        let hueBase = profile.trackCardHueBase
        let hue = CGFloat(fmod(Double(hueBase) + Double(idx) * 0.6180339887 * 0.11, 1.0))
        let satTop = 0.48 + CGFloat((idx * 7) % 11) * 0.018
        let briTop = 0.62 + CGFloat((idx * 5) % 9) * 0.022
        let top = UIColor(hue: hue, saturation: min(0.78, satTop), brightness: min(0.88, briTop), alpha: 1)
        let bottom = UIColor(
            hue: CGFloat(fmod(Double(hue) + 0.06, 1.0)),
            saturation: min(0.85, satTop + 0.12),
            brightness: 0.14 + CGFloat((idx * 3) % 7) * 0.018,
            alpha: 1
        )
        let mid = UIColor(
            hue: CGFloat(fmod(Double(hue) + 0.03, 1.0)),
            saturation: satTop * 0.9,
            brightness: (briTop * 0.45 + 0.12),
            alpha: 1
        )
        return [top, mid, bottom]
    }
}

private extension UIColor {
    var hexKey: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
