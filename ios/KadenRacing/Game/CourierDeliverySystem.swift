import SceneKit
import simd
import UIKit

/// Package delivery / courier run with GPS trail, package kinds, job choice,
/// reverse-park bonus, night premium, rival courier, cargo capacity, and shift grades.
final class CourierDeliverySystem {

    struct JobOffer: Identifiable, Equatable {
        let id: Int
        let kind: CourierPackageKind
        let payout: Int64
        let distance: Float
        let title: String
        let detail: String
    }

    struct Snapshot {
        var deliveriesComplete: Int = 0
        var deliveryGoal: Int = 6
        var carryingPackage: Bool = false
        var cargoHeld: Int = 0
        var cargoCapacity: Int = 1
        var objectiveLabel: String = ""
        var objectiveProgress: Float = 0
        var objectiveComplete: Bool = false
        var timeRemaining: TimeInterval = 210
        var earnedCredits: Int64 = 0
        var nextPayout: Int64 = 0
        var streak: Int = 0
        var distanceToTarget: Float = 0
        var bearingToTarget: Float = 0
        var dwellProgress: Float = 0
        var inZone: Bool = false
        var approaching: Bool = false
        var urgency: Bool = false
        var packageKind: CourierPackageKind = .standard
        var speedMul: Float = 1
        var nightPremium: Bool = false
        var rivalThreat: Float = 0
        var reverseParkHint: Bool = false
        var awaitingJobChoice: Bool = false
        /// True while a pickup/drop route is locked — UI must never show the board.
        var routeLocked: Bool = false
        var jobOffers: [JobOffer] = []
        var shiftGrade: CourierShiftGrade = .c
        var gradeLabel: String = ""
        var toast: String?
        var sessionFinished: Bool = false
        var success: Bool = false
    }

    private struct Zone {
        let node: SCNNode
        let beacon: SCNNode
        let beam: SCNNode
        let pulse: SCNNode
        let worldX: Float
        let worldZ: Float
        let worldY: Float
        let radius: Float
        var active: Bool
    }

    private struct Job {
        let id: Int
        var pickup: Zone
        var dropoff: Zone
        var basePayout: Int64
        var kind: CourierPackageKind
        var completed: Bool = false
    }

    /// Hard route phases — dispatch board is only legal in `choosing`.
    private enum Phase: Equatable {
        case choosing
        case toPickup(jobId: Int)
        case toDrop(jobId: Int)
        case finished
    }

    private weak var root: SCNNode?
    private weak var carNode: SCNNode?
    private var track: ClosedTrackSpline!
    private var pool: [Job] = []
    private var phase: Phase = .choosing
    private var deliveriesDone = 0
    private var cargoHeld = 0
    private var dwell: Float = 0
    private var earned: Int64 = 0
    private var streak = 0
    private var maxStreak = 0
    private var lastDeliveryElapsed: TimeInterval = -999
    private var toast: String?
    private var toastTimer: Float = 0
    private var timeLimit: TimeInterval = 210
    private var elapsed: TimeInterval = 0
    private var finished = false
    private var goal = 6
    private var packageNode: SCNNode?
    private var navArrow: SCNNode?
    private var gpsRoot: SCNNode?
    private var rivalNode: SCNNode?
    private var rivalProgress: Float = 0
    private var approachAnnounced = false
    private var zoneEnterAnnounced = false
    private var animTime: Float = 0
    private var perfectStop = false
    private var reversePark = false
    private var damageCooldown: Float = 0
    private var damageEvents = 0
    private var perfectStops = 0
    private var reverseParks = 0
    private var rivalSteals = 0
    private var offers: [JobOffer] = []
    private var offerPoolIndex: [Int: Int] = [:]
    private var nextOfferId = 1
    private var nextJobId = 1
    private var careerMul: Float = 1
    private var cargoCapacity = 1
    private var nightPremium = false
    private var nightMul: Float = 1
    private var rng = SeededRandom(seed: 0xC0DE51)
    /// After load, player must leave the pickup pad before drop dwell can count.
    private var dropArmed = false
    /// Seconds since the package was loaded onto the van.
    private var carryElapsed: Float = 0
    private let lock = NSLock()

    /// Asphalt ribbon sits ~0.12 above the spline — same offset as race collectibles.
    private static let roadSurfaceY: Float = 0.12
    /// No rival / damage / drop until the van has been rolling with cargo this long.
    private static let carryGrace: Float = 4.0
    /// Drop pad must be this far from the pickup pad center to count.
    private static let minDropSeparation: Float = 28

    private var activeJobId: Int? {
        switch phase {
        case .toPickup(let id), .toDrop(let id): return id
        case .choosing, .finished: return nil
        }
    }

    private var carrying: Bool {
        if cargoHeld > 0 { return true }
        if case .toDrop = phase { return true }
        return false
    }

    private var routeLocked: Bool {
        if cargoHeld > 0 { return true }
        switch phase {
        case .toPickup, .toDrop: return true
        case .choosing, .finished: return false
        }
    }

    private var awaitingChoice: Bool {
        if routeLocked { return false }
        if case .choosing = phase { return !finished }
        return false
    }

    private func job(id: Int) -> Job? {
        pool.first(where: { $0.id == id })
    }

    private var activeJob: Job? {
        guard let id = activeJobId else { return nil }
        return job(id: id)
    }

    private(set) var snapshot = Snapshot()

    static let defaultTimeLimit: TimeInterval = 120
    static let defaultGoal = 3
    private var autoPickFirst = false

