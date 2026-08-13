import SwiftUI

/// Navigation + session configuration for all arcade modes.
final class GameFlowState: ObservableObject {
    enum Screen: Equatable {
        case mainMenu
        case modeSelect
        case carSelect
        case trackSelect
        case racing
        case raceFinished(elapsed: TimeInterval)
        case champComplete(totalTime: TimeInterval)
    }

    struct RaceRewardSummary: Equatable {
        var base: Int64
        var position: Int64
        var heatBonus: Int64
        var daily: Int64
        var arcade: Int64
        var career: Int64
        var ticketFines: Int64
        var damagePenalty: Int64
        /// Actual purse credited (after floor), excluding career which is granted separately.
        var grantedPurse: Int64
        var ticketLines: [String]
        var unlockedCarName: String?
        var courierGrade: String?

        /// Total CR added to the wallet for this finish.
        var total: Int64 { grantedPurse + career }
    }

    @Published var screen: Screen = .mainMenu
    /// Where **Car Select → Back** returns (main menu vs mode picker).
    @Published var carSelectBackScreen: Screen = .mainMenu
    /// 0 = Casual, 1 = Pro, 2 = Elite (matches web garage).
    @Published var difficultyIndex: Int = 1
    /// Primary gameplay mode for the next session.
    @Published var activeGameMode: GameModeKind = .circuit
    /// Visual preset (toggle later from settings).
    @Published var nightRace: Bool = false
    /// True when this race advances the career ladder (even if mode is pursuit/ghost).
    @Published var careerSessionActive: Bool = false
    /// Last finish payout shown on the results screen.
    @Published var lastRaceReward: RaceRewardSummary?
    /// Finish place (1 = first) for grade display.
    @Published var lastFinishPlace: Int = 1
    /// True when the session was launched as Daily Challenge (for rewards + career win).
    @Published var dailyChallengeActive: Bool = false
    /// Selected Hot Pursuit campaign chapter index.
    @Published var pursuitChapterIndex: Int = 0
    /// Session flags from the active pursuit chapter.
    var pursuitRoadblocksEnabled: Bool = false
    var pursuitTimeLimitOverride: TimeInterval? = nil
    var pursuitSuspectCountOverride: Int? = nil

    /// Global procedural city (theme + seed → modular layout via `CityManager`).
    @Published var selectedCityTheme: CityThemeID = .sunsetStripBay
    /// Rolled when entering **Endless** — determines procedural variation for that run.
    var endlessRunSeed: UInt64 = 0xE15E15E15E15E15

    @Published var selectedCarIndex = 0
    @Published var selectedTrackIndex = 0
    @Published var lapCount = 3

    @Published var champRoundsCompleted = 0
    @Published var champAccumulatedTime: TimeInterval = 0

    func openModeSelect() {
        screen = .modeSelect
    }

    func openCarSelect(returningTo back: Screen) {
        carSelectBackScreen = back
        screen = .carSelect
    }

    /// Quick Race — same as web `garage.html?mode=quick`.
    func beginQuickRace() {
        beginCircuit()
    }

    /// Daily Challenge — seeded time trial. Track is deterministic per calendar day.
    func beginDailyChallenge(progress: PlayerProgressStore? = nil) {
        progress?.rollDailyIfNeeded()
        careerSessionActive = false
        dailyChallengeActive = true
        activeGameMode = .timeTrial
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = 3
        selectedCarIndex = 0
        let daySeed = PlayerProgressStore.todayDayKey()
        selectedTrackIndex = daySeed % GameCatalog.activeTracks.count
        syncLapsToSelectedTrack()
        openCarSelect(returningTo: .mainMenu)
    }

    func beginCircuit() {
        careerSessionActive = false
        dailyChallengeActive = false
        activeGameMode = .circuit
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = GameModeKind.circuit.defaultLaps()
        selectedCarIndex = 0
        selectedTrackIndex = 0
        syncLapsToSelectedTrack()
        openCarSelect(returningTo: .mainMenu)
    }

    func beginChampionshipSerie() {
        careerSessionActive = false
        dailyChallengeActive = false
        activeGameMode = .championshipSerie
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        applyChampionshipRoundSettings()
        selectedCarIndex = 0
        openCarSelect(returningTo: .mainMenu)
    }

