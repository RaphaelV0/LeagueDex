# LeagueDex — Projet Master 2 iOS

LeagueDex est une encyclopédie **League of Legends** réalisée en SwiftUI. Le but est de présenter une application iPhone fiable et facile à expliquer : Firebase, une interface native, une carte et le capteur de mouvement.

## Fonctionnalités conservées

1. **Compte Firebase** : inscription, connexion, déconnexion et session persistante avec Firebase Authentication.
2. **Champions** : catalogue Firestore, recherche, filtres, fiches, statistiques du niveau 1 au niveau 18, compétences, histoires et galerie de skins avec zoom.
3. **Favoris** : sélection de champions synchronisée dans `users/{uid}/favorites`.
4. **Mode ARAM** : dans l'onglet Champions, **secouer physiquement l'iPhone** choisit un champion aléatoire. Une deuxième secousse **depuis cette même fiche** remplace le champion sans empiler les pages. La fiche ouverte manuellement dans Champions accepte aussi ce geste. **Aucun bouton de tirage.**
5. **Objets** : catalogue Firestore des objets, recherche, description et prix.
6. **Lieux e-sport** : carte MapKit en lecture seule des documents Firestore `venues`, fiche du lieu et itinéraire Apple Plans. La localisation reste facultative.

Le menu comporte quatre onglets : **Champions, Objets, Lieux, Compte**.

Les fonctionnalités commerciales et communautaires avancées (créateur de builds, comparateur, quiz, défis quotidiens, propositions et modération de lieux) ont été **retirées du code**.

## Architecture

- Swift, SwiftUI et MVVM léger.
- **Firebase Authentication** pour l'identification.
- **Cloud Firestore** comme source des champions, objets, lieux et favoris.
- **Cache persistant Firestore** pour les documents déjà lus lorsque le réseau disparaît.
- Riot Data Dragon : images et détails complémentaires à la demande, avec cache disque. Le catalogue de secours Data Dragon n'est utilisé que hors ligne si Firestore ne dispose pas des données.
- MapKit et CoreLocation pour afficher les lieux et, avec autorisation, la position.
- Une sélection ARAM en Swift pur (`ARAMCore/ARAMState.swift`) et un récepteur UIKit du geste piloté par `Services/ARAMShakeController.swift`.

**Sécurité :** les utilisateurs connectés lisent les catalogues, mais seul un compte administrateur peut écrire dans les collections publiques. Chaque utilisateur modifie uniquement ses propres favoris. L'app ne recrée pas les catalogues en écrivant depuis l'iPhone.

## Démarrer dans Xcode

1. Ouvrir `LeagueDex.xcodeproj` dans Xcode.
2. Laisser résoudre les dépendances Firebase.
3. Vérifier `GoogleService-Info.plist`, l'identifiant de l'app iOS et le projet Firebase.
4. Activer **Email/Password** dans Firebase Console → Authentication → Sign-in method.
5. Vérifier les collections `champions`, `items` et `venues` sur le projet Firestore configuré.
6. Sélectionner le schéma **LeagueDex**, un iPhone ou simulateur et lancer avec **⌘ + R**.

Le **vrai shake** doit être testé sur un **iPhone physique**, pas seulement dans le simulateur.

## Tester

Sur macOS avec Xcode :

```bash
swift test --parallel
bash scripts/validate-ios.sh
```

Pour les règles Firestore (émulateur Firebase, Node.js et Java installés) :

```bash
npm ci
npm run test:rules
```

Les modifications de `firestore.rules` doivent être examinées et **déployées manuellement** dans le projet Firebase approprié. Aucun script ne modifie ni n'efface la base de production.

Les anciens documents de builds, quiz, comparaisons ou contributions peuvent rester dans Firestore : **supprimer du code n'efface pas les données**. Les règles minimalistes de cette version n'exposent plus ces collections au client.

Consulter [la recette ARAM](docs/ARAM_RELIABILITY.md) avant la soutenance.

## Mentions légales

LeagueDex est un projet pédagogique non affilié à Riot Games. League of Legends et ses éléments appartiennent à leurs ayants droit respectifs.
