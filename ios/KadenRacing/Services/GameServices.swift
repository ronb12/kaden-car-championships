import Foundation
import GameKit
import StoreKit
import UIKit

// MARK: - Game Center (configure IDs in App Store Connect → Services → Game Center)
// Leaderboards + achievements, and real-time race matches (automatch, invites, nearby).

enum GameCenterConfig {
    static let lapTimeLeaderboardID = "com.kaden.racing.championships.leaderboard.laptime"
    static let driftScoreLeaderboardID = "com.kaden.racing.championships.leaderboard.drift"

    static let achievementFirstFinish = "com.kaden.racing.championships.achievement.first_finish"
    static let achievementChampion = "com.kaden.racing.championships.achievement.champion"
    static let achievementDriftMaster = "com.kaden.racing.championships.achievement.drift_master"

    static let challengeLapTime = "com.kaden.racing.championships.challenge.laptime"
    static let challengeDrift = "com.kaden.racing.championships.challenge.drift"
    static let activityRace = "com.kaden.racing.championships.activity.race"
    static let activityOnline = "com.kaden.racing.championships.activity.online"
}

enum GameCenterSheetRequest: Identifiable {
    case dashboard
    case leaderboards
    case achievements
    case leaderboard(String)

    var id: String {
        switch self {
        case .dashboard: return "dashboard"
        case .leaderboards: return "leaderboards"
        case .achievements: return "achievements"
        case .leaderboard(let id): return "lb-\(id)"
        }
    }

    var viewState: GKGameCenterViewControllerState {
        switch self {
        case .dashboard: return .default
        case .leaderboards, .leaderboard: return .leaderboards
        case .achievements: return .achievements
        }
    }

    var leaderboardID: String? {
        if case .leaderboard(let id) = self { return id }
        return nil
    }
}