    func beginPoliceChase(progress: PlayerProgressStore? = nil) {
        careerSessionActive = false
        dailyChallengeActive = false
        activeGameMode = .policeChase
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        let chapterIdx = min(
            progress?.pursuitChapterUnlocked ?? pursuitChapterIndex,
            PursuitCampaign.chapters.count - 1
        )
        pursuitChapterIndex = chapterIdx
        let chapter = PursuitCampaign.chapter(at: chapterIdx)
        selectedTrackIndex = min(chapter.trackIndex, GameCatalog.activeTracks.count - 1)
        nightRace = chapter.nightPreferred
        lapCount = GameModeKind.policeChase.defaultLaps()
        pursuitRoadblocksEnabled = chapter.roadblocks
        pursuitTimeLimitOverride = chapter.timeLimitSeconds
        pursuitSuspectCountOverride = chapter.suspectCount
        if let progress, progress.unlockedCarIds.contains("police"),
           let policeIdx = GameCatalog.cars.firstIndex(where: { $0.id == "police" }) {
            selectedCarIndex = policeIdx
        } else if let progress,
                  let starterIdx = GameCatalog.cars.firstIndex(where: { progress.unlockedCarIds.contains($0.id) }) {
            selectedCarIndex = starterIdx
        } else {
            selectedCarIndex = 0
        }
        openCarSelect(returningTo: .mainMenu)
    }

    func beginEndless() {
        careerSessionActive = false
        dailyChallengeActive = false
        activeGameMode = .endless
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = GameModeKind.endless.defaultLaps()
        selectedCarIndex = 0
        endlessRunSeed = UInt64.random(in: UInt64.min ... UInt64.max)
        openCarSelect(returningTo: .modeSelect)
    }

    func beginTimeTrial() {
        careerSessionActive = false
        dailyChallengeActive = false
        activeGameMode = .timeTrial
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = GameModeKind.timeTrial.defaultLaps()
        selectedCarIndex = 0
        selectedTrackIndex = 0
        syncLapsToSelectedTrack()
        openCarSelect(returningTo: .modeSelect)
    }

    func beginGhostDuel() {
        careerSessionActive = false
        dailyChallengeActive = false
        activeGameMode = .ghostDuel
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = GameModeKind.ghostDuel.defaultLaps()
        selectedCarIndex = 0
        openCarSelect(returningTo: .modeSelect)
    }

    /// Compatibility alias — prefer `beginGhostDuel()`.
    func beginGhostDuelPlaceholder() {
        beginGhostDuel()
    }

    func beginCourier(progress: PlayerProgressStore? = nil) {
        careerSessionActive = false
        dailyChallengeActive = false
        activeGameMode = .courier
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = GameModeKind.courier.defaultLaps()
        selectedCarIndex = 0
        selectedTrackIndex = 0
        // Night license ranks get night suggested for premium rates.
        if let progress, progress.courierRank.nightLicense {
            nightRace = true
        }
        syncLapsToSelectedTrack()
        openCarSelect(returningTo: .modeSelect)
    }

    func beginCareerMode(progress: PlayerProgressStore) {
        careerSessionActive = true
        dailyChallengeActive = false
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        selectedCarIndex = 0
        pursuitRoadblocksEnabled = false
        pursuitTimeLimitOverride = nil
        pursuitSuspectCountOverride = nil
        guard let mission = progress.currentCareerMission else {
            activeGameMode = .career
            lapCount = GameModeKind.career.defaultLaps()
            selectedTrackIndex = min(5, GameCatalog.activeTracks.count - 1)
            nightRace = false
            openCarSelect(returningTo: .mainMenu)
            return
        }
        selectedTrackIndex = min(mission.trackIndex, GameCatalog.activeTracks.count - 1)
        lapCount = mission.laps
        nightRace = mission.nightPreferred
        if mission.id == "c09-daily" {
            dailyChallengeActive = true
            let daySeed = PlayerProgressStore.todayDayKey()
            selectedTrackIndex = daySeed % GameCatalog.activeTracks.count
            syncLapsToSelectedTrack()
        }
        if let override = mission.modeOverride {
            activeGameMode = override
            if override == .policeChase {
                // Career pursuit missions unlock the interceptor as part of the ladder.
                progress.grantCar(id: "police")
                if let policeIdx = GameCatalog.cars.firstIndex(where: { $0.id == "police" }) {
                    selectedCarIndex = policeIdx
                }
                pursuitRoadblocksEnabled = true
                pursuitSuspectCountOverride = 4
                pursuitTimeLimitOverride = 180
            }
        } else {
            activeGameMode = .career
        }
        openCarSelect(returningTo: .mainMenu)
    }

