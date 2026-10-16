import SwiftUI

/// A single, unobtrusive banner explains why cached Firestore data is shown.
struct SyncStatusBanner: View {
    @EnvironmentObject private var champions: ChampionViewModel
    @EnvironmentObject private var items: ItemViewModel
    @ObservedObject private var network = ConnectivityStore.shared
    @ObservedObject private var favorites = FavoritesStore.shared

    private var message: String? {
        if !network.isOnline { return "Hors ligne · données déjà téléchargées" }
        if let error = favorites.errorMessage { return error }
        if favorites.hasPendingWrites { return "Favoris en cours de synchronisation" }
        if champions.isFromCache || items.isFromCache || favorites.isFromCache {
            return "Synchronisation Firebase en cours"
        }
        return nil
    }

    var body: some View {
        if let message {
            Label(message, systemImage: network.isOnline ? "arrow.triangle.2.circlepath" : "wifi.slash")
                .font(.footnote)
                .foregroundStyle(LeagueTheme.gold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, LeagueTheme.Space.md)
                .padding(.vertical, LeagueTheme.Space.sm)
                .background(LeagueTheme.surface)
        }
    }
}
