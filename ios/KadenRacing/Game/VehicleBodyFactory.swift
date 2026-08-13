import SceneKit
import UIKit
import simd

/// Builds distinct high-detail procedural silhouettes per `VehicleBodyStyle`.
enum VehicleBodyFactory {

    static func build(
        profile: VehicleVisualProfile,
        bodyColor: UIColor,
        scale: Float,
        isPlayer: Bool
    ) -> SCNNode {
        let root = SCNNode()
        root.name = "krcVehicleBody"
        var paint = profile.paintDescriptor
        paint = VehicleMaterialLibrary.PaintDescriptor(
            color: bodyColor,
            finish: profile.paintFinish,
            flake: paint.flake,
            clearCoat: paint.clearCoat
        )
        let builder = ProceduralBodyBuilder(
            root: root,
            carId: profile.carId,
            paint: paint,
            accent: profile.accentTrim ?? bodyColor.withAlphaComponent(0.85),
            scale: scale,
            dims: profile.dimensions,
            rideHeight: profile.rideHeight,
            headlights: profile.headlightStyle
        )
        switch profile.bodyStyle {
        case .hyperWedge: builder.buildHyperWedge()
        case .midEngineSuper: builder.buildMidEngineSuper()
        case .exoticWide: builder.buildExoticWide()
        case .sportsCoupe: builder.buildSportsCoupe()
        case .muscle: builder.buildMuscle()
        case .tuner: builder.buildTuner()
        case .sedanGT: builder.buildSedanGT()
        case .roadster: builder.buildRoadster()
        case .policeInterceptor: builder.buildPolice()
        }
        builder.attachWheels(style: profile.wheelStyle)
        builder.attachLights()
        if isPlayer { GLBDriverLoader.attach(to: root, scale: scale) }
        return root
    }

