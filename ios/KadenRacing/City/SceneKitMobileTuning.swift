import SceneKit

/// Central place for **mobile-first** SceneKit defaults (LOD hints, lighting budget).
enum SceneKitMobileTuning {

    static func apply(to view: SCNView) {
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
    }
}
