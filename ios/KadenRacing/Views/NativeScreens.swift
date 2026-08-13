import SwiftUI

// MARK: - Time formatting

func formatRaceTime(_ t: TimeInterval) -> String {
    let totalMs = max(0, Int((t * 1000.0).rounded()))
    let ms = totalMs % 1000
    let s = (totalMs / 1000) % 60
    let m = (totalMs / 1000) / 60
    return String(format: "%d:%02d.%03d", m, s, ms)
}

/// Compact HUD format: `m:ss.t` (tenths only) — 6 chars max, fits in the stats row.
func formatHUDTime(_ t: TimeInterval) -> String {
    let totalMs = max(0, Int((t * 1000.0).rounded()))
    let tenths = (totalMs % 1000) / 100
    let s = (totalMs / 1000) % 60
    let m = (totalMs / 1000) / 60
    return String(format: "%d:%02d.%01d", m, s, tenths)
}

// MARK: - Root

struct NativeRootView: View {
    @StateObject private var flow = GameFlowState()
    @EnvironmentObject private var progress: PlayerProgressStore
    @ObservedObject private var gameCenter = GameCenterService.shared
    #if DEBUG
    @State private var didApplyDebugLaunch = false
    #endif

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
                RaceFinishedScreen(flow: flow, progress: progress, lastTime: elapsed)
            case .champComplete(let total):
                ChampCompleteScreen(flow: flow, totalTime: total)
            }
        }
        .sheet(item: $gameCenter.sheetRequest) { request in
            GameCenterUIKitSheet(
                state: request.viewState,
                leaderboardID: request.leaderboardID,
                onDismiss: { gameCenter.sheetRequest = nil }
            )
            .ignoresSafeArea()
        }
        .onAppear {
            #if DEBUG
            guard !didApplyDebugLaunch else { return }
            didApplyDebugLaunch = true
            flow.applyDebugLaunchRouteIfNeeded(progress: progress)
            #endif
        }
        .onChange(of: gameCenter.pendingInviteRace) { go in
            guard go else { return }
            gameCenter.pendingInviteRace = false
            guard flow.screen != .racing else { return }
            KRCPlayerProfile.onlinePlayEnabled = true
            flow.beginQuickRace()
            flow.screen = .racing
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
    @ObservedObject private var online = KRCOnlineService.shared
    @ObservedObject private var gameCenter = GameCenterService.shared
    @State private var showSettings = false
    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var showWeekly = false
    @State private var showAlbum = false
    @State private var titleScale: CGFloat = 1.0
    @State private var titleOpacity: Double = 1.0
    @State private var titleBlur: CGFloat = 0
    @State private var seasonOpacity: Double = 1.0
    @State private var explodeRingScale: CGFloat = 0.2
    @State private var explodeRingOpacity: Double = 0
    @State private var carIntroNonce = 0
    @State private var menuAppearToken = UUID()

    var body: some View {
        ZStack {
            KRCDesign.MenuBackdrop()
                .ignoresSafeArea()

            GeometryReader { geo in
                let landscape = geo.size.width > geo.size.height
                VStack(spacing: 0) {
                    // ── Top bar (always visible) ───────────────────────────
                    HStack {
                        KRCDesign.CreditsChip(credits: progress.credits)
                        Spacer()
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(10)
                                .background(Circle().fill(Color.black.opacity(0.40)))
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("menu.settings.gear")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if landscape {
                        // Compact hero + car side-by-side so the mode list keeps scroll room.
                        HStack(alignment: .center, spacing: 12) {
                            KRCDesign.MenuHeroTitle(
                                flameIntensity: 0.45,
                                titleScale: titleScale,
                                titleOpacity: titleOpacity,
                                titleBlur: titleBlur,
                                seasonOpacity: seasonOpacity,
                                ringScale: explodeRingScale,
                                ringOpacity: explodeRingOpacity
                            )
                            .scaleEffect(0.52)
                            .frame(maxWidth: geo.size.width * 0.42, maxHeight: 96)
                            .clipped()

                            Spacer(minLength: 0)

                            MenuCarDriveInView(
                                car: GameCatalog.cars[flow.selectedCarIndex],
                                introNonce: carIntroNonce
                            )
                            .frame(width: min(280, geo.size.width * 0.42), height: 88)
                            .zIndex(2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                    } else {
                        KRCDesign.MenuHeroTitle(
                            flameIntensity: 0.5,
                            titleScale: titleScale,
                            titleOpacity: titleOpacity,
                            titleBlur: titleBlur,
                            seasonOpacity: seasonOpacity,
                            ringScale: explodeRingScale,
                            ringOpacity: explodeRingOpacity
                        )
                        .padding(.top, 4)
                        .padding(.bottom, 2)

                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            MenuCarDriveInView(
                                car: GameCatalog.cars[flow.selectedCarIndex],
                                introNonce: carIntroNonce
                            )
                            .frame(width: min(380, geo.size.width * 0.88), height: 128)
                            .zIndex(2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }

                    // ── SOLO / ONLINE mode bar ─────────────────────────────
                    HStack(spacing: 0) {
                        playModeButton("SOLO", solo: true)
                        playModeButton("ONLINE", solo: false)
                    }
                    .frame(maxWidth: 300)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.12)))
                    .padding(.horizontal, 40)
                    .padding(.top, landscape ? 2 : 6)
                    .padding(.bottom, landscape ? 2 : 4)
                    if KRCPlayerProfile.onlinePlayEnabled {
                        Text("Race friends & nearby · no voice chat")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(KRCDesign.neonCyan.opacity(0.9))
                            .padding(.bottom, landscape ? 4 : 6)
                    }

                    // ── Race modes — must be height-bounded to scroll ──────
                    ScrollView(.vertical, showsIndicators: landscape) {
                        VStack(spacing: 10) {
                            Button {
                                flow.beginKidPlay(progress: progress)
                            } label: {
                                VStack(spacing: 6) {
                                    Text("PLAY")
                                        .font(.system(size: landscape ? 22 : 28, weight: .black, design: .rounded))
                                        .tracking(2)
                                    Text(KidPlayLoop.nextPrize(progress: progress).line)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .multilineTextAlignment(.center)
                                        .opacity(0.92)
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, landscape ? 12 : 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [KRCDesign.gold, KRCDesign.hotOrange],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .shadow(color: KRCDesign.gold.opacity(0.45), radius: 12, y: 4)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("menu.play")

                            HStack(spacing: 8) {
                                KidToyButton(
                                    icon: "shield.fill",
                                    title: "HOT PURSUIT",
                                    subtitle: "90s bust",
                                    accent: Color(red: 0.3, green: 0.6, blue: 1)
                                ) { flow.beginPoliceChase(progress: progress) }
                                KidToyButton(
                                    icon: "shippingbox.fill",
                                    title: "COURIER",
                                    subtitle: "3 packages",
                                    accent: Color(red: 0.35, green: 0.9, blue: 0.55)
                                ) { flow.beginCourier(progress: progress, returningTo: .mainMenu) }
                            }

                            RaceMenuButton(
                                icon: "paintpalette.fill",
                                title: "PAINT SHOP",
                                subtitle: "Dress the car · wraps unlock after races",
                                accent: Color(red: 1, green: 0.45, blue: 0.75)
                            ) { flow.openCarSelect(returningTo: .mainMenu) }

                            RaceMenuButton(
                                icon: "square.grid.2x2.fill",
                                title: "TROPHY ALBUM",
                                subtitle: progress.albumSubtitle,
                                accent: KRCDesign.gold
                            ) { showAlbum = true }

                            RaceMenuButton(
                                icon: "star.fill",
                                title: progress.careerComplete
                                    ? "CAREER MODE"
                                    : (progress.careerTierCompleted > 0 ? "CONTINUE CAREER" : "CAREER MODE"),
                                subtitle: progress.careerComplete
                                    ? "Ladder complete — showcase races"
                                    : (progress.currentCareerMission.map {
                                        "\($0.title) · \(progress.careerTierCompleted)/\(CareerMissions.all.count)"
                                    } ?? "Earn credits & unlock cars"),
                                accent: KRCDesign.neonCyan
                            ) { flow.beginCareerMode(progress: progress) }

                            RaceMenuButton(
                                icon: "flag.checkered",
                                title: "QUICK RACE",
                                subtitle: "Jump straight into a circuit",
                                accent: KRCDesign.gold
                            ) { flow.beginQuickRace() }

                            RaceMenuButton(
                                icon: "trophy.fill",
                                title: "CHAMPIONSHIP",
                                subtitle: "Multi-round series",
                                accent: Color(red: 1, green: 0.65, blue: 0)
                            ) { flow.beginChampionshipSerie() }

                            RaceMenuButton(
                                icon: "calendar",
                                title: "DAILY CHALLENGE",
                                subtitle: progress.dailySubtitle,
                                accent: Color(red: 0.4, green: 0.9, blue: 0.6)
                            ) { flow.beginDailyChallenge(progress: progress) }

                            RaceMenuButton(
                                icon: "flame.fill",
                                title: "WEEKLY CONTRACTS",
                                subtitle: progress.weeklySubtitle,
                                accent: Color(red: 1, green: 0.45, blue: 0.2)
                            ) { showWeekly = true }

                            RaceMenuButton(
                                icon: "gamecontroller.fill",
                                title: "MORE MODES",
                                subtitle: "Endless · ghost duel · time trial",
                                accent: Color(red: 0.85, green: 0.3, blue: 1)
                            ) { flow.openModeSelect() }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    // ── Footer ─────────────────────────────────────────────
                    HStack(spacing: 4) {
                        menuFooterLink("GAME CENTER", id: "menu.footer.game_center") {
                            gameCenter.presentLeaderboards()
                        }
                        menuFooterLink("SETTINGS", id: "menu.footer.settings") {
                            showSettings = true
                        }
                        menuFooterLink("PRIVACY", id: "menu.footer.privacy") {
                            showPrivacy = true
                        }
                        menuFooterLink("TERMS", id: "menu.footer.terms") {
                            showTerms = true
                        }
                    }
                    .padding(.top, landscape ? 2 : 6)
                    .padding(.bottom, landscape ? 10 : 20)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .id(menuAppearToken)
        .sheet(isPresented: $showSettings) {
            NativeSettingsView(onDismiss: { showSettings = false })
                .environmentObject(progress)
        }
        .sheet(isPresented: $showPrivacy) {
            NavigationView {
                PrivacyPolicyView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showPrivacy = false } } }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showTerms) {
            NavigationView {
                TermsOfServiceView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showTerms = false } } }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showWeekly) {
            WeeklyContractsSheet(progress: progress, onDismiss: { showWeekly = false })
        }
        .sheet(isPresented: $showAlbum) {
            KidTrophyAlbumSheet(progress: progress, onDismiss: { showAlbum = false })
        }
        .alert(
            "Game Center",
            isPresented: Binding(
                get: { gameCenter.signInAlertMessage != nil },
                set: { if !$0 { gameCenter.signInAlertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { gameCenter.signInAlertMessage = nil }
        } message: {
            Text(gameCenter.signInAlertMessage ?? "")
        }
        .onDisappear {
            MenuIntroAudioController.shared.stop()
            KRCMusicDirector.shared.play(.menu)
        }
        .onAppear {
            runMenuIntro()
            #if DEBUG
            if KRCDebugUI.openSettingsOnMenu {
                KRCDebugUI.openSettingsOnMenu = false
                showSettings = true
            }
            if KRCDebugUI.openPrivacyOnMenu {
                KRCDebugUI.openPrivacyOnMenu = false
                showPrivacy = true
            }
            if KRCDebugUI.openTermsOnMenu {
                KRCDebugUI.openTermsOnMenu = false
                showTerms = true
            }
            if KRCDebugUI.showGameCenterAlertOnMenu {
                KRCDebugUI.showGameCenterAlertOnMenu = false
                gameCenter.signInAlertMessage =
                    "Sign in to Game Center in the iOS Settings app to view leaderboards."
            }
            #endif
        }
    }

    /// Replay logo, flames, and drive-in whenever the menu is shown.
    private func runMenuIntro() {
        menuAppearToken = UUID()
        titleScale = 2.6
        titleOpacity = 0
        titleBlur = 14
        seasonOpacity = 0
        explodeRingScale = 0.2
        explodeRingOpacity = 0
        carIntroNonce += 1

        Task { await online.refreshGlobalSummary() }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.45)) {
                explodeRingScale = 2.2
                explodeRingOpacity = 0.85
            }
            withAnimation(.easeOut(duration: 0.55).delay(0.05)) {
                explodeRingOpacity = 0
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) {
                titleScale = 1.0
                titleOpacity = 1.0
                titleBlur = 0
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.55)) {
                seasonOpacity = 1.0
            }
        }

        // If SwiftUI skips animations (e.g. after returning from a race), force visible UI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if titleOpacity < 0.5 {
                titleScale = 1.0
                titleOpacity = 1.0
                titleBlur = 0
                seasonOpacity = 1.0
                explodeRingOpacity = 0
            }
        }
    }

    private func menuFooterLink(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(KRCDesign.neonCyan.opacity(0.82))
                .padding(.horizontal, 6)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func playModeButton(_ title: String, solo: Bool) -> some View {
        let active = KRCPlayerProfile.onlinePlayEnabled != solo
        return Button {
            KRCPlayerProfile.onlinePlayEnabled = !solo
            Task { await online.refreshGlobalSummary() }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .black))
                .kerning(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(active ? KRCDesign.gold : Color.clear)
                .foregroundStyle(active ? Color.black : Color.white.opacity(0.6))
        }
        .buttonStyle(.plain)
    }
}

private struct KidToyButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.38))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(accent.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("menu.\(title.replacingOccurrences(of: " ", with: "_").lowercased())")
    }
}

