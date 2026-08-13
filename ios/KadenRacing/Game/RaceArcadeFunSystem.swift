import SceneKit
import simd
import UIKit

/// On-track arcade layer for the minimal circuit: crystals, nitro pads, drift zones,
/// draft boost, shortcut gates, lap objectives, apex markers, and brief weather bursts.
final class RaceArcadeFunSystem {

    struct Snapshot {
        var crystalsCollected: Int = 0
        var crystalsTotal: Int = 0
        var nitroPadsCollected: Int = 0
        var nearMisses: Int = 0
        var shortcutsTaken: Int = 0
        var objectiveLabel: String = ""
        var objectiveProgress: Float = 0
        var objectiveComplete: Bool = false
        var draftActive: Bool = false
        var driftZoneActive: Bool = false
        var weatherBurstActive: Bool = false
        var bonusCredits: Int64 = 0
        var toast: String?
    }

    private struct Pickup {
        enum Kind { case crystal, nitro }
        let kind: Kind
        let node: SCNNode
        let trackT: Float
        let lateral: Float
        var collected = false
    }

    private struct Zone {
        let startT: Float
        let endT: Float
        let node: SCNNode
    }

    private struct Gate {
        let node: SCNNode
        let trackT: Float
        let lateral: Float
        var broken = false
    }

    private weak var root: SCNNode?
    private var track: ClosedTrackSpline!
    private var trackQuery: TrackWorldQuery!
    private var pickups: [Pickup] = []
    private var driftZones: [Zone] = []
    private var gates: [Gate] = []
    private var apexMarkers: [SCNNode] = []
    private var draftAura: SCNNode?
    private var weatherOverlay: SCNNode?

    private var crystals = 0
    private var nitroPads = 0
    private var nearMisses = 0
    private var shortcuts = 0
    private var crystalTarget = 8
    private var nearMissTarget = 3
    private var objectiveKind = 0
    private var objectiveDone = false

    private var draftTimer: Float = 0
    private var shortcutBoost: Float = 0
    private var weatherTimer: Float = 0
    private var weatherCooldown: Float = 28
    private var toast: String?
    private var toastTimer: Float = 0
    private var lastNearMissCooldown: Float = 0

    private(set) var snapshot = Snapshot()

    func attach(to parent: SCNNode, track: ClosedTrackSpline, trackQuery: TrackWorldQuery, seed: UInt64) {
        detach()
        self.track = track
        self.trackQuery = trackQuery
        let root = SCNNode()
        root.name = "krcArcadeFun"
        parent.addChildNode(root)
        self.root = root

        var rng = SeededRandom(seed: seed == 0 ? 0xC0FFEE : seed)
        objectiveKind = rng.int(in: 0...2)
        crystalTarget = rng.int(in: 6...10)
        nearMissTarget = rng.int(in: 2...4)

        spawnCrystals(rng: &rng)
        spawnNitroPads(rng: &rng)
        spawnDriftZones(rng: &rng)
        spawnShortcutGates(rng: &rng)
        spawnApexMarkers(rng: &rng)
        installDraftAura(on: parent)
        installWeatherOverlay(on: parent)
        refreshSnapshot(nitroBonus: 0)
    }

    func detach() {
        root?.removeFromParentNode()
        root = nil
        draftAura?.removeFromParentNode()
        draftAura = nil
        weatherOverlay?.removeFromParentNode()
        weatherOverlay = nil
        pickups.removeAll()
        driftZones.removeAll()
        gates.removeAll()
        apexMarkers.removeAll()
        crystals = 0
        nitroPads = 0
        nearMisses = 0
        shortcuts = 0
        objectiveDone = false
        snapshot = Snapshot()
    }

