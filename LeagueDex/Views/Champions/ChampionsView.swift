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
                            Button(action: {
                                haptic.impactOccurred(intensity: 0.5)
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selectedRole = roleTag
                                }
                            }) {
                                Text(roleUI)
                                    .font(.subheadline).fontWeight(.semibold)
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(selectedRole == roleTag ? Color.blue : Color(.systemGray6))
                                    .foregroundColor(selectedRole == roleTag ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .background(Color(.systemBackground).shadow(color: .black.opacity(0.05), radius: 5, y: 5))
                .zIndex(1)
                
                // 2. CONTENU DE LA GRILLE
                ScrollView {
                    if let message = viewModel.errorMessage, viewModel.champions.isEmpty {
                        VStack(spacing: 16) {
                            ContentUnavailableView(message, systemImage: "wifi.exclamationmark", description: Text("Vérifiez votre connexion puis réessayez."))
                            Button("Réessayer") { viewModel.fetchChampionsFromFirebase() }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 60)
                    } else if viewModel.isLoading && viewModel.champions.isEmpty {
                        VStack(spacing: 20) {
                            ProgressView().scaleEffect(1.5)
                            Text("Synchronisation Firebase...").font(.headline).foregroundColor(.secondary)
                        }
                        .padding(.top, 120)
                    } else if filteredChampions.isEmpty && !viewModel.champions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass").font(.system(size: 60)).foregroundColor(.secondary.opacity(0.5))
                            Text("Aucun champion trouvé").font(.title2).bold()
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
            }
            .navigationTitle("LeagueDex")
            .searchable(text: $searchText, prompt: "Rechercher un champion...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        haptic.impactOccurred(intensity: 0.5)
                        withAnimation { showOnlyFavorites.toggle() }
                    }) {
                        Image(systemName: showOnlyFavorites ? "heart.fill" : "heart")
                            .foregroundColor(showOnlyFavorites ? .red : .blue)
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
            .onShake {
                if !filteredChampions.isEmpty {
                    haptic.impactOccurred(intensity: 1.0)
                    let chosenChamp = filteredChampions.randomElement()!
                    randomChampion = chosenChamp
                    
                    // On charge d'abord les détails pour que la vue s'affiche complète
                    Task {
                        await viewModel.loadDetails(for: chosenChamp)
                        isNavigatingFromShake = true
                    }
                }
            }
        }
    }
}
