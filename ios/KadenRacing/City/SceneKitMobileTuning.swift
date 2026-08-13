import SceneKit
import UIKit

/// Central place for **mobile-first** SceneKit defaults (LOD hints, lighting budget).
enum SceneKitMobileTuning {

    static func apply(to view: SCNView) {
        let preset = EnvironmentGraphicsSettings.currentPreset
        view.antialiasingMode = preset.antialiasing
        view.preferredFramesPerSecond = 60
        view.autoenablesDefaultLighting = false
        view.scene?.lightingEnvironment.intensity = 1
        view.isTemporalAntialiasingEnabled = EnvironmentGraphicsSettings.quality != .low
        if #available(iOS 15.0, *) {
            view.contentScaleFactor = UIScreen.main.nativeScale
        }
    }
}
