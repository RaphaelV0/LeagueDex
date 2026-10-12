import SwiftUI

/// A single navigation path owns all champion destinations, including ARAM.
/// One shake observer avoids duplicate draws when detail views are stacked.
struct ChampionsView: View {
    var isActive: Bool = true
    @StateObject private var viewModel = ChampionViewModel()

    @State private var searchText = ""
    @State private var selectedRole = "Tous"
    @State private var showOnlyFavorites = false
    @State private var sortDescending = false
    @State private var navigationPath: [String] = []
    @State private var lastShakeAt: Date = .distantPast

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let roles = [
        ("Tous", "Tous"), ("Assassin", "Assassin"),
        ("Combattant", "Fighter"), ("Mage", "Mage"),
        ("Tireur", "Marksman"), ("Support", "Support"), ("Tank", "Tank")
    ]
    private let gridColumns = [
        GridItem(.adaptive(minimum: 142, maximum: 250), spacing: LeagueTheme.Space.md)
    ]

    private var filteredChampions: [DBChampion] {
        let matches = viewModel.champions.filter { champion in
            let isSearchMatch = searchText.isEmpty
                || champion.name.localizedStandardContains(searchText)
            let isRoleMatch = selectedRole == "Tous" || champion.tags.contains(selectedRole)
            let isFavoriteMatch = !showOnlyFavorites || champion.isFavorite
            return isSearchMatch && isRoleMatch && isFavoriteMatch
        }
        return matches.sorted {
            let result = $0.name.localizedStandardCompare($1.name)
            return sortDescending ? result == .orderedDescending : result == .orderedAscending
        }
    }

    private var filtering: Bool {
        !searchText.isEmpty || selectedRole != "Tous" || showOnlyFavorites
    }

    var body: some View {
        let results = filteredChampions

        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: LeagueTheme.Space.lg) {
                    aramFeature
                    rolesRow

                    HStack(spacing: LeagueTheme.Space.sm) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Collection")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(LeagueTheme.text)
                            Text("\(results.count) champions")
                                .font(.subheadline)
                                .foregroundStyle(LeagueTheme.muted)
                        }
                        Spacer(minLength: LeagueTheme.Space.xs)
                        Menu {
                            Button("Nom A à Z") { sortDescending = false }
                            Button("Nom Z à A") { sortDescending = true }
                        } label: {
                            Label("Trier", systemImage: "arrow.up.arrow.down")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LeagueTheme.gold)
                                .frame(minHeight: 44)
                        }
                        .accessibilityValue(sortDescending ? "Nom Z à A" : "Nom A à Z")
                    }

                    if let message = viewModel.errorMessage, viewModel.champions.isEmpty {
                        LeagueErrorState(message: message) {
                            viewModel.fetchChampionsFromFirebase()
                        }
                    } else if viewModel.isLoading && viewModel.champions.isEmpty {
                        LeagueChampionGridSkeleton()
                    } else if results.isEmpty {
                        VStack(spacing: LeagueTheme.Space.md) {
                            LeagueEmptyState(
                                title: "Aucun champion trouvé",
                                detail: filtering
                                    ? "Essayez un autre filtre ou un autre nom."
                                    : "Le catalogue est vide. Réessayez la synchronisation."
                            )
                            Button(filtering ? "Effacer les filtres" : "Recharger les champions") {
                                if filtering {
                                    resetFilters()
                                } else {
                                    viewModel.fetchChampionsFromFirebase()
                                }
                            }
                            .buttonStyle(LeagueActionButtonStyle(prominent: false))
                        }
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: LeagueTheme.Space.md) {
                            ForEach(results) { champion in
                                NavigationLink(value: champion.id) {
                                    ChampionCard(champion: champion)
                                }
                                .buttonStyle(LeagueCompactButtonStyle())
                                .accessibilityHint("Ouvrir la fiche de \(champion.name)")
                            }
                        }
                    }
                }
                .padding(.horizontal, LeagueTheme.Space.md)
                .padding(.top, LeagueTheme.Space.md)
                .padding(.bottom, LeagueTheme.Space.xl)
            }
            .background(LeagueTheme.background)
            .navigationTitle("Champions")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Rechercher un champion")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(reduceMotion ? nil : LeagueMotion.quick) {
                            showOnlyFavorites.toggle()
                        }
                    } label: {
                        Image(systemName: showOnlyFavorites ? "heart.fill" : "heart")
                            .foregroundStyle(showOnlyFavorites ? LeagueTheme.danger : LeagueTheme.gold)
                    }
                    .accessibilityLabel(
                        showOnlyFavorites ? "Afficher tous les champions" : "Afficher les favoris"
                    )
                }
            }
            .navigationDestination(for: String.self) { championID in
                if let champion = viewModel.champions.first(where: { $0.id == championID }) {
                    ChampionDetailView(champion: champion, viewModel: viewModel)
                } else {
                    ContentUnavailableView("Champion introuvable",
                                           systemImage: "person.crop.circle.badge.questionmark")
                }
            }
        }
        .onShake {
            guard isActive else { return }
            drawARAMFromCurrentPage()
        }
    }

    private var aramFeature: some View {
        HStack(alignment: .top, spacing: LeagueTheme.Space.md) {
            Image(systemName: "dice.fill")
                .font(.title2)
                .foregroundStyle(LeagueTheme.gold)
                .frame(width: 42, height: 42)
                .background(LeagueTheme.elevated, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LeagueTheme.Space.xs) {
                Text("Mode ARAM")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(LeagueTheme.text)
                Text("Secouez l’iPhone pour tirer un champion au hasard, même depuis une fiche.")
                    .font(.subheadline)
                    .foregroundStyle(LeagueTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LeagueTheme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .leagueSurface(radius: LeagueTheme.Corner.panel)
    }

    private var rolesRow: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
            Text("Rôles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LeagueTheme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LeagueTheme.Space.sm) {
                    ForEach(roles, id: \.1) { title, tag in
                        LeagueFilterChip(title: title, isSelected: selectedRole == tag) {
                            withAnimation(reduceMotion ? nil : LeagueMotion.quick) {
                                selectedRole = tag
                            }
                        }
                    }
                }
            }
        }
    }

    private func resetFilters() {
        searchText = ""
        selectedRole = "Tous"
        showOnlyFavorites = false
    }

    private func drawARAMFromCurrentPage() {
        // Ignore repeated notifications while a single shake finishes.
        let now = Date()
        guard now.timeIntervalSince(lastShakeAt) > 0.8 else { return }

        let currentChampionID = navigationPath.last
        let candidates: [DBChampion]
        if let currentChampionID {
            // Within a detail, ARAM can select any champion except the current one.
            candidates = viewModel.champions.filter { $0.id != currentChampionID }
        } else {
            // On the catalog, respect active search, role and favorites filters.
            candidates = filteredChampions
        }

        guard let chosen = candidates.randomElement() else { return }
        lastShakeAt = now
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        navigationPath.append(chosen.id)
    }
}
