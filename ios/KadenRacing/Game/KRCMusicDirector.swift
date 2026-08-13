import AVFoundation
import Foundation

/// Background music director for menu / race / victory beds (CC0 bundled tracks).
@MainActor
final class KRCMusicDirector {
    static let shared = KRCMusicDirector()

    enum Track: String {
        case menu
        case garage
        case race
        case countdown
        case victory
    }

    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var current: Track?
    /// Last requested bed — kept across mute so volume unmute can resume.
    private var desired: Track?
    private var procedural: KRCProceduralMusic?
    private var raceQueue: [URL] = []
    private var raceIndex: Int = 0
    private let playerSink = AudioFinishSink()

    private init() {
        playerSink.onFinish = { [weak self] in
            Task { @MainActor in
                self?.advanceRacePlaylist()
            }
        }
    }

    func play(_ track: Track, crossfade: TimeInterval = 1.2) {
        desired = track
        guard current != track else {
            applyVolumeFromSettings()
            return
        }
        current = track
        let vol = KRCAudioPreferences.effectiveMusic
        guard vol > 0.01 else {
            // Keep `desired` so unmute can resume; clear active player only.
            fadeTimer?.invalidate()
            fadeTimer = nil
            procedural?.stop()
            procedural = nil
            player?.stop()
            player = nil
            current = nil
            return
        }
        activateSession()
        if track == .race {
            startRacePlaylist(volume: vol, crossfade: crossfade)
            return
        }
        raceQueue = []
        if let url = bundleURL(for: track) {
            playFile(url: url, volume: vol, crossfade: crossfade, loop: true)
        } else {
            // Prefer silence over whistling procedural beds when files are missing.
            stopImmediate()
            NSLog("[KRCMusicDirector] missing bundled track %@", track.rawValue)
        }
    }

    func setRaceIntensity(_ norm: Float) {
        procedural?.intensity = norm
        guard let player, current == .race else { return }
        let base = KRCAudioPreferences.effectiveMusic
        player.volume = base * (0.78 + min(1, max(0, norm)) * 0.22)
    }

    /// Call when Settings music volume / mute changes so the bed updates immediately.
    func applyVolumeFromSettings() {
        let vol = KRCAudioPreferences.effectiveMusic
        if vol <= 0.01 {
            player?.volume = 0
            procedural?.stop()
            return
        }
        if let player {
            if current == .race {
                player.volume = vol * 0.85
            } else {
                player.volume = vol
            }
        } else if let track = desired {
            // Was muted/stopped — restart the requested bed.
            current = nil
            play(track, crossfade: 0.35)
        }
    }

    func stop(fade: TimeInterval = 0.8) {
        fadeTimer?.invalidate()
        procedural?.stop()
        procedural = nil
        desired = nil
        raceQueue = []
        raceIndex = 0
        guard let p = player else {
            current = nil
            return
        }
        let steps = 12
        var step = 0
        let start = p.volume
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fade / Double(steps), repeats: true) { [weak self] t in
            step += 1
            p.volume = max(0, start * (1 - Float(step) / Float(steps)))
            if step >= steps {
                t.invalidate()
                p.stop()
                self?.player = nil
                self?.current = nil
            }
        }
    }

    private func stopImmediate() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        procedural?.stop()
        procedural = nil
        player?.stop()
        player = nil
        current = nil
        desired = nil
        raceQueue = []
        raceIndex = 0
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func bundleURL(for track: Track) -> URL? {
        let name: String
        let sub: String
        switch track {
        case .menu: name = "menu_theme"; sub = "Audio/Music/Menu"
        case .garage: name = "garage_theme"; sub = "Audio/Music/Menu"
        case .race: name = "race_intensity"; sub = "Audio/Music/Race"
        case .countdown: name = "countdown"; sub = "Audio/Music/Race"
        case .victory: name = "victory"; sub = "Audio/Music/Victory"
        }
        for ext in ["m4a", "mp3", "wav"] {
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: sub) { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Audio") { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext) { return u }
        }
        // Countdown can reuse race bed if a dedicated clip is absent.
        if track == .countdown {
            return bundleURL(for: .race)
        }
        return nil
    }

    private static let raceFileNames = [
        "race_intensity",
        "race_fever",
        "race_highway",
        "race_neon",
        "race_hot",
    ]

    private func startRacePlaylist(volume: Float, crossfade: TimeInterval) {
        var urls = Self.raceFileNames.compactMap { bundleURL(named: $0, subdirectory: "Audio/Music/Race") }
        if urls.isEmpty {
            urls = Self.raceFileNames.compactMap { bundleURL(named: $0, subdirectory: "Audio") }
        }
        if urls.isEmpty, let fallback = bundleURL(for: .race) {
            urls = [fallback]
        }
        urls.shuffle()
        raceQueue = urls
        raceIndex = 0
        guard let first = urls.first else {
            stopImmediate()
            NSLog("[KRCMusicDirector] missing bundled track race")
            return
        }
        playFile(url: first, volume: volume, crossfade: crossfade, loop: false)
    }

    private func advanceRacePlaylist() {
        guard desired == .race, !raceQueue.isEmpty else { return }
        raceIndex = (raceIndex + 1) % raceQueue.count
        let vol = KRCAudioPreferences.effectiveMusic
        guard vol > 0.01 else { return }
        playFile(url: raceQueue[raceIndex], volume: vol, crossfade: 0.7, loop: false)
        current = .race
    }

    private func bundleURL(named name: String, subdirectory: String) -> URL? {
        for ext in ["m4a", "mp3", "wav"] {
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory) { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Audio") { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext) { return u }
        }
        return nil
    }

    private func playFile(url: URL, volume: Float, crossfade: TimeInterval, loop: Bool) {
        procedural?.stop()
        procedural = nil
        guard let next = try? AVAudioPlayer(contentsOf: url) else { return }
        next.numberOfLoops = loop ? -1 : 0
        next.delegate = playerSink
        next.volume = 0
        next.prepareToPlay()
        let prev = player
        player = next
        next.play()
        fadeIn(to: volume, duration: crossfade)
        if let prev {
            fadeOut(player: prev, duration: crossfade) { prev.stop() }
        }
    }

    private func fadeIn(to target: Float, duration: TimeInterval) {
        fadeTimer?.invalidate()
        guard let p = player else { return }
        let steps = 16
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { t in
            step += 1
            p.volume = target * Float(step) / Float(steps)
            if step >= steps { t.invalidate() }
        }
    }

    private func fadeOut(player: AVAudioPlayer, duration: TimeInterval, done: @escaping () -> Void) {
        let start = player.volume
        let steps = 12
        var step = 0
        Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { t in
            step += 1
            player.volume = start * (1 - Float(step) / Float(steps))
            if step >= steps {
                t.invalidate()
                done()
            }
        }
    }
}

private final class AudioFinishSink: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }
        onFinish?()
    }
}
