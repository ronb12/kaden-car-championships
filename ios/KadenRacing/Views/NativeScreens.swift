import SwiftUI

// MARK: - Time formatting

func formatRaceTime(_ t: TimeInterval) -> String {
    let totalMs = max(0, Int((t * 1000.0).rounded()))
    let ms = totalMs % 1000
    let s = (totalMs / 1000) % 60
    let m = (totalMs / 1000) / 60
    return String(format: "%d:%02d.%03d", m, s, ms)
}

// MARK: - Root

struct NativeRootView: View {
    @StateObject private var flow = GameFlowState()
    @EnvironmentObject private var progress: PlayerProgressStore

    var body: some View {
        ZStack {
            switch flow.screen {
            case .mainMenu:
                MainMenuScreen(flow: flow)
            case .modeSelect:
                ModeSelectScreen(flow: flow)
            case .carSelect:
                CarSelectScreen(flow: flow)
            case .trackSelect:
                TrackSelectScreen(flow: flow)
            case .racing:
                ActiveRaceScreen(flow: flow, progress: progress)
                    .id(raceSessionId(flow))
            case .raceFinished(let elapsed):
                RaceFinishedScreen(flow: flow, lastTime: elapsed)
            case .champComplete(let total):
                ChampCompleteScreen(flow: flow, totalTime: total)
            }
        }
    }

    private func raceSessionId(_ f: GameFlowState) -> String {
        "\(f.activeGameMode.rawValue)-\(f.nightRace)-\(f.champRoundsCompleted)-\(f.trackIndexForCurrentRace())-\(f.selectedCarIndex)-\(f.effectiveLapCount())"
    }
}

// MARK: - Main menu

struct MainMenuScreen: View {
    @ObservedObject var flow: GameFlowState
    @EnvironmentObject private var progress: PlayerProgressStore
    @State private var showSettings = false

    var body: some View {
        ZStack {
            backgroundLayer
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal)
                Spacer()
                Text("KADEN RACING")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                Text("Hot Pursuit Edition")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(white: 0.9))
                Text("Credits \(progress.credits)")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(.cyan)
                Spacer()
                menuButton("PLAY") { flow.openModeSelect() }
                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                Form {
                    Section(header: Text("Driving")) {
                        Picker("Steering", selection: Binding(
                            get: { ControlPreferences.scheme },
                            set: { ControlPreferences.scheme = $0 }
                        )) {
                            ForEach(ControlScheme.allCases) { scheme in
                                Text(scheme.label).tag(scheme)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }
                .navigationTitle("Settings")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showSettings = false }
                    }
                }
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Image("MenuBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            LinearGradient(
                colors: [Color.black.opacity(0.45), Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .frame(maxWidth: 360)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.88))
                )
                .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode select

