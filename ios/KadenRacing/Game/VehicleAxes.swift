import SceneKit
import simd

/// Resolves which local Z side is the front bumper for USDZ vs procedural cars.
enum VehicleAxes {

    struct Frame {
        var width: Float
        var height: Float
        var length: Float
        var baseY: Float
        var frontZ: Float
        var rearZ: Float

        var towardCenterFromFront: Float {
            rearZ > frontZ ? 1 : -1
        }

        func isNearFront(z: Float) -> Bool {
            abs(z - frontZ) <= length * 0.26
        }

        func isNearRear(z: Float) -> Bool {
            abs(z - rearZ) <= length * 0.26
        }

        /// Slightly wider band for USDZ lamp slices that sit just inside the bumper.
        func isNearRearLamp(z: Float) -> Bool {
            abs(z - rearZ) <= length * 0.28
        }

        /// SceneKit spot lights aim along local **-Z**; rotate π when the hood faces +Z.
        var headlightSpotYaw: Float {
            frontZ > rearZ ? Float.pi : 0
        }

        func tailLampY(in body: SCNNode) -> Float {
            var hubY: [Float] = []
            for prefix in ["Wheel_RL", "Wheel_RR"] {
                if let y = hubWorldY(prefix: prefix, in: body) {
                    hubY.append(y)
                }
            }
            if !hubY.isEmpty {
                return hubY.reduce(0, +) / Float(hubY.count) + height * 0.11
            }
            return baseY + height * 0.3
        }
    }

    /// Idempotent front/rear bumper markers for lighting (USDZ + procedural).
    static func ensureMarkers(on body: SCNNode) {
        body.childNode(withName: "krcAxleFront", recursively: false)?.removeFromParentNode()
        body.childNode(withName: "krcAxleRear", recursively: false)?.removeFromParentNode()

        let (minB, maxB) = body.boundingBox
        let midY = (minB.y + maxB.y) * 0.5
        let frontIsMaxZ = resolveFrontIsMaxZ(in: body, minB: minB, maxB: maxB)
        let frontZ = frontIsMaxZ ? maxB.z : minB.z
        let rearZ = frontIsMaxZ ? minB.z : maxB.z

        let front = SCNNode()
        front.name = "krcAxleFront"
        front.position = SCNVector3(0, midY, frontZ)
        body.addChildNode(front)

        let rear = SCNNode()
        rear.name = "krcAxleRear"
        rear.position = SCNVector3(0, midY, rearZ)
        body.addChildNode(rear)
    }

    static func frame(in body: SCNNode) -> Frame? {
        let (minB, maxB) = body.boundingBox
        let w = maxB.x - minB.x
        let h = maxB.y - minB.y
        let l = maxB.z - minB.z
        guard w > 0.1, h > 0.1, l > 0.1 else { return nil }

        if let front = body.childNode(withName: "krcAxleFront", recursively: true),
           let rear = body.childNode(withName: "krcAxleRear", recursively: true) {
            return Frame(
                width: w,
                height: h,
                length: l,
                baseY: minB.y,
                frontZ: front.position.z,
                rearZ: rear.position.z
            )
        }

        let frontIsMaxZ = resolveFrontIsMaxZ(in: body, minB: minB, maxB: maxB)
        if frontIsMaxZ {
            return Frame(width: w, height: h, length: l, baseY: minB.y, frontZ: maxB.z, rearZ: minB.z)
        }
        return Frame(width: w, height: h, length: l, baseY: minB.y, frontZ: minB.z, rearZ: maxB.z)
    }

    static func meshCenter(in node: SCNNode, relativeTo body: SCNNode) -> SIMD3<Float> {
        let (minB, maxB) = node.boundingBox
        let hasBox = (maxB.x - minB.x) > 0.001 || (maxB.y - minB.y) > 0.001 || (maxB.z - minB.z) > 0.001
        let center: SCNVector3
        if hasBox {
            center = SCNVector3(
                (minB.x + maxB.x) * 0.5,
                (minB.y + maxB.y) * 0.5,
                (minB.z + maxB.z) * 0.5
            )
        } else {
            center = SCNVector3Zero
        }
        let local = body.convertPosition(center, from: node)
        return SIMD3<Float>(local.x, local.y, local.z)
    }

