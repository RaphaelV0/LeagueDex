import SwiftUI

struct CompanionHubView: View {
    @EnvironmentObject private var userData: UserDataStore
    @ObservedObject private var favorites = FavoritesStore.shared
    @State private var showsAccount = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LeagueTheme.Space.lg) {
                    LeagueSectionHeader(title: "Votre espace joueur",
                        subtitle: "\(favorites.ids.count) favoris · \(userData.builds.count) builds")
                    DailyChampionCard()
                    NavigationLink { QuizView() } label: {
                        CompanionFeatureCard(title: "Quiz League of Legends", subtitle: "Six catégories, dix questions et votre progression", icon: "questionmark.circle.fill")
                    }
                    NavigationLink { ChampionComparisonView() } label: {
                        CompanionFeatureCard(title: "Comparer les champions", subtitle: "Statistiques, rôles et compétences du niveau 1 à 18", icon: "arrow.left.arrow.right")
                    }
                    NavigationLink { BuildsView() } label: {
                        CompanionFeatureCard(title: "Mes builds", subtitle: "Préparez votre inventaire et retrouvez-le sur vos appareils", icon: "square.grid.3x2.fill")
                    }
                }
                .padding(LeagueTheme.Space.md)
            }
            .background(LeagueTheme.background)
            .navigationTitle("LeagueDex")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showsAccount = true } label: { Image(systemName: "person.crop.circle") }
                        .accessibilityLabel("Ouvrir mon compte")
                }
            }
            .sheet(isPresented: $showsAccount) { AccountView() }
        }
    }
}

struct CompanionFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: LeagueTheme.Space.md) {
            Image(systemName: icon).font(.title2).foregroundStyle(LeagueTheme.gold)
                .frame(width: 36).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: LeagueTheme.Space.xs) {
                Text(title).font(.headline).foregroundStyle(LeagueTheme.text)
                Text(subtitle).font(.subheadline).foregroundStyle(LeagueTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(LeagueTheme.muted).accessibilityHidden(true)
        }
        .padding(LeagueTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .leagueSurface(radius: LeagueTheme.Corner.panel)
        .accessibilityElement(children: .combine)
    }
}
