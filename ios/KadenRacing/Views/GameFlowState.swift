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

    @Published var screen: Screen = .mainMenu
    /// Primary gameplay mode for the next session.
    @Published var activeGameMode: GameModeKind = .circuit
    /// Visual preset (toggle later from settings).
    @Published var nightRace: Bool = false

    /// Global procedural city (theme + seed → modular layout via `CityManager`).
    @Published var selectedCityTheme: CityThemeID = .sunsetStripBay
    /// Rolled when entering **Endless** — determines procedural variation for that run.
    var endlessRunSeed: UInt64 = 0xE15E15E15E15E15

    @Published var selectedCarIndex = 0
    @Published var selectedTrackIndex = 0
    @Published var lapCount = 5

    @Published var champRoundsCompleted = 0
    @Published var champAccumulatedTime: TimeInterval = 0

    func openModeSelect() {
        screen = .modeSelect
    }

    func beginCircuit() {
        activeGameMode = .circuit
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = GameModeKind.circuit.defaultLaps()
        selectedCarIndex = 0
        screen = .carSelect
    }

    func beginChampionshipSerie() {
        activeGameMode = .championshipSerie
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = GameCatalog.tracks[0].lapsDefault
        selectedCarIndex = 0
        screen = .carSelect
    }

    func beginPoliceChase() {
        activeGameMode = .policeChase
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = GameModeKind.policeChase.defaultLaps()
        selectedCarIndex = 0
        screen = .carSelect
    }

    func beginEndless() {
        activeGameMode = .endless
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = GameModeKind.endless.defaultLaps()
        selectedCarIndex = 0
        endlessRunSeed = UInt64.random(in: UInt64.min ... UInt64.max)
        screen = .carSelect
    }

    func beginTimeTrial() {
        activeGameMode = .timeTrial
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = GameModeKind.timeTrial.defaultLaps()
        selectedCarIndex = 0
        screen = .carSelect
    }

    func beginGhostDuelPlaceholder() {
        activeGameMode = .ghostDuel
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = GameModeKind.ghostDuel.defaultLaps()
        selectedCarIndex = 0
        screen = .carSelect
    }

    func beginCareerPlaceholder() {
        activeGameMode = .career
        champRoundsCompleted = 0
        champAccumulatedTime = 0
        lapCount = GameModeKind.career.defaultLaps()
        selectedCarIndex = 0
        screen = .carSelect
    }

    func openMainMenu() {
        screen = .mainMenu
        champRoundsCompleted = 0
        champAccumulatedTime = 0
    }

    func effectiveLapCount() -> Int {
        if activeGameMode == .championshipSerie {
            let idx = min(champRoundsCompleted, GameCatalog.tracks.count - 1)
            return GameCatalog.tracks[idx].lapsDefault
        }
        if activeGameMode == .circuit || activeGameMode == .timeTrial {
            return lapCount
        }
        return activeGameMode.defaultLaps()
    }

    func trackIndexForCurrentRace() -> Int {
        activeGameMode == .championshipSerie
            ? min(champRoundsCompleted, GameCatalog.tracks.count - 1)
            : selectedTrackIndex
    }

    func registerRaceFinish(segmentTime: TimeInterval, driftScore: Int64, progress: PlayerProgressStore) {
        progress.creditsMutation(segmentTime.msScaledCredits + driftScore / 40)
        GameCenterService.shared.submitLapTime(ms: Int64(segmentTime * 1000))
        GameCenterService.shared.submitDriftScore(driftScore)

        if activeGameMode == .championshipSerie {
            champRoundsCompleted += 1
            champAccumulatedTime += segmentTime
            if champRoundsCompleted >= 3 {
                screen = .champComplete(totalTime: champAccumulatedTime)
            } else {
                screen = .raceFinished(elapsed: segmentTime)
            }
        } else {
            screen = .raceFinished(elapsed: segmentTime)
        }
    }

    func continueChampionship() {
        screen = .racing
    }

    /// Whether track picker should appear before racing.
    func needsTrackSelect() -> Bool {
        activeGameMode == .circuit || activeGameMode == .timeTrial
    }

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
                trackIndex: selectedTrackIndex,
                lapCount: lapCount
            )
        }
    }

    func venueDisplayName() -> String {
        effectiveCityTheme().displayName
    }
}

private extension TimeInterval {
    var msScaledCredits: Int64 {
        Int64(max(80, 800 - self * 2))
    }
}
