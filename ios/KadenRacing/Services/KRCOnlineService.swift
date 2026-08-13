import Foundation
import SceneKit
import UIKit

struct GlobalLeaderboardEntry: Identifiable {
    let id = UUID()
    let place: Int
    let playerName: String
    let carName: String
    let trackName: String?
    let totalMs: Int
}

struct LiveLobbyPlayer: Identifiable, Equatable {
    let id: String
    let name: String
    let carName: String
    let finishMs: Int?
    let position: Int?
}

struct LiveMatchResult: Equatable {
    let lobbyId: String
    let humanPosition: Int
    let humanCount: Int
    let players: [LiveLobbyPlayer]
}

/// Global scores + live multiplayer presence + head-to-head matchmaking (Neon via Vercel).
@MainActor
final class KRCOnlineService: ObservableObject {
    static let shared = KRCOnlineService()

    @Published private(set) var statusLine = "SOLO MODE"
    @Published private(set) var onlinePlayerCount = 0
    @Published private(set) var globalEnabled = false
    @Published private(set) var globalRaceCount = 0
    @Published private(set) var leaderboard: [GlobalLeaderboardEntry] = []
    @Published private(set) var lastSubmittedRank: Int?
    @Published private(set) var scoreboardMessage = ""

    // Matchmaking / live lobby
    @Published private(set) var lobbyId: String?
    @Published private(set) var lobbyStartsAt: Date?
    @Published private(set) var lobbyPlayers: [LiveLobbyPlayer] = []
    @Published private(set) var matchmakingPhase: MatchPhase = .idle
    @Published private(set) var nearbyRacerCount = 0
    @Published private(set) var lastLiveResult: LiveMatchResult?

    enum MatchPhase: Equatable {
        case idle
        case searching
        case waiting(secondsLeft: Int, racers: Int)
        case go
        case racing
        case offlineFallback
    }

    private let baseURL = URL(string: "https://kaden-car-championships.vercel.app")!
    private var sessionActive = false
    private var lastSync: TimeInterval = 0
    private let syncInterval: TimeInterval = 0.4
    private var inFlight = false
    private var serverOffsetMs: TimeInterval = 0
    private var finishSent = false

    private struct RemoteEntry {
        let node: SCNNode
        var target: SIMD3<Float>
        var angle: Float
        var lastSeen: TimeInterval
    }

    private var remotes: [String: RemoteEntry] = [:]
    private weak var sceneRoot: SCNNode?

    private init() {}