@MainActor
final class GameCenterService: NSObject, ObservableObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var playerDisplayName = ""
    @Published var lastError: String?
    @Published var sheetRequest: GameCenterSheetRequest?
    /// Shown when leaderboards are requested but Game Center is not signed in.
    @Published var signInAlertMessage: String?
    /// Incoming Game Center invite was accepted — start an online race.
    @Published var pendingInviteRace = false
    /// Games app Activity / Challenge “Play” — start a solo circuit.
    @Published var pendingSoloActivityRace = false
    /// Live peer match (other humans). Nil when racing CPU / Neon lobby only.
    private(set) var raceMatch: GKMatch?

    enum RaceMatchOutcome: Equatable {
        case matched
        case cancelled
        case failed
    }

    private var didConfigureAuth = false
    private var didRegisterListener = false
    private let firstFinishKey = "krc_gc_reported_first_finish"
    private var matchContinuation: CheckedContinuation<RaceMatchOutcome, Never>?
    private var lastMatchSend: TimeInterval = 0
    private var lastPosePacket: GCRacePacket?
    private var incomingPackets: [(id: String, name: String, data: Data)] = []

    private var localPlayer: GKLocalPlayer { GKLocalPlayer.local }

    var hasActiveRaceMatch: Bool { raceMatch != nil }
    var matchHumanCount: Int { 1 + (raceMatch?.players.count ?? 0) }

    /// Call once at launch. Requires Game Center capability in `KadenRacing.entitlements`.
    func authenticateIfNeeded() {
        #if DEBUG
        if KRCDebugUI.isQALaunch {
            return
        }
        #endif
        guard !didConfigureAuth else {
            refreshPlayerState()
            return
        }
        didConfigureAuth = true

        localPlayer.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    self.presentAuthViewController(viewController)
                }
                if let error {
                    self.lastError = error.localizedDescription
                }
                self.refreshPlayerState()
                if self.isAuthenticated {
                    self.registerInviteListenerIfNeeded()
                }
            }
        }
        refreshPlayerState()
    }

    /// Automatch, friend invites, nearby — Apple's Game Center matchmaker.
    func presentRaceMatchmaker() async -> RaceMatchOutcome {
        if canRematchFriends { return .matched }
        if raceMatch != nil { disconnectRaceMatch() }
        refreshPlayerState()
        guard isAuthenticated else { return .cancelled }
        #if DEBUG
        if KRCDebugUI.isQALaunch { return .cancelled }
        #endif
        return await withCheckedContinuation { continuation in
            if matchContinuation != nil {
                continuation.resume(returning: .cancelled)
                return
            }
            matchContinuation = continuation
            let request = GKMatchRequest()
            request.minPlayers = 2
            request.maxPlayers = 8
            request.inviteMessage = "Come race in Kaden Racing! No voice chat — just cars."
            guard let controller = GKMatchmakerViewController(matchRequest: request) else {
                matchContinuation = nil
                continuation.resume(returning: .failed)
                return
            }
            controller.matchmakerDelegate = self
            // Nearby + friends + automatch. Never start a voice channel.
            controller.isHosted = false
            guard let host = UIApplication.shared.topViewController else {
                matchContinuation = nil
                continuation.resume(returning: .failed)
                return
            }
            host.present(controller, animated: true)
        }
    }

    func disconnectRaceMatch() {
        raceMatch?.disconnect()
        raceMatch?.delegate = nil
        raceMatch = nil
        incomingPackets.removeAll()
        lastPosePacket = nil
    }

    /// Friends still in the match after a finish — kids can tap Race Again.
    var canRematchFriends: Bool {
        (raceMatch?.players.count ?? 0) >= 1
    }

    func broadcastRacePacket(_ packet: GCRacePacket) {
        var outgoing = packet
        outgoing.emote = nil
        lastPosePacket = outgoing
        guard let match = raceMatch else { return }
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastMatchSend >= 0.08 else { return }
        lastMatchSend = now
        guard let data = try? JSONEncoder().encode(outgoing) else { return }
        try? match.sendData(toAllPlayers: data, with: .unreliable)
    }

    /// WAVE / NICE only — never free text, never voice.
    func broadcastKidEmote(_ emote: KidRaceEmote) {
        guard emote != .none, let match = raceMatch else { return }
        var packet = lastPosePacket ?? GCRacePacket(
            carId: "", colorInt: 0, name: KRCPlayerProfile.gamerName,
            x: 0, y: 0, z: 0, angle: 0, speedKmh: 0, lap: 1, progress: 0
        )
        packet.emote = emote.rawValue
        guard let data = try? JSONEncoder().encode(packet) else { return }
        try? match.sendData(toAllPlayers: data, with: .reliable)
    }

    func drainIncomingPackets() -> [(id: String, name: String, data: Data)] {
        let batch = incomingPackets
        incomingPackets.removeAll(keepingCapacity: true)
        return batch
    }

    func presentDashboard() {
        presentGameCenter(state: .default)
    }

    func presentLeaderboards() {
        presentGameCenter(state: .leaderboards)
    }

    func presentAchievements() {
        presentGameCenter(state: .achievements)
    }

    func presentLapTimeLeaderboard() {
        presentGameCenter(state: .leaderboards, leaderboardID: GameCenterConfig.lapTimeLeaderboardID)
    }

    /// Submit milliseconds lap time (lower is better — use an elapsed-time leaderboard in App Store Connect).
    func submitLapTime(ms: Int64, leaderboardID: String = GameCenterConfig.lapTimeLeaderboardID) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(
            Int(ms),
            context: 0,
            player: localPlayer,
            leaderboardIDs: [leaderboardID]
        ) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.lastError = error.localizedDescription
                }
            }
        }
    }

    func submitDriftScore(_ score: Int64) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(
            Int(score),
            context: 0,
            player: localPlayer,
            leaderboardIDs: [GameCenterConfig.driftScoreLeaderboardID]
        ) { _ in }
    }

    /// Call after each race segment finishes.
    func handleRaceFinished(segmentTime: TimeInterval, driftScore: Int64, championshipJustCompleted: Bool) {
        submitLapTime(ms: Int64(segmentTime * 1000))
        submitDriftScore(driftScore)

        if !UserDefaults.standard.bool(forKey: firstFinishKey) {
            UserDefaults.standard.set(true, forKey: firstFinishKey)
            reportAchievement(GameCenterConfig.achievementFirstFinish)
        }
        if driftScore >= 1000 {
            reportAchievement(GameCenterConfig.achievementDriftMaster)
        }
        if championshipJustCompleted {
            reportAchievement(GameCenterConfig.achievementChampion)
        }
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
        sheetRequest = nil
    }

    private func presentGameCenter(state: GKGameCenterViewControllerState, leaderboardID: String? = nil) {
        guard ensureSignedIn() else { return }
        // Present from the topmost VC so this works while Settings (or any sheet) is open.
        // SwiftUI nested `.sheet` from the root often fails to appear over Settings.
        let controller: GKGameCenterViewController
        if let leaderboardID, !leaderboardID.isEmpty {
            controller = GKGameCenterViewController(
                leaderboardID: leaderboardID,
                playerScope: .global,
                timeScope: .allTime
            )
        } else {
            controller = GKGameCenterViewController(state: state)
        }
        controller.gameCenterDelegate = self
        guard let host = UIApplication.shared.topViewController else {
            // Fallback for unusual window state — still drives the root SwiftUI sheet.
            switch state {
            case .achievements: sheetRequest = .achievements
            case .leaderboards:
                if let leaderboardID, !leaderboardID.isEmpty {
                    sheetRequest = .leaderboard(leaderboardID)
                } else {
                    sheetRequest = .leaderboards
                }
            default: sheetRequest = .dashboard
            }
            return
        }
        if host.presentedViewController is GKGameCenterViewController {
            return
        }
        host.present(controller, animated: true)
    }

    private func reportAchievement(_ identifier: String) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = 100
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.lastError = error.localizedDescription
                }
            }
        }
    }

    private func refreshPlayerState() {
        isAuthenticated = localPlayer.isAuthenticated
        playerDisplayName = isAuthenticated ? (localPlayer.displayName) : ""
        if isAuthenticated {
            registerInviteListenerIfNeeded()
        }
    }

    private func registerInviteListenerIfNeeded() {
        guard isAuthenticated, !didRegisterListener else { return }
        didRegisterListener = true
        localPlayer.register(self)
    }

    private func finishMatchmaking(_ outcome: RaceMatchOutcome, controller: UIViewController?) {
        controller?.dismiss(animated: true)
        let cont = matchContinuation
        matchContinuation = nil
        cont?.resume(returning: outcome)
        if outcome == .matched, cont == nil {
            pendingInviteRace = true
        }
    }

    @discardableResult
    private func ensureSignedIn() -> Bool {
        refreshPlayerState()
        if isAuthenticated { return true }
        let message = "Sign in to Game Center in the iOS Settings app to view leaderboards."
        lastError = message
        signInAlertMessage = message
        #if DEBUG
        if !KRCDebugUI.isQALaunch {
            authenticateIfNeeded()
        }
        #else
        authenticateIfNeeded()
        #endif
        return false
    }

    private func presentAuthViewController(_ viewController: UIViewController) {
        guard let top = UIApplication.shared.topViewController else { return }
        if top.presentedViewController is GKGameCenterViewController { return }
        top.present(viewController, animated: true)
    }
}

