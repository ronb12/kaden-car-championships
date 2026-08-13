import SwiftUI
import UIKit

/// Touch control layout — portrait mirrors web corner anchors; landscape uses a bottom bar.
enum RaceControlLayout {
    case landscape
    case portrait
}

/// Reliable **multi-touch** pedals — SwiftUI `DragGesture` pads often fail when holding GO + N2O together.
struct RacePedalCluster: UIViewRepresentable {
    var input: RaceInput
    var tiltSteer: Bool
    var layout: RaceControlLayout = .landscape

    func makeCoordinator() -> Coordinator {
        Coordinator(input: input)
    }

    func makeUIView(context: Context) -> PedalContainerView {
        let v = PedalContainerView()
        v.coordinator = context.coordinator
        v.tiltSteer = tiltSteer
        v.layoutMode = layout
        return v
    }

    func updateUIView(_ uiView: PedalContainerView, context: Context) {
        uiView.tiltSteer = tiltSteer
        uiView.layoutMode = layout
        context.coordinator.input = input
        uiView.coordinator = context.coordinator
    }

    final class Coordinator {
        var input: RaceInput
        init(input: RaceInput) {
            self.input = input
        }

        func sync(
            gas: Bool,
            brake: Bool,
            nitro: Bool,
            left: Bool,
            right: Bool,
            handbrake: Bool = false,
            reverse: Bool = false,
            throttle: Float = 0,
            brakeAmount: Float = 0
        ) {
            let apply = { [input] in
                input.gas = gas
                input.brake = brake
                input.nitro = nitro
                input.left = left
                input.right = right
                input.handbrake = handbrake
                input.reverse = reverse
                input.throttle = throttle
                input.brakeAmount = brakeAmount
                input.steer = 0
            }
            if Thread.isMainThread {
                apply()
            } else {
                DispatchQueue.main.async(execute: apply)
            }
        }
    }
}

// MARK: - Pedal kinds

private enum RacePedalTag: Int {
    case left = 1, brake, gas, nitro, right, handbrake, reverse
}

private enum RacePedalStyle {
    case steerLeft
    case steerRight
    case gas
    case brake
    case nitro
    case handbrake
    case reverse

    var symbolName: String {
        switch self {
        case .steerLeft: return "chevron.left"
        case .steerRight: return "chevron.right"
        case .gas: return "flame.fill"
        case .brake: return "stop.fill"
        case .nitro: return "bolt.fill"
        case .handbrake: return "p.circle.fill"
        case .reverse: return "arrow.uturn.down"
        }
    }

    var caption: String? {
        switch self {
        case .gas: return "GAS"
        case .brake: return "BRAKE"
        case .nitro: return "N2O"
        case .handbrake: return "E-BRAKE"
        case .reverse: return "REV"
        default: return nil
        }
    }

    var accent: UIColor {
        switch self {
        case .steerLeft, .steerRight:
            return UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        case .gas:
            return UIColor(red: 1, green: 0.55, blue: 0.1, alpha: 1)
        case .brake:
            return UIColor(red: 1, green: 0.28, blue: 0.22, alpha: 1)
        case .nitro:
            return UIColor(red: 0, green: 0.92, blue: 1, alpha: 1)
        case .handbrake:
            return UIColor(red: 0.92, green: 0.78, blue: 0.2, alpha: 1)
        case .reverse:
            return UIColor(red: 0.75, green: 0.55, blue: 1.0, alpha: 1)
        }
    }

    var fillTop: UIColor {
        switch self {
        case .steerLeft, .steerRight:
            return UIColor(red: 0.05, green: 0.14, blue: 0.28, alpha: 0.88)
        case .gas:
            return UIColor(red: 0.22, green: 0.08, blue: 0.02, alpha: 0.9)
        case .brake:
            return UIColor(red: 0.28, green: 0.04, blue: 0.04, alpha: 0.9)
        case .nitro:
            return UIColor(red: 0.02, green: 0.12, blue: 0.22, alpha: 0.9)
        case .handbrake:
            return UIColor(red: 0.22, green: 0.16, blue: 0.02, alpha: 0.9)
        case .reverse:
            return UIColor(red: 0.16, green: 0.08, blue: 0.28, alpha: 0.9)
        }
    }

    var fillBottom: UIColor {
        switch self {
        case .steerLeft, .steerRight:
            return UIColor(red: 0, green: 0.24, blue: 0.55, alpha: 0.78)
        case .gas:
            return UIColor(red: 0.55, green: 0.18, blue: 0.02, alpha: 0.82)
        case .brake:
            return UIColor(red: 0.55, green: 0.06, blue: 0.06, alpha: 0.82)
        case .nitro:
            return UIColor(red: 0, green: 0.35, blue: 0.62, alpha: 0.82)
        case .handbrake:
            return UIColor(red: 0.48, green: 0.34, blue: 0.04, alpha: 0.82)
        case .reverse:
            return UIColor(red: 0.4, green: 0.18, blue: 0.65, alpha: 0.82)
        }
    }