    func syncLapsToSelectedTrack() {
        let idx = min(max(selectedTrackIndex, 0), GameCatalog.activeTracks.count - 1)
        lapCount = GameCatalog.activeTracks[idx].lapsDefault
    }

    func applyChampionshipRoundSettings() {
        let round = min(champRoundsCompleted, GameCatalog.activeChampionshipRounds.count - 1)
        let spec = GameCatalog.activeChampionshipRounds[round]
        selectedTrackIndex = min(spec.trackIndex, GameCatalog.activeTracks.count - 1)
        lapCount = spec.laps
    }

    var difficultyLabel: String {
        switch difficultyIndex {
        case 0: return "Casual"
        case 2: return "Elite"
        default: return "Pro"
        }
    }

    /// Grip / pressure multiplier for solo play (mirrors web AI scaling feel).
    func difficultyGripMul() -> Float {
        switch difficultyIndex {
        case 0: return 1.04
        case 2: return 0.92
        default: return 1.0
        }
    }

    func beginCareerPlaceholder(progress: PlayerProgressStore) {
        beginCareerMode(progress: progress)
    }

    func openMainMenu() {
        screen = .mainMenu
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        careerSessionActive = false
    }

    func effectiveLapCount() -> Int {
        if careerSessionActive {
            return max(1, lapCount)
        }
        if activeGameMode == .championshipSerie {
            let round = min(champRoundsCompleted, GameCatalog.activeChampionshipRounds.count - 1)
            return GameCatalog.activeChampionshipRounds[round].laps
        }
        if activeGameMode == .circuit || activeGameMode == .timeTrial || activeGameMode == .career {
            return lapCount
        }
        return activeGameMode.defaultLaps()
    }

    func trackIndexForCurrentRace() -> Int {
        if activeGameMode == .championshipSerie {
            let round = min(champRoundsCompleted, GameCatalog.activeChampionshipRounds.count - 1)
            return min(GameCatalog.activeChampionshipRounds[round].trackIndex, GameCatalog.activeTracks.count - 1)
        }
        return min(max(selectedTrackIndex, 0), GameCatalog.activeTracks.count - 1)
    }

    func currentTrack() -> TrackChoice {
        GameCatalog.activeTracks[trackIndexForCurrentRace()]
    }

    func currentChampionshipRound() -> ChampionshipRound? {
        guard activeGameMode == .championshipSerie else { return nil }
        let round = min(champRoundsCompleted, GameCatalog.activeChampionshipRounds.count - 1)
        return GameCatalog.activeChampionshipRounds[round]
    }

