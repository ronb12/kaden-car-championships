import Foundation

enum KRCTutorial {
    private static let shownKey = "krc.tutorial.controls.shown.v1"
    private static let guidedKey = "krc.tutorial.guided.race.v1"
    private static let guidedStepKey = "krc.tutorial.guided.step.v1"

    static var hasShownControlsTip: Bool {
        get { UserDefaults.standard.bool(forKey: shownKey) }
        set { UserDefaults.standard.set(newValue, forKey: shownKey) }
    }

    /// First-session guided race (steer → gas → drift → nitro → finish).
    static var hasCompletedGuidedRace: Bool {
        get { UserDefaults.standard.bool(forKey: guidedKey) }
        set { UserDefaults.standard.set(newValue, forKey: guidedKey) }
    }

    static var guidedStepIndex: Int {
        get { UserDefaults.standard.integer(forKey: guidedStepKey) }
        set { UserDefaults.standard.set(newValue, forKey: guidedStepKey) }
    }

    static let controlsTipLines: [String] = [
        "Hold gas to accelerate · brake to slow",
        "Steer with the wheel / tilt / D-pad",
        "Nitro for a short boost · in Hot Pursuit ram suspects to issue tickets",
    ]

    enum GuidedStep: Int, CaseIterable {
        case steer
        case gas
        case drift
        case nitro
        case finish

        var title: String {
            switch self {
            case .steer: return "STEER"
            case .gas: return "GAS"
            case .drift: return "DRIFT"
            case .nitro: return "NITRO"
            case .finish: return "FINISH"
            }
        }

        var tip: String {
            switch self {
            case .steer: return "Use left / right to stay on the asphalt"
            case .gas: return "Hold GAS — build speed into the first corner"
            case .drift: return "Tap DRIFT through a bend for combo score"
            case .nitro: return "Hit NITRO on a straight for a short boost"
            case .finish: return "Complete the lap — podium rewards wait"
            }
        }
    }

    static var currentGuidedStep: GuidedStep {
        GuidedStep(rawValue: min(max(0, guidedStepIndex), GuidedStep.allCases.count - 1)) ?? .steer
    }

    static func advanceGuidedStep() {
        let next = guidedStepIndex + 1
        if next >= GuidedStep.allCases.count {
            hasCompletedGuidedRace = true
            hasShownControlsTip = true
            guidedStepIndex = GuidedStep.allCases.count - 1
        } else {
            guidedStepIndex = next
        }
    }

    static func markGuidedComplete() {
        hasCompletedGuidedRace = true
        hasShownControlsTip = true
        guidedStepIndex = GuidedStep.allCases.count - 1
    }

    /// Declutter HUD until the player finishes their first guided race.
    static var shouldDeclutterHUD: Bool { !hasCompletedGuidedRace }
}
