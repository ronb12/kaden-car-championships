import SceneKit
import simd
import UIKit

/// Instantiates cheap modular props/buildings along the spline — **not** 30 hand-authored scenes.
enum ProceduralCityDecor {

    static func buildLayer(
        into parent: SCNNode,
        city: CityRuntimeConfig,
        night: Bool,
        quality: GraphicsQuality = EnvironmentGraphicsSettings.quality
    ) {
        let track = city.track
        let pts = track.points
        guard pts.count >= 8 else { return }

        let art = CityEnvironmentArt.profile(for: city)
        var rng = SeededRandom(seed: city.seed ^ 0xDEC0_DECADE)

        // Distant skyline — lighter when a photo sky already defines the horizon.
        buildSkylineRing(into: parent, track: track, city: city, night: night, art: art, rng: &rng)

        // Sidewalks, Kenney trees, and road kit barriers along the circuit.
        buildSidewalks(into: parent, track: track, night: night, art: art)
        buildRoadsideTrees(
            into: parent, track: track, night: night,
            coastal: art.prefersPalms, art: art, rng: &rng
        )
        buildRoadBarriers(into: parent, track: track, rng: &rng)

        // Roadside buildings — denser street wall so races read like Courier city stops.
        let step = roadsideBuildingStep(
            pointCount: pts.count,
            densityMul: art.decorDensityMul,
            quality: quality
        )
        let secondRowChance: Float = quality == .low ? 0.4 : 0.62
        for i in stride(from: 0, to: pts.count, by: step) {
            let t = Float(i) / Float(pts.count)
            let base = track.position(at: t)
            let right = track.right(at: t)
            let yaw = atan2(right.x, right.z)

            for side: Float in [-1, 1] {
                // Front row — courier-style storefronts close to the curb.
                placeBuilding(
                    into: parent, city: city, track: track, night: night, rng: &rng,
                    base: base, right: right, side: side, yaw: yaw,
                    setback: RaceTrackMesh.halfWidth + 16 + rng.float(in: 2...6),
                    forceStorefront: true
                )
                if rng.unitFloat() < secondRowChance {
                    placeBuilding(
                        into: parent, city: city, track: track, night: night, rng: &rng,
                        base: base, right: right, side: side, yaw: yaw + rng.float(in: -0.08...0.08),
                        setback: RaceTrackMesh.halfWidth + 34 + rng.float(in: 4...14),
                        forceStorefront: rng.unitFloat() < 0.7
                    )
                }
            }

            if rng.unitFloat() < 0.42 {
                let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
                let roadside = art.prefersPalms
                    ? TrackRoadsideClearance.palmMinLateral
                    : TrackRoadsideClearance.treeMinLateral
                let p = base + right * ((roadside + rng.float(in: 1...6)) * side)
                attachProp(
                    to: parent, city: city, art: art, near: p, right: right,
                    track: track, night: night, rng: &rng
                )
            }
        }
    }

    private static func placeBuilding(
        into parent: SCNNode,
        city: CityRuntimeConfig,
        track: ClosedTrackSpline,
        night: Bool,
        rng: inout SeededRandom,
        base: SIMD3<Float>,
        right: SIMD3<Float>,
        side: Float,
        yaw: Float,
        setback: Float,
        forceStorefront: Bool = false
    ) {
        let pos = base + right * (setback * side)
        let blockKind = pickWeighted(city.definition.buildingWeights, roll: rng.unitFloat())
        // Street wall stays mid-rise so storefronts read; tall Kenney towers only in the back row.
        let h = forceStorefront
            ? rng.float(in: 7...14)
            : height(for: blockKind, rng: &rng)
        let w = forceStorefront ? (10 + rng.float(in: 0...6)) : (6 + rng.float(in: 0...9))
        let d = forceStorefront ? (4.5 + rng.float(in: 0...3)) : (6 + rng.float(in: 0...9))
        _ = yaw

        let buildingNode: SCNNode
        let preferStorefront = forceStorefront || h < 18 || !KenneyEnvironmentLoader.hasBuildings || rng.unitFloat() < 0.7
        if !preferStorefront,
           let kenney = KenneyEnvironmentLoader.loadBuilding(
            kind: blockKind,
            targetHeight: h,
            night: night,
            rng: &rng
        ) {
            buildingNode = kenney
            buildingNode.position = SCNVector3(pos.x, base.y, pos.z)
            KenneyEnvironmentLoader.alignBuildingToGround(buildingNode, groundY: base.y)
        } else {
            buildingNode = buildingWithWindows(
                kind: blockKind, width: w, height: h, depth: d,
                night: night, art: CityEnvironmentArt.profile(for: city), rng: &rng
            )
            buildingNode.position = SCNVector3(pos.x, base.y + Float(h) * 0.5, pos.z)
        }
        // Face storefront toward the track (local +Z points inward along -right * side).
        let faceTrack = atan2(-right.x * side, -right.z * side)
        buildingNode.eulerAngles.y = faceTrack + rng.float(in: -0.08...0.08)
        TrackRoadsideClearance.pushOutsideRoad(
            buildingNode, track: track, minLateral: RaceTrackMesh.halfWidth + 6,
            extraFootprint: max(w, d) * 0.5
        )
        buildingNode.castsShadow = h > 10
        parent.addChildNode(buildingNode)
    }

