import SwiftUI

struct BuildEditorView: View {
    @EnvironmentObject private var catalog: ChampionViewModel
    @EnvironmentObject private var armory: ItemViewModel
    @EnvironmentObject private var userData: UserDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CustomBuild
    @State private var showChampions = false
    @State private var showItems = false
    @State private var inspectedItem: DBItem?
    private let slots = [GridItem(.adaptive(minimum: 80, maximum: 110), spacing: LeagueTheme.Space.sm)]

    init(build: CustomBuild) { _draft = State(initialValue: build) }

    private var champion: DBChampion? { catalog.champions.first { $0.id == draft.championID } }
    private var valid: Bool {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && name.count <= 80 && !draft.championID.isEmpty && BuildInventory(itemIDs: draft.itemIDs).isValid
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LeagueTheme.Space.lg) {
                    VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                        Text("Nom du build").font(.headline).foregroundStyle(LeagueTheme.text)
                        TextField("Ex. Mon inventaire", text: $draft.name)
                            .textFieldStyle(.plain)
                            .padding(LeagueTheme.Space.md).leagueSurface(radius: LeagueTheme.Corner.medium)
                            .accessibilityLabel("Nom du build, 80 caractères maximum")
                        Text("\(draft.name.count) / 80 caractères")
                            .font(.caption).foregroundStyle(draft.name.count > 80 ? LeagueTheme.danger : LeagueTheme.muted)
                    }
                    Button { showChampions = true } label: {
                        HStack(spacing: LeagueTheme.Space.md) {
                            CompanionChampionIcon(champion: champion)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(champion?.name ?? (draft.championID.isEmpty ? "Choisir un champion" : "Champion indisponible (\(draft.championID))"))
                                    .font(.headline).foregroundStyle(LeagueTheme.text)
                                Text("Associer ce build à un champion").font(.caption).foregroundStyle(LeagueTheme.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(LeagueTheme.gold)
                        }
                        .padding(LeagueTheme.Space.md).leagueSurface()
                    }
                    .buttonStyle(.plain)

                    inventory
                    BuildCostLabel(itemIDs: draft.itemIDs, items: armory.items)
                    if !draft.itemIDs.isEmpty { itemProperties }
                    if let error = armory.errorMessage, armory.items.isEmpty {
                        LeagueErrorState(message: error) { armory.fetchItemsFromFirebase() }
                    }
                    Text("Les coûts et caractéristiques proviennent du catalogue. Les passifs et interactions ne sont pas additionnés automatiquement.")
                        .font(.footnote).foregroundStyle(LeagueTheme.muted)
                }
                .padding(LeagueTheme.Space.md)
                .padding(.bottom, LeagueTheme.Space.lg)
            }
            .background(LeagueTheme.background)
            .navigationTitle(draft.revision == 0 ? "Créer un build" : "Modifier le build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        userData.saveBuild(draft)
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
            .sheet(isPresented: $showChampions) {
                ChampionSelectionSheet(selectedID: draft.championID) { draft.championID = $0.id }
            }
            .sheet(isPresented: $showItems) {
                BuildItemSelectionSheet(occupiedSlots: draft.itemIDs.count) { item in
                    var inventory = BuildInventory(itemIDs: draft.itemIDs)
                    if inventory.add(item.id) { draft.itemIDs = inventory.itemIDs }
                }
            }
            .sheet(item: $inspectedItem) { item in
                NavigationStack {
                    ItemDetailView(item: item)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { inspectedItem = nil } } }
                }
                .tint(LeagueTheme.gold)
            }
        }
        .tint(LeagueTheme.gold)
    }

    private var inventory: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            LeagueSectionHeader(title: "Inventaire", subtitle: "\(draft.itemIDs.count) / 6 emplacements · touchez un objet pour sa fiche")
            LazyVGrid(columns: slots, alignment: .leading, spacing: LeagueTheme.Space.md) {
                ForEach(0..<max(BuildInventory.maximumSlots, draft.itemIDs.count), id: \.self) { index in
                    let id = draft.itemIDs.indices.contains(index) ? draft.itemIDs[index] : nil
                    let item = armory.items.first { $0.id == id }
                    VStack(spacing: 0) {
                        Button {
                            if let item { inspectedItem = item }
                            else if id == nil { showItems = true }
                        } label: {
                            BuildItemIcon(item: item, isEmpty: id == nil, size: 58)
                                .padding(.vertical, LeagueTheme.Space.sm)
                        }
                        .buttonStyle(.plain)
                        .disabled(id != nil && item == nil)
                        .accessibilityLabel(id == nil ? "Ajouter un objet à l’emplacement \(index + 1)" : "Fiche de \(item?.name ?? "l’objet indisponible \(id ?? "")")")
                        if id != nil {
                            Button("Retirer") { removeItem(at: index) }
                                .font(.caption).foregroundStyle(LeagueTheme.danger)
                                .frame(minWidth: 70, minHeight: 44)
                                .accessibilityLabel("Retirer \(item?.name ?? "l’objet \(id ?? "")") de l’emplacement \(index + 1)")
                        } else {
                            Text("\(index + 1)").font(.caption).foregroundStyle(LeagueTheme.muted).frame(height: 44)
                        }
                    }
                }
            }
            if draft.itemIDs.count > BuildInventory.maximumSlots {
                Text("Retirez des objets pour revenir à six emplacements.").font(.footnote).foregroundStyle(LeagueTheme.danger)
            }
        }
    }

    private var itemProperties: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            LeagueSectionHeader(title: "Caractéristiques des objets")
            ForEach(Array(draft.itemIDs.enumerated()), id: \.offset) { index, id in
                if let item = armory.items.first(where: { $0.id == id }) {
                    DisclosureGroup("\(index + 1). \(item.name) · \(item.totalCost) PO") {
                        Text(item.itemDescription.removingHTML())
                            .font(.subheadline).foregroundStyle(LeagueTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, LeagueTheme.Space.sm)
                    }
                    .padding(LeagueTheme.Space.md).leagueSurface()
                } else {
                    Text("Emplacement \(index + 1) : objet \(id) indisponible dans ce catalogue.")
                        .font(.footnote).foregroundStyle(LeagueTheme.muted)
                }
            }
        }
    }

    private func removeItem(at index: Int) {
        var inventory = BuildInventory(itemIDs: draft.itemIDs)
        inventory.remove(at: index)
        draft.itemIDs = inventory.itemIDs
    }
}

