import SceneKit
import UIKit

/// Vehicle assembly entry — delegates to `VehicleRenderer` and `VehicleVisualProfile`.
enum RaceCarGeometry {

    static func build(
        root: SCNNode,
        bodyColor: UIColor,
        carId: String = "f40",
        scale: CGFloat = 1,
        isPlayer: Bool = true,
        category: VehicleCategory = .sports,
        applyLivery: Bool = true,
        wheelStyle: VehicleWheelStyle? = nil,
        lod: VehicleRenderer.VehicleLOD = .race,
        paintContext: AutomotiveReflectionSystem.PaintContext? = nil
    ) {
        VehicleRenderer.build(
            into: root,
            request: VehicleRenderer.BuildRequest(
                carId: carId,
                bodyColor: bodyColor,
                scale: Float(scale),
                isPlayer: isPlayer,
                applyLivery: applyLivery,
                category: category,
                wheelStyleOverride: wheelStyle,
                lod: lod,
                paintContext: paintContext
            )
        )
    }

    static func setBrakeLights(root: SCNNode, amount: Float) {
        VehicleLighting.setBrakeLights(on: root, amount: amount)
    }
}
