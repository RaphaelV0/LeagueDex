# LeagueDex — Lot 5 : performances, accessibilité et validation

Branche : `performance/lot-5-accessibility`  
Base : `design/lot-4-premium-motion` — hérite des lots 1 à 4. Aucune PR ni modification directe de `main`.

## Changements techniques

### Images
- `CachedAsyncImage` : cache mémoire `NSCache` limité à 48 MiB / 150 images (existant), et cache disque asynchrone isolé par un `actor`.
- Durée de vie disque de 30 jours ; purge périodique des entrées obsolètes et limite de 160 MiB sur le dossier réservé.
- URLs distinctes conservées sous des clés SHA-256 de l'URL complète, sans collision entre les illustrations.
- Décodage de vignettes au format CGImage sur tâche de priorité `.utility` hors thread UI, construction de UIImage sur le thread UI.
- Résolution demandée ajustée aux dimensions réelles (cartes champions, détails, sorts, icônes et skins).
- Annulation liée au cycle de vie de la vue via `.task(id:)`. Une image corrompue n'est pas réenregistrée.

### Géolocalisation
- `LocationManager` n'effectue plus de suivi GPS continu : autorisation puis `requestLocation()` ponctuelle.
- L'état `isLocating` et les erreurs sont présentés dans la carte avec action « Réessayer » si pertinente.
- La permission `NSLocationWhenInUseUsageDescription` est déclarée dans les configurations Debug et Release du `Info.plist` généré.
- Tous les lieux existants, distances et itinéraires Apple Plans sont conservés.

### SwiftUI et accessibilité
- Tri/filtrage des champions et objets calculé une seule fois par rendu de liste (aucun cache de résultats obsolète).
- `SpellIcon` utilise `@ScaledMetric` et le héros des fiches champions adapte sa hauteur aux grandes polices.
- VoiceOver : meilleur libellé des objets, état du tri, traits sélectionnés des filtres et indications GPS.
- Animations et skeletons du lot 4 restent compatibles avec « Réduire les animations ».

## Vérifications automatisables

Lancer depuis la racine du dépôt :

```bash
python3 scripts/check_lot5.py
```

Ce script valide des **invariants statiques** du code ; il ne prouve pas que l'application compile ni ne mesure les performances.

Sur un Mac avec Xcode installé, lancer :

```bash
bash scripts/validate-ios.sh
```

Le script résout les dépendances et tente deux builds pour simulateur, en Debug et en Release. Les tests d'interface doivent ensuite être exécutés sur simulateur et/ou appareil.

## Checklist manuelle obligatoire

- [ ] **Compilation** : Debug et Release, aucun problème de concurrence Swift ni de package Firebase.
- [ ] **Navigation** : trois onglets, retour, recherche, filtres, favoris et tirage ARAM (bouton + secousse).
- [ ] **Images** : premier lancement / cache chaud / plusieurs skins / réseau lent ou interrompu / cache corrompu.
- [ ] **Mémoire** : ouvrir successivement plusieurs galeries de champions et revenir à la grille, sans croissance mémoire non bornée.
- [ ] **Localisation** : permission indéterminée, autorisée et refusée ; échec GPS, reprise et recentrage.
- [ ] **Carte** : sélection, filtre, distance, itinéraire Apple Plans.
- [ ] **Fiches** : niveau 1 à 18, sorts, historique des fonctionnalités existantes, description longue, liste de skins.
- [ ] **Armurerie** : filtres prix, tri, recherche, détails, état vide / erreur / réessayer.
- [ ] **VoiceOver** : valeurs des filtres et statistiques, sort sélectionné, boutons, erreurs, liens et cartes.
- [ ] **Dynamic Type** : taille standard, XXXL, tailles d'accessibilité ; petits et grands iPhone.
- [ ] **Réduire les animations** : skeleton statique, pas de déplacements forcés, flux fonctionnels identiques.
- [ ] **Contraste, zoom, safe areas** : portrait, paysage si supporté par la cible Xcode.

## Mesure de performance (à exécuter sur appareil)

Effectuer les comparaisons sur **le même appareil, la même connexion et le même volume de données**, avec la même configuration de compilation. Ne pas annoncer un gain avant de l'avoir mesuré.

| Scénario | Instrument / mesure | À noter |
|---|---|---|
| Démarrage à froid | Xcode Organizer / Instruments Time Profiler | Durée avant catalogue interactif |
| Première grille puis retour | Instruments Allocations / Memory Graph | Pic et mémoire après retour |
| Scroll rapide de 100+ champions | Instruments Core Animation | Fluidité et drops de frames |
| Ouverture de plusieurs galeries de skins | Allocations + activité réseau | Décodages répétés, mémoire |
| Réouverture hors-ligne | Network et gestion des erreurs | Requêtes manquées et récupération |
| Carte après recentrage GPS | Instruments Energy Log / localisation | Absence de mise à jour GPS continue |

## Points de prudence

- Le dépôt fixe actuellement le target iOS à **26.5** dans le projet Xcode, contrairement au README qui indique iOS 17+. Ne pas modifier silencieusement le support minimum sans validation.
- Le cache disque utilise un budget total et une purge lors d'écritures ; son comportement après purge automatique par iOS doit être vérifié.
- Le cache mémoire reste géré par NSCache (évictions permises).
- La version du catalogue Riot demeure volontairement fixée tant qu'aucune migration de données n'a été validée.
- **Aucun build Xcode, mesure Instruments ni test sur appareil ne peut être attesté depuis cet environnement.**
