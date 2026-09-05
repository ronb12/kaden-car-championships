import SwiftUI

/// Compact in-race HUD — floating chips so the track stays readable.
struct ModernRaceHUD: View {
    let portrait: Bool
    let venue: String
    let mode: String
    let speedKmh: Int
    let rpm: Float
    let gear: Int
    let lap: Int
    let lapGoal: Int
    let raceTime: String
    let position: Int
    let racerCount: Int
    let showPosition: Bool
    let nitro: Float
    let heat: Float
    let showHeat: Bool
    var heatLabel: String = "HEAT"
    var damage: Float = 0
    var showDamage: Bool = false
    let driftMultiplier: Float
    let driftScore: Int64
    let progress: Float
    var crystals: Int = 0
    var crystalTotal: Int = 0
    var objectiveLabel: String = ""
    var objectiveProgress: Float = 0
    var objectiveComplete: Bool = false
    var arcadeToast: String? = nil
    var draftActive: Bool = false
    var driftZoneActive: Bool = false
    var manualTransmission: Bool = false
    var shiftZone: Bool = false
    var shiftNotice: String? = nil
    var reverseGear: Bool = false
    var positionPrefix: String? = nil
    var onlineStatus: String? = nil
    var wrongWay: Bool = false
    /// Courier Run extras — nav compass, cargo, dwell, earnings.
    var courierMode: Bool = false
    var courierBearing: Float = 0
    var courierDistance: Float = 0
    var courierDwell: Float = 0
    var courierInZone: Bool = false
    var courierCarrying: Bool = false
    var courierEarned: Int64 = 0
    var courierNextPayout: Int64 = 0
    var courierStreak: Int = 0
    var courierUrgency: Bool = false
    var courierPackageKind: String = ""
    var courierRivalThreat: Float = 0
    var courierCargoHeld: Int = 0
    var courierCargoCapacity: Int = 1
    var courierNightPremium: Bool = false
    var courierCoachHint: String = ""
    var courierReverseParkHint: Bool = false
    var courierTipsEarned: Int64 = 0
    var courierLastTipAmount: Int64 = 0
    var courierLastTipStars: Int = 0
    var courierTipFlash: Float = 0
    /// First-race declutter — hide arcade chip clutter so core meters read instantly.
    var decluttered: Bool = false
    @ViewBuilder var pauseControl: () -> AnyView

