#if DEBUG
import Foundation

/// Launch-argument hooks for simulator page QA (`-qaSettings`, `-qaPrivacy`, etc.).
enum KRCDebugUI {
    static var openSettingsOnMenu = false
    static var openPrivacyOnMenu = false
    static var openTermsOnMenu = false
    static var startRacePaused = false
    static var showGameCenterAlertOnMenu = false

    /// Any `-qa…` launch flag (automation / page QA).
    static var isQALaunch: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-qa") }
    }
}
#endif
