import SceneKit
import UIKit

/// GT7-style reflection tiers on iOS: race = standard IBL, showroom/photo = stronger IBL + shader multi-sample specular.
/// (SceneKit on iOS has no `SCNReflectionProbe`; photo mode approximates RT via env sampling in the paint shader.)
enum AutomotiveReflectionSystem {

  enum PaintContext: String {
    case race
    case showroom
    case garage
    case photo

    var reflectionTier: AutomotivePaintShader.ReflectionTier {
      switch self {
      case .race: return .race
      case .showroom, .garage: return .showroom
      case .photo: return .photo
      }
    }

    var lightingEnvironmentIntensity: CGFloat {
      switch self {
      // Keep race IBL near the environment pipeline (~0.55) so paint/asphalt aren't blown out.
      case .race: return 0.55
      case .showroom, .garage: return 1.35
      case .photo: return 1.65
      }
    }
  }

  private final class Handle {
    weak var vehicleRoot: SCNNode?
    weak var scene: SCNScene?
    let context: PaintContext
    var savedEnvIntensity: CGFloat?

    init(context: PaintContext) {
      self.context = context
    }
  }

  private static var handles: [ObjectIdentifier: Handle] = [:]

  static func paintContext(for lod: VehicleRenderer.VehicleLOD) -> PaintContext {
    switch lod {
    case .race, .opponent: return .race
    case .garage:
      return EnvironmentGraphicsSettings.quality == .ultra ? .photo : .showroom
    }
  }

  static func reflectionTier(for lod: VehicleRenderer.VehicleLOD) -> AutomotivePaintShader.ReflectionTier {
    paintContext(for: lod).reflectionTier
  }

  static func register(vehicleRoot: SCNNode, context: PaintContext) {
    let key = ObjectIdentifier(vehicleRoot)
    let handle = Handle(context: context)
    handle.vehicleRoot = vehicleRoot
    vehicleRoot.setValue(context.rawValue, forKey: "krcAutomotivePaintContext")
    handles[key] = handle
  }

  static func bindScene(_ scene: SCNScene, to vehicleRoot: SCNNode) {
    let key = ObjectIdentifier(vehicleRoot)
    guard let handle = handles[key] else { return }
    if handle.savedEnvIntensity == nil {
      handle.savedEnvIntensity = scene.lightingEnvironment.intensity
    }
    handle.scene = scene
    scene.lightingEnvironment.intensity = handle.context.lightingEnvironmentIntensity
  }

  static func unbindScene(_ scene: SCNScene, from vehicleRoot: SCNNode) {
    let key = ObjectIdentifier(vehicleRoot)
    guard let handle = handles[key] else { return }
    if let saved = handle.savedEnvIntensity {
      scene.lightingEnvironment.intensity = saved
    }
    handle.scene = nil
    handle.savedEnvIntensity = nil
  }

  static func unregister(vehicleRoot: SCNNode) {
    handles.removeValue(forKey: ObjectIdentifier(vehicleRoot))
  }

  /// Keeps showroom/photo IBL boosted while the car is on screen (shader uses `u_envSamples` for RT-style specular).
  static func update(renderer: SCNSceneRenderer, atTime time: TimeInterval) {
    _ = renderer
    _ = time
    for handle in handles.values {
      guard let scene = handle.scene, handle.context != .race else { continue }
      scene.lightingEnvironment.intensity = handle.context.lightingEnvironmentIntensity
    }
  }
}
