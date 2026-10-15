import SwiftUI
import Combine

/// Manual navigation and one ARAM presentation share the same champion catalog.
struct ChampionsView: View {
    var isActive: Bool = true
    @StateObject private var viewModel = ChampionViewModel()

    @State private var searchText = ""
    @State private var selectedRole = "Tous"
    @State private var showOnlyFavorites = false
    @State private var sortDescending = false
    @State private var navigationPath: [String] = []
    @State private var aram = ARAMState()

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
        let presentedSessionID = aram.session?.id

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
                    ChampionDetailView(champion: champion, viewModel: viewModel) { presented in
                        updateGallery(presented, sessionID: nil)
                    }
                } else {
                    ContentUnavailableView("Champion introuvable",
                                           systemImage: "person.crop.circle.badge.questionmark")
                }
            }
        }
        // A single subscriber remains mounted underneath both full-screen
        // presentations. Process events directly, without coalescing them into
        // a "latest event" @State that could lose distinct queued gestures.
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { notification in
            guard let event = notification.userInfo?["shake"] as? DeviceShakeEvent else { return }
            receiveShake(event)
        }
        .onChange(of: isActive) { _, active in
            if !active { aram.discardPendingSelection() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { aram.discardPendingSelection() }
        }
        .fullScreenCover(item: presentedSession, onDismiss: {
            guard let presentedSessionID else { return }
            aram.presentationDidDismiss(sessionID: presentedSessionID,
                                        isActive: isActive, sceneIsActive: scenePhase == .active)
            returnToCatalogIfOpening()
        }) { session in
            ARAMChampionPresentation(
                state: $aram, initialSession: session, viewModel: viewModel,
                onGalleryChange: { updateGallery($0, sessionID: session.id) }
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

    private var presentedSession: Binding<ARAMState.Session?> {
        Binding {
            aram.phase == .closing ? nil : aram.session
        } set: { session in
            if session == nil, let id = aram.session?.id {
                aram.close(sessionID: id)
            }
        }
    }

    private func receiveShake(_ event: DeviceShakeEvent) {
        // From the catalog use active filters; within a detail/session preserve
        // the established all-champions pool, excluding the last selected ID.
        let inDetail = aram.session != nil || aram.pendingChampionID != nil || !navigationPath.isEmpty
        let candidates = inDetail ? viewModel.champions : filteredChampions
        let result = aram.receiveShake(
            eventID: event.id, timestamp: event.timestamp, isActive: isActive,
            sceneIsActive: scenePhase == .active, candidateIDs: candidates.map(\.id),
            currentChampionID: navigationPath.last
        )
        guard result.isAccepted else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        returnToCatalogIfOpening()
    }

    private func updateGallery(_ presented: Bool, sessionID: UUID?) {
        aram.setGalleryPresented(presented, sessionID: sessionID,
                                 isActive: isActive, sceneIsActive: scenePhase == .active)
        returnToCatalogIfOpening()
    }

    private func returnToCatalogIfOpening() {
        // Only entering ARAM from a manual detail clears the catalog's path.
        // Rerolls never push, pop or otherwise modify normal navigation.
        guard aram.phase == .opening, !navigationPath.isEmpty else { return }
        var noAnimation = Transaction()
        noAnimation.disablesAnimations = true
        withTransaction(noAnimation) {
            navigationPath.removeAll()
        }
    }
}

private struct ARAMChampionPresentation: View {
    @Binding var state: ARAMState
    let initialSession: ARAMState.Session
    @ObservedObject var viewModel: ChampionViewModel
    let onGalleryChange: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var session: ARAMState.Session {
        guard let current = state.session, current.id == initialSession.id else { return initialSession }
        return current
    }

    var body: some View {
        NavigationStack {
            Group {
                if let champion = viewModel.champions.first(where: { $0.id == session.championID }) {
                    ChampionDetailView(champion: champion, viewModel: viewModel,
                                       onGalleryChange: onGalleryChange)
                        .id(session.revision)
                        .transition(.opacity)
                } else {
                    LeagueErrorState(
                        message: "Ce champion n’est plus disponible dans le catalogue. Réessayez ou secouez l’iPhone pour un nouveau tirage."
                    ) {
                        viewModel.fetchChampionsFromFirebase()
                    }
                    .padding(LeagueTheme.Space.md)
                }
            }
            .animation(reduceMotion ? nil : LeagueMotion.quick, value: session.revision)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        state.close(sessionID: initialSession.id)
                    } label: {
                        Label("Fermer ARAM", systemImage: "xmark")
                    }
                    .accessibilityLabel("Fermer le mode ARAM et revenir au catalogue")
                }
            }
        }
        .tint(LeagueTheme.gold)
        .background(LeagueTheme.background)
        .onAppear { state.presentationDidAppear(sessionID: initialSession.id) }
    }
}
