import Foundation

/// Short engine rev sequence for the main-menu car drive-in (reuses race V8 samples).
@MainActor
final class MenuIntroAudioController {
    static let shared = MenuIntroAudioController()

    private let audio = RaceAudioController()
    private var revTimer: Timer?
    private var elapsed: TimeInterval = 0

    private init() {}

    /// Install AVAudioEngine early so menu rev is not silent on first drive-in.
    func warmUpAudio() {
        audio.prepare()
    }

    func playRevSequence() {
        revTimer?.invalidate()
        revTimer = nil
        elapsed = 0
        audio.prepare()
        audio.configure(cityThemeId: .libertyMetro)
        audio.beginMenuRev()
        // Prime first frame so engine is audible immediately after graph install.
        audio.update(
            forwardSpeedKmh: 8,
            speedNorm: 0.04,
            throttle: 1,
            brake: 0,
            gear: 1,
            nitroActive: false,
            nitroTank: 1,
            trackProgress: 0,
            steerAbs: 0,
            rpm: 0.45
        )

        revTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        if let revTimer {
            RunLoop.main.add(revTimer, forMode: .common)
        }
    }

    private func tick() {
        elapsed += 1.0 / 60.0

        let kmh: Int
        let gas: Bool

        if elapsed < 1.05 {
            let t = elapsed / 1.05
            kmh = Int(t * t * 110)
            gas = elapsed > 0.2
        } else if elapsed < 1.85 {
            let revT = elapsed - 1.05
            let wobble = sin(revT * 13.5) * 22
            kmh = Int(42 + wobble + revT * 38)
            gas = true
        } else if elapsed < 2.55 {
            let cool = elapsed - 1.85
            kmh = max(0, Int(58 - cool * 95))
            gas = cool < 0.22
        } else {
            stop()
            return
        }

        let peakKmh: Float = 115
        let norm = min(1, Float(kmh) / peakKmh)
        let rpm: Float = gas
            ? min(1, 0.38 + norm * 0.55 + (elapsed < 1.05 ? 0.12 : 0))
            : max(0.2, 0.55 - Float(elapsed - 1.85) * 0.4)
        audio.update(
            forwardSpeedKmh: Float(kmh),
            speedNorm: norm,
            throttle: gas ? 1 : 0,
            brake: 0,
            gear: 1,
            nitroActive: false,
            nitroTank: 1,
            trackProgress: Float(elapsed * 0.35),
            steerAbs: elapsed < 1.05 ? 0.12 : 0.04,
            rpm: rpm
        )
    }

    func stop() {
        revTimer?.invalidate()
        revTimer = nil
        elapsed = 0
        audio.stop()
    }
}
