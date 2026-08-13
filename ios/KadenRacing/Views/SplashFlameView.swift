import SwiftUI

/// Animated fire under the menu title — layered tongues, cores, sparks, and ember glow.
struct SplashFlameView: View {
    /// 0…1 — lower values keep the menu closer to the photo backdrop.
    var intensity: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 45, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    drawEmberGlow(context: &context, size: size, time: t)
                    let specs: [(CGFloat, CGFloat, CGFloat, Double)] = [
                        (0.08, 42, 96, 0.0),
                        (0.22, 36, 78, 0.4),
                        (0.38, 54, 118, 0.15),
                        (0.54, 48, 104, 0.55),
                        (0.68, 38, 82, 0.25),
                        (0.82, 44, 94, 0.7)
                    ]
                    for spec in specs {
                        drawFlameColumn(
                            context: &context,
                            size: size,
                            left: spec.0,
                            width: spec.1,
                            height: spec.2,
                            phase: spec.3,
                            time: t
                        )
                    }
                    drawSparks(context: &context, size: size, time: t)
                }
            }
        }
        .opacity(Double(min(1, max(0, intensity))))
        .allowsHitTesting(false)
    }

    private func drawEmberGlow(context: inout GraphicsContext, size: CGSize, time: Double) {
        let pulse = 0.88 + sin(time * 2.1) * 0.12
        let rect = CGRect(
            x: size.width * 0.5 - min(size.width * 0.44, 220),
            y: size.height - 58,
            width: min(size.width * 0.88, 440),
            height: 72 * pulse
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 1, green: 0.45, blue: 0).opacity(0.62),
                    Color(red: 1, green: 0.2, blue: 0).opacity(0.28),
                    .clear
                ]),
                center: CGPoint(x: rect.midX, y: rect.maxY),
                startRadius: 4,
                endRadius: rect.width * 0.52
            )
        )
    }

    private func drawFlameColumn(
        context: inout GraphicsContext,
        size: CGSize,
        left: CGFloat,
        width: CGFloat,
        height: CGFloat,
        phase: Double,
        time: Double
    ) {
        let cx = size.width * left + width * 0.5
        let baseY = size.height
        let flicker = sin(time * 5.5 + phase * 9.1) * 0.06
        let sway = sin(time * 3.2 + phase * 4.7) * width * 0.14

        var outer = Path()
        let h = height * (1 + flicker * 0.5)
        outer.move(to: CGPoint(x: cx + sway, y: baseY))
        outer.addCurve(
            to: CGPoint(x: cx + width * 0.92 + sway * 0.5, y: baseY - h * 0.42),
            control1: CGPoint(x: cx + width * 0.55 + sway, y: baseY - h * 0.08),
            control2: CGPoint(x: cx + width * 1.05 + sway, y: baseY - h * 0.22)
        )
        outer.addCurve(
            to: CGPoint(x: cx + sway * 0.3, y: baseY - h * 0.92),
            control1: CGPoint(x: cx + width * 0.7 + sway, y: baseY - h * 0.78),
            control2: CGPoint(x: cx + width * 0.35 + sway * 0.4, y: baseY - h * 0.88)
        )
        outer.addCurve(
            to: CGPoint(x: cx - width * 0.92 + sway * 0.5, y: baseY - h * 0.42),
            control1: CGPoint(x: cx - width * 0.25 + sway * 0.2, y: baseY - h * 0.88),
            control2: CGPoint(x: cx - width * 0.55 + sway, y: baseY - h * 0.75)
        )
        outer.addCurve(
            to: CGPoint(x: cx + sway, y: baseY),
            control1: CGPoint(x: cx - width * 1.05 + sway, y: baseY - h * 0.22),
            control2: CGPoint(x: cx - width * 0.55 + sway, y: baseY - h * 0.08)
        )
        outer.closeSubpath()

        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.fill(
                outer,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1, green: 0.15, blue: 0).opacity(0.85),
                        Color(red: 1, green: 0.55, blue: 0).opacity(0.55),
                        Color(red: 1, green: 0.85, blue: 0.2).opacity(0.12),
                        .clear
                    ]),
                    startPoint: CGPoint(x: cx, y: baseY),
                    endPoint: CGPoint(x: cx + sway * 0.2, y: baseY - h)
                )
            )
        }

        var mid = Path()
        let mh = h * 0.72
        mid.move(to: CGPoint(x: cx + sway * 0.6, y: baseY - 4))
        mid.addCurve(
            to: CGPoint(x: cx + width * 0.42 + sway, y: baseY - mh * 0.55),
            control1: CGPoint(x: cx + width * 0.35 + sway, y: baseY - mh * 0.12),
            control2: CGPoint(x: cx + width * 0.55 + sway, y: baseY - mh * 0.32)
        )
        mid.addCurve(
            to: CGPoint(x: cx + sway * 0.2, y: baseY - mh * 0.88),
            control1: CGPoint(x: cx + width * 0.18 + sway, y: baseY - mh * 0.78),
            control2: CGPoint(x: cx + sway, y: baseY - mh * 0.9)
        )
        mid.addCurve(
            to: CGPoint(x: cx - width * 0.42 + sway, y: baseY - mh * 0.55),
            control1: CGPoint(x: cx - width * 0.12 + sway, y: baseY - mh * 0.88),
            control2: CGPoint(x: cx - width * 0.35 + sway, y: baseY - mh * 0.32)
        )
        mid.addCurve(
            to: CGPoint(x: cx + sway * 0.6, y: baseY - 4),
            control1: CGPoint(x: cx - width * 0.55 + sway, y: baseY - mh * 0.12),
            control2: CGPoint(x: cx - width * 0.35 + sway, y: baseY - mh * 0.12)
        )
        mid.closeSubpath()

        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.fill(
                mid,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1, green: 0.35, blue: 0).opacity(0.9),
                        Color(red: 1, green: 0.75, blue: 0.1).opacity(0.75),
                        Color(red: 1, green: 0.95, blue: 0.55).opacity(0.35),
                        .clear
                    ]),
                    startPoint: CGPoint(x: cx, y: baseY),
                    endPoint: CGPoint(x: cx, y: baseY - mh)
                )
            )
        }

        let coreH = mh * 0.45
        let coreRect = CGRect(
            x: cx - width * 0.14 + sway * 0.3,
            y: baseY - coreH - 6,
            width: width * 0.28,
            height: coreH
        )
        context.drawLayer { layer in
            layer.blendMode = .plusLighter
            layer.fill(
                Path(ellipseIn: coreRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1, green: 1, blue: 0.85).opacity(0.95),
                        Color(red: 1, green: 0.85, blue: 0.2).opacity(0.55),
                        .clear
                    ]),
                    center: CGPoint(x: coreRect.midX, y: coreRect.maxY - coreRect.height * 0.15),
                    startRadius: 1,
                    endRadius: max(coreRect.width, coreRect.height) * 0.85
                )
            )
        }
    }

    private func drawSparks(context: inout GraphicsContext, size: CGSize, time: Double) {
        let count = 18
        for i in 0..<count {
            let seed = Double(i) * 1.73
            let x = size.width * (0.1 + 0.8 * fract(sin(seed * 12.7) * 0.5 + 0.5))
            let rise = fract(time * 0.55 + seed) * size.height * 0.75
            let y = size.height - rise
            let r = 1.2 + fract(seed * 3.1) * 2.2
            let alpha = (1 - rise / (size.height * 0.75)) * 0.65
            guard alpha > 0.05 else { continue }
            let sparkRect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            context.fill(
                Path(ellipseIn: sparkRect),
                with: .color(Color(red: 1, green: 0.7 + fract(seed) * 0.25, blue: 0.1).opacity(alpha))
            )
        }
    }

    private func fract(_ x: Double) -> Double {
        x - floor(x)
    }
}
