import SceneKit
import simd
import UIKit

/// Instantiates cheap modular props/buildings along the spline — **not** 30 hand-authored scenes.
enum ProceduralCityDecor {

    static func buildLayer(into parent: SCNNode, city: CityRuntimeConfig, night: Bool) {
        let track = city.track
        let pts = track.points
        guard pts.count >= 8 else { return }

        let step = max(2, pts.count / min(120, max(40, pts.count / 3)))
        var rng = SeededRandom(seed: city.seed ^ 0xDEC0_DECADE)

        for i in stride(from: 0, to: pts.count, by: step) {
            let t = Float(i) / Float(pts.count)
            let base = track.position(at: t)
            let right = track.right(at: t)
            let side = rng.unitFloat() > 0.5 ? 1.0 as Float : -1.0 as Float
            let offset = 9 + rng.float(in: 2...11)
            let pos = base + right * (offset * side)

            let roll = rng.unitFloat()
            let blockKind = pickWeighted(city.definition.buildingWeights, roll: roll)
            let h = height(for: blockKind, rng: &rng)
            let w = 5 + rng.float(in: 0...8)
            let d = 5 + rng.float(in: 0...9)

            let box = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0.06)
            box.firstMaterial?.diffuse.contents = tint(for: blockKind, night: night, rng: &rng)
            box.firstMaterial?.specular.contents = UIColor(white: night ? 0.15 : 0.35, alpha: 1)
            box.firstMaterial?.locksAmbientWithDiffuse = true

            let node = SCNNode(geometry: box)
            node.position = SCNVector3(pos.x, Float(h) * 0.5 + pos.y * 0.3, pos.z)
            node.eulerAngles.y = atan2(right.x, right.z) + rng.float(in: -0.08...0.08)
            node.castsShadow = h > 12
            parent.addChildNode(node)

            if rng.unitFloat() < 0.22 {
                attachProp(to: parent, near: pos, right: right, night: night, rng: &rng)
            }
        }
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

    private static func tint(for kind: BuildingBlockKind, night: Bool, rng: inout SeededRandom) -> UIColor {
        let dim = night ? 0.55 : 1.0
        switch kind {
        case .neonTower:
            return UIColor(
                red: CGFloat(0.15 + rng.float(in: 0...0.25)) * CGFloat(dim),
                green: CGFloat(0.35 + rng.float(in: 0...0.35)) * CGFloat(dim),
                blue: CGFloat(0.85 + rng.float(in: 0...0.15)) * CGFloat(dim),
                alpha: 1
            )
        case .industrial:
            return UIColor(white: CGFloat(0.22 * dim), alpha: 1)
        case .desertCompound:
            return UIColor(red: CGFloat(0.55 * dim), green: CGFloat(0.45 * dim), blue: CGFloat(0.28 * dim), alpha: 1)
        case .coastalResort:
            return UIColor(red: CGFloat(0.38 * dim), green: CGFloat(0.52 * dim), blue: CGFloat(0.55 * dim), alpha: 1)
        default:
            return UIColor(
                red: CGFloat(0.28 + rng.float(in: 0...0.25)) * CGFloat(dim),
                green: CGFloat(0.28 + rng.float(in: 0...0.22)) * CGFloat(dim),
                blue: CGFloat(0.32 + rng.float(in: 0...0.2)) * CGFloat(dim),
                alpha: 1
            )
        }
    }

    private static func attachProp(
        to parent: SCNNode,
        near base: SIMD3<Float>,
        right: SIMD3<Float>,
        night: Bool,
        rng: inout SeededRandom
    ) {
        let kinds = PropKind.allCases
        let k = kinds[rng.int(in: 0...(kinds.count - 1))]
        let side: Float = rng.unitFloat() > 0.5 ? 1 : -1
        let p = base + right * (11 * side)
        switch k {
        case .streetLight:
            let pole = SCNCylinder(radius: 0.12, height: 7)
            pole.firstMaterial?.diffuse.contents = UIColor(white: 0.25, alpha: 1)
            let bulb = SCNSphere(radius: 0.28)
            bulb.firstMaterial?.diffuse.contents = UIColor(white: night ? 0.95 : 0.85, alpha: 1)
            bulb.firstMaterial?.emission.contents = UIColor(red: 1, green: night ? 0.92 : 0.88, blue: 0.35, alpha: 1)
            let n = SCNNode(geometry: pole)
            n.position = SCNVector3(p.x, 3.5, p.z)
            let top = SCNNode(geometry: bulb)
            top.position = SCNVector3(0, 3.6, 0)
            n.addChildNode(top)
            parent.addChildNode(n)
        case .barrier, .trafficCone, .signage, .palm, .gantry:
            let box = SCNBox(width: 0.8, height: 1.2, length: 0.35, chamferRadius: 0.02)
            box.firstMaterial?.diffuse.contents = UIColor(red: 0.95, green: 0.52, blue: 0.1, alpha: 1)
            let n = SCNNode(geometry: box)
            n.position = SCNVector3(p.x, 0.6, p.z)
            parent.addChildNode(n)
        }
    }
}

