import SwiftUI

/// Race supports portrait and landscape — no orientation lock (see Info.plist).
struct RaceOrientationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    /// Keeps call sites explicit; does not restrict device rotation.
    func raceAllOrientationsAllowed() -> some View {
        modifier(RaceOrientationModifier())
    }
}
