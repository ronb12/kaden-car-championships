import SceneKit
import simd
import UIKit

/// CPU racers on the same spline as the player — unique cars per grid slot.
final class RaceOpponentController {

    struct Opponent {
        let name: String
        let carId: String
        let node: SCNNode
        var trackT: Float
        var lateral: Float
        var speed: Float
        var lap: Int
        var phase: Float
        var overtakeBias: Float
        var baseSpeedMul: Float
        var personality: VehicleSpawnPlanner.AIPersonality
        var brakeGlow: Float = 0
        var finished = false
        var busted = false
    }

    struct SpeedingTicket: Equatable, Identifiable {
        let id: UUID
        let driverName: String
        let carId: String
        let speedKmh: Int
        let speedLimitKmh: Int
        let fineCredits: Int64

        var headline: String {
            "TICKET · \(driverName)"
        }

        var detail: String {
            "\(speedKmh) km/h in \(speedLimitKmh) · FINE \(fineCredits) CR"
        }
    }

    private(set) var opponents: [Opponent] = []
    private let track: ClosedTrackSpline
    private let trackLength: Float
    private let maxLat: Float
    private let laneW: Float
    private let spawnSlots: [VehicleSpawnPlanner.OpponentSlot]
    /// When true, AI closes on the player instead of holding a race-pack gap.
    var pursuitMode = false
    /// When true, AI flees ahead of the player (Hot Pursuit interceptor — player hunts).
    var fleeMode = false
    /// Ghost rivals render translucent.
    var ghostMode = false
    private(set) var bustCount = 0
    private(set) var issuedTickets: [SpeedingTicket] = []
    /// Bust contact cooldown per opponent index.
    private var bustCooldown: [Float] = []

    // Competitive pack — paced like a real grid, not a rocket convoy.
    private static let difficultyBase: [Float] = [0.96, 1.0, 1.05]
    private static let speedCap: [Float] = [1.02, 1.08, 1.14]
    private static let cornerSlow: [Float] = [0.38, 0.32, 0.26]
    /// Fraction of lap between grid slots at spawn (spread so cars aren't stacked).
    private static let gridSpacing: Float = 0.028
    /// Tight 2-wide starting grid behind the line (circuit / career / championship).
    private static let startGridSpacing: Float = 0.010
    /// Soft leash — keep a pack fight without teleporting off-camera.
    private static let maxPackLead: Float = 0.07
    private static let maxPackTrail: Float = 0.06
    /// When the player is nearly stopped, AI cruise at this fraction of player top-track-rate.
    private static let idleCruiseFrac: Float = 0.28

    init(
        track: ClosedTrackSpline,
        playerCarIndex: Int,
        opponentCount: Int = 4,
        slots: [VehicleSpawnPlanner.OpponentSlot]? = nil
    ) {
        self.track = track
        maxLat = RaceTrackMesh.halfWidth - 1.2
        laneW = (RaceTrackMesh.halfWidth * 2) / RaceTrackMesh.laneCount
        spawnSlots = slots ?? VehicleSpawnPlanner.planOpponents(playerCarIndex: playerCarIndex, count: opponentCount)
        var len: Float = 0
        let samples = 128
        for i in 0..<samples {
            let a = track.sample(Float(i) / Float(samples))
            let b = track.sample(Float(i + 1) / Float(samples))
            len += simd_distance(a, b)
        }
        trackLength = max(len, 1)
    }