    private static func trackMaxRadius(_ track: ClosedTrackSpline) -> Float {
        track.points.reduce(0) { acc, p in
            max(acc, simd_length(SIMD2(p.x, p.z)))
        }
    }

    private static func roadsideBuildingStep(
        pointCount: Int,
        densityMul: Float,
        quality: GraphicsQuality
    ) -> Int {
        let baseDivisor: Float = switch quality {
        case .low: 380
        case .medium: 300
        case .high: 240
        case .ultra: 200
        }
        let scaled = baseDivisor * max(0.85, densityMul)
        return max(2, Int(Float(pointCount) / scaled))
    }

    /// Kenney towers on a ring around the track — sparse horizon accent only.
    private static func buildSkylineRing(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        city: CityRuntimeConfig,
        night: Bool,
        art: CityEnvironmentArt.Profile,
        rng: inout SeededRandom
    ) {
        guard KenneyEnvironmentLoader.hasBuildings else { return }
        // Photo sky already sells the city; skip duplicate 3D skyline wall.
        if city.themeId.hasPreviewCardPhoto { return }

        var center = SIMD3<Float>(0, 0, 0)
        for p in track.points { center += p }
        center /= Float(max(1, track.points.count))

        let trackOuter = trackMaxRadius(track)
        let count = min(art.skylineCount, 22)
        for i in 0..<count {
            let angle = (Float(i) / Float(count)) * 2 * Float.pi
            let kind: BuildingBlockKind = rng.unitFloat() < art.skylineHighRiseBias ? .highRise : .neonTower
            let h = rng.float(in: 28...56)
            guard let tower = KenneyEnvironmentLoader.loadBuilding(
                kind: kind, targetHeight: h, night: night, rng: &rng
            ) else { continue }

            let footprint = TrackRoadsideClearance.footprintRadius(tower)
            let radius = trackOuter + 42 + footprint + rng.float(in: 8...24)
            tower.position = SCNVector3(
                center.x + cos(angle) * radius,
                0,
                center.z + sin(angle) * radius
            )
            KenneyEnvironmentLoader.alignBuildingToGround(tower, groundY: 0)
            tower.eulerAngles.y = angle + Float.pi + rng.float(in: -0.15...0.15)
            TrackRoadsideClearance.pushOutsideRoad(
                tower, track: track, minLateral: RaceTrackMesh.halfWidth + 10
            )
            tower.castsShadow = false
            parent.addChildNode(tower)
        }
    }

    private static func buildSidewalks(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        night: Bool,
        art: CityEnvironmentArt.Profile
    ) {
        let pts = track.points
        let mat = SCNMaterial()
        mat.lightingModel = .lambert
        mat.diffuse.contents = night
            ? UIColor(red: 0.24, green: 0.23, blue: 0.22, alpha: 1)
            : UIColor(red: 0.58, green: 0.55, blue: 0.50, alpha: 1)
        mat.roughness.contents = 0.94
        mat.metalness.contents = 0
        mat.multiply.contents = UIColor(white: night ? 0.88 : 0.96, alpha: 1)

        for i in 0..<(pts.count - 1) {
            let p0 = pts[i]
            let p1 = pts[i + 1]
            let delta = p1 - p0
            let len = max(0.5, simd_length(delta))
            let yaw = atan2(delta.x, delta.z)
            let right = simd_normalize(SIMD3<Float>(-delta.z, 0, delta.x))

            for side: Float in [-1, 1] {
                let inner = RaceTrackMesh.halfWidth + 3.2
                let outer = inner + 9.5
                let off = right * side
                let y = (p0.y + p1.y) * 0.5 + 0.06
                let geo = SCNBox(width: 9.5, height: 0.12, length: CGFloat(len), chamferRadius: 0.04)
                geo.materials = [mat]
                let node = SCNNode(geometry: geo)
                let mid = (p0 + p1) * 0.5 + off * ((inner + outer) * 0.5)
                node.position = SCNVector3(mid.x, y, mid.z)
                node.eulerAngles.y = yaw
                parent.addChildNode(node)
            }
        }
    }

