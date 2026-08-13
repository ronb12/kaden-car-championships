import AVFoundation
import UIKit

enum KRCUISounds {
    private static var clickPlayer: AVAudioPlayer?

    static func playClick() {
        guard KRCAudioPreferences.effectiveSFX > 0.05 else { return }
        if let url = Bundle.main.url(forResource: "ui_click", withExtension: "wav", subdirectory: "Audio/SFX/UI")
            ?? Bundle.main.url(forResource: "ui_click", withExtension: "wav") {
            if clickPlayer == nil || clickPlayer?.url != url {
                clickPlayer = try? AVAudioPlayer(contentsOf: url)
            }
            clickPlayer?.volume = KRCAudioPreferences.effectiveSFX * 0.6
            clickPlayer?.play()
            return
        }
        if KRCAudioPreferences.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.45)
        }
    }

    static func playImpact(strength: Float = 0.6) {
        guard KRCAudioPreferences.effectiveSFX > 0.05 else { return }
        if KRCAudioPreferences.hapticsEnabled {
            let style: UIImpactFeedbackGenerator.FeedbackStyle = strength > 0.5 ? .heavy : .medium
            UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: CGFloat(strength))
        }
    }
}
