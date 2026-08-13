import SwiftUI

struct NativeSettingsView: View {
    @EnvironmentObject private var progress: PlayerProgressStore
    @Environment(\.openURL) private var openURL
    @ObservedObject private var online = KRCOnlineService.shared
    var onDismiss: () -> Void
    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var showDeleteConfirm = false
    @State private var resetConfirm = false
    @State private var deleteStatus = ""
    @State private var isDeletingAccount = false
    @State private var gamerName: String = KRCPlayerProfile.gamerName
    @State private var onlineEnabled: Bool = KRCPlayerProfile.onlinePlayEnabled
    @State private var musicVolume: Float = KRCAudioPreferences.musicVolume
    @State private var musicMuted: Bool = KRCAudioPreferences.musicMuted
    @State private var sfxVolume: Float = KRCAudioPreferences.sfxVolume
    @State private var sfxMuted: Bool = KRCAudioPreferences.sfxMuted
    @State private var hapticsEnabled: Bool = KRCAudioPreferences.hapticsEnabled
    @State private var controlScheme: ControlScheme = ControlPreferences.scheme
    @State private var controlScale: Float = Float(ControlPreferences.controlScale)
    @State private var controlOpacity: Float = Float(ControlPreferences.controlOpacity)
    @State private var steerSensitivity: Float = ControlPreferences.steerSensitivity
    @State private var transmissionMode: TransmissionMode = VehicleDrivingPreferences.transmissionMode
    @State private var manualControl: Bool = VehicleDrivingPreferences.manualControl
    @State private var steeringAssist: Float = VehicleDrivingPreferences.storedSteeringAssist
    @State private var driftAssist: Float = VehicleDrivingPreferences.storedDriftAssist
    @State private var brakeAssist: Float = VehicleDrivingPreferences.storedBrakeAssist
    @State private var tractionControl: Float = VehicleDrivingPreferences.storedTractionControl
    @State private var graphicsQuality: GraphicsQuality = EnvironmentGraphicsSettings.quality

