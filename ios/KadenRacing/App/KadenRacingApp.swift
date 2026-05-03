import SwiftUI

@main
struct KadenRacingApp: App {
    @StateObject private var progress = PlayerProgressStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(progress)
        }
    }
}
