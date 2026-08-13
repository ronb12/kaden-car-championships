import SwiftUI

/// Virtual steering wheel overlay for `.wheel` control scheme.
struct SteeringWheelControl: View {
    var input: RaceInput
    @State private var dragAngle: Double = 0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.42 * ControlPreferences.controlScale
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [KRCDesign.neonCyan.opacity(0.5), KRCDesign.hotOrange.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: size, height: size)
                    .background(Circle().fill(.ultraThinMaterial).opacity(ControlPreferences.controlOpacity))
                Circle()
                    .fill(KRCDesign.neonCyan.opacity(0.85))
                    .frame(width: size * 0.12, height: size * 0.35)
                    .offset(y: -size * 0.22)
                    .rotationEffect(.degrees(dragAngle))
            }
            .position(x: geo.size.width * 0.22, y: geo.size.height * 0.72)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let c = CGPoint(x: geo.size.width * 0.22, y: geo.size.height * 0.72)
                        let dx = v.location.x - c.x
                        let dy = v.location.y - c.y
                        dragAngle = atan2(dy, dx) * 180 / .pi + 90
                        let steer = max(-1, min(1, Float(dx / (size * 0.35)) * ControlPreferences.steerSensitivity))
                        input.steer = steer
                        input.left = steer < -0.15
                        input.right = steer > 0.15
                    }
                    .onEnded { _ in
                        dragAngle = 0
                        input.steer = 0
                        input.left = false
                        input.right = false
                    }
            )
        }
        .allowsHitTesting(true)
    }
}