    /// Simulator-stable upright car: body + cabin + wheels sitting on the road (Y-up).
    /// No `pivot`, no child eulerAngles — every part is an explicit child with real height.
    static func buildChunkyReadable(
        profile: VehicleVisualProfile,
        bodyColor: UIColor,
        scale: Float
    ) -> SCNNode {
        let root = SCNNode()
        root.name = "krcVehicleBody"
        root.geometry = nil
        root.pivot = SCNMatrix4Identity
        root.eulerAngles = SCNVector3Zero
        root.scale = SCNVector3(1, 1, 1)

        let s = max(1.0, scale)
        let shape = chunkyShape(for: profile.bodyStyle)
        // Chase-cam readable sports car ~4.5 m long, clear vertical silhouette (not a road card).
        let w = max(2.0, min(2.6, profile.dimensions.x * s)) * shape.widthMul
        let h = max(1.55, min(2.05, max(profile.dimensions.y, 1.4) * s)) * shape.heightMul
        let len = max(4.4, min(5.2, profile.dimensions.z * s))
        let paint = boostSimPaint(VehicleMaterialLibrary.calibratePaintColor(bodyColor))
        let glass = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1) // black privacy cabin
        let windshield = UIColor(red: 0.30, green: 0.38, blue: 0.46, alpha: 1)
        let tire = UIColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1)
        let rim = UIColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1)

        let wheelR: Float = 0.40
        let wheelThick = max(0.28, w * 0.12)
        let bodyH = max(0.72, h * 0.55)
        let cabinH = max(0.48, h * 0.40)
        let cabinLen = len * 0.42
        // Explicit Y centers — underside clears asphalt; cabin stacks above body.
        let bodyCenterY = wheelR + bodyH * 0.5
        let cabinCenterY = bodyCenterY + bodyH * 0.5 + cabinH * 0.5

        let bodyBox = SCNBox(
            width: CGFloat(w),
            height: CGFloat(bodyH),
            length: CGFloat(len),
            chamferRadius: 0.08
        )
        bodyBox.materials = [simConstantMat(paint, name: "krcAutomotivePaint", emit: 0.95)]
        let bodyNode = SCNNode(geometry: bodyBox)
        bodyNode.name = "krcBodyHull"
        bodyNode.position = SCNVector3(0, bodyCenterY, 0)
        bodyNode.eulerAngles = SCNVector3Zero
        bodyNode.pivot = SCNMatrix4Identity
        bodyNode.castsShadow = false
        root.addChildNode(bodyNode)

        let cabinBox = SCNBox(
            width: CGFloat(w * 0.70),
            height: CGFloat(cabinH),
            length: CGFloat(cabinLen),
            chamferRadius: 0.05
        )
        cabinBox.materials = [simConstantMat(glass, name: "krcGlass", emit: 0.7)]
        let cabinNode = SCNNode(geometry: cabinBox)
        cabinNode.name = "krcCabin"
        cabinNode.position = SCNVector3(0, cabinCenterY, -len * 0.05)
        cabinNode.eulerAngles = SCNVector3Zero
        cabinNode.pivot = SCNMatrix4Identity
        cabinNode.castsShadow = false
        root.addChildNode(cabinNode)

        // Front windshield (lighter) — side/rear cabin stays black.
        let windBox = SCNBox(
            width: CGFloat(w * 0.58),
            height: CGFloat(cabinH * 0.85),
            length: 0.06,
            chamferRadius: 0.02
        )
        windBox.materials = [simConstantMat(windshield, name: "krcWindshield", emit: 0.55)]
        let windNode = SCNNode(geometry: windBox)
        windNode.name = "krcFrontWindshield"
        windNode.position = SCNVector3(0, cabinCenterY, cabinLen * 0.48)
        windNode.castsShadow = false
        root.addChildNode(windNode)

        let head = SCNBox(
            width: CGFloat(w * 0.62),
            height: CGFloat(bodyH * 0.28),
            length: 0.16,
            chamferRadius: 0.03
        )
        head.materials = [simConstantMat(UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1), name: "krcHeadLamp", emit: 1)]
        let headNode = SCNNode(geometry: head)
        headNode.name = "krcHeadLamp"
        headNode.position = SCNVector3(0, bodyCenterY + bodyH * 0.05, len * 0.5 + 0.02)
        headNode.eulerAngles = SCNVector3Zero
        root.addChildNode(headNode)

        // Skip solid red krcTailLamp on Simulator — emissive constant paint reads as a rear slab.

        // Box wheels — no cylinder eulerAngles (Sim Metal + euler/pivot stacks flatten to cards).
        let axleZ: [Float] = [len * 0.32, -len * 0.32]
        let axleX: [Float] = [-w * 0.48, w * 0.48]
        var wheelIndex = 0
        for z in axleZ {
            for x in axleX {
                let tireGeo = SCNBox(
                    width: CGFloat(wheelThick),
                    height: CGFloat(wheelR * 2),
                    length: CGFloat(wheelR * 1.7),
                    chamferRadius: 0.04
                )
                tireGeo.materials = [simConstantMat(tire, name: "krcTire", emit: 0.4)]
                let wheel = SCNNode(geometry: tireGeo)
                wheel.name = "krcWheel_\(wheelIndex)"
                wheel.position = SCNVector3(x, wheelR, z)
                wheel.eulerAngles = SCNVector3Zero
                wheel.pivot = SCNMatrix4Identity
                wheel.castsShadow = false
                root.addChildNode(wheel)

                let rimGeo = SCNBox(
                    width: CGFloat(wheelThick * 1.05),
                    height: CGFloat(wheelR * 1.15),
                    length: CGFloat(wheelR * 1.15),
                    chamferRadius: 0.03
                )
                rimGeo.materials = [simConstantMat(rim, name: "krcRim", emit: 0.55)]
                let rimNode = SCNNode(geometry: rimGeo)
                rimNode.name = "krcRim_\(wheelIndex)"
                rimNode.position = SCNVector3(x, wheelR, z)
                rimNode.eulerAngles = SCNVector3Zero
                rimNode.pivot = SCNMatrix4Identity
                root.addChildNode(rimNode)
                wheelIndex += 1
            }
        }

        NSLog(
            "[VehicleBodyFactory] chunkyReadable w=%.2f bodyH=%.2f cabinH=%.2f len=%.2f roofY=%.2f",
            w, bodyH, cabinH, len, cabinCenterY + cabinH * 0.5
        )
        return root
    }

    /// Bright chase-cam paint for the player on Simulator (garage greys vanish on asphalt).
    static func simulatorPlayerPaint(_ color: UIColor) -> UIColor {
        boostSimPaint(VehicleMaterialLibrary.calibratePaintColor(color))
    }

    /// Single SCNGeometry for Simulator `root.geometry`: upright body + cabin + 4 wheels.
    /// Vertex Y starts at 0 (road contact) — no pivot required. Y-up, length along Z.
    static func buildUprightCompoundGeometry(
        width w: Float,
        height h: Float,
        length len: Float,
        bodyColor: UIColor
    ) -> SCNGeometry {
        let paint = boostSimPaint(VehicleMaterialLibrary.calibratePaintColor(bodyColor))
        let glass = UIColor(red: 0.25, green: 0.45, blue: 0.65, alpha: 1)
        let tire = UIColor(red: 0.1, green: 0.1, blue: 0.11, alpha: 1)

        let wheelR = max(0.36, min(0.44, h * 0.26))
        let bodyH = h * 0.5
        let cabinH = h * 0.36
        let bodyY0 = wheelR * 0.85
        let bodyY1 = bodyY0 + bodyH
        let cabinY1 = bodyY1 + cabinH
        let cabinLen = len * 0.42
        let hx = w * 0.5
        let hz = len * 0.5

        var verts: [SCNVector3] = []
        var norms: [SCNVector3] = []
        var indices: [Int32] = []
        var colors: [Float] = []

        func appendBox(
            minX: Float, maxX: Float,
            minY: Float, maxY: Float,
            minZ: Float, maxZ: Float,
            color: UIColor
        ) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let base = Int32(verts.count)
            // 8 corners
            let corners: [SCNVector3] = [
                SCNVector3(minX, minY, minZ), SCNVector3(maxX, minY, minZ),
                SCNVector3(maxX, maxY, minZ), SCNVector3(minX, maxY, minZ),
                SCNVector3(minX, minY, maxZ), SCNVector3(maxX, minY, maxZ),
                SCNVector3(maxX, maxY, maxZ), SCNVector3(minX, maxY, maxZ),
            ]
            // Duplicate verts per face so normals are correct
            let faces: [(Int, Int, Int, Int, SCNVector3)] = [
                (0, 1, 2, 3, SCNVector3(0, 0, -1)), // -Z
                (5, 4, 7, 6, SCNVector3(0, 0, 1)),  // +Z
                (4, 0, 3, 7, SCNVector3(-1, 0, 0)), // -X
                (1, 5, 6, 2, SCNVector3(1, 0, 0)),  // +X
                (3, 2, 6, 7, SCNVector3(0, 1, 0)),  // +Y
                (4, 5, 1, 0, SCNVector3(0, -1, 0)), // -Y
            ]
            for (i0, i1, i2, i3, n) in faces {
                let vi = Int32(verts.count)
                for idx in [i0, i1, i2, i3] {
                    verts.append(corners[idx])
                    norms.append(n)
                    colors.append(contentsOf: [Float(r), Float(g), Float(b), 1])
                }
                indices.append(contentsOf: [vi, vi + 1, vi + 2, vi, vi + 2, vi + 3])
            }
            _ = base
        }

        // Main body
        appendBox(minX: -hx, maxX: hx, minY: bodyY0, maxY: bodyY1, minZ: -hz, maxZ: hz, color: paint)
        // Cabin (taller silhouette)
        appendBox(
            minX: -hx * 0.72, maxX: hx * 0.72,
            minY: bodyY1, maxY: cabinY1,
            minZ: -cabinLen * 0.5, maxZ: cabinLen * 0.45,
            color: glass
        )
        // Nose block for chase-cam readability (no red tail slab — Sim emission blew it up).
        appendBox(
            minX: -hx * 0.55, maxX: hx * 0.55,
            minY: bodyY0 + bodyH * 0.35, maxY: bodyY0 + bodyH * 0.75,
            minZ: hz - 0.02, maxZ: hz + 0.14,
            color: UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
        )
        // Four wheel boxes (axle along X)
        let axleZ: [Float] = [len * 0.32, -len * 0.32]
        let axleX: [Float] = [-w * 0.42, w * 0.42]
        let wheelHalfW = w * 0.09
        for z in axleZ {
            for x in axleX {
                appendBox(
                    minX: x - wheelHalfW, maxX: x + wheelHalfW,
                    minY: 0, maxY: wheelR * 2,
                    minZ: z - wheelR * 0.85, maxZ: z + wheelR * 0.85,
                    color: tire
                )
            }
        }

        let srcVerts = SCNGeometrySource(vertices: verts)
        let srcNorms = SCNGeometrySource(normals: norms)
        let colorData = Data(bytes: colors, count: colors.count * MemoryLayout<Float>.size)
        let srcColors = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: verts.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 4
        )
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [srcVerts, srcNorms, srcColors], elements: [element])

        let mat = SCNMaterial()
        mat.name = "krcAutomotivePaint"
        mat.lightingModel = .constant
        mat.diffuse.contents = UIColor.white
        mat.emission.contents = UIColor.white
        mat.isDoubleSided = true
        // SceneKit: 1 = opaque, 0 = fully transparent (do NOT set 0).
        mat.transparency = 1
        mat.writesToDepthBuffer = true
        mat.readsFromDepthBuffer = true
        mat.fillMode = .fill
        geo.materials = [mat]
        return geo
    }

    private static func boostSimPaint(_ color: UIColor) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return UIColor(red: 1, green: 0.82, blue: 0.12, alpha: 1)
        }
        // Preserve true blacks (police / matte) — don't remap to orange or brighten into blue.
        if b < 0.22 {
            return UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1)
        }
        // Near-greys → hot orange so the chase-cam car never blends into asphalt.
        if s < 0.18 || b < 0.45 {
            return UIColor(red: 1.0, green: 0.55, blue: 0.05, alpha: 1)
        }
        s = max(0.65, min(0.98, s))
        b = max(0.85, min(1.0, b))
        return UIColor(hue: h, saturation: s, brightness: b, alpha: 1)
    }

    private static func simConstantMat(_ color: UIColor, name: String, emit: CGFloat) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.name = name
        // Constant + emission: MinimalRaceEnvironment lighting is too weak for Lambert on Sim.
        mat.lightingModel = .constant
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.ambient.contents = UIColor.black
        mat.isDoubleSided = true
        mat.cullMode = .back
        // SceneKit: 1 = opaque, 0 = fully transparent (do NOT set 0).
        mat.transparency = 1
        mat.writesToDepthBuffer = true
        mat.readsFromDepthBuffer = true
        mat.fillMode = .fill
        _ = emit
        return mat
    }

    private struct ChunkyShape {
        var widthMul: Float
        var heightMul: Float
        var hasSpoiler: Bool
    }

    private static func chunkyShape(for style: VehicleBodyStyle) -> ChunkyShape {
        switch style {
        case .hyperWedge: return ChunkyShape(widthMul: 0.95, heightMul: 0.95, hasSpoiler: true)
        case .exoticWide: return ChunkyShape(widthMul: 1.12, heightMul: 1.0, hasSpoiler: true)
        case .midEngineSuper: return ChunkyShape(widthMul: 1.0, heightMul: 0.95, hasSpoiler: true)
        case .muscle: return ChunkyShape(widthMul: 1.14, heightMul: 1.05, hasSpoiler: true)
        case .sedanGT, .policeInterceptor: return ChunkyShape(widthMul: 1.06, heightMul: 1.12, hasSpoiler: false)
        case .roadster: return ChunkyShape(widthMul: 0.98, heightMul: 0.88, hasSpoiler: false)
        case .tuner: return ChunkyShape(widthMul: 1.0, heightMul: 0.98, hasSpoiler: true)
        case .sportsCoupe: return ChunkyShape(widthMul: 1.02, heightMul: 0.98, hasSpoiler: true)
        }
    }
}