    var supportsAnalog: Bool {
        self == .gas || self == .brake
    }

    static func from(tag: RacePedalTag) -> RacePedalStyle {
        switch tag {
        case .left: return .steerLeft
        case .right: return .steerRight
        case .gas: return .gas
        case .brake: return .brake
        case .nitro: return .nitro
        case .handbrake: return .handbrake
        case .reverse: return .reverse
        }
    }
}

// MARK: - Container

final class PedalContainerView: UIView {

    var coordinator: RacePedalCluster.Coordinator?
    var tiltSteer = false {
        didSet { if oldValue != tiltSteer { rebuild() } }
    }
    var layoutMode: RaceControlLayout = .landscape {
        didSet { if oldValue != layoutMode { rebuild() } }
    }

    private var landscapeBar: UIView?
    private var landscapeLeftStack: UIStackView?
    private var landscapeRightStack: UIStackView?
    private var pedalButtons: [RacePedalTag: PedalButton] = [:]
    private var gasOn = false
    private var brakeOn = false
    private var nitroOn = false
    private var handbrakeOn = false
    private var reverseOn = false
    private var leftOn = false
    private var rightOn = false
    private var gasLevel: CGFloat = 0
    private var brakeLevel: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
        backgroundColor = .clear
        rebuild()
    }

    override var intrinsicContentSize: CGSize {
        layoutMode == .portrait
            ? CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
            : CGSize(width: UIView.noIntrinsicMetric, height: 92)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard layoutMode == .portrait else { return }
        layoutPortraitPedals()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        guard layoutMode == .portrait else { return }
        layoutPortraitPedals()
    }

    private func rebuild() {
        landscapeBar?.removeFromSuperview()
        landscapeBar = nil
        landscapeLeftStack = nil
        landscapeRightStack = nil
        pedalButtons.values.forEach { $0.removeFromSuperview() }
        pedalButtons.removeAll()
        gasOn = false
        brakeOn = false
        nitroOn = false
        handbrakeOn = false
        reverseOn = false
        leftOn = false
        rightOn = false
        gasLevel = 0
        brakeLevel = 0

        switch layoutMode {
        case .landscape:
            buildLandscapeBar()
        case .portrait:
            buildPortraitPedals()
        }
        alpha = ControlPreferences.controlOpacity
    }

    private func pedalSize(for layout: RaceControlLayout) -> CGFloat {
        let base: CGFloat = layout == .portrait ? 58 : 62
        return base * ControlPreferences.controlScale
    }

    private func buildLandscapeBar() {
        // Clear host only — no frosted dock plate / border (that read as an empty bottom box).
        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = .clear
        bar.isOpaque = false

        let leftStack = UIStackView()
        leftStack.axis = .horizontal
        leftStack.spacing = 10
        leftStack.alignment = .center
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        let rightStack = UIStackView()
        rightStack.axis = .horizontal
        rightStack.spacing = 10
        rightStack.alignment = .center
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        let actionTags: [RacePedalTag] = [.handbrake, .nitro, .gas, .brake, .reverse]
        if tiltSteer {
            for tag in actionTags {
                rightStack.addArrangedSubview(makePedal(tag))
            }
        } else {
            leftStack.addArrangedSubview(makePedal(.left))
            for tag in actionTags {
                rightStack.addArrangedSubview(makePedal(tag))
            }
            rightStack.addArrangedSubview(makePedal(.right))
        }

        bar.addSubview(leftStack)
        bar.addSubview(rightStack)
        addSubview(bar)

        let size = pedalSize(for: .landscape)
        var constraints: [NSLayoutConstraint] = [
            bar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            bar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -2),
            bar.heightAnchor.constraint(equalToConstant: 76),
            rightStack.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ]
        if tiltSteer {
            constraints.append(rightStack.centerXAnchor.constraint(equalTo: bar.centerXAnchor))
        } else {
            constraints += [
                leftStack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 6),
                leftStack.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
                rightStack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -6),
            ]
        }
        NSLayoutConstraint.activate(constraints)

        for stack in [leftStack, rightStack] {
            for case let btn as PedalButton in stack.arrangedSubviews {
                NSLayoutConstraint.activate([
                    btn.widthAnchor.constraint(equalToConstant: size),
                    btn.heightAnchor.constraint(equalToConstant: size),
                ])
            }
        }

        landscapeBar = bar
        landscapeLeftStack = leftStack
        landscapeRightStack = rightStack
    }

    private func buildPortraitPedals() {
        var tags: [RacePedalTag] = [.handbrake, .nitro, .gas, .brake, .reverse]
        if !tiltSteer {
            tags.insert(.left, at: 0)
            tags.append(.right)
        }
        for tag in tags {
            let btn = makePedal(tag)
            btn.translatesAutoresizingMaskIntoConstraints = true
            addSubview(btn)
            pedalButtons[tag] = btn
        }
        setNeedsLayout()
    }

    /// Portrait: steer cluster left, pedals right — size shrinks on narrow screens to prevent overlap.
    private func layoutPortraitPedals() {
        let marginL = max(8, safeAreaInsets.left + 4)
        let marginR = max(8, safeAreaInsets.right + 4)
        let bottomInset = safeAreaInsets.bottom
        let w = bounds.width
        let h = bounds.height
        let gap: CGFloat = 8
        let row: CGFloat = 2
        let centerGap: CGFloat = 18

        let maxSize = pedalSize(for: .portrait)
        let size: CGFloat
        if tiltSteer {
            let usable = w - marginL - marginR - gap * 4
            size = min(maxSize, floor(usable / 5))
        } else {
            let usable = w - marginL - marginR - centerGap - gap * 6
            size = min(maxSize, floor(usable / 7))
        }

        func place(_ tag: RacePedalTag, x: CGFloat) {
            guard let btn = pedalButtons[tag] else { return }
            let y = h - bottomInset - row - size
            btn.frame = CGRect(x: x, y: y, width: size, height: size)
        }

        if !tiltSteer {
            place(.left, x: marginL)
            place(.right, x: marginL + size + gap)
            let actionStart = w - marginR - (size * 5 + gap * 4)
            place(.handbrake, x: actionStart)
            place(.nitro, x: actionStart + size + gap)
            place(.gas, x: actionStart + (size + gap) * 2)
            place(.brake, x: actionStart + (size + gap) * 3)
            place(.reverse, x: actionStart + (size + gap) * 4)
        } else {
            let actionStart = w - marginR - (size * 5 + gap * 4)
            place(.handbrake, x: actionStart)
            place(.nitro, x: actionStart + size + gap)
            place(.gas, x: actionStart + (size + gap) * 2)
            place(.brake, x: actionStart + (size + gap) * 3)
            place(.reverse, x: actionStart + (size + gap) * 4)
        }
    }

    private func makePedal(_ tag: RacePedalTag) -> PedalButton {
        let style = RacePedalStyle.from(tag: tag)
        let b = PedalButton(style: style)
        b.pedalTag = tag
        b.isExclusiveTouch = false
        b.tag = tag.rawValue
        if style.supportsAnalog {
            b.onAnalogChange = { [weak self] level in
                self?.setAnalog(tag: tag, level: level)
            }
        }
        b.addTarget(self, action: #selector(btnDown(_:)), for: .touchDown)
        b.addTarget(self, action: #selector(btnUp(_:)), for: [.touchUpInside, .touchCancel, .touchUpOutside, .touchDragExit])
        return b
    }

    private func setAnalog(tag: RacePedalTag, level: CGFloat) {
        let clamped = max(0, min(1, level))
        switch tag {
        case .gas:
            gasLevel = max(clamped, gasOn ? 0.35 : 0)
            gasOn = gasLevel > 0.04
        case .brake:
            brakeLevel = max(clamped, brakeOn ? 0.35 : 0)
            brakeOn = brakeLevel > 0.04
        default:
            break
        }
        fire()
    }

    @objc private func btnDown(_ sender: PedalButton) {
        hapticPedal()
        setPedal(RacePedalTag(rawValue: sender.tag), on: true, button: sender)
    }

    @objc private func btnUp(_ sender: PedalButton) {
        setPedal(RacePedalTag(rawValue: sender.tag), on: false, button: sender)
    }

    private func setPedal(_ tag: RacePedalTag?, on: Bool, button: PedalButton) {
        guard let tag else { return }
        switch tag {
        case .left: leftOn = on
        case .brake:
            brakeOn = on
            brakeLevel = on ? max(brakeLevel, 1) : 0
        case .gas:
            gasOn = on
            gasLevel = on ? max(gasLevel, 1) : 0
        case .nitro: nitroOn = on
        case .handbrake: handbrakeOn = on
        case .reverse: reverseOn = on
        case .right: rightOn = on
        }
        button.setPressed(on)
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
            reverse: reverseOn,
            throttle: Float(gasOn ? max(gasLevel, 0.35) : 0),
            brakeAmount: Float(brakeOn ? max(brakeLevel, 0.35) : 0)
        )
    }

    private func hapticPedal() {
        if KRCAudioPreferences.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
        }
        KRCUISounds.playClick()
    }
}

