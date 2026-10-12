import SwiftUI
import UIKit

private enum ItemPriceFilter: String, CaseIterable, Identifiable {
    case all = "Tous"
    case budget = "1–1500"
    case medium = "1501–3000"
    case premium = "3001+"

    var id: Self { self }

    func includes(_ price: Int) -> Bool {
        switch self {
        case .all: return true
        case .budget: return price <= 1500
        case .medium: return price > 1500 && price <= 3000
        case .premium: return price > 3000
        }
    }
}

private enum ItemSortOrder: String {
    case expensive = "Prix décroissant"
    case affordable = "Prix croissant"
    case name = "Nom A–Z"
}

struct ItemsView: View {
    @StateObject private var viewModel = ItemViewModel()
    @State private var searchText = ""
    @State private var priceFilter: ItemPriceFilter = .all
    @State private var sortOrder: ItemSortOrder = .expensive

    private var filteredItems: [DBItem] {
        let matches = viewModel.items.filter { item in
            let matchesText = searchText.isEmpty
                || item.name.localizedStandardContains(searchText)
                || item.plaintext.localizedStandardContains(searchText)
            return matchesText && priceFilter.includes(item.totalCost)
        }
        return matches.sorted { lhs, rhs in
            switch sortOrder {
            case .expensive:
                return lhs.totalCost == rhs.totalCost
                    ? lhs.name < rhs.name : lhs.totalCost > rhs.totalCost
            case .affordable:
                return lhs.totalCost == rhs.totalCost
                    ? lhs.name < rhs.name : lhs.totalCost < rhs.totalCost
            case .name:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LeagueTheme.Space.sm) {
                        ForEach(ItemPriceFilter.allCases) { filter in
                            LeagueFilterChip(title: filter.rawValue, isSelected: priceFilter == filter) {
                                UISelectionFeedbackGenerator().selectionChanged()
                                priceFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal, LeagueTheme.Space.md)
                    .padding(.vertical, LeagueTheme.Space.sm)
                }
                .background(LeagueTheme.surface)

                HStack {
                    VStack(alignment: .leading, spacing: LeagueTheme.Space.xs) {
                        Text("Armurerie").font(.headline).foregroundStyle(LeagueTheme.text)
                        Text("\(filteredItems.count) objet(s)")
                            .font(.caption).foregroundStyle(LeagueTheme.muted)
                    }
                    Spacer()
                    Menu {
                        Button(ItemSortOrder.expensive.rawValue) { sortOrder = .expensive }
                        Button(ItemSortOrder.affordable.rawValue) { sortOrder = .affordable }
                        Button(ItemSortOrder.name.rawValue) { sortOrder = .name }
                    } label: {
                        Label("Trier", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LeagueTheme.gold)
                            .frame(minHeight: 44)
                    }
                    .accessibilityLabel("Trier les objets")
                    .accessibilityValue(sortOrder.rawValue)
                }
                .padding(.horizontal, LeagueTheme.Space.md)
                .padding(.vertical, LeagueTheme.Space.sm)

                Group {
                    if let message = viewModel.errorMessage, viewModel.items.isEmpty {
                        LeagueErrorState(message: message) { viewModel.fetchItemsFromFirebase() }
                            .leagueReveal()
                    } else if viewModel.isLoading && viewModel.items.isEmpty {
                        LeagueItemListSkeleton()
                            .leagueReveal()
                    } else if filteredItems.isEmpty {
                        VStack(spacing: LeagueTheme.Space.sm) {
                            LeagueEmptyState(
                                title: "Aucun objet trouvé",
                                detail: "Essayez un autre nom ou une autre gamme de prix."
                            )
                            Button("Effacer les filtres") {
                                priceFilter = .all
                                searchText = ""
                            }
                            .buttonStyle(LeagueActionButtonStyle(prominent: false))
                            .padding(.horizontal, LeagueTheme.Space.lg)
                        }
                        .leagueReveal()
                    } else {
                        List(filteredItems) { item in
                            NavigationLink(destination: ItemDetailView(item: item)) {
                                HStack(spacing: LeagueTheme.Space.md) {
                                    CachedAsyncImage(url: item.iconURL) { image in
                                        image.resizable().scaledToFit()
                                    } placeholder: { LeagueTheme.elevated }
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
                                    Spacer(minLength: LeagueTheme.Space.xs)
                                    Label(item.totalCost.formatted(), systemImage: "circle.hexagongrid.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(LeagueTheme.gold)
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
            }
            .background(LeagueTheme.background)
            .navigationTitle("Armurerie")
            .searchable(text: $searchText, prompt: "Rechercher un objet...")
        }
    }
}

struct ItemDetailView: View {
    let item: DBItem
    private let priceColumns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(spacing: LeagueTheme.Space.lg) {
                CachedAsyncImage(url: item.iconURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    LeagueSkeletonBlock(radius: LeagueTheme.Corner.large)
                }
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: LeagueTheme.Corner.large))
                .overlay {
                    RoundedRectangle(cornerRadius: LeagueTheme.Corner.large)
                        .strokeBorder(LeagueTheme.border, lineWidth: 1)
                }
                .leagueReveal()

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

                VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                    LeagueSectionHeader(title: "Coûts", subtitle: "Coût initial, coût total et valeur de revente")
                    LazyVGrid(columns: priceColumns, spacing: LeagueTheme.Space.sm) {
                        PriceBox(title: "Coût de base", price: item.baseCost)
                        PriceBox(title: "Coût total", price: item.totalCost)
                        PriceBox(title: "Revente", price: item.sellPrice)
                    }
                }
                .leagueReveal()

                VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
                    LeagueSectionHeader(title: "Statistiques & Passifs")
                    Text(item.itemDescription.removingHTML())
                        .font(.body)
                        .foregroundStyle(LeagueTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(LeagueTheme.Space.md)
                        .leagueSurface()
                }
                .leagueReveal()
            }
            .padding(LeagueTheme.Space.md)
            .padding(.bottom, LeagueTheme.Space.lg)
        }
        .background(LeagueTheme.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}