    private static func buildRoadsideTrees(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        night: Bool,
        coastal: Bool,
        art: CityEnvironmentArt.Profile,
        rng: inout SeededRandom
    ) {
        let sampleCount = max(track.points.count * 2, 140)
        let step = max(2, sampleCount / (coastal ? 72 : 88))
        let minLateral = coastal
            ? TrackRoadsideClearance.palmMinLateral
            : TrackRoadsideClearance.treeMinLateral

        for i in stride(from: 0, to: sampleCount, by: step) {
            if rng.unitFloat() > (coastal ? 0.72 : 0.58) { continue }
            let t = Float(i) / Float(sampleCount)
            let base = track.position(at: t)
            let right = track.right(at: t)
            let yaw = atan2(right.x, right.z)
            let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
            let roadside = base + right * ((minLateral + rng.float(in: 2...9)) * side)

            let treeHeight = rng.float(in: 4.5...9.5)
            if let tree = KenneyEnvironmentLoader.loadTree(
                targetHeight: treeHeight, coastal: coastal, rng: &rng
            ) ?? KenneyEnvironmentLoader.loadSuburbanTree(targetHeight: treeHeight, rng: &rng) {
                tree.position = SCNVector3(roadside.x, base.y, roadside.z)
                KenneyEnvironmentLoader.alignBuildingToGround(tree, groundY: base.y)
                tree.eulerAngles.y = yaw + rng.float(in: -0.4...0.4)
                TrackRoadsideClearance.pushOutsideRoad(tree, track: track, minLateral: minLateral)
                tree.castsShadow = true
                parent.addChildNode(tree)
            }
        }
        _ = art
        _ = night
    }

    private static func buildRoadBarriers(
        into parent: SCNNode,
        track: ClosedTrackSpline,
        rng: inout SeededRandom
    ) {
        guard KenneyEnvironmentLoader.hasRoads else { return }
        let pts = track.points
        for i in stride(from: 0, to: pts.count - 1, by: 4) {
            let p0 = pts[i]
            let p1 = pts[min(i + 1, pts.count - 1)]
            let delta = p1 - p0
            let yaw = atan2(delta.x, delta.z)
            let right = simd_normalize(SIMD3<Float>(-delta.z, 0, delta.x))
            for side: Float in [-1, 1] {
                let base = p0 + right * ((RaceTrackMesh.halfWidth + 6.2) * side)
                guard let barrier = KenneyEnvironmentLoader.loadRoadBarrier() else { continue }
                barrier.position = SCNVector3(base.x, base.y, base.z)
                KenneyEnvironmentLoader.alignBuildingToGround(barrier, groundY: base.y)
                barrier.eulerAngles.y = yaw + (side < 0 ? Float.pi * 0.5 : -Float.pi * 0.5)
                parent.addChildNode(barrier)
            }
        }
    }

    private static func buildingWithWindows(
        kind: BuildingBlockKind, width: Float, height: Float, depth: Float,
        night: Bool, art: CityEnvironmentArt.Profile, rng: inout SeededRandom
    ) -> SCNNode {
        let root = SCNNode()
        let baseColor = tint(for: kind, night: night, art: art, rng: &rng)

        // Main building body
        let bodyMat = SCNMaterial()
        bodyMat.lightingModel = .physicallyBased
        bodyMat.diffuse.contents = baseColor
        bodyMat.metalness.contents = night ? 0.08 : 0.02
        bodyMat.roughness.contents = night ? 0.72 : 0.82
        bodyMat.specular.contents = UIColor(white: 0.2, alpha: 1)
        let box = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(depth), chamferRadius: 0.08)
        box.materials = Array(repeating: bodyMat, count: 6)
        root.geometry = box

        // Window rows overlay (flat quads sitting on the building face)
        let windowColor: UIColor = night ? art.windowNight : art.windowDay