/// Real-time pose sent over a Game Center match (~12 Hz, unreliable).
struct GCRacePacket: Codable {
    var carId: String
    var colorInt: Int
    var name: String
    var x: Float
    var y: Float
    var z: Float
    var angle: Float
    var speedKmh: Int
    var lap: Int
    var progress: Float
    var emote: UInt8? = nil
}

/// Kid-safe canned signals. No voice, no typing.
enum KidRaceEmote: UInt8 {
    case none = 0
    case horn = 1
    case wave = 2
    case nice = 3

    var glyph: String {
        switch self {
        case .none: return ""
        case .horn: return "📣"
        case .wave: return "👋"
        case .nice: return "👍"
        }
    }
}

extension GameCenterService: GKMatchmakerViewControllerDelegate {
    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        Task { @MainActor in
            match.delegate = self
            self.raceMatch = match
            self.finishMatchmaking(.matched, controller: viewController)
        }
    }

    nonisolated func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        Task { @MainActor in
            self.finishMatchmaking(.cancelled, controller: viewController)
        }
    }

    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        Task { @MainActor in
            self.lastError = error.localizedDescription
            self.finishMatchmaking(.failed, controller: viewController)
        }
    }
}

extension GameCenterService: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        let pid = player.gamePlayerID.isEmpty ? player.displayName : player.gamePlayerID
        let name = player.displayName
        Task { @MainActor in
            self.incomingPackets.append((id: pid, name: name, data: data))
        }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        Task { @MainActor in
            if state == .disconnected, match.players.isEmpty {
                self.statusLineSafeDisconnect()
            }
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        Task { @MainActor in
            if let error {
                self.lastError = error.localizedDescription
            }
        }
    }

    private func statusLineSafeDisconnect() {
        if raceMatch != nil {
            disconnectRaceMatch()
        }
    }
}