    func attach(
        to parent: SCNNode,
        track: ClosedTrackSpline,
        seed: UInt64,
        goal: Int = CourierDeliverySystem.defaultGoal,
        timeLimit: TimeInterval = CourierDeliverySystem.defaultTimeLimit,
        careerMul: Float = 1,
        cargoCapacity: Int = 1,
        nightPremium: Bool = false,
        timeBonus: TimeInterval = 0,
        autoPickFirst: Bool = true
    ) {
        detach()
        self.track = track
        self.autoPickFirst = autoPickFirst
        self.goal = max(2, min(8, goal))
        self.timeLimit = timeLimit + timeBonus
        self.careerMul = max(1, careerMul)
        self.cargoCapacity = max(1, min(3, cargoCapacity))
        self.nightPremium = nightPremium
        self.nightMul = nightPremium ? 1.22 : 1
        self.elapsed = 0
        self.finished = false
        self.phase = .choosing
        self.cargoHeld = 0
        self.dwell = 0
        self.dropArmed = false
        self.carryElapsed = 0
        self.earned = 0
        self.streak = 0
        self.maxStreak = 0
        self.deliveriesDone = 0
        self.lastDeliveryElapsed = -999
        self.damageEvents = 0
        self.perfectStops = 0
        self.reverseParks = 0
        self.rivalSteals = 0
        self.offers = []
        self.offerPoolIndex = [:]
        self.nextJobId = 1
        self.rivalProgress = 0
        self.rng = SeededRandom(seed: seed == 0 ? 0xC0DE51 : seed)

        let root = SCNNode()
        root.name = "krcCourier"
        parent.addChildNode(root)
        self.root = root

        // Build a pool of potential jobs around the district.
        let poolCount = max(goal + 4, 10)
        for i in 0..<poolCount {
            let pickT = (Float(i) + 0.07 + rng.float(in: 0...0.05)) / Float(poolCount)
            let dropT = (pickT + 0.18 + rng.float(in: 0.1...0.28)).truncatingRemainder(dividingBy: 1)
            let pickSide: Float = (i + rng.int(in: 0...1)) % 2 == 0 ? 1 : -1
            let dropSide: Float = -pickSide
            let kind = rollKind()
            let pickup = makeZone(
                trackT: pickT,
                lateral: pickSide * (RaceTrackMesh.halfWidth + 9 + rng.float(in: 0...7)),
                color: kind.accentUIColor,
                label: "PICKUP",
                active: false
            )
            let dropoff = makeZone(
                trackT: dropT,
                lateral: dropSide * (RaceTrackMesh.halfWidth + 11 + rng.float(in: 0...9)),
                color: UIColor(red: 0.15, green: 0.95, blue: 0.55, alpha: 1),
                label: "DROP",
                active: false
            )
            let dist = hypot(dropoff.worldX - pickup.worldX, dropoff.worldZ - pickup.worldZ)
            // Skip degenerate pairs so load can't immediately count as a drop.
            guard dist > 48 else { continue }
            let payout = Int64(Float(180 + min(300, dist * 0.45)) * kind.payoutMul * careerMul * nightMul)
            let jobId = nextJobId
            nextJobId += 1
            let job = Job(id: jobId, pickup: pickup, dropoff: dropoff, basePayout: payout, kind: kind)
            pool.append(job)
            root.addChildNode(pickup.node)
            root.addChildNode(dropoff.node)
        }
        // Guarantee enough jobs even if some pairs were skipped.
        var guardLoops = 0
        while pool.count < max(goal + 2, 8), guardLoops < 40 {
            guardLoops += 1
            let pickT = rng.float(in: 0...1)
            let dropT = (pickT + 0.28 + rng.float(in: 0.12...0.3)).truncatingRemainder(dividingBy: 1)
            let pickSide: Float = rng.int(in: 0...1) == 0 ? 1 : -1
            let kind = rollKind()
            let pickup = makeZone(
                trackT: pickT,
                lateral: pickSide * (RaceTrackMesh.halfWidth + 10 + rng.float(in: 0...6)),
                color: kind.accentUIColor,
                label: "PICKUP",
                active: false
            )
            let dropoff = makeZone(
                trackT: dropT,
                lateral: -pickSide * (RaceTrackMesh.halfWidth + 12 + rng.float(in: 0...8)),
                color: UIColor(red: 0.15, green: 0.95, blue: 0.55, alpha: 1),
                label: "DROP",
                active: false
            )
            let dist = hypot(dropoff.worldX - pickup.worldX, dropoff.worldZ - pickup.worldZ)
            guard dist > 48 else { continue }
            let payout = Int64(Float(180 + min(300, dist * 0.45)) * kind.payoutMul * careerMul * nightMul)
            let jobId = nextJobId
            nextJobId += 1
            pool.append(Job(id: jobId, pickup: pickup, dropoff: dropoff, basePayout: payout, kind: kind))
            root.addChildNode(pickup.node)
            root.addChildNode(dropoff.node)
        }

        let crate = makePackageVisual()
        crate.isHidden = true
        root.addChildNode(crate)
        packageNode = crate

        let arrow = makeNavArrow()
        root.addChildNode(arrow)
        navArrow = arrow

        let gps = SCNNode()
        gps.name = "krcCourierGPS"
        root.addChildNode(gps)
        gpsRoot = gps

        let rival = makeRivalNode()
        rival.isHidden = true
        root.addChildNode(rival)
        rivalNode = rival

        let nightTag = nightPremium ? " · NIGHT RATES" : ""
        presentJobOffers(count: autoPickFirst ? 1 : 3, first: true)
        if autoPickFirst, let first = offers.first {
            showToast("COURIER\(nightTag) — FOLLOW THE ARROW", duration: 2.0)
            selectOffer(id: first.id)
        } else {
            showToast("COURIER DISPATCH\(nightTag) — PICK A JOB", duration: 2.4)
        }
        refreshSnapshot(worldX: 0, worldZ: 0, heading: 0)
    }

    func bindCar(_ node: SCNNode) {
        carNode = node
    }

    func detach() {
        packageNode?.removeFromParentNode()
        navArrow?.removeFromParentNode()
        gpsRoot?.removeFromParentNode()
        rivalNode?.removeFromParentNode()
        root?.removeFromParentNode()
        root = nil
        carNode = nil
        packageNode = nil
        navArrow = nil
        gpsRoot = nil
        rivalNode = nil
        pool.removeAll()
        phase = .choosing
        offers = []
        offerPoolIndex = [:]
        snapshot = Snapshot()
        finished = false
        dropArmed = false
        carryElapsed = 0
        cargoHeld = 0
    }

    /// Player picks a dispatch offer while the shift is paused for choice.
    func selectOffer(id: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard case .choosing = phase, !finished else { return }
        guard let idx = offerPoolIndex[id], pool.indices.contains(idx), !pool[idx].completed else { return }

        let jobId = pool[idx].id
        offers = []
        offerPoolIndex = [:]
        dropArmed = false
        dwell = 0
        carryElapsed = 0
        setExclusiveRoute(jobId: jobId, pickupActive: true, dropActive: false)
        phase = .toPickup(jobId: jobId)
        rivalProgress = 0
        rivalNode?.isHidden = true
        showToast("\(pool[idx].kind.title) JOB — FOLLOW THE BEAM", duration: 1.7)
        refreshSnapshot(worldX: 0, worldZ: 0, heading: 0)
    }

