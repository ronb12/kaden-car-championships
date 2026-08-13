import AVFoundation
import Foundation

/// Arcade race engine audio tuned like Asphalt / NFS / Real Racing style loops:
/// one solid V8 cruise bed + mild rate climb + EQ body — no scream/high layer, no TimePitch detune.
final class RaceAudioController {

    private var audioEngine: AVAudioEngine?
    private var engineLowPlayer: AVAudioPlayerNode?
    private var engineHighPlayer: AVAudioPlayerNode?
    private var engineLowPitch: AVAudioUnitTimePitch?
    private var engineHighPitch: AVAudioUnitTimePitch?
    private var engineEQ: AVAudioUnitEQ?
    private var engineLowBuffer: AVAudioPCMBuffer?
    private var engineHighBuffer: AVAudioPCMBuffer?
    private var engineLoopFormat: AVAudioFormat?
    private var lowLoopScheduled = false
    private var highLoopScheduled = false

    private var procSource: AVAudioSourceNode?
    private var auxMixer: AVAudioMixerNode?
    private var auxSampleRate: Double = 44_100

    private var useSynthEngine: Bool = false
    private var samplesEngineActive: Bool = false

    private var tickTimer: Timer?
    private var isPrepared = false
    private var isStopped = true
    private var suspended = false

    var needsPrepare: Bool { !isPrepared || audioEngine == nil }

    private var phaseWind: Double = 0
    private var phaseNitro: Double = 0
    private var phaseSynthEngine: Double = 0
    private var phaseTire: Double = 0

    private var smoothEngineVol: Float = 0
    private var smoothBodyVol: Float = 0
    private var smoothEngineRate: Float = 1
    /// Race uses engine only for a short intro, then music carries the bed (Asphalt/NFS style).
    private var raceIntroActive = false
    private var raceIntroElapsed: Float = 0
    private var raceIntroGain: Float = 1
    /// Full engine for menu rev / diagnostics; race fades after intro.
    private var keepEngineThroughout = false

    private var lastGearForShiftFX: Int = 1
    private var shiftDip: Float = 1
    private var lastSpeedNorm: Float = 0
    private var lastThrottle: Float = 0
    private var nitroWhoosh: Float = 0
    private var passByWhoosh: Float = 0

    /// Hold engine under music longer so races keep a V8 character.
    private let raceIntroHoldSeconds: Float = 8.0
    private let raceIntroFadeSeconds: Float = 4.0
    /// Residual under music so the world never feels mute.
    private let raceEngineFloor: Float = 0.28

    private let gearUpshift: [Float] = [0.17, 0.32, 0.47, 0.62, 0.78]
    private let gearHysteresis: Float = 0.055
    private var gearIndex: Int = 0

    private struct EngineProfile {
        var rumbleMul: Float = 1
        var bodyMul: Float = 1
        /// Tiny rate bias only (never large pitch cents — those made a motorcycle whine).
        var rateMul: Float = 1
        var rateOffset: Float = 0
    }

    /// Presence without clipping; sit under music but still read as a muscle V8.
    private let engineSampleGain: Float = 1.12
    private let rumbleCap: Float = 0.88
    private let bodyCap: Float = 0.48

    private final class Params: @unchecked Sendable {
        var speedNorm: Float = 0
        var throttle: Float = 0
        var brake: Float = 0
        var gear: Int = 1
        var nitro: Bool = false
        var nitroTank: Float = 1
        var trackProgress: Float = 0
        var themeId: Int = 0
        var steerAbs: Float = 0
        var rpm: Float = 0.35
        var vehicleCategory: VehicleCategory = .sports
        var passBy: Float = 0
        let lock = NSLock()
    }

    private let params = Params()

    func prepare() {
        guard !isPrepared || audioEngine == nil else { return }
        isPrepared = true
        isStopped = false
        suspended = false
        runOnMain { [weak self] in
            self?.installAudioGraph()
        }
    }

    /// Call when a race session starts — engine audible briefly, then fades under music.
    func beginRaceIntro() {
        raceIntroActive = true
        keepEngineThroughout = false
        raceIntroElapsed = 0
        raceIntroGain = 1
        resume()
    }

    /// Menu drive-in / short rev — keep engine for the whole sequence.
    func beginMenuRev() {
        raceIntroActive = false
        keepEngineThroughout = true
        raceIntroGain = 1
        resume()
    }

