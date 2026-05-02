import SceneKit

/// Distance-based visibility window around the player’s **`t` parameter** — cheap occlusion substitute on mobile.
final class CityStreamingCoordinator {

    private weak var decorRoot: SCNNode?
    private let band: Int

    init(decorRoot: SCNNode, trackPoints: Int) {
        self.decorRoot = decorRoot
        self.band = max(4, min(18, trackPoints / 24))
    }

    func update(playerT: Float) {
        guard let decorRoot, !decorRoot.childNodes.isEmpty else { return }
        let nodes = decorRoot.childNodes
        let n = nodes.count
        let focus = Int(playerT * Float(n)) % n
        for i in 0..<n {
            let wrapDist = min(abs(i - focus), n - abs(i - focus))
            nodes[i].isHidden = wrapDist > band
        }
    }
}