    func update(
        dt: Float,
        worldX: Float,
        worldZ: Float,
        worldY: Float,
        heading: Float,
        speed: Float,
        impact: Float
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }

        // Job choice pauses the shift clock so picking isn't a tax.
        if case .choosing = phase {
            toastTimer = max(0, toastTimer - dt)
            if toastTimer <= 0 { toast = nil }
            animTime += dt
            pulseActiveZones(dt: dt)
            refreshSnapshot(worldX: worldX, worldZ: worldZ, heading: heading)
            return
        }

        elapsed += TimeInterval(dt)
        animTime += dt
        damageCooldown = max(0, damageCooldown - dt)
        toastTimer = max(0, toastTimer - dt)
        if toastTimer <= 0 { toast = nil }

        if timeLimit - elapsed <= 0 {
            finishSession(success: false)
            return
        }

        if deliveriesDone >= goal {
            finishSession(success: true)
            return
        }

        guard let jobId = activeJobId, let job = job(id: jobId) else {
            // Never reopen dispatch while cargo / a locked route is in progress.
            if routeLocked || cargoHeld > 0 {
                refreshSnapshot(worldX: worldX, worldZ: worldZ, heading: heading)
                return
            }
            if case .choosing = phase {
                refreshSnapshot(worldX: worldX, worldZ: worldZ, heading: heading)
                return
            }
            cargoHeld = 0
            detachPackageFromCar()
            dropArmed = false
            presentJobOffers(count: 3, first: false)
            refreshSnapshot(worldX: worldX, worldZ: worldZ, heading: heading)
            return
        }

        let isCarrying = carrying
        if isCarrying {
            carryElapsed += dt
        } else {
            carryElapsed = 0
        }
        let graceDone = carryElapsed >= Self.carryGrace

        // One job at a time: empty → pickup only; loaded → dropoff only.
        let target = isCarrying ? job.dropoff : job.pickup
        let dx = target.worldX - worldX
        let dz = target.worldZ - worldZ
        let dist = hypot(dx, dz)
        let bearingWorld = atan2(dx, dz)
        var relative = bearingWorld - heading
        while relative > Float.pi { relative -= 2 * Float.pi }
        while relative < -Float.pi { relative += 2 * Float.pi }

        // Arm drop only after leaving the pickup pad (prevents instant "delivered").
        let distFromPickup = hypot(job.pickup.worldX - worldX, job.pickup.worldZ - worldZ)
        if isCarrying, !dropArmed {
            if distFromPickup > job.pickup.radius + 8 {
                dropArmed = true
            }
        }

        let farEnoughFromPickup = distFromPickup > Self.minDropSeparation
        let inZone = dist < target.radius
            && (isCarrying ? (dropArmed && graceDone && farEnoughFromPickup) : true)
        let slowEnough = abs(speed) < 6.2
        let crawl = abs(speed) < 3.2
        let reversing = speed < -0.8