        let windowMat = SCNMaterial()
        windowMat.lightingModel = .physicallyBased
        windowMat.diffuse.contents = windowColor
        if night { windowMat.emission.contents = UIColor(red: 0.92, green: 0.78, blue: 0.48, alpha: 0.22) }
        windowMat.roughness.contents = night ? 0.5 : 0.1
        windowMat.metalness.contents = night ? 0.0 : 0.7

        let floors = max(2, Int(height / 3.5))
        let cols = max(2, Int(width / 2.8))
        let wW = CGFloat(width) / CGFloat(cols) * 0.52
        let wH: CGFloat = 1.4

        for floor in 0..<floors {
            let fy = CGFloat(floor) * (CGFloat(height) / CGFloat(floors)) - CGFloat(height) * 0.5 + CGFloat(height) / CGFloat(floors) * 0.5
            for col in 0..<cols {
                guard night || rng.unitFloat() > 0.15 else { continue }
                let fx = CGFloat(col) * (CGFloat(width) / CGFloat(cols)) - CGFloat(width) * 0.5 + CGFloat(width) / CGFloat(cols) * 0.5
                let wGeo = SCNBox(width: wW, height: wH, length: 0.05, chamferRadius: 0.02)
                wGeo.materials = [windowMat]
                let wNode = SCNNode(geometry: wGeo)
                wNode.position = SCNVector3(fx, fy, CGFloat(depth) * 0.5 + 0.03)
                root.addChildNode(wNode)
            }
        }

        // Courier-style loading bay / shopfront facing the track (+Z after yaw).
        let doorW = min(CGFloat(width) * 0.48, 5.8)
        let doorH = min(CGFloat(height) * 0.38, 4.2)
        let door = SCNBox(width: doorW, height: doorH, length: 0.32, chamferRadius: 0.04)
        let doorMat = SCNMaterial()
        doorMat.lightingModel = .constant
        doorMat.diffuse.contents = UIColor(white: night ? 0.05 : 0.08, alpha: 1)
        doorMat.emission.contents = UIColor(white: night ? 0.06 : 0.03, alpha: 1)
        door.materials = [doorMat]
        let doorNode = SCNNode(geometry: door)
        doorNode.position = SCNVector3(0, -CGFloat(height) * 0.5 + doorH * 0.5 + 0.2, CGFloat(depth) * 0.5 + 0.04)
        root.addChildNode(doorNode)

        let awningColor = art.billboardColors.isEmpty
            ? (night ? art.windowNight : UIColor(red: 0.85, green: 0.35, blue: 0.2, alpha: 1))
            : art.billboardColors[Int(rng.unitFloat() * Float(art.billboardColors.count)) % art.billboardColors.count]
        let awning = SCNBox(width: doorW + 1.1, height: 0.16, length: 2.4, chamferRadius: 0.03)
        let awnMat = SCNMaterial()
        awnMat.lightingModel = .physicallyBased
        awnMat.diffuse.contents = awningColor
        awnMat.emission.contents = awningColor.withAlphaComponent(night ? 0.35 : 0.18)
        awnMat.roughness.contents = 0.5
        awning.materials = [awnMat]
        let awnNode = SCNNode(geometry: awning)
        awnNode.position = SCNVector3(0, -CGFloat(height) * 0.5 + doorH + 0.45, CGFloat(depth) * 0.5 + 1.05)
        root.addChildNode(awnNode)

        // Horizontal concrete spandrel bands between every 3–4 floors
        let bandMat = SCNMaterial()
        bandMat.lightingModel = .physicallyBased
        bandMat.diffuse.contents = UIColor(white: night ? 0.18 : 0.28, alpha: 1)
        bandMat.roughness.contents = 0.90
        bandMat.metalness.contents = 0.0
        let bandFloors = max(1, floors / 3)
        for bf in stride(from: bandFloors, to: floors, by: bandFloors) {
            let by = CGFloat(bf) * (CGFloat(height) / CGFloat(floors)) - CGFloat(height) * 0.5
            let band = SCNBox(width: CGFloat(width) + 0.18, height: 0.28, length: CGFloat(depth) + 0.18, chamferRadius: 0.04)
            band.materials = [bandMat]
            let bandNode = SCNNode(geometry: band)
            bandNode.position = SCNVector3(0, by, 0)
            root.addChildNode(bandNode)
        }

