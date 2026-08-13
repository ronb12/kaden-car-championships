import UIKit

/// Central orientation policy for the app (read by `UIApplicationDelegate`).
final class AppOrientationController {
    static let shared = AppOrientationController()

    /// Default: portrait + landscape, never upside-down (avoids inverted SceneKit view).
    var supportedMask: UIInterfaceOrientationMask = .allButUpsideDown
}

final class KadenRacingAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppOrientationController.shared.supportedMask
    }
}
