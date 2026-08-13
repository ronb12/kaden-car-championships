import Foundation
import SceneKit
import simd
import UIKit

/// Local personal-best ghost tape for Ghost Duel / Time Trial.
struct RaceGhostSample: Codable, Equatable {
    var elapsed: Float
    var trackT: Float
    var worldX: Float
    var worldY: Float
    var worldZ: Float
    var heading: Float
}

struct RaceGhostTape: Codable, Equatable {
    var trackKey: String
    var carId: String
    var totalTime: Float
    var samples: [RaceGhostSample]

    static func trackKey(trackIndex: Int, laps: Int) -> String {
        "t\(trackIndex)_l\(laps)"
    }
}

/// Last finished run on this device — the “beat Dad / sibling” ghost.
enum HouseGhostStore {
    private static let prefix = "krc.ghost.house."

    static func load(trackKey: String) -> RaceGhostTape? {
        let key = prefix + trackKey
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RaceGhostTape.self, from: data)
    }

    static func save(_ tape: RaceGhostTape) {
        guard tape.samples.count >= 8, tape.totalTime > 1 else { return }
        if let data = try? JSONEncoder().encode(tape) {
            UserDefaults.standard.set(data, forKey: prefix + tape.trackKey)
        }
    }
}

enum RaceGhostStore {
    private static let prefix = "krc.ghost.pb."

    static func load(trackKey: String) -> RaceGhostTape? {
        let key = prefix + trackKey
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RaceGhostTape.self, from: data)
    }

    static func saveIfBetter(_ tape: RaceGhostTape) {
        guard tape.samples.count >= 8, tape.totalTime > 1 else { return }
        if let existing = load(trackKey: tape.trackKey), existing.totalTime <= tape.totalTime {
            return
        }
        if let data = try? JSONEncoder().encode(tape) {
            UserDefaults.standard.set(data, forKey: prefix + tape.trackKey)
        }
    }
}

/// Records the player and plays back a translucent PB ghost.
final class RaceGhostController {
    private(set) var recording: [RaceGhostSample] = []
    private var ghostNode: SCNNode?
    private var playback: RaceGhostTape?
    private var recordAccum: Float = 0
    private let sampleHz: Float = 12
    private(set) var lastHouseDelta: TimeInterval?
    private(set) var racedHouseGhost = false

    func beginRecording() {
        recording.removeAll(keepingCapacity: true)
        recordAccum = 0
    }

    func attachPlaybackGhost(tape: RaceGhostTape?, into parent: SCNNode, bodyColor: UIColor) {
        ghostNode?.removeFromParentNode()
        ghostNode = nil
        playback = tape
        guard tape != nil else { return }

        let root = SCNNode()
        root.name = "krcHouseGhost"
        root.opacity = 0.48
        #if targetEnvironment(simulator)
        let body = SCNBox(width: 1.7, height: 0.55, length: 3.6, chamferRadius: 0.08)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = bodyColor.withAlphaComponent(0.85)
        mat.emission.contents = UIColor(red: 0.35, green: 0.85, blue: 1, alpha: 0.55)
        body.materials = [mat]
        root.geometry = body
        #else
        let shell = SCNBox(width: 1.65, height: 0.5, length: 3.5, chamferRadius: 0.1)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = bodyColor.withAlphaComponent(0.7)
        mat.emission.contents = UIColor(red: 0.2, green: 0.75, blue: 1, alpha: 0.45)
        mat.transparency = 0.55
        shell.materials = [mat]
        let shellNode = SCNNode(geometry: shell)
        shellNode.position.y = 0.35
        root.addChildNode(shellNode)
        #endif
        parent.addChildNode(root)
        ghostNode = root
    }

    func record(
        elapsed: Float,
        trackT: Float,
        worldX: Float,
        worldY: Float,
        worldZ: Float,
        heading: Float,
        dt: Float
    ) {
        recordAccum += dt
        let interval = 1 / sampleHz
        guard recordAccum >= interval else { return }
        recordAccum -= interval
        recording.append(
            RaceGhostSample(
                elapsed: elapsed,
                trackT: trackT,
                worldX: worldX,
                worldY: worldY,
                worldZ: worldZ,
                heading: heading
            )
        )
    }

    func updatePlayback(elapsed: Float) {
        guard let node = ghostNode, let tape = playback, !tape.samples.isEmpty else { return }
        let sample = interpolated(at: elapsed, in: tape.samples)
        node.position = SCNVector3(sample.worldX, sample.worldY, sample.worldZ)
        node.eulerAngles = SCNVector3(0, sample.heading, 0)
        node.isHidden = false
    }

    func finishTape(trackKey: String, carId: String, totalTime: Float) -> RaceGhostTape? {
        lastHouseDelta = nil
        racedHouseGhost = false
        guard recording.count >= 8 else { return nil }
        let tape = RaceGhostTape(
            trackKey: trackKey,
            carId: carId,
            totalTime: totalTime,
            samples: recording
        )
        if let existing = HouseGhostStore.load(trackKey: trackKey) {
            racedHouseGhost = true
            lastHouseDelta = TimeInterval(tape.totalTime - existing.totalTime)
        }
        HouseGhostStore.save(tape)
        RaceGhostStore.saveIfBetter(tape)
        return tape
    }

    private func interpolated(at elapsed: Float, in samples: [RaceGhostSample]) -> RaceGhostSample {
        if elapsed <= samples[0].elapsed { return samples[0] }
        if elapsed >= samples[samples.count - 1].elapsed { return samples[samples.count - 1] }
        var lo = 0
        var hi = samples.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if samples[mid].elapsed <= elapsed { lo = mid } else { hi = mid }
        }
        let a = samples[lo]
        let b = samples[hi]
        let span = max(0.0001, b.elapsed - a.elapsed)
        let u = (elapsed - a.elapsed) / span
        return RaceGhostSample(
            elapsed: elapsed,
            trackT: a.trackT + (b.trackT - a.trackT) * u,
            worldX: a.worldX + (b.worldX - a.worldX) * u,
            worldY: a.worldY + (b.worldY - a.worldY) * u,
            worldZ: a.worldZ + (b.worldZ - a.worldZ) * u,
            heading: a.heading + shortestAngle(b.heading - a.heading) * u
        )
    }

    private func shortestAngle(_ d: Float) -> Float {
        var x = d
        while x > Float.pi { x -= Float.pi * 2 }
        while x < -Float.pi { x += Float.pi * 2 }
        return x
    }
}
