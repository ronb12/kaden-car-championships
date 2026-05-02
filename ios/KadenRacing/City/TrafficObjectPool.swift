import SceneKit

/// Pool for reusable traffic / prop nodes — dequeue before spawning AI extras; enqueue when off-loop.
final class TrafficNodePool {

    private var storage: [SCNNode] = []
    private let maxCount: Int

    init(maxCount: Int = 24) {
        self.maxCount = maxCount
    }

    func dequeue(factory: () -> SCNNode) -> SCNNode {
        if let n = storage.popLast() {
            n.isHidden = false
            return n
        }
        return factory()
    }

    func enqueue(_ node: SCNNode) {
        guard storage.count < maxCount else {
            node.removeFromParentNode()
            return
        }
        node.isHidden = true
        storage.append(node)
    }
}
