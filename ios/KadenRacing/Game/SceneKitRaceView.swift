import SwiftUI
import SceneKit

/// Hosts the native SceneKit racetrack inside SwiftUI.
struct SceneKitRaceView: UIViewRepresentable {
    let engine: NativeRaceEngine
    var onScenePrepared: (() -> Void)?

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        view.rendersContinuously = true
        view.isJitteringEnabled = EnvironmentGraphicsSettings.quality != .low
        SceneKitMobileTuning.apply(to: view)
        engine.attach(to: view)
        // Controls are in the SwiftUI overlay; SCNView should not take touches (ZStack order).
        view.isUserInteractionEnabled = false
        view.showsStatistics = false
        warmUpShaders(in: view, completion: onScenePrepared)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    private func warmUpShaders(in view: SCNView, completion: (() -> Void)?) {
        guard let completion else { return }
        guard let root = view.scene?.rootNode else {
            completion()
            return
        }
        var nodes: [SCNNode] = []
        root.enumerateChildNodes { node, _ in
            nodes.append(node)
        }
        nodes.append(root)
        view.prepare(nodes) { _ in
            DispatchQueue.main.async(execute: completion)
        }
    }
}
