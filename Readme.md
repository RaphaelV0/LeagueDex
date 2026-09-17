# ⚔️ LeagueDex

## Raphaël Verchain — Master 2 CCM (Cours iOS)

Une application iOS native, fluide et moderne, développée dans le cadre de mon Master 2 (cours iOS). Elle sert d'encyclopédie (façon Pokédex) pour l'univers de **League of Legends**. 
Retrouvez toutes les informations sur vos champions préférés, les objets du jeu, et localisez les lieux e-sport autour de vous grâce à une architecture cloud moderne, des capteurs matériels natifs et un support hors-ligne optimisé.

---

## 🌟 Fonctionnalités Principales

*   **📚 Encyclopédie des Champions :** Accédez aux statistiques dynamiques (évolutives du niveau 1 à 18), aux descriptions détaillées des compétences interactives, aux astuces de jeu (alliés/ennemis) et à la galerie complète des skins.
*   **🛡️ Armurerie (Objets) :** Explorez tous los objets du jeu, leurs coûts (base, total, revente) et leurs statistiques détaillées.
*   **🎲 Mode ARAM (Accéléromètre) :** Secouez physiquement votre iPhone pour déclencher un tirage au sort instantané parmi vos champions filtrés et afficher directement leur fiche technique complète.
*   **📍 Lieux E-sport & LAN (Géolocalisation) :** Une carte interactive intégrée (`MapKit`) qui détecte votre position GPS en temps réel (`CoreLocation`), liste les bars e-sport et salles LAN à proximité, calcule la distance exacte et intègre un bouton d'itinéraire vers l'application Plans.
*   **☁️ Cloud & Hors-Ligne (Firebase Firestore) :** Synchronisation en temps réel des données distantes et gestion du cache local pour un fonctionnement entièrement transparent même sans connexion Internet.
*   **🎨 UI/UX Premium :** Design soigné utilisant le *Glassmorphism* (`.ultraThinMaterial`), des effets de parallaxe sur les bannières, un cache d'images sur-mesure (`CachedAsyncImage`) et des retours haptiques (vibrations).
*   **❤️ Favoris & Filtres :** Marquez vos champions préférés et triez-les rapidement par classes (Assassin, Mage, Tank, etc.).

---

## 🛠️ Technologies & Architecture

*   **Langage :** Swift
*   **Interface :** SwiftUI
*   **Base de données & Cloud :** Firebase Firestore (avec persistance locale)
*   **Capteurs & Matériel :** 
    *   `CoreMotion` / `UIWindow` (Détection de secousse pour l'ARAM)
    *   `CoreLocation` & `MapKit` (Géolocalisation et cartographie interactive)
*   **Réseau & Asynchronisme :** `async/await` et URLSession (API Riot Games Data Dragon)
*   **Architecture :** MVVM (Model-View-ViewModel) + "Lazy Fetching" (chargement des détails à la demande).

---

## 🚀 Installation & Prérequis

1. **Prérequis :** Xcode 15+ et cible iOS 17.0 minimum.
2. Clonez ou téléchargez ce projet sur votre Mac.
3. Ouvrez le projet dans Xcode et assurez-vous que le package **FirebaseFirestore** est correctement lié.
4. Configurez les autorisations de localisation dans le fichier `Info.plist` (`Privacy - Location When In Use Usage Description`).
5. Sélectionnez un simulateur (ex: iPhone Pro avec une position GPS simulée via le menu *Debug > Location*) ou branchez votre iPhone.
6. Lancez l'application (`Cmd + R`).

---

## 📂 Structure du projet

*   `App/` 
    *   `LeagueDexApp.swift` : Point d'entrée et initialisation de Firebase (`AppDelegate`).
*   `Components/` 
    *   `CachedAsyncImage.swift` : Système de cache d'images local sur-mesure.
    *   `ChampionCard.swift` & `SpellIcon.swift` : Composants graphiques réutilisables.
*   `Models/` 
    *   `Champion.swift` : Structures de données des champions (API Riot et Firestore).
    *   `DBVenue.swift` : Modèle de données pour les lieux e-sport.
    *   `Item.swift` : Structures de données de l'armurerie.
*   `Utils/` 
    *   `DeviceShakeViewModifier.swift` : Gestionnaire de l'accéléromètre (Mode ARAM).
    *   `LocationManager.swift` : Gestionnaire de géolocalisation (`CoreLocation`).
    *   `String+Extension.swift` : Nettoyage des balises HTML des descriptions.
*   `ViewModels/` 
    *   `ChampionViewModel.swift` & `ItemViewModel.swift` : Logique métier et synchronisation avec Firestore.
*   `Views/` 
    *   `Champions/` : 
        *   `ChampionsView.swift` : Catalogue, filtres, recherche et déclencheur ARAM.
        *   `ChampionDetailView.swift` : Fiche détaillée (stats par niveau, sorts, skins).
    *   `Core/` : 
        *   `MainTabView.swift` : Navigation principale par onglets.
    *   `Items/` : 
        *   `ItemsView.swift` : Interface de l'armurerie et détails des objets.
    *   `VenuesMapView.swift` : Carte interactive et gestion des lieux e-sport.

---

## ⚖️ Mentions légales

*LeagueDex a été créé dans le cadre d'un projet universitaire (Master 2) et n'est pas approuvé par Riot Games. L'application ne reflète pas les vues ou opinions de Riot Games ou de toute personne officiellement impliquée dans la production ou la gestion de League of Legends. League of Legends et Riot Games sont des marques commerciales ou des marques déposées de Riot Games, Inc.*