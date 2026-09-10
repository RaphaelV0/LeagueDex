import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = ChampionViewModel()
    
    // Récupération locale triée par ordre alphabétique
    @Query(sort: \DBChampion.name) private var allChampions: [DBChampion]
    
    @State private var searchText = ""
    @State private var selectedRole: String = "Tous"
    @State private var showOnlyFavorites = false
    
    // Générateur de vibrations pour les filtres
    let haptic = UIImpactFeedbackGenerator(style: .light)
    
    let roles = [
        ("Tous", "Tous"), ("Assassin", "Assassin"), ("Combattant", "Fighter"),
        ("Mage", "Mage"), ("Tireur", "Marksman"), ("Support", "Support"), ("Tank", "Tank")
    ]
    
    let gridColumns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var filteredChampions: [DBChampion] {
        allChampions.filter { champ in
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
                                haptic.impactOccurred()
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selectedRole = roleTag
                                }
                            }) {
                                Text(roleUI)
                                    .font(.subheadline).fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(selectedRole == roleTag ? Color.blue : Color(.systemGray6))
                                    .foregroundColor(selectedRole == roleTag ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground).shadow(color: .black.opacity(0.05), radius: 5, y: 5))
                .zIndex(1)
                
                // 2. CONTENU PRINCIPAL
                ScrollView {
                    if viewModel.isLoading && allChampions.isEmpty {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Invocation de la Faille...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 120)
                        
                    } else if filteredChampions.isEmpty && !allChampions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Aucun champion trouvé")
                                .font(.title2).bold()
                            Text("Essayez un autre rôle ou modifiez votre recherche.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
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
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredChampions.count)
                    }
                }
            }
            .navigationTitle("LeagueDex")
            .searchable(text: $searchText, prompt: "Rechercher un champion...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        haptic.impactOccurred()
                        withAnimation { showOnlyFavorites.toggle() }
                    }) {
                        Image(systemName: showOnlyFavorites ? "heart.fill" : "heart")
                            .foregroundColor(showOnlyFavorites ? .red : .blue)
                            .font(.title3)
                    }
                }
            }
            .task {
                if allChampions.isEmpty { await viewModel.syncChampions(context: context) }
            }
        }
    }
}

// COMPOSANT UI : Carte d'un champion
struct ChampionCard: View {
    let champion: DBChampion
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            
            // Correction de la grille : le cadre transparent force l'image à respecter la largeur de la colonne
            Color.clear
                .frame(height: 170)
                .overlay(
                    CachedAsyncImage(url: champion.splashArtURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                )
                .clipped()
            
            // Dégradé sombre pour faire ressortir le texte
            LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
            
            // Texte en bas à gauche
            VStack(alignment: .leading, spacing: 2) {
                Text(champion.name)
                    .font(.title3).bold()
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(champion.title.capitalized)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        
        // Cœur des favoris superposé
        .overlay(alignment: .topTrailing) {
            if champion.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(8)
            }
        }
    }
}