    func spawn(into parent: SCNNode, playerCarIndex: Int, count: Int = 4) {
        opponents.removeAll()
        let slots = Array(spawnSlots.prefix(min(count, spawnSlots.count)))
        for (i, slot) in slots.enumerated() {
            let root = SCNNode()
            let category = GameCatalog.vehicleCategory(for: slot.carId)
            let simScale: Float = 0.94
            let simColor = slot.bodyColor
            RaceCarGeometry.build(
                root: root,
                bodyColor: simColor,
                carId: slot.carId,
                scale: CGFloat(simScale),
                isPlayer: false,
                category: category,
                applyLivery: true,
                wheelStyle: slot.wheelStyle,
                lod: .opponent
            )
            root.castsShadow = true
            root.enumerateChildNodes { node, _ in node.castsShadow = true }
            if ghostMode {
                root.opacity = 0.42
                root.enumerateHierarchy { node, _ in
                    node.opacity = min(node.opacity, 0.45)
                }
            }
            parent.addChildNode(root)
            let bias = Float.random(in: slot.personality.overtakeBiasRange)
            let gridT: Float
            let lateral: Float
            if pursuitMode || slot.personality == .pursuit {
                // Spawn staggered BEHIND the player so they chase, not race each other ahead.
                gridT = -Self.gridSpacing * Float(i + 2) - Float(i) * 0.012
                lateral = laneW * (0.35 - Float(i) * 0.12) * (i % 2 == 0 ? 1 : -1)
            } else if fleeMode {
                // Suspects start ahead — you hunt them down.
                gridT = Self.gridSpacing * Float(i + 2) + Float(i) * 0.018
                lateral = laneW * (0.45 - Float(i) * 0.14) * (i % 2 == 0 ? -1 : 1)
            } else {
                // 2-wide starting grid at the line. Player is pole (slot 0, left lane).
                let slot = i + 1
                let row = slot / 2
                let col = slot % 2
                gridT = -Self.startGridSpacing * Float(row)
                lateral = laneW * 0.38 * (col == 0 ? -1 : 1)
            }
            opponents.append(Opponent(
                name: slot.name,
                carId: slot.carId,
                node: root,
                trackT: gridT,
                lateral: lateral,
                speed: 0.002,
                lap: 1,
                phase: Float.random(in: 0...(Float.pi * 2)),
                overtakeBias: bias,
                baseSpeedMul: slot.baseSpeedMul,
                personality: slot.personality
            ))
        }
        bustCooldown = Array(repeating: 0, count: opponents.count)
        bustCount = 0
        issuedTickets = []
        placeAll()
    }

