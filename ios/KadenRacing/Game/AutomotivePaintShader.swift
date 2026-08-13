import Metal
import SceneKit
import UIKit

/// Multi-layer automotive paint: Disney PBR base + metallic flake + clear-coat (GT7-style, SceneKit).
enum AutomotivePaintShader {

  enum ReflectionTier {
    case race
    case showroom
    case photo
  }

  static func makeBodyPaintMaterial(
    brdf: AutomotiveBRDFLibrary.MeasuredBRDF,
    tier: ReflectionTier
  ) -> SCNMaterial {
    if let metal = makeMetalProgramMaterial(brdf: brdf, tier: tier) {
      return metal
    }
    return makeModifierMaterial(brdf: brdf, tier: tier)
  }

  // MARK: - Runtime Metal (multi-layer single pass)

  private static func makeMetalProgramMaterial(
    brdf: AutomotiveBRDFLibrary.MeasuredBRDF,
    tier: ReflectionTier
  ) -> SCNMaterial? {
    // Custom SCNProgram path reserved — modifier + clear-coat path is stable on all devices.
    guard false,
          let device = MTLCreateSystemDefaultDevice(),
          let library = try? device.makeLibrary(source: metalSource, options: nil),
          library.makeFunction(name: "krcAutomotivePaintVertex") != nil,
          library.makeFunction(name: "krcAutomotivePaintFragment") != nil else {
      return nil
    }

    let program = SCNProgram()
    program.library = library
    program.vertexFunctionName = "krcAutomotivePaintVertex"
    program.fragmentFunctionName = "krcAutomotivePaintFragment"

    let mat = SCNMaterial()
    mat.program = program
    mat.lightingModel = .physicallyBased
    mat.name = "krcAutomotivePaintMetal"
    mat.isDoubleSided = false
    mat.writesToDepthBuffer = true
    mat.readsFromDepthBuffer = true
    bindBRDFUniforms(brdf, tier: tier, to: mat)
    applyFlakeMaps(brdf: brdf, to: mat)
    return mat
  }

  private static func bindBRDFUniforms(
    _ brdf: AutomotiveBRDFLibrary.MeasuredBRDF,
    tier: ReflectionTier,
    to mat: SCNMaterial
  ) {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    brdf.baseColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    mat.setValue(UIColor(red: r, green: g, blue: b, alpha: a), forKey: "u_baseColor")
    mat.setValue(NSNumber(value: brdf.baseMetalness), forKey: "u_baseMetal")
    mat.setValue(NSNumber(value: brdf.baseRoughness), forKey: "u_baseRough")
    mat.setValue(NSNumber(value: brdf.clearCoat), forKey: "u_clearCoat")
    mat.setValue(NSNumber(value: brdf.clearCoatRoughness), forKey: "u_clearRough")
    mat.setValue(NSNumber(value: brdf.flakeDensity), forKey: "u_flake")
    mat.setValue(NSNumber(value: brdf.flakeMetalness), forKey: "u_flakeMetal")
    mat.setValue(NSNumber(value: brdf.sheen), forKey: "u_sheen")
    mat.setValue(NSNumber(value: brdf.pearlShift), forKey: "u_pearlShift")
    mat.setValue(NSNumber(value: Float(tier.envSampleCount)), forKey: "u_envSamples")
    mat.setValue(NSNumber(value: tier.coatBoost), forKey: "u_coatBoost")
  }

  private static func applyFlakeMaps(brdf: AutomotiveBRDFLibrary.MeasuredBRDF, to mat: SCNMaterial) {
    guard brdf.flakeDensity > 0.04 else {
      mat.setValue(NSNumber(value: brdf.baseMetalness), forKey: "u_useFlakeMaps")
      return
    }
    mat.setValue(NSNumber(value: 1), forKey: "u_useFlakeMaps")
    mat.setValue(
      KRCProceduralTextures.automotiveFlakeMetalness(
        intensity: brdf.flakeDensity, baseMetal: CGFloat(brdf.baseMetalness)
      ),
      forKey: "u_flakeMetalMap"
    )
    mat.setValue(
      KRCProceduralTextures.automotiveFlakeRoughness(
        intensity: brdf.flakeDensity, baseRough: CGFloat(brdf.baseRoughness)
      ),
      forKey: "u_flakeRoughMap"
    )
  }

  // MARK: - Shader-modifier fallback

