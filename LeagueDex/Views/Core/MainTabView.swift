import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

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
        }
        .tint(LeagueTheme.gold)
        .toolbarBackground(LeagueTheme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}
