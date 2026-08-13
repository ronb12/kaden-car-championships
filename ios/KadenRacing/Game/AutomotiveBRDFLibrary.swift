import SceneKit
import UIKit

/// Measured-style automotive BRDF parameters (Disney principled + clear-coat), loaded from bundled presets.
enum AutomotiveBRDFLibrary {

    struct MeasuredBRDF {
        var baseColor: UIColor
        var baseMetalness: Float
        var baseRoughness: Float
        var clearCoat: Float
        var clearCoatRoughness: Float
        var flakeDensity: Float
        var flakeMetalness: Float
        var specularTint: SIMD3<Float>
        var sheen: Float
        var pearlShift: Float
    }

    private struct PresetFile: Decodable {
        struct FinishFamily: Decodable {
            var baseMetalness: Float
            var baseRoughness: Float
            var clearCoat: Float
            var clearCoatRoughness: Float
            var flakeDensity: Float
            var flakeMetalness: Float
            var specularTint: [Float]
            var sheen: Float
            var pearlShift: Float?
        }

        struct CarOverride: Decodable {
            var factorySample: String?
            var flakeDensityMul: Float?
        }

        var finishFamilies: [String: FinishFamily]
        var carOverrides: [String: CarOverride]?
    }

    private static var cachedPresets: PresetFile?

    static func resolve(
        paint: VehicleMaterialLibrary.PaintDescriptor,
        carId: String?
    ) -> MeasuredBRDF {
        let family = loadFamily(for: paint.finish)
        var flake = family.flakeDensity * paint.flake
        if let carId, let override = loadPresets().carOverrides?[carId] {
            if let mul = override.flakeDensityMul { flake *= mul }
        }
        flake = min(1, max(0, flake))

        let coat = paint.finish == .matte ? 0 : min(1, family.clearCoat * max(0.35, paint.clearCoat))
        let tint = SIMD3<Float>(
            family.specularTint.count >= 3 ? family.specularTint[0] : 1,
            family.specularTint.count >= 2 ? family.specularTint[1] : 1,
            family.specularTint.count >= 1 ? family.specularTint[2] : 1
        )

        return MeasuredBRDF(
            baseColor: VehicleMaterialLibrary.calibratePaintColor(paint.color),
            baseMetalness: family.baseMetalness,
            baseRoughness: family.baseRoughness,
            clearCoat: coat,
            clearCoatRoughness: family.clearCoatRoughness,
            flakeDensity: flake,
            flakeMetalness: family.flakeMetalness,
            specularTint: tint,
            sheen: family.sheen,
            pearlShift: family.pearlShift ?? 0
        )
    }

    private static func loadFamily(for finish: VehiclePaintFinish) -> PresetFile.FinishFamily {
        let key: String = switch finish {
        case .gloss: "gloss"
        case .metallic: "metallic"
        case .pearl: "pearl"
        case .matte: "matte"
        }
        return loadPresets().finishFamilies[key] ?? loadPresets().finishFamilies["gloss"]!
    }

    private static func loadPresets() -> PresetFile {
        if let cachedPresets { return cachedPresets }
        let url = Bundle.main.url(forResource: "AutomotiveBRDFPresets", withExtension: "json")
            ?? Bundle.main.url(forResource: "AutomotiveBRDFPresets", withExtension: "json", subdirectory: "Resources")
        guard let url,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(PresetFile.self, from: data) else {
            let fallback = PresetFile(
                finishFamilies: [
                    "gloss": .init(
                        baseMetalness: 0.05, baseRoughness: 0.46, clearCoat: 0.96, clearCoatRoughness: 0.06,
                        flakeDensity: 0, flakeMetalness: 0, specularTint: [1, 1, 1], sheen: 0.02, pearlShift: nil
                    ),
                ],
                carOverrides: nil
            )
            cachedPresets = fallback
            return fallback
        }
        cachedPresets = decoded
        return decoded
    }
}
