import SwiftUI
import UIKit

/// System accessibility + in-app options used by menus, HUD, and racing.
enum KRCAccessibility {
    private static let calloutsKey = "krc.a11y.raceCallouts"
    private static let darkerKey = "krc.a11y.darkerRaces"
    private static let largeControlsKey = "krc.a11y.largeControls"

    static var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    static var increaseContrast: Bool { UIAccessibility.isDarkerSystemColorsEnabled }
    static var voiceOverRunning: Bool { UIAccessibility.isVoiceOverRunning }
    static var boldText: Bool { UIAccessibility.isBoldTextEnabled }

    /// Spoken race callouts (countdown, position, wrong way). Default on.
    static var raceCalloutsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: calloutsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: calloutsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: calloutsKey) }
    }

    /// Night lighting for races. Follows Increase Contrast unless the player overrides.
    static var darkerRacesEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: darkerKey) == nil {
                return increaseContrast
            }
            return UserDefaults.standard.bool(forKey: darkerKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: darkerKey) }
    }

    /// Bigger on-screen pedals / D-pad.
    static var largeControlsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: largeControlsKey) }
        set { UserDefaults.standard.set(newValue, forKey: largeControlsKey) }
    }

    static var shouldAnnounce: Bool {
        raceCalloutsEnabled || voiceOverRunning
    }

    static var preferDarkerWorld: Bool { darkerRacesEnabled || increaseContrast }

    static var extraSteeringAssist: Float {
        voiceOverRunning ? 0.28 : 0
    }

    static var controlScaleBoost: CGFloat {
        largeControlsEnabled || voiceOverRunning ? 1.18 : 1
    }

    static func announce(_ message: String) {
        guard shouldAnnounce, !message.isEmpty else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    static func layoutChanged() {
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
}

// MARK: - Race callouts

@MainActor
final class KRCRaceAnnouncer {
    static let shared = KRCRaceAnnouncer()

    private var lastLight: Int = .min
    private var lastPosition: Int = 0
    private var lastWrongWay = false
    private var lastPositionAt: TimeInterval = 0

    func reset() {
        lastLight = .min
        lastPosition = 0
        lastWrongWay = false
        lastPositionAt = 0
    }

    func countdown(light: Int) {
        guard light != lastLight else { return }
        lastLight = light
        if light > 0 {
            KRCAccessibility.announce("\(light)")
        } else if light == 0 {
            KRCAccessibility.announce("Go")
        }
    }

    func tick(position: Int, racerCount: Int, wrongWay: Bool, finished: Bool) {
        if wrongWay != lastWrongWay {
            lastWrongWay = wrongWay
            if wrongWay { KRCAccessibility.announce("Wrong way") }
        }
        guard !finished, position > 0, racerCount > 1 else { return }
        let now = Date().timeIntervalSinceReferenceDate
        if position != lastPosition, now - lastPositionAt > 3.5 {
            lastPosition = position
            lastPositionAt = now
            KRCAccessibility.announce("P \(position) of \(racerCount)")
        }
    }

    func finished(place: Int, racerCount: Int) {
        if racerCount > 1 {
            KRCAccessibility.announce("Finished in position \(place) of \(racerCount)")
        } else {
            KRCAccessibility.announce("Race finished")
        }
    }
}

// MARK: - SwiftUI helpers

extension View {
    func krcReduceMotion(_ reduce: Bool, animation: Animation) -> some View {
        self.animation(reduce ? nil : animation, value: reduce)
    }
}

enum KRCAccessFonts {
    static func title() -> Font { .title.weight(.black) }
    static func headline() -> Font { .headline.weight(.bold) }
    static func body() -> Font { .body.weight(.semibold) }
    static func caption() -> Font { .caption.weight(.semibold) }
    static func hud(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