    func update(
        dt: Float,
        playerTrackT: Float,
        playerLap: Int,
        playerTopLapSpeed: Float,
        playerWorldSpeed: Float = 0,
        playerMaxWorldSpeed: Float = 21,
        playerWorldX: Float = 0,
        playerWorldZ: Float = 0,
        playerHeading: Float = 0,
        difficultyIndex: Int,
        lapGoal: Int,
        headlightLevel: Float = 0
    ) {
        guard !opponents.isEmpty else { return }
        let headlightsOn = VehicleLighting.shouldEnableHeadlights(level: headlightLevel)
        let diff = min(max(difficultyIndex, 0), 2)
        let diffMul = Self.difficultyBase[diff]
        let capMul = Self.speedCap[diff]
        let cornerMul = Self.cornerSlow[diff]
        let playerT = playerTrackT.truncatingRemainder(dividingBy: 1)
        let playerProgress = raceProgress(lap: playerLap, t: playerT)

        // Convert world units/sec → track-parameter rate. Do NOT use VehicleDrivingSimulation.topLapSpeed
        // here (different unit system) — that made AI lap in ~12s and vanish off-camera.
        let livePlayerRate = max(0, abs(playerWorldSpeed) / trackLength)
        let playerTopRate = max(0.0001, abs(playerMaxWorldSpeed) / trackLength)
        var racePace = max(livePlayerRate * 0.9, playerTopRate * Self.idleCruiseFrac)
        racePace = min(racePace, playerTopRate * (0.98 + Float(diff) * 0.02))
        _ = playerTopLapSpeed
        _ = capMul

        // Player lateral vs track center — pursuit AI mirrors this lane.
        let playerSample = track.sample(playerT)
        let playerTan = track.tangent(playerT)
        let playerRight = SIMD3<Float>(playerTan.z, 0, -playerTan.x)
        let toPlayer = SIMD3<Float>(playerWorldX - playerSample.x, 0, playerWorldZ - playerSample.z)
        let playerLat = simd_dot(toPlayer, playerRight)

        for i in opponents.indices {
            var ai = opponents[i]
            if i < bustCooldown.count {
                bustCooldown[i] = max(0, bustCooldown[i] - dt)
            }
            if ai.finished || ai.busted {
                ai.node.isHidden = true
                opponents[i] = ai
                continue
            }
            ai.node.isHidden = false
            ai.node.opacity = ghostMode ? 0.42 : 1
            ai.phase += dt

            // Late-apex racing line — stay wide on entry, cut inside at the corner.
            var targetLat = ai.overtakeBias * (laneW * 0.32)
                + sin(ai.phase * 0.55 + Float(i) * 1.1) * (laneW * 0.18 + Float(diff) * 0.12)
            let aiProgress = raceProgress(lap: ai.lap, t: ai.trackT)
            let deltaProg = aiProgress - playerProgress
            // Soft preferred gap — pace nudge only, not hard slot lock.
            let preferredLead = Self.gridSpacing * Float(i + 1) * 1.15
            let slotError = (playerProgress + preferredLead) - aiProgress

            let tNorm = ai.trackT.truncatingRemainder(dividingBy: 1)
            let tApex = (tNorm + 0.038).truncatingRemainder(dividingBy: 1)
            let tExit = (tNorm + 0.062).truncatingRemainder(dividingBy: 1)
            let tan1 = track.tangent(tNorm)
            let tanApex = track.tangent(tApex)
            let tanExit = track.tangent(tExit)
            let nearCorner = max(0, min(1, 1 - simd_dot(simd_normalize(tan1), simd_normalize(tanApex))))
            let farCorner = max(0, min(1, 1 - simd_dot(simd_normalize(tan1), simd_normalize(tanExit))))
            let cornerPressure = max(nearCorner, farCorner * 0.72)
            // Late apex: wide on entry, dive inside as corner pressure peaks.
            let sideSign: Float = i % 2 == 0 ? -1 : 1
            let lateApex = sideSign * laneW * (0.16 + cornerPressure * 0.58)
            targetLat += lateApex
            if cornerPressure < 0.1 {
                targetLat += sin(ai.phase * 1.4) * laneW * 0.12
            }

            switch ai.personality {
            case .aggressive:
                if deltaProg < 0.12 { targetLat += laneW * 0.55 * (deltaProg < 0 ? 1 : -1) }
                if cornerPressure > 0.2 { targetLat *= 0.75 }
            case .blocker:
                // Sit in the racing line when the player is closing — forces a pass.
                if deltaProg > -0.08 && deltaProg < 0.1 {
                    targetLat = playerLat * 0.55 + (deltaProg > 0 ? -laneW * 0.7 : laneW * 0.35)
                }
            case .technical:
                targetLat = targetLat * max(0.65, 1 - cornerPressure * 0.5) + lateApex * 0.35
            case .balanced:
                if deltaProg > -0.06 && deltaProg < 0.09 {
                    targetLat += deltaProg > 0 ? -laneW * 0.55 : laneW * 0.55
                }
            case .pursuit:
                targetLat = playerLat * 0.85 + sin(ai.phase * 1.4 + Float(i)) * laneW * 0.12
            }

            if fleeMode {
                // Cut away from the interceptor when pressure is high.
                let evade = (playerLat >= 0 ? -1 : 1) * laneW * (deltaProg < 0.08 ? 0.85 : 0.35)
                targetLat = playerLat * 0.25 + evade + sin(ai.phase * 1.9 + Float(i)) * laneW * 0.2
            } else if pursuitMode || ai.personality == .pursuit {
                let pinch = (Float(i % 2 == 0 ? 1 : -1) * laneW * (0.08 + Float(i) * 0.04))
                targetLat = playerLat * 0.92 + pinch
            }

            targetLat = max(-maxLat, min(maxLat, targetLat))
            let steerRate = min(1, (3.2 - cornerPressure * 1.1) * dt)
            ai.lateral += (targetLat - ai.lateral) * steerRate

            let lanePressure = min(1, abs(targetLat - ai.lateral) / max(1, laneW * 0.55))
            let cornerFactor = max(0.62, 1 - cornerPressure * 8.0 - lanePressure * cornerMul)
            var targetSpeed = racePace * ai.baseSpeedMul * diffMul * cornerFactor

            if fleeMode {
                // Suspects flee ahead; panic when the interceptor closes.
                if deltaProg < -0.01 {
                    targetSpeed = playerTopRate * (1.20 + Float(diff) * 0.04) * ai.baseSpeedMul
                } else if deltaProg < 0.045 {
                    targetSpeed = playerTopRate * (1.12 + Float(diff) * 0.03) * ai.baseSpeedMul
                    targetSpeed = max(targetSpeed, livePlayerRate * 1.08)
                } else if deltaProg < 0.12 {
                    targetSpeed = max(livePlayerRate * 1.02, playerTopRate * 0.98) * ai.baseSpeedMul
                } else {
                    targetSpeed = racePace * 1.04 * ai.baseSpeedMul
                }
                targetSpeed *= max(0.68, 1 - cornerPressure * 0.38)
            } else if pursuitMode || ai.personality == .pursuit {
                if deltaProg < -0.04 {
                    let catchUp = 1.10 + Float(diff) * 0.05 + min(0.12, -deltaProg * 0.55)
                    targetSpeed = playerTopRate * catchUp * ai.baseSpeedMul
                    targetSpeed = max(targetSpeed, livePlayerRate * 1.12)
                } else if deltaProg < 0.01 {
                    targetSpeed = max(livePlayerRate * 1.04, playerTopRate * 0.98) * ai.baseSpeedMul
                } else if deltaProg < 0.035 {
                    targetSpeed = livePlayerRate * 0.96 * ai.baseSpeedMul
                } else {
                    targetSpeed = livePlayerRate * 0.72 * ai.baseSpeedMul
                }
                targetSpeed *= max(0.72, 1 - cornerPressure * 0.32)
            } else {
                // Mild rubber-band: pack stays visible and contestable from chase cam.
                targetSpeed += slotError * 0.38
                if deltaProg < -0.1 {
                    targetSpeed = max(targetSpeed, livePlayerRate * (0.92 + Float(diff) * 0.03))
                } else if deltaProg > 0.12 {
                    targetSpeed = min(targetSpeed, livePlayerRate * 0.94)
                }
                targetSpeed *= 1 + sin(ai.phase * 0.7) * 0.03
            }

            let speedFloor = racePace * (fleeMode ? 0.5 : (pursuitMode ? 0.35 : 0.55))
            let speedCeil: Float
            if fleeMode {
                speedCeil = playerTopRate * (1.24 + Float(diff) * 0.05)
            } else if pursuitMode {
                speedCeil = playerTopRate * (1.22 + Float(diff) * 0.04)
            } else {
                speedCeil = min(playerTopRate * 1.05, racePace * 1.12)
            }
            let prevSpeed = ai.speed
            ai.speed += (targetSpeed - ai.speed) * min(1, (fleeMode || pursuitMode ? 2.8 : 2.2) * dt)
            ai.speed = max(speedFloor, min(speedCeil, ai.speed))
            if fleeMode {
                if deltaProg > 0.2 {
                    ai.speed = min(ai.speed, racePace * 0.95)
                } else if deltaProg < -0.08 {
                    ai.speed = max(ai.speed, playerTopRate * 1.14)
                }
            } else if pursuitMode {
                if deltaProg > 0.06 {
                    ai.speed = min(ai.speed, max(0.0001, livePlayerRate * 0.7))
                } else if deltaProg < -0.18 {
                    ai.speed = max(ai.speed, playerTopRate * 1.12)
                }
            } else if deltaProg > Self.maxPackLead {
                ai.speed = min(ai.speed, racePace * 0.82)
            } else if deltaProg < -Self.maxPackTrail {
                ai.speed = max(ai.speed, racePace * 1.04)
            }
            ai.brakeGlow = max(
                min(1, (prevSpeed - ai.speed) * 700 + lanePressure * 0.4 + cornerPressure * 5),
                ai.brakeGlow * max(0, 1 - dt * 3.5)
            )

            let prevT = ai.trackT
            ai.trackT += ai.speed * dt
            let newProg = raceProgress(lap: ai.lap, t: ai.trackT)
            if fleeMode {
                if newProg - playerProgress > 0.22 {
                    applyProgress(&ai, playerProgress + 0.14 + Float(i) * 0.015)
                } else if playerProgress - newProg > 0.1 {
                    applyProgress(&ai, playerProgress + 0.04 + Float(i) * 0.01)
                }
            } else if pursuitMode {
                if newProg - playerProgress > 0.04 {
                    applyProgress(&ai, playerProgress + 0.015)
                } else if playerProgress - newProg > 0.22 {
                    applyProgress(&ai, playerProgress - 0.10 - Float(i) * 0.02)
                }
            } else {
                let leadCap = Self.maxPackLead * 1.15
                let trailCap = Self.maxPackTrail * 1.25
                if newProg - playerProgress > leadCap {
                    applyProgress(&ai, playerProgress + Self.maxPackLead)
                } else if playerProgress - newProg > trailCap {
                    applyProgress(&ai, playerProgress - Self.maxPackTrail * 0.7)
                }
            }
            let prevNorm = prevT.truncatingRemainder(dividingBy: 1)
            let currNorm = ai.trackT.truncatingRemainder(dividingBy: 1)
            if prevNorm > 0.88 && currNorm < 0.12 {
                ai.lap += 1
                if !fleeMode, ai.lap > lapGoal { ai.finished = true }
            }

            opponents[i] = ai
            placeOpponent(index: i)
            RaceCarGeometry.setBrakeLights(root: ai.node, amount: ai.brakeGlow)
            VehicleLighting.setHeadlights(
                on: ai.node,
                enabled: headlightsOn || pursuitMode,
                level: max(headlightLevel, pursuitMode ? 0.85 : 0) * 0.82,
                isPlayer: false
            )
            if ai.carId == "police" {
                VehicleLighting.updatePoliceFlashers(on: ai.node, time: Date().timeIntervalSinceReferenceDate + Double(i))
            }
            WheelAssembly.spinWheels(in: ai.node, speed: ai.speed * trackLength * 0.08, dt: dt)
        }
    }