    func registerRaceFinish(
        segmentTime: TimeInterval,
        driftScore: Int64,
        arcadeBonusCredits: Int64 = 0,
        position: Int = 1,
        racerCount: Int = 1,
        heat: Float = 0,
        damage: Float = 0,
        pursuitBusts: Int = 0,
        ticketFines: Int64 = 0,
        ticketLines: [String] = [],
        crystalsCollected: Int = 0,
        courierGrade: String? = nil,
        progress: PlayerProgressStore
    ) {
        let base = segmentTime.msScaledCredits + driftScore / 40
        let field = max(1, racerCount)
        let place = min(max(1, position), field)
        var positionBonus: Int64
        var heatBonus: Int64
        if activeGameMode == .policeChase {
            positionBonus = 0
            heatBonus = Int64(pursuitBusts) * 140 + (pursuitBusts >= 4 ? 220 : 0)
            let chapter = PursuitCampaign.chapter(at: pursuitChapterIndex)
            heatBonus += chapter.rewardBonus
            if pursuitBusts >= max(1, pursuitSuspectCountOverride ?? 4) {
                progress.unlockNextPursuitChapter()
            }
        } else if activeGameMode == .courier {
            positionBonus = 0
            heatBonus = Int64(pursuitBusts) * 80
        } else {
            positionBonus = Int64(max(0, (field - place + 1) * 120))
            heatBonus = activeGameMode.enablesPolice
                ? Int64(max(0, (1 - heat) * 280))
                : 0
        }
        let fines = activeGameMode == .policeChase ? ticketFines : 0
        let damagePenalty = Int64(damage * 180)

        // Daily bonus is included in the race purse only (do not also mutate credits inside registerDaily…).
        let dailyBonus: Int64 = dailyChallengeActive
            ? progress.registerDailyChallengeFinish(time: segmentTime)
            : 0

        let rawPurse = base + positionBonus + heatBonus + dailyBonus + arcadeBonusCredits + fines - damagePenalty
        let racePurse = max(80, rawPurse)

        var careerAward: Int64 = 0
        var unlockedName: String?
        if careerSessionActive, !progress.careerComplete, let mission = progress.currentCareerMission {
            let win = CareerMissions.meetsWin(
                mission,
                position: place,
                busts: pursuitBusts,
                driftScore: driftScore,
                dailyJustCompleted: dailyChallengeActive && progress.dailyCompletedToday
            )
            if win {
                let result = progress.completeCareerMission()
                careerAward = result.credits
                if let carId = result.unlockedCarId,
                   let car = GameCatalog.cars.first(where: { $0.id == carId }) {
                    unlockedName = car.name
                }
            }
        }

        if activeGameMode == .courier {
            if let van = progress.registerCourierShift(deliveries: pursuitBusts) {
                unlockedName = unlockedName ?? van
            }
        }

        progress.creditsMutation(racePurse)
        progress.noteWeeklyProgress(
            racesFinished: 1,
            crystals: crystalsCollected,
            busts: pursuitBusts,
            drift: Int(min(driftScore, 50_000)),
            podium: place <= 3 && activeGameMode != .policeChase && activeGameMode != .courier
        )
        lastRaceReward = RaceRewardSummary(
            base: base,
            position: positionBonus,
            heatBonus: heatBonus,
            daily: dailyBonus,
            arcade: arcadeBonusCredits,
            career: careerAward,
            ticketFines: fines,
            damagePenalty: damagePenalty,
            grantedPurse: racePurse,
            ticketLines: activeGameMode == .policeChase ? ticketLines : [],
            unlockedCarName: unlockedName,
            courierGrade: activeGameMode == .courier ? courierGrade : nil
        )
        lastFinishPlace = place

        let willCompleteChampionship = activeGameMode == .championshipSerie
            && champRoundsCompleted + 1 >= GameCatalog.activeChampionshipRounds.count

        Task { @MainActor in
            GameCenterService.shared.handleRaceFinished(
                segmentTime: segmentTime,
                driftScore: driftScore,
                championshipJustCompleted: willCompleteChampionship
            )
        }

        if activeGameMode == .championshipSerie {
            champRoundsCompleted += 1
            champAccumulatedTime += segmentTime
            if champRoundsCompleted >= GameCatalog.activeChampionshipRounds.count {
                screen = .champComplete(totalTime: champAccumulatedTime)
            } else {
                applyChampionshipRoundSettings()
                screen = .raceFinished(elapsed: segmentTime)
            }
        } else {
            screen = .raceFinished(elapsed: segmentTime)
        }
        careerSessionActive = false
        dailyChallengeActive = false
        pursuitRoadblocksEnabled = false
        pursuitTimeLimitOverride = nil
        pursuitSuspectCountOverride = nil
        KRCAppStorePolish.noteRaceFinished(position: place)
    }

    func continueChampionship() {
        applyChampionshipRoundSettings()
        preloadRaceEnvironment { [weak self] in
            self?.screen = .racing
        }
    }

    /// City layout for the upcoming or active race (championship rounds use locked presets).
    func cityForCurrentRace() -> CityRuntimeConfig {
        if activeGameMode == .championshipSerie {
            return CityManager.shared.resolveChampionship(round: champRoundsCompleted)
        }
        let catalogIdx: Int? = activeGameMode == .endless ? nil : trackIndexForCurrentRace()
        return CityManager.shared.resolve(
            theme: effectiveCityTheme(),
            seed: effectiveCitySeed(),
            catalogTrackIndex: catalogIdx
        )
    }

    func environmentCacheKey() -> String {
        RaceEnvironmentPreloader.cacheKey(city: cityForCurrentRace(), nightOverride: nightRace)
    }

    /// Prebuild track + city and warm shaders before showing the race scene.
    func preloadRaceEnvironment(completion: (() -> Void)? = nil) {
        RaceEnvironmentPreloader.ensureReady(
            city: cityForCurrentRace(),
            nightOverride: nightRace,
            completion: completion ?? {}
        )
    }

    /// Whether track picker should appear before racing.
    func needsTrackSelect() -> Bool {
        activeGameMode == .circuit || activeGameMode == .timeTrial
    }