struct ModeSelectScreen: View {
    @ObservedObject var flow: GameFlowState
    @EnvironmentObject private var progress: PlayerProgressStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button("← Back") { flow.openMainMenu() }
                    Spacer()
                    Text("Credits \(progress.credits)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text("GAME MODE")
                    .font(.title.weight(.bold))
                Toggle("Night race (visual)", isOn: $flow.nightRace)
                    .tint(.orange)
                ForEach(GameModeKind.allCases) { mode in
                    modeRow(mode)
                }
            }
            .padding()
        }
        .background(Color(white: 0.08).ignoresSafeArea())
    }

    private func modeRow(_ mode: GameModeKind) -> some View {
        Button {
            switch mode {
            case .circuit: flow.beginCircuit()
            case .championshipSerie: flow.beginChampionshipSerie()
            case .policeChase: flow.beginPoliceChase()
            case .endless: flow.beginEndless()
            case .timeTrial: flow.beginTimeTrial()
            case .ghostDuel: flow.beginGhostDuelPlaceholder()
            case .career: flow.beginCareerPlaceholder()
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.displayTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(mode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Car select

struct CarSelectScreen: View {
    @ObservedObject var flow: GameFlowState
    @EnvironmentObject private var progress: PlayerProgressStore
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("← Back") { flow.screen = .modeSelect }
                Spacer()
            }
            .padding()
            Text("SELECT YOUR CAR")
                .font(.title2.weight(.bold))
                .padding(.bottom, 8)
            if flow.activeGameMode != .championshipSerie {
                VStack(alignment: .leading, spacing: 6) {
                    Text("City")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("City theme", selection: $flow.selectedCityTheme) {
                        ForEach(CityThemeID.allCases) { city in
                            Text(city.displayName).tag(city)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            } else {
                Text("Championship uses three fixed world-tour venues.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(GameCatalog.cars.enumerated()), id: \.offset) { idx, car in
                        carTile(car: car, index: idx)
                    }
                }
                .padding()
            }
            Button {
                proceedToRace()
            } label: {
                Text("SELECT & RACE")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(canRace ? Color.cyan : Color.gray))
                    .foregroundStyle(.black)
            }
            .disabled(!canRace)
            .padding()
        }
        .background(Color(white: 0.08).ignoresSafeArea())
    }

    private var selectedCar: CarChoice { GameCatalog.cars[flow.selectedCarIndex] }

    private var canRace: Bool {
        progress.unlockedCarIds.contains(selectedCar.id)
    }

    private func proceedToRace() {
        guard canRace else { return }
        if flow.needsTrackSelect() {
            flow.screen = .trackSelect
        } else {
            flow.screen = .racing
        }
    }

    private func carTile(car: CarChoice, index: Int) -> some View {
        let profile = GameCatalog.profile(forCarIndex: index)
        let unlocked = progress.unlockedCarIds.contains(car.id)
        let on = flow.selectedCarIndex == index
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                flow.selectedCarIndex = index
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(car.uiColor))
                        .frame(height: 44)
                        .overlay {
                            if !unlocked {
                                Color.black.opacity(0.45)
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                    Text(car.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    statLine("SPD", profile.speed)
                    statLine("ACC", profile.acceleration)
                    statLine("HAN", profile.handling)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(on ? Color.cyan : Color.white.opacity(0.2), lineWidth: on ? 2 : 1)
                )
            }
            .buttonStyle(.plain)
            if !unlocked {
                Button("Unlock — \(profile.unlockCostCredits) cr") {
                    _ = progress.unlockCar(id: car.id, cost: profile.unlockCostCredits)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
                .disabled(progress.credits < profile.unlockCostCredits)
            }
        }
    }

    private func statLine(_ title: String, _ v: Int) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(v)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

// MARK: - Track select

struct TrackSelectScreen: View {
    @ObservedObject var flow: GameFlowState

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("← Back") { flow.screen = .carSelect }
                Spacer()
            }
            .padding([.horizontal, .top])
            Text("CIRCUIT & LAPS")
                .font(.title2.weight(.bold))
            Text("Procedural city modules seed from your picks — same theme + track + laps ⇒ identical layout.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Picker("City theme", selection: $flow.selectedCityTheme) {
                ForEach(CityThemeID.allCases) { city in
                    Text(city.displayName).tag(city)
                }
            }
            .pickerStyle(.wheel)
            Picker("Track", selection: $flow.selectedTrackIndex) {
                ForEach(0..<GameCatalog.tracks.count, id: \.self) { i in
                    Text(GameCatalog.tracks[i].name).tag(i)
                }
            }
            .pickerStyle(.wheel)
            HStack {
                Text("Laps")
                Stepper(value: $flow.lapCount, in: 1...20) {
                    Text("\(flow.lapCount)")
                        .monospacedDigit()
                }
            }
            .padding(.horizontal)
            Spacer()
            Button {
                flow.screen = .racing
            } label: {
                Text("RACE HERE")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange))
                    .foregroundStyle(.black)
            }
            .padding()
        }
        .background(Color(white: 0.08).ignoresSafeArea())
    }
}

// MARK: - Active race

struct ActiveRaceScreen: View {
    @ObservedObject var flow: GameFlowState
    @ObservedObject var progress: PlayerProgressStore
    @StateObject private var session: RaceSessionHost
    @State private var paused = false
    @State private var tilt = TiltSteeringController()

    init(flow: GameFlowState, progress: PlayerProgressStore) {
        self.flow = flow
        self.progress = progress
        let car = GameCatalog.cars[flow.selectedCarIndex]
        let stats = GameCatalog.runtimeStats(carIndex: flow.selectedCarIndex, progress: progress)
        let city: CityRuntimeConfig = {
            if flow.activeGameMode == .championshipSerie {
                return CityManager.shared.resolveChampionship(round: flow.champRoundsCompleted)
            }
            return CityManager.shared.resolve(theme: flow.effectiveCityTheme(), seed: flow.effectiveCitySeed())
        }()
        let category = GameCatalog.profile(forCarIndex: flow.selectedCarIndex).category
        _session = StateObject(wrappedValue: RaceSessionHost(
            carColor: car.uiColor,
            lapCount: flow.effectiveLapCount(),
            mode: flow.activeGameMode,
            stats: stats,
            city: city,
            nightOverride: flow.nightRace,
            vehicleCategory: category
        ))
    }

