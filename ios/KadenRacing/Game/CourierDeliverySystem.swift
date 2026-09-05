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
        var deliveryGoal: Int = 3
        var carryingPackage: Bool = false
        var cargoHeld: Int = 0
        var cargoCapacity: Int = 1
        var objectiveLabel: String = ""
        var objectiveProgress: Float = 0
        var objectiveComplete: Bool = false
        var timeRemaining: TimeInterval = 120
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
        var shiftGrade: CourierShiftGrade = .two
        var gradeLabel: String = ""
        /// Filled stars 1–5 for finish UI / rating checks.
        var gradeStars: Int = 2
        /// Compact glyph e.g. "★★☆☆☆".
        var gradeGlyph: String = "★★☆☆☆"
        var toast: String?
        var sessionFinished: Bool = false
        var success: Bool = false
        var rivalApproaching: Bool = false
        var coachHint: String = ""
        var maxStreak: Int = 0
        var rivalSteals: Int = 0
        var perfectStops: Int = 0
        /// Tips earned this shift (separate from base payout — the real-app dopamine loop).
        var tipsEarned: Int64 = 0
        /// Most recent customer tip amount (0 when idle).
        var lastTipAmount: Int64 = 0
        /// Stars the last customer left (1–5).
        var lastTipStars: Int = 0
        /// Seconds remaining to show the tip flash on the HUD.
        var tipFlashRemaining: Float = 0
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
        /// Shift clock when the package was loaded (for tip speed scoring).
        var pickedAt: TimeInterval = 0
        /// Crashes while this package was aboard.
        var carryImpacts: Int = 0
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
    private var timeLimit: TimeInterval = 120
    private var elapsed: TimeInterval = 0
    private var finished = false
    private var goal = 3
    private var packageNode: SCNNode?
    private var navArrow: SCNNode?
    private var gpsRoot: SCNNode?
    private var rivalNode: SCNNode?
    private var rivalProgress: Float = 0
    private var approachAnnounced = false
    private var zoneEnterAnnounced = false
    private var rivalWarned = false
    private var animTime: Float = 0
    private var perfectStop = false
    private var reversePark = false
    private var damageCooldown: Float = 0
    private var damageEvents = 0
    private var perfectStops = 0
    private var reverseParks = 0
    private var rivalSteals = 0
    private var tipsEarned: Int64 = 0
    private var lastTipAmount: Int64 = 0
    private var lastTipStars: Int = 0
    private var tipFlashRemaining: Float = 0
    private var offers: [JobOffer] = []
    private var offerPoolIndex: [Int: Int] = [:]
    private var nextOfferId = 1
    private var nextJobId = 1
    private var careerMul: Float = 1
    private var cargoCapacity = 1
    /// FIFO stack of loaded job ids — capacity > 1 can hold several packages.
    private var heldJobIds: [Int] = []
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
    private static var carryGrace: Float {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-qaCourierTip") { return 0.35 }
        #endif
        return 4.0
    }
    /// Drop pad must be this far from the pickup pad center to count.
    private static var minDropSeparation: Float {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-qaCourierTip") { return 12 }
        #endif
        return 28
    }

    private var activeJobId: Int? {
        switch phase {
        case .toPickup(let id), .toDrop(let id): return id
        case .choosing, .finished: return nil
        }
    }

    private var carrying: Bool {
        !heldJobIds.isEmpty || cargoHeld > 0
    }

    #if DEBUG
    /// Pad the QA tip probe should sit on right now.
    func debugActivePadWorld() -> (x: Float, z: Float, y: Float)? {
        lock.lock()
        defer { lock.unlock() }
        switch phase {
        case .toPickup(let id):
            guard let job = job(id: id) else { return nil }
            // Tip probe phase 0 needs the pickup; once cargo is aboard prefer the drop.
            if carrying, let held = primaryHeldJob {
                return (held.dropoff.worldX, held.dropoff.worldZ, held.dropoff.worldY)
            }
            return (job.pickup.worldX, job.pickup.worldZ, job.pickup.worldY)
        case .toDrop(let id):
            let j = primaryHeldJob ?? job(id: id)
            guard let drop = j?.dropoff else { return nil }
            return (drop.worldX, drop.worldZ, drop.worldY)
        default:
            return nil
        }
    }
    #endif

    private var routeLocked: Bool {
        switch phase {
        case .toPickup, .toDrop: return true
        case .choosing, .finished: return false
        }
    }

    private var awaitingChoice: Bool {
        if finished { return false }
        if case .choosing = phase { return true }
        return false
    }

    private func job(id: Int) -> Job? {
        pool.first(where: { $0.id == id })
    }

    private var activeJob: Job? {
        guard let id = activeJobId else { return nil }
        return job(id: id)
    }

    /// Drop target when cargo is aboard — first loaded package (FIFO).
    private var primaryHeldJob: Job? {
        guard let id = heldJobIds.first else { return nil }
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
        autoPickFirst: Bool = false
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
        self.heldJobIds = []
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
        self.tipsEarned = 0
        self.lastTipAmount = 0
        self.lastTipStars = 0
        self.tipFlashRemaining = 0
        self.offers = []
        self.offerPoolIndex = [:]
        self.nextJobId = 1
        self.rivalProgress = 0
        self.rivalWarned = false
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
                kind: kind,
                active: false
            )
            let dropoff = makeZone(
                trackT: dropT,
                lateral: dropSide * (RaceTrackMesh.halfWidth + 11 + rng.float(in: 0...9)),
                color: UIColor(red: 0.15, green: 0.95, blue: 0.55, alpha: 1),
                label: "DROP",
                kind: kind,
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
                kind: kind,
                active: false
            )
            let dropoff = makeZone(
                trackT: dropT,
                lateral: -pickSide * (RaceTrackMesh.halfWidth + 12 + rng.float(in: 0...8)),
                color: UIColor(red: 0.15, green: 0.95, blue: 0.55, alpha: 1),
                label: "DROP",
                kind: kind,
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
        heldJobIds = []
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
            tipFlashRemaining = max(0, tipFlashRemaining - dt)
            if tipFlashRemaining <= 0 {
                lastTipAmount = 0
                lastTipStars = 0
            }
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
        tipFlashRemaining = max(0, tipFlashRemaining - dt)
        if tipFlashRemaining <= 0 {
            lastTipAmount = 0
            lastTipStars = 0
        }

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
            heldJobIds = []
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

        // Resolve nav / interaction target. Chain mode (toPickup while carrying) allows
        // either loading the next pickup or dropping the primary held package.
        let interactingPickup: Bool
        let interactJob: Job
        let target: Zone
        if case .toPickup = phase {
            if isCarrying, let held = primaryHeldJob {
                let pickDist = hypot(job.pickup.worldX - worldX, job.pickup.worldZ - worldZ)
                let dropDist = hypot(held.dropoff.worldX - worldX, held.dropoff.worldZ - worldZ)
                let inPick = pickDist < job.pickup.radius
                let inDrop = dropDist < held.dropoff.radius
                if inDrop && !inPick {
                    interactingPickup = false
                    interactJob = held
                    target = held.dropoff
                } else if inPick {
                    interactingPickup = true
                    interactJob = job
                    target = job.pickup
                } else if dropDist < pickDist {
                    interactingPickup = false
                    interactJob = held
                    target = held.dropoff
                } else {
                    interactingPickup = true
                    interactJob = job
                    target = job.pickup
                }
            } else {
                interactingPickup = true
                interactJob = job
                target = job.pickup
            }
        } else {
            interactingPickup = false
            interactJob = primaryHeldJob ?? job
            target = interactJob.dropoff
        }

        let dx = target.worldX - worldX
        let dz = target.worldZ - worldZ
        let dist = hypot(dx, dz)
        let bearingWorld = atan2(dx, dz)
        var relative = bearingWorld - heading
        while relative > Float.pi { relative -= 2 * Float.pi }
        while relative < -Float.pi { relative += 2 * Float.pi }

        // Arm drop only after leaving the last loaded pickup pad.
        if isCarrying, !dropArmed, let lastId = heldJobIds.last, let lastJob = self.job(id: lastId) {
            let distFromLastPickup = hypot(lastJob.pickup.worldX - worldX, lastJob.pickup.worldZ - worldZ)
            if distFromLastPickup > lastJob.pickup.radius + 8 {
                dropArmed = true
            }
        }

        let distFromInteractPickup = hypot(interactJob.pickup.worldX - worldX, interactJob.pickup.worldZ - worldZ)
        let farEnoughFromPickup = distFromInteractPickup > Self.minDropSeparation
        let dropGate = dropArmed && graceDone && farEnoughFromPickup
        let inZone = dist < target.radius && (interactingPickup ? true : dropGate)
        let slowEnough = abs(speed) < 6.2
        let crawl = abs(speed) < 3.2
        let reversing = speed < -0.8

        if inZone && !zoneEnterAnnounced {
            zoneEnterAnnounced = true
            let tip = reversing
                ? "REVERSE PARK · HOLD"
                : (interactingPickup ? "STOP · HOLD TO LOAD" : "STOP · HOLD TO DELIVER")
            showToast(tip, duration: 1.2)
            DispatchQueue.main.async {
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.55)
            }
        } else if !inZone {
            zoneEnterAnnounced = false
        }

        if dist < 55 && !approachAnnounced && !inZone {
            approachAnnounced = true
            showToast(interactingPickup ? "PICKUP AHEAD" : "DROP AHEAD", duration: 1.1)
        } else if dist > 70 {
            approachAnnounced = false
        }

        // Fragile / general cargo damage — never during the post-load grace window.
        let fragileJob = primaryHeldJob ?? interactJob
        if isCarrying, graceDone, dropArmed, impact > 0.55, damageCooldown <= 0 {
            damageEvents += 1
            damageCooldown = 1.6
            streak = 0
            if let idx = pool.firstIndex(where: { $0.id == fragileJob.id }) {
                pool[idx].carryImpacts += 1
            }
            if fragileJob.kind == .fragile {
                let lost = Int64(Float(fragileJob.basePayout) * 0.45)
                earned = max(0, earned - lost)
                showToast("FRAGILE BROKEN −\(lost) KR", duration: 1.5)
                clearCargoAndOpenBoard(jobId: fragileJob.id, toastAlreadySet: true)
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
        let rivalDrop = primaryHeldJob?.dropoff ?? interactJob.dropoff
        if isCarrying, graceDone, dropArmed {
            let dropDist = hypot(rivalDrop.worldX - worldX, rivalDrop.worldZ - worldZ)
            updateRival(dt: dt, drop: rivalDrop, playerDist: dropDist)
            if rivalProgress >= 0.98 {
                rivalSteals += 1
                rivalNode?.isHidden = true
                rivalProgress = 0
                rivalWarned = false
                showToast("RIVAL STOLE THE DROP", duration: 1.8)
                clearCargoAndOpenBoard(jobId: (primaryHeldJob ?? interactJob).id, toastAlreadySet: true)
                DispatchQueue.main.async {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
                refreshSnapshot(worldX: worldX, worldZ: worldZ, heading: heading)
                return
            }
        } else {
            rivalNode?.isHidden = true
            if !isCarrying {
                rivalProgress = 0
                rivalWarned = false
            }
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
                if interactingPickup {
                    completePickup(job: interactJob, worldX: worldX, worldZ: worldZ, worldY: worldY, heading: heading, dt: dt)
                    return
                } else {
                    completeDrop(job: interactJob, worldX: worldX, worldZ: worldZ, heading: heading)
                    return
                }
            }
        } else {
            dwell = max(0, dwell - dt * 1.8)
            perfectStop = false
            reversePark = false
        }

        // Rush jobs burn extra clock while carrying.
        if isCarrying, (primaryHeldJob ?? interactJob).kind == .rush {
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

    /// Load a package onto the van — may auto-chain another pickup when capacity remains.
    private func completePickup(
        job: Job,
        worldX: Float,
        worldZ: Float,
        worldY: Float,
        heading: Float,
        dt: Float
    ) {
        if !heldJobIds.contains(job.id) {
            heldJobIds.append(job.id)
        }
        cargoHeld = heldJobIds.count
        dropArmed = false
        carryElapsed = 0
        offers = []
        offerPoolIndex = [:]
        approachAnnounced = false
        zoneEnterAnnounced = false
        rivalProgress = 0
        rivalWarned = false
        rivalNode?.isHidden = true
        if let idx = pool.firstIndex(where: { $0.id == job.id }) {
            pool[idx].pickedAt = elapsed
            pool[idx].carryImpacts = 0
        }
        attachPackageToCar(kind: job.kind)

        let canChain = heldJobIds.count < cargoCapacity
            && deliveriesDone + heldJobIds.count < goal
        let navTarget: Zone
        if canChain,
           let next = nearestUnusedJob(fromX: worldX, fromZ: worldZ, excluding: Set(heldJobIds)),
           let dropId = heldJobIds.first {
            setCargoRoute(pickupJobId: next.id, dropJobId: dropId)
            phase = .toPickup(jobId: next.id)
            showToast("CARGO \(cargoHeld)/\(cargoCapacity) — LOAD MORE OR DROP", duration: 1.8)
            // Nav toward closer of next pickup vs primary drop.
            let pickD = hypot(next.pickup.worldX - worldX, next.pickup.worldZ - worldZ)
            let dropD = hypot((primaryHeldJob ?? job).dropoff.worldX - worldX,
                              (primaryHeldJob ?? job).dropoff.worldZ - worldZ)
            navTarget = pickD <= dropD ? next.pickup : (primaryHeldJob ?? job).dropoff
        } else if let dropId = heldJobIds.first, let held = self.job(id: dropId) {
            setExclusiveRoute(jobId: dropId, pickupActive: false, dropActive: true)
            phase = .toDrop(jobId: dropId)
            showToast("\(job.kind.title) LOADED — HEAD TO DROP", duration: 1.7)
            navTarget = held.dropoff
        } else {
            setExclusiveRoute(jobId: job.id, pickupActive: false, dropActive: true)
            phase = .toDrop(jobId: job.id)
            showToast("\(job.kind.title) LOADED — HEAD TO DROP", duration: 1.7)
            navTarget = job.dropoff
        }

        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let ndx = navTarget.worldX - worldX
        let ndz = navTarget.worldZ - worldZ
        let ndist = hypot(ndx, ndz)
        var nrel = atan2(ndx, ndz) - heading
        while nrel > Float.pi { nrel -= 2 * Float.pi }
        while nrel < -Float.pi { nrel += 2 * Float.pi }
        updateNavArrow(worldX: worldX, worldZ: worldZ, worldY: worldY, heading: heading, target: navTarget, relativeBearing: nrel)
        updateGPSTrail(fromX: worldX, fromZ: worldZ, fromY: worldY, to: navTarget)
        pulseActiveZones(dt: dt)
        refreshSnapshot(
            worldX: worldX,
            worldZ: worldZ,
            heading: heading,
            distance: ndist,
            bearing: nrel,
            inZone: false
        )
    }

    /// Deliver the first held package (FIFO); keep rolling if more cargo remains.
    private func completeDrop(job: Job, worldX: Float, worldZ: Float, heading: Float) {
        if perfectStop { perfectStops += 1 }
        if reversePark { reverseParks += 1 }
        let payout = resolvePayout(base: job.basePayout, kind: job.kind)
        let tip = resolveCustomerTip(job: job)
        deliveriesDone += 1
        earned += payout + tip.amount
        tipsEarned += tip.amount
        lastTipAmount = tip.amount
        lastTipStars = tip.stars
        tipFlashRemaining = 3.2
        lastDeliveryElapsed = elapsed
        showToast({
            let tags = [
                reversePark ? "REV PARK" : nil,
                streak > 1 ? "\(streak)×" : nil,
            ].compactMap { $0 }.joined(separator: " · ")
            let tagBit = tags.isEmpty ? "" : " · \(tags)"
            if tip.amount > 0 {
                return "DELIVERED +\(payout) · TIP +\(tip.amount) \(tip.glyph)\(tagBit)"
            }
            return "DELIVERED +\(payout) KR · NO TIP\(tagBit)"
        }(), duration: 2.2)
        approachAnnounced = false
        zoneEnterAnnounced = false
        rivalNode?.isHidden = true
        rivalProgress = 0
        rivalWarned = false
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        if let idx = heldJobIds.firstIndex(of: job.id) {
            heldJobIds.remove(at: idx)
        } else if !heldJobIds.isEmpty {
            heldJobIds.removeFirst()
        }
        cargoHeld = heldJobIds.count
        markJobFinished(jobId: job.id, completed: true)

        if deliveriesDone >= goal {
            cargoHeld = 0
            heldJobIds = []
            detachPackageFromCar()
            finishSession(success: true)
            return
        }

        if let nextId = heldJobIds.first, let nextJob = self.job(id: nextId) {
            dropArmed = false
            carryElapsed = 0
            dwell = 0
            setExclusiveRoute(jobId: nextId, pickupActive: false, dropActive: true)
            phase = .toDrop(jobId: nextId)
            attachPackageToCar(kind: nextJob.kind)
            // Keep tip flash visible; secondary toast is shorter.
            showToast("NEXT DROP — \(nextJob.kind.title) · TIP +\(tip.amount)", duration: 1.6)
            refreshSnapshot(worldX: worldX, worldZ: worldZ, heading: heading)
            return
        }

        // heldJobIds already empty — open the board.
        cargoHeld = 0
        carryElapsed = 0
        dropArmed = false
        dwell = 0
        detachPackageFromCar()
        phase = .choosing
        presentJobOffers(count: min(3, goal - deliveriesDone), first: false)
        refreshSnapshot(worldX: worldX, worldZ: worldZ, heading: heading)
    }

    /// Real courier dopamine: customers tip based on speed, smooth arrival, and care.
    private func resolveCustomerTip(job: Job) -> (amount: Int64, stars: Int, glyph: String) {
        let live = pool.first(where: { $0.id == job.id }) ?? job
        let carrySecs = max(0, elapsed - (live.pickedAt > 0 ? live.pickedAt : elapsed))
        // Expected windows scale with package kind (rush is impatient).
        let fast: TimeInterval
        let ok: TimeInterval
        let slow: TimeInterval
        switch job.kind {
        case .rush:
            fast = 22; ok = 36; slow = 52
        case .heavy:
            fast = 40; ok = 58; slow = 80
        case .fragile:
            fast = 32; ok = 48; slow = 68
        case .standard:
            fast = 28; ok = 44; slow = 64
        }
        var stars = 3
        if carrySecs <= fast { stars = 5 }
        else if carrySecs <= ok { stars = 4 }
        else if carrySecs <= slow { stars = 3 }
        else if carrySecs <= slow + 20 { stars = 2 }
        else { stars = 1 }

        if reversePark { stars = min(5, stars + 1) }
        if perfectStop { stars = min(5, stars + 1) }
        stars = max(1, stars - live.carryImpacts)
        if streak >= 3 { stars = min(5, stars + 1) }

        let kindTip: Float
        switch job.kind {
        case .rush: kindTip = 1.35
        case .fragile: kindTip = 1.25
        case .heavy: kindTip = 1.15
        case .standard: kindTip = 1.0
        }
        let starMul = 0.10 + Float(stars) * 0.08
        var tip = Int64(Float(job.basePayout) * starMul * kindTip)
        if nightPremium { tip = Int64(Float(tip) * 1.12) }
        if stars <= 1 { tip = max(8, tip / 3) }
        let glyph = String(repeating: "★", count: stars) + String(repeating: "☆", count: 5 - stars)
        return (tip, stars, glyph)
    }

    private func nearestUnusedJob(fromX: Float, fromZ: Float, excluding: Set<Int>) -> Job? {
        var best: Job?
        var bestD = Float.greatestFiniteMagnitude
        for j in pool where !j.completed && !excluding.contains(j.id) {
            let d = hypot(j.pickup.worldX - fromX, j.pickup.worldZ - fromZ)
            if d < bestD {
                bestD = d
                best = j
            }
        }
        return best
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
        bonus += tipsEarned / 2
        bonus -= Int64(rivalSteals) * 80
        return max(0, bonus)
    }

    // MARK: - Offers

    private func presentJobOffers(count: Int, first: Bool) {
        // Hard rule: never reopen dispatch while a route/cargo is active.
        guard !finished else { return }
        if cargoHeld > 0 || !heldJobIds.isEmpty { return }
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
        if first, !autoPickFirst {
            showToast("DISPATCH — PICK A JOB (OR WAIT FOR GO)", duration: 2.2)
        } else if first {
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
        score += Int(min(20, tipsEarned / 40))
        score += Int(max(0, timeLimit - elapsed) / 8)
        score -= damageEvents * 7
        score -= rivalSteals * 12
        if deliveriesDone >= goal { score += 15 }
        return CourierShiftGrade.fromScore(score)
    }

    /// Light one pickup and one drop across possibly different jobs (multi-cargo chain).
    private func setCargoRoute(pickupJobId: Int?, dropJobId: Int?) {
        for i in pool.indices {
            let pick = pickupJobId != nil && pool[i].id == pickupJobId
            let drop = dropJobId != nil && pool[i].id == dropJobId
            setActive(job: &pool[i], pickupActive: pick, dropActive: drop)
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
        heldJobIds = []
        carryElapsed = 0
        dropArmed = false
        dwell = 0
        rivalProgress = 0
        rivalWarned = false
        rivalNode?.isHidden = true
        detachPackageFromCar()
        markJobFinished(jobId: jobId, completed: completed)
        if case .toPickup(let id) = phase, id == jobId { phase = .choosing }
        if case .toDrop(let id) = phase, id == jobId { phase = .choosing }
        // Any leftover route phase after a steal/break — force choosing.
        if case .toPickup = phase { phase = .choosing }
        if case .toDrop = phase { phase = .choosing }
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
        zone.node.opacity = 1
        zone.beacon.isHidden = !zone.active
        zone.beam.isHidden = !zone.active
        zone.pulse.isHidden = !zone.active
        zone.beam.opacity = zone.active ? (nightPremium ? 0.75 : 0.55) : 0
        if let pad = zone.node.childNode(withName: "krcCourierPad", recursively: false) {
            pad.opacity = zone.active ? 1 : 0.15
        }
        if let ring = zone.node.childNode(withName: "krcCourierRing", recursively: false) {
            ring.opacity = zone.active ? 1 : 0.25
        }
        if let dressing = zone.node.childNode(withName: "krcCourierDressing", recursively: false) {
            dressing.isHidden = !zone.active
        }
        let activeIntensity: CGFloat = nightPremium ? 1400 : 900
        if let light = zone.beacon.childNodes.first(where: { $0.light != nil })?.light {
            light.intensity = zone.active ? activeIntensity : 0
        }
        if let sign = zone.node.childNode(withName: "krcCourierBaySign", recursively: true) {
            sign.opacity = zone.active ? 1 : 0.55
        }
    }

    private func finishSession(success: Bool) {
        finished = true
        phase = .finished
        cargoHeld = 0
        heldJobIds = []
        dropArmed = false
        detachPackageFromCar()
        navArrow?.isHidden = true
        gpsRoot?.isHidden = true
        rivalNode?.isHidden = true
        let grade = computeGrade()
        if success {
            showToast("SHIFT CLEAR · \(grade.glyph)", duration: 2.6)
        } else if deliveriesDone > 0 {
            showToast("SHIFT CUT SHORT · \(deliveriesDone)/\(goal) · \(grade.glyph)", duration: 2.6)
        } else {
            showToast("SHIFT OVER · NO DROPS · \(grade.glyph)", duration: 2.6)
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
        let kind = (primaryHeldJob ?? activeJob)?.kind ?? .standard
        let rivalApproaching = rivalProgress > 0.35
        snapshot.deliveriesComplete = deliveriesDone
        snapshot.deliveryGoal = goal
        snapshot.carryingPackage = carrying
        snapshot.cargoHeld = cargoHeld
        snapshot.cargoCapacity = cargoCapacity
        snapshot.earnedCredits = earned
        snapshot.nextPayout = (primaryHeldJob ?? activeJob)?.basePayout ?? offers.first?.payout ?? 0
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
        // Board only when held empty and choosing — no mid-cargo dispatch.
        let boardLegal = !finished && !routeLocked && heldJobIds.isEmpty && cargoHeld == 0 && {
            if case .choosing = phase { return true }
            return false
        }()
        snapshot.awaitingJobChoice = boardLegal
        snapshot.jobOffers = boardLegal ? offers : []
        snapshot.shiftGrade = grade
        snapshot.gradeLabel = grade.title
        snapshot.gradeStars = grade.stars
        snapshot.gradeGlyph = grade.glyph
        snapshot.maxStreak = maxStreak
        snapshot.rivalSteals = rivalSteals
        snapshot.perfectStops = perfectStops
        snapshot.tipsEarned = tipsEarned
        snapshot.lastTipAmount = tipFlashRemaining > 0 ? lastTipAmount : 0
        snapshot.lastTipStars = tipFlashRemaining > 0 ? lastTipStars : 0
        snapshot.tipFlashRemaining = tipFlashRemaining
        snapshot.rivalApproaching = rivalApproaching
        if tipFlashRemaining > 0.4, lastTipAmount > 0 {
            snapshot.coachHint = "TIP +\(lastTipAmount) · \(String(repeating: "★", count: lastTipStars))"
        } else if snapshot.reverseParkHint {
            snapshot.coachHint = "REVERSE PARK +18%"
        } else if kind == .fragile && carrying {
            snapshot.coachHint = "NO CRASHES"
        } else if kind == .heavy && carrying {
            snapshot.coachHint = "HEAVY — SLOWER"
        } else if rivalApproaching {
            snapshot.coachHint = "RIVAL CLOSING IN"
        } else {
            snapshot.coachHint = ""
        }
        snapshot.toast = toast
        snapshot.sessionFinished = forceFinish || finished
        snapshot.success = forceFinish ? success : (finished && deliveriesDone >= goal)
        snapshot.objectiveComplete = deliveriesDone >= goal
        snapshot.objectiveProgress = Float(deliveriesDone) / Float(max(1, goal))

        let cargoTag = cargoHeld > 1 ? " · CARGO \(cargoHeld)/\(cargoCapacity)" : ""
        if boardLegal {
            snapshot.objectiveLabel = "CHOOSE JOB · \(offers.count) OFFERS"
        } else if carrying {
            snapshot.objectiveLabel = "\(kind.title) DROP \(deliveriesDone)/\(goal)\(cargoTag) · \(Int(distance.rounded()))m"
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
        let prev = rivalProgress
        rivalProgress = min(1, rivalProgress + dt * chase)
        if !rivalWarned, prev < 0.4, rivalProgress >= 0.4 {
            rivalWarned = true
            showToast("RIVAL CLOSING — HURRY", duration: 1.5)
        }
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

    private func nearestTrackT(x: Float, z: Float) -> Float {
        let pts = track.points
        guard !pts.isEmpty else { return 0 }
        var bestIdx = 0
        var bestD = Float.greatestFiniteMagnitude
        for i in pts.indices {
            let p = pts[i]
            let d = hypot(p.x - x, p.z - z)
            if d < bestD {
                bestD = d
                bestIdx = i
            }
        }
        return Float(bestIdx) / Float(pts.count)
    }

    private func updateGPSTrail(fromX: Float, fromZ: Float, fromY: Float, to: Zone) {
        guard let gps = gpsRoot else { return }
        gps.childNodes.forEach { $0.removeFromParentNode() }
        guard !awaitingChoice, activeJob != nil || !heldJobIds.isEmpty else { return }

        let straightDist = hypot(to.worldX - fromX, to.worldZ - fromZ)
        guard straightDist > 4 else { return }

        let fromT = nearestTrackT(x: fromX, z: fromZ)
        let toT = nearestTrackT(x: to.worldX, z: to.worldZ)
        var fwd = (toT - fromT).truncatingRemainder(dividingBy: 1)
        if fwd < 0 { fwd += 1 }
        // Shortest arc on the loop (forward or back along track-T).
        let dir: Float = fwd <= 0.5 ? 1 : -1
        let absSpan: Float = fwd <= 0.5 ? fwd : (1 - fwd)

        let segments = min(28, max(8, Int(straightDist / 8)))
        let color = carrying
            ? UIColor(red: 0.2, green: 0.95, blue: 0.55, alpha: 1)
            : ((primaryHeldJob ?? activeJob)?.kind.accentUIColor ?? UIColor.orange)
        let padBlendStart = max(0, segments - 4)

        var points: [(x: Float, y: Float, z: Float)] = []
        points.reserveCapacity(segments + 1)
        for i in 0...segments {
            let u = Float(i) / Float(segments)
            if i >= padBlendStart {
                let trackU = Float(padBlendStart) / Float(segments)
                var t = (fromT + dir * absSpan * trackU).truncatingRemainder(dividingBy: 1)
                if t < 0 { t += 1 }
                let sp = track.sample(t)
                let blend = Float(i - padBlendStart) / Float(max(1, segments - padBlendStart))
                points.append((
                    sp.x + (to.worldX - sp.x) * blend,
                    sp.y + Self.roadSurfaceY + (to.worldY - (sp.y + Self.roadSurfaceY)) * blend,
                    sp.z + (to.worldZ - sp.z) * blend
                ))
            } else {
                var t = (fromT + dir * absSpan * u).truncatingRemainder(dividingBy: 1)
                if t < 0 { t += 1 }
                let sp = track.sample(t)
                points.append((sp.x, sp.y + Self.roadSurfaceY, sp.z))
            }
        }

        for i in 0..<segments {
            let a = points[i]
            let b = points[i + 1]
            let segLen = hypot(b.x - a.x, b.z - a.z)
            guard segLen > 0.05 else { continue }
            let box = SCNBox(width: CGFloat(segLen), height: 0.08, length: 0.55, chamferRadius: 0.02)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = color.withAlphaComponent(0.55)
            mat.emission.contents = color
            mat.transparency = 0.35
            box.materials = [mat]
            let node = SCNNode(geometry: box)
            node.position = SCNVector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5 + 0.12, (a.z + b.z) * 0.5)
            node.eulerAngles.y = atan2(b.x - a.x, b.z - a.z) + Float.pi / 2
            let pulse = 0.45 + 0.4 * sin(animTime * 6 - Float(i) * 0.45)
            node.opacity = CGFloat(max(0.25, pulse))
            gps.addChildNode(node)
        }
        _ = fromY
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
        let stack = Float(max(0, cargoHeld - 1))
        let scale: Float = 1 + stack * 0.18
        crate.scale = SCNVector3(scale, scale * (1 + stack * 0.12), scale)
        if let car = carNode {
            car.addChildNode(crate)
            // Stack on the roof rack — keep clear of the chassis/road.
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
        crate.scale = SCNVector3(1, 1, 1)
        crate.removeFromParentNode()
        root?.addChildNode(crate)
    }

    private func makeZone(
        trackT: Float,
        lateral: Float,
        color: UIColor,
        label: String,
        kind: CourierPackageKind,
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
        beamMat.diffuse.contents = color.withAlphaComponent(nightPremium ? 0.4 : 0.25)
        beamMat.emission.contents = color
        beamMat.transparency = nightPremium ? 0.55 : 0.7
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
        light.light?.intensity = active ? (nightPremium ? 1400 : 900) : 0
        light.light?.attenuationStartDistance = 1
        light.light?.attenuationEndDistance = nightPremium ? 48 : 36
        light.position = SCNVector3(0, 2.8, 0)
        beacon.addChildNode(light)

        // Light building dressing — façade + bay behind the pad (local +Z = outward).
        let dressing = makeStopDressing(color: color, isPickup: label == "PICKUP", kind: kind)
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
    private func makeStopDressing(color: UIColor, isPickup: Bool, kind: CourierPackageKind) -> SCNNode {
        let root = SCNNode()
        root.name = "krcCourierDressing"

        // Kind silhouette: fragile = glass-blue windows; rush = taller neon fin;
        // heavy = wider dock; standard = baseline shop/warehouse.
        var wallW: CGFloat = isPickup ? 14 : 12
        var wallH: CGFloat = isPickup ? 7.5 : 9.5
        var wallD: CGFloat = isPickup ? 4.2 : 5.5
        switch kind {
        case .fragile:
            wallW = isPickup ? 13 : 11
            wallH = isPickup ? 8.2 : 10
        case .rush:
            wallH = isPickup ? 9.5 : 12
            wallD = isPickup ? 3.8 : 5.0
        case .heavy:
            wallW = isPickup ? 18 : 16
            wallD = isPickup ? 5.5 : 7.0
        case .standard:
            break
        }

        let wallColor: UIColor
        switch kind {
        case .fragile:
            wallColor = UIColor(red: 0.55, green: 0.72, blue: 0.82, alpha: 1)
        case .rush:
            wallColor = isPickup
                ? UIColor(red: 0.38, green: 0.28, blue: 0.30, alpha: 1)
                : UIColor(red: 0.32, green: 0.22, blue: 0.26, alpha: 1)
        case .heavy:
            wallColor = UIColor(red: 0.24, green: 0.24, blue: 0.28, alpha: 1)
        case .standard:
            wallColor = isPickup
                ? UIColor(red: 0.42, green: 0.38, blue: 0.34, alpha: 1)
                : UIColor(red: 0.28, green: 0.32, blue: 0.36, alpha: 1)
        }

        let wall = SCNBox(width: wallW, height: wallH, length: wallD, chamferRadius: 0.08)
        let wallMat = SCNMaterial()
        wallMat.lightingModel = .physicallyBased
        wallMat.diffuse.contents = wallColor
        wallMat.roughness.contents = kind == .fragile ? 0.35 : 0.78
        wallMat.metalness.contents = kind == .fragile ? 0.35 : 0.08
        wall.materials = [wallMat]
        let wallNode = SCNNode(geometry: wall)
        wallNode.position = SCNVector3(0, Float(wallH) * 0.5, 0)
        wallNode.castsShadow = true
        root.addChildNode(wallNode)

        // Loading bay opening (dark inset on the track-facing face).
        let doorW: CGFloat = kind == .heavy ? (isPickup ? 7.5 : 6.0) : (isPickup ? 5.5 : 4.2)
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

        // Rush: tall neon fin on the roof.
        if kind == .rush {
            let fin = SCNBox(width: 0.35, height: wallH * 0.55, length: 1.8, chamferRadius: 0.04)
            let finMat = SCNMaterial()
            finMat.lightingModel = .constant
            finMat.diffuse.contents = color
            finMat.emission.contents = color
            fin.materials = [finMat]
            let finNode = SCNNode(geometry: fin)
            finNode.position = SCNVector3(Float(wallW) * 0.35, Float(wallH) + Float(wallH) * 0.2, 0)
            root.addChildNode(finNode)
        }

        // Window strip — fragile gets glass-blue panes; pickups get shop windows; warehouses get panels.
        if kind == .fragile {
            for i in -2...2 {
                let win = SCNBox(width: 1.8, height: 2.2, length: 0.12, chamferRadius: 0.02)
                let winMat = SCNMaterial()
                winMat.lightingModel = .constant
                winMat.diffuse.contents = UIColor(red: 0.45, green: 0.85, blue: 1.0, alpha: 0.75)
                winMat.emission.contents = UIColor(red: 0.35, green: 0.7, blue: 0.95, alpha: 0.55)
                win.materials = [winMat]
                let winNode = SCNNode(geometry: win)
                winNode.position = SCNVector3(Float(i) * 2.4, Float(wallH) * 0.5, -Float(wallD) * 0.5 - 0.06)
                root.addChildNode(winNode)
            }
        } else if isPickup {
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

        // Low curb / dock platform — heavier jobs get a wider apron.
        let dockW = kind == .heavy ? wallW * 1.05 : wallW * 0.92
        let dockLen: CGFloat = kind == .heavy ? 4.5 : 3.2
        let dock = SCNBox(width: dockW, height: 0.35, length: dockLen, chamferRadius: 0.04)
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