// MARK: - Builder

private struct ProceduralBodyBuilder {
    let root: SCNNode
    let carId: String
    let paint: VehicleMaterialLibrary.PaintDescriptor
    let accent: UIColor
    let scale: Float
    let dims: SIMD3<Float>
    let rideHeight: Float
    let headlights: VehicleHeadlightStyle
    private let s: Float

    init(
        root: SCNNode,
        carId: String,
        paint: VehicleMaterialLibrary.PaintDescriptor,
        accent: UIColor,
        scale: Float,
        dims: SIMD3<Float>,
        rideHeight: Float,
        headlights: VehicleHeadlightStyle
    ) {
        self.root = root
        self.carId = carId
        self.paint = paint
        self.accent = accent
        self.scale = scale
        self.dims = dims
        self.rideHeight = rideHeight
        self.headlights = headlights
        self.s = scale
    }

    private var w: Float { dims.x * s }
    private var h: Float { dims.y * s }
    private var len: Float { dims.z * s }
    private var baseY: Float { rideHeight * s }

    private func bodyMat() -> SCNMaterial {
        VehicleMaterialLibrary.bodyPaint(paint, carId: carId, reflectionTier: .race)
    }
    private func glassMat() -> SCNMaterial { VehicleMaterialLibrary.automotiveGlass() }
    private func chromeMat() -> SCNMaterial { VehicleMaterialLibrary.chrome() }
    private func carbonMat() -> SCNMaterial {
        #if targetEnvironment(simulator)
        // Avoid near-black carbon swallowing the silhouette on Simulator.
        return VehicleMaterialLibrary.makeVisibleSurface(
            color: UIColor(white: 0.22, alpha: 1),
            metalness: 0.25,
            roughness: 0.5,
            emission: 0.18,
            constantLighting: true
        )
        #else
        return VehicleMaterialLibrary.carbonFiber()
        #endif
    }
    private func accentMat() -> SCNMaterial { accent.asMaterial() ?? bodyMat() }
    private func ventMat() -> SCNMaterial {
        #if targetEnvironment(simulator)
        return VehicleMaterialLibrary.makeVisibleSurface(
            color: UIColor(white: 0.16, alpha: 1),
            metalness: 0.15,
            roughness: 0.7,
            emission: 0.12,
            constantLighting: true
        )
        #else
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(white: 0.04, alpha: 1)
        m.metalness.contents = 0.2
        m.roughness.contents = 0.85
        return m
        #endif
    }