    private var useTiltSteer: Bool { ControlPreferences.scheme == .tilt }

    var body: some View {
        ZStack {
            SceneKitRaceView(engine: session.engine)
                .ignoresSafeArea()
            raceOverlay
                .zIndex(1)
        }
        .raceLandscapePreferred()
        .onAppear {
            session.engine.setPaused(false)
            if useTiltSteer {
                tilt.start(updating: session.input)
            }
            session.engine.onRaceFinished = { t in
                DispatchQueue.main.async {
                    session.engine.setPaused(true)
                    flow.registerRaceFinish(
                        segmentTime: t,
                        driftScore: session.engine.driftScore,
                        progress: progress
                    )
                }
            }
        }
        .onDisappear {
            tilt.stop()
        }
    }

    private var raceOverlay: some View {
        VStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(flow.venueDisplayName())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(flow.activeGameMode.displayTitle.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange.opacity(0.95))
                        Text("\(session.engine.speedKmh()) km/h")
                            .font(.title2.monospacedDigit().weight(.bold))
                            .foregroundStyle(.orange)
                        Text("LAP \(session.engine.displayLapIndex) / \(session.engine.lapGoal)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white)
                        Text(formatRaceTime(session.engine.elapsedTime))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.cyan)
                        meterBar(label: "NITRO", value: session.engine.nitroMeter(), tint: .cyan)
                        if flow.activeGameMode.enablesPolice {
                            meterBar(label: "HEAT", value: session.engine.heatMeter(), tint: .red)
                        }
                        HStack {
                            Text("DRIFT ×\(String(format: "%.1f", session.engine.driftMultiplierDisplay()))")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.yellow)
                            Spacer()
                            Text("\(session.engine.driftScore) PTS")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        if useTiltSteer {
                            Text("Tilt to steer · Touch brake / gas / nitro")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        paused.toggle()
                        session.engine.setPaused(paused)
                    } label: {
                        Text(paused ? "RESUME" : "PAUSE")
                            .font(.caption.weight(.bold))
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    .foregroundStyle(.white)
                }
                .padding()
            }
            Spacer()
            touchControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .overlay {
            if paused {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    Text("PAUSED")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                }
                .onTapGesture {
                    paused = false
                    session.engine.setPaused(false)
                }
            }
        }
    }

    private func meterBar(label: String, value: Float, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint.opacity(0.9))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(tint)
                        .frame(width: g.size.width * CGFloat(min(1, max(0, value))))
                }
            }
            .frame(height: 6)
            .frame(maxWidth: 160)
        }
    }

    private var touchControls: some View {
        RacePedalCluster(input: session.input, tiltSteer: useTiltSteer)
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .padding(.bottom, 24)
            .padding(.horizontal, 10)
    }
}

// MARK: - Finish

struct RaceFinishedScreen: View {
    @ObservedObject var flow: GameFlowState
    let lastTime: TimeInterval

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("FINISH")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.orange)
                Text(formatRaceTime(lastTime))
                    .font(.system(size: 36, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                if flow.activeGameMode == .championshipSerie, flow.champRoundsCompleted < 3 {
                    Text(
                        "Next: \(CityThemeCatalog.championshipTheme(round: flow.champRoundsCompleted).displayName)"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    Button("NEXT ROUND") {
                        flow.continueChampionship()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("MAIN MENU") {
                    flow.openMainMenu()
                }
                .foregroundStyle(.cyan)
            }
            .padding()
        }
    }
}

struct ChampCompleteScreen: View {
    @ObservedObject var flow: GameFlowState
    let totalTime: TimeInterval

    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("CHAMPIONSHIP COMPLETE")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.2))
                Text("Total time")
                    .foregroundStyle(.secondary)
                Text(formatRaceTime(totalTime))
                    .font(.system(size: 34, weight: .medium, design: .monospaced))
                Button("MAIN MENU") {
                    flow.openMainMenu()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
