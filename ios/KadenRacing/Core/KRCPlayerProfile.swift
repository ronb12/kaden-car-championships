import Foundation

/// Shared player identity keys (same as web `localStorage`).
enum KRCPlayerProfile {
    private static let idKey = "krc-player-id"
    private static let nameKey = "krc-gamer-name"
    private static let playModeKey = "krc-play-mode"

    static var playerId: String {
        if let id = UserDefaults.standard.string(forKey: idKey), !id.isEmpty {
            return id
        }
        let id = "krc-\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
        UserDefaults.standard.set(id, forKey: idKey)
        return id
    }

    static var gamerName: String {
        get {
            let raw = UserDefaults.standard.string(forKey: nameKey) ?? "KRC DRIVER"
            return cleanGamerName(raw)
        }
        set {
            UserDefaults.standard.set(cleanGamerName(newValue), forKey: nameKey)
        }
    }

    static var onlinePlayEnabled: Bool {
        get { UserDefaults.standard.string(forKey: playModeKey) != "solo" }
        set { UserDefaults.standard.set(newValue ? "online" : "solo", forKey: playModeKey) }
    }

    /// Removes the stored player ID so the next read creates a new anonymous ID.
    static func regeneratePlayerId() {
        UserDefaults.standard.removeObject(forKey: idKey)
    }

    /// Clears online identity on device (new player ID, default nickname, solo mode).
    static func resetOnlineIdentityOnDevice() {
        regeneratePlayerId()
        gamerName = "KRC DRIVER"
        onlinePlayEnabled = false
    }

    static func cleanGamerName(_ value: String) -> String {
        let upper = value.uppercased()
        let filtered = upper.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "_" || $0 == "." || $0 == "-"
        }
        let collapsed = String(String.UnicodeScalarView(filtered))
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        let trimmed = String(collapsed.prefix(16))
        return trimmed.isEmpty ? "KRC DRIVER" : trimmed
    }
}
