import SwiftUI

struct ChampionsView: View {
    @StateObject private var viewModel = ChampionViewModel()
    
    @State private var searchText = ""
    @State private var selectedRole: String = "Tous"
    @State private var showOnlyFavorites = false
    
    @State private var randomChampion: DBChampion?
    @State private var isNavigatingFromShake = false
    
    let haptic = UIImpactFeedbackGenerator(style: .heavy)
    let roles = [
        ("Tous", "Tous"), ("Assassin", "Assassin"), ("Combattant", "Fighter"),
        ("Mage", "Mage"), ("Tireur", "Marksman"), ("Support", "Support"), ("Tank", "Tank")
    ]
    let gridColumns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var filteredChampions: [DBChampion] {
        viewModel.champions.filter { champ in
            let matchesSearch = searchText.isEmpty || champ.name.localizedCaseInsensitiveContains(searchText)
            let matchesRole = selectedRole == "Tous" || champ.tags.contains(selectedRole)
            let matchesFavorite = !showOnlyFavorites || champ.isFavorite
            return matchesSearch && matchesRole && matchesFavorite
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. BARRE DE FILTRES
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(roles, id: \.1) { roleUI, roleTag in
                            LeagueFilterChip(title: roleUI, isSelected: selectedRole == roleTag) {
                                haptic.impactOccurred(intensity: 0.5)
                                withAnimation(.easeOut(duration: LeagueTheme.pressDuration)) {
                                    selectedRole = roleTag
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .background(LeagueTheme.surface)
                .overlay(alignment: .bottom) { LeagueTheme.border.frame(height: 1) }
                .zIndex(1)
                
                // 2. CONTENU DE LA GRILLE
                ScrollView {
                    if let message = viewModel.errorMessage, viewModel.champions.isEmpty {
                        VStack(spacing: 16) {
                            ContentUnavailableView(message, systemImage: "wifi.exclamationmark", description: Text("Vérifiez votre connexion puis réessayez."))
                            Button("Réessayer") { viewModel.fetchChampionsFromFirebase() }
                                .buttonStyle(LeagueActionButtonStyle())
                                .padding(.horizontal, LeagueTheme.Space.lg)
                        }
                        .padding(.top, 60)
                    } else if viewModel.isLoading && viewModel.champions.isEmpty {
                        LeagueLoadingState(message: "Synchronisation des champions...")
                        .padding(.top, 120)
                    } else if filteredChampions.isEmpty && !viewModel.champions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass").font(.system(size: 48)).foregroundStyle(LeagueTheme.muted)
                            Text("Aucun champion trouvé").font(.title2).bold().foregroundStyle(LeagueTheme.text)
                            Text("Essayez un autre nom ou modifiez les filtres.")
                                .font(.subheadline).foregroundStyle(LeagueTheme.muted)
                        }
                        .padding(.top, 100)
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(filteredChampions) { champion in
                                NavigationLink(destination: ChampionDetailView(champion: champion, viewModel: viewModel)) {
                                    ChampionCard(champion: champion)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(16)
                    }
                }
                .background(LeagueTheme.background)
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
                    .disabled(filteredChampions.isEmpty)
                    .accessibilityLabel("Champion aléatoire ARAM")
                    .accessibilityHint("Tire au sort un champion parmi les filtres actifs")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        haptic.impactOccurred(intensity: 0.5)
                        withAnimation { showOnlyFavorites.toggle() }
                    }) {
                        Image(systemName: showOnlyFavorites ? "heart.fill" : "heart")
                            .foregroundColor(showOnlyFavorites ? LeagueTheme.danger : LeagueTheme.gold)
                            .accessibilityLabel(showOnlyFavorites ? "Afficher tous les champions" : "Afficher les favoris")
                            .font(.title3)
                    }
                }
            }
            // NAVIGATION FIXE POUR L'ARAM
            .background(
                NavigationLink(
                    destination: Group {
                        if let champion = randomChampion {
                            ChampionDetailView(champion: champion, viewModel: viewModel)
                        }
                    },
                    isActive: $isNavigatingFromShake
                ) {
                    EmptyView()
                }
            )
            // DÉTECTEUR DE SECOUSSE (ARAM)
            .onShake { selectRandomChampion() }
        }
    }

    private func selectRandomChampion() {
        guard let chosenChampion = filteredChampions.randomElement() else { return }
        haptic.impactOccurred(intensity: 1.0)
        randomChampion = chosenChampion
        Task {
            await viewModel.loadDetails(for: chosenChampion)
            isNavigatingFromShake = true
        }
    }
}
