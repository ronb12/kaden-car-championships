import GameKit
import SwiftUI
import UIKit

/// Presents Apple's Game Center dashboard, leaderboards, or achievements.
struct GameCenterUIKitSheet: UIViewControllerRepresentable {
    let state: GKGameCenterViewControllerState
    var leaderboardID: String?
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let controller: GKGameCenterViewController
        if let leaderboardID, !leaderboardID.isEmpty {
            controller = GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime)
        } else {
            controller = GKGameCenterViewController(state: state)
        }
        controller.gameCenterDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {}

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            onDismiss()
        }
    }
}

/// Settings rows for Game Center sign-in status and leaderboards.
struct GameCenterSettingsSection: View {
    @ObservedObject private var gameCenter = GameCenterService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .foregroundStyle(KRCDesign.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text(gameCenter.isAuthenticated ? gameCenter.playerDisplayName : "Not signed in")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(gameCenter.isAuthenticated
                        ? "Race times sync to Game Center leaderboards"
                        : "Tap Sign In, or use Settings → Game Center on your device")
                        .font(.caption)
                        .foregroundStyle(KRCDesign.mutedText)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            Divider().overlay(Color.white.opacity(0.08))
            if !gameCenter.isAuthenticated {
                gameCenterButton("Sign In to Game Center") {
                    gameCenter.authenticateIfNeeded()
                }
                Divider().overlay(Color.white.opacity(0.08))
            }
            gameCenterButton("View Leaderboards") { gameCenter.presentLeaderboards() }
            Divider().overlay(Color.white.opacity(0.08))
            gameCenterButton("Best Lap Times") { gameCenter.presentLapTimeLeaderboard() }
            Divider().overlay(Color.white.opacity(0.08))
            gameCenterButton("Achievements") { gameCenter.presentAchievements() }
            Divider().overlay(Color.white.opacity(0.08))
            gameCenterButton("Game Center Dashboard") { gameCenter.presentDashboard() }
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
        .onAppear {
            gameCenter.authenticateIfNeeded()
        }
    }

    private func gameCenterButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            KRCDesign.SettingsRow(label: title)
        }
        .buttonStyle(.plain)
    }
}
