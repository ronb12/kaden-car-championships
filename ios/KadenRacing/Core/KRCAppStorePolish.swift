import Foundation
import StoreKit
import UIKit

/// Soft App Store ratings prompt + first-session polish gates.
enum KRCAppStorePolish {
    private static let finishesKey = "krc.store.raceFinishes"
    private static let ratedPromptKey = "krc.store.ratedPrompted"
    private static let onboardingKey = "krc.onboarding.v1.done"

    static var raceFinishCount: Int {
        get { UserDefaults.standard.integer(forKey: finishesKey) }
        set { UserDefaults.standard.set(newValue, forKey: finishesKey) }
    }

    static var hasPromptedReview: Bool {
        get { UserDefaults.standard.bool(forKey: ratedPromptKey) }
        set { UserDefaults.standard.set(newValue, forKey: ratedPromptKey) }
    }

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
    }

    static func noteRaceFinished(position: Int) {
        raceFinishCount += 1
        // Prompt after a strong early session — not on first race.
        guard !hasPromptedReview, raceFinishCount >= 3, position <= 3 else { return }
        hasPromptedReview = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            requestReviewIfAppropriate()
        }
    }

    static func requestReviewIfAppropriate() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}