    private func box(_ wx: Float, _ hy: Float, _ lz: Float, _ mat: SCNMaterial, _ pos: SCNVector3, rake: Float = 0) {
        let g = SCNBox(width: CGFloat(wx), height: CGFloat(hy), length: CGFloat(lz), chamferRadius: CGFloat(min(wx, hy, lz) * 0.08))
        g.materials = [mat]
        let n = SCNNode(geometry: g)
        n.position = pos
        n.eulerAngles.x = rake
        n.castsShadow = true
        root.addChildNode(n)
    }

    private func addFloorPan() {
        box(w * 1.04, h * 0.14, len * 1.02, ventMat(), SCNVector3(0, baseY + h * 0.08, 0))
    }

    private func addSkirts() {
        for sx: Float in [-1, 1] {
            box(w * 0.08, h * 0.1, len * 0.82, ventMat(), SCNVector3(sx * w * 0.54, baseY + h * 0.14, 0))
        }
    }

    private func addMirrors() {
        for sx: Float in [-1, 1] {
            box(w * 0.04, h * 0.08, len * 0.14, ventMat(), SCNVector3(sx * w * 0.52, baseY + h * 0.62, len * 0.12))
            box(w * 0.12, h * 0.06, len * 0.08, chromeMat(), SCNVector3(sx * w * 0.56, baseY + h * 0.66, len * 0.12))
        }
    }

    private func addFrontFenders() {
        for sx: Float in [-1, 1] {
            box(w * 0.14, h * 0.32, len * 0.28, bodyMat(), SCNVector3(sx * w * 0.48, baseY + h * 0.38, len * 0.28))
            box(w * 0.06, h * 0.1, len * 0.22, carbonMat(), SCNVector3(sx * w * 0.54, baseY + h * 0.2, len * 0.3))
        }
    }