  /// SceneKit PBR with factory color in `diffuse` — no custom fragment stage (uniforms were unreliable; high metalness hid pigment).
  private static func makeModifierMaterial(
    brdf: AutomotiveBRDFLibrary.MeasuredBRDF,
    tier: ReflectionTier
  ) -> SCNMaterial {
    let mat = SCNMaterial()
    mat.name = "krcAutomotivePaint"
    mat.diffuse.contents = brdf.baseColor
    // USDZ imports often have flipped normals — single-sided paint disappears in chase view.
    mat.isDoubleSided = true
    mat.writesToDepthBuffer = true
    mat.readsFromDepthBuffer = true
    mat.fillMode = .fill
    mat.transparency = 1
    mat.transparencyMode = .default
    mat.transparent.contents = nil
    mat.multiply.contents = UIColor.white

    // Same PBR paint path on device and Simulator so store / QA shots match.
    mat.lightingModel = .physicallyBased
    mat.blendMode = .alpha
    VehicleMaterialLibrary.configureFullyOpaque(mat)

    #if targetEnvironment(simulator)
    // Slightly stronger emission only — keeps body color readable under Simulator Metal.
    let emissionStrength: CGFloat = switch tier {
    case .race: 0.42
    case .showroom: 0.22
    case .photo: 0.16
    }
    #else
    let emissionStrength: CGFloat = switch tier {
    case .race: 0.32
    case .showroom: 0.16
    case .photo: 0.12
    }
    #endif
    mat.emission.contents = brdf.baseColor.withAlphaComponent(emissionStrength)

    let metal = min(brdf.baseMetalness + brdf.flakeDensity * 0.03, 0.08)
    mat.metalness.contents = CGFloat(metal)
    mat.roughness.contents = CGFloat(min(brdf.baseRoughness, 0.42))

    if #available(iOS 13.0, *) {
      let coatScale: Float = tier == .race ? 0.5 : 0.85
      let coat = min(1, brdf.clearCoat * tier.coatBoost * coatScale)
      mat.clearCoat.contents = CGFloat(coat)
      mat.clearCoatRoughness.contents = CGFloat(brdf.clearCoatRoughness)
    }

    return mat
  }

  private static let metalSource = """
  #include <metal_stdlib>
  #include <SceneKit/scn_metal>

  using namespace metal;

  struct KRCPaintUniforms {
    float4 baseColor;
    float baseMetal;
    float baseRough;
    float clearCoat;
    float clearRough;
    float flake;
    float flakeMetal;
    float sheen;
    float pearlShift;
    float envSamples;
    float coatBoost;
    float useFlakeMaps;
  };

  constant KRCPaintUniforms *u [[buffer(0)]];

  float hash21(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
  }

  [[visible]]
  void krcAutomotivePaintVertex(
    scn_node node [[attribute(SCNVertexSemanticScnNode)]],
    scn_frame frame [[attribute(SCNVertexSemanticScnFrame)]],
    scn_vertex in [[stage_in]],
    constant KRCPaintUniforms &uni [[buffer(0)]],
    out scn_vertex outVertex [[stage_out]]
  ) {
    outVertex = in;
  }

  [[visible]]
  float4 krcAutomotivePaintFragment(
    scn_frame frame [[attribute(SCNVertexSemanticScnFrame)]],
    scn_surface surface [[stage_in]],
    constant KRCPaintUniforms &uni [[buffer(0)]]
  ) {
    float3 n = normalize(surface.normal);
    float3 v = normalize(surface.view);
    float ndv = saturate(dot(n, v));
    float fresnel = pow(1.0 - ndv, mix(4.0, 7.0, uni.clearRough));

    float2 uv = surface.position.xz * 50.0;
    float flakeN = hash21(uv);
    float metal = mix(uni.baseMetal, uni.flakeMetal, flakeN * uni.flake);
    float rough = mix(uni.baseRough, uni.baseRough * 0.8, flakeN * uni.flake * 0.5);

    float3 base = uni.baseColor.rgb;
    float3 diff = base * (0.18 + 0.82 * ndv);

    float3 spec = float3(0.04 + metal * 0.5) * pow(ndv, mix(8.0, 24.0, rough));
    spec += float3(flakeN) * uni.flake * uni.flakeMetal * pow(ndv, 10.0) * 0.9;
    spec += float3(uni.sheen) * pow(1.0 - ndv, 5.0);
    spec += float3(0.02, 0.03, 0.06) * uni.pearlShift * pow(1.0 - ndv, 3.0);

    float coatW = uni.clearCoat * fresnel * uni.coatBoost * (1.0 + max(0.0, uni.envSamples - 1.0) * 0.15);
    float3 coat = mix(diff + spec, diff + spec + float3(0.25, 0.27, 0.32), coatW);

    return float4(coat, uni.baseColor.a);
  }
  """
}

private extension AutomotivePaintShader.ReflectionTier {
  var envSampleCount: Int {
    switch self {
    case .race: return 1
    case .showroom: return 3
    case .photo: return 6
    }
  }

  var coatBoost: Float {
    switch self {
    case .race: return 1.0
    case .showroom: return 1.12
    case .photo: return 1.28
    }
  }
}