    func suspend() {
        suspended = true
        runOnMain { [weak self] in
            self?.engineLowPlayer?.volume = 0
            self?.engineHighPlayer?.volume = 0
        }
    }

    func resume() {
        suspended = false
        runOnMain { [weak self] in
            self?.activateAudioSession()
            self?.flushEngineFromParams()
        }
    }

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch { }
    }

    private func makeCarBodyEQ() -> AVAudioUnitEQ {
        // Arcade car body: warm low end, tame harsh highs (bike-whine band).
        let eq = AVAudioUnitEQ(numberOfBands: 4)
        eq.globalGain = 0

        let low = eq.bands[0]
        low.filterType = .lowShelf
        low.frequency = 110
        low.gain = 5.5
        low.bypass = false

        let mid = eq.bands[1]
        mid.filterType = .parametric
        mid.frequency = 420
        mid.bandwidth = 0.9
        mid.gain = 2.0
        mid.bypass = false

        let bite = eq.bands[2]
        bite.filterType = .parametric
        bite.frequency = 1_600
        bite.bandwidth = 1.1
        bite.gain = -2.5
        bite.bypass = false

        let air = eq.bands[3]
        air.filterType = .highShelf
        air.frequency = 3_200
        air.gain = -9.0
        air.bypass = false

        return eq
    }

    private func installAudioGraph() {
        guard !isStopped else { return }
        guard audioEngine == nil else { return }

        activateAudioSession()

        let eng = AVAudioEngine()
        let main = eng.mainMixerNode
        applyMasterVolume(to: main)

        // Prefer AC Cobra V8 cruise loop (real car) + richer stereo body from full engine clip.
        // Never attach muscle_v8_high — that trim is the motorcycle scream.
        let rumbleURL = Bundle.main.url(forResource: "muscle_v8_loop", withExtension: "mp3")
        let bodyURL = Bundle.main.url(forResource: "car_engine_racing", withExtension: "mp3")

        if let rumbleURL,
           let (rumbleBuf, rumbleFmt) = try? loadEntireLoopBuffer(url: rumbleURL) {
            engineLowBuffer = rumbleBuf
            engineLoopFormat = rumbleFmt
            auxSampleRate = rumbleFmt.sampleRate

            let rumblePn = AVAudioPlayerNode()
            let rumbleTp = AVAudioUnitTimePitch()
            rumbleTp.rate = 1
            rumbleTp.pitch = 0
            rumbleTp.overlap = 8

            let eq = makeCarBodyEQ()
            let engineMix = AVAudioMixerNode()
            engineMix.outputVolume = 1

            eng.attach(rumblePn)
            eng.attach(rumbleTp)
            eng.attach(eq)
            eng.attach(engineMix)
            eng.connect(rumblePn, to: rumbleTp, format: rumbleFmt)
            eng.connect(rumbleTp, to: engineMix, format: rumbleFmt)

            engineLowPlayer = rumblePn
            engineLowPitch = rumbleTp
            engineEQ = eq
            useSynthEngine = false
            samplesEngineActive = true
            lowLoopScheduled = true
            scheduleLowLoopRecursive()

            // Optional stereo body layer (full natural clip — not the scream trim).
            if let bodyURL,
               let (bodyBuf, bodyFmt) = try? loadSeamlessLoopBuffer(url: bodyURL) {
                let bodyPn = AVAudioPlayerNode()
                let bodyTp = AVAudioUnitTimePitch()
                bodyTp.rate = 1
                bodyTp.pitch = 0
                bodyTp.overlap = 8

                eng.attach(bodyPn)
                eng.attach(bodyTp)
                eng.connect(bodyPn, to: bodyTp, format: bodyFmt)
                eng.connect(bodyTp, to: engineMix, format: bodyFmt)

                engineHighBuffer = bodyBuf
                engineHighPlayer = bodyPn
                engineHighPitch = bodyTp
                highLoopScheduled = true
                scheduleHighLoopRecursive()
            } else {
                engineHighPlayer = nil
                engineHighPitch = nil
                highLoopScheduled = false
            }

            eng.connect(engineMix, to: eq, format: nil)
            eng.connect(eq, to: main, format: nil)
        } else if let bodyURL,
                  let (bodyBuf, bodyFmt) = try? loadSeamlessLoopBuffer(url: bodyURL) {
            engineLowBuffer = bodyBuf
            engineLoopFormat = bodyFmt
            auxSampleRate = bodyFmt.sampleRate

            let pn = AVAudioPlayerNode()
            let tp = AVAudioUnitTimePitch()
            tp.rate = 1
            tp.pitch = 0
            tp.overlap = 8
            let eq = makeCarBodyEQ()

            eng.attach(pn)
            eng.attach(tp)
            eng.attach(eq)
            eng.connect(pn, to: tp, format: bodyFmt)
            eng.connect(tp, to: eq, format: bodyFmt)
            eng.connect(eq, to: main, format: bodyFmt)

            engineLowPlayer = pn
            engineLowPitch = tp
            engineEQ = eq
            useSynthEngine = false
            samplesEngineActive = true
            lowLoopScheduled = true
            scheduleLowLoopRecursive()
        } else {
            useSynthEngine = true
            samplesEngineActive = false
        }

        // Wind / nitro only — never sine "engine" over samples (that reads as a bike).
        attachProceduralAux(to: eng, mixer: main)

        do {
            try eng.start()
        } catch {
            useSynthEngine = true
            engineLowPlayer?.stop()
            engineHighPlayer?.stop()
            engineLowPlayer = nil
            engineHighPlayer = nil
            engineLowPitch = nil
            engineHighPitch = nil
            engineEQ = nil
            lowLoopScheduled = false
            highLoopScheduled = false
        }

        audioEngine = eng

        if samplesEngineActive {
            engineLowPlayer?.play()
            engineHighPlayer?.play()
        }

        startMainTick()
    }

    private func loadEntireLoopBuffer(url: URL) throws -> (AVAudioPCMBuffer, AVAudioFormat) {
        let file = try AVAudioFile(forReading: url)
        let fmt = file.processingFormat
        let total = file.length
        guard total > 0 else {
            throw NSError(domain: "RaceAudio", code: 1)
        }
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(total)) else {
            throw NSError(domain: "RaceAudio", code: 2)
        }
        try file.read(into: buf)
        buf.frameLength = AVAudioFrameCount(total)
        return (buf, fmt)
    }

    /// Use most of the clip as a loop (better than a tiny center slice).
    private func loadSeamlessLoopBuffer(url: URL) throws -> (AVAudioPCMBuffer, AVAudioFormat) {
        let file = try AVAudioFile(forReading: url)
        let fmt = file.processingFormat
        let total = file.length
        guard total > 8_000 else {
            throw NSError(domain: "RaceAudio", code: 1)
        }

        // Skip a short attack, keep a long stable body for looping.
        let sr = fmt.sampleRate
        let skip = AVAudioFramePosition(min(Int(sr * 0.35), Int(Double(total) * 0.12)))
        let usable = total - skip
        let frames = AVAudioFrameCount(max(Int(sr * 2.2), Int(Double(usable) * 0.72)))
        let safeFrames = min(frames, AVAudioFrameCount(usable))

        file.framePosition = skip
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: safeFrames) else {
            throw NSError(domain: "RaceAudio", code: 2)
        }
        try file.read(into: buf, frameCount: safeFrames)
        buf.frameLength = safeFrames
        return (buf, fmt)
    }

    private func scheduleLowLoopRecursive() {
        guard lowLoopScheduled,
              let pn = engineLowPlayer,
              let buf = engineLowBuffer,
              !isStopped else { return }

        pn.scheduleBuffer(buf, at: nil, options: []) { [weak self] in
            guard let self, self.lowLoopScheduled, !self.isStopped else { return }
            self.scheduleLowLoopRecursive()
        }
    }

    private func scheduleHighLoopRecursive() {
        guard highLoopScheduled,
              let pn = engineHighPlayer,
              let buf = engineHighBuffer,
              !isStopped else { return }

        pn.scheduleBuffer(buf, at: nil, options: []) { [weak self] in
            guard let self, self.highLoopScheduled, !self.isStopped else { return }
            self.scheduleHighLoopRecursive()
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
            let rpm = self.params.rpm
            let gas = self.params.throttle > 0.05
            let nitroOn = self.params.nitro && self.params.nitroTank > 0.05
            let steer = Double(self.params.steerAbs)
            let synth = self.useSynthEngine
            let whoosh = Double(self.nitroWhoosh)
            let passBy = Double(max(self.passByWhoosh, self.params.passBy))
            self.params.lock.unlock()

            let drive = max(speed, rpm * 0.5)
            let samplesActive = !synth

            let windHz = 24 + Double(drive) * 42
            let nitroHz: Double = 88
            let tireHz = 90 + Double(drive) * 70 + steer * 40
            let passHz = 150 + passBy * 140
            let windGain = (!samplesActive || speed > 0.22)
                ? (samplesActive ? 0.007 : 0.018) * (0.25 + Double(drive) * 1.15)
                : 0
            let tireGain = steer > 0.08
                ? (samplesActive ? 0.01 : 0.028) * steer * (0.35 + Double(speed))
                : 0
            let nitroGain = (nitroOn || whoosh > 0.02)
                ? (samplesActive ? 0.012 : 0.04) * max(whoosh, nitroOn ? 1 : 0)
                : 0
            let passGain = passBy > 0.06 ? (samplesActive ? 0.02 : 0.045) * passBy : 0
            let synthGain = synth ? (0.08 + Double(drive) * 0.22 + (gas ? 0.06 : 0)) : 0
            let synthHz = 48 + Double(drive) * 40 + (gas ? 8 : 0)

            let channels = Int(format.channelCount)
            let n = Int(frameCount)

            for frame in 0..<n {
                let wind = sin(self.phaseWind) * windGain
                    + sin(self.phaseWind * 0.51) * windGain * 0.3
                let tire = tireGain > 0
                    ? (sin(self.phaseTire) * 0.55 + sin(self.phaseTire * 2.37) * 0.35) * tireGain
                    : 0
                let hiss = nitroGain > 0
                    ? sin(self.phaseNitro) * nitroGain * 0.7
                    : 0
                let pass = passGain > 0
                    ? sin(self.phaseWind * 1.65) * passGain * 0.55
                        + sin(2 * .pi * passHz * Double(frame) / self.auxSampleRate) * passGain * 0.45
                    : 0
                let synthTone = synth ? sin(self.phaseSynthEngine) * synthGain : 0
                let m = tanh((wind + tire + hiss + pass + synthTone) * 0.9) * (synth ? 0.45 : 0.14)

                self.phaseWind += 2 * .pi * windHz / self.auxSampleRate
                self.phaseTire += 2 * .pi * tireHz / self.auxSampleRate
                self.phaseNitro += 2 * .pi * nitroHz / self.auxSampleRate
                self.phaseSynthEngine += 2 * .pi * synthHz / self.auxSampleRate
                if self.phaseWind > 1e6 { self.phaseWind = self.phaseWind.truncatingRemainder(dividingBy: 2 * .pi) }
                if self.phaseTire > 1e6 { self.phaseTire = self.phaseTire.truncatingRemainder(dividingBy: 2 * .pi) }
                if self.phaseNitro > 1e6 { self.phaseNitro = self.phaseNitro.truncatingRemainder(dividingBy: 2 * .pi) }
                if self.phaseSynthEngine > 1e6 {
                    self.phaseSynthEngine = self.phaseSynthEngine.truncatingRemainder(dividingBy: 2 * .pi)
                }

                let out = Float(m)
                for ch in 0..<channels {
                    raw[frame * channels + ch] = out
                }
            }

            return noErr
        }

        let aux = AVAudioMixerNode()
        eng.attach(aux)
        eng.attach(src)
        eng.connect(src, to: aux, format: format)
        eng.connect(aux, to: mixer, format: format)
        aux.outputVolume = 0.22
        procSource = src
        auxMixer = aux
    }

    private func startMainTick() {
        guard tickTimer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.flushEngineFromParams()
        }
        RunLoop.main.add(t, forMode: .common)
        tickTimer = t
    }

    private func engineProfile(for category: VehicleCategory) -> EngineProfile {
        switch category {
        case .muscle, .policeInterceptor:
            return EngineProfile(rumbleMul: 1.15, bodyMul: 0.85, rateMul: 1.0, rateOffset: -0.02)
        case .hypercar, .supercar:
            return EngineProfile(rumbleMul: 0.95, bodyMul: 1.05, rateMul: 1.02, rateOffset: 0.01)
        case .compact:
            return EngineProfile(rumbleMul: 0.9, bodyMul: 0.9, rateMul: 1.03, rateOffset: 0.02)
        case .sports:
            return EngineProfile(rumbleMul: 1.05, bodyMul: 1.0, rateMul: 1.0, rateOffset: 0)
        }
    }

    private func updateGear(drive: Float) {
        let h = gearHysteresis
        if gearIndex < 5, drive >= gearUpshift[gearIndex] {
            gearIndex += 1
        } else if gearIndex > 0, drive < gearUpshift[gearIndex - 1] - h {
            gearIndex -= 1
        }
        gearIndex = max(0, min(5, gearIndex))
    }

    /// Asphalt/NFS-style: modest rate climb only. Pitch stays 0 to avoid chipmunk/bike artifacts.
    private func targetRate(
        speed: Float,
        rpm: Float,
        gas: Bool,
        nitroOn: Bool,
        profile: EngineProfile
    ) -> Float {
        // Idle ~0.92, cruise ~1.0, WOT ~1.10 — feels like a car, not a reving bike.
        let load = min(1, max(speed, rpm * 0.55))
        var r: Float = 0.92 + load * 0.14 + (gas ? 0.03 : 0) + max(0, rpm - 0.45) * 0.04
        if nitroOn { r += 0.03 }
        // Soft per-gear dip without big pitch jumps.
        let gearPull = Float(gearIndex) * 0.008
        r = (r - gearPull) * profile.rateMul + profile.rateOffset
        return min(1.12, max(0.88, r))
    }

    private func flushEngineFromParams() {
        params.lock.lock()
        let sn = params.speedNorm
        let throttle = params.throttle
        let brake = params.brake
        let gear = params.gear
        let nitroOn = params.nitro && params.nitroTank > 0.05
        let rpm = params.rpm
        let category = params.vehicleCategory
        params.lock.unlock()

        let profile = engineProfile(for: category)
        let gas = throttle > 0.05
        let drive = min(1, max(sn, rpm * 0.45))

        if gear != lastGearForShiftFX, gear > 0 {
            shiftDip = 0.88
            lastGearForShiftFX = gear
        }
        shiftDip += (1 - shiftDip) * 0.16

        if useSynthEngine {
            updateGear(drive: drive)
            flushSynthEngine(drive: drive, gas: gas, rpm: rpm)
            lastSpeedNorm = sn
            return
        }

        let sfx = KRCAudioPreferences.effectiveSFX
        if suspended || sfx <= 0.001 {
            engineLowPlayer?.volume = 0
            engineHighPlayer?.volume = 0
            lastSpeedNorm = sn
            return
        }

        lastSpeedNorm = sn
        updateGear(drive: drive)

        if nitroOn {
            nitroWhoosh = min(1, nitroWhoosh + 0.1)
        } else {
            nitroWhoosh *= 0.9
        }
        lastThrottle = throttle

        // Race intro: full engine for a few seconds, then fade so music owns the bed.
        if raceIntroActive && !keepEngineThroughout {
            raceIntroElapsed += 1.0 / 60.0
            if raceIntroElapsed <= raceIntroHoldSeconds {
                raceIntroGain = 1
            } else {
                let t = (raceIntroElapsed - raceIntroHoldSeconds) / max(0.01, raceIntroFadeSeconds)
                raceIntroGain = max(raceEngineFloor, 1 - min(1, t))
            }
        } else if keepEngineThroughout {
            raceIntroGain = 1
        }

        let rate = targetRate(speed: sn, rpm: rpm, gas: gas, nitroOn: nitroOn, profile: profile)

        // Constant-ish power: rumble always present; body layer grows with road speed.
        let load = max(sn, gas ? 0.16 : 0, rpm * 0.25)
        var rumbleVol = (0.20 + load * 0.48 + (gas ? 0.06 : 0)) * profile.rumbleMul
        let bodyMix = min(1, max(0, (sn - 0.05) / 0.55))
        var bodyVol = bodyMix * (0.12 + load * 0.28) * (gas ? 1.05 : 0.9) * profile.bodyMul

        if !gas && sn < 0.02 {
            rumbleVol = 0.14
            bodyVol = 0.02
        }
        if brake > 0.4 {
            rumbleVol *= 0.9
            bodyVol *= 0.8
        }
        if nitroOn {
            rumbleVol = min(rumbleCap, rumbleVol * 1.05)
            bodyVol = min(bodyCap, bodyVol * 1.08)
        }

        rumbleVol *= raceIntroGain
        bodyVol *= raceIntroGain

        let risingRate = rate > smoothEngineRate
        let risingVol = rumbleVol > smoothEngineVol
        let rateK: Float = shiftDip < 0.94 ? 0.28 : (risingRate ? 0.32 : 0.18)
        let volK: Float = risingVol ? 0.34 : 0.18

        smoothEngineVol += (rumbleVol - smoothEngineVol) * volK
        smoothBodyVol += (bodyVol - smoothBodyVol) * volK
        smoothEngineRate += (rate - smoothEngineRate) * rateK

        let gain = engineSampleGain * sfx
        // Pitch locked at 0 — rate-only like most mobile arcade racers.
        engineLowPitch?.rate = smoothEngineRate
        engineLowPitch?.pitch = 0
        engineHighPitch?.rate = min(1.1, smoothEngineRate * 1.02)
        engineHighPitch?.pitch = 0

        engineLowPlayer?.volume = min(rumbleCap, smoothEngineVol * shiftDip * gain)
        engineHighPlayer?.volume = min(bodyCap, smoothBodyVol * shiftDip * gain)

        auxMixer?.outputVolume = min(0.28, 0.1 + sn * 0.16) * sfx * raceIntroGain

        if let pn = engineLowPlayer, !pn.isPlaying { pn.play() }
        if let pn = engineHighPlayer, !pn.isPlaying { pn.play() }
    }

    private func flushSynthEngine(drive: Float, gas: Bool, rpm: Float) {
        let load = max(drive, rpm * 0.5, gas ? 0.25 : 0)
        smoothEngineVol += ((0.14 + load * 0.4) - smoothEngineVol) * 0.2
        auxMixer?.outputVolume = KRCAudioPreferences.effectiveSFX * 0.4
    }

    private func applyMasterVolume(to mixer: AVAudioMixerNode) {
        mixer.outputVolume = 0.92 * KRCAudioPreferences.effectiveSFX
    }

    func configure(cityThemeId: CityThemeID, vehicleCategory: VehicleCategory = .sports) {
        params.lock.lock()
        params.themeId = cityThemeId.rawValue
        params.vehicleCategory = vehicleCategory
        params.lock.unlock()
    }

    func update(
        forwardSpeedKmh: Float = 0,
        speedNorm: Float,
        throttle: Float,
        brake: Float = 0,
        gear: Int = 1,
        nitroActive: Bool,
        nitroTank: Float,
        trackProgress: Float,
        steerAbs: Float,
        rpm: Float = 0.35,
        passByIntensity: Float = 0
    ) {
        params.lock.lock()
        params.speedNorm = min(1, max(0, speedNorm))
        params.throttle = min(1, max(0, throttle))
        params.brake = min(1, max(0, brake))
        params.gear = gear
        params.rpm = min(1, max(0.1, rpm))
        params.nitro = nitroActive
        params.nitroTank = nitroTank
        params.trackProgress = trackProgress
        params.steerAbs = min(1, steerAbs)
        params.passBy = min(1, max(0, passByIntensity))
        params.lock.unlock()
        passByWhoosh += (min(1, max(0, passByIntensity)) - passByWhoosh) * 0.28
        flushEngineFromParams()
        _ = forwardSpeedKmh
    }

    func stop() {
        isStopped = true
        suspended = false
        lowLoopScheduled = false
        highLoopScheduled = false
        isPrepared = false
        gearIndex = 0
        lastGearForShiftFX = 1
        shiftDip = 1
        lastSpeedNorm = 0
        lastThrottle = 0
        nitroWhoosh = 0
        passByWhoosh = 0
        raceIntroActive = false
        keepEngineThroughout = false
        raceIntroElapsed = 0
        raceIntroGain = 1

        runOnMain { [weak self] in
            self?.tearDownAudioGraph()
        }
    }

    private func tearDownAudioGraph() {
        tickTimer?.invalidate()
        tickTimer = nil
        engineLowPlayer?.stop()
        engineHighPlayer?.stop()
        engineLowPlayer = nil
        engineHighPlayer = nil
        engineLowPitch = nil
        engineHighPitch = nil
        engineEQ = nil
        engineLowBuffer = nil
        engineHighBuffer = nil
        engineLoopFormat = nil
        audioEngine?.stop()
        audioEngine = nil
        procSource = nil
        auxMixer = nil
        samplesEngineActive = false
        smoothEngineVol = 0
        smoothBodyVol = 0
        smoothEngineRate = 1
    }
}
