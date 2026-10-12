import SwiftUI

struct SpellIcon: View {
    let url: URL?

    var body: some View {
        CachedAsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            LeagueTheme.elevated
                .overlay { Image(systemName: "sparkles").foregroundStyle(LeagueTheme.muted) }
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: LeagueTheme.Corner.medium))
        .overlay {
            RoundedRectangle(cornerRadius: LeagueTheme.Corner.medium)
                .strokeBorder(LeagueTheme.border, lineWidth: 1)
        }
    }
}

struct RealStatCard: View {
    let title: String
    let icon: String
    let color: Color
    let value: Double

    var body: some View {
        HStack(spacing: LeagueTheme.Space.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 25)

            VStack(alignment: .leading, spacing: LeagueTheme.Space.xs) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(LeagueTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Text(value.formatted(.number.precision(.fractionLength(1))))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(LeagueTheme.text)
            }
            Spacer(minLength: 0)
        }
        .padding(LeagueTheme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .leagueSurface(radius: LeagueTheme.Corner.medium)
        .accessibilityElement(children: .combine)
    }
}

struct PriceBox: View {
    let title: String
    let price: Int

    var body: some View {
        VStack(spacing: LeagueTheme.Space.sm) {
            Text(title)
                .font(.caption)
                .foregroundStyle(LeagueTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: LeagueTheme.Space.xs) {
                Text(price.formatted())
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(LeagueTheme.text)
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundStyle(LeagueTheme.gold)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(LeagueTheme.Space.sm)
        .frame(minHeight: 86)
        .leagueSurface(radius: LeagueTheme.Corner.medium)
        .accessibilityElement(children: .combine)
    }
}
