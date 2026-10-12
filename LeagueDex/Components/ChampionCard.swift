import SwiftUI

struct ChampionCard: View {
    let champion: DBChampion

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: champion.splashArtURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                LeagueTheme.elevated.overlay {
                    Image(systemName: "person.crop.rectangle")
                        .font(.title2)
                        .foregroundStyle(LeagueTheme.muted)
                }
            }
            .imageDimension(260)
            .frame(maxWidth: .infinity)
            .frame(height: 184)
            .clipped()

            LeagueTheme.championGradient

            VStack(alignment: .leading, spacing: LeagueTheme.Space.xs) {
                Text(champion.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LeagueTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(champion.title.capitalized)
                    .font(.caption)
                    .foregroundStyle(LeagueTheme.muted)
                    .lineLimit(1)
            }
            .padding(LeagueTheme.Space.md)
        }
        .frame(height: 184)
        .clipShape(RoundedRectangle(cornerRadius: LeagueTheme.Corner.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LeagueTheme.Corner.large, style: .continuous)
                .strokeBorder(LeagueTheme.border.opacity(0.9), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            if champion.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.subheadline)
                    .foregroundStyle(LeagueTheme.danger)
                    .padding(LeagueTheme.Space.sm)
                    .background(LeagueTheme.surface.opacity(0.94), in: Circle())
                    .padding(LeagueTheme.Space.sm)
                    .accessibilityHidden(true)
            }
        }
        .shadow(color: .black.opacity(0.24), radius: 9, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(champion.name), \(champion.title)" +
            (champion.isFavorite ? ", favori" : "")
        )
    }
}
