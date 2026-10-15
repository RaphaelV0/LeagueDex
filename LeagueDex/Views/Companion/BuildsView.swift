import SwiftUI

struct BuildsView: View {
    @EnvironmentObject private var catalog: ChampionViewModel
    @EnvironmentObject private var armory: ItemViewModel
    @EnvironmentObject private var userData: UserDataStore
    @State private var editing: CustomBuild?
    @State private var deleting: CustomBuild?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
                LeagueSectionHeader(title: "Mes builds", subtitle: "Un champion, six emplacements et votre inventaire personnel.")
                Button {
                    editing = CustomBuild(name: "", championID: "", itemIDs: [])
                } label: {
                    Label("Créer un build", systemImage: "plus")
                }
                .buttonStyle(LeagueActionButtonStyle())

                if !userData.conflictedBuilds.isEmpty { conflicts }
                if let error = userData.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(LeagueTheme.danger)
                }
                if userData.builds.isEmpty {
                    LeagueEmptyState(title: "Votre inventaire vous attend", detail: "Créez votre premier build pour le retrouver sur vos appareils.", icon: "square.grid.3x2")
                }
                ForEach(userData.builds) { build in
                    buildCard(build)
                }
                if !userData.pendingBuildIDs.isEmpty {
                    Button("Réessayer la synchronisation") { userData.retryPendingBuilds() }
                        .buttonStyle(LeagueActionButtonStyle(prominent: false))
                }
            }
            .padding(LeagueTheme.Space.md)
            .padding(.bottom, LeagueTheme.Space.lg)
        }
        .background(LeagueTheme.background)
        .navigationTitle("Builds")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { build in BuildEditorView(build: build) }
        .confirmationDialog("Supprimer ce build ?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            if let deleting {
                Button("Supprimer « \(deleting.name) »", role: .destructive) { userData.deleteBuild(deleting) }
            }
            Button("Annuler", role: .cancel) { deleting = nil }
        } message: {
            Text("La suppression sera synchronisée avec votre compte.")
        }
    }

    private func buildCard(_ build: CustomBuild) -> some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            HStack(alignment: .top, spacing: LeagueTheme.Space.sm) {
                Button { editing = build } label: {
                    HStack(spacing: LeagueTheme.Space.sm) {
                        CompanionChampionIcon(champion: catalog.champions.first { $0.id == build.championID }, size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(build.name).font(.headline).foregroundStyle(LeagueTheme.text)
                            Text(championName(build.championID)).font(.caption).foregroundStyle(LeagueTheme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 44)
                }
                .accessibilityHint("Modifier le build")
                Menu {
                    Button("Modifier", systemImage: "pencil") { editing = build }
                    Button("Dupliquer", systemImage: "plus.square.on.square") { userData.duplicateBuild(build) }
                    Button("Supprimer", systemImage: "trash", role: .destructive) { deleting = build }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(width: 44, height: 44).foregroundStyle(LeagueTheme.gold)
                }
                .accessibilityLabel("Actions du build \(build.name)")
            }
            BuildInventoryStrip(itemIDs: build.itemIDs, items: armory.items)
            BuildCostLabel(itemIDs: build.itemIDs, items: armory.items)
            if userData.pendingBuildIDs.contains(build.id) {
                Label(userData.conflictingBuildIDs.contains(build.id) ? "Conflit à résoudre" : "En attente de synchronisation",
                      systemImage: userData.conflictingBuildIDs.contains(build.id) ? "exclamationmark.triangle" : "arrow.triangle.2.circlepath")
                    .font(.caption).foregroundStyle(LeagueTheme.gold)
            }
        }
        .padding(LeagueTheme.Space.md).leagueSurface()
    }

    private var conflicts: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            LeagueSectionHeader(title: "Modifications en conflit", subtitle: "Une version plus récente existe sur un autre appareil.")
            // Includes deleted pending builds: a conflicting deletion must remain recoverable.
            ForEach(userData.conflictedBuilds) { build in
                VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                    Text(build.name).font(.headline).foregroundStyle(LeagueTheme.text)
                    Text(build.deleted ? "La suppression locale n’a pas remplacé la version distante." : "Votre version locale est conservée sur cet appareil.")
                        .font(.footnote).foregroundStyle(LeagueTheme.muted)
                    Button("Conserver une copie de mon build") {
                        userData.duplicateBuild(build)
                        userData.useServerBuild(id: build.id)
                    }
                    .buttonStyle(LeagueActionButtonStyle(prominent: false))
                    Button("Recharger la version synchronisée") { userData.useServerBuild(id: build.id) }
                        .buttonStyle(LeagueActionButtonStyle(prominent: false))
                }
                .padding(LeagueTheme.Space.md).leagueSurface()
            }
        }
    }

    private func championName(_ id: String) -> String {
        catalog.champions.first { $0.id == id }?.name ?? "Champion indisponible (\(id))"
    }
}

struct BuildInventoryStrip: View {
    let itemIDs: [String]
    let items: [DBItem]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<BuildInventory.maximumSlots, id: \.self) { index in
                let id = itemIDs.indices.contains(index) ? itemIDs[index] : nil
                let item = items.first { $0.id == id }
                BuildItemIcon(item: item, isEmpty: id == nil)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(id == nil ? "Emplacement \(index + 1) vide" : "Emplacement \(index + 1) : \(item?.name ?? "objet indisponible")")
            }
        }
    }
}

struct BuildItemIcon: View {
    let item: DBItem?
    var isEmpty = false
    var size: CGFloat = 38

    var body: some View {
        CachedAsyncImage(url: item?.iconURL) { image in image.resizable().scaledToFit() } placeholder: {
            ZStack {
                LeagueTheme.elevated
                Image(systemName: isEmpty ? "plus" : "questionmark")
                    .foregroundStyle(LeagueTheme.muted)
            }
        }
        .imageDimension(size * 2)
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: LeagueTheme.Corner.small))
        .overlay {
            RoundedRectangle(cornerRadius: LeagueTheme.Corner.small).strokeBorder(LeagueTheme.border, lineWidth: 1)
        }
    }
}

struct BuildCostLabel: View {
    let itemIDs: [String]
    let items: [DBItem]

    private var cost: BuildInventory.Cost {
        BuildInventory(itemIDs: itemIDs).cost(prices: Dictionary(items.map { ($0.id, $0.totalCost) }, uniquingKeysWith: { _, latest in latest }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("\(cost.isComplete ? "Coût total" : "Sous-total connu") : \(cost.knownSubtotal.formatted()) PO", systemImage: "circle.hexagongrid.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(LeagueTheme.gold)
            if !cost.isComplete {
                Text("Coût total indisponible : \(cost.missingItemIDs.count) référence(s) absente(s) du catalogue. \(cost.missingItemIDs.joined(separator: ", "))")
                    .font(.caption).foregroundStyle(LeagueTheme.muted)
            }
        }
    }
}
