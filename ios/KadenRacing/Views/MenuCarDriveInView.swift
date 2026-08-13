import SceneKit
import SwiftUI

/// Player car slides in from the left on the main menu, then parks on the right in a 3/4 hero pose.
struct MenuCarDriveInView: UIViewRepresentable {
    /// Scene X where the car rests (right side of the menu hero).
    static let restX: Float = 1.38
    /// Off-screen left — matches web `krc-car-3d.js` menu drive-in.
    private static let startX: Float = -5.4
    let car: CarChoice
    var introNonce: Int = 0
    var height: CGFloat = 112

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = true
        view.scene = SCNScene()
        view.delegate = context.coordinator
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.setCar(car, in: view)
        if context.coordinator.lastIntroNonce != introNonce {
            context.coordinator.lastIntroNonce = introNonce
            context.coordinator.scheduleIntro(in: view)
        }
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        private weak var sceneView: SCNView?
        private weak var menuCamera: SCNNode?
        private var carRoot: SCNNode?
        private var currentCarId: String?
        private var introScheduled = false
        private var isDriving = false
        private var isRevving = false
        private var settleBob: Float = 0
        private var lastWheelSpinTime: TimeInterval = 0
        var lastIntroNonce = -1

        /// Matches race `WheelAssembly.spinWheels` (~0.22 rad/frame at 60fps when driving).
        private static let driveSpinSpeed: Float = 1.85
        private static let revSpinSpeed: Float = 0.75

        func attach(to view: SCNView) {
            sceneView = view
            guard let scene = view.scene else { return }

            let amb = SCNNode()
            amb.light = SCNLight()
            amb.light?.type = .ambient
            amb.light?.intensity = 920
            amb.light?.color = UIColor(white: 0.95, alpha: 1)
            scene.rootNode.addChildNode(amb)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 1680
            key.position = SCNVector3(2, 7, 5)
            key.eulerAngles = SCNVector3(-0.85, 0.35, 0)
            scene.rootNode.addChildNode(key)

            let rim = SCNNode()
            rim.light = SCNLight()
            rim.light?.type = .directional
            rim.light?.intensity = 420
            rim.light?.color = UIColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
            rim.eulerAngles = SCNVector3(-0.5, -0.9, 0)
            scene.rootNode.addChildNode(rim)

            let cam = SCNNode()
            let camera = SCNCamera()
            camera.fieldOfView = 36
            camera.wantsHDR = true
            camera.bloomIntensity = 0.35
            camera.bloomThreshold = 0.75
            cam.camera = camera
            cam.name = "menuCarCamera"
            cam.position = SCNVector3(0.15, 0.72, 4.35)
            cam.look(at: SCNVector3(MenuCarDriveInView.restX * 0.55 - 0.05, 0.28, 0))
            scene.rootNode.addChildNode(cam)
            menuCamera = cam
            view.pointOfView = cam

            scene.lightingEnvironment.contents = KRCSceneKitHelpers.studioEnvironmentMap()
            scene.lightingEnvironment.intensity = 2.2
            scene.background.contents = UIColor.clear
        }

        func setCar(_ car: CarChoice, in view: SCNView) {
            guard let scene = view.scene else { return }
            if currentCarId == car.id, carRoot != nil { return }

            currentCarId = car.id
            introScheduled = false
            isDriving = false
            isRevving = false

            carRoot?.removeFromParentNode()
            lastWheelSpinTime = 0

            let root = SCNNode()
            root.name = "menuCarRoot"
            RaceCarGeometry.build(
                root: root,
                bodyColor: car.uiColor,
                carId: car.id,
                scale: 0.78,
                isPlayer: true,
                category: GameCatalog.vehicleCategory(for: car.id),
                applyLivery: true,
                lod: .garage
            )
            // Hood toward +X (screen right). SceneKit Y sign is opposite Three.js menu (-0.5π).
            root.eulerAngles.y = Float.pi * 0.5
            root.position = SCNVector3(MenuCarDriveInView.startX, 0, 0)
            scene.rootNode.addChildNode(root)
            carRoot = root
            RaceParticles.prepareMenuCar(root)
            if let scene = view.scene {
                AutomotiveReflectionSystem.bindScene(scene, to: root)
            }
            frameCamera(on: root)
            view.pointOfView = menuCamera
            scheduleVisibilityFallback()
        }

