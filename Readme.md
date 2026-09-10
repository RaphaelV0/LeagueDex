# ⚔️ LeagueDex

Une application iOS native, fluide et moderne, servant d'encyclopédie (façon Pokédex) pour l'univers de **League of Legends**. 
Retrouvez toutes les informations sur vos champions préférés et les objets du jeu, avec une interface premium et un support **100% hors-ligne**.

## 🌟 Fonctionnalités

*   **📚 Encyclopédie des Champions :** Accédez aux statistiques dynamiques (évolutives du niveau 1 à 18), aux descriptions détaillées des compétences, aux astuces de jeu (alliés/ennemis) et à la galerie complète des skins.
*   **🛡️ Armurerie (Objets) :** Explorez tous les objets du jeu, leurs coûts (base, total, revente) et leurs statistiques.
*   **💾 Mode Hors-Ligne (Offline First) :** Grâce à `SwiftData` et un système de mise en cache d'images sur-mesure (`CachedAsyncImage`), l'application reste entièrement fonctionnelle sans connexion internet après le premier chargement.
*   **🎨 UI/UX Premium :** Design soigné utilisant le *Glassmorphism* (`.ultraThinMaterial`), des effets de parallaxe sur les bannières, des transitions fluides et des retours haptiques (vibrations) pour une expérience utilisateur optimale.
*   **❤️ Favoris & Filtres :** Marquez vos champions préférés et trouvez rapidement votre personnage idéal grâce au système de filtrage par classes (Assassin, Mage, Tank, etc.) et à la barre de recherche.

## 🛠️ Technologies & Architecture

*   **Langage :** Swift
*   **Interface :** SwiftUI
*   **Base de données locale :** SwiftData
*   **Réseau & Asynchronisme :** `async/await` et URLSession
*   **Architecture :** MVVM (Model-View-ViewModel) + "Lazy Fetching" (chargement des détails à la demande pour économiser la data).
*   **API :** [Riot Games Data Dragon](https://developer.riotgames.com/docs/lol) // Pas accessible avec la connexion de l'UPJV

## 🚀 Installation & Prérequis

1. **Prérequis :** Xcode 15+ et cible iOS 17.0 minimum (requis par SwiftData).
2. Clonez ou téléchargez ce projet sur votre Mac.
3. Ouvrez le projet dans Xcode.
4. Sélectionnez un simulateur (ex: iPhone 15 Pro) ou branchez votre iPhone.
5. Lancez l'application (`Cmd + R`). 
*Note : Lors du tout premier lancement, une connexion internet est requise pour constituer la base de données locale.*

## 📂 Structure du projet (Aperçu)

*   `Models.swift` : Définition des structures de l'API Riot et des schémas locaux (`@Model`).
*   `ChampionViewModel.swift` & `ItemViewModel.swift` : Logique de téléchargement, parsing JSON et synchronisation avec SwiftData.
*   `Views/` : 
    *   `ContentView.swift` : Écran d'accueil, grille des champions et filtres.
    *   `ChampionDetailView.swift` : Fiche détaillée avec effet parallaxe, sorts et stats.
    *   `ItemsView.swift` : Interface de l'armurerie.
*   `Components/` : Composants réutilisables comme `CachedAsyncImage` et les cartes de statistiques.

## ⚖️ Mentions légales

*LeagueDex a été créé dans le cadre d'un projet de développement indépendant et n'est pas approuvé par Riot Games. L'application ne reflète pas les vues ou opinions de Riot Games ou de toute personne officiellement impliquée dans la production ou la gestion de League of Legends. League of Legends et Riot Games sont des marques commerciales ou des marques déposées de Riot Games, Inc.*
