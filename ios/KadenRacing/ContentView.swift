import SwiftUI

struct ContentView: View {
    private let gameURL: URL = ContentView.resolvedGameURL()

    var body: some View {
        GameWebContainer(url: gameURL)
            .ignoresSafeArea()
            .background(Color.black)
    }

    /// Primary: `GAME_WEB_URL` in Info.plist. Fallback: production placeholder (replace before App Store).
    static func resolvedGameURL() -> URL {
        if let s = Bundle.main.object(forInfoDictionaryKey: "GAME_WEB_URL") as? String,
           let u = URL(string: s), u.scheme == "http" || u.scheme == "https" {
            return u
        }
        return URL(string: "https://kaden-car-championships.vercel.app")!
    }
}
