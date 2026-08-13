import SwiftUI

/// Cinematic intro shown once at cold start before the main menu.
struct SplashScreenView: View {
    var onFinished: () -> Void

    @State private var titleScale: CGFloat = 2.5
    @State private var titleOpacity: Double = 0
    @State private var titleBlur: CGFloat = 18
    @State private var seasonOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.12
    @State private var ringOpacity: Double = 0
    @State private var progress: CGFloat = 0
    @State private var screenOpacity: Double = 1
    @State private var didFinish = false

    var body: some View {
        ZStack {
            KRCDesign.MenuBackdrop()
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    KRCDesign.hotOrange.opacity(0.28),
                    KRCDesign.neonCyan.opacity(0.12),
                    .clear,
                ],
                center: .center,
                startRadius: 40,
                endRadius: 340
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                KRCDesign.MenuHeroTitle(
                    flameIntensity: 0.95,
                    titleScale: titleScale,
                    titleOpacity: titleOpacity,
                    titleBlur: titleBlur,
                    seasonOpacity: seasonOpacity,
                    ringScale: ringScale,
                    ringOpacity: ringOpacity
                )
                .padding(.horizontal, 12)

                Spacer(minLength: 24)

                VStack(spacing: 16) {
                    Text("TAP TO SKIP")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2.4)
                        .foregroundStyle(Color.white.opacity(0.42))
                        .opacity(seasonOpacity)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [KRCDesign.gold, KRCDesign.hotOrange, KRCDesign.neonCyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(12, geo.size.width * progress))
                                .shadow(color: KRCDesign.hotOrange.opacity(0.55), radius: 8)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 52)
                }
                .padding(.bottom, max(44, 28))
            }
        }
        .opacity(screenOpacity)
        .contentShape(Rectangle())
        .onTapGesture { finishSplash() }
        .onAppear { runIntro() }
        .accessibilityIdentifier("splash.screen")
    }

    private func runIntro() {
        withAnimation(.easeOut(duration: 0.5)) {
            ringScale = 2.4
            ringOpacity = 0.9
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.08)) {
            ringOpacity = 0
        }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.58)) {
            titleScale = 1
            titleOpacity = 1
            titleBlur = 0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            seasonOpacity = 1
        }
        withAnimation(.easeInOut(duration: 2.15)) {
            progress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.35) {
            finishSplash()
        }
    }

    private func finishSplash() {
        guard !didFinish else { return }
        didFinish = true
        withAnimation(.easeOut(duration: 0.32)) {
            screenOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            onFinished()
        }
    }
}

/// Root wrapper: optional splash, then main game UI.
struct AppRootView: View {
    @EnvironmentObject private var progress: PlayerProgressStore
    @State private var showSplash = true

    var body: some View {
        ZStack {
            NativeRootView()
                .environmentObject(progress)

            if showSplash && shouldShowSplash {
                SplashScreenView {
                    showSplash = false
                }
                .transition(.opacity)
                .zIndex(50)
            }
        }
    }

    private var shouldShowSplash: Bool {
        #if DEBUG
        if KRCDebugUI.isQALaunch { return false }
        #endif
        return true
    }
}
