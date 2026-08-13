import SwiftUI
import UIKit

/// Gamepad-style on-screen controls — left steer pad + A/B/X/Y face buttons (gas/brake on A/B only).
struct DPadRaceControls: UIViewRepresentable {
    var input: RaceInput
    var layout: RaceControlLayout

    func makeCoordinator() -> Coordinator {
        Coordinator(input: input)
    }

    func makeUIView(context: Context) -> DPadControllerView {
        let v = DPadControllerView()
        v.coordinator = context.coordinator
        v.layoutMode = layout
        return v
    }

    func updateUIView(_ uiView: DPadControllerView, context: Context) {
        uiView.layoutMode = layout
        context.coordinator.input = input
        uiView.coordinator = context.coordinator
    }

    final class Coordinator {
        var input: RaceInput
        init(input: RaceInput) { self.input = input }

        func sync(
            gas: Bool,
            brake: Bool,
            nitro: Bool,
            left: Bool,
            right: Bool,
            handbrake: Bool,
            reverse: Bool
        ) {
            let apply = { [input] in
                input.gas = gas
                input.brake = brake
                input.nitro = nitro
                input.left = left
                input.right = right
                input.handbrake = handbrake
                input.reverse = reverse
                input.throttle = gas ? 1 : 0
                input.brakeAmount = brake ? 1 : 0
                input.handbrakeAmount = handbrake ? 1 : 0
                input.steer = (right ? 1 : 0) - (left ? 1 : 0)
            }
            if Thread.isMainThread {
                apply()
            } else {
                DispatchQueue.main.async(execute: apply)
            }
        }
    }
}

// MARK: - Container

private enum DPadDirection: Int {
    case up = 1, down, left, right
}

private enum FaceButton: Int {
    case a = 10, b, x, y
}

final class DPadControllerView: UIView {

    var coordinator: DPadRaceControls.Coordinator?
    var layoutMode: RaceControlLayout = .landscape {
        didSet { if oldValue != layoutMode { rebuild() } }
    }

    private var dpadCenter = UIView()
    private var dpadButtons: [DPadDirection: DPadPadButton] = [:]
    private var faceButtons: [FaceButton: DPadPadButton] = [:]

