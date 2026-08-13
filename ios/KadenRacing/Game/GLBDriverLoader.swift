import SceneKit
import UIKit

/// Bundled cockpit driver (`kenney-blocky-driver.glb`).
enum GLBDriverLoader {
    private static var cached: SCNNode?

    static func attach(to carRoot: SCNNode, scale s: Float) {
        guard let driver = load(scale: s) else { return }
        carRoot.addChildNode(driver)
    }

    private static func load(scale s: Float) -> SCNNode? {
        if let cached {
            return prepare(node: cached.clone(), scale: s)
        }
        guard let url = Bundle.main.url(forResource: "kenney-blocky-driver", withExtension: "glb", subdirectory: "models/characters")
            ?? Bundle.main.url(forResource: "kenney-blocky-driver", withExtension: "glb") else {
            return nil
        }
        guard let source = SCNSceneSource(url: url, options: nil),
              let scene = source.scene(options: nil) else {
            return nil
        }
        let wrapper = SCNNode()
        for child in scene.rootNode.childNodes {
            wrapper.addChildNode(child.clone())
        }
        guard !wrapper.childNodes.isEmpty else { return nil }
        cached = wrapper
        return prepare(node: wrapper.clone(), scale: s)
    }

    private static func prepare(node: SCNNode, scale s: Float) -> SCNNode {
        let (minVec, maxVec) = node.boundingBox
        let height = max(maxVec.y - minVec.y, 0.001)
        let targetHeight: Float = 0.55 * s
        let uniform = targetHeight / height
        node.scale = SCNVector3(uniform, uniform, uniform)
        node.position = SCNVector3(0.05 * s, 0.58 * s, 0.12 * s)
        node.eulerAngles = SCNVector3(0, Float.pi, 0)
        node.name = "krcDriver"
        return node
    }
}