    private static func resolveFrontIsMaxZ(in body: SCNNode, minB: SCNVector3, maxB: SCNVector3) -> Bool {
        let frontZs = ["Wheel_FL", "Wheel_FR"].compactMap { hubWorldZ(prefix: $0, in: body) }
        let rearZs = ["Wheel_RL", "Wheel_RR"].compactMap { hubWorldZ(prefix: $0, in: body) }
        if !frontZs.isEmpty, !rearZs.isEmpty {
            let f = frontZs.reduce(0, +) / Float(frontZs.count)
            let r = rearZs.reduce(0, +) / Float(rearZs.count)
            if abs(f - r) > 0.04 { return f > r }
        }

        let frontMeshZ = averageMeshCenterZ(
            in: body,
            matching: ["grille", "bumper_f", "front_bumper", "windshield", "windscreen", "hood", "headlight"]
        )
        let rearMeshZ = averageMeshCenterZ(
            in: body,
            matching: ["trunk", "spoiler", "tailgate", "rear_bumper", "bumper_r", "taillight", "tail_light", "exhaust", "t red", "red a"]
        )
        if let fz = frontMeshZ, let rz = rearMeshZ, abs(fz - rz) > 0.05 {
            return fz > rz
        }

        return geometryHeavyEndIsMaxZ(in: body, minB: minB, maxB: maxB)
    }

    /// More exterior mesh in the +Z third ⇒ hood faces +Z; more in −Z third ⇒ hood faces −Z (bundled USDZ).
    private static func geometryHeavyEndIsMaxZ(in body: SCNNode, minB: SCNVector3, maxB: SCNVector3) -> Bool {
        let span = maxB.z - minB.z
        guard span > 0.1 else { return true }
        let band = span / 3
        var lowCount: Float = 0
        var highCount: Float = 0
        body.enumerateHierarchy { node, _ in
            guard node.geometry != nil, !node.isHidden else { return }
            let n = (node.name ?? "").lowercased()
            if n.hasPrefix("krc") || n.contains("wheel") || n.contains("tire") { return }
            let z = meshCenter(in: node, relativeTo: body).z
            if z <= minB.z + band { lowCount += 1 }
            if z >= maxB.z - band { highCount += 1 }
        }
        if lowCount < 1, highCount < 1 { return true }
        return highCount >= lowCount
    }

    private static func averageMeshCenterZ(in body: SCNNode, matching keys: [String]) -> Float? {
        var zs: [Float] = []
        body.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let n = (node.name ?? "").lowercased()
            guard keys.contains(where: { n.contains($0) }) else { return }
            zs.append(meshCenter(in: node, relativeTo: body).z)
        }
        guard !zs.isEmpty else { return nil }
        return zs.reduce(0, +) / Float(zs.count)
    }

    private static func hubWorldZ(prefix: String, in body: SCNNode) -> Float? {
        guard let hub = findWheelHub(prefix: prefix, in: body) else { return nil }
        return meshCenter(in: hub, relativeTo: body).z
    }

    private static func hubWorldY(prefix: String, in body: SCNNode) -> Float? {
        guard let hub = findWheelHub(prefix: prefix, in: body) else { return nil }
        return meshCenter(in: hub, relativeTo: body).y
    }

    private static func findWheelHub(prefix: String, in body: SCNNode) -> SCNNode? {
        let key = prefix.lowercased()
        var hit: SCNNode?
        body.enumerateHierarchy { node, stop in
            let n = (node.name ?? "").lowercased()
            if n == key || n.hasSuffix("_\(key)") || n.contains(key) {
                hit = node
                stop.pointee = true
            }
        }
        return hit
    }
}
