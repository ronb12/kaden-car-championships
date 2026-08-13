import UIKit

/// Race sky / background from the same bundled photo as city-select cards.
enum CitySkyBackdrop {

    enum Kind: String {
        case sceneBackground
        case skyDome
    }

    private static var cache: [String: UIImage] = [:]

    /// Bump when crop/grade pipeline changes so stale in-memory skies don't stick.
    private static let cacheEpoch = "v10-original-clear"

    static func image(
        for city: CityRuntimeConfig,
        night: Bool,
        weather: EnvironmentLightingSystem.WeatherMode,
        kind: Kind = .sceneBackground
    ) -> UIImage? {
        guard city.themeId.hasPreviewCardPhoto else { return nil }
        let key = "\(cacheEpoch)-\(city.themeId.previewCardAssetName)-\(night)-\(weather.rawKey)-\(kind.rawValue)"
        if let hit = cache[key] { return hit }
        guard let source = UIImage(named: city.themeId.previewCardAssetName) else { return nil }
        let built = render(source: source, night: night, weather: weather, kind: kind)
        cache[key] = built
        return built
    }

    static func evictCache() {
        cache.removeAll()
    }

    // MARK: - Render

    private static func render(
        source: UIImage,
        night: Bool,
        weather: EnvironmentLightingSystem.WeatherMode,
        kind: Kind
    ) -> UIImage {
        let size: CGSize
        switch kind {
        case .skyDome: size = CGSize(width: 1024, height: 512)
        case .sceneBackground: size = CGSize(width: 1920, height: 1080)
        }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            drawPhoto(source, in: size, context: cg)
            drawHorizonFade(size: size, context: cg, strength: kind == .skyDome ? 0.55 : 0.42)
            applyWeatherOverlay(size: size, context: cg, night: night, weather: weather)
        }
    }

    /// Aspect-fill draw — never stretch; bias slightly upward for skyline.
    private static func drawPhoto(_ source: UIImage, in size: CGSize, context: CGContext) {
        let src = source.size
        guard src.width > 1, src.height > 1 else {
            source.draw(in: CGRect(origin: .zero, size: size))
            return
        }
        let scale = max(size.width / src.width, size.height / src.height)
        let w = src.width * scale
        let h = src.height * scale
        let x = (size.width - w) * 0.5
        let y = (size.height - h) * 0.35
        source.draw(in: CGRect(x: x, y: y, width: w, height: h))
    }

    private static func drawHorizonFade(size: CGSize, context: CGContext, strength: CGFloat) {
        let colors = [
            UIColor.clear.cgColor,
            UIColor(white: 0, alpha: 0.25 * strength).cgColor,
            UIColor(white: 0, alpha: 0.85 * strength).cgColor,
            UIColor(white: 0, alpha: 0.96).cgColor
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.42, 0.72, 1.0]
        guard let grad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else { return }
        context.drawLinearGradient(
            grad,
            start: CGPoint(x: size.width * 0.5, y: 0),
            end: CGPoint(x: size.width * 0.5, y: size.height),
            options: []
        )
    }

    private static func applyWeatherOverlay(
        size: CGSize,
        context: CGContext,
        night: Bool,
        weather: EnvironmentLightingSystem.WeatherMode
    ) {
        var overlay = UIColor.clear
        switch (night, weather) {
        case (true, _):
            overlay = UIColor(red: 0.04, green: 0.06, blue: 0.14, alpha: 0.48)
        case (false, .sunset):
            overlay = UIColor(red: 0.55, green: 0.28, blue: 0.08, alpha: 0.22)
        case (false, .night):
            overlay = UIColor(red: 0.05, green: 0.08, blue: 0.18, alpha: 0.4)
        default:
            overlay = UIColor(white: 1, alpha: 0.04)
        }
        context.setFillColor(overlay.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
    }
}

private extension EnvironmentLightingSystem.WeatherMode {
    var rawKey: String {
        switch self {
        case .day: return "day"
        case .sunset: return "sunset"
        case .night: return "night"
        }
    }
}
