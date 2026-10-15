import SwiftUI

/// Shared catalog selection for comparisons and build editors; no second listener.
struct ChampionSelectionSheet: View {
    @EnvironmentObject private var catalog: ChampionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var selectedID: String?
    var excludedID: String? = nil
    let onSelect: (DBChampion) -> Void

    private var matches: [DBChampion] {
        catalog.champions.filter {
            $0.id != excludedID && (search.isEmpty || $0.name.localizedStandardContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if catalog.isLoading && catalog.champions.isEmpty {
                    LeagueLoadingState(message: "Chargement des champions…")
                } else if let error = catalog.errorMessage, catalog.champions.isEmpty {
                    LeagueErrorState(message: error) { catalog.fetchChampionsFromFirebase() }
                } else if matches.isEmpty {
                    LeagueEmptyState(title: "Aucun champion", detail: "Essayez un autre nom.")
                } else {
                    List(matches) { champion in
                        Button {
                            onSelect(champion)
                            dismiss()
                        } label: {
                            HStack(spacing: LeagueTheme.Space.md) {
                                CompanionChampionIcon(champion: champion, size: 44)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(champion.name).font(.headline).foregroundStyle(LeagueTheme.text)
                                    Text(champion.tags.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(LeagueTheme.muted)
                                }
                                Spacer()
                                if champion.id == selectedID {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(LeagueTheme.gold)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityLabel("Choisir \(champion.name), \(champion.tags.joined(separator: ", "))")
                        .listRowBackground(LeagueTheme.surface)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(LeagueTheme.background)
            .navigationTitle("Choisir un champion")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Rechercher un champion")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
        .tint(LeagueTheme.gold)
    }
}

struct CompanionChampionIcon: View {
    let champion: DBChampion?
    var size: CGFloat = 52

    var body: some View {
        CachedAsyncImage(url: champion?.iconURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                LeagueTheme.elevated
                Image(systemName: "person.fill").foregroundStyle(LeagueTheme.muted)
            }
        }
        .imageDimension(size * 2)
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: LeagueTheme.Corner.medium))
        .accessibilityHidden(true)
    }
}
