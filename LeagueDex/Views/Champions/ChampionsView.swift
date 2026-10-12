import SwiftUI

struct ChampionsView: View {
    @StateObject private var viewModel = ChampionViewModel()
    @State private var searchText = ""
    @State private var selectedRole = "Tous"
    @State private var showOnlyFavorites = false
    @State private var sortDescending = false

    @State private var randomChampion: DBChampion?
    @State private var isNavigatingFromShake = false
    @State private var isDrawing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let haptic = UIImpactFeedbackGenerator(style: .heavy)
    private let roles = [
        ("Tous", "Tous"), ("Assassin", "Assassin"), ("Combattant", "Fighter"),
        ("Mage", "Mage"), ("Tireur", "Marksman"), ("Support", "Support"), ("Tank", "Tank")
    ]
    private let gridColumns = [GridItem(.adaptive(minimum: 148, maximum: 240), spacing: 12)]

    private var filteredChampions: [DBChampion] {
        let matches = viewModel.champions.filter { champion in
            let matchesSearch = searchText.isEmpty
                || champion.name.localizedStandardContains(searchText)
            let matchesRole = selectedRole == "Tous" || champion.tags.contains(selectedRole)
            let matchesFavorite = !showOnlyFavorites || champion.isFavorite
            return matchesSearch && matchesRole && matchesFavorite
        }
        return matches.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return sortDescending ? order == .orderedDescending : order == .orderedAscending
        }
    }

    private var hasActiveFilters: Bool {
        selectedRole != "Tous" || showOnlyFavorites || !searchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LeagueTheme.Space.sm) {
                        ForEach(roles, id: \.1) { title, tag in
                            LeagueFilterChip(title: title, isSelected: selectedRole == tag) {
                                haptic.impactOccurred(intensity: 0.5)
                                withAnimation(reduceMotion ? nil : .easeOut(duration: LeagueTheme.pressDuration)) {
                                    selectedRole = tag
                                }
                            }
                        }
                    }
                    .padding(.horizontal, LeagueTheme.Space.md)
                    .padding(.vertical, LeagueTheme.Space.sm)
                }
                .background(LeagueTheme.surface)
                .overlay(alignment: .bottom) {
                    LeagueTheme.border.frame(height: 1)
                }

                HStack(spacing: LeagueTheme.Space.sm) {
                    VStack(alignment: .leading, spacing: LeagueTheme.Space.xs) {
                        Text("Champions")
                            .font(.headline)
                            .foregroundStyle(LeagueTheme.text)
                        Text("\(filteredChampions.count) résultat(s)")
                            .font(.caption)
                            .foregroundStyle(LeagueTheme.muted)
                    }
                    Spacer(minLength: 4)
                    Menu {
                        Button("Nom : A à Z") { sortDescending = false }
                        Button("Nom : Z à A") { sortDescending = true }
                    } label: {
                        Label("Trier", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LeagueTheme.gold)
                            .frame(minHeight: 44)
                    }
                    .accessibilityLabel("Trier les champions")

                    Button(action: selectRandomChampion) {
                        Label(isDrawing ? "Tirage…" : "ARAM", systemImage: "dice.fill")
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, LeagueTheme.Space.md)
                            .frame(minHeight: 44)
                            .foregroundStyle(LeagueTheme.background)
                            .background(LeagueTheme.gold, in: Capsule())
                    }
                    .buttonStyle(LeagueCompactButtonStyle())
                    .disabled(filteredChampions.isEmpty || isDrawing)
                    .accessibilityHint("Tire au sort un champion parmi les résultats")
                }
                .padding(.horizontal, LeagueTheme.Space.md)
                .padding(.vertical, LeagueTheme.Space.sm)

                ScrollView {
                    if let message = viewModel.errorMessage, viewModel.champions.isEmpty {
                        LeagueErrorState(message: message) { viewModel.fetchChampionsFromFirebase() }
                            .padding(.top, LeagueTheme.Space.lg)
                            .leagueReveal()
                    } else if viewModel.isLoading && viewModel.champions.isEmpty {
                        LeagueChampionGridSkeleton()
                            .leagueReveal()
                    } else if filteredChampions.isEmpty {
                        VStack(spacing: LeagueTheme.Space.sm) {
                            LeagueEmptyState(
                                title: "Aucun champion trouvé",
                                detail: "Essayez un autre nom ou modifiez les filtres."
                            )
                            if hasActiveFilters {
                                Button("Effacer les filtres", action: resetFilters)
                                    .buttonStyle(LeagueActionButtonStyle(prominent: false))
                                    .padding(.horizontal, LeagueTheme.Space.lg)
                            }
                        }
                        .padding(.top, 48)
                        .leagueReveal()
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: LeagueTheme.Space.md) {
                            ForEach(filteredChampions) { champion in
                                NavigationLink(destination: ChampionDetailView(champion: champion, viewModel: viewModel)) {
                                    ChampionCard(champion: champion)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(LeagueTheme.Space.md)
                    }
                }
            }
            .background(LeagueTheme.background)
            .navigationTitle("LeagueDex")
            .searchable(text: $searchText, prompt: "Rechercher un champion...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: selectRandomChampion) {
                        Image(systemName: "dice.fill")
                            .foregroundStyle(LeagueTheme.gold)
                    }
                    .disabled(filteredChampions.isEmpty || isDrawing)
                    .accessibilityLabel("Champion aléatoire ARAM")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        haptic.impactOccurred(intensity: 0.5)
                        withAnimation(reduceMotion ? nil : .easeOut(duration: LeagueTheme.pressDuration)) {
                            showOnlyFavorites.toggle()
                        }
                    } label: {
                        Image(systemName: showOnlyFavorites ? "heart.fill" : "heart")
                            .foregroundStyle(showOnlyFavorites ? LeagueTheme.danger : LeagueTheme.gold)
                    }
                    .accessibilityLabel(showOnlyFavorites ? "Afficher tous les champions" : "Afficher les favoris")
                }
            }
            .background(
                NavigationLink(
                    destination: Group {
                        if let champion = randomChampion {
                            ChampionDetailView(champion: champion, viewModel: viewModel)
                        }
                    },
                    isActive: $isNavigatingFromShake
                ) { EmptyView() }
            )
            .onShake { selectRandomChampion() }
        }
    }

    private func resetFilters() {
        searchText = ""
        selectedRole = "Tous"
        showOnlyFavorites = false
    }

    private func selectRandomChampion() {
        guard !isDrawing, !isNavigatingFromShake,
              let chosen = filteredChampions.randomElement() else { return }
        isDrawing = true
        haptic.impactOccurred(intensity: 1.0)
        randomChampion = chosen
        Task {
            await viewModel.loadDetails(for: chosen)
            isNavigatingFromShake = true
            isDrawing = false
        }
    }
}