private struct BuildItemSelectionSheet: View {
    @EnvironmentObject private var armory: ItemViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    let occupiedSlots: Int
    let onSelect: (DBItem) -> Void

    private var matches: [DBItem] {
        armory.items.filter { search.isEmpty || $0.name.localizedStandardContains(search) || $0.plaintext.localizedStandardContains(search) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if armory.isLoading && armory.items.isEmpty {
                    LeagueLoadingState(message: "Chargement de l’armurerie…")
                } else if let error = armory.errorMessage, armory.items.isEmpty {
                    LeagueErrorState(message: error) { armory.fetchItemsFromFirebase() }
                } else if matches.isEmpty {
                    LeagueEmptyState(title: "Aucun objet", detail: "Essayez un autre nom ou rechargez l’armurerie.")
                } else {
                    List(matches) { item in
                        Button {
                            guard occupiedSlots < BuildInventory.maximumSlots else { return }
                            onSelect(item)
                            dismiss()
                        } label: {
                            HStack(spacing: LeagueTheme.Space.sm) {
                                BuildItemIcon(item: item, size: 44).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name).font(.headline).foregroundStyle(LeagueTheme.text)
                                    Text(item.plaintext).font(.caption).foregroundStyle(LeagueTheme.muted)
                                    Text("\(item.totalCost) PO").font(.caption.weight(.semibold)).foregroundStyle(LeagueTheme.gold)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityLabel("Ajouter \(item.name), \(item.totalCost) pièces d’or")
                        .listRowBackground(LeagueTheme.surface)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(LeagueTheme.background)
            .searchable(text: $search, prompt: "Nom ou caractéristique")
            .navigationTitle("Choisir un objet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
        }
        .tint(LeagueTheme.gold)
    }
}
