import SceneKit
import UIKit

/// Bundled USDZ wheels keep tire geometry; garage rims add a spoke face on each hub.
/// Procedural wheels are used for the primitive fallback car.
enum WheelAssembly {

    struct Anchor {
        let x: Float
        let y: Float
        let z: Float
        let sideSign: Float
    }

    private static let cornerPrefixes = ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]

    static func wheelScale(for carNode: SCNNode) -> Float { 1.0 }

    static func defaultAnchors(scale: Float) -> [Anchor] {
        let s = scale
        return [
            Anchor(x: 1.24 * s, y: 0.37 * s, z: 1.32 * s, sideSign: 1),
            Anchor(x: -1.24 * s, y: 0.37 * s, z: 1.32 * s, sideSign: -1),
            Anchor(x: 1.31 * s, y: 0.37 * s, z: -1.35 * s, sideSign: 1),
            Anchor(x: -1.31 * s, y: 0.37 * s, z: -1.35 * s, sideSign: -1),
        ]
    }

    /// Re-apply the garage rim pick on an already-built car (preview + race).
    static func restyleGarageWheels(in root: SCNNode, carId: String, scale: Float) {
        let host = root.childNode(withName: "krcVehicleRoot", recursively: false) ?? root
        let mesh = host.childNode(withName: "krcBundledContainer", recursively: false)
            ?? host.childNode(withName: "krcVehicleBody", recursively: true)
            ?? host
        if !usdzWheelHubs(in: mesh).isEmpty {
            prepareBundledWheels(carNode: mesh, container: host, scale: scale, carId: carId)
            return
        }
        for group in wheelGroups(in: root) {
            group.removeFromParentNode()
        }
        let style = VehicleVisualProfile.profile(carId: carId).wheelStyle
        attachStyledWheels(to: host, style: style, scale: scale, anchors: defaultAnchors(scale: scale))
    }

    /// Clean up and restyle wheels on the bundled USDZ.
    static func prepareBundledWheels(carNode: SCNNode, container: SCNNode, scale: Float, carId: String? = nil) {
        stripDuplicateWheelDecals(from: carNode)
        stripBrakeDiscMeshes(from: carNode)
        stripFlatWheelArt(from: carNode)
        purgeContainerOrphans(container)
        let rim = carId.map { GarageCustomization.style(for: $0).rim } ?? .stock
        applyBundledWheelLook(in: carNode, rim: rim)
        attachRimFaceDesigns(in: carNode, rim: rim, scale: scale)
        pruneGroundWheelDuplicates(carNode: carNode, container: container, scale: scale)
    }

    private static func stripDuplicateWheelDecals(from root: SCNNode) {
        var remove: [SCNNode] = []
        root.enumerateHierarchy { node, _ in
            let n = (node.name ?? "").lowercased()
            if n.contains("visible_dark_rim") || n.contains("rim_spoke") {
                remove.append(node)
            }
        }
        removeNodes(remove, from: root)
    }

    private static func stripBrakeDiscMeshes(from root: SCNNode) {
        var remove: [SCNNode] = []
        root.enumerateHierarchy { node, _ in
            let n = (node.name ?? "").lowercased()
            if n.contains("brake") && n.contains("wheel") {
                remove.append(node)
            }
        }
        removeNodes(remove, from: root)
    }

    private static func removeNodes(_ remove: [SCNNode], from root: SCNNode) {
        let sorted = remove.sorted { depth(of: $0, in: root) > depth(of: $1, in: root) }
        for node in sorted where node.parent != nil {
            node.removeFromParentNode()
        }
    }

    private static func applyBundledWheelLook(in carNode: SCNNode, rim: GarageRimStyle = .stock) {
        let rimMat = VehicleMaterialLibrary.wheelRim(for: rim)
        let caliperMat = VehicleMaterialLibrary.brakeCaliper(for: rim)
        enumerateMeshes(in: carNode) { node, name in
            guard let geometry = node.geometry else { return }
            if name.contains("visible_dark_rim") || name.contains("rim_spoke") { return }
            node.isHidden = false
            if name.contains("tire") || name.contains("rubber") {
                geometry.materials = geometry.materials.map { _ in VehicleMaterialLibrary.tireRubber() }
            } else if name.contains("brake") || name.contains("caliper") {
                geometry.materials = geometry.materials.map { _ in caliperMat }
            } else if name.contains("common_wheel") || name.contains("helga_wheel")
                || name.contains("alloy_wheel") || name.contains("dark_alloy")
                || ((name.contains("rim") || name.contains("spoke") || name.contains("alloy"))
                    && !name.contains("tire") && !name.contains("rubber")) {
                // Dim stock alloys when a custom face is installed so the new design reads.
                let mat = rim == .stock ? rimMat : VehicleMaterialLibrary.wheelRimDark()
                geometry.materials = geometry.materials.map { _ in mat }
            }
        }
    }

    /// Distinct spoke faces on each hub so rim picks read clearly.
    private static func attachRimFaceDesigns(in carNode: SCNNode, rim: GarageRimStyle, scale: Float) {
        var stale: [SCNNode] = []
        carNode.enumerateHierarchy { node, _ in
            if node.name == "krcRimFace" || node.name == "krcRimAccent" { stale.append(node) }
        }
        stale.forEach { $0.removeFromParentNode() }
        guard rim != .stock else { return }

        let hubs = usdzWheelHubs(in: carNode)
        if hubs.isEmpty {
            let (mn, mx) = carNode.boundingBox
            let midY = mn.y + (mx.y - mn.y) * 0.28
            let pairs: [(Float, Float, Float)] = [
                (mn.x * 0.78 + mx.x * 0.22, midY, mn.z * 0.28 + mx.z * 0.72),
                (mn.x * 0.22 + mx.x * 0.78, midY, mn.z * 0.28 + mx.z * 0.72),
                (mn.x * 0.78 + mx.x * 0.22, midY, mn.z * 0.72 + mx.z * 0.28),
                (mn.x * 0.22 + mx.x * 0.78, midY, mn.z * 0.72 + mx.z * 0.28),
            ]
            let bodySpan = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
            let faceScale = max(scale * 2.4, bodySpan * 0.12)
            for (x, y, z) in pairs {
                let side: Float = x >= 0 ? 1 : -1
                let face = makeRimFace(rim: rim, scale: faceScale, sideSign: side)
                face.position = SCNVector3(x, y, z)
                carNode.addChildNode(face)
            }
            return
        }

        for hub in hubs {
            let name = (hub.name ?? "").lowercased()
            let side = hubSideSign(name: name, hub: hub, body: carNode)
            let faceScale = rimFaceScale(for: hub, fallback: scale)
            let face = makeRimFace(rim: rim, scale: faceScale, sideSign: side)
            hub.addChildNode(face)
        }
    }

    private static func hubSideSign(name: String, hub: SCNNode, body: SCNNode) -> Float {
        if name.contains("_fl") || name.contains("_rl") || name.hasSuffix("fl") || name.hasSuffix("rl") {
            return -1
        }
        if name.contains("_fr") || name.contains("_rr") || name.hasSuffix("fr") || name.hasSuffix("rr") {
            return 1
        }
        return VehicleAxes.meshCenter(in: hub, relativeTo: body).x >= 0 ? 1 : -1
    }

    /// Outward-facing alloy design parented to the wheel hub (spins with the tire).
    private static func makeRimFace(rim: GarageRimStyle, scale: Float, sideSign: Float) -> SCNNode {
        let root = SCNNode()
        root.name = "krcRimFace"

        let rimMat = VehicleMaterialLibrary.wheelRim(for: rim)
        let accentMat = VehicleMaterialLibrary.rimAccent(for: rim)
        let calMat = VehicleMaterialLibrary.brakeCaliper(for: rim)
        let s = scale

        let outerR: Float
        let spokeCount: Int
        let spokeW: Float
        let spokeH: Float
        let dish: Float
        switch rim {
        case .stock:
            outerR = 0.15 * s; spokeCount = 5; spokeW = 0.028 * s; spokeH = 0.11 * s; dish = 0.01 * s
        case .sport5:
            outerR = 0.155 * s; spokeCount = 5; spokeW = 0.034 * s; spokeH = 0.118 * s; dish = 0.012 * s
        case .deepDish, .bronze:
            outerR = 0.16 * s; spokeCount = 6; spokeW = 0.022 * s; spokeH = 0.09 * s; dish = 0.03 * s
        case .hyper, .candyRed:
            outerR = 0.15 * s; spokeCount = 7; spokeW = 0.016 * s; spokeH = 0.122 * s; dish = 0.01 * s
        case .chromeLux:
            outerR = 0.152 * s; spokeCount = 10; spokeW = 0.013 * s; spokeH = 0.112 * s; dish = 0.008 * s
        case .muscle:
            outerR = 0.162 * s; spokeCount = 5; spokeW = 0.042 * s; spokeH = 0.122 * s; dish = 0.016 * s
        case .blackChrome:
            outerR = 0.155 * s; spokeCount = 5; spokeW = 0.032 * s; spokeH = 0.115 * s; dish = 0.012 * s
        }

        let lip = SCNTube(
            innerRadius: CGFloat(outerR * 0.78),
            outerRadius: CGFloat(outerR),
            height: CGFloat(0.024 * s + dish * 0.35)
        )
        lip.materials = [rimMat]
        let lipNode = SCNNode(geometry: lip)
        lipNode.eulerAngles.z = .pi / 2
        root.addChildNode(lipNode)

        if dish > 0.012 * s {
            let barrel = SCNTube(
                innerRadius: CGFloat(outerR * 0.52),
                outerRadius: CGFloat(outerR * 0.76),
                height: CGFloat(dish)
            )
            barrel.materials = [rimMat]
            let barrelNode = SCNNode(geometry: barrel)
            barrelNode.eulerAngles.z = .pi / 2
            barrelNode.position.x = -sideSign * dish * 0.35
            root.addChildNode(barrelNode)
        }

        for i in 0..<spokeCount {
            let a = Float(i) / Float(spokeCount) * Float.pi * 2
            let useAccent = (rim == .chromeLux) || (rim == .hyper || rim == .candyRed) && i % 2 == 1
            let arm = SCNNode(geometry: SCNBox(
                width: CGFloat(spokeW),
                height: CGFloat(spokeH),
                length: CGFloat(max(spokeW * 0.8, 0.01 * s)),
                chamferRadius: CGFloat(0.004 * s)
            ))
            arm.geometry?.materials = [useAccent ? accentMat : rimMat]
            arm.eulerAngles = SCNVector3(a, 0, 0)
            arm.position = SCNVector3(
                -sideSign * dish * 0.15,
                cos(a) * outerR * 0.42,
                sin(a) * outerR * 0.42
            )
            root.addChildNode(arm)
        }

        let cap = SCNCylinder(radius: CGFloat(outerR * 0.24), height: CGFloat(0.03 * s))
        cap.materials = [accentMat]
        let capNode = SCNNode(geometry: cap)
        capNode.eulerAngles.z = .pi / 2
        capNode.position.x = -sideSign * 0.008 * s
        root.addChildNode(capNode)

        let cal = SCNNode(geometry: SCNBox(
            width: CGFloat(0.04 * s),
            height: CGFloat(0.07 * s),
            length: CGFloat(0.09 * s),
            chamferRadius: CGFloat(0.008 * s)
        ))
        cal.geometry?.materials = [calMat]
        cal.position = SCNVector3(-sideSign * (0.02 * s + dish * 0.4), outerR * 0.35, 0)
        root.addChildNode(cal)

        root.position = SCNVector3(sideSign * 0.018 * s, 0, 0)
        root.renderingOrder = 4
        return root
    }

    private static func enumerateMeshes(
        in root: SCNNode,
        _ block: (SCNNode, String) -> Void
    ) {
        root.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            block(node, (node.name ?? "").lowercased())
        }
    }

    private static func stripFlatWheelArt(from root: SCNNode) {
        var remove: [SCNNode] = []
        root.enumerateHierarchy { node, _ in
            if shouldRemoveFlatWheelArt(node) { remove.append(node) }
        }
        let sorted = remove.sorted { depth(of: $0, in: root) > depth(of: $1, in: root) }
        for node in sorted where node.parent != nil {
            node.removeFromParentNode()
        }
    }

    private static func shouldRemoveFlatWheelArt(_ node: SCNNode) -> Bool {
        let n = (node.name ?? "").lowercased()
        if n.contains("tire") || n.contains("rubber") { return false }
        guard node.geometry is SCNPlane else { return false }
        return n.contains("spoke") || n.contains("rim_spoke")
    }

    private static func pruneGroundWheelDuplicates(carNode: SCNNode, container: SCNNode, scale: Float) {
        guard let hubY = averageWheelHubY(carNode: carNode, container: container) else { return }
        let cutoff = hubY - 0.14 * scale
        var remove: [SCNNode] = []
        enumerateMeshes(in: carNode) { node, name in
            guard name.contains("tire") || name.contains("rubber") || name.contains("rim")
                || name.contains("spoke") || name.contains("visible_dark_rim") else { return }
            let local = node.convertPosition(SCNVector3Zero, to: container)
            if local.y < cutoff {
                remove.append(node)
            }
        }
        let sorted = remove.sorted { depth(of: $0, in: carNode) > depth(of: $1, in: carNode) }
        for node in sorted where node.parent != nil {
            node.removeFromParentNode()
        }
    }

    private static func averageWheelHubY(carNode: SCNNode, container: SCNNode) -> Float? {
        var ys: [Float] = []
        for prefix in cornerPrefixes {
            guard let hub = findNode(matchingPrefix: prefix, in: carNode) else { continue }
            let local = hub.convertPosition(SCNVector3Zero, to: container)
            ys.append(local.y)
        }
        guard !ys.isEmpty else { return nil }
        return ys.reduce(0, +) / Float(ys.count)
    }

    private static func purgeContainerOrphans(_ container: SCNNode) {
        for child in container.childNodes where child.name == "wheelGroup" {
            child.removeFromParentNode()
        }
    }

    private static func depth(of node: SCNNode, in root: SCNNode) -> Int {
        var d = 0
        var current: SCNNode? = node
        while let p = current, p !== root {
            d += 1
            current = p.parent
        }
        return d
    }

    // MARK: - Procedural fallback

    static func attachWheels(to root: SCNNode, scale s: Float, anchors: [Anchor]) {
        attachStyledWheels(to: root, style: .sport5, scale: s, anchors: anchors)
    }

    static func attachStyledWheels(
        to root: SCNNode,
        style: VehicleWheelStyle,
        scale s: Float,
        anchors: [Anchor]
    ) {
        let rim = garageRim(for: style)
        for anchor in anchors {
            let wg = makeWheelNode(scale: s, sideSign: anchor.sideSign, style: style, rim: rim)
            wg.position = SCNVector3(anchor.x, anchor.y, anchor.z)
            root.addChildNode(wg)
        }
    }

    private static func garageRim(for style: VehicleWheelStyle) -> GarageRimStyle {
        switch style {
        case .sport5: return .sport5
        case .deepDish, .rally: return .deepDish
        case .hyper: return .hyper
        case .muscle: return .muscle
        case .chromeLux: return .chromeLux
        }
    }

    static func makeWheelNode(
        scale s: Float,
        sideSign: Float,
        style: VehicleWheelStyle = .sport5,
        rim: GarageRimStyle = .sport5
    ) -> SCNNode {
        let wg = SCNNode()
        wg.name = "wheelGroup"

        let rubber = VehicleMaterialLibrary.tireRubber()
        let rimMat = VehicleMaterialLibrary.wheelRim(for: rim)
        let accent = VehicleMaterialLibrary.rimAccent(for: rim)
        let calMat = VehicleMaterialLibrary.brakeCaliper(for: rim)

        let (ringR, pipeR, spokeCount, spokeReach) = wheelDimensions(style: style, scale: s)
        let tread = SCNNode(geometry: SCNTorus(ringRadius: CGFloat(ringR), pipeRadius: CGFloat(pipeR)))
        tread.geometry?.materials = [rubber]
        tread.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
        tread.castsShadow = true
        wg.addChildNode(tread)

        let lip = SCNTube(
            innerRadius: CGFloat(ringR - pipeR * 0.35),
            outerRadius: CGFloat(ringR - pipeR * 0.05),
            height: CGFloat(0.05 * s)
        )
        lip.materials = [rimMat]
        let lipNode = SCNNode(geometry: lip)
        lipNode.eulerAngles.y = .pi / 2
        wg.addChildNode(lipNode)

        let spokeW: Float
        switch style {
        case .chromeLux, .hyper: spokeW = 0.028 * s
        case .muscle: spokeW = 0.07 * s
        case .deepDish, .rally: spokeW = 0.04 * s
        default: spokeW = 0.05 * s
        }

        for i in 0..<spokeCount {
            let a = Float(i) / Float(spokeCount) * Float.pi * 2
            let spoke = SCNNode(geometry: SCNBox(
                width: CGFloat(spokeW),
                height: CGFloat(spokeReach * 1.7),
                length: CGFloat(spokeW * 0.75),
                chamferRadius: CGFloat(0.006 * s)
            ))
            spoke.geometry?.materials = [i % 2 == 0 ? rimMat : accent]
            spoke.eulerAngles = SCNVector3(a, Float.pi / 2, 0)
            spoke.position = SCNVector3(0, cos(a) * spokeReach, sin(a) * spokeReach)
            wg.addChildNode(spoke)
        }

        let hub = SCNCylinder(radius: CGFloat(0.08 * s), height: CGFloat(0.08 * s))
        hub.materials = [accent]
        let hubNode = SCNNode(geometry: hub)
        hubNode.eulerAngles.y = .pi / 2
        wg.addChildNode(hubNode)

        let cal = SCNNode(geometry: SCNBox(
            width: CGFloat(0.1 * s), height: CGFloat(0.18 * s),
            length: CGFloat(0.12 * s), chamferRadius: CGFloat(0.016 * s)
        ))
        cal.geometry?.materials = [calMat]
        cal.position = SCNVector3(-sideSign * 0.1 * s, 0.16 * s, 0)
        cal.castsShadow = true
        wg.addChildNode(cal)

        return wg
    }

    private static func wheelDimensions(style: VehicleWheelStyle, scale s: Float) -> (Float, Float, Int, Float) {
        switch style {
        case .sport5: return (0.42 * s, 0.14 * s, 5, 0.13 * s)
        case .deepDish: return (0.4 * s, 0.16 * s, 6, 0.1 * s)
        case .rally: return (0.44 * s, 0.15 * s, 5, 0.12 * s)
        case .hyper: return (0.43 * s, 0.12 * s, 7, 0.14 * s)
        case .muscle: return (0.45 * s, 0.17 * s, 5, 0.135 * s)
        case .chromeLux: return (0.41 * s, 0.13 * s, 10, 0.125 * s)
        }
    }

    // MARK: - Spin

    static func wheelGroups(in root: SCNNode) -> [SCNNode] {
        var result: [SCNNode] = []
        root.enumerateHierarchy { node, _ in
            if node.name == "wheelGroup" { result.append(node) }
        }
        return result
    }

    static func usdzWheelHubs(in root: SCNNode) -> [SCNNode] {
        var hubs: [SCNNode] = []
        for prefix in cornerPrefixes {
            if let hub = findNode(matchingPrefix: prefix, in: root) { hubs.append(hub) }
        }
        return hubs
    }

    private static func rimFaceScale(for hub: SCNNode, fallback: Float) -> Float {
        let (mn, mx) = hub.boundingBox
        let span = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
        // makeRimFace uses outerR ≈ 0.15 * scale; match the inner rim of the USDZ tire.
        if span > 0.12 {
            return max(fallback, span * 3.0)
        }
        return max(fallback * 2.6, 1.8)
    }

    private static func findNode(matchingPrefix prefix: String, in root: SCNNode) -> SCNNode? {
        let key = prefix.lowercased()
        var hit: SCNNode?
        root.enumerateHierarchy { node, stop in
            let n = (node.name ?? "").lowercased()
            if n.contains("krcrim") { return }
            if n == key || n.hasPrefix(key + "_") || n.contains(key) {
                hit = node
                stop.pointee = true
            }
        }
        return hit
    }

    private static var hubRestY: [ObjectIdentifier: Float] = [:]

    /// Subtle per-corner travel so braking/throttle reads on the chassis.
    static func applySuspension(in root: SCNNode, compression: SIMD4<Float>) {
        let hubs = usdzWheelHubs(in: root)
        let corners = hubs.isEmpty ? wheelGroups(in: root) : hubs
        guard !corners.isEmpty else { return }
        if hubRestY.count > 48 { hubRestY.removeAll(keepingCapacity: true) }
        let values: [Float] = [compression.x, compression.y, compression.z, compression.w]
        for (i, hub) in corners.prefix(4).enumerated() {
            let id = ObjectIdentifier(hub)
            if hubRestY[id] == nil { hubRestY[id] = hub.position.y }
            let rest = hubRestY[id] ?? hub.position.y
            let travel = max(-0.04, min(0.04, values[i]))
            hub.position.y = rest + travel
        }
    }

    static func spinWheels(in root: SCNNode, speed: Float, dt: Float) {
        guard speed > 0.0001 else { return }
        let delta = speed * 7.2 * dt
        let hubs = usdzWheelHubs(in: root)
        if hubs.isEmpty {
            for hub in wheelGroups(in: root) {
                hub.eulerAngles.x += delta
            }
        } else {
            for hub in hubs {
                hub.eulerAngles.x += delta
            }
        }
    }
}
