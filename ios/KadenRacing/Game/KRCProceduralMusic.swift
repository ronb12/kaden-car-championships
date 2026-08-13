import AVFoundation
import Foundation

/// Royalty-free procedural synthwave / EDM beds when no bundled music files exist.
final class KRCProceduralMusic {
    private var engine: AVAudioEngine?
    private var source: AVAudioSourceNode?
    var intensity: Float = 0.5
    private var mode: KRCMusicDirector.Track = .menu
    private var phase: Double = 0

    private func waveformSample(at t: Double) -> Float {
        switch mode {
        case .menu, .garage:
            let bass = sin(2 * .pi * 55 * t) * 0.12
            let pad = sin(2 * .pi * 220 * t) * 0.04 + sin(2 * .pi * 277 * t) * 0.03
            return Float(bass + pad)
        case .race:
            let bpm = 128.0 + Double(intensity) * 24
            let beat = sin(2 * .pi * t * bpm / 60) > 0.85 ? 0.14 : 0.0
            let arp = sin(2 * .pi * (440 + sin(t * 3) * 40) * t) * 0.06
            return Float(beat + arp) * (0.7 + intensity * 0.3)
        case .countdown:
            return Float(fmod(t, 1) < 0.08 ? 0.25 : 0)
        case .victory:
            return Float(sin(2 * .pi * 523 * t) * 0.1 + sin(2 * .pi * 659 * t) * 0.08)
        }
    }

    func start(mode: KRCMusicDirector.Track, volume: Float) {
        stop()
        self.mode = mode
        let eng = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let gain = KRCAudioPreferences.effectiveMusic * volume * 0.45
        let src = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, abl -> OSStatus in
            guard let self else { return noErr }
            let ptr = UnsafeMutableAudioBufferListPointer(abl)
            let n = Int(frameCount)
            let sr = 44_100.0
            for frame in 0..<n {
                self.phase += 1 / sr
                let v = self.waveformSample(at: self.phase) * gain
                for buf in ptr {
                    guard let data = buf.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    data[frame] = v
                }
            }
            return noErr
        }
        eng.attach(src)
        eng.connect(src, to: eng.mainMixerNode, format: format)
        eng.mainMixerNode.outputVolume = 1
        try? eng.start()
        engine = eng
        source = src
    }

    func stop() {
        engine?.stop()
        engine = nil
        source = nil
    }
}
