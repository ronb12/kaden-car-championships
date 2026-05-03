import AVFoundation
import Foundation

/// Engine: **short loop** from the middle of `car_engine_racing.mp3` (steadier than looping the full clip)
/// + **discrete gear ratios** via `AVAudioUnitTimePitch` (rate), hysteresis, in-gear “revs”, shift dip.
/// Aux: wind / nitro / optional synth on the same engine graph.
final class RaceAudioController {

    private var audioEngine: AVAudioEngine?
    private var enginePlayerNode: AVAudioPlayerNode?
    private var engineTimePitch: AVAudioUnitTimePitch?
    private var engineLoopBuffer: AVAudioPCMBuffer?
    private var engineLoopFormat: AVAudioFormat?
    private var loopScheduled = false

    private var procSource: AVAudioSourceNode?
    private var auxSampleRate: Double = 44_100

    private var useSynthEngine: Bool = false

    private var tickTimer: Timer?
    private var isPrepared = false
    private var isStopped = true

    private var phaseWind: Double = 0
    private var phaseNitro: Double = 0
    private var phaseSynthEngine: Double = 0
    private var phaseScrub: Double = 0

    private var smoothEngineVol: Float = 0
    private var smoothEngineRate: Float = 1

    /// Discrete gears (0…5): hysteresis avoids flutter at boundaries.
    private var gearIndex: Int = 0
    private var lastGearForShiftFX: Int = 0
    private var shiftDip: Float = 1

    /// Upshift thresholds (speedNorm). Downshift uses same minus hysteresis.
    private let gearUpshift: [Float] = [0.17, 0.32, 0.47, 0.62, 0.78]
    private let gearHysteresis: Float = 0.055

    /// Target time-pitch rate center per gear (simulated ratio stack).
    private let gearRateCenter: [Float] = [0.68, 0.79, 0.90, 1.02, 1.14, 1.26]

    private final class Params: @unchecked Sendable {
        var speedNorm: Float = 0
        var gasActive: Bool = false
        var nitro: Bool = false
        var nitroTank: Float = 1
        var trackProgress: Float = 0
        var themeId: Int = 0
        var steerAbs: Float = 0
        let lock = NSLock()
    }

    private let params = Params()

    func prepare() {
        guard !isPrepared else { return }
        isPrepared = true
        isStopped = false
        DispatchQueue.main.async { [weak self] in
            self?.installAudioGraph()
        }
    }

    private func installAudioGraph() {
        guard !isStopped else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch { }

        let eng = AVAudioEngine()
        let main = eng.mainMixerNode
        main.outputVolume = 0.95

        // --- Load short steady loop from bundled MP3 (center of file) ---
        if let url = Bundle.main.url(forResource: "car_engine_racing", withExtension: "mp3") {
            if let (buf, fmt) = try? loadCenterLoopBuffer(url: url) {
                engineLoopBuffer = buf
                engineLoopFormat = fmt
                auxSampleRate = fmt.sampleRate

                let pn = AVAudioPlayerNode()
                let tp = AVAudioUnitTimePitch()
                tp.rate = 1
                tp.pitch = 0

                eng.attach(pn)
                eng.attach(tp)
                eng.connect(pn, to: tp, format: fmt)
                eng.connect(tp, to: main, format: fmt)

                enginePlayerNode = pn
                engineTimePitch = tp
                useSynthEngine = false
                loopScheduled = true
                scheduleEngineLoopRecursive()
                pn.play()
            } else {
                useSynthEngine = true
            }
        } else {
            useSynthEngine = true
        }

        attachProceduralAux(to: eng, mixer: main)

        do {
            try eng.start()
        } catch {
            useSynthEngine = true
            enginePlayerNode?.stop()
            enginePlayerNode = nil
            engineTimePitch = nil
            loopScheduled = false
        }

        audioEngine = eng
        startMainTick()
    }