        // Rooftop parapet and antenna for tall buildings
        if height > 20 {
            let parapetMat = SCNMaterial()
            parapetMat.lightingModel = .physicallyBased
            parapetMat.diffuse.contents = UIColor(white: night ? 0.20 : 0.32, alpha: 1)
            parapetMat.roughness.contents = 0.85
            let parapet = SCNBox(width: CGFloat(width) + 0.3, height: 0.55, length: CGFloat(depth) + 0.3, chamferRadius: 0.05)
            parapet.materials = [parapetMat]
            let parapetNode = SCNNode(geometry: parapet)
            parapetNode.position = SCNVector3(0, CGFloat(height) * 0.5 + 0.28, 0)
            root.addChildNode(parapetNode)

            let antMat = SCNMaterial()
            antMat.diffuse.contents = UIColor(white: 0.28, alpha: 1)
            antMat.lightingModel = .physicallyBased
            antMat.metalness.contents = 0.65
            antMat.roughness.contents = 0.45
            let antenna = SCNCylinder(radius: 0.14, height: 4.0)
            antenna.materials = [antMat]
            let antNode = SCNNode(geometry: antenna)
            antNode.position = SCNVector3(0, CGFloat(height) * 0.5 + 2.0 + 0.55, 0)
            root.addChildNode(antNode)
        }

