import SwiftUI
import SwiftData

@main
struct LeagueDexApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView() // L'application démarre maintenant avec la barre des onglets
        }
        // Déclare les deux modèles pour la base de données locale
        .modelContainer(for: [DBChampion.self, DBItem.self])
    }
}
