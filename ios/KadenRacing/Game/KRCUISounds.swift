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

    private static var hornPlayer: AVAudioPlayer?
    private static var lastHorn: TimeInterval = 0

    /// Big cartoon horn — only if the kid equipped the rare horn toy.
    static func playHorn() {
        guard KidShowOffLoadout.live.toys.contains(.horn) else { return }
        guard KRCAudioPreferences.effectiveSFX > 0.05 else { return }
        let now = Date().timeIntervalSince1970
        guard now - lastHorn > 0.45 else { return }
        lastHorn = now
        if hornPlayer == nil {
            hornPlayer = try? AVAudioPlayer(data: hornWAV())
            hornPlayer?.prepareToPlay()
        }
        hornPlayer?.volume = KRCAudioPreferences.effectiveSFX * 0.85
        hornPlayer?.currentTime = 0
        hornPlayer?.play()
        if KRCAudioPreferences.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.8)
        }
    }

    private static func hornWAV() -> Data {
        let sampleRate = 22050
        let duration = 0.28
        let n = Int(Double(sampleRate) * duration)
        var data = Data()
        func appendU32(_ v: UInt32) {
            var le = v.littleEndian
            data.append(Data(bytes: &le, count: 4))
        }
        func appendU16(_ v: UInt16) {
            var le = v.littleEndian
            data.append(Data(bytes: &le, count: 2))
        }
        data.append(contentsOf: Array("RIFF".utf8))
        appendU32(UInt32(36 + n * 2))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        appendU32(16)
        appendU16(1)
        appendU16(1)
        appendU32(UInt32(sampleRate))
        appendU32(UInt32(sampleRate * 2))
        appendU16(2)
        appendU16(16)
        data.append(contentsOf: Array("data".utf8))
        appendU32(UInt32(n * 2))
        for i in 0..<n {
            let t = Double(i) / Double(sampleRate)
            let env = t < 0.04 ? t / 0.04 : max(0, 1 - (t - 0.04) / 0.24)
            let wave = sin(2 * .pi * 196 * t) * 0.55 + sin(2 * .pi * 247 * t) * 0.45
            let sample = Int16(max(-1, min(1, wave * env)) * 28000)
            var le = UInt16(bitPattern: sample).littleEndian
            data.append(Data(bytes: &le, count: 2))
        }
        return data
    }
}