    private var speedRatio: CGFloat { min(1, CGFloat(speedKmh) / 400) }
    @ScaledMetric(relativeTo: .caption) private var hudCaption: CGFloat = 11
    @ScaledMetric(relativeTo: .caption) private var hudTitle: CGFloat = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            topBar
            compactMeters
            if courierMode {
                courierStrip
            } else if !decluttered, (!objectiveLabel.isEmpty || crystals > 0 || draftActive || driftZoneActive) {
                arcadeChips
            }
            if let arcadeToast {
                toastBanner(arcadeToast)
            }
            if wrongWay {
                wrongWayBanner
            }
            if let shiftNotice, manualTransmission {
                shiftNoticeBanner(shiftNotice)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hudSpokenSummary)
    }

    private var hudSpokenSummary: String {
        var parts: [String] = ["\(speedKmh) kilometers per hour"]
        if showPosition {
            if let positionPrefix {
                parts.append("\(positionPrefix) \(position) of \(max(1, racerCount))")
            } else {
                parts.append("Position \(position) of \(max(1, racerCount))")
            }
        }
        if courierMode {
            parts.append("Time \(raceTime)")
        } else if positionPrefix == nil {
            parts.append("Lap \(lap) of \(lapGoal), time \(raceTime)")
        }
        parts.append("Nitro \(Int((nitro * 100).rounded())) percent")
        if showHeat {
            parts.append("\(heatLabel) \(Int((heat * 100).rounded())) percent")
        }
        if wrongWay { parts.append("Wrong way") }
        if draftActive { parts.append("Draft") }
        if driftZoneActive { parts.append("Drift zone") }
        return parts.joined(separator: ". ")
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 8) {
            speedPill
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if showPosition {
                        Text(positionPrefix != nil
                             ? "\(positionPrefix!) \(position)/\(max(1, racerCount))"
                             : "P\(position)/\(max(1, racerCount))")
                            .font(.system(size: hudTitle, weight: .black, design: .rounded))
                            .foregroundStyle(position == 1 || positionPrefix != nil ? KRCDesign.gold : KRCDesign.neonCyan)
                    }
                    Text(courierMode ? "TIME" : (positionPrefix != nil ? "CATCH" : "L\(lap)/\(lapGoal)"))
                        .font(.system(size: hudCaption, weight: .bold, design: .monospaced))
                        .foregroundStyle(courierUrgency ? Color.red : .white)
                    Text(raceTime)
                        .font(.system(size: hudCaption, weight: .bold, design: .monospaced))
                        .foregroundStyle(courierUrgency ? Color.red.opacity(0.95) : KRCDesign.mutedText)
                }
                Text(venue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                if let onlineStatus, !onlineStatus.isEmpty {
                    Text(onlineStatus)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(KRCDesign.neonCyan.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.42)))
            Spacer(minLength: 0)
            pauseControl()
        }
    }

    private var speedPill: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 3)
            Circle()
                .trim(from: 0, to: speedRatio)
                .stroke(
                    AngularGradient(
                        colors: [KRCDesign.neonCyan, KRCDesign.gold, KRCDesign.hotOrange],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: -1) {
                Text("\(speedKmh)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(reverseGear ? "R" : "G\(max(1, gear))")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(KRCDesign.gold)
            }
        }
        .frame(width: 52, height: 52)
        .background(Circle().fill(Color.black.opacity(0.45)))
    }

    private var compactMeters: some View {
        HStack(spacing: 8) {
            miniMeter("N2O", nitro, KRCDesign.neonCyan)
            miniMeter(manualTransmission && shiftZone ? "SHIFT" : "RPM", rpm,
                      manualTransmission && shiftZone ? Color(red: 0.55, green: 1, blue: 0.74) : KRCDesign.hotOrange)
            Text("DRIFT ×\(String(format: "%.1f", driftMultiplier))")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
            if !decluttered, showHeat {
                miniMeter(heatLabel, heat, heatLabel == "LOCK" ? KRCDesign.neonCyan : .red)
            }
            if !decluttered, showDamage {
                miniMeter("DMG", damage, Color(red: 1, green: 0.45, blue: 0.15))
            }
            // Fixed-width lap progress — a GeometryReader here used to expand into a long empty pill.
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [KRCDesign.neonCyan, KRCDesign.gold], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 72 * CGFloat(min(1, max(0, progress))))
            }
            .frame(width: 72, height: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.38)))
    }

    private var arcadeChips: some View {
        HStack(spacing: 6) {
            chip(icon: "diamond.fill", text: "KR \(crystals)/\(max(crystalTotal, 1))", color: KRCDesign.gold)
            if draftActive { chip(icon: "wind", text: "DRAFT", color: KRCDesign.neonCyan) }
            if driftZoneActive { chip(icon: "flame.fill", text: "ZONE", color: Color(red: 1, green: 0.4, blue: 0.85)) }
            if !objectiveLabel.isEmpty {
                HStack(spacing: 4) {
                    Text(objectiveComplete ? "DONE" : "OBJ")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(objectiveComplete ? Color.green : KRCDesign.gold)
                    Text(objectiveLabel.replacingOccurrences(of: "Collect ", with: "").replacingOccurrences(of: "Score ", with: ""))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 36, height: 3)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(objectiveComplete ? Color.green : KRCDesign.gold)
                                .frame(width: 36 * CGFloat(min(1, max(0, objectiveProgress))), height: 3)
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.4)))
            }
            Spacer(minLength: 0)
        }
    }

    private var courierStrip: some View {
        HStack(spacing: 8) {
            // Compass — arrow rotates toward next stop.
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 2)
                    .frame(width: 40, height: 40)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(courierCarrying ? Color(red: 0.2, green: 0.95, blue: 0.55) : KRCDesign.hotOrange)
                    .rotationEffect(.radians(Double(courierBearing)))
            }
            .padding(2)
            .background(Circle().fill(Color.black.opacity(0.45)))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(courierCarrying ? "CARGO \(max(1, courierCargoHeld))/\(max(1, courierCargoCapacity))" : "EMPTY")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(courierCarrying ? Color(red: 0.2, green: 0.95, blue: 0.55) : KRCDesign.mutedText)
                    if !courierPackageKind.isEmpty, courierCarrying {
                        Text(courierPackageKind)
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(KRCDesign.hotOrange)
                    }
                    Text("\(Int(max(0, courierDistance).rounded()))m")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    if courierStreak > 1 {
                        Text("\(courierStreak)×")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(KRCDesign.gold)
                    }
                    if courierNightPremium {
                        Text("NIGHT")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(KRCDesign.neonCyan)
                    }
                }
                if courierRivalThreat > 0.05 {
                    HStack(spacing: 4) {
                        Text("RIVAL")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.red)
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 52, height: 4)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Color.red)
                                    .frame(width: 52 * CGFloat(min(1, max(0, courierRivalThreat))), height: 4)
                            }
                    }
                }
                if courierTipFlash > 0.05, courierLastTipAmount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(red: 1, green: 0.35, blue: 0.55))
                        Text("TIP +\(courierLastTipAmount)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(KRCDesign.gold)
                        Text(String(repeating: "★", count: max(1, min(5, courierLastTipStars))))
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(KRCDesign.gold)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                    .opacity(Double(min(1, courierTipFlash)))
                } else if !courierCoachHint.isEmpty {
                    Text(courierCoachHint)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(courierReverseParkHint ? KRCDesign.neonCyan : KRCDesign.gold)
                        .lineLimit(1)
                } else if !objectiveLabel.isEmpty {
                    Text(objectiveLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                if courierInZone {
                    HStack(spacing: 4) {
                        Text(courierCarrying
                             ? (courierReverseParkHint ? "REVERSE + HOLD" : "HOLD TO DROP")
                             : "HOLD TO LOAD")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(KRCDesign.gold)
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 52, height: 4)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(KRCDesign.gold)
                                    .frame(width: 52 * CGFloat(min(1, max(0, courierDwell))), height: 4)
                            }
                    }
                }
            }

            Spacer(minLength: 0)

            // Demote earnings while driving; promote dwell / next stop in the strip.
            if courierInZone || courierAwaitingBoard {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(courierEarned)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(KRCDesign.gold)
                    if courierTipsEarned > 0 {
                        Text("TIPS \(courierTipsEarned)")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.65))
                    } else if courierNextPayout > 0 {
                        Text("NEXT \(courierNextPayout)")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.42)))
            } else if courierTipFlash > 0.05, courierLastTipAmount > 0 {
                Text("+\(courierLastTipAmount) tip")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(KRCDesign.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.5)))
            } else if courierNextPayout > 0 {
                Text("→\(courierNextPayout)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.32)))
    }

    /// Board open / not mid-route — show full earnings chip.
    private var courierAwaitingBoard: Bool {
        !courierCarrying && courierCargoHeld == 0 && courierDistance < 0.5
    }

    private func chip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.42)))
    }

    private func miniMeter(_ label: String, _ value: Float, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(color)
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: 28, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color)
                        .frame(width: 28 * CGFloat(min(1, max(0, value))), height: 4)
                }
            if KRCAccessibility.increaseContrast {
                Text("\(Int((value * 100).rounded()))")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(Int((value * 100).rounded())) percent")
    }

    private func toastBanner(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .multilineTextAlignment(.center)
            .foregroundStyle(KRCDesign.gold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.55))
            )
    }

    private var wrongWayBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.uturn.down")
                .font(.system(size: 14, weight: .black))
            Text("WRONG WAY")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .tracking(1.5)
            Image(systemName: "arrow.uturn.down")
                .font(.system(size: 14, weight: .black))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                )
        )
        .shadow(color: .red.opacity(0.45), radius: 10, y: 2)
        .frame(maxWidth: .infinity)
        .opacity(0.92)
    }

    private func shiftNoticeBanner(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .foregroundStyle(text == "PERFECT SHIFT" ? Color(red: 0.55, green: 1, blue: 0.74) : KRCDesign.gold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.45)))
    }
}