        if inZone && !zoneEnterAnnounced {
            zoneEnterAnnounced = true
            let tip = reversing ? "REVERSE PARK · HOLD" : (isCarrying ? "STOP · HOLD TO DELIVER" : "STOP · HOLD TO LOAD")
            showToast(tip, duration: 1.2)
            DispatchQueue.main.async {
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.55)
            }
        } else if !inZone {
            zoneEnterAnnounced = false
        }

        if dist < 55 && !approachAnnounced && !inZone {
            approachAnnounced = true
            showToast(isCarrying ? "DROP AHEAD" : "PICKUP AHEAD", duration: 1.1)
        } else if dist > 70 {
            approachAnnounced = false
        }

        // Fragile / general cargo damage — never during the post-load grace window.
        if isCarrying, graceDone, dropArmed, impact > 0.55, damageCooldown <= 0 {
            damageEvents += 1
            damageCooldown = 1.6
            streak = 0
            if job.kind == .fragile {
                let lost = Int64(Float(job.basePayout) * 0.45)
                earned = max(0, earned - lost)
                showToast("FRAGILE BROKEN −\(lost) KR", duration: 1.5)
                clearCargoAndOpenBoard(jobId: job.id, toastAlreadySet: true)
                DispatchQueue.main.async {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
                refreshSnapshot(worldX: worldX, worldZ: worldZ, heading: heading)
                return
            } else {
                let lost = Int64(40 + impact * 55)
                earned = max(0, earned - lost)
                showToast("PACKAGE DAMAGED −\(lost) KR", duration: 1.3)
                DispatchQueue.main.async {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }
        }

        // Rival only after grace + leaving the pickup — never the instant you load.
        if isCarrying, graceDone, dropArmed {
            updateRival(dt: dt, drop: job.dropoff, playerDist: dist)
            if rivalProgress >= 0.98 {
                rivalSteals += 1
                rivalNode?.isHidden = true
                rivalProgress = 0
                showToast("RIVAL STOLE THE DROP", duration: 1.8)
                clearCargoAndOpenBoard(jobId: job.id, toastAlreadySet: true)
                DispatchQueue.main.async {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
                refreshSnapshot(worldX: worldX, worldZ: worldZ, heading: heading)
                return
            }
        } else {
            rivalNode?.isHidden = true
            if !isCarrying { rivalProgress = 0 }
        }

        if inZone && slowEnough {
            if dwell <= 0.001 {
                perfectStop = crawl
                reversePark = reversing
            }
            if reversing { reversePark = true }
            let rate: Float = reversePark ? 1.7 : (perfectStop ? 1.5 : (crawl ? 1.25 : 1.0))
            dwell = min(1, dwell + dt * rate / 0.45)
            if dwell >= 1 {
                dwell = 0
                if !isCarrying {
                    cargoHeld = min(cargoCapacity, max(1, cargoHeld + 1))
                    dropArmed = false
                    carryElapsed = 0
                    offers = []
                    offerPoolIndex = [:]
                    setExclusiveRoute(jobId: job.id, pickupActive: false, dropActive: true)
                    phase = .toDrop(jobId: job.id)
                    approachAnnounced = false
                    zoneEnterAnnounced = false
                    attachPackageToCar(kind: job.kind)
                    rivalProgress = 0
                    rivalNode?.isHidden = true
                    showToast("\(job.kind.title) LOADED — HEAD TO DROP", duration: 1.7)
                    DispatchQueue.main.async {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    let drop = job.dropoff
                    let ndx = drop.worldX - worldX
                    let ndz = drop.worldZ - worldZ
                    let ndist = hypot(ndx, ndz)
                    var nrel = atan2(ndx, ndz) - heading
                    while nrel > Float.pi { nrel -= 2 * Float.pi }
                    while nrel < -Float.pi { nrel += 2 * Float.pi }
                    updateNavArrow(worldX: worldX, worldZ: worldZ, worldY: worldY, heading: heading, target: drop, relativeBearing: nrel)
                    updateGPSTrail(fromX: worldX, fromZ: worldZ, fromY: worldY, to: drop)
                    pulseActiveZones(dt: dt)
                    refreshSnapshot(
                        worldX: worldX,
                        worldZ: worldZ,
                        heading: heading,
                        distance: ndist,
                        bearing: nrel,
                        inZone: false
                    )
                    return
                } else {
                    if perfectStop { perfectStops += 1 }
                    if reversePark { reverseParks += 1 }
                    let payout = resolvePayout(base: job.basePayout, kind: job.kind)
                    deliveriesDone += 1
                    earned += payout
                    lastDeliveryElapsed = elapsed
                    showToast({
                        let tags = [
                            reversePark ? "REV PARK" : nil,
                            streak > 1 ? "\(streak)×" : nil,
                        ].compactMap { $0 }.joined(separator: " · ")
                        let suffix = tags.isEmpty ? "" : " · \(tags)"
                        return "DELIVERED +\(payout) KR\(suffix)"
                    }(), duration: 1.7)
                    approachAnnounced = false
                    zoneEnterAnnounced = false
                    dropArmed = false
                    rivalNode?.isHidden = true
                    rivalProgress = 0
                    DispatchQueue.main.async {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    clearCargoAndOpenBoard(jobId: job.id, toastAlreadySet: true, completed: true)
                    if deliveriesDone >= goal {
                        finishSession(success: true)
                        return
                    }
                    refreshSnapshot(worldX: worldX, worldZ: worldZ, heading: heading)
                    return
                }
            }
        } else {
            dwell = max(0, dwell - dt * 1.8)
            perfectStop = false
            reversePark = false
        }

        // Rush jobs burn extra clock while carrying.
        if isCarrying, job.kind == .rush {
            elapsed += TimeInterval(dt * 0.35)
        }

        updateNavArrow(worldX: worldX, worldZ: worldZ, worldY: worldY, heading: heading, target: target, relativeBearing: relative)
        updateGPSTrail(fromX: worldX, fromZ: worldZ, fromY: worldY, to: target)
        pulseActiveZones(dt: dt)
        refreshSnapshot(
            worldX: worldX,
            worldZ: worldZ,
            heading: heading,
            distance: dist,
            bearing: relative,
            inZone: inZone
        )
    }

    func finishBonusCredits() -> Int64 {
        var bonus = earned
        let grade = computeGrade()
        bonus = Int64(Float(bonus) * grade.bonusMul)
        if snapshot.success {
            bonus += 500
            bonus += Int64(max(0, snapshot.timeRemaining)) * 5
            if deliveriesDone >= goal { bonus += 250 }
        }
        bonus += Int64(deliveriesDone) * 35
        bonus += Int64(perfectStops) * 40
        bonus += Int64(reverseParks) * 55
        bonus += Int64(max(0, maxStreak - 1)) * 60
        bonus -= Int64(rivalSteals) * 80
        return max(0, bonus)
    }

    // MARK: - Offers

    private func presentJobOffers(count: Int, first: Bool) {
        // Hard rule: never reopen dispatch while a route/cargo is active.
        guard !finished else { return }
        if cargoHeld > 0 { return }
        if case .toDrop = phase { return }
        if case .toPickup = phase { return }

        phase = .choosing
        dropArmed = false
        dwell = 0
        carryElapsed = 0
        clearAllZoneActivity()
        offers = []
        offerPoolIndex = [:]
        let availableIndices = pool.indices.filter { !pool[$0].completed }
        guard !availableIndices.isEmpty else {
            finishSession(success: deliveriesDone > 0)
            return
        }
        var picks = availableIndices
        // Shuffle indices with seeded RNG.
        for i in stride(from: picks.count - 1, through: 1, by: -1) {
            let j = rng.int(in: 0...i)
            picks.swapAt(i, j)
        }
        let n = min(count, picks.count)
        for i in 0..<n {
            let poolIdx = picks[i]
            let job = pool[poolIdx]
            let id = nextOfferId
            nextOfferId += 1
            let dist = hypot(job.dropoff.worldX - job.pickup.worldX, job.dropoff.worldZ - job.pickup.worldZ)
            let offer = JobOffer(
                id: id,
                kind: job.kind,
                payout: job.basePayout,
                distance: dist,
                title: job.kind.title,
                detail: "\(job.kind.blurb) · \(Int(dist.rounded()))m"
            )
            offers.append(offer)
            offerPoolIndex[id] = poolIdx
            // Do not light pickup beams during choice — only the selected job gets a route.
        }
        if first {
            showToast("CHOOSE A JOB — \(offers.count) OFFERS", duration: 2.0)
        } else {
            showToast("NEXT JOB — PICK YOUR ROUTE", duration: 1.6)
        }
        refreshSnapshot(worldX: 0, worldZ: 0, heading: 0)
    }

    private func rollKind() -> CourierPackageKind {
        let roll = rng.int(in: 0...9)
        switch roll {
        case 0...3: return .standard
        case 4...5: return .fragile
        case 6...7: return .rush
        default: return .heavy
        }
    }

    private func resolvePayout(base: Int64, kind: CourierPackageKind) -> Int64 {
        let gap = elapsed - lastDeliveryElapsed
        if gap < 32 {
            streak = min(5, streak + 1)
        } else {
            streak = 1
        }
        maxStreak = max(maxStreak, streak)
        var mul: Float = 1 + Float(streak - 1) * 0.12
        if timeLimit - elapsed < 45 { mul += 0.18 }
        if perfectStop { mul += 0.1 }
        if reversePark { mul += 0.18 }
        if nightPremium { mul += 0.05 }
        _ = kind
        return Int64(Float(base) * mul)
    }

    private func computeGrade() -> CourierShiftGrade {
        var score = 40
        score += deliveriesDone * 8
        score += perfectStops * 6
        score += reverseParks * 8
        score += maxStreak * 5
        score += Int(max(0, timeLimit - elapsed) / 8)
        score -= damageEvents * 7
        score -= rivalSteals * 12
        if deliveriesDone >= goal { score += 15 }
        switch score {
        case 95...: return .s
        case 80..<95: return .a
        case 62..<80: return .b
        case 45..<62: return .c
        default: return .d
        }
    }

    /// Only one job may own an active pad/beam at a time.
    private func setExclusiveRoute(jobId: Int, pickupActive: Bool, dropActive: Bool) {
        for i in pool.indices {
            if pool[i].id == jobId {
                setActive(job: &pool[i], pickupActive: pickupActive, dropActive: dropActive)
            } else {
                setActive(job: &pool[i], pickupActive: false, dropActive: false)
            }
        }
    }

    private func markJobFinished(jobId: Int, completed: Bool) {
        if let idx = pool.firstIndex(where: { $0.id == jobId }) {
            pool[idx].completed = completed
            setActive(job: &pool[idx], pickupActive: false, dropActive: false)
        }
        clearAllZoneActivity()
        dropArmed = false
        carryElapsed = 0
        // Phase stays until clearCargoAndOpenBoard / finishSession moves it.
    }

    /// Clear cargo, retire the job, then open the board (or leave finished to the caller).
    private func clearCargoAndOpenBoard(jobId: Int, toastAlreadySet: Bool = false, completed: Bool = true) {
        cargoHeld = 0
        carryElapsed = 0
        dropArmed = false
        dwell = 0
        rivalProgress = 0
        rivalNode?.isHidden = true
        detachPackageFromCar()
        markJobFinished(jobId: jobId, completed: completed)
        if case .toPickup(let id) = phase, id == jobId { phase = .choosing }
        if case .toDrop(let id) = phase, id == jobId { phase = .choosing }
        guard !finished, deliveriesDone < goal else { return }
        if !toastAlreadySet {
            showToast("NEXT JOB — PICK YOUR ROUTE", duration: 1.4)
        }
        presentJobOffers(count: min(3, goal - deliveriesDone), first: false)
    }

    private func clearAllZoneActivity() {
        for i in pool.indices {
            setActive(job: &pool[i], pickupActive: false, dropActive: false)
        }
    }

    private func setActive(job: inout Job, pickupActive: Bool, dropActive: Bool) {
        job.pickup.active = pickupActive
        job.dropoff.active = dropActive
        applyZoneVisual(job.pickup)
        applyZoneVisual(job.dropoff)
    }

    private func applyZoneVisual(_ zone: Zone) {
        // Keep the parent opaque so building dressing stays readable when inactive.
        zone.node.opacity = 1
        zone.beacon.isHidden = !zone.active
        zone.beam.isHidden = !zone.active
        zone.pulse.isHidden = !zone.active
        zone.beam.opacity = zone.active ? 0.55 : 0
        if let pad = zone.node.childNode(withName: "krcCourierPad", recursively: false) {
            pad.opacity = zone.active ? 1 : 0.4
        }
        if let ring = zone.node.childNode(withName: "krcCourierRing", recursively: false) {
            ring.opacity = zone.active ? 1 : 0.25
        }
        if let light = zone.beacon.childNodes.first(where: { $0.light != nil })?.light {
            light.intensity = zone.active ? 900 : 0
        }
        if let sign = zone.node.childNode(withName: "krcCourierBaySign", recursively: true) {
            sign.opacity = zone.active ? 1 : 0.55
        }
    }

    private func finishSession(success: Bool) {
        finished = true
        phase = .finished
        cargoHeld = 0
        dropArmed = false
        detachPackageFromCar()
        navArrow?.isHidden = true
        gpsRoot?.isHidden = true
        rivalNode?.isHidden = true
        let grade = computeGrade()
        if success {
            showToast("SHIFT CLEAR · GRADE \(grade.rawValue)", duration: 2.6)
        } else {
            showToast("SHIFT OVER · GRADE \(grade.rawValue) · \(deliveriesDone)/\(goal)", duration: 2.6)
        }
        refreshSnapshot(worldX: 0, worldZ: 0, heading: 0, forceFinish: true, success: success)
    }

    private func refreshSnapshot(
        worldX: Float,
        worldZ: Float,
        heading: Float,
        distance: Float = 0,
        bearing: Float = 0,
        inZone: Bool = false,
        forceFinish: Bool = false,
        success: Bool = false
    ) {
        let grade = computeGrade()
        let kind = activeJob?.kind ?? .standard
        snapshot.deliveriesComplete = deliveriesDone
        snapshot.deliveryGoal = goal
        snapshot.carryingPackage = carrying
        snapshot.cargoHeld = cargoHeld
        snapshot.cargoCapacity = cargoCapacity
        snapshot.earnedCredits = earned
        snapshot.nextPayout = activeJob?.basePayout ?? offers.first?.payout ?? 0
        snapshot.streak = streak
        snapshot.distanceToTarget = distance
        snapshot.bearingToTarget = bearing
        snapshot.dwellProgress = dwell
        snapshot.inZone = inZone
        snapshot.approaching = distance > 0 && distance < 55 && !inZone
        snapshot.urgency = (timeLimit - elapsed) < 40
        snapshot.timeRemaining = max(0, timeLimit - elapsed)
        snapshot.packageKind = kind
        snapshot.speedMul = carrying ? kind.speedMul : 1
        snapshot.nightPremium = nightPremium
        snapshot.rivalThreat = carrying ? rivalProgress : 0
        snapshot.reverseParkHint = inZone && carrying
        snapshot.routeLocked = routeLocked
        // Board is only legal in choosing with empty cargo and no active route.
        let boardLegal = !finished && !routeLocked && cargoHeld == 0 && {
            if case .choosing = phase { return true }
            return false
        }()
        snapshot.awaitingJobChoice = boardLegal
        snapshot.jobOffers = boardLegal ? offers : []
        snapshot.shiftGrade = grade
        snapshot.gradeLabel = grade.title
        snapshot.toast = toast
        snapshot.sessionFinished = forceFinish || finished
        snapshot.success = forceFinish ? success : (finished && deliveriesDone >= goal)
        snapshot.objectiveComplete = deliveriesDone >= goal
        snapshot.objectiveProgress = Float(deliveriesDone) / Float(max(1, goal))

        if boardLegal {
            snapshot.objectiveLabel = "CHOOSE JOB · \(offers.count) OFFERS"
        } else if carrying {
            snapshot.objectiveLabel = "\(kind.title) DROP \(deliveriesDone)/\(goal) · \(Int(distance.rounded()))m"
        } else if deliveriesDone >= goal {
            snapshot.objectiveLabel = "ROUTE CLEAR \(deliveriesDone)/\(goal)"
        } else if let job = activeJob {
            snapshot.objectiveLabel = "\(job.kind.title) PICKUP · \(Int(distance.rounded()))m"
        } else {
            snapshot.objectiveLabel = "STAND BY"
        }
        _ = worldX
        _ = worldZ
        _ = heading
    }

    private func showToast(_ text: String, duration: Float = 1.4) {
        toast = text
        toastTimer = duration
    }

    // MARK: - Rival / GPS / visuals

    private func updateRival(dt: Float, drop: Zone, playerDist: Float) {
        guard let rival = rivalNode else { return }
        // Give the player time to leave the pad before the rival is a real threat.
        guard carryElapsed >= Self.carryGrace + 6 else {
            rival.isHidden = true
            return
        }
        rival.isHidden = false
        // Rival gains faster when player is far / slow — paced so a normal drive wins.
        let chase: Float = 0.028 + min(0.05, playerDist / 1200)
        rivalProgress = min(1, rivalProgress + dt * chase)
        let y = drop.worldY + 0.4
        // Approach drop from a side angle so they feel like another courier.
        let ang = animTime * 0.7
        let radius = (1 - rivalProgress) * max(18, playerDist * 0.55)
        rival.position = SCNVector3(
            drop.worldX + cos(ang) * radius,
            y,
            drop.worldZ + sin(ang) * radius
        )
        rival.eulerAngles.y = ang + Float.pi / 2
        rival.opacity = CGFloat(0.55 + rivalProgress * 0.4)
    }

    private func updateGPSTrail(fromX: Float, fromZ: Float, fromY: Float, to: Zone) {
        guard let gps = gpsRoot else { return }
        gps.childNodes.forEach { $0.removeFromParentNode() }
        guard !awaitingChoice, activeJob != nil else { return }

        let dx = to.worldX - fromX
        let dz = to.worldZ - fromZ
        let dist = hypot(dx, dz)
        guard dist > 4 else { return }
        let segments = min(28, max(8, Int(dist / 8)))
        let color = carrying
            ? UIColor(red: 0.2, green: 0.95, blue: 0.55, alpha: 1)
            : (activeJob?.kind.accentUIColor ?? UIColor.orange)

        for i in 0..<segments {
            let t0 = Float(i) / Float(segments)
            let t1 = Float(i + 1) / Float(segments)
            let x0 = fromX + dx * t0
            let z0 = fromZ + dz * t0
            let x1 = fromX + dx * t1
            let z1 = fromZ + dz * t1
            let mx = (x0 + x1) * 0.5
            let mz = (z0 + z1) * 0.5
            let segLen = hypot(x1 - x0, z1 - z0)
            let box = SCNBox(width: CGFloat(segLen), height: 0.08, length: 0.55, chamferRadius: 0.02)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = color.withAlphaComponent(0.55)
            mat.emission.contents = color
            mat.transparency = 0.35
            box.materials = [mat]
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(mx, fromY * 0.15 + to.worldY + 0.12, mz)
            node.eulerAngles.y = atan2(x1 - x0, z1 - z0) + Float.pi / 2
            // Pulse traveling light.
            let pulse = 0.45 + 0.4 * sin(animTime * 6 - Float(i) * 0.45)
            node.opacity = CGFloat(max(0.25, pulse))
            gps.addChildNode(node)
        }
    }

    private func pulseActiveZones(dt: Float) {
        _ = dt
        for job in pool {
            for zone in [job.pickup, job.dropoff] where zone.active {
                let s = 1 + 0.08 * sin(animTime * 4.2)
                zone.pulse.scale = SCNVector3(s, 1, s)
                zone.beam.opacity = CGFloat(0.35 + 0.25 * (0.5 + 0.5 * sin(animTime * 3.1)))
            }
        }
    }

    private func updateNavArrow(
        worldX: Float,
        worldZ: Float,
        worldY: Float,
        heading: Float,
        target: Zone,
        relativeBearing: Float
    ) {
        guard let arrow = navArrow else { return }
        arrow.isHidden = finished || awaitingChoice
        let fx = sin(heading)
        let fz = cos(heading)
        arrow.position = SCNVector3(worldX + fx * 4.2, worldY + 2.4, worldZ + fz * 4.2)
        arrow.eulerAngles.y = heading + relativeBearing
        arrow.position.y += 0.12 * sin(animTime * 5)
    }

    private func attachPackageToCar(kind: CourierPackageKind) {
        guard let crate = packageNode else { return }
        crate.removeFromParentNode()
        // Tint by kind.
        crate.enumerateChildNodes { node, _ in
            node.geometry?.materials.forEach { mat in
                if mat.lightingModel == .physicallyBased {
                    mat.emission.contents = kind.accentUIColor.withAlphaComponent(0.4)
                }
            }
        }
        if let car = carNode {
            car.addChildNode(crate)
            // Stack on the roof rack — keep clear of the chassis/road.
            let stack = Float(max(0, cargoHeld - 1))
            crate.position = SCNVector3(0, 1.35 + stack * 0.4, -0.2)
            crate.eulerAngles = SCNVector3(0, 0, 0)
        } else {
            root?.addChildNode(crate)
        }
        crate.isHidden = false
    }

    private func detachPackageFromCar() {
        guard let crate = packageNode else { return }
        crate.isHidden = true
        crate.removeFromParentNode()
        root?.addChildNode(crate)
    }

    private func makeZone(
        trackT: Float,
        lateral: Float,
        color: UIColor,
        label: String,
        active: Bool
    ) -> Zone {
        let p = track.sample(trackT)
        let tan = track.tangent(trackT)
        let forward = simd_normalize(SIMD3<Float>(tan.x, 0, tan.z))
        let right = SIMD3<Float>(forward.z, 0, -forward.x)
        let pos = p + right * lateral

        let node = SCNNode()
        node.name = "krcCourierZone_\(label)"
        // Sit on driving surface (asphalt/apron), not the raw spline under the ribbon.
        let surfaceY = p.y + Self.roadSurfaceY
        node.position = SCNVector3(pos.x, surfaceY + 0.02, pos.z)
        // Face building outward; pad sits in front of the façade toward the track.
        let outward = lateral >= 0 ? 1 : -1
        node.eulerAngles.y = atan2(right.x * Float(outward), right.z * Float(outward))

        let pad = SCNCylinder(radius: 5.6, height: 0.12)
        let padMat = SCNMaterial()
        padMat.lightingModel = .constant
        padMat.diffuse.contents = color.withAlphaComponent(0.5)
        padMat.emission.contents = color
        padMat.transparency = 0.5
        pad.materials = [padMat]
        let padNode = SCNNode(geometry: pad)
        padNode.name = "krcCourierPad"
        // Cylinder is centered — lift so the full disc sits above the surface.
        padNode.position = SCNVector3(0, 0.08, 0)
        node.addChildNode(padNode)

        let ring = SCNTube(innerRadius: 5.0, outerRadius: 5.5, height: 0.14)
        let ringMat = SCNMaterial()
        ringMat.lightingModel = .constant
        ringMat.diffuse.contents = UIColor.white.withAlphaComponent(0.85)
        ringMat.emission.contents = color
        ring.materials = [ringMat]
        let ringNode = SCNNode(geometry: ring)
        ringNode.name = "krcCourierRing"
        ringNode.position = SCNVector3(0, 0.16, 0)
        node.addChildNode(ringNode)

        let pulseGeo = SCNTube(innerRadius: 5.8, outerRadius: 6.3, height: 0.08)
        let pulseMat = SCNMaterial()
        pulseMat.lightingModel = .constant
        pulseMat.diffuse.contents = color.withAlphaComponent(0.35)
        pulseMat.emission.contents = color
        pulseMat.transparency = 0.65
        pulseGeo.materials = [pulseMat]
        let pulse = SCNNode(geometry: pulseGeo)
        pulse.position = SCNVector3(0, 0.2, 0)
        node.addChildNode(pulse)

        let beamGeo = SCNCylinder(radius: 0.55, height: 28)
        let beamMat = SCNMaterial()
        beamMat.lightingModel = .constant
        beamMat.diffuse.contents = color.withAlphaComponent(0.25)
        beamMat.emission.contents = color
        beamMat.transparency = 0.7
        beamMat.isDoubleSided = true
        beamGeo.materials = [beamMat]
        let beam = SCNNode(geometry: beamGeo)
        beam.position = SCNVector3(0, 14.2, 0)
        node.addChildNode(beam)

        let pole = SCNCylinder(radius: 0.14, height: 5.0)
        let poleMat = SCNMaterial()
        poleMat.lightingModel = .physicallyBased
        poleMat.diffuse.contents = UIColor(white: 0.16, alpha: 1)
        poleMat.metalness.contents = 0.75
        poleMat.roughness.contents = 0.3
        pole.materials = [poleMat]
        let beacon = SCNNode(geometry: pole)
        beacon.position = SCNVector3(0, 2.5, 0)
        node.addChildNode(beacon)

        let lamp = SCNSphere(radius: 0.42)
        let lampMat = SCNMaterial()
        lampMat.lightingModel = .constant
        lampMat.diffuse.contents = color
        lampMat.emission.contents = color
        lamp.materials = [lampMat]
        let lampNode = SCNNode(geometry: lamp)
        lampNode.position = SCNVector3(0, 2.7, 0)
        beacon.addChildNode(lampNode)

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.color = color
        light.light?.intensity = active ? 900 : 0
        light.light?.attenuationStartDistance = 1
        light.light?.attenuationEndDistance = 36
        light.position = SCNVector3(0, 2.8, 0)
        beacon.addChildNode(light)

        // Light building dressing — façade + bay behind the pad (local +Z = outward).
        let dressing = makeStopDressing(color: color, isPickup: label == "PICKUP")
        dressing.position = SCNVector3(0, 0, 7.2)
        node.addChildNode(dressing)

        let zone = Zone(
            node: node,
            beacon: beacon,
            beam: beam,
            pulse: pulse,
            worldX: pos.x,
            worldZ: pos.z,
            worldY: surfaceY,
            radius: 6.8,
            active: active
        )
        applyZoneVisual(zone)
        return zone
    }

    /// Cheap storefront / warehouse shell so stops feel like places, not floating rings.
    private func makeStopDressing(color: UIColor, isPickup: Bool) -> SCNNode {
        let root = SCNNode()
        root.name = "krcCourierDressing"

        let wallW: CGFloat = isPickup ? 14 : 12
        let wallH: CGFloat = isPickup ? 7.5 : 9.5
        let wallD: CGFloat = isPickup ? 4.2 : 5.5

        let wallColor = isPickup
            ? UIColor(red: 0.42, green: 0.38, blue: 0.34, alpha: 1)
            : UIColor(red: 0.28, green: 0.32, blue: 0.36, alpha: 1)

        let wall = SCNBox(width: wallW, height: wallH, length: wallD, chamferRadius: 0.08)
        let wallMat = SCNMaterial()
        wallMat.lightingModel = .physicallyBased
        wallMat.diffuse.contents = wallColor
        wallMat.roughness.contents = 0.78
        wallMat.metalness.contents = 0.08
        wall.materials = [wallMat]
        let wallNode = SCNNode(geometry: wall)
        wallNode.position = SCNVector3(0, Float(wallH) * 0.5, 0)
        wallNode.castsShadow = true
        root.addChildNode(wallNode)

        // Loading bay opening (dark inset on the track-facing face).
        let doorW: CGFloat = isPickup ? 5.5 : 4.2
        let doorH: CGFloat = isPickup ? 3.6 : 4.4
        let door = SCNBox(width: doorW, height: doorH, length: 0.35, chamferRadius: 0.04)
        let doorMat = SCNMaterial()
        doorMat.lightingModel = .constant
        doorMat.diffuse.contents = UIColor(white: 0.06, alpha: 1)
        doorMat.emission.contents = UIColor(white: 0.04, alpha: 1)
        door.materials = [doorMat]
        let doorNode = SCNNode(geometry: door)
        doorNode.position = SCNVector3(0, Float(doorH) * 0.5 + 0.15, -Float(wallD) * 0.5 - 0.05)
        root.addChildNode(doorNode)

        // Awning / canopy over the bay.
        let awning = SCNBox(width: doorW + 1.2, height: 0.18, length: 2.8, chamferRadius: 0.04)
        let awnMat = SCNMaterial()
        awnMat.lightingModel = .physicallyBased
        awnMat.diffuse.contents = color
        awnMat.emission.contents = color.withAlphaComponent(0.25)
        awnMat.roughness.contents = 0.45
        awning.materials = [awnMat]
        let awnNode = SCNNode(geometry: awning)
        awnNode.position = SCNVector3(0, Float(doorH) + 0.35, -Float(wallD) * 0.5 - 1.2)
        root.addChildNode(awnNode)

        // Neon / painted bay sign.
        let sign = SCNBox(width: isPickup ? 4.2 : 3.6, height: 0.7, length: 0.12, chamferRadius: 0.03)
        let signMat = SCNMaterial()
        signMat.lightingModel = .constant
        signMat.diffuse.contents = UIColor.black.withAlphaComponent(0.85)
        signMat.emission.contents = color.withAlphaComponent(0.7)
        sign.materials = [signMat]
        let signNode = SCNNode(geometry: sign)
        signNode.name = "krcCourierBaySign"
        signNode.position = SCNVector3(0, Float(wallH) - 1.1, -Float(wallD) * 0.5 - 0.08)
        root.addChildNode(signNode)

        // Window strip for shop feel on pickups; blank panels on warehouses.
        if isPickup {
            for i in -1...1 where i != 0 {
                let win = SCNBox(width: 1.6, height: 1.4, length: 0.1, chamferRadius: 0.02)
                let winMat = SCNMaterial()
                winMat.lightingModel = .constant
                winMat.diffuse.contents = UIColor(red: 0.55, green: 0.75, blue: 0.9, alpha: 0.85)
                winMat.emission.contents = UIColor(red: 0.35, green: 0.55, blue: 0.75, alpha: 0.35)
                win.materials = [winMat]
                let winNode = SCNNode(geometry: win)
                winNode.position = SCNVector3(Float(i) * 4.2, Float(wallH) * 0.55, -Float(wallD) * 0.5 - 0.06)
                root.addChildNode(winNode)
            }
        } else {
            for i in 0..<3 {
                let panel = SCNBox(width: 2.2, height: 1.1, length: 0.08, chamferRadius: 0.02)
                let panelMat = SCNMaterial()
                panelMat.lightingModel = .physicallyBased
                panelMat.diffuse.contents = UIColor(white: 0.22, alpha: 1)
                panelMat.metalness.contents = 0.55
                panelMat.roughness.contents = 0.4
                panel.materials = [panelMat]
                let panelNode = SCNNode(geometry: panel)
                panelNode.position = SCNVector3(Float(i - 1) * 3.0, Float(wallH) * 0.62, -Float(wallD) * 0.5 - 0.05)
                root.addChildNode(panelNode)
            }
        }

        // Dock crates beside the bay — sit on the pad surface, not under it.
        let cratePositions: [SIMD3<Float>] = [
            SIMD3(-4.2, 0.55, -2.2),
            SIMD3(-3.3, 0.55, -3.0),
            SIMD3(3.8, 0.65, -2.5),
            SIMD3(4.5, 0.45, -3.4),
        ]
        for (i, cp) in cratePositions.enumerated() {
            let size: Float = i % 2 == 0 ? 0.9 : 0.7
            let crate = SCNBox(
                width: CGFloat(size),
                height: CGFloat(size * 0.85),
                length: CGFloat(size * 1.1),
                chamferRadius: 0.04
            )
            let crateMat = SCNMaterial()
            crateMat.lightingModel = .physicallyBased
            crateMat.diffuse.contents = UIColor(red: 0.55, green: 0.38, blue: 0.18, alpha: 1)
            crateMat.roughness.contents = 0.7
            crate.materials = [crateMat]
            let crateNode = SCNNode(geometry: crate)
            crateNode.position = SCNVector3(cp.x, cp.y, cp.z)
            crateNode.eulerAngles.y = Float(i) * 0.35
            root.addChildNode(crateNode)
        }

        // Low curb / dock platform under the pad side of the façade.
        let dock = SCNBox(width: wallW * 0.92, height: 0.35, length: 3.2, chamferRadius: 0.04)
        let dockMat = SCNMaterial()
        dockMat.lightingModel = .physicallyBased
        dockMat.diffuse.contents = UIColor(white: 0.35, alpha: 1)
        dockMat.roughness.contents = 0.85
        dock.materials = [dockMat]
        let dockNode = SCNNode(geometry: dock)
        dockNode.position = SCNVector3(0, 0.18, -Float(wallD) * 0.25 - 1.0)
        root.addChildNode(dockNode)

        return root
    }

    private func makePackageVisual() -> SCNNode {
        let root = SCNNode()
        root.name = "krcCourierPackage"
        let box = SCNBox(width: 0.62, height: 0.44, length: 0.78, chamferRadius: 0.05)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(red: 0.78, green: 0.52, blue: 0.18, alpha: 1)
        mat.emission.contents = UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 0.3)
        mat.roughness.contents = 0.5
        box.materials = [mat]
        root.addChildNode(SCNNode(geometry: box))
        return root
    }

    private func makeNavArrow() -> SCNNode {
        let root = SCNNode()
        root.name = "krcCourierNav"
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor(red: 0.2, green: 0.95, blue: 1.0, alpha: 1)
        mat.emission.contents = UIColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1)
        let cone = SCNCone(topRadius: 0, bottomRadius: 0.45, height: 1.1)
        cone.materials = [mat]
        let coneNode = SCNNode(geometry: cone)
        coneNode.eulerAngles.x = Float.pi / 2
        root.addChildNode(coneNode)
        return root
    }

    private func makeRivalNode() -> SCNNode {
        let root = SCNNode()
        root.name = "krcCourierRival"
        let body = SCNBox(width: 1.8, height: 0.7, length: 3.6, chamferRadius: 0.12)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor(red: 1, green: 0.2, blue: 0.35, alpha: 0.7)
        mat.emission.contents = UIColor(red: 1, green: 0.15, blue: 0.3, alpha: 0.55)
        mat.transparency = 0.35
        body.materials = [mat]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position.y = 0.4
        root.addChildNode(bodyNode)
        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.color = UIColor.red
        light.light?.intensity = 400
        light.light?.attenuationEndDistance = 18
        light.position = SCNVector3(0, 1.2, 0)
        root.addChildNode(light)
        return root
    }
}

private extension Array {
    mutating func shuffle(using rng: inout SeededRandom) {
        guard count > 1 else { return }
        for i in stride(from: count - 1, through: 1, by: -1) {
            let j = rng.int(in: 0...i)
            swapAt(i, j)
        }
    }
}
