import SwiftUI

/// Four straightforward tabs for the Master 2 project.
/// Firebase authentication is handled once by LeagueDexApp.
struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var champions = ChampionViewModel()
    @StateObject private var items = ItemViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            ChampionsView(isActive: selectedTab == 0)
                .tabItem { Label("Champions", systemImage: "person.3.fill") }
                .tag(0)

            ItemsView()
                .tabItem { Label("Objets", systemImage: "shield.lefthalf.filled") }
                .tag(1)

            VenuesMapView()
                .tabItem { Label("Lieux", systemImage: "map.fill") }
                .tag(2)

            AccountView()
                .tabItem { Label("Compte", systemImage: "person.crop.circle.fill") }
                .tag(3)
        }
        .safeAreaInset(edge: .top, spacing: 0) { SyncStatusBanner() }
        .environmentObject(champions)
        .environmentObject(items)
        .tint(LeagueTheme.gold)
        .toolbarBackground(LeagueTheme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}
