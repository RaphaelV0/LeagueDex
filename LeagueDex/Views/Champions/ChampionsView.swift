import SwiftUI
import Combine

/// Manual navigation and one ARAM presentation share the same champion catalog.
struct ChampionsView: View {
    var isActive: Bool = true
    @EnvironmentObject private var viewModel: ChampionViewModel

    @State private var searchText = ""
    @State private var selectedRole = "Tous"
    @State private var showOnlyFavorites = false
    @State private var sortDescending = false
    @State private var navigationPath: [String] = []
    @StateObject private var aram = ARAMShakeController()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let roles = [
        ("Tous", "Tous"), ("Assassin", "Assassin"),
        ("Combattant", "Fighter"), ("Mage", "Mage"),
        ("Tireur", "Marksman"), ("Support", "Support"), ("Tank", "Tank")
    ]
    private let gridColumns = [
        GridItem(.adaptive(minimum: 142, maximum: 250), spacing: LeagueTheme.Space.md)
    ]

    private var filteredChampions: [DBChampion] {
        let filter = ChampionFilter(searchText: searchText, selectedRole: selectedRole,
                                    favoritesOnly: showOnlyFavorites, sortDescending: sortDescending)
        let candidates = viewModel.champions.map {
            ChampionCandidate(id: $0.id, name: $0.name, tags: $0.tags, isFavorite: $0.isFavorite)
        }
        let byID = Dictionary(viewModel.champions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return filter.apply(to: candidates).compactMap { byID[$0.id] }
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
                    ChampionDetailView(champion: champion, viewModel: viewModel,
                                       enableShakeDetection: true) { presented in
                        aram.setGalleryPresented(presented)
                    }
                } else {
                    ContentUnavailableView("Champion introuvable",
                                           systemImage: "person.crop.circle.badge.questionmark")
                }
            }
        }
        // A visible UIKit responder receives motionEnded reliably while the
        // catalog is active, instead of relying on UIWindow to be the responder.
        .background {
            ShakeEventReceiver(enabled: isActive && scenePhase == .active)
        }
        // The UIKit notification is owned by ARAMShakeController, not by
        // either SwiftUI screen. Presenting a full-screen cover cannot cancel it.
        .onAppear {
            aram.setTabActive(isActive)
            aram.setChampions(viewModel.champions.map(\.id))
        }
        .onChange(of: isActive) { _, active in
            aram.setTabActive(active)
        }
        .onChange(of: viewModel.champions.map(\.id)) { _, ids in
            aram.setChampions(ids)
        }
        .fullScreenCover(isPresented: $aram.isShowingARAM, onDismiss: {
            aram.didDismiss()
            navigationPath.removeAll()
        }) {
            ARAMChampionPresentation(
                aram: aram,
                viewModel: viewModel,
                onClose: { aram.close() },
                onGalleryChange: { aram.setGalleryPresented($0) }
            )
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

}

private struct ARAMChampionPresentation: View {
    @ObservedObject var aram: ARAMShakeController
    @ObservedObject var viewModel: ChampionViewModel
    let onClose: () -> Void
    let onGalleryChange: (Bool) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let championID = aram.currentChampionID,
                   let champion = viewModel.champions.first(where: { $0.id == championID }) {
                    ChampionDetailView(
                        champion: champion,
                        viewModel: viewModel,
                        onGalleryChange: onGalleryChange
                    )
                    // Every accepted shake constructs a fresh complete champion
                    // detail, with its scroll position and selection reset.
                    .id(aram.revision)
                } else {
                    ContentUnavailableView(
                        "Champion indisponible",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Secoue à nouveau l’iPhone pour choisir un champion.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Label("Fermer ARAM", systemImage: "xmark")
                    }
                    .accessibilityLabel("Fermer le mode ARAM et revenir au catalogue")
                }
            }
        }
        .tint(LeagueTheme.gold)
        .background(LeagueTheme.background)
        // Keep a UIKit first responder on the visible full-screen page. Shake
        // notifications go directly to the persistent observable controller.
        .background {
            ShakeEventReceiver(enabled: true, reactivation: aram.revision)
        }
    }
}
