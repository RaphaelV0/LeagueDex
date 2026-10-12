import SwiftUI

struct ItemsView: View {
    @StateObject private var viewModel = ItemViewModel()
    @State private var searchText = ""

    var filteredItems: [DBItem] {
        if searchText.isEmpty { return viewModel.items }
        return viewModel.items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let message = viewModel.errorMessage, viewModel.items.isEmpty {
                    LeagueErrorState(message: message) { viewModel.fetchItemsFromFirebase() }
                } else if viewModel.isLoading && viewModel.items.isEmpty {
                    LeagueLoadingState(message: "Chargement de l'armurerie...")
                } else if filteredItems.isEmpty {
                    LeagueEmptyState(
                        title: "Aucun objet trouvé",
                        detail: "Essayez un autre nom d'objet."
                    )
                } else {
                    List(filteredItems) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            HStack(spacing: LeagueTheme.Space.md) {
                                CachedAsyncImage(url: item.iconURL) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    LeagueTheme.elevated
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: LeagueTheme.Corner.small))
                                .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: LeagueTheme.Space.xs) {
                                    Text(item.name)
                                        .font(.headline)
                                        .foregroundStyle(LeagueTheme.text)

                                    Text(item.plaintext)
                                        .font(.caption)
                                        .foregroundStyle(LeagueTheme.muted)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 0)

                                Label(item.totalCost.formatted(), systemImage: "circle.hexagongrid.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(LeagueTheme.gold)
                                    .labelStyle(.titleAndIcon)
                            }
                            .padding(.vertical, LeagueTheme.Space.xs)
                        }
                        .listRowBackground(LeagueTheme.surface)
                        .listRowSeparatorTint(LeagueTheme.border)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LeagueTheme.background)
            .navigationTitle("Armurerie")
            .searchable(text: $searchText, prompt: "Rechercher un objet...")
        }
    }
}

struct ItemDetailView: View {
    let item: DBItem

    var body: some View {
        ScrollView {
            VStack(spacing: LeagueTheme.Space.lg) {
                CachedAsyncImage(url: item.iconURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    LeagueTheme.elevated
                }
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: LeagueTheme.Corner.large))
                .overlay {
                    RoundedRectangle(cornerRadius: LeagueTheme.Corner.large)
                        .strokeBorder(LeagueTheme.border, lineWidth: 1)
                }

                VStack(spacing: LeagueTheme.Space.sm) {
                    Text(item.name)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(LeagueTheme.text)
                        .multilineTextAlignment(.center)

                    Text(item.plaintext)
                        .font(.subheadline)
                        .foregroundStyle(LeagueTheme.muted)
                        .multilineTextAlignment(.center)
                }

                HStack(alignment: .top, spacing: LeagueTheme.Space.sm) {
                    PriceBox(title: "Coût de base", price: item.baseCost)
                    PriceBox(title: "Coût total", price: item.totalCost)
                    PriceBox(title: "Revente", price: item.sellPrice)
                }

                VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
                    LeagueSectionHeader(title: "Statistiques & Passifs")
                    Text(item.itemDescription.removingHTML())
                        .font(.body)
                        .foregroundStyle(LeagueTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(LeagueTheme.Space.md)
                        .leagueSurface()
                }
            }
            .padding(LeagueTheme.Space.md)
            .padding(.bottom, LeagueTheme.Space.lg)
        }
        .background(LeagueTheme.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}
