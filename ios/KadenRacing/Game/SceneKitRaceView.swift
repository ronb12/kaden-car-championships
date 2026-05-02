import SwiftUI
import SceneKit

/// Hosts the native SceneKit racetrack inside SwiftUI.
struct SceneKitRaceView: UIViewRepresentable {
    let engine: NativeRaceEngine

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        view.rendersContinuously = true
        SceneKitMobileTuning.apply(to: view)
        engine.attach(to: view)
        // Controls are in the SwiftUI overlay; SCNView should not take touches (ZStack order).
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
