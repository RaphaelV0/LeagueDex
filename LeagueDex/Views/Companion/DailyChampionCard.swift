import SwiftUI
import Combine

struct DailyChampionCard: View {
    @EnvironmentObject private var daily: DailyChampionStore
    @EnvironmentObject private var quiz: QuizViewModel
    @EnvironmentObject private var catalog: ChampionViewModel
    @EnvironmentObject private var userData: UserDataStore
    @Environment(\.scenePhase) private var scenePhase
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var hasParticipated: Bool {
        userData.quizRuns.contains { $0.dayKey == daily.dayKey } || quiz.submittedDailyResults[daily.dayKey] != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            LeagueSectionHeader(title: "Champion du jour", subtitle: "\(daily.dayKey) · renouvelé à 00:00 UTC")
            if let champion = daily.champion {
                GeometryReader { geometry in
                    CachedAsyncImage(url: champion.splashArtURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { LeagueSkeletonBlock() }
                    .imageDimension(460)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: LeagueTheme.Corner.medium))
                }
                .frame(height: 180)
                .accessibilityLabel("Illustration de \(champion.name)")
                Text(champion.name).font(.title2.weight(.bold)).foregroundStyle(LeagueTheme.gold)
                Text(champion.tags.joined(separator: " · ")).font(.subheadline).foregroundStyle(LeagueTheme.cyan)
                Text(QuizEngine.plainText(champion.blurb)).font(.subheadline).foregroundStyle(LeagueTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let localChampion = catalog.champions.first(where: { $0.id == champion.id }) {
                    NavigationLink {
                        ChampionDetailView(champion: localChampion, viewModel: catalog, showsARAMHint: false)
                    } label: { Label("Découvrir \(champion.name)", systemImage: "person.text.rectangle") }
                    .buttonStyle(LeagueActionButtonStyle(prominent: false))
                } else {
                    Text("La fiche de ce champion sera accessible lorsque le catalogue sera disponible. La sélection du jour reste identique.")
                        .font(.footnote).foregroundStyle(LeagueTheme.muted)
                }
                if hasParticipated {
                    Label("Défi du jour déjà terminé", systemImage: "checkmark.seal")
                        .font(.subheadline).foregroundStyle(LeagueTheme.cyan)
                }
                NavigationLink { QuizView(dailyChallenge: true) } label: {
                    Label(hasParticipated ? "Voir ma participation" : "La question du jour", systemImage: "calendar.badge.questionmark")
                }
                .buttonStyle(LeagueActionButtonStyle())
                .disabled(daily.question == nil && !hasParticipated)
                if daily.isFromCache {
                    Label("Catalogue Riot en cache", systemImage: "internaldrive")
                        .font(.caption).foregroundStyle(LeagueTheme.muted)
                }
            } else if daily.isLoading {
                LeagueLoadingState(message: "Recherche du champion du jour…")
            } else {
                Text(daily.errorMessage ?? "Le catalogue Riot doit être téléchargé une première fois.")
                    .font(.subheadline).foregroundStyle(LeagueTheme.muted)
                Button("Réessayer") { Task { await daily.refresh(force: true) } }
                    .buttonStyle(LeagueActionButtonStyle(prominent: false))
            }
            Text("La sélection utilise le catalogue Riot complet du patch \(DataDragon.version), trié par identifiant et la date UTC.")
                .font(.caption).foregroundStyle(LeagueTheme.muted)
        }
        .padding(LeagueTheme.Space.md).leagueSurface(radius: LeagueTheme.Corner.panel)
        .task { await daily.refresh() }
        .onReceive(clock) { date in
            if DailySelection.dayKey(for: date) != daily.dayKey { Task { await daily.refresh(for: date) } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await daily.refresh() } }
        }
    }
}
