import SwiftUI

/// City photo / gradient thumbnail — always cover-fills the parent frame (no letterbox / gaps).
struct CityPreviewArt: View {
    let city: CityThemeID
    var accent: Color = KRCDesign.neonCyan
    var showName: Bool = false

    var body: some View {
        ZStack {
            photoLayer
            LinearGradient(
                colors: [
                    Color.black.opacity(0.02),
                    Color.black.opacity(showName ? 0.58 : 0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            if showName {
                VStack {
                    Spacer()
                    Text(city.cityName.uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(accent.opacity(0.5), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var photoLayer: some View {
        if city.hasPreviewCardPhoto {
            GeometryReader { geo in
                Image(city.previewCardAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        } else {
            LinearGradient(
                colors: city.previewCardColors.map { Color(uiColor: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

/// City picker for track select (strip) or garage (grid).
struct CityThemePicker: View {
    enum Layout {
        /// Horizontal filmstrip — fits circuit select without a 30-row grid.
        case trackSelect
        /// Hero + grid for garage / modes without track pick.
        case grid
    }

    @Binding var selection: CityThemeID
    var layout: Layout = .grid
    private let gridColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    private let cardAspect: CGFloat = 16.0 / 9.0

    var body: some View {
        switch layout {
        case .trackSelect:
            trackSelectLayout
        case .grid:
            gridLayout
        }
    }

    // MARK: - Track select (compact)

    private var trackSelectLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                CityPreviewArt(city: selection, accent: KRCDesign.gold, showName: true)
                    .aspectRatio(cardAspect, contentMode: .fit)
                    .frame(width: 176)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(selection.cityName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(selection.countryName)
                        .font(.caption2)
                        .foregroundStyle(KRCDesign.mutedText)
                    Text(selection.localeTagline)
                        .font(.caption2)
                        .foregroundStyle(KRCDesign.neonCyan.opacity(0.9))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CityThemeID.allCases) { city in
                        trackSelectThumb(city)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func trackSelectThumb(_ city: CityThemeID) -> some View {
        let on = selection == city
        return Button {
            selection = city
        } label: {
            CityPreviewArt(
                city: city,
                accent: on ? KRCDesign.gold : Color.cyan.opacity(0.45),
                showName: true
            )
            .aspectRatio(cardAspect, contentMode: .fit)
            .frame(width: 104)
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .topTrailing) {
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(KRCDesign.gold)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Garage grid

    private var gridLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                CityPreviewArt(city: selection, accent: KRCDesign.gold, showName: true)
                    .aspectRatio(cardAspect, contentMode: .fit)
                    .frame(width: 184)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(selection.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(selection.localeTagline)
                        .font(.caption)
                        .foregroundStyle(KRCDesign.neonCyan.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(CityThemeID.allCases) { city in
                    gridChip(city)
                }
            }
        }
    }

    private func gridChip(_ city: CityThemeID) -> some View {
        let on = selection == city
        return Button {
            selection = city
        } label: {
            CityPreviewArt(
                city: city,
                accent: on ? KRCDesign.gold : Color.cyan.opacity(0.35),
                showName: true
            )
            .aspectRatio(cardAspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
