import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 3
    @StateObject private var champions = ChampionViewModel()
    @StateObject private var items = ItemViewModel()
    @StateObject private var userData: UserDataStore
    @StateObject private var daily = DailyChampionStore()
    @StateObject private var quiz = QuizViewModel()

    init(uid: String) {
        _userData = StateObject(wrappedValue: UserDataStore(uid: uid))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CompanionHubView()
                .tabItem { Label("Accueil", systemImage: "house.fill") }
                .tag(3)
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
            VenuesMapView(uid: userData.uid)
                .tabItem {
                    Label("Lieux", systemImage: "map.fill")
                }
                .tag(2)

        }
        .safeAreaInset(edge: .top, spacing: 0) { SyncStatusBanner() }
        .environmentObject(champions)
        .environmentObject(items)
        .environmentObject(userData)
        .environmentObject(daily)
        .environmentObject(quiz)
        .tint(LeagueTheme.gold)
        .toolbarBackground(LeagueTheme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}