    /// Call each physics tick after the player has moved.
    func update(
        dt: Float,
        worldX: Float,
        worldZ: Float,
        heading: Float,
        trackT: Float,
        speed: Float,
        isDrifting: Bool,
        nitro: inout Float,
        opponents: RaceOpponentController?
    ) -> (gripMul: Float, speedMul: Float, driftScoreMul: Float) {
        toastTimer = max(0, toastTimer - dt)
        if toastTimer <= 0 { toast = nil }
        lastNearMissCooldown = max(0, lastNearMissCooldown - dt)
        shortcutBoost = max(0, shortcutBoost - dt)
        weatherCooldown = max(0, weatherCooldown - dt)

        collectPickups(worldX: worldX, worldZ: worldZ, nitro: &nitro)
        updateDriftZones(trackT: trackT, isDrifting: isDrifting)
        updateGates(worldX: worldX, worldZ: worldZ)
        updateDraft(dt: dt, worldX: worldX, worldZ: worldZ, heading: heading, speed: speed, opponents: opponents)
        updateWeather(dt: dt, speed: speed)
        checkObjectives()

        var grip: Float = 1
        var speedMul: Float = 1
        var driftMul: Float = 1

        if snapshot.driftZoneActive && isDrifting {
            driftMul = 2.4
        }
        if draftTimer > 0 {
            speedMul *= 1.08
            snapshot.draftActive = true
        } else {
            snapshot.draftActive = false
        }
        if shortcutBoost > 0 {
            speedMul *= 1.12
        }
        if weatherTimer > 0 {
            grip *= 0.72
            snapshot.weatherBurstActive = true
        } else {
            snapshot.weatherBurstActive = false
        }

        refreshSnapshot(nitroBonus: 0)
        return (grip, speedMul, driftMul)
    }

    /// Temporary track-T bump from shortcuts (consumed by engine).
    private(set) var pendingTrackBump: Float = 0

    func consumeTrackBump() -> Float {
        let v = pendingTrackBump
        pendingTrackBump = 0
        return v
    }

    func finishBonusCredits() -> Int64 {
        var bonus: Int64 = Int64(crystals) * 35 + Int64(nitroPads) * 20
        bonus += Int64(nearMisses) * 40
        bonus += Int64(shortcuts) * 75
        if objectiveDone { bonus += 250 }
        return bonus
    }

    // MARK: - Spawn

    private func spawnCrystals(rng: inout SeededRandom) {
        let count = 14
        for i in 0..<count {
            let t = (Float(i) + 0.35) / Float(count)
            let side: Float = i % 2 == 0 ? -1 : 1
            let lat = side * (RaceTrackMesh.halfWidth * (0.22 + rng.float(in: 0...0.15)))
            let node = makeCrystalNode()
            // Root on asphalt; gem + badge float clear of the ribbon.
            place(node, trackT: t, lateral: lat, yOffset: 0.04)
            root?.addChildNode(node)
            pickups.append(Pickup(kind: .crystal, node: node, trackT: t, lateral: lat))
        }
        snapshot.crystalsTotal = count
    }

    private func spawnNitroPads(rng: inout SeededRandom) {
        let count = 6
        for i in 0..<count {
            let t = (Float(i) + 0.5) / Float(count)
            let lat = rng.float(in: -1.6...1.6)
            let node = makeNitroPadNode()
            place(node, trackT: t, lateral: lat, yOffset: 0.06)
            root?.addChildNode(node)
            pickups.append(Pickup(kind: .nitro, node: node, trackT: t, lateral: lat))
        }
    }

    private func spawnDriftZones(rng: inout SeededRandom) {
        let count = 3
        for i in 0..<count {
            let start = (Float(i) + 0.2) / Float(count)
            let end = start + 0.07
            let node = makeDriftZoneRibbon(from: start, to: end)
            root?.addChildNode(node)
            driftZones.append(Zone(startT: start, endT: end, node: node))
        }
        _ = rng
    }

    private func spawnShortcutGates(rng: inout SeededRandom) {
        let count = 3
        for i in 0..<count {
            let t = (Float(i) + 0.65) / Float(count)
            let lat = (i % 2 == 0 ? 1 : -1) * (RaceTrackMesh.halfWidth - 2.2)
            let node = makeShortcutGateNode()
            place(node, trackT: t, lateral: lat, yOffset: 1.1)
            // Face along track
            let tan = track.tangent(t)
            node.eulerAngles.y = atan2(tan.x, tan.z) + Float.pi * 0.5
            root?.addChildNode(node)
            gates.append(Gate(node: node, trackT: t, lateral: lat))
        }
        _ = rng
    }

