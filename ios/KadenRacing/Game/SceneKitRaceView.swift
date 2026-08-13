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

/// Live rear-view — same race scene, camera looking behind the player so rivals actually appear.
struct RearViewMirrorView: View {
    let engine: NativeRaceEngine
    var portrait: Bool = true

    var body: some View {
        RearViewMirrorSCNView(engine: engine)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 1.2)
            )
            .overlay(alignment: .top) {
                Text("REAR")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.top, 3)
            }
            .frame(width: portrait ? 172 : 214, height: portrait ? 54 : 66)
            .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
            .allowsHitTesting(false)
    }
}

private struct RearViewMirrorSCNView: UIViewRepresentable {
    let engine: NativeRaceEngine

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        view.rendersContinuously = true
        view.isJitteringEnabled = false
        view.antialiasingMode = .none
        view.preferredFramesPerSecond = 24
        view.autoenablesDefaultLighting = false
        view.isUserInteractionEnabled = false
        view.showsStatistics = false
        view.contentScaleFactor = 1
        bind(view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        bind(uiView)
    }

    private func bind(_ view: SCNView) {
        let scene = engine.raceScene()
        if view.scene !== scene {
            view.scene = scene
        }
        view.pointOfView = engine.rearViewPointOfView()
    }
}