    /// Contact bust — ram / pin a suspect, then issue a speeding ticket.
    @discardableResult
    func processInterceptorBusts(
        playerWorldX: Float,
        playerWorldZ: Float,
        radius: Float = 4.4,
        speedLimitKmh: Int = 100
    ) -> [SpeedingTicket] {
        guard fleeMode else { return [] }
        var tickets: [SpeedingTicket] = []
        let px = playerWorldX
        let pz = playerWorldZ
        for i in opponents.indices {
            var ai = opponents[i]
            guard !ai.busted, !ai.finished else { continue }
            if i < bustCooldown.count, bustCooldown[i] > 0 { continue }
            let dx = ai.node.position.x - px
            let dz = ai.node.position.z - pz
            let dist = sqrt(dx * dx + dz * dz)
            if dist <= radius {
                let speedKmh = max(
                    speedLimitKmh + 20,
                    Int((abs(ai.speed) * trackLength * OpenWorldDrivingSimulation.worldUnitsToKmh).rounded())
                )
                let over = max(0, speedKmh - speedLimitKmh)
                let fine = Int64(min(650, max(120, 90 + over * 4)))
                let ticket = SpeedingTicket(
                    id: UUID(),
                    driverName: ai.name,
                    carId: ai.carId,
                    speedKmh: speedKmh,
                    speedLimitKmh: speedLimitKmh,
                    fineCredits: fine
                )
                ai.busted = true
                ai.finished = true
                ai.node.isHidden = true
                opponents[i] = ai
                if i < bustCooldown.count { bustCooldown[i] = 1.2 }
                bustCount += 1
                issuedTickets.append(ticket)
                tickets.append(ticket)
            }
        }
        return tickets
    }

