import SceneKit
import SwiftUI

/// Rotating SceneKit car preview (replaces 2D garage PNG thumbnails).
struct CarPreview3DView: UIViewRepresentable {
    let car: CarChoice
    var height: CGFloat = 88
    var bodyColorOverride: UIColor? = nil
    /// Bumps when paint / wrap / rim changes so the spinning car actually restyles.
    var appearanceKey: String = ""

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1)
        view.isUserInteractionEnabled = false
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        // Continuous render so the spin action stays smooth without a per-frame euler fight.
        view.rendersContinuously = true
        view.scene = SCNScene()
        context.coordinator.setupScene(in: view)
        context.coordinator.updateCar(
            car: car,
            bodyColor: bodyColorOverride ?? GarageCustomization.bodyColor(for: car),
            appearanceKey: appearanceKey,
            in: view
        )
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.updateCar(
            car: car,
            bodyColor: bodyColorOverride ?? GarageCustomization.bodyColor(for: car),
            appearanceKey: appearanceKey,
            in: view
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        /// Rotates around world Y — car is a seated child so tires stay planted.
        private var spinPivot: SCNNode?
        private var carRoot: SCNNode?
        private weak var sceneView: SCNView?
        private weak var previewCamera: SCNNode?
        private var lastCarKey: String?
        private var lastPaint: GaragePaintSwatch?
        private var lastWrap: GarageWrapStyle?
        private var lastRim: GarageRimStyle?
        private var lastCarId: String?
        private var previewCar: CarChoice?
        private var didFrameCamera = false
        private var seatWorkItem: DispatchWorkItem?
        private let previewScale: CGFloat = 0.82

        func setupScene(in view: SCNView) {
            sceneView = view
            guard let scene = view.scene else { return }

            let amb = SCNNode()
            amb.light = SCNLight()
            amb.light?.type = .ambient
            amb.light?.intensity = 980
            amb.light?.color = UIColor(white: 0.94, alpha: 1)
            scene.rootNode.addChildNode(amb)

            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 1320
            key.light?.castsShadow = false
            key.position = SCNVector3(3, 7, 5)
            key.eulerAngles = SCNVector3(-0.95, 0.45, 0)
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .directional
            fill.light?.intensity = 640
            fill.position = SCNVector3(-4, 3, -3)
            fill.eulerAngles = SCNVector3(-0.5, -0.6, 0)
            scene.rootNode.addChildNode(fill)

            let cam = SCNNode()
            let camera = SCNCamera()
            camera.fieldOfView = 42
            camera.zNear = 0.1
            camera.zFar = 120
            // HDR/bloom on a spinning car caused sparkle flicker on device.
            camera.wantsHDR = false
            cam.camera = camera
            cam.name = "previewCamera"
            scene.rootNode.addChildNode(cam)
            previewCamera = cam
            view.pointOfView = cam

            scene.lightingEnvironment.contents = KRCSceneKitHelpers.studioEnvironmentMap()
            scene.lightingEnvironment.intensity = 1.2
            scene.background.contents = UIColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1)
            scene.rootNode.addChildNode(KRCSceneKitHelpers.garageShowroomPlatform())
            scene.rootNode.addChildNode(KRCSceneKitHelpers.reflectiveFloor(radius: 5.5, opacity: 0))
            scene.rootNode.addChildNode(Self.makeStickerWall())
        }

        private static func makeStickerWall() -> SCNNode {
            let wall = SCNNode()
            wall.name = "krcGarageStickerWall"
            let board = SCNBox(width: 3.4, height: 1.8, length: 0.06, chamferRadius: 0.02)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = UIColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 1)
            board.materials = [mat]
            let boardNode = SCNNode(geometry: board)
            boardNode.name = "krcGarageStickerBoard"
            wall.addChildNode(boardNode)
            wall.position = SCNVector3(0, 1.35, -2.35)
            return wall
        }

        private func refreshStickerWall(in scene: SCNScene) {
            guard let wall = scene.rootNode.childNode(withName: "krcGarageStickerWall", recursively: false) else { return }
            wall.childNodes.filter { $0.name == "krcGarageWallSticker" }.forEach { $0.removeFromParentNode() }
            let owned = KidShowOffLoadout.live.ownedStickers
            guard !owned.isEmpty else { return }
            let cols = min(4, max(1, owned.count))
            for (i, sticker) in owned.prefix(8).enumerated() {
                let col = i % cols
                let row = i / cols
                let plane = SCNPlane(width: 0.42, height: 0.42)
                let mat = SCNMaterial()
                let image = sticker.makeImage()
                mat.lightingModel = .constant
                mat.diffuse.contents = image
                mat.emission.contents = image
                mat.isDoubleSided = true
                plane.materials = [mat]
                let node = SCNNode(geometry: plane)
                node.name = "krcGarageWallSticker"
                let x = (Float(col) - Float(cols - 1) * 0.5) * 0.62
                let y = 0.35 - Float(row) * 0.55
                node.position = SCNVector3(x, y, 0.05)
                wall.addChildNode(node)
            }
        }

        func updateCar(car: CarChoice, bodyColor: UIColor, appearanceKey: String, in view: SCNView) {
            guard let scene = view.scene else { return }
            let style = GarageCustomization.style(for: car.id)
            let carKey = "\(car.id)-\(bodyColor.hash)-\(style.paint.rawValue)-\(style.wrap.rawValue)-\(style.rim.rawValue)-\(appearanceKey)"
            guard carKey != lastCarKey else { return }
            previewCar = car

            // Rim-only: restyle wheels on the live mesh so the spin doesn't flash.
            if let root = carRoot,
               lastCarId == car.id,
               lastPaint == style.paint,
               lastWrap == style.wrap,
               lastRim != style.rim {
                WheelAssembly.restyleGarageWheels(in: root, carId: car.id, scale: Float(previewScale))
                lastRim = style.rim
                lastCarKey = carKey
                return
            }

            lastCarKey = carKey
            lastCarId = car.id
            lastPaint = style.paint
            lastWrap = style.wrap
            lastRim = style.rim

            seatWorkItem?.cancel()
            seatWorkItem = nil

            if let previous = carRoot {
                AutomotiveReflectionSystem.unbindScene(scene, from: previous)
                AutomotiveReflectionSystem.unregister(vehicleRoot: previous)
                previous.removeFromParentNode()
            }
            spinPivot?.removeAllActions()
            spinPivot?.removeFromParentNode()
            spinPivot = nil
            carRoot = nil
            didFrameCamera = false

            let pivot = SCNNode()
            pivot.name = "previewSpinPivot"
            pivot.position = SCNVector3Zero
            scene.rootNode.addChildNode(pivot)
            spinPivot = pivot

            let root = SCNNode()
            root.name = "previewCar"
            RaceCarGeometry.build(
                root: root,
                bodyColor: bodyColor,
                carId: car.id,
                scale: previewScale,
                isPlayer: true,
                category: GameCatalog.vehicleCategory(for: car.id),
                applyLivery: true,
                lod: .garage
            )
            // Fixed yaw so the hood faces camera-friendly +X; spin is applied on the pivot only.
            root.eulerAngles = SCNVector3(0, Float.pi * 0.5, 0)
            pivot.addChildNode(root)
            carRoot = root

            seatOnPlatform(root)
            AutomotiveReflectionSystem.bindScene(scene, to: root)
            frameCamera(on: root)
            view.pointOfView = previewCamera
            startSpin(on: pivot)
            refreshStickerWall(in: scene)
            scheduleLateSeatIfNeeded(root: root, pivot: pivot)
        }

        private func startSpin(on pivot: SCNNode) {
            pivot.removeAction(forKey: "garageSpin")
            // SceneKit-timed rotation stays smooth across frame-rate dips (unlike += euler per frame).
            let spin = SCNAction.repeatForever(
                SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 9.0)
            )
            spin.timingMode = .linear
            pivot.runAction(spin, forKey: "garageSpin")
        }

        private func seatOnPlatform(_ car: SCNNode) {
            car.position = SCNVector3Zero
            car.enumerateHierarchy { node, _ in
                _ = node.geometry
            }
            let (minB, maxB) = car.boundingBox
            let span = max(maxB.x - minB.x, maxB.y - minB.y, maxB.z - minB.z)
            guard span > 0.05 else {
                car.position = SCNVector3(0, KRCSceneKitHelpers.garagePlatformTopY, 0)
                return
            }
            let centerX = (minB.x + maxB.x) * 0.5
            let centerZ = (minB.z + maxB.z) * 0.5
            // Center XZ on the spin axis so rotation does not orbit/wobble.
            car.position = SCNVector3(
                -centerX,
                KRCSceneKitHelpers.garagePlatformTopY - minB.y,
                -centerZ
            )
        }

        /// USDZ bounds sometimes finalize a beat late — re-seat once without moving the camera mid-spin.
        private func scheduleLateSeatIfNeeded(root: SCNNode, pivot: SCNNode) {
            let work = DispatchWorkItem { [weak self, weak root, weak pivot] in
                guard let self, let root, let pivot, self.carRoot === root else { return }
                let yaw = pivot.eulerAngles.y
                self.seatOnPlatform(root)
                if let car = self.previewCar {
                    self.reseatPlates(on: root, car: car)
                }
                // Keep current spin phase; do not reframe camera (that caused the garage glitch).
                pivot.eulerAngles.y = yaw
                if !self.didFrameCamera {
                    self.frameCamera(on: root)
                }
            }
            seatWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        }

        private func reseatPlates(on root: SCNNode, car: CarChoice) {
            let host = root.childNode(withName: "krcVehicleRoot", recursively: false) ?? root
            let mesh = host.childNode(withName: "krcVehicleBody", recursively: true) ?? host
            CarDecals.apply(
                to: mesh,
                container: root,
                carId: car.id,
                isPlayer: true,
                scale: Float(previewScale)
            )
        }

        private func frameCamera(on car: SCNNode) {
            guard let cam = previewCamera else { return }
            let (minB, maxB) = car.boundingBox
            let size = SCNVector3(maxB.x - minB.x, maxB.y - minB.y, maxB.z - minB.z)
            let localCenter = SCNVector3(
                (minB.x + maxB.x) * 0.5,
                (minB.y + maxB.y) * 0.5,
                (minB.z + maxB.z) * 0.5
            )
            let worldCenter = car.convertPosition(localCenter, to: nil)
            let radius = max(size.x, size.y, size.z, 0.5) * 0.55
            let dist = max(4.6, radius * 3.15)
            cam.position = SCNVector3(
                worldCenter.x + dist * 0.08,
                worldCenter.y + radius * 0.38,
                worldCenter.z + dist
            )
            cam.look(at: SCNVector3(worldCenter.x, worldCenter.y * 0.85, worldCenter.z))
            didFrameCamera = true
        }
    }
}
