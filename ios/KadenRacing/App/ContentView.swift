import SwiftUI

struct ContentView: View {
    @StateObject private var progress = PlayerProgressStore()

    var body: some View {
        NativeRootView()
            .environmentObject(progress)
            .preferredColorScheme(.dark)
            .onAppear {
                GameCenterService.shared.authenticateIfNeeded()
            }
    }
}
