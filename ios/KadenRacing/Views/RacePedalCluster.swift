import SwiftUI
import UIKit

/// Reliable **multi-touch** pedals — SwiftUI `DragGesture` pads often fail when holding GO + N2O together.
struct RacePedalCluster: UIViewRepresentable {
    var input: RaceInput
    var tiltSteer: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(input: input)
    }

    func makeUIView(context: Context) -> PedalContainerView {
        let v = PedalContainerView()
        v.coordinator = context.coordinator
        v.tiltSteer = tiltSteer
        return v
    }

    func updateUIView(_ uiView: PedalContainerView, context: Context) {
        uiView.tiltSteer = tiltSteer
        context.coordinator.input = input
        uiView.coordinator = context.coordinator
    }

    final class Coordinator {
        var input: RaceInput
        init(input: RaceInput) {
            self.input = input
        }

        func sync(gas: Bool, brake: Bool, nitro: Bool, left: Bool, right: Bool) {
            let apply = { [input] in
                input.gas = gas
                input.brake = brake
                input.nitro = nitro
                input.left = left
                input.right = right
            }
            // Prefer synchronous updates on main so SceneKit reads gas in the same run-loop
            // tick as UIKit touchDown (async previously deferred past physics → dead throttle).
            if Thread.isMainThread {
                apply()
            } else {
                DispatchQueue.main.async(execute: apply)
            }
        }
    }
}

final class PedalContainerView: UIView {

    private enum PedalTag: Int {
        case left = 1, brake, gas, nitro, right
    }

    var coordinator: RacePedalCluster.Coordinator?
    var tiltSteer = false {
        didSet { rebuild() }
    }

    private var stack: UIStackView?
    private var gasOn = false
    private var brakeOn = false
    private var nitroOn = false
    private var leftOn = false
    private var rightOn = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
        backgroundColor = .clear
        rebuild()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 70)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func rebuild() {
        stack?.removeFromSuperview()
        gasOn = false
        brakeOn = false
        nitroOn = false
        leftOn = false
        rightOn = false

        let h = UIStackView()
        h.axis = .horizontal
        h.spacing = 10
        h.distribution = .fillEqually
        h.translatesAutoresizingMaskIntoConstraints = false

        if !tiltSteer {
            h.addArrangedSubview(makeBtn("◀", tag: .left))
        }
        h.addArrangedSubview(makeBtn("BRK", tag: .brake))
        h.addArrangedSubview(makeBtn("GO", tag: .gas))
        h.addArrangedSubview(makeBtn("N2O", tag: .nitro))
        if !tiltSteer {
            h.addArrangedSubview(makeBtn("▶", tag: .right))
        }

        addSubview(h)
        NSLayoutConstraint.activate([
            h.leadingAnchor.constraint(equalTo: leadingAnchor),
            h.trailingAnchor.constraint(equalTo: trailingAnchor),
            h.topAnchor.constraint(equalTo: topAnchor),
            h.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        stack = h
    }

    private func makeBtn(_ title: String, tag: PedalTag) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        b.layer.cornerRadius = 12
        b.isExclusiveTouch = false
        b.isUserInteractionEnabled = true
        b.tag = tag.rawValue
        b.addTarget(self, action: #selector(btnDown(_:)), for: .touchDown)
        b.addTarget(self, action: #selector(btnUp(_:)), for: [.touchUpInside, .touchCancel, .touchUpOutside, .touchDragExit])
        return b
    }

    @objc private func btnDown(_ sender: UIButton) {
        setPedal(PedalTag(rawValue: sender.tag), on: true)
    }

    @objc private func btnUp(_ sender: UIButton) {
        setPedal(PedalTag(rawValue: sender.tag), on: false)
    }

    private func setPedal(_ tag: PedalTag?, on: Bool) {
        guard let tag else { return }
        switch tag {
        case .left: leftOn = on
        case .brake: brakeOn = on
        case .gas: gasOn = on
        case .nitro: nitroOn = on
        case .right: rightOn = on
        }
        fire()
    }

    private func fire() {
        coordinator?.sync(gas: gasOn, brake: brakeOn, nitro: nitroOn, left: leftOn, right: rightOn)
    }
}
