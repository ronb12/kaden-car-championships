import SwiftUI

/// Manual gearbox shift buttons (− down / + up) — shown only in manual transmission mode.
struct TransmissionShiftControls: View {
    var input: RaceInput
    let portrait: Bool
    let shiftZone: Bool

    var body: some View {
        HStack {
            shiftPad(label: "−", isDown: true)
            Spacer(minLength: 0)
            shiftPad(label: "+", isDown: false, highlight: shiftZone)
        }
        .padding(.horizontal, portrait ? 148 : 168)
        .padding(.bottom, portrait ? 10 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func shiftPad(label: String, isDown: Bool, highlight: Bool = false) -> some View {
        Text(label)
            .font(.system(size: 34, weight: .black, design: .rounded))
            .foregroundStyle(highlight ? Color(red: 0.55, green: 1, blue: 0.74) : .white)
            .frame(width: portrait ? 56 : 64, height: portrait ? 60 : 72)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.12, blue: 0.22, opacity: 0.82),
                                Color(red: 0, green: 0.28, blue: 0.55, opacity: 0.58)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                highlight ? Color(red: 0.55, green: 1, blue: 0.74).opacity(0.95) : Color.white.opacity(0.75),
                                lineWidth: highlight ? 2.5 : 1.5
                            )
                    )
                    .shadow(color: highlight ? Color.green.opacity(0.45) : Color.cyan.opacity(0.25), radius: highlight ? 12 : 8)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if isDown { input.shiftDown = true } else { input.shiftUp = true }
                    }
                    .onEnded { _ in
                        if isDown { input.shiftDown = false } else { input.shiftUp = false }
                    }
            )
            .accessibilityLabel(isDown ? "Shift down" : "Shift up")
    }
}