    private func addRearFenders() {
        for sx: Float in [-1, 1] {
            box(w * 0.16, h * 0.36, len * 0.32, bodyMat(), SCNVector3(sx * w * 0.5, baseY + h * 0.4, -len * 0.28))
        }
    }

    private func addExhaust(count: Int = 2) {
        let xs: [Float] = count >= 4
            ? [-0.22, -0.08, 0.08, 0.22]
            : count == 3 ? [-0.14, 0, 0.14] : [-0.1, 0.1]
        for x in xs {
            let pipe = SCNCylinder(radius: CGFloat(w * 0.025), height: CGFloat(len * 0.08))
            pipe.materials = [chromeMat()]
            let n = SCNNode(geometry: pipe)
            n.position = SCNVector3(x * w, baseY + h * 0.16, -len * 0.48)
            n.eulerAngles.x = .pi / 2
            root.addChildNode(n)
        }
    }

    private func addRearWing(widthMul: Float = 0.92, heightMul: Float = 0.08) {
        for sx: Float in [-1, 1] {
            box(w * 0.05, h * 0.22, len * 0.06, bodyMat(), SCNVector3(sx * w * 0.42, baseY + h * 0.88, -len * 0.4))
        }
        box(w * widthMul, h * heightMul, len * 0.1, carbonMat(), SCNVector3(0, baseY + h * 0.96, -len * 0.4), rake: -0.12)
    }

    func buildHyperWedge() {
        addFloorPan()
        box(w, h * 0.82, len * 0.96, bodyMat(), SCNVector3(0, baseY + h * 0.4, 0))
        box(w * 0.94, h * 0.18, len * 0.48, bodyMat(), SCNVector3(0, baseY + h * 0.74, len * 0.2), rake: -0.14)
        box(w * 0.9, h * 0.12, len * 0.55, bodyMat(), SCNVector3(0, baseY + h * 0.58, len * 0.08), rake: -0.06)
        box(w * 0.86, h * 0.46, len * 0.36, glassMat(), SCNVector3(0, baseY + h * 0.7, -len * 0.06), rake: 0.16)
        box(w * 0.72, h * 0.08, len * 0.2, glassMat(), SCNVector3(0, baseY + h * 0.78, len * 0.1), rake: -0.2)
        box(w * 1.04, h * 0.07, len * 0.14, carbonMat(), SCNVector3(0, baseY + h * 0.16, len * 0.46))
        box(w * 0.55, h * 0.05, len * 0.18, carbonMat(), SCNVector3(0, baseY + h * 0.12, len * 0.38), rake: -0.22)
        for sx: Float in [-1, 1] {
            box(w * 0.08, h * 0.04, len * 0.35, ventMat(), SCNVector3(sx * w * 0.42, baseY + h * 0.52, len * 0.34))
        }
        addFrontFenders()
        addRearFenders()
        addSkirts()
        addRearWing(widthMul: 1.05, heightMul: 0.06)
        box(w * 0.78, h * 0.05, len * 0.12, accentMat(), SCNVector3(0, baseY + h * 0.48, len * 0.44))
        addMirrors()
        addExhaust(count: 4)
    }

    func buildMidEngineSuper() {
        addFloorPan()
        box(w * 0.98, h * 0.88, len * 0.9, bodyMat(), SCNVector3(0, baseY + h * 0.42, -len * 0.02))
        box(w * 0.92, h * 0.2, len * 0.4, bodyMat(), SCNVector3(0, baseY + h * 0.74, len * 0.18), rake: -0.08)
        box(w * 0.88, h * 0.1, len * 0.52, bodyMat(), SCNVector3(0, baseY + h * 0.56, 0))
        box(w * 0.84, h * 0.44, len * 0.38, glassMat(), SCNVector3(0, baseY + h * 0.68, -len * 0.1), rake: 0.1)
        box(w * 0.5, h * 0.32, len * 0.12, glassMat(), SCNVector3(0, baseY + h * 0.72, len * 0.22), rake: -0.35)
        for sx: Float in [-1, 1] {
            box(w * 0.14, h * 0.34, len * 0.52, bodyMat(), SCNVector3(sx * w * 0.52, baseY + h * 0.46, -len * 0.18))
            box(w * 0.1, h * 0.22, len * 0.4, bodyMat(), SCNVector3(sx * w * 0.54, baseY + h * 0.5, len * 0.12))
        }
        box(w * 0.9, h * 0.05, len * 0.14, carbonMat(), SCNVector3(0, baseY + h * 0.18, len * 0.44))
        box(w * 0.7, h * 0.06, len * 0.5, carbonMat(), SCNVector3(0, baseY + h * 0.86, -len * 0.36), rake: 0.28)
        addSkirts()
        addMirrors()
        addExhaust(count: 2)
        if carId == "f40" {
            addRearWing(widthMul: 0.88, heightMul: 0.07)
        }
    }