    var body: some View {
        NavigationView {
            ZStack {
                KRCDesign.MenuBackdrop()
                Color.black.opacity(0.55).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Spacer()
                            Button("Done") {
                                commitGamerName()
                                onDismiss()
                            }
                            .font(.headline.weight(.bold))
                            .foregroundStyle(KRCDesign.gold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.4))
                                    .overlay(Capsule().strokeBorder(KRCDesign.gold.opacity(0.4), lineWidth: 1))
                            )
                        }
                        KRCDesign.ScreenHeader(title: "SETTINGS", subtitle: "Controls & account")
                        KRCDesign.SettingsGroup(title: "GLOBAL ONLINE") {
                            Toggle(isOn: $onlineEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Play online globally")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white)
                                    Text(online.statusLine)
                                        .font(.system(.caption, design: .monospaced).weight(.medium))
                                        .foregroundStyle(KRCDesign.mutedText)
                                }
                            }
                            .tint(KRCDesign.hotOrange)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .onChange(of: onlineEnabled) { newValue in
                                KRCPlayerProfile.onlinePlayEnabled = newValue
                                if newValue {
                                    Task {
                                        await KRCOnlineService.shared.refreshGlobalSummary()
                                        await KRCOnlineService.shared.refreshLeaderboard()
                                    }
                                }
                            }
                            if onlineEnabled {
                                GlobalLeaderboardView()
                                    .padding(.horizontal, 10)
                                    .padding(.bottom, 10)
                            }
                            Divider().overlay(Color.white.opacity(0.08))
                            VStack(alignment: .leading, spacing: 6) {
                                KRCDesign.SectionLabel(text: "GAMER NAME")
                                TextField("Nickname", text: $gamerName)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black.opacity(0.35))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(KRCDesign.neonCyan.opacity(0.35), lineWidth: 1)
                                            )
                                    )
                                    .onSubmit { commitGamerName() }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                        KRCDesign.SettingsGroup(title: "GAME CENTER") {
                            GameCenterSettingsSection()
                        }
                        KRCDesign.SettingsGroup(title: "AUDIO") {
                            audioSlider("Music", value: $musicVolume)
                                .onChange(of: musicVolume) { v in
                                    KRCAudioPreferences.musicVolume = v
                                    Task { @MainActor in KRCMusicDirector.shared.applyVolumeFromSettings() }
                                }
                            Toggle("Mute music", isOn: $musicMuted)
                                .tint(KRCDesign.neonCyan)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .onChange(of: musicMuted) { v in
                                    KRCAudioPreferences.musicMuted = v
                                    Task { @MainActor in KRCMusicDirector.shared.applyVolumeFromSettings() }
                                }
                            audioSlider("SFX", value: $sfxVolume)
                                .onChange(of: sfxVolume) { v in
                                    KRCAudioPreferences.sfxVolume = v
                                }
                            Toggle("Mute SFX", isOn: $sfxMuted)
                                .tint(KRCDesign.neonCyan)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .onChange(of: sfxMuted) { v in
                                    KRCAudioPreferences.sfxMuted = v
                                }
                            Toggle("Haptics", isOn: $hapticsEnabled)
                                .tint(KRCDesign.hotOrange)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .onChange(of: hapticsEnabled) { v in
                                    KRCAudioPreferences.hapticsEnabled = v
                                }
                        }
                        KRCDesign.SettingsGroup(title: "DRIVING") {
                            Picker("Steering", selection: $controlScheme) {
                                ForEach(ControlScheme.allCases) { scheme in
                                    Text(scheme.label).tag(scheme)
                                }
                            }
                            .pickerStyle(.inline)
                            .tint(KRCDesign.neonCyan)
                            .padding(.horizontal, 6)
                            .onChange(of: controlScheme) { v in
                                ControlPreferences.scheme = v
                            }
                            audioSlider("Control size", value: $controlScale, range: 0.85...1.2)
                                .onChange(of: controlScale) { v in
                                    ControlPreferences.controlScale = CGFloat(v)
                                }
                            audioSlider("Control opacity", value: $controlOpacity, range: 0.45...1)
                                .onChange(of: controlOpacity) { v in
                                    ControlPreferences.controlOpacity = CGFloat(v)
                                }
                            audioSlider("Steer sensitivity", value: $steerSensitivity, range: 0.6...1.4)
                                .onChange(of: steerSensitivity) { v in
                                    ControlPreferences.steerSensitivity = v
                                }
                            Picker("Transmission", selection: $transmissionMode) {
                                ForEach(TransmissionMode.allCases) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .onChange(of: transmissionMode) { v in
                                VehicleDrivingPreferences.transmissionMode = v
                            }
                            Toggle("Pro controls (assists off)", isOn: $manualControl)
                                .tint(KRCDesign.hotOrange)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .onChange(of: manualControl) { v in
                                    VehicleDrivingPreferences.manualControl = v
                                }
                            if !manualControl {
                                audioSlider("Steering assist", value: $steeringAssist)
                                    .onChange(of: steeringAssist) { v in
                                        VehicleDrivingPreferences.steeringAssist = v
                                    }
                                audioSlider("Drift assist", value: $driftAssist)
                                    .onChange(of: driftAssist) { v in
                                        VehicleDrivingPreferences.driftAssist = v
                                    }
                                audioSlider("Brake assist", value: $brakeAssist)
                                    .onChange(of: brakeAssist) { v in
                                        VehicleDrivingPreferences.brakeAssist = v
                                    }
                                audioSlider("Traction control", value: $tractionControl)
                                    .onChange(of: tractionControl) { v in
                                        VehicleDrivingPreferences.tractionControl = v
                                    }
                            }
                        }
                        KRCDesign.SettingsGroup(title: "STORE") {
                            Button {
                                KRCAppStorePolish.requestReviewIfAppropriate()
                            } label: {
                                KRCDesign.SettingsRow(label: "Rate Kaden Racing")
                            }
                            Divider().overlay(Color.white.opacity(0.08))
                            Text("Cosmetics & credits only — no pay-to-win handling.")
                                .font(.caption2)
                                .foregroundStyle(KRCDesign.mutedText)
                                .padding(.horizontal, 14)
                                .padding(.top, 6)
                            ForEach(IAPProductID.allCases.filter(\.isCosmeticOrCurrency), id: \.rawValue) { sku in
                                Button {
                                    Task { @MainActor in
                                        await StoreKitFacade.shared.loadProducts()
                                        if let product = StoreKitFacade.shared.product(for: sku) {
                                            _ = try? await StoreKitFacade.shared.purchase(product, progress: progress)
                                        }
                                    }
                                } label: {
                                    KRCDesign.SettingsRow(label: sku.displayName)
                                }
                                .buttonStyle(.plain)
                                if sku != IAPProductID.allCases.filter(\.isCosmeticOrCurrency).last {
                                    Divider().overlay(Color.white.opacity(0.08))
                                }
                            }
                            .padding(.bottom, 6)
                        }
                        KRCDesign.SettingsGroup(title: "GRAPHICS") {
                            Picker("Quality", selection: $graphicsQuality) {
                                ForEach(GraphicsQuality.allCases) { tier in
                                    Text(tier.displayName).tag(tier)
                                }
                            }
                            .pickerStyle(.inline)
                            .tint(KRCDesign.neonCyan)
                            .padding(.horizontal, 6)
                            .onChange(of: graphicsQuality) { v in
                                EnvironmentGraphicsSettings.quality = v
                            }
                            Text("Applies on the next race load.")
                                .font(.caption2)
                                .foregroundStyle(KRCDesign.mutedText)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 8)
                        }
                        KRCDesign.SettingsGroup(title: "LEGAL") {
                            Button { showPrivacy = true } label: {
                                KRCDesign.SettingsRow(label: "Privacy Policy")
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(Color.white.opacity(0.08))
                            Button { showTerms = true } label: {
                                KRCDesign.SettingsRow(label: "Terms of Service")
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(Color.white.opacity(0.08))
                            Button { openURL(AppLegalLinks.support) } label: {
                                KRCDesign.SettingsRow(label: "Support")
                            }
                            .buttonStyle(.plain)
                        }
                        KRCDesign.SettingsGroup(title: "ACCOUNT") {
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                KRCDesign.SettingsRow(label: "Delete Account", destructive: true)
                            }
                            .buttonStyle(.plain)
                            .disabled(isDeletingAccount)
                            if !deleteStatus.isEmpty {
                                Text(deleteStatus)
                                    .font(.caption)
                                    .foregroundStyle(KRCDesign.mutedText)
                                    .padding(.horizontal, 14)
                                    .padding(.bottom, 10)
                            }
                        }
                        KRCDesign.SettingsGroup(title: "DATA") {
                            Button {
                                resetConfirm = true
                            } label: {
                                KRCDesign.SettingsRow(label: "Reset local progress", destructive: true)
                            }
                            .buttonStyle(.plain)
                        }
                        KRCDesign.Panel {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Kaden Racing Championships")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("Created by Ronell Bradley")
                                    .font(.subheadline)
                                    .foregroundStyle(KRCDesign.mutedText)
                                Text("A product of Bradley Virtual Solutions, LLC")
                                    .font(.caption)
                                    .foregroundStyle(KRCDesign.mutedText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPrivacy) {
                NavigationView {
                    PrivacyPolicyView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showPrivacy = false }
                            }
                        }
                }
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showTerms) {
                NavigationView {
                    TermsOfServiceView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showTerms = false }
                            }
                        }
                }
                .preferredColorScheme(.dark)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            gamerName = KRCPlayerProfile.gamerName
            onlineEnabled = KRCPlayerProfile.onlinePlayEnabled
            musicVolume = KRCAudioPreferences.musicVolume
            musicMuted = KRCAudioPreferences.musicMuted
            sfxVolume = KRCAudioPreferences.sfxVolume
            sfxMuted = KRCAudioPreferences.sfxMuted
            hapticsEnabled = KRCAudioPreferences.hapticsEnabled
            controlScheme = ControlPreferences.scheme
            controlScale = Float(ControlPreferences.controlScale)
            controlOpacity = Float(ControlPreferences.controlOpacity)
            steerSensitivity = ControlPreferences.steerSensitivity
            transmissionMode = VehicleDrivingPreferences.transmissionMode
            manualControl = VehicleDrivingPreferences.manualControl
            steeringAssist = VehicleDrivingPreferences.storedSteeringAssist
            driftAssist = VehicleDrivingPreferences.storedDriftAssist
            brakeAssist = VehicleDrivingPreferences.storedBrakeAssist
            tractionControl = VehicleDrivingPreferences.storedTractionControl
            graphicsQuality = EnvironmentGraphicsSettings.quality
            if onlineEnabled {
                Task {
                    await KRCOnlineService.shared.refreshGlobalSummary()
                    await KRCOnlineService.shared.refreshLeaderboard()
                }
            }
        }
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Account", role: .destructive) {
                Task { await deleteOnlineAccount() }
            }
        } message: {
            Text("Permanently removes your global scores and online presence from our servers (Neon database). This device gets a new anonymous player ID. Local progress is also cleared. This cannot be undone.")
        }
        .alert("Reset local progress?", isPresented: $resetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                progress.resetAllProgress()
            }
        } message: {
            Text("Clears credits, unlocks, upgrades, career, daily, and weekly progress on this device.")
        }
    }

    private func commitGamerName() {
        KRCPlayerProfile.gamerName = gamerName
    }

    @ViewBuilder
    private func audioSlider(
        _ title: String,
        value: Binding<Float>,
        range: ClosedRange<Float> = 0...1
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(KRCDesign.mutedText)
            }
            Slider(value: value, in: range)
                .tint(KRCDesign.neonCyan)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @MainActor
    private func deleteOnlineAccount() async {
        isDeletingAccount = true
        deleteStatus = "Deleting account data…"
        let oldId = KRCPlayerProfile.playerId
        do {
            _ = try await KRCOnlineService.shared.deleteAccountData(playerId: oldId)
            deleteStatus = "Server records removed."
        } catch {
            deleteStatus = "Server delete unavailable; clearing this device only."
        }
        KRCPlayerProfile.resetOnlineIdentityOnDevice()
        progress.resetAllProgress()
        gamerName = KRCPlayerProfile.gamerName
        onlineEnabled = KRCPlayerProfile.onlinePlayEnabled
        await KRCOnlineService.shared.refreshGlobalSummary()
        isDeletingAccount = false
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Privacy Policy")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("Effective date: May 2, 2026")
                    .font(.subheadline)
                    .foregroundStyle(KRCDesign.mutedText)
                legalBlock(
                    "Overview",
                    "Kaden Racing Championships is a racing game that can be played solo or with online global play features."
                )
                legalBlock(
                    "Information We Collect",
                    """
                    When online play is enabled, the game may save your gamer nickname, player ID, selected car, race score, lap time, track, race position, play activity, and temporary online presence so other players can see active racers.

                    Do not use your real name as your gamer nickname.
                    """
                )
                legalBlock(
                    "How We Use Information",
                    "We use this information to show leaderboards, online player counts, multiplayer presence, race results, and saved game preferences."
                )
                legalBlock(
                    "Solo Mode",
                    "Solo mode keeps gameplay private on your device and does not intentionally publish online presence or leaderboard records."
                )
                legalBlock(
                    "Storage",
                    """
                    Settings, progress, and your anonymous player ID are stored locally on your device using standard on-device app storage.

                    When online play is enabled, online play data is also stored in the game database on our servers.
                    """
                )
                legalBlock(
                    "Delete Account",
                    """
                    You can delete your KRC account data from Settings. This removes local KRC data from your device and requests deletion of server records tied to your player ID.

                    Open Settings → Data → Delete online account data, or use the delete option on the web settings page at kaden-car-championships.vercel.app.
                    """
                )
                legalBlock(
                    "Game Center",
                    "If you are signed in to Game Center, Apple may process leaderboard scores according to Apple's privacy policy. Leaderboard participation is optional."
                )
                legalBlock(
                    "Children and Safety",
                    "Players should use a nickname and avoid sharing personal information. Public display names may be visible to other players when online features are enabled."
                )
                legalBlock(
                    "Contact",
                    "For privacy or support questions, contact the app owner through the support contact listed on the App Store product page, or use the Support link in Settings."
                )
                Link("View privacy policy on the web", destination: AppLegalLinks.privacyPolicy)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KRCDesign.gold)
                    .padding(.top, 4)
            }
            .padding()
        }
        .background(Color(white: 0.06).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Terms of Service")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("Effective date: May 2, 2026")
                    .font(.subheadline)
                    .foregroundStyle(KRCDesign.mutedText)
                legalBlock(
                    "Agreement",
                    "By playing Kaden Racing Championships, you agree to use the game fairly, safely, and respectfully."
                )
                legalBlock(
                    "Player Names",
                    "Use a gamer nickname. Do not use your real name or share personal information in your gamer name."
                )
                legalBlock(
                    "Online Play",
                    "Online features may show player names, online presence, scores, lap times, and race results. Do not cheat, disrupt other players, or use offensive names."
                )
                legalBlock(
                    "Solo Play",
                    "Players can choose Solo mode when they do not want to use online global play features."
                )
                legalBlock(
                    "Account Deletion",
                    "The Settings page includes a Delete Account option that clears local KRC data and requests deletion of server records tied to your player ID."
                )
                legalBlock(
                    "Game Content",
                    "The game uses fictional KRC vehicle names. Real vehicle brands, trademarks, and logos belong to their respective owners and are not claimed by this game."
                )
                legalBlock(
                    "Changes",
                    "These terms may be updated as the game changes. Continued use of the game means you accept the current terms."
                )
                Link("View terms of service on the web", destination: AppLegalLinks.termsOfService)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KRCDesign.gold)
                    .padding(.top, 4)
            }
            .padding()
        }
        .background(Color(white: 0.06).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

private func legalBlock(_ title: String, _ body: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.headline)
            .foregroundStyle(KRCDesign.neonCyan)
        Text(body)
            .font(.body)
            .foregroundStyle(KRCDesign.mutedText)
    }
}