// MARK: - Pedal button

private final class PedalButton: UIControl {

    var pedalTag: RacePedalTag?
    var onAnalogChange: ((CGFloat) -> Void)?

    private let style: RacePedalStyle
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let gradientLayer = CAGradientLayer()
    private let ringLayer = CAShapeLayer()
    private let symbolView = UIImageView()
    private let captionLabel = UILabel()
    private var pressed = false

    init(style: RacePedalStyle) {
        self.style = style
        super.init(frame: .zero)
        isExclusiveTouch = false
        setupChrome()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setPressed(_ on: Bool) {
        guard pressed != on else { return }
        pressed = on
        updateLook(animated: true)
    }

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted != pressed {
                pressed = isHighlighted
                updateLook(animated: false)
            }
        }
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let tracking = super.beginTracking(touch, with: event)
        if style.supportsAnalog { reportPressure(touch) }
        return tracking
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let tracking = super.continueTracking(touch, with: event)
        if style.supportsAnalog { reportPressure(touch) }
        return tracking
    }

    private func reportPressure(_ touch: UITouch) {
        let loc = touch.location(in: self)
        let raw = 1 - (loc.y / max(bounds.height, 1))
        let level = max(0.2, min(1, raw))
        onAnalogChange?(level)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = bounds.insetBy(dx: 2, dy: 2)
        blurView.frame = inset
        blurView.layer.cornerRadius = inset.width * 0.5
        gradientLayer.frame = inset
        gradientLayer.cornerRadius = inset.width * 0.5

        let ringRect = bounds.insetBy(dx: 1.5, dy: 1.5)
        ringLayer.path = UIBezierPath(ovalIn: ringRect).cgPath
        ringLayer.frame = bounds

        let symbolSize = style.caption == nil ? min(bounds.width, bounds.height) * 0.34 : min(bounds.width, bounds.height) * 0.26
        symbolView.frame = CGRect(
            x: (bounds.width - symbolSize) / 2,
            y: style.caption == nil ? (bounds.height - symbolSize) / 2 : bounds.height * 0.28,
            width: symbolSize,
            height: symbolSize
        )
        captionLabel.frame = CGRect(x: 0, y: bounds.height * 0.62, width: bounds.width, height: bounds.height * 0.28)
    }

    private func setupChrome() {
        layer.cornerCurve = .continuous
        clipsToBounds = false

        blurView.isUserInteractionEnabled = false
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        insertSubview(blurView, at: 0)

        gradientLayer.colors = [style.fillTop.cgColor, style.fillBottom.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.35, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.65, y: 1)
        gradientLayer.cornerCurve = .continuous
        layer.insertSublayer(gradientLayer, at: 0)

        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.lineWidth = 2.5
        ringLayer.strokeColor = style.accent.withAlphaComponent(0.85).cgColor
        layer.addSublayer(ringLayer)

        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        symbolView.image = UIImage(systemName: style.symbolName, withConfiguration: cfg)
        symbolView.tintColor = UIColor.white.withAlphaComponent(0.94)
        symbolView.contentMode = .scaleAspectFit
        symbolView.isUserInteractionEnabled = false
        addSubview(symbolView)

        if let caption = style.caption {
            captionLabel.text = caption
            captionLabel.font = .monospacedSystemFont(ofSize: 8, weight: .heavy)
            captionLabel.textAlignment = .center
            captionLabel.textColor = UIColor.white.withAlphaComponent(0.88)
            captionLabel.isUserInteractionEnabled = false
            addSubview(captionLabel)
        }

        layer.shadowColor = style.accent.cgColor
        layer.shadowOpacity = 0.38
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 5)

        updateLook(animated: false)
    }

    private func updateLook(animated: Bool) {
        let accent = style.accent
        let changes = {
            self.gradientLayer.colors = self.pressed
                ? [accent.withAlphaComponent(0.55).cgColor, accent.withAlphaComponent(0.32).cgColor]
                : [self.style.fillTop.cgColor, self.style.fillBottom.cgColor]
            self.ringLayer.strokeColor = (self.pressed ? accent : accent.withAlphaComponent(0.72)).cgColor
            self.ringLayer.lineWidth = self.pressed ? 2.5 : 2
            self.layer.shadowOpacity = self.pressed ? 0.72 : 0.28
            self.layer.shadowRadius = self.pressed ? 16 : 10
            self.transform = self.pressed
                ? CGAffineTransform(scaleX: 0.94, y: 0.94)
                : .identity
            self.symbolView.tintColor = self.pressed
                ? UIColor.white
                : UIColor.white.withAlphaComponent(0.94)
        }
        if animated {
            UIView.animate(withDuration: 0.1, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: changes)
        } else {
            changes()
        }
    }
}
