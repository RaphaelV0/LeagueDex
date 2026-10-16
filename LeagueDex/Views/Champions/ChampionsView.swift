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
    @State private var aram = ARAMState()
    @State private var showingARAM = false
    @State private var galleryPresented = false
    @State private var pendingShake: DeviceShakeEvent?

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
                        updateGallery(presented)
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
        // Keep this listener for shakes on the catalog or a manually opened
        // champion. The full-screen screen also listens, because SwiftUI can
        // pause delivery to the presenting view while a cover is visible.
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { notification in
            guard let event = notification.userInfo?["shake"] as? DeviceShakeEvent else { return }
            receiveShake(event)
        }
        .onChange(of: isActive) { _, active in
            if !active { pendingShake = nil }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pendingShake = nil }
        }
        // This cover is presented once. A new shake only changes its content;
        // no additional champion card is ever pushed on the navigation stack.
        .fullScreenCover(isPresented: $showingARAM, onDismiss: {
            aram.reset()
            galleryPresented = false
            pendingShake = nil
            navigationPath.removeAll()
        }) {
            ARAMChampionPresentation(
                state: $aram,
                viewModel: viewModel,
                onClose: { showingARAM = false },
                onGalleryChange: updateGallery,
                onShake: receiveShake
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

    private func receiveShake(_ event: DeviceShakeEvent) {
        guard isActive, scenePhase == .active else { return }

        // If a skin image is enlarged, keep it intact. The most recent shake
        // takes effect immediately after that gallery is dismissed.
        if galleryPresented {
            pendingShake = event
            return
        }

        // Always use the full champion catalog, even if the catalog search or
        // role filter happens to be empty. The shake is an independent ARAM draw.
        let result = aram.receiveShake(
            eventID: event.id,
            timestamp: event.timestamp,
            candidateIDs: viewModel.champions.map(\.id)
        )
        guard result.isAccepted else { return }

        #if DEBUG
        print("[LeagueDex ARAM] Champion tiré: \(aram.currentChampionID ?? "aucun"), révision \(aram.revision)")
        #endif
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if !showingARAM { showingARAM = true }
    }

    private func updateGallery(_ isPresented: Bool) {
        galleryPresented = isPresented
        guard !isPresented, let event = pendingShake else { return }
        pendingShake = nil
        receiveShake(event)
    }
}

private struct ARAMChampionPresentation: View {
    @Binding var state: ARAMState
    @ObservedObject var viewModel: ChampionViewModel
    let onClose: () -> Void
    let onGalleryChange: (Bool) -> Void
    let onShake: (DeviceShakeEvent) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let championID = state.currentChampionID,
                   let champion = viewModel.champions.first(where: { $0.id == championID }) {
                    ChampionDetailView(
                        champion: champion,
                        viewModel: viewModel,
                        onGalleryChange: onGalleryChange
                    )
                    // New card identity resets scroll, selected spell and stats.
                    .id(state.revision)
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
        // This receiver remains mounted in the full-screen presentation even
        // when the champion detail is recreated for a reroll.
        .background {
            ShakeEventReceiver(enabled: true, reactivation: state.revision)
        }
        // The listener inside the cover makes rerolls reliable on the champion
        // page. The selector discards a duplicate notification automatically.
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { notification in
            guard let event = notification.userInfo?["shake"] as? DeviceShakeEvent else { return }
            onShake(event)
        }
    }
}
