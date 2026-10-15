import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var champions = ChampionViewModel()
    @StateObject private var items = ItemViewModel()
    @StateObject private var userData: UserDataStore

    init(uid: String) {
        _userData = StateObject(wrappedValue: UserDataStore(uid: uid))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1er Onglet : Champions & ARAM
            ChampionsView(isActive: selectedTab == 0)
                .tabItem {
                    Label("Champions", systemImage: "person.3.fill")
                }
                .tag(0)
            
            // 2ème Onglet : Objets / Armurerie
            ItemsView()
                .tabItem {
                    Label("Objets", systemImage: "shield.lefthalf.filled")
                }
                .tag(1)
            
            // 3ème Onglet : Carte des Lieux E-sport & LAN (NOUVEAU)
            VenuesMapView()
                .tabItem {
                    Label("Lieux", systemImage: "map.fill")
                }
                .tag(2)

            AccountView()
                .tabItem { Label("Compte", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .safeAreaInset(edge: .top, spacing: 0) { SyncStatusBanner() }
        .environmentObject(champions)
        .environmentObject(items)
        .environmentObject(userData)
        .tint(LeagueTheme.gold)
        .toolbarBackground(LeagueTheme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}
