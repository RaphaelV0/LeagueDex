# LeagueDex

**Projet iOS du Master 2 CCM — Raphaël Verchain**

LeagueDex est une application iOS en **SwiftUI**, développée dans le cadre de mon Master 2 CCM. Inspirée de *League of Legends*, elle propose une encyclopédie des champions et des objets, des favoris et une carte de lieux e-sport.

## Fonctionnalités

- **Compte** : inscription, connexion et gestion de session avec Firebase Authentication.
- **Champions** : recherche, filtres par rôle, statistiques selon le niveau, compétences, histoires et galerie de skins.
- **Favoris** : sauvegarde et synchronisation des champions favoris sur Firestore.
- **ARAM** : secouer physiquement l'iPhone depuis l'onglet Champions ou une fiche champion pour obtenir un champion aléatoire ; une nouvelle secousse renouvelle le tirage.
- **Objets** : catalogue, recherche, prix, filtres et descriptions.
- **Lieux** : carte MapKit des lieux e-sport, itinéraires dans Apple Plans et ajout de lieux après vérification de leur adresse.

Les quatre onglets sont **Champions**, **Objets**, **Lieux** et **Compte**.

## Technologies utilisées

- **Swift, SwiftUI** et architecture MVVM légère.
- **Firebase Authentication** pour les comptes et **Cloud Firestore** pour les données et les favoris.
- **Riot Data Dragon** pour les illustrations et informations complémentaires.
- **MapKit** et **Core Location** pour les lieux et la position facultative.
- **UIKit** pour la détection du geste de secousse.

Certaines données déjà consultées sont conservées en cache pour une consultation hors ligne.

## Installation

### Prérequis

- Un Mac avec **Xcode** et un SDK iOS compatible.
- Un projet **Firebase** avec Authentication et Cloud Firestore.
- Un iPhone physique pour tester le mode ARAM avec le geste de secousse.

### Mise en place

1. Cloner le dépôt et ouvrir `LeagueDex.xcodeproj` dans Xcode.
2. Attendre la résolution des dépendances Firebase par Xcode.
3. Vérifier que `LeagueDex/Resources/GoogleService-Info.plist` et l'identifiant d'application dans Xcode correspondent à l'application déclarée dans Firebase.
4. Activer **Email/Password** dans **Firebase Console → Authentication → Sign-in method**.
5. Préparer dans Cloud Firestore les collections `champions`, `items` et `venues` avec les données attendues par les modèles Swift de `LeagueDex/Models`.
6. Déployer sur le bon projet Firebase les règles présentes dans `firestore.rules` (elles ne sont pas déployées automatiquement).
7. Sélectionner le schéma **LeagueDex** et un appareil ou simulateur compatible, puis lancer avec **⌘ + R**.

La version minimale actuellement configurée dans Xcode est **iOS 26.5**. Les secousses doivent être testées sur un iPhone physique.

Pour ajouter un lieu, ouvrir **Lieux → +**, saisir une adresse, la vérifier avec Apple Plans, puis confirmer l'ajout. Cette fonction nécessite une connexion réseau et les règles Firestore appropriées.

Le projet dispose également d'une validation automatisée iOS via GitHub Actions, fondée sur Xcode et Swift, sans installation de Node.js.

## Auteur

**Raphaël Verchain** — Projet iOS de **Master 2 CCM**.

LeagueDex est un projet pédagogique sans affiliation avec Riot Games. *League of Legends* et les éléments associés appartiennent à leurs ayants droit respectifs.