    private func spawnApexMarkers(rng: inout SeededRandom) {
        // Sample curvature and drop neon chevrons on sharper bends.
        var placed = 0
        var t: Float = 0
        while t < 1 && placed < 10 {
            let t0 = t
            let t1 = (t + 0.03).truncatingRemainder(dividingBy: 1)
            let a = simd_normalize(track.tangent(t0))
            let b = simd_normalize(track.tangent(t1))
            let bend = max(0, 1 - simd_dot(SIMD3<Float>(a.x, 0, a.z), SIMD3<Float>(b.x, 0, b.z)))
            if bend > 0.08 {
                let node = makeApexMarkerNode()
                place(node, trackT: t0, lateral: 0, yOffset: 0.35)
                let tan = track.tangent(t0)
                node.eulerAngles.y = atan2(tan.x, tan.z)
                root?.addChildNode(node)
                apexMarkers.append(node)
                placed += 1
                t += 0.08
            } else {
                t += 0.02
            }
        }
        _ = rng
    }

    private func installDraftAura(on parent: SCNNode) {
        let torus = SCNTorus(ringRadius: 1.6, pipeRadius: 0.08)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor(red: 0.2, green: 0.95, blue: 1, alpha: 1)
        mat.emission.contents = UIColor(red: 0.2, green: 0.95, blue: 1, alpha: 0.85)
        mat.transparency = 0.55
        torus.materials = [mat]
        let node = SCNNode(geometry: torus)
        node.name = "krcDraftAura"
        node.isHidden = true
        node.eulerAngles.x = Float.pi * 0.5
        parent.addChildNode(node)
        draftAura = node
    }

    private func installWeatherOverlay(on parent: SCNNode) {
        let plane = SCNPlane(width: 80, height: 80)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor(white: 0.75, alpha: 0.18)
        mat.transparency = 0.35
        mat.writesToDepthBuffer = false
        plane.materials = [mat]
        let node = SCNNode(geometry: plane)
        node.name = "krcWeatherBurst"
        node.eulerAngles.x = -Float.pi * 0.5
        node.position = SCNVector3(0, 8, 0)
        node.isHidden = true
        node.renderingOrder = 40
        parent.addChildNode(node)
        weatherOverlay = node
    }

    // MARK: - Update helpers

    private func collectPickups(worldX: Float, worldZ: Float, nitro: inout Float) {
        let player = SIMD2<Float>(worldX, worldZ)
        for i in pickups.indices {
            guard !pickups[i].collected else { continue }
            let p = SIMD2<Float>(pickups[i].node.position.x, pickups[i].node.position.z)
            let dist = simd_distance(player, p)
            let radius: Float = pickups[i].kind == .crystal ? 2.4 : 3.2
            guard dist < radius else { continue }
            pickups[i].collected = true
            animateCollect(pickups[i].node)
            switch pickups[i].kind {
            case .crystal:
                crystals += 1
                showToast("+\(35) KR CRYSTAL")
            case .nitro:
                nitroPads += 1
                nitro = min(1, nitro + 0.42)
                showToast("N2O PAD +42%")
            }
        }
    }

    private func updateDriftZones(trackT: Float, isDrifting: Bool) {
        let t = trackT.truncatingRemainder(dividingBy: 1)
        var active = false
        for zone in driftZones {
            if inArc(t, zone.startT, zone.endT) {
                active = true
                zone.node.opacity = isDrifting ? 1 : 0.55
            } else {
                zone.node.opacity = 0.35
            }
        }
        snapshot.driftZoneActive = active
        if active && isDrifting {
            // Toast sparsely
            if toast == nil { showToast("DRIFT ZONE ×2.4", duration: 0.8) }
        }
    }

    private func updateGates(worldX: Float, worldZ: Float) {
        let player = SIMD2<Float>(worldX, worldZ)
        for i in gates.indices {
            guard !gates[i].broken else { continue }
            let p = SIMD2<Float>(gates[i].node.position.x, gates[i].node.position.z)
            if simd_distance(player, p) < 3.5 {
                gates[i].broken = true
                shatter(gates[i].node)
                shortcuts += 1
                shortcutBoost = 1.6
                pendingTrackBump = 0.012
                showToast("SHORTCUT +BOOST")
            }
        }
    }

