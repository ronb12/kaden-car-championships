import SwiftUI

/// Mini circuit silhouette + themed backdrop for track-select cards.
struct TrackPreviewArt: View {
    let trackIndex: Int
    var accent: Color = KRCDesign.neonCyan

    private var profile: EnvironmentTrackProfile {
        EnvironmentTrackProfile.from(catalogTrackIndex: trackIndex)
    }

    var body: some View {
        ZStack {
            let colors = KRCProceduralTextures.trackCardGradient(seed: trackIndex)
            LinearGradient(
                colors: colors.map { Color(uiColor: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                drawEnvironmentMotif(context: &context, size: size, profile: profile, seed: trackIndex)
            }
            .opacity(0.35)
            Canvas { context, size in
                drawCircuit(context: &context, size: size)
            }
            .opacity(0.95)
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack {
                HStack {
                    Spacer()
                    Text(profile.displayName.uppercased())
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundStyle(accent.opacity(0.9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.45)))
                }
                Spacer()
            }
            .padding(5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func drawEnvironmentMotif(
        context: inout GraphicsContext,
        size: CGSize,
        profile: EnvironmentTrackProfile,
        seed: Int
    ) {
        let w = size.width
        let h = size.height
        let tint = Color.white.opacity(0.22)
        switch profile {
        case .coastalCityCircuit, .coastalOpen, .stormHarbor:
            for i in 0..<4 {
                let y = h * (0.55 + CGFloat(i) * 0.11)
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: y))
                for x in stride(from: 0.0, through: Double(w), by: 8) {
                    let phase = CGFloat(x) * 0.04 + CGFloat(i) * 0.8 + CGFloat(seed) * 0.02
                    wave.addLine(to: CGPoint(x: x, y: y + sin(phase) * 4))
                }
                context.stroke(wave, with: .color(tint), lineWidth: 1.2)
            }
        case .desertHighway:
            for i in 0..<3 {
                let baseY = h * (0.72 - CGFloat(i) * 0.14)
                var dune = Path()
                dune.move(to: CGPoint(x: -4, y: baseY))
                dune.addQuadCurve(
                    to: CGPoint(x: w * 0.55, y: baseY - 14),
                    control: CGPoint(x: w * 0.22, y: baseY - 22)
                )
                dune.addQuadCurve(
                    to: CGPoint(x: w + 4, y: baseY),
                    control: CGPoint(x: w * 0.82, y: baseY - 10)
                )
                dune.closeSubpath()
                context.fill(dune, with: .color(tint.opacity(0.35)))
            }
        case .alpineRidge:
            var peaks = Path()
            peaks.move(to: CGPoint(x: 0, y: h))
            let pts: [CGFloat] = [0.12, 0.28, 0.42, 0.58, 0.74, 0.9]
            for (i, fx) in pts.enumerated() {
                let peakH = h * (0.35 + CGFloat((seed + i) % 5) * 0.04)
                peaks.addLine(to: CGPoint(x: w * fx, y: peakH))
            }
            peaks.addLine(to: CGPoint(x: w, y: h))
            peaks.closeSubpath()
            context.fill(peaks, with: .color(tint.opacity(0.4)))
        case .urbanNight:
            let step: CGFloat = 14
            for x in stride(from: step, to: w, by: step) {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: h))
                context.stroke(line, with: .color(tint.opacity(0.18)), lineWidth: 0.8)
            }
            for y in stride(from: step, to: h, by: step) {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: w, y: y))
                context.stroke(line, with: .color(tint.opacity(0.14)), lineWidth: 0.8)
            }
        case .speedwayOval:
            let cx = w * 0.5
            let cy = h * 0.52
            for ring in 1...3 {
                let rx = w * 0.38 * CGFloat(ring) / 3
                let ry = h * 0.32 * CGFloat(ring) / 3
                let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
                context.stroke(Ellipse().path(in: rect), with: .color(tint), lineWidth: 1.4)
            }
        case .technicalCircuit:
            var chicane = Path()
            chicane.move(to: CGPoint(x: w * 0.1, y: h * 0.7))
            chicane.addLine(to: CGPoint(x: w * 0.35, y: h * 0.35))
            chicane.addLine(to: CGPoint(x: w * 0.55, y: h * 0.75))
            chicane.addLine(to: CGPoint(x: w * 0.78, y: h * 0.4))
            context.stroke(chicane, with: .color(tint), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        case .standard:
            let dotCount = 12 + (seed % 6)
            for i in 0..<dotCount {
                let px = CGFloat((i * 17 + seed * 3) % Int(max(1, w - 4))) + 2
                let py = CGFloat((i * 11 + seed * 5) % Int(max(1, h - 4))) + 2
                let r: CGFloat = 1.2 + CGFloat(i % 3) * 0.6
                context.fill(
                    Circle().path(in: CGRect(x: px, y: py, width: r, height: r)),
                    with: .color(tint.opacity(0.5))
                )
            }
        }
    }

    private func drawCircuit(context: inout GraphicsContext, size: CGSize) {
        let pts = circuitPoints(seed: trackIndex, count: 32)
        guard pts.count >= 3 else { return }

        let pad: CGFloat = 8
        let w = size.width - pad * 2
        let h = size.height - pad * 2
        let mapped = pts.map { CGPoint(x: pad + CGFloat($0.x) * w, y: pad + CGFloat($0.y) * h) }

        var path = Path()
        path.move(to: mapped[0])
        for p in mapped.dropFirst() { path.addLine(to: p) }
        path.closeSubpath()

        context.stroke(
            path,
            with: .color(.white.opacity(0.3)),
            style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(accent.opacity(0.95)),
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
        )

        let start = mapped[0]
        context.fill(
            Circle().path(in: CGRect(x: start.x - 3.5, y: start.y - 3.5, width: 7, height: 7)),
            with: .color(KRCDesign.gold)
        )
    }

    private func circuitPoints(seed: Int, count: Int) -> [(x: Float, y: Float)] {
        let spline = CatalogTrackGenerator.makeTrack(index: seed)
        let raw = spline.points
        guard !raw.isEmpty else { return [] }
        var minX = raw[0].x, maxX = raw[0].x, minZ = raw[0].z, maxZ = raw[0].z
        for p in raw {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minZ = min(minZ, p.z); maxZ = max(maxZ, p.z)
        }
        let spanX = max(maxX - minX, 1)
        let spanZ = max(maxZ - minZ, 1)
        let step = max(1, raw.count / max(count, 8))
        var pts: [(Float, Float)] = []
        pts.reserveCapacity(count + 1)
        for i in stride(from: 0, to: raw.count, by: step) {
            let p = raw[i]
            let nx = (p.x - minX) / spanX
            let nz = (p.z - minZ) / spanZ
            pts.append((min(0.94, max(0.06, nx)), min(0.94, max(0.06, nz))))
        }
        if let first = pts.first, let last = pts.last, first.0 != last.0 || first.1 != last.1 {
            pts.append(first)
        }
        return pts
    }
}
