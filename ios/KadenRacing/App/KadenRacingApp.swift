import SwiftUI

@main
struct KadenRacingApp: App {
    @UIApplicationDelegateAdaptor(KadenRacingAppDelegate.self) private var appDelegate
    @StateObject private var progress = PlayerProgressStore()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(progress)
                .onAppear {
                    #if DEBUG
                    if !KRCDebugUI.isQALaunch {
                        GameCenterService.shared.authenticateIfNeeded()
                    }
                    #else
                    GameCenterService.shared.authenticateIfNeeded()
                    #endif
                    MenuIntroAudioController.shared.warmUpAudio()
                    KenneyEnvironmentLoader.prewarm()
                }
        }
    }
}
