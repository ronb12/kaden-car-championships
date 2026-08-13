import SceneKit
import UIKit

/// HDR bloom and light grading on the race camera — kept stable (no speed tunnel / color crush).
enum EnvironmentPostProcessing {

    static func configure(
        camera: SCNCamera,
        weather: EnvironmentLightingSystem.WeatherMode,
        quality: GraphicsQuality,
        speedRatio: Float = 0
    ) {
        _ = speedRatio
        let preset = EnvironmentGraphicsSettings.preset(for: quality)
        camera.wantsHDR = true
        // Exposure adaptation pulses on dark asphalt when the car is idle — reads as road glitching.
        camera.wantsExposureAdaptation = false
        camera.motionBlurIntensity = 0
        camera.vignettingIntensity = 0
        camera.vignettingPower = 1.0
        camera.colorFringeIntensity = 0
        camera.colorFringeStrength = 0

        if PalmCityEnvironment.isActive {
            camera.bloomIntensity = PalmCityEnvironment.isNight ? 0.35 : 0.22
            camera.bloomThreshold = PalmCityEnvironment.isNight ? 0.72 : 0.82
            camera.bloomBlurRadius = quality == .ultra ? 5.0 : 3.5
            camera.saturation = 1.0
            camera.contrast = PalmCityEnvironment.isNight ? 1.12 : 1.08
            return
        }

        switch weather {
        case .night:
            camera.bloomIntensity = preset.bloomIntensity * 0.4
            camera.bloomThreshold = 0.78
            camera.saturation = 1.0
            camera.contrast = 1.1
        case .sunset:
            camera.bloomIntensity = preset.bloomIntensity * 0.32
            camera.bloomThreshold = 0.86
            camera.saturation = 1.02
            camera.contrast = 1.08
        case .day:
            camera.bloomIntensity = preset.bloomIntensity * 0.22
            camera.bloomThreshold = 0.94
            camera.saturation = 1.0
            camera.contrast = 1.05
        }
        camera.bloomBlurRadius = quality == .ultra ? 5.0 : 3.0
    }

    static func applyBackground(
        to scene: SCNScene,
        city: CityRuntimeConfig,
        night: Bool,
        weather: EnvironmentLightingSystem.WeatherMode
    ) {
        if PalmCityEnvironment.isActive, let bg = PalmCityEnvironment.sceneBackground() {
            scene.background.contents = bg
            return
        }
        if let photo = CitySkyBackdrop.image(for: city, night: night, weather: weather, kind: .sceneBackground) {
            scene.background.contents = photo
            return
        }
        let sky = CityEnvironmentArt.skyGradient(for: city, night: night, weather: weather)
        scene.background.contents = KRCProceduralTextures.skyGradient(
            top: sky.top,
            bottom: sky.bottom,
            mid: sky.mid
        )
    }
}