    /// 0…1 lock strength based on nearest active suspect distance.
    func interceptorLockStrength(playerWorldX: Float, playerWorldZ: Float) -> Float {
        guard fleeMode else { return 0 }
        var best: Float = 80
        for ai in opponents where !ai.busted && !ai.finished {
            let dx = ai.node.position.x - playerWorldX
            let dz = ai.node.position.z - playerWorldZ
            best = min(best, sqrt(dx * dx + dz * dz))
        }
        // Full lock inside ~6m, fades out by ~28m.
        return max(0, min(1, 1 - (best - 6) / 22))
    }

    var activeSuspectCount: Int {
        opponents.filter { !$0.busted && !$0.finished }.count
    }

    /// 0…1 Doppler pass-by intensity from nearest rival closing speed / proximity.
    func closestRelativeSpeed(playerWorldX: Float, playerWorldZ: Float, playerSpeed: Float) -> Float {
        var best: Float = 0
        for ai in opponents where !ai.finished && !ai.busted {
            let dx = ai.node.position.x - playerWorldX
            let dz = ai.node.position.z - playerWorldZ
            let dist = max(0.5, sqrt(dx * dx + dz * dz))
            guard dist < 18 else { continue }
            let rel = abs(ai.speed - playerSpeed)
            let proximity = max(0, 1 - dist / 18)
            let intensity = min(1, (rel / max(0.001, abs(playerSpeed) + 8)) * 1.8) * proximity
            best = max(best, intensity)
        }
        return best
    }

