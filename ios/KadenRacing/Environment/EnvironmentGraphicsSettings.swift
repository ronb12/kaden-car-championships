import SceneKit
import UIKit

/// Mobile graphics tiers — balances NFS/GT-style fidelity with 60 FPS target.
enum GraphicsQuality: String, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case ultra

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .ultra: return "Ultra"
        }
    }
}

enum EnvironmentGraphicsSettings {
    private static let key = "krc.graphicsQuality"

    static var quality: GraphicsQuality {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let q = GraphicsQuality(rawValue: raw) else { return recommendedDefault }
            return q
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    /// Prefer Medium on older / thermally constrained devices so themed worlds stay ≥30 FPS.
    static var recommendedDefault: GraphicsQuality {
        #if targetEnvironment(simulator)
        return .medium
        #else
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return .medium }
        // Physical memory is a coarse proxy for GPU class on iPhone.
        let gb = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
        if gb < 4.5 { return .medium }
        if gb < 6.5 { return .high }
        return .high
        #endif
    }

    struct Preset {
        let antialiasing: SCNAntialiasingMode
        let shadowSampleCount: Int
        let shadowRadius: CGFloat
        let decorStepDivisor: Int
        let bloomIntensity: CGFloat
        let motionBlur: CGFloat
        let fogNear: CGFloat
        let fogFar: CGFloat
        let oceanEnabled: Bool
        let mountainRingEnabled: Bool
        let streetLightStep: Int
        let maxDrawDistance: CGFloat
    }

    static func preset(for quality: GraphicsQuality) -> Preset {
        switch quality {
        case .low:
            return Preset(
                antialiasing: .multisampling2X,
                shadowSampleCount: 4,
                shadowRadius: 6,
                decorStepDivisor: 320,
                bloomIntensity: 0.55,
                motionBlur: 0.12,
                fogNear: 140,
                fogFar: 480,
                oceanEnabled: false,
                mountainRingEnabled: false,
                streetLightStep: 28,
                maxDrawDistance: 320
            )
        case .medium:
            return Preset(
                antialiasing: .multisampling4X,
                shadowSampleCount: 8,
                shadowRadius: 5,
                decorStepDivisor: 240,
                bloomIntensity: 0.72,
                motionBlur: 0.20,
                fogNear: 160,
                fogFar: 560,
                oceanEnabled: true,
                mountainRingEnabled: true,
                streetLightStep: 20,
                maxDrawDistance: 400
            )
        case .high:
            return Preset(
                antialiasing: .multisampling4X,
                shadowSampleCount: 16,
                shadowRadius: 4,
                decorStepDivisor: 180,
                bloomIntensity: 0.88,
                motionBlur: 0.32,
                fogNear: 180,
                fogFar: 680,
                oceanEnabled: true,
                mountainRingEnabled: true,
                streetLightStep: 14,
                maxDrawDistance: 480
            )
        case .ultra:
            return Preset(
                antialiasing: .multisampling4X,
                shadowSampleCount: 24,
                shadowRadius: 3,
                decorStepDivisor: 140,
                bloomIntensity: 1.05,
                motionBlur: 0.42,
                fogNear: 200,
                fogFar: 780,
                oceanEnabled: true,
                mountainRingEnabled: true,
                streetLightStep: 10,
                maxDrawDistance: 560
            )
        }
    }

    static var currentPreset: Preset { preset(for: quality) }
}
