import SwiftUI

/// Top global times from Neon (same data as web scoreboard).
struct GlobalLeaderboardView: View {
    @ObservedObject private var online = KRCOnlineService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if !online.scoreboardMessage.isEmpty {
                statusBanner(online.scoreboardMessage)
            }
            if online.leaderboard.isEmpty {
                emptyState
            } else {
                leaderboardTable
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.55),
                            KRCDesign.cardFill,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    KRCDesign.neonCyan.opacity(0.5),
                                    KRCDesign.gold.opacity(0.35),
                                    Color.white.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: KRCDesign.neonCyan.opacity(0.12), radius: 16, y: 6)
        }
        .task {
            await online.refreshLeaderboard()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [KRCDesign.gold, KRCDesign.hotOrange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: KRCDesign.gold.opacity(0.45), radius: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("GLOBAL SCOREBOARD")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                if online.globalEnabled {
                    Text(
                        online.leaderboard.isEmpty && online.globalRaceCount > 0
                            ? "\(online.globalRaceCount) races logged · awaiting ranked times"
                            : "\(online.globalRaceCount) races logged"
                    )
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(KRCDesign.neonCyan)
                }
            }
            Spacer()
        }
    }

    private func statusBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(KRCDesign.mutedText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(KRCDesign.neonCyan.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(KRCDesign.neonCyan.opacity(0.25), lineWidth: 1)
                    )
            }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "flag.checkered")
                .font(.title3)
                .foregroundStyle(KRCDesign.mutedText)
            Text(
                online.globalEnabled
                    ? (online.globalRaceCount > 0
                        ? "\(online.globalRaceCount) races logged · no ranked finish times yet."
                        : "No global times yet — finish a race online to claim a spot.")
                    : "Connect the server database to enable global rankings."
            )
            .font(.subheadline)
            .foregroundStyle(KRCDesign.mutedText)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var leaderboardTable: some View {
        VStack(spacing: 0) {
            tableHeader
            ForEach(Array(online.leaderboard.prefix(10).enumerated()), id: \.element.id) { index, row in
                leaderboardRow(row, index: index)
                if index < min(9, online.leaderboard.count - 1) {
                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.leading, 52)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var tableHeader: some View {
        HStack(spacing: 8) {
            Text("RK")
                .frame(width: 36, alignment: .leading)
            Text("RACER")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("TIME")
                .frame(width: 72, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .heavy, design: .monospaced))
        .foregroundStyle(KRCDesign.mutedText)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
    }

    private func leaderboardRow(_ row: GlobalLeaderboardEntry, index: Int) -> some View {
        HStack(spacing: 10) {
            rankBadge(row.place)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.playerName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text([row.carName, row.trackName].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(KRCDesign.mutedText)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(formatRaceMs(row.totalMs))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(KRCDesign.neonCyan)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(index.isMultiple(of: 2) ? Color.white.opacity(0.03) : Color.clear)
    }

    @ViewBuilder
    private func rankBadge(_ place: Int) -> some View {
        let style = rankStyle(place)
        ZStack {
            Circle()
                .fill(style.fill)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .strokeBorder(style.stroke, lineWidth: 1)
                )
            if place <= 3 {
                Image(systemName: style.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(style.foreground)
            } else {
                Text("\(place)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(style.foreground)
            }
        }
        .frame(width: 36, alignment: .leading)
    }

    private func rankStyle(_ place: Int) -> (fill: Color, stroke: Color, foreground: Color, icon: String) {
        switch place {
        case 1:
            return (KRCDesign.gold.opacity(0.22), KRCDesign.gold.opacity(0.7), KRCDesign.gold, "crown.fill")
        case 2:
            return (Color.white.opacity(0.14), Color.white.opacity(0.45), Color.white.opacity(0.92), "medal.fill")
        case 3:
            return (KRCDesign.hotOrange.opacity(0.18), KRCDesign.hotOrange.opacity(0.55), KRCDesign.hotOrange, "medal.fill")
        default:
            return (Color.white.opacity(0.06), Color.white.opacity(0.12), KRCDesign.mutedText, "number")
        }
    }

    private func formatRaceMs(_ ms: Int) -> String {
        let s = Double(ms) / 1000
        let m = Int(s) / 60
        let r = s - Double(m * 60)
        return m > 0 ? String(format: "%d:%05.2f", m, r) : String(format: "%.2fs", r)
    }
}