    func buildExoticWide() {
        addFloorPan()
        box(w, h * 0.86, len, bodyMat(), SCNVector3(0, baseY + h * 0.41, 0))
        box(w * 0.88, h * 0.48, len * 0.42, glassMat(), SCNVector3(0, baseY + h * 0.76, -len * 0.04), rake: 0.08)
        box(w * 0.76, h * 0.12, len * 0.28, bodyMat(), SCNVector3(0, baseY + h * 0.58, len * 0.16), rake: -0.1)
        for sx: Float in [-1, 1] {
            box(w * 0.18, h * 0.3, len * 0.68, bodyMat(), SCNVector3(sx * w * 0.56, baseY + h * 0.48, len * 0.04))
            box(w * 0.06, h * 0.14, len * 0.55, carbonMat(), SCNVector3(sx * w * 0.6, baseY + h * 0.22, 0))
            box(w * 0.22, h * 0.08, len * 0.2, ventMat(), SCNVector3(sx * w * 0.58, baseY + h * 0.52, len * 0.32))
        }
        box(w * 1.12, h * 0.07, len * 0.22, carbonMat(), SCNVector3(0, baseY + h * 0.9, -len * 0.4), rake: -0.28)
        box(w * 0.62, h * 0.04, len * 0.16, accentMat(), SCNVector3(0, baseY + h * 0.2, len * 0.45))
        addSkirts()
        addMirrors()
        addExhaust(count: 2)
    }

    func buildSportsCoupe() {
        addFloorPan()
        box(w * 0.98, h * 0.9, len * 0.94, bodyMat(), SCNVector3(0, baseY + h * 0.43, 0))
        box(w * 0.92, h * 0.18, len * 0.42, bodyMat(), SCNVector3(0, baseY + h * 0.72, len * 0.18), rake: -0.06)
        box(w * 0.88, h * 0.44, len * 0.4, glassMat(), SCNVector3(0, baseY + h * 0.66, -len * 0.08), rake: 0.12)
        box(w * 0.82, h * 0.1, len * 0.48, bodyMat(), SCNVector3(0, baseY + h * 0.54, 0))
        for sx: Float in [-1, 1] {
            box(w * 0.06, h * 0.28, len * 0.08, glassMat(), SCNVector3(sx * w * 0.48, baseY + h * 0.62, -len * 0.02))
        }
        addFrontFenders()
        addRearFenders()
        addSkirts()
        box(w, h * 0.05, len * 0.16, accentMat(), SCNVector3(0, baseY + h * 0.5, -len * 0.44))
        if ["gtr", "r34", "r35-nismo", "evo", "sti"].contains(carId) {
            box(w * 0.92, h * 0.08, len * 0.2, carbonMat(), SCNVector3(0, baseY + h * 0.86, -len * 0.36), rake: -0.18)
            for sx: Float in [-1, 1] {
                box(w * 0.05, h * 0.28, len * 0.08, carbonMat(), SCNVector3(sx * w * 0.46, baseY + h * 0.58, -len * 0.34))
            }
        }
        if ["rx7", "supra"].contains(carId) {
            addRearWing(widthMul: 0.85, heightMul: 0.07)
        }
        addMirrors()
        addExhaust(count: 2)
    }

    func buildMuscle() {
        addFloorPan()
        box(w, h * 0.96, len, bodyMat(), SCNVector3(0, baseY + h * 0.44, -len * 0.04))
        box(w * 0.98, h * 0.2, len * 0.46, bodyMat(), SCNVector3(0, baseY + h * 0.78, len * 0.2), rake: 0.06)
        box(w * 0.5, h * 0.12, len * 0.34, bodyMat(), SCNVector3(0, baseY + h * 0.9, len * 0.1), rake: 0.06)
        box(w * 0.86, h * 0.5, len * 0.36, glassMat(), SCNVector3(0, baseY + h * 0.66, -len * 0.36), rake: 0.35)
        box(w * 0.94, h * 0.08, len * 0.38, bodyMat(), SCNVector3(0, baseY + h * 0.52, len * 0.08))
        for sx: Float in [-1, 1] {
            box(w * 0.22, h * 0.4, len * 0.24, bodyMat(), SCNVector3(sx * w * 0.54, baseY + h * 0.46, -len * 0.3))
            box(w * 0.06, h * 0.18, len * 0.68, carbonMat(), SCNVector3(sx * w * 0.56, baseY + h * 0.2, 0))
            box(w * 0.12, h * 0.08, len * 0.28, ventMat(), SCNVector3(sx * w * 0.5, baseY + h * 0.58, len * 0.34))
        }
        box(w * 0.95, h * 0.1, len * 0.2, bodyMat(), SCNVector3(0, baseY + h * 0.88, -len * 0.42), rake: -0.22)
        for sx: Float in [-1, 1] {
            box(w * 0.06, h * 0.04, len * 0.72, accentMat(), SCNVector3(sx * w * 0.22, baseY + h * 0.58, len * 0.02))
        }
        addSkirts()
        addMirrors()
        addExhaust(count: 2)
    }