    #if DEBUG
    /// Simulator / CI shortcuts: `simctl launch … -qaRace`, `-qaPolice`, `-qaTrack`, `-qaModes`.
    func applyDebugLaunchRouteIfNeeded(progress: PlayerProgressStore) {
        let args = ProcessInfo.processInfo.arguments
        let qaTrackIndex = args.first(where: { $0.hasPrefix("-qaTrackIndex=") })
            .flatMap { $0.split(separator: "=").last.flatMap { Int($0) } }

        if args.contains("-qaRace") || qaTrackIndex != nil {
            beginQuickRace()
            if args.contains("-qaNight") {
                nightRace = true
            }
            if let num = qaTrackIndex {
                selectedTrackIndex = min(max(num, 0), GameCatalog.activeTracks.count - 1)
                let profile = EnvironmentTrackProfile.from(catalogTrackIndex: selectedTrackIndex)
                selectedCityTheme = profile.suggestedCityTheme
                syncLapsToSelectedTrack()
            }
            screen = .racing
            return
        }
        if args.contains("-qaTrack") {
            beginQuickRace()
            screen = .trackSelect
            return
        }
        if args.contains("-qaPolice") {
            beginPoliceChase()
            screen = .racing
            return
        }
        if args.contains("-qaEndless") {
            beginEndless()
            screen = .racing
            return
        }
        if args.contains("-qaDaily") {
            beginDailyChallenge()
            screen = .racing
            return
        }
        if args.contains("-qaChamp") {
            beginChampionshipSerie()
            screen = .racing
            return
        }
        if args.contains("-qaCareer") {
            beginCareerMode(progress: progress)
            screen = .racing
            return
        }
        if args.contains("-qaModes") {
            screen = .modeSelect
            return
        }
        if args.contains("-qaGarage") {
            beginQuickRace()
            return
        }
        if args.contains("-qaGarageChamp") {
            beginChampionshipSerie()
            return
        }
        if args.contains("-qaGarageCareer") {
            beginCareerMode(progress: progress)
            return
        }
        if args.contains("-qaGarageDaily") {
            beginDailyChallenge()
            return
        }
        if args.contains("-qaGaragePolice") {
            beginPoliceChase()
            return
        }
        if args.contains("-qaGarageTimeTrial") {
            beginTimeTrial()
            carSelectBackScreen = .modeSelect
            return
        }
        if args.contains("-qaGarageEndless") {
            beginEndless()
            return
        }
        if args.contains("-qaGarageGhost") {
            beginGhostDuel()
            return
        }
        if args.contains("-qaFinished") {
            beginQuickRace()
            screen = .raceFinished(elapsed: 92.347)
            return
        }
        if args.contains("-qaChampComplete") {
            beginChampionshipSerie()
            champRoundsCompleted = GameCatalog.activeChampionshipRounds.count
            screen = .champComplete(totalTime: 512.891)
            return
        }
        if args.contains("-qaSettings") {
            KRCDebugUI.openSettingsOnMenu = true
            screen = .mainMenu
            return
        }
        if args.contains("-qaPrivacy") {
            KRCDebugUI.openPrivacyOnMenu = true
            screen = .mainMenu
            return
        }
        if args.contains("-qaTerms") {
            KRCDebugUI.openTermsOnMenu = true
            screen = .mainMenu
            return
        }
        if args.contains("-qaPaused") {
            beginQuickRace()
            KRCDebugUI.startRacePaused = true
            screen = .racing
            return
        }
        if args.contains("-qaGameCenter") {
            KRCDebugUI.showGameCenterAlertOnMenu = true
            screen = .mainMenu
            return
        }
    }
    #endif

    func effectiveCityTheme() -> CityThemeID {
        if activeGameMode == .championshipSerie {
            return CityThemeCatalog.championshipTheme(round: champRoundsCompleted)
        }
        return selectedCityTheme
    }

    func effectiveCitySeed() -> UInt64 {
        switch activeGameMode {
        case .endless:
            return endlessRunSeed
        case .championshipSerie:
            return CityThemeCatalog.championshipSeed(round: champRoundsCompleted)
        default:
            return SeededRandom.layoutSeed(
                theme: selectedCityTheme,
                trackIndex: trackIndexForCurrentRace(),
                lapCount: lapCount
            )
        }
    }

    func venueDisplayName() -> String {
        let track = currentTrack()
        let fullCity = effectiveCityTheme().displayName
        let cityLabel = fullCity
            .split(separator: ",")
            .first
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? fullCity
        if activeGameMode == .championshipSerie, let round = currentChampionshipRound() {
            return "\(round.name) · \(track.name)"
        }
        return "\(cityLabel) · \(track.name)"
    }
}

private extension TimeInterval {
    var msScaledCredits: Int64 {
        // Faster finishes pay more. ~90s ≈ 792 CR, ~120s ≈ 756 CR, long races floor at 150.
        Int64(max(150, 900 - self * 1.2))
    }
}