    /// Pull ~1.12s from the middle of the file so the texture is more steady than looping the whole acceleration take.
    private func loadCenterLoopBuffer(url: URL) throws -> (AVAudioPCMBuffer, AVAudioFormat) {
        let file = try AVAudioFile(forReading: url)
        let fmt = file.processingFormat
        let total = file.length
        guard total > 4000 else {
            throw NSError(domain: "RaceAudio", code: 1)
        }

        let sr = fmt.sampleRate
        let desiredFrames = AVAudioFrameCount(min(Int(sr * 1.12), Int(Double(total) * 0.30)))
        let halfRemainder = AVAudioFramePosition(total) - AVAudioFramePosition(desiredFrames)
        let start = max(0, AVAudioFramePosition(total) / 2 - AVAudioFramePosition(desiredFrames) / 2)
        let safeStart = min(start, max(0, halfRemainder))

        file.framePosition = safeStart
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: desiredFrames) else {
            throw NSError(domain: "RaceAudio", code: 2)
        }
        let toRead = min(desiredFrames, AVAudioFrameCount(total - safeStart))
        try file.read(into: buf, frameCount: toRead)
        buf.frameLength = toRead
        return (buf, fmt)
    }

    private func scheduleEngineLoopRecursive() {
        guard loopScheduled,
              let pn = enginePlayerNode,
              let buf = engineLoopBuffer,
              !isStopped else { return }

        pn.scheduleBuffer(buf, at: nil, options: []) { [weak self] in
            guard let self, self.loopScheduled, !self.isStopped else { return }
            self.scheduleEngineLoopRecursive()
        }
    }

    private func attachProceduralAux(to eng: AVAudioEngine, mixer: AVAudioMixerNode) {
        guard procSource == nil else { return }

        let format = AVAudioFormat(
            standardFormatWithSampleRate: auxSampleRate,
            channels: 2
        )!

        let src = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buf = abl.first, let raw = buf.mData?.assumingMemoryBound(to: Float.self) else {
                return kAudio_ParamError
            }

            self.params.lock.lock()
            let speed = self.params.speedNorm
            let nitroOn = self.params.nitro && self.params.nitroTank > 0.05
            let t = Double(self.params.trackProgress)
            let tid = self.params.themeId
            let steer = self.params.steerAbs
            let synth = self.useSynthEngine
            self.params.lock.unlock()

            let pulse = 0.82 + 0.18 * sin(t * .pi * 2 * 7)
            let (baseHz, windAmt, bright): (Double, Double, Double) = {
                switch abs(tid) % 6 {
                case 0, 1: return (90, 0.22, 1.06)
                case 2: return (78, 0.32, 0.9)
                case 3: return (94, 0.38, 1.12)
                case 4: return (84, 0.16, 0.98)
                default: return (86, 0.26, 1.0)
                }
            }()

            let rpmHz = baseHz + Double(speed) * 155 * pulse
            let windHz = 180 + Double(speed) * 140
            let nitroHz: Double = 720

            let windGain = windAmt * (0.025 + Double(speed) * 0.14)
            let nitroGain = nitroOn ? 0.072 : 0
            let tireScrub = Double(steer) * Double(speed) * 0.038
            let synthGain = synth ? (0.065 + Double(speed) * 0.18) * pulse : 0

            let channels = Int(format.channelCount)
            let n = Int(frameCount)

            for frame in 0..<n {
                let wind = sin(self.phaseWind) * windGain
                let hiss = nitroOn ? sin(self.phaseNitro) * nitroGain : 0
                let synthTone = synth ? sin(self.phaseSynthEngine) * synthGain : 0
                let scrub = sin(self.phaseScrub) * tireScrub

                var m = wind + hiss + synthTone + scrub
                let mix = tanh(m * bright) * (synth ? 0.52 : 0.42)
                m = mix

                self.phaseWind += 2 * .pi * windHz / self.auxSampleRate
                self.phaseNitro += 2 * .pi * nitroHz / self.auxSampleRate
                self.phaseSynthEngine += 2 * .pi * rpmHz / self.auxSampleRate
                self.phaseScrub += 2 * .pi * (rpmHz * 2.1) / self.auxSampleRate
                if self.phaseWind > 1e6 { self.phaseWind = self.phaseWind.truncatingRemainder(dividingBy: 2 * .pi) }
                if self.phaseNitro > 1e6 { self.phaseNitro = self.phaseNitro.truncatingRemainder(dividingBy: 2 * .pi) }
                if self.phaseSynthEngine > 1e6 { self.phaseSynthEngine = self.phaseSynthEngine.truncatingRemainder(dividingBy: 2 * .pi) }
                if self.phaseScrub > 1e6 { self.phaseScrub = self.phaseScrub.truncatingRemainder(dividingBy: 2 * .pi) }

                let out = Float(m)
                for ch in 0..<channels {
                    raw[frame * channels + ch] = out
                }
            }

            return noErr
        }

        eng.attach(src)
        eng.connect(src, to: mixer, format: format)
        procSource = src
    }

    private func startMainTick() {
        guard tickTimer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.flushEngineFromParams()
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func updateGear(speed: Float) {
        let h = gearHysteresis
        if gearIndex < 5, speed >= gearUpshift[gearIndex] {
            gearIndex += 1
        } else if gearIndex > 0, speed < gearUpshift[gearIndex - 1] - h {
            gearIndex -= 1
        }
        gearIndex = max(0, min(5, gearIndex))
    }

    /// Rate within current gear + throttle (revs “under load”), stacked on gear center.
    private func targetRate(speed: Float, gas: Bool, nitroOn: Bool) -> Float {
        let g = min(max(gearIndex, 0), 5)
        let center = gearRateCenter[g]

        let lowBound: Float = g == 0 ? 0 : gearUpshift[g - 1] - gearHysteresis
        let highBound: Float = g >= 5 ? 1 : gearUpshift[g]
        let span = max(0.08, highBound - lowBound)
        let t = max(0, min(1, (speed - lowBound) / span))
        let revSweep: Float = (t * t) * 0.095
        let throttlePush: Float = gas ? 0.045 : 0
        var r = center + revSweep + throttlePush
        if nitroOn {
            r *= 1.055
        }
        return min(1.85, max(0.55, r))
    }

    private func flushEngineFromParams() {
        params.lock.lock()
        let speed = params.speedNorm
        let gas = params.gasActive
        let nitroOn = params.nitro && params.nitroTank > 0.05
        let t = params.trackProgress
        params.lock.unlock()

        updateGear(speed: speed)

        if gearIndex != lastGearForShiftFX {
            shiftDip = 0.74
            lastGearForShiftFX = gearIndex
        }
        shiftDip += (1 - shiftDip) * 0.11

        let pulse = 0.88 + 0.12 * sin(Double(t) * .pi * 2 * 7)
        let load = max(speed, gas ? 0.22 : 0)
        var targetVol = (0.12 + load * 0.74) * Float(pulse)
        if speed < 0.035 && !gas {
            targetVol *= 0.2
        }
        targetVol = min(1, max(0, targetVol))

        let tgtRate = targetRate(speed: speed, gas: gas, nitroOn: nitroOn)

        let volK: Float = shiftDip < 0.92 ? 0.22 : 0.14
        let rateK: Float = 0.2

        smoothEngineVol += (targetVol - smoothEngineVol) * volK
        smoothEngineRate += (tgtRate - smoothEngineRate) * rateK

        if useSynthEngine { return }

        engineTimePitch?.rate = smoothEngineRate
        enginePlayerNode?.volume = smoothEngineVol * shiftDip
        if let pn = enginePlayerNode, !pn.isPlaying {
            pn.play()
        }
    }

    func configure(cityThemeId: CityThemeID) {
        params.lock.lock()
        params.themeId = cityThemeId.rawValue
        params.lock.unlock()
    }

    func update(
        speedKmh: Int,
        gasActive: Bool,
        nitroActive: Bool,
        nitroTank: Float,
        trackProgress: Float,
        steerAbs: Float
    ) {
        let mx = 420
        let sn = min(1, max(0, Float(speedKmh) / Float(mx)))
        params.lock.lock()
        params.speedNorm = sn
        params.gasActive = gasActive
        params.nitro = nitroActive
        params.nitroTank = nitroTank
        params.trackProgress = trackProgress
        params.steerAbs = min(1, steerAbs)
        params.lock.unlock()
    }

    func stop() {
        isStopped = true
        loopScheduled = false
        isPrepared = false
        gearIndex = 0
        lastGearForShiftFX = 0
        shiftDip = 1

        DispatchQueue.main.async { [weak self] in
            self?.tickTimer?.invalidate()
            self?.tickTimer = nil
            self?.enginePlayerNode?.stop()
            self?.enginePlayerNode = nil
            self?.engineTimePitch = nil
            self?.engineLoopBuffer = nil
            self?.engineLoopFormat = nil
            self?.audioEngine?.stop()
            self?.audioEngine = nil
            self?.procSource = nil
            self?.smoothEngineVol = 0
            self?.smoothEngineRate = 1
        }
    }
}