    func buildTuner() {
        addFloorPan()
        box(w * 0.96, h * 0.86, len * 0.88, bodyMat(), SCNVector3(0, baseY + h * 0.44, 0))
        box(w * 0.9, h * 0.46, len * 0.44, glassMat(), SCNVector3(0, baseY + h * 0.64, -len * 0.04))
        box(w * 0.88, h * 0.12, len * 0.5, bodyMat(), SCNVector3(0, baseY + h * 0.52, 0))
        box(w, h * 0.08, len * 0.24, carbonMat(), SCNVector3(0, baseY + h * 0.86, -len * 0.36), rake: -0.16)
        box(w * 0.92, h * 0.06, len * 0.12, carbonMat(), SCNVector3(0, baseY + h * 0.2, len * 0.4))
        for sx: Float in [-1, 1] {
            box(w * 0.05, h * 0.3, len * 0.1, carbonMat(), SCNVector3(sx * w * 0.48, baseY + h * 0.58, -len * 0.32))
            box(w * 0.14, h * 0.06, len * 0.55, accentMat(), SCNVector3(sx * w * 0.5, baseY + h * 0.56, 0.04))
        }
        addFrontFenders()
        addSkirts()
        addMirrors()
        addExhaust(count: 2)
        if carId == "evo" || carId == "sti" {
            addRearWing(widthMul: 0.95, heightMul: 0.09)
        }
    }

    func buildSedanGT() {
        addFloorPan()
        box(w, h * 0.94, len, bodyMat(), SCNVector3(0, baseY + h * 0.46, 0))
        box(w * 0.94, h * 0.54, len * 0.58, glassMat(), SCNVector3(0, baseY + h * 0.7, -len * 0.06))
        box(w * 0.96, h * 0.16, len * 0.38, bodyMat(), SCNVector3(0, baseY + h * 0.76, len * 0.2), rake: -0.04)
        box(w * 0.98, h * 0.12, len * 0.42, bodyMat(), SCNVector3(0, baseY + h * 0.58, -len * 0.18))
        box(w * 0.9, h * 0.05, len * 0.14, chromeMat(), SCNVector3(0, baseY + h * 0.54, len * 0.46))
        box(w * 0.85, h * 0.04, len * 0.1, chromeMat(), SCNVector3(0, baseY + h * 0.42, len * 0.47))
        for sx: Float in [-1, 1] {
            box(w * 0.12, h * 0.2, len * 0.35, bodyMat(), SCNVector3(sx * w * 0.48, baseY + h * 0.5, -len * 0.12))
        }
        addSkirts()
        addMirrors()
        addExhaust(count: 2)
    }

    func buildRoadster() {
        addFloorPan()
        box(w * 0.94, h * 0.72, len * 0.86, bodyMat(), SCNVector3(0, baseY + h * 0.4, len * 0.05))
        box(w * 0.88, h * 0.2, len * 0.34, bodyMat(), SCNVector3(0, baseY + h * 0.64, len * 0.16), rake: -0.05)
        box(w * 0.52, h * 0.26, len * 0.22, glassMat(), SCNVector3(0, baseY + h * 0.68, -len * 0.06))
        box(w * 0.78, h * 0.08, len * 0.18, bodyMat(), SCNVector3(0, baseY + h * 0.48, -len * 0.2))
        for sx: Float in [-1, 1] {
            box(w * 0.1, h * 0.24, len * 0.3, bodyMat(), SCNVector3(sx * w * 0.46, baseY + h * 0.42, 0))
        }
        box(w, h * 0.06, len * 0.14, carbonMat(), SCNVector3(0, baseY + h * 0.2, len * 0.38))
        box(w * 0.7, h * 0.04, len * 0.08, accentMat(), SCNVector3(0, baseY + h * 0.52, len * 0.4))
        addSkirts()
        addMirrors()
        addExhaust(count: 2)
    }

    func buildPolice() {
        buildMuscle()
        let kit = SCNNode()
        kit.name = "krcPoliceKit"

        let bar = SCNBox(width: CGFloat(w * 0.88), height: CGFloat(h * 0.08), length: CGFloat(len * 0.22), chamferRadius: 0.02)
        let pm = SCNMaterial()
        pm.lightingModel = .physicallyBased
        pm.diffuse.contents = UIColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1)
        pm.metalness.contents = 0.4
        bar.materials = [pm]
        let barNode = SCNNode(geometry: bar)
        barNode.name = "krcPoliceLightBar"
        barNode.position = SCNVector3(0, baseY + h * 1.04, -len * 0.14)
        kit.addChildNode(barNode)