    /// App Store Guideline 5.1.1(v): delete server-side records for this player ID.
    func deleteAccountData(playerId: String) async throws -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/delete-account"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["playerId": playerId])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let json = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return json["deleted"] as? Bool == true || json["ok"] as? Bool == true
    }

    // MARK: - Global scoreboard

    func refreshGlobalSummary() async {
        guard KRCPlayerProfile.onlinePlayEnabled else {
            statusLine = "SOLO MODE"
            onlinePlayerCount = 0
            globalEnabled = false
            globalRaceCount = 0
            leaderboard = []
            scoreboardMessage = "Solo mode — scores stay on this device."
            return
        }
        do {
            let data = try await getJSON(path: "/api/global")
            applyGlobalPayload(data)
        } catch {
            statusLine = "ONLINE RECONNECTING…"
            scoreboardMessage = "Could not reach global scoreboard."
        }
    }

    func refreshLeaderboard(trackKey: String? = nil) async {
        guard KRCPlayerProfile.onlinePlayEnabled else {
            leaderboard = []
            return
        }
        do {
            var items: [URLQueryItem] = []
            if let trackKey, !trackKey.isEmpty {
                items.append(URLQueryItem(name: "trackKey", value: trackKey))
            }
            let data = try await getJSON(path: "/api/global", queryItems: items)
            applyGlobalPayload(data)
        } catch {
            scoreboardMessage = "Leaderboard offline — check connection."
        }
    }

    func recordGlobalPlayStart(mode: String, trackKey: String, trackName: String) async {
        guard KRCPlayerProfile.onlinePlayEnabled else { return }
        do {
            let data = try await postGlobal(body: globalPayload(
                type: "play_start",
                mode: mode,
                trackKey: trackKey,
                trackName: trackName
            ))
            applyGlobalPayload(data)
        } catch { }
    }

    func submitGlobalRaceFinish(
        context: RaceOnlineContext,
        totalMs: Int64,
        position: Int,
        racerCount: Int
    ) async {
        guard KRCPlayerProfile.onlinePlayEnabled else { return }
        do {
            let data = try await postGlobal(body: globalPayload(
                type: "finish",
                mode: context.mode,
                trackKey: context.trackKey,
                trackName: GameCatalog.track(at: context.trackIndex).name,
                carName: context.carName,
                carId: context.carId,
                totalMs: totalMs,
                position: position,
                racerCount: racerCount
            ))
            applyGlobalPayload(data)
            if let rank = data["rank"] as? Int {
                lastSubmittedRank = rank
                scoreboardMessage = "Score saved · global rank P\(rank) on this track"
            } else {
                scoreboardMessage = "Score saved to global leaderboard"
            }
        } catch {
            scoreboardMessage = "Race finished — could not save score online."
        }
    }

    // MARK: - Matchmaking

    /// Join / create a lobby for this track. Returns when GO should fire (or falls back offline).
    @discardableResult
    func runMatchmaking(
        trackKey: String,
        mode: String,
        carId: String,
        carName: String,
        colorInt: UInt32
    ) async -> Bool {
        guard KRCPlayerProfile.onlinePlayEnabled else {
            matchmakingPhase = .idle
            return false
        }
        finishSent = false
        lastLiveResult = nil
        matchmakingPhase = .searching
        statusLine = "FINDING LIVE RACE…"

        do {
            let data = try await postMatchmaking(body: [
                "type": "join",
                "playerId": KRCPlayerProfile.playerId,
                "playerName": KRCPlayerProfile.gamerName,
                "trackKey": trackKey,
                "mode": mode,
                "carId": carId,
                "carName": carName,
                "colorInt": Int(colorInt),
            ])
            if data["enabled"] as? Bool == false {
                matchmakingPhase = .offlineFallback
                statusLine = "LIVE MATCHMAKING OFFLINE"
                clearLobbyLocal()
                return false
            }
            guard applyLobbyPayload(data) else {
                matchmakingPhase = .offlineFallback
                return false
            }
            await waitForLobbyStart(
                trackKey: trackKey,
                mode: mode,
                carId: carId,
                carName: carName,
                colorInt: colorInt
            )
            matchmakingPhase = .go
            statusLine = "LIVE RACE · \(max(1, lobbyPlayers.count)) RACERS"
            return lobbyId != nil
        } catch {
            matchmakingPhase = .offlineFallback
            statusLine = "MATCHMAKING RECONNECTING…"
            clearLobbyLocal()
            return false
        }
    }

    private func waitForLobbyStart(
        trackKey: String,
        mode: String,
        carId: String,
        carName: String,
        colorInt: UInt32
    ) async {
        var lastPoll = Date.distantPast
        while !Task.isCancelled {
            let nowServer = Date().addingTimeInterval(serverOffsetMs / 1000)
            let starts = lobbyStartsAt ?? nowServer
            let left = starts.timeIntervalSince(nowServer)
            let racers = max(1, lobbyPlayers.count)
            if left > 0 {
                matchmakingPhase = .waiting(secondsLeft: max(1, Int(ceil(left))), racers: racers)
                statusLine = left > 3.5
                    ? "MATCH FOUND · \(racers) RACER\(racers == 1 ? "" : "S")"
                    : "LIVE START \(max(1, Int(ceil(left))))…"
            }
            if left <= 0 { break }
            if Date().timeIntervalSince(lastPoll) >= 0.85, let lobbyId {
                lastPoll = Date()
                if let data = try? await postMatchmaking(body: [
                    "type": "status",
                    "lobbyId": lobbyId,
                    "playerId": KRCPlayerProfile.playerId,
                    "playerName": KRCPlayerProfile.gamerName,
                    "trackKey": trackKey,
                    "mode": mode,
                    "carId": carId,
                    "carName": carName,
                    "colorInt": Int(colorInt),
                ]) {
                    _ = applyLobbyPayload(data)
                }
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    /// Submit live finish + return human standing in the lobby.
    func submitLiveFinish(finishMs: Int64, fallbackPosition: Int) async -> LiveMatchResult? {
        guard KRCPlayerProfile.onlinePlayEnabled, let lobbyId, !finishSent else { return lastLiveResult }
        finishSent = true
        do {
            let data = try await postMatchmaking(body: [
                "type": "finish",
                "lobbyId": lobbyId,
                "playerId": KRCPlayerProfile.playerId,
                "playerName": KRCPlayerProfile.gamerName,
                "trackKey": "",
                "finishMs": finishMs,
                "position": fallbackPosition,
            ])
            _ = applyLobbyPayload(data)
            // Brief settle so other finishers land.
            try? await Task.sleep(nanoseconds: 450_000_000)
            if let refreshed = try? await postMatchmaking(body: [
                "type": "status",
                "lobbyId": lobbyId,
                "playerId": KRCPlayerProfile.playerId,
                "playerName": KRCPlayerProfile.gamerName,
                "trackKey": "",
            ]) {
                _ = applyLobbyPayload(refreshed)
            }
            let ranked = lobbyPlayers.sorted { a, b in
                switch (a.finishMs, b.finishMs) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.name < b.name
                }
            }
            let humanCount = max(1, ranked.count)
            let myIndex = ranked.firstIndex(where: { $0.id == KRCPlayerProfile.playerId }) ?? max(0, fallbackPosition - 1)
            let result = LiveMatchResult(
                lobbyId: lobbyId,
                humanPosition: myIndex + 1,
                humanCount: humanCount,
                players: ranked
            )
            lastLiveResult = result
            scoreboardMessage = "Live finish · P\(result.humanPosition)/\(result.humanCount) in lobby"
            return result
        } catch {
            return nil
        }
    }

    // MARK: - Race session / presence

    func beginRaceSession(scene: SCNScene, root: SCNNode) {
        lastSubmittedRank = nil
        if matchmakingPhase != .go && matchmakingPhase != .racing {
            scoreboardMessage = ""
        }
        sceneRoot = root
        sessionActive = KRCPlayerProfile.onlinePlayEnabled
        lastSync = 0
        if sessionActive {
            matchmakingPhase = lobbyId == nil ? .racing : .racing
        } else {
            clearRemotes()
            statusLine = "SOLO MODE"
        }
    }

    func endRaceSession() {
        sessionActive = false
        clearRemotes()
        let leavingLobby = lobbyId
        clearLobbyLocal()
        guard KRCPlayerProfile.onlinePlayEnabled else { return }
        Task {
            try? await postMultiplayer(type: "leave", snapshot: nil)
            if leavingLobby != nil {
                try? await postMatchmaking(body: [
                    "type": "leave",
                    "playerId": KRCPlayerProfile.playerId,
                    "playerName": KRCPlayerProfile.gamerName,
                    "lobbyId": leavingLobby ?? "",
                    "trackKey": "",
                ])
            }
        }
    }

    func tick(
        scene: SCNScene,
        dt: Float,
        snapshot: RaceOnlineSnapshot
    ) {
        guard sessionActive else { return }
        let now = Date().timeIntervalSinceReferenceDate
        if now - lastSync >= syncInterval, !inFlight {
            lastSync = now
            inFlight = true
            Task {
                await syncMultiplayer(snapshot: snapshot)
                inFlight = false
            }
        }
        let lerp = min(1, dt * 10)
        for (id, entry) in remotes {
            let p = entry.node.position
            entry.node.position = SCNVector3(
                p.x + (entry.target.x - p.x) * lerp,
                p.y + (entry.target.y - p.y) * lerp,
                p.z + (entry.target.z - p.z) * lerp
            )
            entry.node.eulerAngles.y += (entry.angle - entry.node.eulerAngles.y) * lerp
            remotes[id] = entry
        }
        _ = scene
    }

    private func syncMultiplayer(snapshot: RaceOnlineSnapshot) async {
        do {
            var snap = snapshot
            snap.lobbyId = lobbyId ?? ""
            let data = try await postMultiplayer(type: "update", snapshot: snap)
            guard data["enabled"] as? Bool != false else {
                statusLine = "ONLINE PLAY OFFLINE"
                return
            }
            let players = data["players"] as? [[String: Any]] ?? []
            applyRemotePlayers(players)
            nearbyRacerCount = players.count
            onlinePlayerCount = max(onlinePlayerCount, players.count + 1)
            statusLine = players.isEmpty
                ? (lobbyId == nil ? "ONLINE MULTIPLAYER READY" : "LIVE LOBBY · WAITING FOR RACERS")
                : "LIVE NEARBY: \(players.count)"
        } catch {
            statusLine = "ONLINE RECONNECTING…"
        }
    }

    private func applyRemotePlayers(_ players: [[String: Any]]) {
        guard let root = sceneRoot else { return }
        let now = Date().timeIntervalSinceReferenceDate
        var active = Set<String>()
        for p in players {
            guard let id = p["player_id"] as? String, id != KRCPlayerProfile.playerId else { continue }
            active.insert(id)
            let x = (p["x"] as? Double).map(Float.init) ?? 0
            let yRaw = (p["y"] as? Double).map(Float.init)
            let z = (p["z"] as? Double).map(Float.init) ?? 0
            let y = (yRaw ?? 0) > 0.01 ? (yRaw ?? 0.35) : 0.35
            let angle = (p["angle"] as? Double).map(Float.init) ?? 0
            let carId = p["car_id"] as? String ?? "gtr"
            let colorInt = (p["color_int"] as? Int) ?? 0x00d4ff
            let uiColor = UIColor(rgb: UInt32(max(0, min(0xffffff, colorInt))))

            if var entry = remotes[id] {
                entry.target = SIMD3(x, y, z)
                entry.angle = angle
                entry.lastSeen = now
                remotes[id] = entry
            } else {
                let carRoot = SCNNode()
                RaceCarGeometry.build(
                    root: carRoot,
                    bodyColor: uiColor,
                    carId: carId,
                    isPlayer: false,
                    category: GameCatalog.vehicleCategory(for: carId),
                    applyLivery: true
                )
                carRoot.scale = SCNVector3(0.96, 0.96, 0.96)
                tintGhost(carRoot)
                root.addChildNode(carRoot)
                remotes[id] = RemoteEntry(
                    node: carRoot,
                    target: SIMD3(x, y, z),
                    angle: angle,
                    lastSeen: now
                )
            }
            remotes[id]?.node.isHidden = false
        }
        for (id, entry) in remotes where !active.contains(id) || now - entry.lastSeen > 14 {
            entry.node.removeFromParentNode()
            remotes.removeValue(forKey: id)
        }
    }

    private func tintGhost(_ root: SCNNode) {
        root.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }
            geometry.materials = geometry.materials.map { m in
                let copy = m.copy() as? SCNMaterial ?? m
                copy.transparency = 0.28
                copy.isDoubleSided = true
                return copy
            }
        }
    }

    private func clearRemotes() {
        remotes.values.forEach { $0.node.removeFromParentNode() }
        remotes.removeAll()
        nearbyRacerCount = 0
    }

    private func clearLobbyLocal() {
        lobbyId = nil
        lobbyStartsAt = nil
        lobbyPlayers = []
        if matchmakingPhase != .idle {
            matchmakingPhase = .idle
        }
    }

    @discardableResult
    private func applyLobbyPayload(_ data: [String: Any]) -> Bool {
        guard let lobby = data["lobby"] as? [String: Any] else { return false }
        let id = (lobby["lobby_id"] as? String) ?? (lobby["lobbyId"] as? String)
        guard let id, !id.isEmpty else { return false }
        lobbyId = id
        if let starts = lobby["starts_at"] as? String ?? lobby["startsAt"] as? String {
            lobbyStartsAt = ISO8601DateFormatter.krc.date(from: starts) ?? parseFlexibleDate(starts)
        }
        if let serverNow = lobby["server_now_ms"] as? Double ?? (lobby["server_now_ms"] as? Int).map(Double.init)
            ?? lobby["serverNowMs"] as? Double {
            serverOffsetMs = serverNow - Date().timeIntervalSince1970 * 1000
        }
        let rows = data["players"] as? [[String: Any]] ?? []
        lobbyPlayers = rows.compactMap { row in
            guard let pid = row["player_id"] as? String else { return nil }
            return LiveLobbyPlayer(
                id: pid,
                name: row["player_name"] as? String ?? "KRC DRIVER",
                carName: row["car_name"] as? String ?? "KRC CAR",
                finishMs: row["finish_ms"] as? Int,
                position: row["position"] as? Int
            )
        }
        // Ensure local player is represented.
        if !lobbyPlayers.contains(where: { $0.id == KRCPlayerProfile.playerId }) {
            lobbyPlayers.insert(
                LiveLobbyPlayer(
                    id: KRCPlayerProfile.playerId,
                    name: KRCPlayerProfile.gamerName,
                    carName: "",
                    finishMs: nil,
                    position: nil
                ),
                at: 0
            )
        }
        return true
    }

    private func parseFlexibleDate(_ raw: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let d = f.date(from: raw) { return d }
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let d = f.date(from: raw) { return d }
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.date(from: raw)
    }

    private func applyGlobalPayload(_ data: [String: Any]) {
        if data["solo"] as? Bool == true {
            statusLine = "SOLO MODE"
            globalEnabled = false
            return
        }
        globalEnabled = data["enabled"] as? Bool ?? false
        if let stats = data["stats"] as? [String: Any] {
            let live = (stats["live_players"] as? Int) ?? (stats["active_players"] as? Int) ?? 0
            let players = (stats["players"] as? Int) ?? 0
            let races = (stats["races"] as? Int) ?? 0
            onlinePlayerCount = max(live, players, remotes.count)
            globalRaceCount = races
        }
        if globalEnabled {
            if case .racing = matchmakingPhase {
                // keep live race status
            } else if lobbyId == nil {
                statusLine = "GLOBAL ONLINE · \(onlinePlayerCount) PLAYER\(onlinePlayerCount == 1 ? "" : "S")"
            }
        } else {
            statusLine = "GLOBAL OFFLINE"
            if scoreboardMessage.isEmpty {
                scoreboardMessage = "Connect DATABASE_URL on the server to enable Neon scoreboard."
            }
        }
        if let rows = data["leaderboard"] as? [[String: Any]] {
            leaderboard = parseLeaderboard(rows)
        }
        if let rank = data["rank"] as? Int {
            lastSubmittedRank = rank
        }
    }

    private func parseLeaderboard(_ rows: [[String: Any]]) -> [GlobalLeaderboardEntry] {
        rows.enumerated().map { index, row in
            GlobalLeaderboardEntry(
                place: index + 1,
                playerName: row["player_name"] as? String ?? "KRC DRIVER",
                carName: row["car_name"] as? String ?? "KRC CAR",
                trackName: row["track_name"] as? String,
                totalMs: row["total_ms"] as? Int ?? 0
            )
        }
    }

    private func globalPayload(
        type: String,
        mode: String,
        trackKey: String,
        trackName: String = "",
        carName: String = "",
        carId: String = "",
        totalMs: Int64 = 0,
        position: Int = 0,
        racerCount: Int = 0
    ) -> [String: Any] {
        var body: [String: Any] = [
            "type": type,
            "playerId": KRCPlayerProfile.playerId,
            "playerName": KRCPlayerProfile.gamerName,
            "mode": mode,
            "trackKey": trackKey,
            "trackName": trackName,
            "carName": carName,
            "carId": carId,
        ]
        if type == "finish" {
            body["totalMs"] = totalMs
            body["position"] = position
            body["racerCount"] = racerCount
        }
        return body
    }

    private func postGlobal(body: [String: Any]) async throws -> [String: Any] {
        try await postJSON(path: "/api/global", body: body)
    }

    private func postMatchmaking(body: [String: Any]) async throws -> [String: Any] {
        try await postJSON(path: "/api/matchmaking", body: body)
    }

    private func postMultiplayer(type: String, snapshot: RaceOnlineSnapshot?) async throws -> [String: Any] {
        var body: [String: Any] = [
            "type": type,
            "playerId": KRCPlayerProfile.playerId,
            "playerName": KRCPlayerProfile.gamerName,
        ]
        if let snapshot {
            body.merge(snapshot.json) { _, new in new }
        }
        if let lobbyId {
            body["lobbyId"] = lobbyId
        }
        return try await postJSON(path: "/api/multiplayer", body: body)
    }

    private func postJSON(path: String, body: [String: Any]) async throws -> [String: Any] {
        let url = try apiURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func getJSON(path: String, queryItems: [URLQueryItem] = []) async throws -> [String: Any] {
        let url = try apiURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return json
    }

    private func apiURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        components.path = "/" + trimmed.split(separator: "?").first!.description
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }
}

struct RaceOnlineSnapshot {
    let carId: String
    let carName: String
    let colorInt: UInt32
    let cityThemeIndex: Int
    let trackIndex: Int
    let trackKey: String
    let mode: String
    let x: Float
    let y: Float
    let z: Float
    let angle: Float
    let speedKmh: Int
    let lap: Int
    let progress: Float
    var lobbyId: String = ""

    var json: [String: Any] {
        var body: [String: Any] = [
            "carId": carId,
            "carName": carName,
            "colorInt": Int(colorInt),
            "cityIdx": cityThemeIndex,
            "trackIdx": trackIndex,
            "trackKey": trackKey,
            "mode": mode,
            "x": Double(x),
            "y": Double(y),
            "z": Double(z),
            "angle": Double(angle),
            "speedKmh": speedKmh,
            "lap": lap,
            "progress": Double(progress),
        ]
        if !lobbyId.isEmpty {
            body["lobbyId"] = lobbyId
        }
        return body
    }
}

private extension ISO8601DateFormatter {
    static let krc: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        let r = CGFloat((rgb >> 16) & 0xff) / 255
        let g = CGFloat((rgb >> 8) & 0xff) / 255
        let b = CGFloat(rgb & 0xff) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
