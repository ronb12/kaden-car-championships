import SceneKit
import SwiftUI

/// Player car slides in from the left on the main menu, then parks on the right in a 3/4 hero pose.
struct MenuCarDriveInView: UIViewRepresentable {
    /// Scene X where the car rests (right side of the menu hero).
    static let restX: Float = 1.42
    /// Off-screen left — matches web `krc-car-3d.js` menu drive-in.
    private static let startX: Float = -5.6
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
        private weak var groundPlate: SCNNode?
        private weak var keyLight: SCNNode?
        private weak var rimLight: SCNNode?
        private var carRoot: SCNNode?
        private var currentCarKey: String?
        private var introScheduled = false
        private var isDriving = false
        private var isRevving = false
        private var settleBob: Float = 0
        private var lastWheelSpinTime: TimeInterval = 0
        private var lightPulse: Float = 0
        var lastIntroNonce = -1

        /// Matches race `WheelAssembly.spinWheels` (~0.22 rad/frame at 60fps when driving).
        private static let driveSpinSpeed: Float = 1.85
        private static let revSpinSpeed: Float = 0.75
        private static let heroScale: CGFloat = 0.92

        func attach(to view: SCNView) {
            sceneView = view
            guard let scene = view.scene else { return }

            // Soft ambient — keeps shadows readable without flattening paint.
            let amb = SCNNode()
            amb.light = SCNLight()
            amb.light?.type = .ambient
            amb.light?.intensity = 520
            amb.light?.color = UIColor(red: 0.78, green: 0.84, blue: 0.95, alpha: 1)
            scene.rootNode.addChildNode(amb)

            // Key — bright showroom overhead from front-right.
            let key = SCNNode()
            key.name = "menuKeyLight"
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 2100
            key.light?.color = UIColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 1)
            key.position = SCNVector3(3.2, 8.5, 6.2)
            key.eulerAngles = SCNVector3(-0.95, 0.42, 0)
            scene.rootNode.addChildNode(key)
            keyLight = key

            // Cool fill from camera-left so body panels don't go black.
            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .directional
            fill.light?.intensity = 780
            fill.light?.color = UIColor(red: 0.55, green: 0.72, blue: 1.0, alpha: 1)
            fill.eulerAngles = SCNVector3(-0.35, -1.05, 0)
            scene.rootNode.addChildNode(fill)

            // Warm brand rim — orange edge light along the silhouette.
            let rim = SCNNode()
            rim.name = "menuRimLight"
            rim.light = SCNLight()
            rim.light?.type = .directional
            rim.light?.intensity = 920
            rim.light?.color = UIColor(red: 1.0, green: 0.48, blue: 0.12, alpha: 1)
            rim.eulerAngles = SCNVector3(-0.25, 2.45, 0)
            scene.rootNode.addChildNode(rim)
            rimLight = rim

            // Soft omni near the hood for clear-coat sparkle (kept modest so it doesn't bloom into a streak).
            let sparkle = SCNNode()
            sparkle.light = SCNLight()
            sparkle.light?.type = .omni
            sparkle.light?.intensity = 260
            sparkle.light?.color = UIColor(red: 1.0, green: 0.96, blue: 0.9, alpha: 1)
            sparkle.light?.attenuationStartDistance = 2.0
            sparkle.light?.attenuationEndDistance = 7
            sparkle.position = SCNVector3(MenuCarDriveInView.restX + 0.35, 1.15, 2.1)
            scene.rootNode.addChildNode(sparkle)

            let ground = KRCSceneKitHelpers.menuHeroGroundPlate()
            ground.position = SCNVector3(MenuCarDriveInView.restX, 0, 0)
            scene.rootNode.addChildNode(ground)
            groundPlate = ground