        let red = UIColor(red: 1, green: 0.05, blue: 0.12, alpha: 1)
        let blue = UIColor(red: 0.08, green: 0.48, blue: 1, alpha: 1)
        for (x, color, side): (Float, UIColor, String) in [
            (-0.18, red, "Red"),
            (0.18, blue, "Blue"),
        ] {
            let lens = SCNBox(width: CGFloat(w * 0.14), height: CGFloat(h * 0.06), length: CGFloat(len * 0.1), chamferRadius: 0.01)
            let lm = SCNMaterial()
            lm.name = "krcPoliceLensMat\(side)"
            lm.lightingModel = .constant
            lm.diffuse.contents = color
            lm.emission.contents = color
            lens.materials = [lm]
            let n = SCNNode(geometry: lens)
            n.name = "krcPoliceLens\(side)"
            n.position = SCNVector3(x * w, baseY + h * 1.08, -len * 0.14)
            kit.addChildNode(n)

            let light = SCNLight()
            light.type = .omni
            light.color = color
            light.intensity = 0
            light.attenuationEndDistance = 8
            let lightNode = SCNNode()
            lightNode.name = "krcPoliceFlash\(side)"
            lightNode.light = light
            lightNode.position = SCNVector3(n.position.x, n.position.y + 0.04, n.position.z)
            kit.addChildNode(lightNode)
        }
        box(w * 0.92, h * 0.05, len * 0.7, accentMat(), SCNVector3(0, baseY + h * 0.58, len * 0.02))
        root.addChildNode(kit)
    }

    func attachWheels(style: VehicleWheelStyle) {
        let spread = w * 0.5
        let frontZ = len * 0.28
        let rearZ = -len * 0.3
        let wheelY = baseY + h * 0.22
        let anchors: [WheelAssembly.Anchor] = [
            .init(x: spread, y: wheelY, z: frontZ, sideSign: 1),
            .init(x: -spread, y: wheelY, z: frontZ, sideSign: -1),
            .init(x: spread * 1.02, y: wheelY, z: rearZ, sideSign: 1),
            .init(x: -spread * 1.02, y: wheelY, z: rearZ, sideSign: -1),
        ]
        WheelAssembly.attachStyledWheels(to: root, style: style, scale: s, anchors: anchors)
    }

    func attachLights() {
        let headMat = VehicleMaterialLibrary.headlightLens()
        let tailMat = VehicleMaterialLibrary.tailLight()
        switch headlights {
        case .quadRound:
            for sx: Float in [-1, 1] {
                for row: Float in [0, 1] {
                    let cyl = SCNCylinder(radius: CGFloat(w * 0.055), height: CGFloat(h * 0.05))
                    cyl.materials = [headMat]
                    let n = SCNNode(geometry: cyl)
                    n.name = "krcHeadlightLens"
                    n.renderingOrder = 6
                    // Keep both rows inside the nose — previously the outer row stuck past the bumper.
                    let z = len * (0.42 - row * 0.045)
                    n.position = SCNVector3(sx * w * 0.30, baseY + h * 0.36, z)
                    n.eulerAngles.x = .pi / 2
                    root.addChildNode(n)
                }
            }
        case .slimLED, .aggressiveSplit:
            addNamedHeadlightBox(w * 0.50, h * 0.045, h * 0.03, headMat, SCNVector3(0, baseY + h * 0.37, len * 0.42))
            for sx: Float in [-1, 1] {
                addNamedHeadlightBox(w * 0.16, h * 0.035, h * 0.025, headMat, SCNVector3(sx * w * 0.34, baseY + h * 0.36, len * 0.415))
            }
        }
        let tail = SCNBox(width: CGFloat(w * 0.82), height: CGFloat(h * 0.08), length: CGFloat(h * 0.04), chamferRadius: 0.02)
        tail.materials = [tailMat]
        let tailNode = SCNNode(geometry: tail)
        tailNode.name = "krcTailLamp"
        tailNode.position = SCNVector3(0, baseY + h * 0.42, -len * 0.47)
        root.addChildNode(tailNode)
        attachBrakeSystem()
    }

    private func addNamedHeadlightBox(_ width: Float, _ height: Float, _ depth: Float, _ mat: SCNMaterial, _ pos: SCNVector3) {
        let geo = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(depth), chamferRadius: 0.02)
        geo.materials = [mat]
        let n = SCNNode(geometry: geo)
        n.name = "krcHeadlightLens"
        n.renderingOrder = 6
        n.position = pos
        root.addChildNode(n)
    }

    private func attachBrakeSystem() {
        let brakeMat = VehicleMaterialLibrary.tailLight()
        let brakeGeo = SCNBox(width: CGFloat(w * 0.22), height: CGFloat(h * 0.14), length: CGFloat(h * 0.05), chamferRadius: 0.02)
        brakeGeo.materials = [brakeMat]
        for sx: Float in [-1, 1] {
            let lamp = SCNNode(geometry: brakeGeo)
            lamp.name = "krcBrakeLamp"
            lamp.position = SCNVector3(sx * w * 0.34, baseY + h * 0.42, -len * 0.48)
            root.addChildNode(lamp)
            let glow = SCNLight()
            glow.type = .omni
            glow.color = UIColor(red: 1, green: 0.05, blue: 0, alpha: 1)
            glow.intensity = 480
            let gn = SCNNode()
            gn.name = "krcBrakeGlow"
            gn.light = glow
            gn.position = SCNVector3(sx * w * 0.34, baseY + h * 0.42, -len * 0.5)
            root.addChildNode(gn)
        }
    }
}

private extension UIColor {
    func asMaterial() -> SCNMaterial? {
        let m = VehicleMaterialLibrary.bodyPaint(
            VehicleMaterialLibrary.PaintDescriptor(color: self, finish: .gloss)
        )
        return m
    }
}
