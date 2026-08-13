import Foundation

enum KRCAudioPreferences {
    private static let musicKey = "krc.audio.music"
    private static let sfxKey = "krc.audio.sfx"
    private static let musicMuteKey = "krc.audio.musicMute"
    private static let sfxMuteKey = "krc.audio.sfxMute"
    private static let hapticsKey = "krc.audio.haptics"

    static var musicVolume: Float {
        get { stored(musicKey, default: 0.72) }
        set { UserDefaults.standard.set(newValue, forKey: musicKey) }
    }

    static var sfxVolume: Float {
        get { stored(sfxKey, default: 0.88) }
        set { UserDefaults.standard.set(newValue, forKey: sfxKey) }
    }

    static var musicMuted: Bool {
        get { UserDefaults.standard.bool(forKey: musicMuteKey) }
        set { UserDefaults.standard.set(newValue, forKey: musicMuteKey) }
    }

    static var sfxMuted: Bool {
        get { UserDefaults.standard.bool(forKey: sfxMuteKey) }
        set { UserDefaults.standard.set(newValue, forKey: sfxMuteKey) }
    }

    static var hapticsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: hapticsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: hapticsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: hapticsKey) }
    }

    /// Music bed volume (settings slider). Engine SFX use `effectiveSFX`.
    static var effectiveMusic: Float { musicMuted ? 0 : musicVolume }
    static var effectiveSFX: Float { sfxMuted ? 0 : sfxVolume }

    private static func stored(_ key: String, default def: Float) -> Float {
        if UserDefaults.standard.object(forKey: key) == nil { return def }
        return UserDefaults.standard.float(forKey: key)
    }
}