// Cinematic race-mode button row
private struct RaceMenuButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accent.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(accent)
                }

                // Labels
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.38))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(accent.opacity(0.28), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("menu.\(title.replacingOccurrences(of: " ", with: "_").lowercased())")
    }
}

// MARK: - Mode select

struct ModeSelectScreen: View {
    @ObservedObject var flow: GameFlowState
    @EnvironmentObject private var progress: PlayerProgressStore

    var body: some View {
        KRCArcadeScreen(title: "ARCADE MODES", subtitle: "Pick a challenge style") {
            KRCDesign.ArcadeTopBar(
                backTitle: "Menu",
                backAction: { flow.openMainMenu() },
                credits: progress.credits
            )
            KRCDesign.Panel {
                Toggle(isOn: $flow.nightRace) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Night race")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Darker city lighting & neon roads")
                            .font(.caption)
                            .foregroundStyle(KRCDesign.mutedText)
                    }
                }
                .tint(KRCDesign.hotOrange)
            }
            VStack(spacing: 10) {
                ForEach(GameModeKind.allCases) { mode in
                    modeRow(mode)
                }
            }
        }
    }

    private func modeIcon(_ mode: GameModeKind) -> String {
        switch mode {
        case .circuit: return "flag.checkered"
        case .championshipSerie: return "trophy.fill"
        case .policeChase: return "shield.fill"
        case .endless: return "infinity"
        case .timeTrial: return "stopwatch.fill"
        case .ghostDuel: return "figure.run"
        case .career: return "star.fill"
        case .courier: return "shippingbox.fill"
        }
    }

    private func modeRow(_ mode: GameModeKind) -> some View {
        Button {
            switch mode {
            case .circuit:
                flow.beginCircuit()
                flow.carSelectBackScreen = .modeSelect
            case .championshipSerie:
                flow.beginChampionshipSerie()
                flow.carSelectBackScreen = .modeSelect
            case .policeChase: flow.beginPoliceChase(progress: progress)
            case .endless: flow.beginEndless()
            case .timeTrial: flow.beginTimeTrial()
            case .ghostDuel: flow.beginGhostDuel()
            case .career: flow.beginCareerPlaceholder(progress: progress)
            case .courier: flow.beginCourier(progress: progress)
            }
        } label: {
            KRCDesign.ListRow(
                icon: modeIcon(mode),
                title: mode.displayTitle,
                subtitle: mode.subtitle,
                accent: KRCDesign.neonCyan
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Car select

struct CarSelectScreen: View {
    @ObservedObject var flow: GameFlowState
    @EnvironmentObject private var progress: PlayerProgressStore
    @State private var styleTick = 0
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ZStack {
            KRCDesign.MenuBackdrop()
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        KRCDesign.ArcadeTopBar(
                            backTitle: "Back",
                            backAction: { flow.screen = flow.carSelectBackScreen },
                            credits: progress.credits,
                            trailing: "\(GameCatalog.cars.count) CARS"
                        )
                        KRCDesign.ScreenHeader(
                            title: "KRC GARAGE",
                            subtitle: flow.activeGameMode.displayTitle.uppercased()
                        )
                        raceSetupBar
                        if flow.activeGameMode == .championshipSerie, let round = flow.currentChampionshipRound() {
                            KRCDesign.Panel {
                                VStack(alignment: .leading, spacing: 4) {
                                    KRCDesign.SectionLabel(text: "CHAMPIONSHIP ROUND")
                                    Text("\(round.name) · \(GameCatalog.activeTracks[round.trackIndex].name)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("\(round.laps) laps")
                                        .font(.caption)
                                        .foregroundStyle(KRCDesign.mutedText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else if !flow.needsTrackSelect() {
                            KRCDesign.Panel {
                                VStack(alignment: .leading, spacing: 8) {
                                    KRCDesign.SectionLabel(text: "CITY THEME")
                                    CityThemePicker(selection: $flow.selectedCityTheme)
                                }
                            }
                        }
                        ZStack {
                            CarPreview3DView(
                                car: selectedCar,
                                height: 150,
                                bodyColorOverride: GarageCustomization.bodyColor(for: selectedCar),
                                appearanceKey: "\(styleTick)-\(GarageCustomization.style(for: selectedCar.id).rim.rawValue)-\(GarageCustomization.style(for: selectedCar.id).wrap.rawValue)-\(GarageCustomization.style(for: selectedCar.id).paint.rawValue)-\(KidShowOffLoadout.live.appearanceKey)"
                            )
                            // Remount only when the car identity changes — styleTick used to
                            // rebuild the whole SCNView on every paint/wrap tweak and flash the spin.
                            .id(selectedCar.id)
                        }
                            .frame(height: 150)
                            .background(Color(red: 0.04, green: 0.05, blue: 0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [KRCDesign.gold.opacity(0.6), KRCDesign.neonCyan.opacity(0.35)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
                        if canRace {
                            garageCustomizePanel
                        } else {
                            lockedCarCallout
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(sortedGarageCars, id: \.offset) { idx, car in
                                carTile(car: car, index: idx)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)
                    KRCDesign.PrimaryButton(
                        title: canRace
                            ? "SELECT & RACE"
                            : (flow.activeGameMode == .policeChase && selectedCar.id != "police"
                               ? "NEED INTERCEPTOR"
                               : "LOCKED — EARN THIS CAR"),
                        enabled: canRace
                    ) {
                        proceedToRace()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
                .background(Color.black.opacity(0.95))
            }
        }
        .onAppear {
            KRCMusicDirector.shared.play(.garage)
            // After economy migration, keep selection on an owned car.
            if !progress.unlockedCarIds.contains(selectedCar.id),
               let ownedIdx = GameCatalog.cars.firstIndex(where: { progress.unlockedCarIds.contains($0.id) }) {
                flow.selectedCarIndex = ownedIdx
            }
            if !flow.needsTrackSelect() {
                flow.preloadRaceEnvironment()
            }
        }
        .onChange(of: flow.selectedCarIndex) { _ in
            if !flow.needsTrackSelect() {
                flow.preloadRaceEnvironment()
            }
        }
        .onChange(of: flow.difficultyIndex) { _ in
            if !flow.needsTrackSelect() {
                flow.preloadRaceEnvironment()
            }
        }
        .onChange(of: flow.selectedCityTheme) { _ in
            if !flow.needsTrackSelect() {
                flow.preloadRaceEnvironment()
            }
        }
    }

    private var selectedCar: CarChoice { GameCatalog.cars[flow.selectedCarIndex] }

    private var sortedGarageCars: [(offset: Int, element: CarChoice)] {
        Array(GameCatalog.cars.enumerated()).sorted { a, b in
            let sa = GameCatalog.garageSortIndex(forCarId: a.element.id, progress: progress)
            let sb = GameCatalog.garageSortIndex(forCarId: b.element.id, progress: progress)
            if sa.0 != sb.0 { return sa.0 < sb.0 }
            if sa.1 != sb.1 { return sa.1 < sb.1 }
            return sa.2 < sb.2
        }
    }

    private var canRace: Bool {
        progress.unlockedCarIds.contains(selectedCar.id)
            && (flow.activeGameMode != .policeChase || selectedCar.id == "police")
    }

    private var selectedUnlockStatus: PlayerProgressStore.CarUnlockStatus {
        progress.unlockStatus(forCarId: selectedCar.id)
    }

    private var raceSetupBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            KRCDesign.DifficultyChips(index: $flow.difficultyIndex)
            if !flow.needsTrackSelect() {
                HStack {
                    KRCDesign.SectionLabel(text: "LAPS")
                    Stepper(value: $flow.lapCount, in: 1...30) {
                        Text("\(flow.lapCount)")
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var garageCustomizePanel: some View {
        let carId = selectedCar.id
        let style = GarageCustomization.style(for: carId)
        let up = progress.upgrades[carId] ?? .baseline
        return KRCDesign.Panel {
            VStack(alignment: .leading, spacing: 10) {
                KRCDesign.SectionLabel(text: "PAINT SHOP")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(GaragePaintSwatch.allCases) { swatch in
                            let owned = progress.ownsPaint(swatch)
                            Button {
                                guard owned else { return }
                                GarageCustomization.setPaint(swatch, for: carId)
                                styleTick += 1
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(swatch.color ?? selectedCar.uiColor))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle().strokeBorder(
                                                style.paint == swatch ? KRCDesign.gold : Color.white.opacity(0.25),
                                                lineWidth: style.paint == swatch ? 2 : 1
                                            )
                                        )
                                    if !owned {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .opacity(owned ? 1 : 0.45)
                            }
                            .accessibilityLabel(owned ? swatch.label : "\(swatch.label) locked")
                        }
                    }
                }
                KRCDesign.SectionLabel(text: "WRAP")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(GarageWrapStyle.allCases) { wrap in
                            let owned = progress.ownsWrap(wrap)
                            Button {
                                guard owned else { return }
                                GarageCustomization.setWrap(wrap, for: carId)
                                styleTick += 1
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color(wrap.previewColor))
                                            .frame(width: 52, height: 28)
                                        if let second = wrap.secondaryPreviewColor {
                                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                                .fill(Color(second))
                                                .frame(width: 8, height: 22)
                                        }
                                        if !owned {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(
                                                style.wrap == wrap ? KRCDesign.gold : Color.white.opacity(0.2),
                                                lineWidth: style.wrap == wrap ? 2 : 1
                                            )
                                    )
                                    .opacity(owned ? 1 : 0.45)
                                    Text(owned ? wrap.label : "Race")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(style.wrap == wrap ? KRCDesign.gold : .white.opacity(0.75))
                                }
                            }
                            .accessibilityLabel(owned ? wrap.label : "\(wrap.label) locked")
                        }
                    }
                }
                KRCDesign.SectionLabel(text: "HOOD STICKER")
                collectibleChipRow(items: KidSticker.allCases.map { item in
                    CollectibleChip(
                        id: item.rawValue,
                        title: item.title,
                        symbol: item.symbolName,
                        tint: Color(uiColor: item.tint),
                        owned: progress.ownsSticker(item),
                        equipped: progress.equippedHoodStickerId == item.rawValue
                    )
                }) { id in
                    if let sticker = KidSticker(rawValue: id) {
                        progress.equipHoodSticker(progress.equippedHoodStickerId == id ? nil : sticker)
                        styleTick += 1
                    }
                }
                KRCDesign.SectionLabel(text: "DOOR STICKER")
                collectibleChipRow(items: KidSticker.allCases.map { item in
                    CollectibleChip(
                        id: item.rawValue,
                        title: item.title,
                        symbol: item.symbolName,
                        tint: Color(uiColor: item.tint),
                        owned: progress.ownsSticker(item),
                        equipped: progress.equippedDoorStickerId == item.rawValue
                    )
                }) { id in
                    if let sticker = KidSticker(rawValue: id) {
                        progress.equipDoorSticker(progress.equippedDoorStickerId == id ? nil : sticker)
                        styleTick += 1
                    }
                }
                KRCDesign.SectionLabel(text: "RARE TOYS")
                collectibleChipRow(items: KidToy.allCases.map { item in
                    CollectibleChip(
                        id: item.rawValue,
                        title: item.title,
                        symbol: item.symbolName,
                        tint: KRCDesign.hotOrange,
                        owned: progress.ownsToy(item),
                        equipped: progress.equippedToyIds.contains(item.rawValue)
                    )
                }) { id in
                    if let toy = KidToy(rawValue: id) {
                        progress.toggleToy(toy)
                        styleTick += 1
                    }
                }
                KRCDesign.SectionLabel(text: "PLATES")
                collectibleChipRow(items: KidPlate.allCases.map { item in
                    CollectibleChip(
                        id: item.rawValue,
                        title: item.shortText,
                        symbol: "rectangle.fill",
                        tint: KRCDesign.gold,
                        owned: progress.ownsPlate(item),
                        equipped: progress.equippedPlateId == item.rawValue
                    )
                }) { id in
                    if let plate = KidPlate(rawValue: id) {
                        progress.equipPlate(plate)
                        styleTick += 1
                    }
                }
                KRCDesign.SectionLabel(text: "DRIVER HATS")
                collectibleChipRow(items: KidHat.allCases.map { item in
                    CollectibleChip(
                        id: item.rawValue,
                        title: item.title,
                        symbol: item.symbolName,
                        tint: Color(uiColor: item.color),
                        owned: progress.ownsHat(item),
                        equipped: progress.equippedHatId == item.rawValue
                    )
                }) { id in
                    if let hat = KidHat(rawValue: id) {
                        progress.equipHat(progress.equippedHatId == id ? nil : hat)
                        styleTick += 1
                    }
                }
                KRCDesign.SectionLabel(text: "RIMS")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(GarageRimStyle.allCases) { rim in
                            Button {
                                GarageCustomization.setRim(rim, for: carId)
                                styleTick += 1
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.55))
                                            .frame(width: 34, height: 34)
                                        Circle()
                                            .strokeBorder(Color(rim.previewColor), lineWidth: 5)
                                            .frame(width: 28, height: 28)
                                        Circle()
                                            .fill(Color(rim.previewColor).opacity(0.85))
                                            .frame(width: 10, height: 10)
                                    }
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                style.rim == rim ? KRCDesign.gold : Color.clear,
                                                lineWidth: 2
                                            )
                                            .frame(width: 36, height: 36)
                                    )
                                    Text(rim.label)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(style.rim == rim ? KRCDesign.gold : .white.opacity(0.75))
                                }
                            }
                            .accessibilityLabel(rim.label)
                        }
                    }
                }
                KRCDesign.SectionLabel(text: "UPGRADES")
                Text("Each level stacks — buy to raise race performance.")
                    .font(.caption2)
                    .foregroundStyle(KRCDesign.mutedText)
                HStack(alignment: .top, spacing: 8) {
                    upgradeButton(slot: .engine, level: up.engine, carId: carId)
                    upgradeButton(slot: .nitro, level: up.nitro, carId: carId)
                    upgradeButton(slot: .tires, level: up.tires, carId: carId)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(styleTick)
        }
    }

    private struct CollectibleChip: Identifiable {
        var id: String
        var title: String
        var symbol: String
        var tint: Color
        var owned: Bool
        var equipped: Bool
    }

    private func collectibleChipRow(items: [CollectibleChip], action: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button {
                        guard item.owned else { return }
                        action(item.id)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(item.tint.opacity(item.owned ? 0.35 : 0.12))
                                    .frame(width: 52, height: 36)
                                Image(systemName: item.symbol)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(item.owned ? .white : .white.opacity(0.35))
                                if !item.owned {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .offset(x: 16, y: -10)
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(
                                        item.equipped ? KRCDesign.gold : Color.white.opacity(0.18),
                                        lineWidth: item.equipped ? 2 : 1
                                    )
                            )
                            Text(item.owned ? item.title : "Race")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(item.equipped ? KRCDesign.gold : .white.opacity(0.75))
                        }
                    }
                    .accessibilityLabel(item.owned ? item.title : "\(item.title) locked")
                    .opacity(item.owned ? 1 : 0.5)
                }
            }
        }
    }

    private func chipButton(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(on ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(on ? KRCDesign.neonCyan : Color.white.opacity(0.12)))
        }
    }

    private func upgradeButton(slot: PlayerProgressStore.UpgradeSlot, level: Int, carId: String) -> some View {
        let cost = progress.upgradeCost(level: level)
        let maxed = level >= 5
        let canBuy = !maxed && progress.credits >= cost
        return Button {
            _ = progress.upgrade(carId: carId, slot: slot, cost: cost)
            styleTick += 1
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(slot.shortTitle)
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    Spacer(minLength: 0)
                    Text("\(level)/5")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(KRCDesign.neonCyan)
                }
                Text(slot.benefitHeadline)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                if maxed {
                    Text("MAXED")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(KRCDesign.gold)
                } else {
                    Text(slot.nextLevelGain)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(KRCDesign.gold.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(cost) CR")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(canBuy ? KRCDesign.gold : .orange.opacity(0.85))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(canBuy ? KRCDesign.neonCyan.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .disabled(!canBuy)
        .opacity(maxed ? 0.55 : (canBuy ? 1 : 0.5))
        .accessibilityLabel("\(slot.shortTitle) level \(level). \(slot.benefitHeadline). \(maxed ? "Maxed" : slot.nextLevelGain)")
    }

    private func proceedToRace() {
        guard canRace else { return }
        if flow.needsTrackSelect() {
            flow.screen = .trackSelect
        } else {
            flow.preloadRaceEnvironment {
                flow.screen = .racing
            }
        }
    }

    private func carTile(car: CarChoice, index: Int) -> some View {
        let profile = GameCatalog.profile(forCarIndex: index)
        let unlocked = progress.unlockedCarIds.contains(car.id)
        let status = progress.unlockStatus(forCarId: car.id)
        let on = flow.selectedCarIndex == index
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                flow.selectedCarIndex = index
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(car.uiColor).opacity(0.22),
                                        Color(white: 0.1),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        GarageCarImage(car: car, paintColor: GarageCustomization.bodyColor(for: car))
                            .frame(height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .id("tile-\(car.id)-\(styleTick)")
                        if !unlocked {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.55))
                            VStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.white)
                                Text(profile.unlockTierLabel)
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(KRCDesign.gold)
                            }
                        }
                    }
                    .frame(height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(car.uiColor).opacity(on ? 0.85 : 0.35), lineWidth: on ? 2 : 1)
                    )
                    Text(car.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(unlocked ? "OWNED" : profile.formattedUnlockCost)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(unlocked ? KRCDesign.neonCyan : .orange)
                    statLine("SPD", profile.speed)
                    statLine("ACC", profile.acceleration)
                    statLine("HAN", profile.handling)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(on ? KRCDesign.cardFill : Color.black.opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    on ? KRCDesign.neonCyan : Color.white.opacity(0.18),
                                    lineWidth: on ? 2 : 1
                                )
                        )
                        .shadow(color: on ? KRCDesign.neonCyan.opacity(0.2) : .clear, radius: 8)
                )
            }
            .buttonStyle(.plain)
            if !unlocked {
                unlockButton(for: car.id, status: status, profile: profile)
            }
        }
    }

    @ViewBuilder
    private func unlockButton(
        for carId: String,
        status: PlayerProgressStore.CarUnlockStatus,
        profile: CarStatProfile
    ) -> some View {
        switch status {
        case .purchasable(let cost):
            Button("BUY — \(profile.formattedUnlockCost)") {
                _ = progress.unlockCar(id: carId, cost: cost)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(KRCDesign.gold)
        case .needCredits(let cost):
            Text("NEED \(profile.formattedUnlockCost)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange.opacity(0.85))
            Text("\(progress.credits) / \(cost) CR")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(KRCDesign.mutedText)
        case .careerGated(let tiers):
            Text("CAREER RANK \(tiers)+")
                .font(.caption.weight(.bold))
                .foregroundStyle(KRCDesign.neonCyan.opacity(0.9))
            Text("Complete more career missions")
                .font(.caption2)
                .foregroundStyle(KRCDesign.mutedText)
        case .owned:
            EmptyView()
        case .locked(let reason):
            Text(reason)
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
        }
    }

    private var lockedCarCallout: some View {
        let profile = GameCatalog.profile(forCarIndex: flow.selectedCarIndex)
        let status = selectedUnlockStatus
        return KRCDesign.Panel {
            VStack(alignment: .leading, spacing: 10) {
                KRCDesign.SectionLabel(text: "EARN THIS CAR")
                Text(selectedCar.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(profile.unlockTierLabel) · \(profile.category.rawValue.uppercased())")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(KRCDesign.gold)
                switch status {
                case .purchasable(let cost):
                    Text("Buy with race credits or unlock it free through Career.")
                        .font(.caption)
                        .foregroundStyle(KRCDesign.mutedText)
                    Button {
                        _ = progress.unlockCar(id: selectedCar.id, cost: cost)
                    } label: {
                        Text("UNLOCK — \(profile.formattedUnlockCost)")
                            .font(.subheadline.weight(.black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(KRCDesign.gold))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                case .needCredits(let cost):
                    Text("Race to earn credits, then buy this ride.")
                        .font(.caption)
                        .foregroundStyle(KRCDesign.mutedText)
                    Text("\(progress.credits) / \(cost) CR")
                        .font(.title3.weight(.black).monospacedDigit())
                        .foregroundStyle(.orange)
                case .careerGated(let tiers):
                    Text("Reach Career mission \(tiers) before this car hits the dealership.")
                        .font(.caption)
                        .foregroundStyle(KRCDesign.mutedText)
                    Text("Career progress \(progress.careerTierCompleted)/\(tiers)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(KRCDesign.neonCyan)
                default:
                    Text("Finish Career missions or grind credits to unlock the garage.")
                        .font(.caption)
                        .foregroundStyle(KRCDesign.mutedText)
                }
                if let rewardMission = CareerMissions.all.first(where: { $0.unlockCarId == selectedCar.id }),
                   let idx = CareerMissions.all.firstIndex(where: { $0.id == rewardMission.id }),
                   idx >= progress.careerTierCompleted {
                    Text("Career reward: \(rewardMission.title)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(KRCDesign.neonCyan.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statLine(_ title: String, _ v: Int) -> some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundStyle(KRCDesign.mutedText)
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
    @State private var trackEnvironmentReady = false
    private let trackColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        KRCArcadeScreen(
            title: "SELECT CIRCUIT",
            subtitle: "Same city + track + laps = identical layout"
        ) {
            KRCDesign.ArcadeTopBar(
                backTitle: "Garage",
                backAction: { flow.screen = .carSelect },
                trailing: "\(GameCatalog.activeTracks.count) TRACKS"
            )
            KRCDesign.DifficultyChips(index: $flow.difficultyIndex)
            let selectedTrack = GameCatalog.activeTracks[flow.selectedTrackIndex]
            VStack(alignment: .leading, spacing: 8) {
                TrackPreviewArt(
                    trackIndex: flow.selectedTrackIndex,
                    accent: KRCDesign.gold
                )
                .frame(height: 118)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(KRCDesign.gold.opacity(0.55), lineWidth: 1.5)
                )
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedTrack.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(selectedTrack.tag)
                            .font(.caption)
                            .foregroundStyle(KRCDesign.neonCyan.opacity(0.9))
                    }
                    Spacer()
                    Text(String(format: "%02d", flow.selectedTrackIndex + 1))
                        .font(.title2.weight(.black).monospacedDigit())
                        .foregroundStyle(KRCDesign.gold)
                }
            }
            KRCDesign.Panel {
                VStack(alignment: .leading, spacing: 8) {
                    KRCDesign.SectionLabel(text: "CITY THEME")
                    CityThemePicker(selection: $flow.selectedCityTheme, layout: .trackSelect)
                }
            }
            LazyVGrid(columns: trackColumns, spacing: 10) {
                ForEach(0..<GameCatalog.activeTracks.count, id: \.self) { i in
                    trackCard(index: i)
                }
            }
            KRCDesign.Panel {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        KRCDesign.SectionLabel(text: "LAPS")
                        Text("Default 3 · up to 30")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Stepper(value: $flow.lapCount, in: 1...30) {
                        Text("\(flow.lapCount)")
                            .font(.headline.monospacedDigit().weight(.bold))
                            .foregroundStyle(KRCDesign.gold)
                    }
                }
            }
        } footer: {
            let track = GameCatalog.activeTracks[flow.selectedTrackIndex]
            KRCDesign.PrimaryButton(
                title: trackEnvironmentReady ? "RACE · \(track.name.uppercased())" : "PREPARING TRACK…",
                enabled: trackEnvironmentReady
            ) {
                flow.preloadRaceEnvironment {
                    flow.screen = .racing
                }
            }
        }
        .onAppear {
            flow.syncLapsToSelectedTrack()
            refreshTrackEnvironmentPreload()
        }
        .onChange(of: flow.selectedTrackIndex) { _ in
            flow.syncLapsToSelectedTrack()
            refreshTrackEnvironmentPreload()
        }
        .onChange(of: flow.selectedCityTheme) { _ in
            refreshTrackEnvironmentPreload()
        }
        .onChange(of: flow.nightRace) { _ in
            refreshTrackEnvironmentPreload()
        }
    }

    private func refreshTrackEnvironmentPreload() {
        let key = flow.environmentCacheKey()
        if RaceEnvironmentPreloader.isReady(for: key) {
            trackEnvironmentReady = true
            return
        }
        trackEnvironmentReady = false
        flow.preloadRaceEnvironment {
            trackEnvironmentReady = true
        }
    }

    private func trackCard(index: Int) -> some View {
        let tr = GameCatalog.activeTracks[index]
        let selected = flow.selectedTrackIndex == index
        return Button {
            flow.selectedTrackIndex = index
            flow.lapCount = tr.lapsDefault
            flow.selectedCityTheme = EnvironmentTrackProfile.from(catalogTrackIndex: index).suggestedCityTheme
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                TrackPreviewArt(
                    trackIndex: index,
                    accent: selected ? KRCDesign.gold : KRCDesign.neonCyan
                )
                .frame(height: 56)
                Text(String(format: "%02d", index + 1))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(KRCDesign.gold)
                Text(tr.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(tr.tag)
                    .font(.caption2)
                    .foregroundStyle(KRCDesign.neonCyan.opacity(0.85))
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.orange.opacity(0.18) : KRCDesign.panelFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selected ? KRCDesign.gold : Color.cyan.opacity(0.35), lineWidth: selected ? 2 : 1)
                    )
                    .shadow(color: selected ? KRCDesign.gold.opacity(0.25) : .clear, radius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Active race

struct ActiveRaceScreen: View {
    @ObservedObject var flow: GameFlowState
    @ObservedObject var progress: PlayerProgressStore
    @ObservedObject private var online = KRCOnlineService.shared
    @StateObject private var session: RaceSessionHost
    @State private var paused = false
    @State private var environmentPreloaded = false
    @State private var scenePrepared = false
    @State private var matchGateReady = false
    @State private var matchmakingTask: Task<Void, Never>?
    @State private var lastKidEmoteAt: TimeInterval = 0
    #if DEBUG
    @State private var showTutorial = !KRCTutorial.hasShownControlsTip && !KRCDebugUI.isQALaunch
    #else
    @State private var showTutorial = !KRCTutorial.hasShownControlsTip
    #endif
    @State private var tilt = TiltSteeringController()

    init(flow: GameFlowState, progress: PlayerProgressStore) {
        self.flow = flow
        self.progress = progress
        let car = GameCatalog.cars[flow.selectedCarIndex]
        let stats = GameCatalog.runtimeStats(carIndex: flow.selectedCarIndex, progress: progress)
        let city = flow.cityForCurrentRace()
        let category = GameCatalog.profile(forCarIndex: flow.selectedCarIndex).category
        let onlineCtx = RaceOnlineContext(
            carId: car.id,
            carName: car.name,
            colorInt: car.colorUInt32,
            cityThemeIndex: flow.selectedCityTheme.rawValue,
            trackIndex: flow.trackIndexForCurrentRace(),
            trackKey: "\(flow.selectedCityTheme.rawValue)-\(flow.trackIndexForCurrentRace())",
            mode: flow.activeGameMode.rawValue
        )
        _session = StateObject(wrappedValue: RaceSessionHost(
            carColor: GarageCustomization.bodyColor(for: car),
            carId: car.id,
            lapCount: flow.effectiveLapCount(),
            mode: flow.activeGameMode,
            stats: stats,
            city: city,
            nightOverride: flow.nightRace,
            vehicleCategory: category,
            difficultyGripMul: flow.difficultyGripMul(),
            difficultyIndex: flow.difficultyIndex,
            playerCarIndex: flow.selectedCarIndex,
            onlineContext: KRCPlayerProfile.onlinePlayEnabled ? onlineCtx : nil,
            pursuitSuspectCount: flow.pursuitSuspectCountOverride,
            pursuitTimeLimit: flow.pursuitTimeLimitOverride,
            pursuitRoadblocks: flow.pursuitRoadblocksEnabled,
            ghostTrackKey: RaceGhostTape.trackKey(
                trackIndex: flow.trackIndexForCurrentRace(),
                laps: flow.effectiveLapCount()
            ),
            courierConfig: CourierSessionConfig.from(progress: progress, nightRace: flow.nightRace)
        ))
        _matchGateReady = State(initialValue: !KRCPlayerProfile.onlinePlayEnabled)
    }

    private var useTiltSteer: Bool { ControlPreferences.scheme == .tilt }
    private var useDPadControls: Bool { ControlPreferences.scheme == .dpad }

    private var raceVisualReady: Bool { environmentPreloaded && scenePrepared }

    private func beginRaceIfReady() {
        guard raceVisualReady, matchGateReady, !paused else { return }
        session.engine.setPaused(false)
    }

    private func startMatchmakingIfNeeded() {
        guard KRCPlayerProfile.onlinePlayEnabled else {
            matchGateReady = true
            beginRaceIfReady()
            return
        }
        guard matchmakingTask == nil else { return }
        let car = GameCatalog.cars[flow.selectedCarIndex]
        let trackKey = "\(flow.selectedCityTheme.rawValue)-\(flow.trackIndexForCurrentRace())"
        matchmakingTask = Task { @MainActor in
            session.engine.setPaused(true)
            var racedHumans = false
            #if DEBUG
            let skipGameCenter = KRCDebugUI.isQALaunch
            #else
            let skipGameCenter = false
            #endif
            if !skipGameCenter, GameCenterService.shared.isAuthenticated {
                let gc = await GameCenterService.shared.presentRaceMatchmaker()
                if gc == .matched {
                    online.bindGameCenterMatch()
                    racedHumans = true
                }
            }
            if !racedHumans {
                let live = await online.runMatchmaking(
                    trackKey: trackKey,
                    mode: flow.activeGameMode.rawValue,
                    carId: car.id,
                    carName: car.name,
                    colorInt: car.colorUInt32
                )
                if !live {
                    online.markSoloFallback()
                    try? await Task.sleep(nanoseconds: 700_000_000)
                }
            }
            matchGateReady = true
            beginRaceIfReady()
        }
    }

    var body: some View {
        ZStack {
            if environmentPreloaded {
                SceneKitRaceView(engine: session.engine) {
                    scenePrepared = true
                    beginRaceIfReady()
                }
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            if raceVisualReady {
                raceOverlay
                    .zIndex(1)
            }
            if !raceVisualReady {
                Color.black.opacity(0.72)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(KRCDesign.gold)
                    Text("LOADING TRACK")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(KRCDesign.gold)
                }
                .zIndex(2)
            }
            if raceVisualReady && !matchGateReady {
                matchmakingOverlay
                    .zIndex(3)
            }
        }
        .raceAllOrientationsAllowed()
        .onAppear {
            AppOrientationController.shared.supportedMask = .allButUpsideDown
            environmentPreloaded = false
            scenePrepared = false
            matchGateReady = !KRCPlayerProfile.onlinePlayEnabled
            session.engine.setPaused(true)
            flow.preloadRaceEnvironment {
                environmentPreloaded = true
                #if DEBUG
                if KRCDebugUI.startRacePaused {
                    KRCDebugUI.startRacePaused = false
                    paused = true
                    session.engine.setPaused(true)
                    return
                }
                #endif
                startMatchmakingIfNeeded()
                beginRaceIfReady()
            }
            KRCMusicDirector.shared.play(.countdown)
            #if DEBUG
            let qaDrive = RaceQAAutopilot.enabled
            #else
            let qaDrive = false
            #endif
            if useTiltSteer, !qaDrive {
                tilt.start(updating: session.input)
            }
            if session.engine.onRaceFinished == nil {
                session.engine.onRaceFinished = { t in
                    DispatchQueue.main.async {
                        session.engine.setPaused(true)
                        // Finish ceremony beat — let victory music + last frame breathe.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                            flow.registerRaceFinish(
                                segmentTime: t,
                                driftScore: session.engine.driftScore,
                                arcadeBonusCredits: session.engine.arcadeBonusCredits(),
                                position: session.engine.racePosition,
                                racerCount: session.engine.racerCount,
                                heat: session.engine.heatMeter(),
                                damage: session.engine.damageMeter(),
                                pursuitBusts: session.engine.isCourierRun()
                                    ? session.engine.courierDeliveries
                                    : session.engine.pursuitBusts,
                                ticketFines: session.engine.ticketFinesTotal(),
                                ticketLines: session.engine.issuedTickets.map { "\($0.driverName) · \($0.speedKmh) km/h · \($0.fineCredits) CR" },
                                crystalsCollected: session.engine.arcadeCrystals,
                                courierGrade: session.engine.isCourierRun()
                                    ? session.engine.courierShiftGrade
                                    : nil,
                                houseGhostDelta: session.engine.houseGhostDelta,
                                hadHouseGhost: session.engine.hadHouseGhost,
                                progress: progress
                            )
                        }
                    }
                }
            }
        }
        .onDisappear {
            matchmakingTask?.cancel()
            matchmakingTask = nil
            tilt.stop()
            session.engine.tearDown()
            KRCMusicDirector.shared.stop()
            flow.preloadRaceEnvironment()
        }
    }

    private var matchmakingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("RACE FRIENDS")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(KRCDesign.gold)
                Text("No voice chat · WAVE and NICE only")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(KRCDesign.mutedText)
                Group {
                    switch online.matchmakingPhase {
                    case .searching:
                        Text("FINDING RACERS…")
                        Text("Invite friends, nearby, or a public lobby")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(KRCDesign.mutedText)
                    case .waiting(let seconds, let racers):
                        if seconds > 3 {
                            Text(racers <= 1 ? "LOBBY OPEN" : "HUMANS FOUND")
                            Text(racers <= 1
                                 ? "Starts with you + CPU if nobody joins"
                                 : "\(racers) HUMANS · CPU fills the rest")
                                .foregroundStyle(KRCDesign.neonCyan)
                        } else {
                            Text("GET READY")
                            Text("Your 3-2-1 is next")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(KRCDesign.mutedText)
                        }
                    case .go:
                        Text("GET READY")
                    case .offlineFallback:
                        Text("SERVER UNAVAILABLE")
                        Text("Continuing in Solo — CPU grid, no lobby")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(KRCDesign.mutedText)
                    default:
                        Text(online.statusLine)
                    }
                }
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                if !online.lobbyPlayers.isEmpty {
                    Text(online.lobbyPlayers.map(\.name).joined(separator: " · "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                ProgressView()
                    .tint(KRCDesign.neonCyan)
            }
            .padding(28)
        }
    }

    private var courierJobPicker: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(session.engine.courierNightPremium ? "NIGHT DISPATCH" : "DISPATCH BOARD")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(KRCDesign.gold)
                Text(progress.courierRankSubtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                ForEach(session.engine.courierJobOffers) { offer in
                    Button {
                        session.engine.selectCourierOffer(id: offer.id)
                        KRCUISounds.playClick()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(offer.title)
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(offer.detail)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineLimit(2)
                            }
                            Spacer()
                            Text("+\(offer.payout)")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(KRCDesign.gold)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.55))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(KRCDesign.neonCyan.opacity(0.45), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(maxWidth: 420)
        }
        .allowsHitTesting(true)
    }

    private func startLightsOverlay(_ light: Int) -> some View {
        let label = light == 0 ? "GO!" : "\(light)"
        let color = light == 0 ? KRCDesign.gold : Color.white
        return VStack(spacing: 6) {
            Text(label)
                .font(.system(size: light == 0 ? 72 : 88, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .shadow(color: .black.opacity(0.85), radius: 10)
                .shadow(color: color.opacity(0.45), radius: 16)
                .scaleEffect(light == 0 ? 1.08 : 1)
            if light > 0 {
                Text("GRID")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: light)
    }

    private var raceOverlay: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width
            let topInset = geo.safeAreaInsets.top
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        Spacer(minLength: 0)
                        if session.engine.startLight < 0 {
                            RearViewMirrorView(engine: session.engine, portrait: portrait)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, max(topInset - 4, 0))
                    .padding(.bottom, 2)
                    raceHUD(portrait: portrait, topInset: 0)
                    Spacer(minLength: 0)
                    if !portrait && !useDPadControls {
                        touchControls(portrait: false)
                    }
                }
                if portrait || useDPadControls {
                    touchControls(portrait: portrait)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                        .zIndex(10)
                        .allowsHitTesting(true)
                    if ControlPreferences.scheme == .wheel {
                        SteeringWheelControl(input: session.input)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .ignoresSafeArea()
                    }
                }
                if VehicleDrivingPreferences.isManualTransmission {
                    TransmissionShiftControls(
                        input: session.input,
                        portrait: portrait,
                        shiftZone: session.engine.isShiftZone()
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                    .zIndex(11)
                    .allowsHitTesting(true)
                }
                if session.engine.isCourierRun(),
                   session.engine.courierAwaitingJobChoice,
                   !session.engine.courierCarrying,
                   session.engine.courierCargoHeld == 0 {
                    courierJobPicker
                        .zIndex(40)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            if session.engine.startLight >= 0 {
                startLightsOverlay(session.engine.startLight)
                    .zIndex(50)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if paused {
                KRCDesign.PauseMenuOverlay(
                    onResume: {
                        paused = false
                        session.engine.setPaused(false)
                    },
                    onMainMenu: {
                        paused = false
                        session.engine.setPaused(true)
                        flow.openMainMenu()
                    },
                    onFlashback: {
                        if session.engine.performFlashback() {
                            paused = false
                            session.engine.setPaused(false)
                        }
                    },
                    flashbackAvailable: session.engine.flashbackAvailable()
                )
            }
        }
        .overlay {
            if showTutorial && raceVisualReady && !paused {
                tutorialOverlay
            }
        }
        .overlay(alignment: .top) {
            #if DEBUG
            let skipCoach = KRCDebugUI.isQALaunch
            #else
            let skipCoach = false
            #endif
            if !KRCTutorial.hasCompletedGuidedRace && !skipCoach && raceVisualReady && !paused && !showTutorial {
                guidedCoachBanner
            }
        }
    }

    private var guidedCoachBanner: some View {
        let step = KRCTutorial.currentGuidedStep
        return TimelineView(.animation(minimumInterval: 0.25)) { _ in
            let _ = advanceGuidedIfNeeded()
            VStack(spacing: 4) {
                Text("COACH · \(step.title)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(KRCDesign.gold)
                Text(step.tip)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.62))
                    .overlay(Capsule().strokeBorder(KRCDesign.gold.opacity(0.35), lineWidth: 1))
            )
            .padding(.top, 8)
        }
    }

    private func advanceGuidedIfNeeded() {
        guard !KRCTutorial.hasCompletedGuidedRace else { return }
        let step = KRCTutorial.currentGuidedStep
        let speed = session.engine.speedKmh()
        let drift = session.engine.driftMultiplierDisplay()
        let nitro = session.engine.nitroMeter()
        switch step {
        case .steer:
            if speed > 15 { KRCTutorial.advanceGuidedStep() }
        case .gas:
            if speed > 55 { KRCTutorial.advanceGuidedStep() }
        case .drift:
            if drift > 1.15 { KRCTutorial.advanceGuidedStep() }
        case .nitro:
            if nitro < 0.92 || speed > 110 { KRCTutorial.advanceGuidedStep() }
        case .finish:
            break
        }
    }

    private var tutorialOverlay: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Text("FIRST RACE COACH")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(KRCDesign.gold)
                Text("60-second primer — then the coach tips stay on-screen.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                ForEach(KRCTutorial.controlsTipLines, id: \.self) { line in
                    Text("· \(line)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                Button {
                    KRCTutorial.hasShownControlsTip = true
                    showTutorial = false
                } label: {
                    Text("LET'S RACE")
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(KRCDesign.gold))
                        .foregroundStyle(.black)
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(KRCDesign.gold.opacity(0.35), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func raceHUD(portrait: Bool, topInset: CGFloat = 0) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
            let interceptor = session.engine.isHotPursuitInterceptor()
            let courier = session.engine.isCourierRun()
            let catchLeft = Int(session.engine.catchTimeDisplay().rounded(.down))
            ModernRaceHUD(
                portrait: portrait,
                venue: flow.venueDisplayName(),
                mode: flow.activeGameMode.displayTitle,
                speedKmh: session.engine.speedKmh(),
                rpm: session.engine.rpmNormalized(),
                gear: session.engine.gearDisplay(),
                lap: interceptor
                    ? session.engine.pursuitBusts
                    : (courier ? session.engine.courierDeliveries : session.engine.displayLapIndex),
                lapGoal: interceptor
                    ? session.engine.pursuitBustGoal
                    : (courier ? session.engine.courierGoal : session.engine.lapGoal),
                raceTime: (interceptor || courier)
                    ? String(format: "%d:%02d", catchLeft / 60, catchLeft % 60)
                    : formatHUDTime(session.engine.elapsedTime),
                position: interceptor
                    ? session.engine.pursuitBusts
                    : (courier ? session.engine.courierDeliveries : session.engine.racePosition),
                racerCount: interceptor
                    ? session.engine.pursuitBustGoal
                    : (courier ? session.engine.courierGoal : session.engine.racerCount),
                showPosition: interceptor || courier || session.engine.racerCount > 1,
                nitro: session.engine.nitroMeter(),
                heat: session.engine.heatMeter(),
                showHeat: interceptor || flow.activeGameMode == .endless,
                heatLabel: interceptor ? "LOCK" : "HEAT",
                damage: session.engine.damageMeter(),
                showDamage: session.engine.damageMeter() > 0.02,
                driftMultiplier: session.engine.driftMultiplierDisplay(),
                driftScore: session.engine.driftScore,
                progress: session.engine.trackProgressNormalized(),
                crystals: session.engine.arcadeCrystals,
                crystalTotal: session.engine.arcadeCrystalTotal,
                objectiveLabel: session.engine.arcadeObjective,
                objectiveProgress: session.engine.arcadeObjectiveProgress,
                objectiveComplete: session.engine.arcadeObjectiveComplete,
                arcadeToast: session.engine.arcadeToast,
                draftActive: session.engine.arcadeDraftActive,
                driftZoneActive: session.engine.arcadeDriftZoneActive,
                manualTransmission: VehicleDrivingPreferences.isManualTransmission,
                shiftZone: session.engine.isShiftZone(),
                shiftNotice: session.engine.shiftNotice(),
                reverseGear: session.engine.isReversingGear(),
                positionPrefix: interceptor ? "BUSTS" : (courier ? "PKG" : nil),
                onlineStatus: KRCPlayerProfile.onlinePlayEnabled ? online.statusLine : nil,
                wrongWay: session.engine.wrongWayActive,
                courierMode: courier,
                courierBearing: session.engine.courierBearing,
                courierDistance: session.engine.courierDistance,
                courierDwell: session.engine.courierDwell,
                courierInZone: session.engine.courierInZone,
                courierCarrying: session.engine.courierCarrying,
                courierEarned: session.engine.courierEarned,
                courierNextPayout: session.engine.courierNextPayout,
                courierStreak: session.engine.courierStreak,
                courierUrgency: session.engine.courierUrgency,
                courierPackageKind: session.engine.courierPackageKind.title,
                courierRivalThreat: session.engine.courierRivalThreat,
                courierCargoHeld: session.engine.courierCargoHeld,
                courierCargoCapacity: session.engine.courierCargoCapacity,
                courierNightPremium: session.engine.courierNightPremium,
                decluttered: KRCTutorial.shouldDeclutterHUD
            ) {
                AnyView(Group {
                    if !paused {
                        HStack(spacing: 8) {
                            if GameCenterService.shared.hasActiveRaceMatch {
                                kidEmoteChip("👋", "WAVE", .wave)
                                kidEmoteChip("👍", "NICE", .nice)
                            }
                            pauseButton
                        }
                    }
                })
            }
        }
        .padding(.horizontal, portrait ? 10 : 12)
        .padding(.top, max(topInset + 4, portrait ? 6 : 8))
        // Keep HUD as overlay chips — don't stretch a glass panel across the road.
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .allowsHitTesting(true)
    }

    private func kidEmoteChip(_ glyph: String, _ title: String, _ emote: KidRaceEmote) -> some View {
        Button {
            let now = Date().timeIntervalSinceReferenceDate
            guard now - lastKidEmoteAt > 1.15 else { return }
            lastKidEmoteAt = now
            GameCenterService.shared.broadcastKidEmote(emote)
            KRCUISounds.playClick()
        } label: {
            VStack(spacing: 1) {
                Text(glyph)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 8, weight: .black, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().strokeBorder(KRCDesign.gold.opacity(0.45), lineWidth: 1))
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var pauseButton: some View {
        Button {
            paused.toggle()
            if paused {
                session.engine.setPaused(true)
            } else {
                beginRaceIfReady()
            }
        } label: {
            Text("PAUSE")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(KRCDesign.neonCyan.opacity(0.5), lineWidth: 1)
                        )
                }
        }
        .foregroundStyle(.white)
        .accessibilityIdentifier("race.pause")
    }

    @ViewBuilder
    private func touchControls(portrait: Bool) -> some View {
        let layout = portrait ? RaceControlLayout.portrait : RaceControlLayout.landscape
        if useDPadControls {
            DPadRaceControls(input: session.input, layout: layout)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(true)
        } else {
            let cluster = RacePedalCluster(
                input: session.input,
                tiltSteer: useTiltSteer,
                layout: layout
            )
            // No fixed frosted dock height — pedals sit in a clear host (see RacePedalCluster).
            cluster
                .frame(maxWidth: .infinity)
                .padding(.horizontal, portrait ? 0 : 6)
                .padding(.bottom, portrait ? 0 : 2)
        }
    }
}

// MARK: - Finish

struct RaceFinishedScreen: View {
    @ObservedObject var flow: GameFlowState
    @ObservedObject var progress: PlayerProgressStore
    let lastTime: TimeInterval
    @ObservedObject private var online = KRCOnlineService.shared
    @State private var appear = false

    private var finishGrade: String {
        if let g = flow.lastRaceReward?.courierGrade, !g.isEmpty { return g }
        let pos = max(1, flow.lastFinishPlace)
        switch pos {
        case 1: return "S"
        case 2: return "A"
        case 3: return "B"
        case 4: return "C"
        default: return "D"
        }
    }

    private var nextUnlockTeaser: String? {
        guard !progress.careerComplete,
              let mission = progress.currentCareerMission else { return nil }
        return "Next career: \(mission.title)"
    }

    var body: some View {
        ZStack {
            KRCDesign.MenuBackdrop()
            Color.black.opacity(0.62).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        if flow.lastRaceReward?.celebratePodium == true {
                            KidPodiumBurst(active: appear)
                        }
                        Image(systemName: flow.activeGameMode == .courier
                              ? "shippingbox.fill"
                              : (flow.lastFinishPlace == 1 ? "trophy.fill" : "flag.checkered.circle.fill"))
                            .font(.system(size: 52))
                            .foregroundStyle(KRCDesign.gold)
                            .shadow(color: KRCDesign.gold.opacity(0.45), radius: 12)
                            .scaleEffect(appear ? 1 : 0.55)
                            .opacity(appear ? 1 : 0)
                    }
                    .frame(height: 72)
                    KRCDesign.ScreenHeader(
                        title: flow.lastFinishPlace == 1 ? "YOU WIN" : "FINISH",
                        subtitle: flow.venueDisplayName()
                    )
                    KRCDesign.ModeBadge(text: flow.activeGameMode.displayTitle)
                    Text(finishGrade)
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(KRCDesign.gold)
                        .shadow(color: KRCDesign.gold.opacity(0.35), radius: 10)
                        .opacity(appear ? 1 : 0)
                    KRCDesign.HighlightStatCard(
                        label: flow.activeGameMode == .courier ? "ROUTE TIME" : "LAP TIME",
                        value: formatRaceTime(lastTime)
                    )
                    .padding(.horizontal, 24)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 18)
                    if let reward = flow.lastRaceReward {
                        KRCDesign.Panel {
                            VStack(spacing: 8) {
                                KRCDesign.SectionLabel(text: "REWARDS")
                                Text("+\(reward.total) CR")
                                    .font(.system(size: 30, weight: .black, design: .rounded))
                                    .foregroundStyle(KRCDesign.gold)
                                VStack(spacing: 4) {
                                    rewardLine(
                                        flow.activeGameMode == .courier ? "Shift pay" : "Race purse",
                                        reward.base
                                    )
                                    if reward.position > 0 { rewardLine("Position", reward.position) }
                                    if reward.heatBonus > 0 {
                                        rewardLine(
                                            flow.activeGameMode == .policeChase
                                                ? "Busts"
                                                : (flow.activeGameMode == .courier ? "Deliveries" : "Heat survival"),
                                            reward.heatBonus
                                        )
                                    }
                                    if reward.daily > 0 { rewardLine("Daily challenge", reward.daily) }
                                    if reward.ticketFines > 0 {
                                        rewardLine("Speeding tickets", reward.ticketFines)
                                    }
                                    if reward.arcade > 0 {
                                        rewardLine(
                                            flow.activeGameMode == .courier ? "Courier bonus" : "Arcade bonus",
                                            reward.arcade
                                        )
                                    }
                                    if reward.damagePenalty > 0 {
                                        rewardLine("Damage", -reward.damagePenalty)
                                    }
                                    if reward.career > 0 { rewardLine("Career mission", reward.career) }
                                }
                                if !reward.ticketLines.isEmpty {
                                    VStack(alignment: .leading, spacing: 3) {
                                        KRCDesign.SectionLabel(text: "CITATIONS")
                                        ForEach(reward.ticketLines, id: \.self) { line in
                                            Text(line)
                                                .font(.caption2.weight(.semibold).monospacedDigit())
                                                .foregroundStyle(.white.opacity(0.88))
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 6)
                                }
                                if let unlocked = reward.unlockedCarName {
                                    Text("Unlocked \(unlocked)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(KRCDesign.neonCyan)
                                        .padding(.top, 4)
                                }
                                if let symbol = reward.stickerSymbol, let title = reward.stickerTitle {
                                    HStack(spacing: 8) {
                                        Image(systemName: symbol)
                                            .foregroundStyle(KRCDesign.gold)
                                        Text(reward.lootHeadline ?? "New sticker: \(title)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.top, 6)
                                }
                                if let ghost = reward.houseGhostLine {
                                    Text(ghost)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(KRCDesign.neonCyan)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 2)
                                }
                                HStack(spacing: 10) {
                                    Label("\(progress.lifetimeCrystals)", systemImage: "diamond.fill")
                                    Label("\(progress.trophyWins)", systemImage: "trophy.fill")
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(KRCDesign.gold)
                                .padding(.top, 4)
                                if !progress.trophyStickers.isEmpty {
                                    HStack(spacing: 6) {
                                        ForEach(progress.trophyStickers) { sticker in
                                            Image(systemName: sticker.symbolName)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color(uiColor: sticker.tint))
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                                if let teaser = nextUnlockTeaser {
                                    Text(teaser)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .padding(.top, 2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24)
                    }
                    if KRCPlayerProfile.onlinePlayEnabled {
                        if let live = online.lastLiveResult, live.humanCount > 1 {
                            KRCDesign.Panel {
                                VStack(spacing: 6) {
                                    KRCDesign.SectionLabel(text: "LIVE LOBBY")
                                    Text("P\(live.humanPosition)/\(live.humanCount)")
                                        .font(.system(size: 32, weight: .black, design: .rounded))
                                        .foregroundStyle(KRCDesign.neonCyan)
                                    Text(live.players.map(\.name).joined(separator: " · "))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.75))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 24)
                        }
                        if let rank = online.lastSubmittedRank {
                            KRCDesign.Panel {
                                VStack(spacing: 6) {
                                    KRCDesign.SectionLabel(text: "GLOBAL TRACK RANK")
                                    Text("P\(rank)")
                                        .font(.system(size: 32, weight: .black, design: .rounded))
                                        .foregroundStyle(KRCDesign.gold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 24)
                        }
                        if !online.scoreboardMessage.isEmpty {
                            Text(online.scoreboardMessage)
                                .font(.caption)
                                .foregroundStyle(KRCDesign.mutedText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                        }
                        GlobalLeaderboardView()
                            .padding(.horizontal, 20)
                    }
                    if GameCenterService.shared.canRematchFriends {
                        KRCDesign.PrimaryButton(title: "RACE FRIENDS AGAIN") {
                            flow.beginQuickRace()
                        }
                        .padding(.horizontal, 32)
                    }
                    if flow.activeGameMode == .championshipSerie,
                       flow.champRoundsCompleted < GameCatalog.activeChampionshipRounds.count {
                        let next = GameCatalog.activeChampionshipRounds[flow.champRoundsCompleted]
                        KRCDesign.Panel {
                            VStack(spacing: 8) {
                                KRCDesign.SectionLabel(text: "NEXT ROUND")
                                Text("\(next.name) · \(GameCatalog.activeTracks[next.trackIndex].name)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                Text("\(next.laps) laps")
                                    .font(.caption)
                                    .foregroundStyle(KRCDesign.mutedText)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 24)
                        KRCDesign.PrimaryButton(title: "NEXT ROUND") {
                            flow.continueChampionship()
                        }
                        .padding(.horizontal, 32)
                    } else if !progress.careerComplete {
                        KRCDesign.PrimaryButton(title: "CONTINUE CAREER") {
                            flow.beginCareerMode(progress: progress)
                        }
                        .padding(.horizontal, 32)
                        KRCDesign.SecondaryButton(title: "MAIN MENU") {
                            flow.openMainMenu()
                        }
                        .padding(.top, 4)
                    } else if !GameCenterService.shared.canRematchFriends {
                        KRCDesign.PrimaryButton(title: "RACE AGAIN") {
                            flow.beginQuickRace()
                        }
                        .padding(.horizontal, 32)
                        KRCDesign.SecondaryButton(title: "MAIN MENU") {
                            flow.openMainMenu()
                        }
                        .padding(.top, 4)
                    } else {
                        KRCDesign.SecondaryButton(title: "MAIN MENU") {
                            flow.openMainMenu()
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            KRCTutorial.markGuidedComplete()
            KRCMusicDirector.shared.play(.victory)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                appear = true
            }
            if KRCAudioPreferences.hapticsEnabled {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func rewardLine(_ label: String, _ amount: Int64) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(KRCDesign.mutedText)
            Spacer()
            Text(amount >= 0 ? "+\(amount)" : "\(amount)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(amount >= 0 ? .white.opacity(0.9) : Color.red.opacity(0.85))
        }
    }
}

struct ChampCompleteScreen: View {
    @ObservedObject var flow: GameFlowState
    let totalTime: TimeInterval

    var body: some View {
        ZStack {
            KRCDesign.MenuBackdrop()
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer(minLength: 24)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [KRCDesign.gold, KRCDesign.hotOrange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: KRCDesign.gold.opacity(0.55), radius: 16)
                KRCDesign.ScreenHeader(
                    title: "CHAMPIONSHIP COMPLETE",
                    subtitle: "Total time · \(GameCatalog.activeChampionshipRounds.count) rounds"
                )
                KRCDesign.HighlightStatCard(
                    label: "SERIES TIME",
                    value: formatRaceTime(totalTime),
                    accent: KRCDesign.neonCyan
                )
                .padding(.horizontal, 28)
                Spacer()
                KRCDesign.PrimaryButton(title: "MAIN MENU") {
                    flow.openMainMenu()
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 28)
            }
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Weekly contracts

private struct WeeklyContractsSheet: View {
    @ObservedObject var progress: PlayerProgressStore
    let onDismiss: () -> Void
    @State private var claimToast: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(progress.weeklySubtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KRCDesign.mutedText)
                        ForEach(WeeklyEvents.contracts(forWeekKey: progress.weeklyKey)) { contract in
                            let prog = progress.weeklyProgress[contract.id, default: 0]
                            let claimed = progress.weeklyClaimed.contains(contract.id)
                            let ready = prog >= contract.target
                            KRCDesign.Panel {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(contract.title)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.white)
                                    Text(contract.blurb)
                                        .font(.caption)
                                        .foregroundStyle(KRCDesign.mutedText)
                                    ProgressView(value: Double(min(prog, contract.target)), total: Double(contract.target))
                                        .tint(KRCDesign.neonCyan)
                                    HStack {
                                        Text("\(min(prog, contract.target))/\(contract.target)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.white.opacity(0.85))
                                        Spacer()
                                        if claimed {
                                            Text("CLAIMED")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(KRCDesign.gold)
                                        } else if ready {
                                            Button("CLAIM +\(contract.rewardCredits)") {
                                                let got = progress.claimWeeklyContract(contract.id)
                                                claimToast = got > 0 ? "+\(got) CR" : nil
                                            }
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(KRCDesign.gold))
                                        } else {
                                            Text("+\(contract.rewardCredits) CR")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(KRCDesign.gold.opacity(0.7))
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        if let claimToast {
                            Text(claimToast)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(KRCDesign.neonCyan)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Weekly Contracts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
            .onAppear { progress.rollWeeklyIfNeeded() }
        }
        .preferredColorScheme(.dark)
    }
}

private struct KidTrophyAlbumSheet: View {
    @ObservedObject var progress: PlayerProgressStore
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            albumStat(icon: "diamond.fill", value: "\(progress.lifetimeCrystals)", label: "Crystals")
                            albumStat(icon: "trophy.fill", value: "\(progress.trophyWins)", label: "Trophies")
                            albumStat(icon: "star.fill", value: "\(progress.trophyStickers.count)", label: "Stickers")
                        }
                        KRCDesign.SectionLabel(text: "STICKERS")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                            ForEach(KidSticker.allCases) { sticker in
                                let count = progress.stickerCounts[sticker.rawValue] ?? 0
                                VStack(spacing: 6) {
                                    Image(systemName: sticker.symbolName)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(count > 0 ? Color(uiColor: sticker.tint) : .white.opacity(0.2))
                                    Text(sticker.title)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white.opacity(count > 0 ? 0.9 : 0.35))
                                    Text(count > 0 ? "×\(count)" : "—")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundStyle(KRCDesign.gold.opacity(count > 0 ? 1 : 0.3))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(count > 0 ? 0.08 : 0.04))
                                )
                            }
                        }
                        KRCDesign.SectionLabel(text: "RARE TOYS")
                        albumOwnedRow(KidToy.allCases.map { ($0.rawValue, $0.title, $0.symbolName, progress.ownsToy($0)) })
                        KRCDesign.SectionLabel(text: "PLATES")
                        albumOwnedRow(KidPlate.allCases.map { ($0.rawValue, $0.shortText, "rectangle.fill", progress.ownsPlate($0)) })
                        KRCDesign.SectionLabel(text: "HATS")
                        albumOwnedRow(KidHat.allCases.map { ($0.rawValue, $0.title, $0.symbolName, progress.ownsHat($0)) })
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Trophy Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func albumStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(KRCDesign.gold)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(KRCDesign.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func albumOwnedRow(_ items: [(String, String, String, Bool)]) -> some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.0) { item in
                VStack(spacing: 4) {
                    Image(systemName: item.2)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(item.3 ? KRCDesign.gold : .white.opacity(0.25))
                    Text(item.1)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(item.3 ? .white : .white.opacity(0.35))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Quick podium sparkle burst on the results screen.
private struct KidPodiumBurst: View {
    let active: Bool

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                Image(systemName: "star.fill")
                    .font(.system(size: CGFloat(8 + (i % 4) * 3), weight: .bold))
                    .foregroundStyle(i % 3 == 0 ? KRCDesign.gold : KRCDesign.neonCyan)
                    .offset(
                        x: active ? CGFloat((i % 5) * 18 - 36) : 0,
                        y: active ? CGFloat((i % 3) * 14 - 20) : 0
                    )
                    .opacity(active ? 0.9 : 0)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.62).delay(Double(i) * 0.03),
                        value: active
                    )
            }
        }
        .allowsHitTesting(false)
    }
}