        func scheduleIntro(in view: SCNView) {
            guard carRoot != nil else { return }
            introScheduled = true
            view.pointOfView = menuCamera
            view.setNeedsLayout()
            view.layoutIfNeeded()

            func attempt(retry: Int) {
                guard let view = sceneView, carRoot != nil else { return }
                if view.bounds.width > 20, view.bounds.height > 20 {
                    runIntro()
                } else if retry < 8 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        attempt(retry: retry + 1)
                    }
                } else {
                    snapCarToRestPose()
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                attempt(retry: 0)
            }
        }

        /// If drive-in never runs (zero layout pass), still show the car parked on the right.
        private func scheduleVisibilityFallback() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { [weak self] in
                guard let self, let root = self.carRoot, !self.isDriving else { return }
                if abs(root.position.x - MenuCarDriveInView.restX) > 0.35 {
                    self.snapCarToRestPose()
                }
            }
        }

        private func snapCarToRestPose() {
            guard let root = carRoot else { return }
            root.removeAllActions()
            isDriving = false
            isRevving = false
            root.position = SCNVector3(MenuCarDriveInView.restX, 0, 0)
            root.eulerAngles.y = Float.pi * 0.5
            root.eulerAngles.z = 0
        }

        private func frameCamera(on car: SCNNode) {
            guard let cam = menuCamera else { return }
            let (minB, maxB) = car.boundingBox
            let center = SCNVector3(
                (minB.x + maxB.x) * 0.5,
                (minB.y + maxB.y) * 0.5,
                (minB.z + maxB.z) * 0.5
            )
            let size = SCNVector3(maxB.x - minB.x, maxB.y - minB.y, maxB.z - minB.z)
            let radius = max(size.x, size.y, size.z, 0.5) * 0.55
            let dist = max(4.2, radius * 3.1)
            cam.position = SCNVector3(center.x + 0.12, center.y + radius * 0.38, center.z + dist)
            cam.look(at: SCNVector3(MenuCarDriveInView.restX * 0.52, center.y * 0.42, 0))
        }

        private func runIntro() {
            guard !isDriving, let root = carRoot else { return }
            introScheduled = false
            isDriving = true
            isRevving = false
            lastWheelSpinTime = 0

            root.removeAllActions()
            root.position = SCNVector3(MenuCarDriveInView.startX, 0, 0)
            root.eulerAngles.y = Float.pi * 0.5
            root.eulerAngles.z = 0

            Task { @MainActor in
                MenuIntroAudioController.shared.playRevSequence()
            }

            let drive = SCNAction.move(to: SCNVector3(MenuCarDriveInView.restX, 0, 0), duration: 1.05)
            drive.timingMode = .easeOut
            root.runAction(drive) { [weak self] in
                DispatchQueue.main.async {
                    self?.isDriving = false
                    self?.isRevving = true
                    self?.playSettleBounce()
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.72) { [weak self] in
                self?.isRevving = false
                if let root = self?.carRoot {
                    RaceParticles.updateMenuExhaust(on: root, active: false)
                }
            }
        }

        private func playSettleBounce() {
            guard let root = carRoot else { return }
            let up = SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: 0.12)
            let down = SCNAction.moveBy(x: 0, y: -0.04, z: 0, duration: 0.16)
            up.timingMode = .easeOut
            down.timingMode = .easeIn
            root.runAction(SCNAction.sequence([up, down]))
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            AutomotiveReflectionSystem.update(renderer: renderer, atTime: time)
            guard (isDriving || isRevving), let root = carRoot else { return }

            let dt: Float
            if lastWheelSpinTime > 0 {
                dt = Float(min(0.05, time - lastWheelSpinTime))
            } else {
                dt = 1.0 / 60.0
            }
            lastWheelSpinTime = time

            // Same +X roll as race (procedural wheelGroup + USDZ tire meshes).
            let spinSpeed = isDriving ? Self.driveSpinSpeed : Self.revSpinSpeed
            WheelAssembly.spinWheels(in: root, speed: spinSpeed, dt: dt)
            RaceParticles.updateMenuExhaust(on: root, active: isDriving || isRevving)

            if isRevving {
                settleBob += 0.14
                root.eulerAngles.z = sin(settleBob) * 0.012
            }
        }

        func teardown() {
            Task { @MainActor in
                MenuIntroAudioController.shared.stop()
            }
            carRoot?.removeAllActions()
            carRoot = nil
            menuCamera = nil
            lastWheelSpinTime = 0
            sceneView?.delegate = nil
            sceneView?.pointOfView = nil
            sceneView = nil
        }
    }
}