    private var leftOn = false
    private var rightOn = false
    private var gasOn = false
    private var brakeOn = false
    private var nitroOn = false
    private var handbrakeOn = false
    private var reverseOn = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Pass through touches that don't land on any actual button subview,
        // so the SwiftUI layer below (PAUSE button, etc.) can receive them.
        let result = super.hitTest(point, with: event)
        return result === self ? nil : result
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutControls()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        layoutControls()
    }

    private func rebuild() {
        subviews.forEach { $0.removeFromSuperview() }
        dpadButtons.removeAll()
        faceButtons.removeAll()
        leftOn = false
        rightOn = false
        gasOn = false
        brakeOn = false
        nitroOn = false
        handbrakeOn = false
        reverseOn = false

        // No frosted landscape dock plate — only the control buttons themselves.
        buildDPad()
        buildFaceButtons()
        setNeedsLayout()
    }

    private func controlScale() -> CGFloat {
        ControlPreferences.controlScale
    }

    private func controlOpacity() -> CGFloat {
        ControlPreferences.controlOpacity
    }

    private func buildDPad() {
        // Clear hit-target host only — no frosted plate behind the steer buttons.
        let shell = UIView()
        shell.isUserInteractionEnabled = false
        shell.backgroundColor = .clear
        shell.isOpaque = false
        dpadCenter = shell
        addSubview(shell)

        // Steer L/R + reverse under the pad.
        let specs: [(DPadDirection, String, String?, UIColor)] = [
            (.left, "chevron.left", nil, UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)),
            (.right, "chevron.right", nil, UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)),
            (.down, "arrow.uturn.down", "REV", UIColor(red: 0.75, green: 0.55, blue: 1.0, alpha: 1)),
        ]
        for (dir, symbol, caption, accent) in specs {
            let btn = DPadPadButton(
                symbol: symbol,
                caption: caption,
                accent: accent,
                isDirectional: true
            )
            btn.tag = dir.rawValue
            btn.addTarget(self, action: #selector(padDown(_:)), for: .touchDown)
            btn.addTarget(self, action: #selector(padUp(_:)), for: [.touchUpInside, .touchCancel, .touchUpOutside, .touchDragExit])
            addSubview(btn)
            dpadButtons[dir] = btn
        }
    }

    private func buildFaceButtons() {
        let specs: [(FaceButton, String, String, UIColor)] = [
            (.y, "bolt.fill", "N2O", UIColor(red: 0, green: 0.92, blue: 1, alpha: 1)),
            (.x, "p.circle.fill", "DRIFT", UIColor(red: 0.92, green: 0.78, blue: 0.2, alpha: 1)),
            (.b, "stop.fill", "BRAKE", UIColor(red: 1, green: 0.28, blue: 0.22, alpha: 1)),
            (.a, "flame.fill", "GAS", UIColor(red: 1, green: 0.55, blue: 0.1, alpha: 1)),
        ]
        for (face, symbol, label, accent) in specs {
            let btn = DPadPadButton(symbol: symbol, caption: label, accent: accent, isDirectional: false)
            btn.tag = face.rawValue
            btn.addTarget(self, action: #selector(faceDown(_:)), for: .touchDown)
            btn.addTarget(self, action: #selector(faceUp(_:)), for: [.touchUpInside, .touchCancel, .touchUpOutside, .touchDragExit])
            addSubview(btn)
            faceButtons[face] = btn
        }
    }

    private func layoutControls() {
        let marginL = max(12, safeAreaInsets.left + 6)
        let marginR = max(12, safeAreaInsets.right + 6)
        let bottom = safeAreaInsets.bottom
        let scale = controlScale()
        let pad = 10 * scale
        let dpadGap = 10 * scale
        let faceGap = 12 * scale

        let dpadBtnBase: CGFloat = layoutMode == .portrait ? 52 : 48
        let dpadBtnScaled = dpadBtnBase * scale
        let faceSize: CGFloat = (layoutMode == .portrait ? 50 : 46) * scale

        let dpadW = dpadBtnScaled * 2 + dpadGap
        let dpadH = dpadBtnScaled * 2 + dpadGap
        // Sit controls just above the home indicator — no empty dock chrome reserved.
        let yBase = bounds.height - bottom - (layoutMode == .landscape ? 14 : pad) - dpadH

        dpadCenter.frame = CGRect(x: marginL, y: yBase, width: dpadW, height: dpadH)

        dpadButtons[.left]?.frame = CGRect(x: marginL, y: yBase, width: dpadBtnScaled, height: dpadBtnScaled)
        dpadButtons[.right]?.frame = CGRect(
            x: marginL + dpadBtnScaled + dpadGap,
            y: yBase,
            width: dpadBtnScaled,
            height: dpadBtnScaled
        )
        dpadButtons[.down]?.frame = CGRect(
            x: marginL + (dpadW - dpadBtnScaled) * 0.5,
            y: yBase + dpadBtnScaled + dpadGap,
            width: dpadBtnScaled,
            height: dpadBtnScaled
        )

        // Diamond: Y top, X/B middle row, A bottom — each row separated by (faceSize + gap).
        let step = faceSize + faceGap
        let faceW = step + faceSize
        let faceH = step * 2 + faceSize
        let faceX = bounds.width - marginR - faceW
        let faceY = bounds.height - bottom - (layoutMode == .landscape ? 10 : pad) - faceH
        let faceCenterX = faceX + faceW * 0.5

        faceButtons[.y]?.frame = CGRect(
            x: faceCenterX - faceSize * 0.5,
            y: faceY,
            width: faceSize,
            height: faceSize
        )
        faceButtons[.x]?.frame = CGRect(
            x: faceX,
            y: faceY + step,
            width: faceSize,
            height: faceSize
        )
        faceButtons[.b]?.frame = CGRect(
            x: faceX + step,
            y: faceY + step,
            width: faceSize,
            height: faceSize
        )
        faceButtons[.a]?.frame = CGRect(
            x: faceCenterX - faceSize * 0.5,
            y: faceY + step * 2,
            width: faceSize,
            height: faceSize
        )
    }

    @objc private func padDown(_ sender: DPadPadButton) {
        haptic()
        guard let dir = DPadDirection(rawValue: sender.tag) else { return }
        switch dir {
        case .left: leftOn = true
        case .right: rightOn = true
        case .down: reverseOn = true
        case .up: break
        }
        sender.setPressed(true)
        fire()
    }

    @objc private func padUp(_ sender: DPadPadButton) {
        guard let dir = DPadDirection(rawValue: sender.tag) else { return }
        switch dir {
        case .left: leftOn = false
        case .right: rightOn = false
        case .down: reverseOn = false
        case .up: break
        }
        sender.setPressed(false)
        fire()
    }

    @objc private func faceDown(_ sender: DPadPadButton) {
        haptic()
        guard let face = FaceButton(rawValue: sender.tag) else { return }
        switch face {
        case .a: gasOn = true
        case .b: brakeOn = true
        case .x: handbrakeOn = true
        case .y: nitroOn = true
        }
        sender.setPressed(true)
        fire()
    }

    @objc private func faceUp(_ sender: DPadPadButton) {
        guard let face = FaceButton(rawValue: sender.tag) else { return }
        switch face {
        case .a: gasOn = false
        case .b: brakeOn = false
        case .x: handbrakeOn = false
        case .y: nitroOn = false
        }
        sender.setPressed(false)
        fire()
    }

    private func fire() {
        coordinator?.sync(
            gas: gasOn,
            brake: brakeOn,
            nitro: nitroOn,
            left: leftOn,
            right: rightOn,
            handbrake: handbrakeOn,
            reverse: reverseOn
        )
    }

    private func haptic() {
        if KRCAudioPreferences.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
        }
        KRCUISounds.playClick()
    }
}

// MARK: - Pad / face button chrome

private final class DPadPadButton: UIControl {
    private let accent: UIColor
    private let symbolView = UIImageView()
    private let captionLabel = UILabel()
    private var pressed = false

    init(symbol: String, caption: String?, accent: UIColor, isDirectional: Bool) {
        self.accent = accent
        super.init(frame: .zero)
        isExclusiveTouch = false
        layer.cornerRadius = isDirectional ? 12 : 14
        layer.cornerCurve = .continuous
        backgroundColor = UIColor(white: 0.08, alpha: 0.82)
        layer.borderWidth = 2
        layer.borderColor = accent.withAlphaComponent(0.55).cgColor

        let cfg = UIImage.SymbolConfiguration(pointSize: isDirectional ? 18 : 20, weight: .bold)
        symbolView.image = UIImage(systemName: symbol, withConfiguration: cfg)
        symbolView.tintColor = .white
        symbolView.contentMode = .scaleAspectFit
        symbolView.isUserInteractionEnabled = false
        addSubview(symbolView)

        if let caption {
            captionLabel.text = caption
            captionLabel.font = .monospacedSystemFont(ofSize: 7, weight: .heavy)
            captionLabel.textAlignment = .center
            captionLabel.textColor = UIColor.white.withAlphaComponent(0.75)
            captionLabel.isUserInteractionEnabled = false
            addSubview(captionLabel)
        }

        layer.shadowColor = accent.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setPressed(_ on: Bool) {
        pressed = on
        backgroundColor = on
            ? accent.withAlphaComponent(0.42)
            : UIColor(white: 0.08, alpha: 0.82)
        layer.borderColor = (on ? accent : accent.withAlphaComponent(0.55)).cgColor
        transform = on ? CGAffineTransform(scaleX: 0.94, y: 0.94) : .identity
        layer.shadowOpacity = on ? 0.65 : 0.35
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if captionLabel.superview != nil {
            symbolView.frame = CGRect(x: bounds.width * 0.2, y: bounds.height * 0.12, width: bounds.width * 0.6, height: bounds.height * 0.48)
            captionLabel.frame = CGRect(x: 0, y: bounds.height * 0.58, width: bounds.width, height: bounds.height * 0.32)
        } else {
            let s = min(bounds.width, bounds.height) * 0.52
            symbolView.frame = CGRect(x: (bounds.width - s) / 2, y: (bounds.height - s) / 2, width: s, height: s)
        }
    }
}