        return root
    }

    private static func pickWeighted(_ w: [BuildingBlockKind: Float], roll: Float) -> BuildingBlockKind {
        let keys = BuildingBlockKind.allCases.sorted { (w[$0] ?? 0) > (w[$1] ?? 0) }
        let total: Float = keys.reduce(0) { $0 + (w[$1] ?? 0) }
        guard total > 1e-4 else { return .lowRise }
        var acc: Float = 0
        for k in keys {
            acc += (w[k] ?? 0) / total
            if roll <= acc { return k }
        }
        return keys[0]
    }

    private static func height(for kind: BuildingBlockKind, rng: inout SeededRandom) -> Float {
        switch kind {
        case .lowRise: return rng.float(in: 6...14)
        case .highRise: return rng.float(in: 22...42)
        case .industrial: return rng.float(in: 10...20)
        case .residential: return rng.float(in: 8...16)
        case .neonTower: return rng.float(in: 26...48)
        case .desertCompound: return rng.float(in: 5...12)
        case .coastalResort: return rng.float(in: 8...18)
        }
    }

    private static func tint(
        for kind: BuildingBlockKind,
        night: Bool,
        art: CityEnvironmentArt.Profile,
        rng: inout SeededRandom
    ) -> UIColor {
        // All palettes muted and desaturated for photorealistic city look.
        let dim: CGFloat = night ? 0.50 : 1.0
        switch kind {
        case .neonTower:
            // Dark glass cladding with subtle blue-gray tint — no cartoon brightness
            let v = CGFloat(0.18 + rng.float(in: 0...0.08))
            return UIColor(red: v * 0.75 * dim, green: v * 0.85 * dim, blue: v * dim, alpha: 1)
        case .industrial:
            // Weathered concrete / corrugated metal
            let v = CGFloat(0.24 + rng.float(in: 0...0.10))
            return UIColor(red: v * dim, green: v * 0.96 * dim, blue: v * 0.92 * dim, alpha: 1)
        case .desertCompound:
            // Sandstone / stucco — warm but muted
            let r = CGFloat(0.56 + rng.float(in: 0...0.10))
            let g = CGFloat(0.48 + rng.float(in: 0...0.08))
            let b = CGFloat(0.36 + rng.float(in: 0...0.06))
            return UIColor(red: r * dim, green: g * dim, blue: b * dim, alpha: 1)
        case .coastalResort:
            // Whitewashed / light sea-gray concrete
            let v = CGFloat(0.60 + rng.float(in: 0...0.12))
            return UIColor(red: v * 0.95 * dim, green: v * dim, blue: v * dim, alpha: 1)
        case .highRise:
            // Dark steel-frame glass tower
            let v = CGFloat(0.20 + rng.float(in: 0...0.08))
            return UIColor(red: v * 0.88 * dim, green: v * 0.92 * dim, blue: v * dim, alpha: 1)
        default:
            // Concrete / brick — neutral warm gray
            let base = CGFloat(0.30 + rng.float(in: 0...0.14))
            let warm = CGFloat(rng.float(in: 0...0.04))
            return UIColor(red: (base + warm) * dim, green: base * dim, blue: (base - warm * 0.5) * dim, alpha: 1)
        }
    }

    private static func attachProp(
        to parent: SCNNode,
        city: CityRuntimeConfig,
        art: CityEnvironmentArt.Profile,
        near base: SIMD3<Float>,
        right: SIMD3<Float>,
        track: ClosedTrackSpline,
        night: Bool,
        rng: inout SeededRandom
    ) {
        let k = pickWeighted(city.definition.propWeights, roll: rng.unitFloat())
        let outward = outwardSide(from: base, track: track, right: right)
        let p = k == .palm ? base : base + right * (8 * outward)
        switch k {
        case .streetLight:
            if let light = KenneyEnvironmentLoader.loadStreetLight(night: night) {
                light.position = SCNVector3(p.x, base.y, p.z)
                KenneyEnvironmentLoader.alignBuildingToGround(light, groundY: base.y)
                parent.addChildNode(light)
            } else {
                let pole = SCNCylinder(radius: 0.12, height: 7)
                pole.firstMaterial?.diffuse.contents = UIColor(white: 0.25, alpha: 1)
                let bulb = SCNSphere(radius: 0.28)
                bulb.firstMaterial?.diffuse.contents = UIColor(white: night ? 0.95 : 0.85, alpha: 1)
                bulb.firstMaterial?.emission.contents = night
                    ? UIColor(red: 0.92, green: 0.82, blue: 0.55, alpha: 0.35)
                    : UIColor.black
                let n = SCNNode(geometry: pole)
                n.position = SCNVector3(p.x, 3.5, p.z)
                let top = SCNNode(geometry: bulb)
                top.position = SCNVector3(0, 3.6, 0)
                n.addChildNode(top)
                parent.addChildNode(n)
            }
        case .barrier, .trafficCone:
            if let prop = KenneyEnvironmentLoader.loadRoadBarrier() {
                prop.position = SCNVector3(p.x, base.y, p.z)
                KenneyEnvironmentLoader.alignBuildingToGround(prop, groundY: base.y)
                parent.addChildNode(prop)
            } else {
                let box = SCNBox(width: 0.8, height: 1.2, length: 0.35, chamferRadius: 0.02)
                box.firstMaterial?.diffuse.contents = UIColor(red: 0.95, green: 0.52, blue: 0.1, alpha: 1)
                let n = SCNNode(geometry: box)
                n.position = SCNVector3(p.x, 0.6, p.z)
                parent.addChildNode(n)
            }
        case .signage:
            if let sign = KenneyEnvironmentLoader.loadHighwaySign(night: night) {
                sign.position = SCNVector3(p.x, base.y, p.z)
                KenneyEnvironmentLoader.alignBuildingToGround(sign, groundY: base.y)
                parent.addChildNode(sign)
            }
        case .palm:
            if let palm = KenneyEnvironmentLoader.loadTree(
                targetHeight: rng.float(in: 5.5...9.5),
                coastal: true,
                rng: &rng
            ) {
                palm.position = SCNVector3(p.x, base.y, p.z)
                KenneyEnvironmentLoader.alignBuildingToGround(palm, groundY: base.y)
                TrackRoadsideClearance.pushOutsideRoad(
                    palm, track: track, minLateral: TrackRoadsideClearance.palmMinLateral
                )
                parent.addChildNode(palm)
            }
        case .gantry:
            if let sign = KenneyEnvironmentLoader.loadHighwaySign(night: night) {
                sign.position = SCNVector3(p.x, base.y, p.z)
                sign.eulerAngles.y = atan2(right.x, right.z)
                KenneyEnvironmentLoader.alignBuildingToGround(sign, groundY: base.y)
                parent.addChildNode(sign)
            }
        }
    }

    private static func outwardSide(
        from base: SIMD3<Float>,
        track: ClosedTrackSpline,
        right: SIMD3<Float>
    ) -> Float {
        let (_, center, trackRight) = TrackRoadsideClearance.closestFrame(to: base, track: track)
        let lat = simd_dot(
            SIMD2(base.x - center.x, base.z - center.z),
            SIMD2(trackRight.x, trackRight.z)
        )
        _ = right
        return lat >= 0 ? 1 : -1
    }

    private static func pickWeighted(_ w: [PropKind: Float], roll: Float) -> PropKind {
        let keys = PropKind.allCases.sorted { (w[$0] ?? 0) > (w[$1] ?? 0) }
        let total: Float = keys.reduce(0) { $0 + (w[$1] ?? 0) }
        guard total > 1e-4 else { return .streetLight }
        var acc: Float = 0
        for k in keys {
            acc += (w[k] ?? 0) / total
            if roll <= acc { return k }
        }
        return keys[0]
    }
}

