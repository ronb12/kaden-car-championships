import Foundation
import GameKit
import StoreKit

// MARK: - Game Center (leaderboards / achievements shell)

enum GameCenterConfig {
    static let lapTimeLeaderboardID = "com.kaden.racing.championships.leaderboard.laptime"
    static let driftScoreLeaderboardID = "com.kaden.racing.championships.leaderboard.drift"
}

final class GameCenterService: NSObject, ObservableObject {
    static let shared = GameCenterService()

    @Published private(set) var isAuthenticated = false
    @Published var lastError: String?

    private var didConfigureAuth = false

    /// Call once at launch. Requires `com.apple.developer.game-center` in the entitlements (`KadenRacing.entitlements`).
    ///
    /// **Simulator:** We skip `authenticateHandler` by default. Without a signed-in Game Center
    /// account, GameKit returns GKError 3/6 and GameOverlayUI proxy errors (noisy, not useful).
    /// Leaderboards still work on a **physical device** with a normal Game Center sign-in.
    /// To exercise Game Center on Simulator, sign in under Settings → Game Center and
    /// temporarily remove the `#if targetEnvironment(simulator)` block below.
    func authenticateIfNeeded() {
        guard !didConfigureAuth else { return }
        didConfigureAuth = true

        #if targetEnvironment(simulator)
        return
        #else
        localPlayer.authenticateHandler = { [weak self] _, error in
            DispatchQueue.main.async {
                self?.isAuthenticated = self?.localPlayer.isAuthenticated ?? false
                self?.lastError = error?.localizedDescription
            }
        }
        #endif
    }

    private var localPlayer: GKLocalPlayer { GKLocalPlayer.local }

    /// Submit milliseconds lap time (configure leaderboard IDs in App Store Connect).
    func submitLapTime(ms: Int64, leaderboardID: String = GameCenterConfig.lapTimeLeaderboardID) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(Int(ms), context: 0, player: localPlayer, leaderboardIDs: [leaderboardID]) { error in
            if let error { DispatchQueue.main.async { GameCenterService.shared.lastError = error.localizedDescription } }
        }
    }

    func submitDriftScore(_ score: Int64) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(Int(score), context: 0, player: localPlayer, leaderboardIDs: [GameCenterConfig.driftScoreLeaderboardID]) { _ in }
    }
}

// MARK: - StoreKit 2 (IAP hooks — add products in App Store Connect)

enum IAPProductID: String, CaseIterable {
    case premiumBundle = "com.kaden.racing.premium.bundle"
    case creditsSmall = "com.kaden.racing.credits.small"
    case removeAds = "com.kaden.racing.removeads"
}

@MainActor
final class StoreKitFacade: ObservableObject {
    static let shared = StoreKitFacade()

    @Published private(set) var products: [Product] = []

    func loadProducts() async {
        do {
            products = try await Product.products(for: IAPProductID.allCases.map(\.rawValue))
        } catch {
            products = []
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let tx = try checkVerified(verification)
            await tx.finish()
            return tx
        default:
            return nil
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }
}