    private func updateDraft(
        dt: Float,
        worldX: Float,
        worldZ: Float,
        heading: Float,
        speed: Float,
        opponents: RaceOpponentController?
    ) {
        guard let opponents, speed > 8 else {
            draftTimer = max(0, draftTimer - dt * 2)
            draftAura?.isHidden = true
            return
        }
        let forward = SIMD2<Float>(sin(heading), cos(heading))
        let player = SIMD2<Float>(worldX, worldZ)
        var bestDist: Float = 12
        var drafting = false
        var auraPos = SCNVector3(worldX, 1.2, worldZ)

        for opp in opponents.opponents where !opp.finished {
            let ox = opp.node.position.x
            let oz = opp.node.position.z
            let toOpp = SIMD2<Float>(ox - worldX, oz - worldZ)
            let dist = simd_length(toOpp)
            guard dist > 0.5, dist < bestDist else { continue }
            let dir = toOpp / dist
            let align = simd_dot(forward, dir)
            // Opponent roughly ahead in a cone
            if align > 0.72 {
                drafting = true
                bestDist = dist
                auraPos = SCNVector3(ox, 1.15, oz)
                if dist < 5.5, lastNearMissCooldown <= 0 {
                    nearMisses += 1
                    lastNearMissCooldown = 2.2
                    showToast("NEAR MISS +\(nearMisses)")
                }
            }
        }

        if drafting {
            draftTimer = min(1.5, draftTimer + dt)
            draftAura?.isHidden = false
            draftAura?.position = auraPos
            draftAura?.eulerAngles.y += dt * 4
        } else {
            draftTimer = max(0, draftTimer - dt * 1.5)
            if draftTimer <= 0 { draftAura?.isHidden = true }
        }
    }

    private func updateWeather(dt: Float, speed: Float) {
        if weatherTimer > 0 {
            weatherTimer -= dt
            weatherOverlay?.isHidden = false
            weatherOverlay?.opacity = CGFloat(min(1, weatherTimer))
            if weatherTimer <= 0 {
                weatherOverlay?.isHidden = true
                weatherCooldown = Float.random(in: 22...38)
            }
            return
        }
        weatherOverlay?.isHidden = true
        if weatherCooldown <= 0, speed > 12 {
            weatherTimer = Float.random(in: 6...10)
            showToast("WEATHER BURST — SLICK SECTOR")
        }
    }

    private func checkObjectives() {
        guard !objectiveDone else {
            snapshot.objectiveComplete = true
            return
        }
        switch objectiveKind {
        case 0:
            snapshot.objectiveLabel = "Collect \(crystalTarget) crystals"
            snapshot.objectiveProgress = min(1, Float(crystals) / Float(max(1, crystalTarget)))
            if crystals >= crystalTarget { completeObjective("OBJECTIVE CLEAR +250 KR") }
        case 1:
            snapshot.objectiveLabel = "Score \(nearMissTarget) near-misses"
            snapshot.objectiveProgress = min(1, Float(nearMisses) / Float(max(1, nearMissTarget)))
            if nearMisses >= nearMissTarget { completeObjective("OBJECTIVE CLEAR +250 KR") }
        default:
            snapshot.objectiveLabel = "Take 2 shortcuts"
            snapshot.objectiveProgress = min(1, Float(shortcuts) / 2)
            if shortcuts >= 2 { completeObjective("OBJECTIVE CLEAR +250 KR") }
        }
    }

    private func completeObjective(_ message: String) {
        objectiveDone = true
        snapshot.objectiveComplete = true
        showToast(message, duration: 2.2)
    }

    private func refreshSnapshot(nitroBonus: Int) {
        _ = nitroBonus
        snapshot.crystalsCollected = crystals
        snapshot.crystalsTotal = pickups.filter { $0.kind == .crystal }.count
        snapshot.nitroPadsCollected = nitroPads
        snapshot.nearMisses = nearMisses
        snapshot.shortcutsTaken = shortcuts
        snapshot.bonusCredits = finishBonusCredits()
        snapshot.toast = toast
        if !objectiveDone {
            // labels already set in checkObjectives
        }
    }

    private func showToast(_ text: String, duration: Float = 1.4) {
        toast = text
        toastTimer = duration
    }

    // MARK: - Geometry helpers

    /// Asphalt ribbon in `RaceTrackMesh` sits ~0.10–0.12 above the spline sample.
    private static let roadSurfaceY: Float = 0.12

    private func place(_ node: SCNNode, trackT: Float, lateral: Float, yOffset: Float) {
        let p = track.sample(trackT)
        let tan = track.tangent(trackT)
        let forward = simd_normalize(SIMD3<Float>(tan.x, 0, tan.z))
        let right = SIMD3<Float>(forward.z, 0, -forward.x)
        let pos = p + right * lateral
        // Sit on the driving surface, then apply local clearance.
        node.position = SCNVector3(pos.x, p.y + Self.roadSurfaceY + yOffset, pos.z)
    }