extension GameCenterService: GKLocalPlayerListener {
    nonisolated func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        Task { @MainActor in
            guard let controller = GKMatchmakerViewController(invite: invite) else { return }
            controller.matchmakerDelegate = self
            controller.isHosted = false
            UIApplication.shared.topViewController?.present(controller, animated: true)
        }
    }

    @available(iOS 26.0, *)
    nonisolated func player(_ player: GKPlayer, wantsToPlay activity: GKGameActivity, completionHandler: @escaping @Sendable (Bool) -> Void) {
        Task { @MainActor in
            let id = activity.activityDefinition.identifier
            activity.start()
            if id == GameCenterConfig.activityOnline {
                pendingInviteRace = true
            } else {
                pendingSoloActivityRace = true
            }
            completionHandler(true)
        }
    }
}

// MARK: - StoreKit 2 (IAP hooks — add products in App Store Connect)

enum IAPProductID: String, CaseIterable {
    /// Cosmetic wrap pack — no handling boost.
    case wrapPackNeon = "com.kaden.racing.cosmetics.wraps.neon"
    /// Starter credit pack for garage vanity / unlocks.
    case creditsStarter = "com.kaden.racing.credits.starter"
    case creditsSmall = "com.kaden.racing.credits.small"
    case removeAds = "com.kaden.racing.removeads"

    var displayName: String {
        switch self {
        case .wrapPackNeon: return "Neon Wrap Pack"
        case .creditsStarter: return "Starter Credits"
        case .creditsSmall: return "Credit Pack"
        case .removeAds: return "Remove Ads"
        }
    }

    var isCosmeticOrCurrency: Bool {
        switch self {
        case .wrapPackNeon, .creditsStarter, .creditsSmall: return true
        case .removeAds: return true
        }
    }
}

@MainActor
final class StoreKitFacade: ObservableObject {
    static let shared = StoreKitFacade()

    @Published private(set) var products: [Product] = []
    @Published private(set) var lastError: String?
    @Published private(set) var ownedWrapPackNeon = false
    @Published private(set) var removeAdsOwned = false

    private static let wrapOwnedKey = "krc.iap.wrapPackNeon"
    private static let removeAdsKey = "krc.iap.removeAds"

    init() {
        ownedWrapPackNeon = UserDefaults.standard.bool(forKey: Self.wrapOwnedKey)
        removeAdsOwned = UserDefaults.standard.bool(forKey: Self.removeAdsKey)
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: IAPProductID.allCases.map(\.rawValue))
            lastError = nil
        } catch {
            products = []
            lastError = "Store unavailable — try again later."
        }
    }

    func product(for id: IAPProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    func purchase(_ product: Product, progress: PlayerProgressStore? = nil) async throws -> Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let tx = try checkVerified(verification)
            await applyEntitlement(for: tx.productID, progress: progress)
            await tx.finish()
            return tx
        default:
            return nil
        }
    }

    /// Grant cosmetic / currency entitlements after a verified purchase (never pay-to-win handling).
    func applyEntitlement(for productID: String, progress: PlayerProgressStore? = nil) async {
        guard let id = IAPProductID(rawValue: productID) else { return }
        switch id {
        case .wrapPackNeon:
            ownedWrapPackNeon = true
            UserDefaults.standard.set(true, forKey: Self.wrapOwnedKey)
        case .creditsStarter:
            progress?.creditsMutation(8_000)
        case .creditsSmall:
            progress?.creditsMutation(2_500)
        case .removeAds:
            removeAdsOwned = true
            UserDefaults.standard.set(true, forKey: Self.removeAdsKey)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }
}

private extension UIApplication {
    var topViewController: UIViewController? {
        let root = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
        return topMost(from: root)
    }

    func topMost(from base: UIViewController?) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topMost(from: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topMost(from: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topMost(from: presented)
        }
        return base
    }
}