            let cam = SCNNode()
            let camera = SCNCamera()
            camera.fieldOfView = 32
            camera.zNear = 0.05
            camera.zFar = 80
            camera.wantsHDR = true
            camera.bloomIntensity = 0.28
            camera.bloomThreshold = 0.78
            camera.bloomBlurRadius = 4
            camera.wantsExposureAdaptation = false
            camera.minimumExposure = -0.2
            camera.maximumExposure = 0.55
            cam.camera = camera
            cam.name = "menuCarCamera"
            cam.position = SCNVector3(0.05, 0.78, 4.55)
            cam.look(at: SCNVector3(MenuCarDriveInView.restX * 0.58, 0.32, 0))
            scene.rootNode.addChildNode(cam)
            menuCamera = cam
            view.pointOfView = cam

            // Brighter IBL — showroom clear-coat / metal read.
            scene.lightingEnvironment.contents = KRCSceneKitHelpers.studioEnvironmentMap()
            scene.lightingEnvironment.intensity = 1.7
            scene.background.contents = UIColor.clear
        }

        func setCar(_ car: CarChoice, in view: SCNView) {
            guard let scene = view.scene else { return }
            let bodyColor = GarageCustomization.bodyColor(for: car)
            let style = GarageCustomization.style(for: car.id)
            let carKey = "\(car.id)-\(bodyColor.hash)-\(style.paint.rawValue)-\(style.wrap.rawValue)-\(style.rim.rawValue)"
            if currentCarKey == carKey, carRoot != nil { return }

            currentCarKey = carKey
            introScheduled = false
            isDriving = false
            isRevving = false

            if let previous = carRoot {
                AutomotiveReflectionSystem.unbindScene(scene, from: previous)
                AutomotiveReflectionSystem.unregister(vehicleRoot: previous)
                previous.removeFromParentNode()
            }
            lastWheelSpinTime = 0

            let root = SCNNode()
            root.name = "menuCarRoot"
            RaceCarGeometry.build(
                root: root,
                bodyColor: bodyColor,
                carId: car.id,
                scale: Self.heroScale,
                isPlayer: true,
                category: GameCatalog.vehicleCategory(for: car.id),
                applyLivery: true,
                lod: .garage,
                paintContext: .photo
            )
            // Hood toward +X (screen right). SceneKit Y sign is opposite Three.js menu (-0.5π).
            root.eulerAngles.y = Float.pi * 0.5
            root.position = SCNVector3(MenuCarDriveInView.startX, 0.02, 0)
            scene.rootNode.addChildNode(root)
            carRoot = root
            RaceParticles.prepareMenuCar(root)
            AutomotiveReflectionSystem.bindScene(scene, to: root)
            // Soft lens only — spots off. Avoid bright fallback boxes that read as junk on the nose.
            VehicleLighting.setHeadlights(on: root, enabled: true, level: 0.22, isPlayer: true)
            muteMenuHeadlightSpots(on: root)
            recessMenuHeadlightLenses(on: root)
            polishMenuPaint(on: root)
            frameCamera(on: root)
            view.pointOfView = menuCamera
            scheduleVisibilityFallback()
        }

        /// Extra clear-coat punch so the home hero reads richer than the in-race LOD.
        private func polishMenuPaint(on root: SCNNode) {
            root.enumerateHierarchy { node, _ in
                guard let mats = node.geometry?.materials else { return }
                for mat in mats {
                    guard mat.lightingModel == .physicallyBased else { continue }
                    if #available(iOS 13.0, *) {
                        let coat = (mat.clearCoat.contents as? NSNumber)?.floatValue ?? 0
                        if coat < 0.55 {
                            mat.clearCoat.contents = 0.72
                            mat.clearCoatRoughness.contents = 0.12
                        }
                    }
                    if let rough = mat.roughness.contents as? NSNumber {
                        mat.roughness.contents = max(0.08, rough.floatValue * 0.82)
                    }
                }
            }
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
            root.position = SCNVector3(MenuCarDriveInView.restX, 0.02, 0)
            root.eulerAngles.y = Float.pi * 0.5
            root.eulerAngles.x = 0
            root.eulerAngles.z = 0
            groundPlate?.position.x = MenuCarDriveInView.restX
        }

        /// Drop race spot beams — they bloom into white spikes in the menu hero shot.
        private func muteMenuHeadlightSpots(on root: SCNNode) {
            root.enumerateHierarchy { node, _ in
                guard node.name == "krcHeadlightSpot", let light = node.light else { return }
                light.intensity = 0
            }
        }

        /// Pull synthetic lamp boxes into the bumper so they don't stick out past the nose.
        private func recessMenuHeadlightLenses(on root: SCNNode) {
            guard let body = root.childNode(withName: "krcVehicleBody", recursively: true)
                    ?? root.childNode(withName: "krcBundledContainer", recursively: true),
                  let frame = VehicleAxes.frame(in: body) else { return }
            let inset = frame.towardCenterFromFront * frame.length * 0.04
            root.enumerateHierarchy { node, _ in
                guard node.name == "krcHeadlightLens", node.geometry is SCNBox else { return }
                node.position.z += inset
            }
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
            // Slightly closer + lower for a tighter 3/4 hero crop.
            let dist = max(3.85, radius * 2.85)
            cam.position = SCNVector3(
                MenuCarDriveInView.restX * 0.22 + 0.08,
                center.y + radius * 0.28 + 0.12,
                dist
            )
            cam.look(at: SCNVector3(
                MenuCarDriveInView.restX * 0.62,
                center.y * 0.55 + 0.08,
                0
            ))
        }

        private func runIntro() {
            guard !isDriving, let root = carRoot else { return }
            introScheduled = false
            isDriving = true
            isRevving = false
            lastWheelSpinTime = 0

            root.removeAllActions()
            root.position = SCNVector3(MenuCarDriveInView.startX, 0.02, 0)
            root.eulerAngles.y = Float.pi * 0.5
            root.eulerAngles.x = 0
            root.eulerAngles.z = 0
            groundPlate?.position.x = MenuCarDriveInView.startX
            groundPlate?.opacity = 0.35

            Task { @MainActor in
                MenuIntroAudioController.shared.playRevSequence()
            }

            let drive = SCNAction.move(to: SCNVector3(MenuCarDriveInView.restX, 0.02, 0), duration: 1.05)
            drive.timingMode = .easeOut
            let groundDrive = SCNAction.move(to: SCNVector3(MenuCarDriveInView.restX, 0, 0), duration: 1.05)
            groundDrive.timingMode = .easeOut
            let groundFade = SCNAction.fadeOpacity(to: 1, duration: 0.85)
            groundPlate?.runAction(SCNAction.group([groundDrive, groundFade]))

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
            let up = SCNAction.moveBy(x: 0, y: 0.045, z: 0, duration: 0.12)
            let down = SCNAction.moveBy(x: 0, y: -0.045, z: 0, duration: 0.18)
            up.timingMode = .easeOut
            down.timingMode = .easeIn
            root.runAction(SCNAction.sequence([up, down]))
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            AutomotiveReflectionSystem.update(renderer: renderer, atTime: time)

            // Subtle showroom light breathing so paint never looks frozen.
            lightPulse += 0.018
            if let key = keyLight?.light {
                key.intensity = 2050 + CGFloat(sin(lightPulse) * 80)
            }
            if let rim = rimLight?.light {
                rim.intensity = 880 + CGFloat(sin(lightPulse * 1.3 + 0.6) * 70)
            }

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

            if isDriving, let ground = groundPlate {
                ground.position.x = root.position.x
            }

            if isRevving {
                settleBob += 0.14
                root.eulerAngles.z = sin(settleBob) * 0.012
            }
        }

        func teardown() {
            Task { @MainActor in
                MenuIntroAudioController.shared.stop()
            }
            if let scene = sceneView?.scene, let root = carRoot {
                AutomotiveReflectionSystem.unbindScene(scene, from: root)
                AutomotiveReflectionSystem.unregister(vehicleRoot: root)
            }
            carRoot?.removeAllActions()
            carRoot = nil
            menuCamera = nil
            groundPlate = nil
            keyLight = nil
            rimLight = nil
            lastWheelSpinTime = 0
            sceneView?.delegate = nil
            sceneView?.pointOfView = nil
            sceneView = nil
        }
    }
}