    private func placeAll() {
        for i in opponents.indices { placeOpponent(index: i) }
    }

    private func placeOpponent(index: Int) {
        let ai = opponents[index]
        let t = ai.trackT.truncatingRemainder(dividingBy: 1)
        let p = track.sample(t)
        let forward = track.tangent(t)
        let right = SIMD3<Float>(forward.z, 0, -forward.x)
        let pos = p + right * ai.lateral
        // Opponents also use seatOnContactPlane — sit on asphalt surface (+0.1 ribbon).
        let rideY: Float = 0.37
        ai.node.position = SCNVector3(pos.x, pos.y + rideY, pos.z)
        // Face along track tangent (not player heading) so cornering reads correctly.
        let horiz = max(0.001, simd_length(SIMD2(forward.x, forward.z)))
        let gradePitch = max(-0.26, min(0.26, -atan2(forward.y, horiz)))
        ai.node.eulerAngles = SCNVector3(gradePitch, atan2(forward.x, forward.z), 0)
        ai.node.isHidden = false
        ai.node.opacity = 1
        ai.node.scale = SCNVector3(1, 1, 1)
    }

    private func raceProgress(lap: Int, t: Float) -> Float {
        var ll = lap
        var tt = t
        // Negative trackT = still on the previous lap (pursuit spawn behind the player).
        while tt < 0 {
            tt += 1
            ll -= 1
        }
        tt = tt.truncatingRemainder(dividingBy: 1)
        if tt < 0 { tt += 1 }
        return Float(ll - 1) + tt
    }

    private func applyProgress(_ ai: inout Opponent, _ progress: Float) {
        let p = max(0, progress)
        ai.lap = max(1, Int(floor(p)) + 1)
        var t = p - Float(ai.lap - 1)
        if t < 0 { t += 1 }
        if t >= 1 { t = 0; ai.lap += 1 }
        ai.trackT = t
    }

    func playerPosition(playerLap: Int, playerTrackT: Float) -> Int {
        let playerProg = raceProgress(lap: playerLap, t: playerTrackT.truncatingRemainder(dividingBy: 1))
        var ahead = 0
        for ai in opponents where !ai.finished {
            if raceProgress(lap: ai.lap, t: ai.trackT.truncatingRemainder(dividingBy: 1)) > playerProg {
                ahead += 1
            }
        }
        return 1 + ahead
    }

    var activeRacerCount: Int { 1 + opponents.filter { !$0.finished }.count }
}
