import SwiftUI
import UIKit

/// Locks the race view to **landscape** so the track reads horizontally (correct driving orientation).
struct RaceLandscapeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear(perform: lockLandscape)
            .onDisappear(perform: unlockOrientations)
    }

    private func lockLandscape() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: [.landscapeRight, .landscapeLeft])
            scene.requestGeometryUpdate(prefs)
        }
    }

    private func unlockOrientations() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .all)
            scene.requestGeometryUpdate(prefs)
        }
    }
}

extension View {
    func raceLandscapePreferred() -> some View {
        modifier(RaceLandscapeModifier())
    }
}
