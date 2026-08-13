import SwiftUI

/// Shared arcade UI tokens (web garage / main menu parity).
enum KRCDesign {
    static let gold = Color(red: 1, green: 0.8, blue: 0)
    static let hotOrange = Color(red: 1, green: 0.4, blue: 0)
    static let neonCyan = Color(red: 0, green: 0.83, blue: 1)
    static let subtitleGold = Color(red: 0.91, green: 0.75, blue: 0.5)
    static let panelFill = Color.white.opacity(0.06)
    static let panelStroke = Color.orange.opacity(0.55)
    static let mutedText = Color.white.opacity(0.58)
    static let cardFill = Color.black.opacity(0.42)

    // MARK: - Background

    struct MenuBackdrop: View {
        @State private var offsetX: CGFloat = 0
        @State private var offsetY: CGFloat = 0
        @State private var auroraPhase: CGFloat = 0
        @State private var scanY: CGFloat = -0.35

        var body: some View {
            ZStack {
                Color(red: 0.02, green: 0, blue: 0.01)
                    .ignoresSafeArea()

                GeometryReader { geo in
                    Image("MenuBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width * 1.14, height: geo.size.height * 1.14)
                        .offset(x: offsetX, y: offsetY)
                        .saturation(1.12)
                        .contrast(1.08)
                        .brightness(0.88)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                                offsetX = -geo.size.width * 0.07
                                offsetY = -geo.size.height * 0.04
                            }
                            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                                auroraPhase = 1
                            }
                            withAnimation(.linear(duration: 5.5).repeatForever(autoreverses: false)) {
                                scanY = 1.35
                            }
                        }
                }
                .ignoresSafeArea()
                .clipped()

                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0, blue: 0).opacity(0.25),
                        Color.black.opacity(0.55),
                        Color.black.opacity(0.82),
                        Color.black.opacity(0.94),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color(red: 1, green: 0.35, blue: 0).opacity(0.38),
                        Color(red: 0, green: 0.75, blue: 1).opacity(0.22),
                        .clear,
                    ],
                    center: UnitPoint(x: 0.5 + auroraPhase * 0.04, y: 0.72),
                    startRadius: 20,
                    endRadius: 420
                )
                .ignoresSafeArea()
                .blur(radius: 18)
                .allowsHitTesting(false)

                MenuSpeedLines()
                    .ignoresSafeArea()
                    .opacity(0.55)

                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, neonCyan.opacity(0.14), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.42)
                    .offset(y: geo.size.height * scanY - geo.size.height * 0.2)
                    .blur(radius: 6)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.35), Color.black.opacity(0.78)],
                    center: .center,
                    startRadius: 80,
                    endRadius: 520
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
    }

    /// Diagonal racing streaks behind menu / splash content.
    struct MenuSpeedLines: View {
        @State private var shift: CGFloat = 0

        var body: some View {
            GeometryReader { geo in
                Canvas { context, size in
                    let spacing: CGFloat = 56
                    let offset = shift * spacing
                    for i in -3..<Int(size.width / spacing) + 4 {
                        let x = CGFloat(i) * spacing + offset
                        var path = Path()
                        path.move(to: CGPoint(x: x - 40, y: size.height + 20))
                        path.addLine(to: CGPoint(x: x + size.width * 0.55, y: -20))
                        context.stroke(
                            path,
                            with: .color(Color.white.opacity(0.06)),
                            lineWidth: 1.2
                        )
                        var hot = Path()
                        hot.move(to: CGPoint(x: x - 38, y: size.height + 18))
                        hot.addLine(to: CGPoint(x: x + size.width * 0.52, y: -18))
                        context.stroke(
                            hot,
                            with: .color(hotOrange.opacity(0.12)),
                            lineWidth: 0.8
                        )
                    }
                }
                .onAppear {
                    withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                        shift = 1
                    }
                }
            }
        }
    }

    /// Shared hero title + flames (main menu + splash).
    struct MenuHeroTitle: View {
        var flameIntensity: CGFloat = 0.55
        var showFlag = true
        var titleScale: CGFloat = 1
        var titleOpacity: Double = 1
        var titleBlur: CGFloat = 0
        var seasonOpacity: Double = 1
        var ringScale: CGFloat = 0.2
        var ringOpacity: Double = 0
        var breatheFlames = true

        var body: some View {
            VStack(spacing: 6) {
                if showFlag {
                    Text("🏁")
                        .font(.system(size: 46))
                        .opacity(titleOpacity)
                        .shadow(color: hotOrange.opacity(0.35), radius: 10, y: 4)
                }

                ZStack {
                    SplashFlameView(intensity: flameIntensity)
                        .frame(height: 158)
                        .frame(maxWidth: min(540, UIScreen.main.bounds.width * 0.96))
                        .offset(y: 28)
                        .allowsHitTesting(false)

                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [gold, hotOrange, neonCyan.opacity(0.85), gold],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 210, height: 210)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                        .blur(radius: 0.5)

                    VStack(spacing: 4) {
                        Text("Kaden's")
                            .font(.system(size: 42, weight: .heavy))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, gold, hotOrange.opacity(0.95)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: hotOrange.opacity(0.5), radius: 10, y: 4)
                            .shadow(color: Color.black.opacity(0.45), radius: 2, y: 1)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text("RACING CHAMPIONSHIPS")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .kerning(2.2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white.opacity(0.95), gold.opacity(0.92)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.72)
                            .lineLimit(2)

                        Text("SEASON ONE")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(3)
                            .foregroundStyle(neonCyan.opacity(0.9))
                            .shadow(color: neonCyan.opacity(0.45), radius: 8)
                            .opacity(seasonOpacity)
                            .padding(.top, 6)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, gold, hotOrange, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: min(280, UIScreen.main.bounds.width * 0.62), height: 2)
                            .shadow(color: hotOrange.opacity(0.65), radius: 10)
                            .padding(.top, 4)
                            .opacity(seasonOpacity)
                    }
                    .scaleEffect(titleScale)
                    .opacity(titleOpacity)
                    .blur(radius: titleBlur)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Kaden Racing Championships")
                }
                .frame(height: 196)
                .modifier(MenuFlameBreathe(enabled: breatheFlames))
            }
        }
    }

    private struct MenuFlameBreathe: ViewModifier {
        let enabled: Bool
        @State private var offset: CGFloat = 0
        @State private var scale: CGFloat = 1

        func body(content: Content) -> some View {
            content
                .offset(y: offset)
                .scaleEffect(x: 1, y: scale, anchor: .bottom)
                .onAppear {
                    guard enabled else { return }
                    withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                        offset = 5
                        scale = 1.05
                    }
                }
        }
    }

    /// Frosted HUD strip for in-race overlays.
    struct RaceHUDPanel<Content: View>: View {
        var compact = false
        @ViewBuilder var content: Content

        var body: some View {
            content
                .padding(compact ? 6 : 12)
                .background {
                    RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            neonCyan.opacity(0.55),
                                            hotOrange.opacity(0.35),
                                            Color.white.opacity(0.12),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.45), radius: 12, y: 4)
                }
        }
    }

    // MARK: - In-race scoreboard

    struct RaceScoreboardStrip: View {
        let portrait: Bool
        let venue: String
        let mode: String
        let speedKmh: Int
        let lap: Int
        let lapGoal: Int
        let raceTime: String
        let position: Int
        let racerCount: Int
        let showPosition: Bool
        let nitro: Float
        let heat: Float
        let showHeat: Bool
        let driftMultiplier: Float
        let driftScore: Int64
        @ViewBuilder var pauseControl: () -> AnyView

        init(
            portrait: Bool,
            venue: String,
            mode: String,
            speedKmh: Int,
            lap: Int,
            lapGoal: Int,
            raceTime: String,
            position: Int,
            racerCount: Int,
            showPosition: Bool,
            nitro: Float,
            heat: Float,
            showHeat: Bool,
            driftMultiplier: Float,
            driftScore: Int64,
            @ViewBuilder pauseControl: @escaping () -> some View
        ) {
            self.portrait = portrait
            self.venue = venue
            self.mode = mode
            self.speedKmh = speedKmh
            self.lap = lap
            self.lapGoal = lapGoal
            self.raceTime = raceTime
            self.position = position
            self.racerCount = racerCount
            self.showPosition = showPosition
            self.nitro = nitro
            self.heat = heat
            self.showHeat = showHeat
            self.driftMultiplier = driftMultiplier
            self.driftScore = driftScore
            self.pauseControl = { AnyView(pauseControl()) }
        }

        var body: some View {
            if portrait {
                portraitLayout
            } else {
                landscapeLayout
            }
        }

        private var landscapeLayout: some View {
            HStack(alignment: .center, spacing: 8) {
                RaceHUDPanel(compact: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        headerRow
                        bottomRow
                    }
                    .frame(maxWidth: 300, alignment: .leading)
                }
                Spacer(minLength: 0)
                pauseControl()
            }
        }

        private var portraitLayout: some View {
            RaceHUDPanel(compact: true) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 6) {
                        if showPosition {
                            positionBadge(compact: true)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(venue)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.92))
                                .lineLimit(1)
                            Text(mode.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(hotOrange.opacity(0.95))
                        }
                        Spacer(minLength: 2)
                        speedPill(size: 22)
                        pauseControl()
                    }
                    bottomRow
                }
            }
        }

        /// Lap / time / drift + nitro (and heat) on one tight row.
        private var bottomRow: some View {
            HStack(alignment: .center, spacing: 6) {
                statChip("LAP", "\(lap)/\(lapGoal)")
                statChip("TIME", raceTime)
                statChip("DRF", "×\(String(format: "%.1f", driftMultiplier))")
                compactMeterRow
            }
        }

        private var compactMeterRow: some View {
            HStack(spacing: 6) {
                RaceMeterBar(label: "N2O", value: nitro, tint: neonCyan, compact: true)
                if showHeat {
                    RaceMeterBar(label: "HEAT", value: heat, tint: .red, compact: true)
                }
            }
            .frame(maxWidth: portrait ? 120 : 140)
        }

        private var headerRow: some View {
            HStack(alignment: .center, spacing: 6) {
                if showPosition {
                    positionBadge(compact: true)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(venue)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                    Text(mode.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(hotOrange.opacity(0.95))
                }
                Spacer(minLength: 2)
                speedPill(size: 24)
            }
        }

        private func positionBadge(compact: Bool) -> some View {
            let rankColor: Color = position == 1 ? gold : (position <= 3 ? neonCyan : mutedText)
            return HStack(spacing: 3) {
                Text("P")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(mutedText)
                Text("\(position)")
                    .font(.system(size: compact ? 18 : 20, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(rankColor)
                if racerCount > 1 {
                    Text("/\(racerCount)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(mutedText)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(rankColor.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(rankColor.opacity(0.45), lineWidth: 1)
                    )
            }
        }

        private func speedPill(size: CGFloat) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(speedKmh)")
                    .font(.system(size: size, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [gold, hotOrange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("km/h")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }

        private func statChip(_ label: String, _ value: String) -> some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 7, weight: .heavy, design: .monospaced))
                    .foregroundStyle(mutedText)
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            }
        }
    }

    struct RaceMeterBar: View {
        let label: String
        let value: Float
        let tint: Color
        var compact = false

        var body: some View {
            VStack(alignment: .leading, spacing: compact ? 1 : 3) {
                Text(label)
                    .font(.system(size: compact ? 7 : 10, weight: .bold))
                    .foregroundStyle(tint.opacity(0.95))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.85), tint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: tint.opacity(compact ? 0.25 : 0.45), radius: compact ? 2 : 4)
                            .frame(width: g.size.width * CGFloat(min(1, max(0, value))))
                    }
                }
                .frame(height: compact ? 4 : 7)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Typography

    struct ScreenTitle: View {
        let text: String
        var body: some View {
            Text(text)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(neonCyan)
                .shadow(color: neonCyan.opacity(0.45), radius: 12)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    struct SectionLabel: View {
        let text: String
        var body: some View {
            Text(text)
                .font(.caption2.weight(.bold))
                .foregroundStyle(subtitleGold.opacity(0.95))
        }
    }

    // MARK: - Controls

    struct PrimaryButton: View {
        let title: String
        var enabled: Bool = true
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .kerning(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                enabled
                                    ? LinearGradient(
                                        colors: [
                                            hotOrange.opacity(0.38),
                                            Color(red: 0.55, green: 0.22, blue: 0.05, opacity: 0.85),
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    : LinearGradient(
                                        colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.28)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        enabled ? gold.opacity(0.75) : Color.gray.opacity(0.35),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: enabled ? gold.opacity(0.22) : .clear, radius: 10, y: 3)
                    }
                    .foregroundStyle(enabled ? Color.white : Color.white.opacity(0.45))
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
        }
    }

    struct MenuPillButton: View {
        let title: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .frame(maxWidth: 320)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.orange.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.orange.opacity(0.85), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(gold)
            }
            .buttonStyle(.plain)
        }
    }

    struct DifficultyChips: View {
        @Binding var index: Int

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "OPPONENT SKILL")
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { idx in
                        let labels = ["CASUAL", "PRO", "ELITE"]
                        let on = index == idx
                        Button(labels[idx]) {
                            index = idx
                        }
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(on ? Color.orange : panelFill)
                        )
                        .foregroundStyle(on ? Color.black : Color.white.opacity(0.85))
                    }
                }
            }
        }
    }

    struct Panel<Content: View>: View {
        @ViewBuilder var content: Content

        var body: some View {
            content
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(panelFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.cyan.opacity(0.28), lineWidth: 1)
                        )
                )
        }
    }

    /// Credits + optional trailing pill (track count, etc.).
    struct CreditsChip: View {
        let credits: Int64
        var trailing: String? = nil

        var body: some View {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("KR")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(gold))
                    Text("\(credits)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.92))
                }
                if let trailing {
                    Text(trailing)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().strokeBorder(gold.opacity(0.45), lineWidth: 1))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.45)))
            .overlay(Capsule().strokeBorder(gold.opacity(0.3), lineWidth: 1))
        }
    }

    /// Consistent back + credits row used on garage, track pick, mode select.
    struct ArcadeTopBar: View {
        let backTitle: String
        let backAction: () -> Void
        var credits: Int64? = nil
        var trailing: String? = nil

        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                Button(action: backAction) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.bold))
                        Text(backTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.35))
                            .overlay(Capsule().strokeBorder(gold.opacity(0.35), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                if let credits {
                    CreditsChip(credits: credits, trailing: trailing)
                } else if let trailing {
                    Text(trailing)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.4)))
                        .overlay(Capsule().strokeBorder(gold.opacity(0.4), lineWidth: 1))
                }
            }
        }
    }

    struct ScreenHeader: View {
        let title: String
        var subtitle: String? = nil

        var body: some View {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(neonCyan)
                    .shadow(color: neonCyan.opacity(0.35), radius: 10)
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(subtitleGold)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    struct ListRow: View {
        let icon: String
        let title: String
        let subtitle: String
        var accent: Color = neonCyan

        var body: some View {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent.opacity(0.65))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(accent.opacity(0.22), lineWidth: 1)
                    )
            )
        }
    }

    struct SecondaryButton: View {
        let title: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .kerning(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.42))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(neonCyan.opacity(0.55), lineWidth: 1)
                            )
                    }
                    .foregroundStyle(neonCyan)
            }
            .buttonStyle(.plain)
        }
    }

    struct HighlightStatCard: View {
        let label: String
        let value: String
        var accent: Color = gold

        var body: some View {
            VStack(spacing: 8) {
                SectionLabel(text: label)
                Text(value)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 14)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.48))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [accent.opacity(0.75), neonCyan.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: accent.opacity(0.18), radius: 12, y: 4)
            }
        }
    }

    struct PauseMenuOverlay: View {
        let onResume: () -> Void
        let onMainMenu: () -> Void
        var onFlashback: (() -> Void)? = nil
        var flashbackAvailable: Bool = false

        var body: some View {
            ZStack {
                Color.black.opacity(0.62).ignoresSafeArea()
                VStack(spacing: 18) {
                    Text("PAUSED")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(neonCyan)
                        .shadow(color: neonCyan.opacity(0.35), radius: 10)
                    if KRCPlayerProfile.onlinePlayEnabled {
                        Text("No voice chat · WAVE or NICE to say hi")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(mutedText)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: 10) {
                        PrimaryButton(title: "RESUME", action: onResume)
                            .accessibilityIdentifier("race.pause.resume")
                        if let onFlashback {
                            SecondaryButton(
                                title: flashbackAvailable ? "FLASHBACK (−2.5s)" : "FLASHBACK (EMPTY)",
                                action: onFlashback
                            )
                            .opacity(flashbackAvailable ? 1 : 0.45)
                            .disabled(!flashbackAvailable)
                            .accessibilityIdentifier("race.pause.flashback")
                        }
                        SecondaryButton(title: "MAIN MENU", action: onMainMenu)
                            .accessibilityIdentifier("race.pause.main_menu")
                    }
                }
                .padding(22)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [neonCyan.opacity(0.5), gold.opacity(0.35)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 24, y: 8)
                }
                .padding(.horizontal, 28)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Race paused")
        }
    }

    struct ModeBadge: View {
        let text: String
        var accent: Color = hotOrange

        var body: some View {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .kerning(1)
                .foregroundStyle(accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(accent.opacity(0.14))
                        .overlay(Capsule().strokeBorder(accent.opacity(0.45), lineWidth: 1))
                }
        }
    }

    struct SettingsGroup<Content: View>: View {
        let title: String
        @ViewBuilder var content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: title)
                VStack(spacing: 0) {
                    content
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.cyan.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }

    struct SettingsRow: View {
        var label: String
        var value: String? = nil
        var destructive = false

        var body: some View {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(destructive ? Color.red.opacity(0.9) : .white)
                Spacer()
                if let value {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(mutedText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

/// Standard full-screen layout: menu backdrop + scroll + optional pinned footer CTA.
struct KRCArcadeScreen<Content: View, Footer: View>: View {
    var title: String?
    var subtitle: String? = nil
  @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.footer = footer
    }

    var body: some View {
        ZStack {
            KRCDesign.MenuBackdrop()
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        if let title {
                            KRCDesign.ScreenHeader(title: title, subtitle: subtitle)
                        }
                        content()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 96)
                }
                footer()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0), Color.black.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                    )
            }
        }
    }
}

extension KRCArcadeScreen where Footer == EmptyView {
    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.footer = { EmptyView() }
    }
}
