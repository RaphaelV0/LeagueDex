import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // 1er Onglet : Champions & ARAM
            ChampionsView()
                .tabItem {
                    Label("Champions", systemImage: "person.3.fill")
                }
            
            // 2ème Onglet : Objets / Armurerie
            ItemsView()
                .tabItem {
                    Label("Objets", systemImage: "shield.fill")
                }
            
            // 3ème Onglet : Carte des Lieux E-sport & LAN (NOUVEAU)
            VenuesMapView()
                .tabItem {
                    Label("Lieux", systemImage: "map.fill")
                }
        }
    }
}