    private func makeCrystalNode() -> SCNNode {
        let root = SCNNode()
        root.name = "krcCrystal"

        let gold = UIColor(red: 1.0, green: 0.82, blue: 0.22, alpha: 1)
        let amber = UIColor(red: 1.0, green: 0.55, blue: 0.08, alpha: 1)

        // Ground marker — readable lane paint, not buried geometry.
        let aura = SCNCylinder(radius: 1.05, height: 0.05)
        let auraMat = SCNMaterial()
        auraMat.lightingModel = .constant
        auraMat.diffuse.contents = gold.withAlphaComponent(0.45)
        auraMat.emission.contents = amber
        auraMat.transparency = 0.4
        aura.materials = [auraMat]
        let auraNode = SCNNode(geometry: aura)
        auraNode.position = SCNVector3(0, 0.03, 0)

        // Big, simple diamond silhouette (chase-cam readable).
        let gem = SCNNode()
        gem.name = "krcCrystalGem"
        gem.position = SCNVector3(0, 1.55, 0)

        let shellMat = SCNMaterial()
        shellMat.lightingModel = .constant
        shellMat.diffuse.contents = gold
        shellMat.emission.contents = UIColor(red: 1.0, green: 0.75, blue: 0.15, alpha: 1)
        shellMat.isDoubleSided = true

        let top = SCNPyramid(width: 1.15, height: 1.15, length: 1.15)
        top.materials = [shellMat]
        let topNode = SCNNode(geometry: top)
        topNode.position = SCNVector3(0, 0.55, 0)

        let bottom = SCNPyramid(width: 1.15, height: 1.15, length: 1.15)
        bottom.materials = [shellMat]
        let bottomNode = SCNNode(geometry: bottom)
        bottomNode.eulerAngles.x = Float.pi
        bottomNode.position = SCNVector3(0, -0.55, 0)

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.intensity = 520
        light.light?.color = gold
        light.light?.attenuationStartDistance = 0.5
        light.light?.attenuationEndDistance = 14
        light.position = SCNVector3(0, 0.2, 0)

        gem.addChildNode(topNode)
        gem.addChildNode(bottomNode)
        gem.addChildNode(light)

        // Camera-facing badge: same language as HUD (diamond = KR crystal).
        let badge = makePickupBadge(
            systemName: "diamond.fill",
            caption: "KR",
            tint: gold,
            disc: amber
        )
        badge.position = SCNVector3(0, 3.15, 0)

        root.addChildNode(auraNode)
        root.addChildNode(gem)
        root.addChildNode(badge)

        let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 2.6))
        let bob = SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.16, z: 0, duration: 0.7),
            SCNAction.moveBy(x: 0, y: -0.16, z: 0, duration: 0.7)
        ]))
        gem.runAction(spin)
        gem.runAction(bob)
        auraNode.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.scale(to: 1.12, duration: 0.85),
            SCNAction.scale(to: 0.94, duration: 0.85)
        ])))
        return root
    }

    private func makeNitroPadNode() -> SCNNode {
        let root = SCNNode()
        root.name = "krcNitroPad"

        let cyan = UIColor(red: 0.15, green: 0.92, blue: 1.0, alpha: 1)
        let deep = UIColor(red: 0.05, green: 0.35, blue: 0.85, alpha: 1)
        let white = UIColor.white

        let disc = SCNCylinder(radius: 1.45, height: 0.1)
        let discMat = SCNMaterial()
        discMat.lightingModel = .constant
        discMat.diffuse.contents = deep
        discMat.emission.contents = cyan.withAlphaComponent(0.9)
        disc.materials = [discMat]
        let discNode = SCNNode(geometry: disc)
        discNode.position = SCNVector3(0, 0.08, 0)

        let ring = SCNTorus(ringRadius: 1.5, pipeRadius: 0.07)
        let ringMat = SCNMaterial()
        ringMat.lightingModel = .constant
        ringMat.diffuse.contents = white
        ringMat.emission.contents = cyan
        ring.materials = [ringMat]
        let ringNode = SCNNode(geometry: ring)
        ringNode.eulerAngles.x = Float.pi * 0.5
        ringNode.position = SCNVector3(0, 0.16, 0)

        let bolt = SCNCone(topRadius: 0, bottomRadius: 0.38, height: 0.95)
        let boltMat = SCNMaterial()
        boltMat.lightingModel = .constant
        boltMat.diffuse.contents = white
        boltMat.emission.contents = cyan
        bolt.materials = [boltMat]
        let boltNode = SCNNode(geometry: bolt)
        boltNode.position = SCNVector3(0, 0.85, 0)

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.intensity = 420
        light.light?.color = cyan
        light.light?.attenuationEndDistance = 10
        light.position = SCNVector3(0, 0.7, 0)

        let badge = makePickupBadge(
            systemName: "bolt.fill",
            caption: "N2O",
            tint: cyan,
            disc: deep
        )
        badge.position = SCNVector3(0, 2.55, 0)

        root.addChildNode(discNode)
        root.addChildNode(ringNode)
        root.addChildNode(boltNode)
        root.addChildNode(light)
        root.addChildNode(badge)

        ringNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: 2.0)))
        boltNode.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: 0.45),
            SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: 0.45)
        ])))
        discNode.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.fadeOpacity(to: 0.75, duration: 0.6),
            SCNAction.fadeOpacity(to: 1.0, duration: 0.6)
        ])))
        return root
    }

    /// Camera-facing icon + short caption so chase-cam players can read pickups at speed.
    private func makePickupBadge(
        systemName: String,
        caption: String,
        tint: UIColor,
        disc: UIColor
    ) -> SCNNode {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let cg = ctx.cgContext
            cg.setFillColor(disc.withAlphaComponent(0.92).cgColor)
            cg.fillEllipse(in: rect.insetBy(dx: 8, dy: 8))
            cg.setStrokeColor(tint.cgColor)
            cg.setLineWidth(10)
            cg.strokeEllipse(in: rect.insetBy(dx: 14, dy: 14))

            let config = UIImage.SymbolConfiguration(pointSize: 72, weight: .black)
            if let symbol = UIImage(systemName: systemName, withConfiguration: config)?
                .withTintColor(tint, renderingMode: .alwaysOriginal) {
                let symSize = symbol.size
                let symRect = CGRect(
                    x: (size.width - symSize.width) * 0.5,
                    y: 36,
                    width: symSize.width,
                    height: symSize.height
                )
                symbol.draw(in: symRect)
            }

            let para = NSMutableParagraphStyle()
            para.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 42, weight: .black),
                .foregroundColor: UIColor.white,
                .paragraphStyle: para,
            ]
            let text = caption as NSString
            let textRect = CGRect(x: 16, y: 175, width: size.width - 32, height: 52)
            text.draw(in: textRect, withAttributes: attrs)
        }

        let plane = SCNPlane(width: 1.7, height: 1.7)
        let mat = SCNMaterial()
        mat.lightingModel = .constant
        mat.diffuse.contents = image
        mat.emission.contents = image
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        plane.materials = [mat]

        let face = SCNNode(geometry: plane)
        face.name = "krcPickupBadgeFace"

        let holder = SCNNode()
        holder.name = "krcPickupBadge"
        holder.renderingOrder = 50
        holder.addChildNode(face)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        holder.constraints = [billboard]
        holder.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.fadeOpacity(to: 0.88, duration: 0.55),
            SCNAction.fadeOpacity(to: 1.0, duration: 0.55)
        ])))
        return holder
    }

    private func makeDriftZoneRibbon(from start: Float, to end: Float) -> SCNNode {
        let container = SCNNode()
        container.name = "krcDriftZone"
        let steps = 8
        for i in 0..<steps {
            let u = Float(i) / Float(steps)
            let t = start + (end - start) * u
            let strip = SCNBox(width: CGFloat(RaceTrackMesh.halfWidth * 1.6), height: 0.05, length: 2.2, chamferRadius: 0.02)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = UIColor(red: 1, green: 0.28, blue: 0.78, alpha: 0.75)
            mat.emission.contents = UIColor(red: 1, green: 0.2, blue: 0.7, alpha: 0.65)
            mat.transparency = 0.4
            strip.materials = [mat]
            let node = SCNNode(geometry: strip)
            place(node, trackT: t, lateral: 0, yOffset: 0.04)
            let tan = track.tangent(t)
            node.eulerAngles.y = atan2(tan.x, tan.z)
            container.addChildNode(node)

            let edge = SCNTorus(ringRadius: 0.55, pipeRadius: 0.035)
            let edgeMat = SCNMaterial()
            edgeMat.lightingModel = .constant
            edgeMat.diffuse.contents = UIColor.white
            edgeMat.emission.contents = UIColor(red: 1, green: 0.55, blue: 0.9, alpha: 1)
            edge.materials = [edgeMat]
            let edgeNode = SCNNode(geometry: edge)
            edgeNode.eulerAngles.x = Float.pi * 0.5
            edgeNode.position.y = 0.12
            node.addChildNode(edgeNode)
        }
        container.opacity = 0.55
        return container
    }

    private func makeShortcutGateNode() -> SCNNode {
        let root = SCNNode()
        root.name = "krcShortcutGate"

        let bar = SCNBox(width: 0.28, height: 2.4, length: 3.4, chamferRadius: 0.06)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(red: 1.0, green: 0.45, blue: 0.05, alpha: 1)
        mat.emission.contents = UIColor(red: 1, green: 0.55, blue: 0.08, alpha: 0.8)
        mat.metalness.contents = 0.7
        mat.roughness.contents = 0.25
        bar.materials = [mat]
        let barNode = SCNNode(geometry: bar)

        let arch = SCNTorus(ringRadius: 1.55, pipeRadius: 0.08)
        let archMat = SCNMaterial()
        archMat.lightingModel = .constant
        archMat.diffuse.contents = UIColor.white
        archMat.emission.contents = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1)
        arch.materials = [archMat]
        let archNode = SCNNode(geometry: arch)
        archNode.eulerAngles.z = Float.pi * 0.5
        archNode.position.y = 0.2

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.intensity = 280
        light.light?.color = UIColor(red: 1, green: 0.55, blue: 0.1, alpha: 1)
        light.light?.attenuationEndDistance = 8
        light.position = SCNVector3(0, 1.0, 0)

        root.addChildNode(barNode)
        root.addChildNode(archNode)
        root.addChildNode(light)
        archNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: CGFloat.pi * 2, y: 0, z: 0, duration: 2.8)))
        return root
    }

    private func makeApexMarkerNode() -> SCNNode {
        let root = SCNNode()
        root.name = "krcApexMarker"

        let chevron = SCNCone(topRadius: 0, bottomRadius: 0.58, height: 0.95)
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = UIColor(red: 0.15, green: 1, blue: 0.55, alpha: 1)
        mat.emission.contents = UIColor(red: 0.1, green: 1, blue: 0.45, alpha: 0.9)
        mat.metalness.contents = 0.55
        mat.roughness.contents = 0.2
        chevron.materials = [mat]
        let node = SCNNode(geometry: chevron)
        node.eulerAngles.x = Float.pi * 0.5

        let ring = SCNTorus(ringRadius: 0.7, pipeRadius: 0.04)
        let ringMat = SCNMaterial()
        ringMat.lightingModel = .constant
        ringMat.diffuse.contents = UIColor.white
        ringMat.emission.contents = UIColor(red: 0.4, green: 1, blue: 0.7, alpha: 1)
        ring.materials = [ringMat]
        let ringNode = SCNNode(geometry: ring)
        ringNode.eulerAngles.x = Float.pi * 0.5
        ringNode.position.z = -0.15

        root.addChildNode(node)
        root.addChildNode(ringNode)
        ringNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: 1.8)))
        return root
    }

    private func animateCollect(_ node: SCNNode) {
        let up = SCNAction.moveBy(x: 0, y: 1.8, z: 0, duration: 0.28)
        let fade = SCNAction.fadeOut(duration: 0.28)
        let scale = SCNAction.scale(to: 1.45, duration: 0.12)
        let shrink = SCNAction.scale(to: 0.05, duration: 0.18)
        node.runAction(SCNAction.sequence([
            SCNAction.group([up, fade, SCNAction.sequence([scale, shrink])]),
            SCNAction.removeFromParentNode()
        ]))
    }

    private func shatter(_ node: SCNNode) {
        node.runAction(SCNAction.sequence([
            SCNAction.group([
                SCNAction.fadeOut(duration: 0.2),
                SCNAction.scale(to: 1.6, duration: 0.2)
            ]),
            SCNAction.removeFromParentNode()
        ]))
    }

    private func inArc(_ t: Float, _ a: Float, _ b: Float) -> Bool {
        let tt = t.truncatingRemainder(dividingBy: 1)
        let aa = a.truncatingRemainder(dividingBy: 1)
        let bb = b.truncatingRemainder(dividingBy: 1)
        if aa <= bb { return tt >= aa && tt <= bb }
        return tt >= aa || tt <= bb
    }
}
