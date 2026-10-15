# LeagueDex — Livraison compagnon

## Base et validation par phase

Base demandée : dernier commit distant de `codex/aram-reliability`,
`d64baa1f46a8fddb623d8054defbfa4477764dfd`, récupéré le 15 octobre 2026.
Branche de travail : `codex/premium-companion`. Aucune fusion dans `main`.

L'environnement de développement est Windows : ni Swift ni Xcode ne sont installés.
Une revue statique n'est pas une compilation iOS. Les workflows GitHub exécutent
les validations natives sur macOS et les règles sur un émulateur isolé ; leurs
résultats doivent être vérifiés avant toute fusion.

## Phase A — Firebase et sécurité

- Réutilisation de l'unique `FirebaseApp.configure()` et du package Firebase existants.
  Ajout du produit `FirebaseAuth` ; aucun fournisseur d'authentification concurrent.
- Connexion e-mail/mot de passe, inscription, réinitialisation, déconnexion et
  restauration par listener Firebase. Les secrets de session restent gérés par le SDK.
- L'arbre authentifié est recréé à chaque changement de `uid`. Les favoris sont
  détachés de l'ancien compte avant de publier la nouvelle identité.
- Un seul catalogue champions et objets est partagé entre les écrans de la session.
- Favoris : `users/{uid}/favorites/{championID}`, avec `selected` et `updatedAt`.
  Les retraits sont des tombstones. Les modifications simultanées d'un même favori
  suivent l'ordre de réception serveur ; des champions différents ne s'écrasent pas.
- Migration de la clé locale `LeagueDex.favoriteChampionIDs.v1` : union
  transactionnelle uniquement pour les documents absents. Les anciens indicateurs
  partagés du catalogue, sans auteur identifiable, ne sont pas attribués à un compte.
  Un retrait distant explicite est conservé. La clé source n'est jamais supprimée.
  Une réservation locale `LeagueDex.legacyFavoritesClaim.v2` associe la tentative
  au premier compte avant le réseau ; un changement de compte pendant l'import
  ne peut donc pas transférer sa sauvegarde au suivant.
  `LeagueDex.legacyFavoritesOwner.v2` est écrit après confirmation serveur.
- Les clients ne modifient plus les catalogues publics `champions` et `items`.
  Les données Data Dragon validées peuvent servir de secours local ; les détails
  téléchargés sont conservés sur disque. Le patch reste volontairement `14.18.1`.

## Phase B — Comparateur et builds

- Accueil compagnon dans une navigation à quatre onglets ; compte accessible depuis l'accueil.
- Recherche des deux champions, niveau commun 1–18, huit statistiques avec barres
  et écarts numériques, rôles, passif et compétences issus du catalogue existant.
- Comparaisons favorites enregistrées, rouvertes et supprimées dans le compte.
- Création, édition, duplication et suppression de builds ; choix du champion,
  recherche d'objets, six emplacements, icônes, descriptions et coût du catalogue.
  Les doublons d'objets sont conservés comme des emplacements distincts.
- Un objet absent garde sa référence et rend le total explicitement indisponible ;
  seul un sous-total des objets connus est alors affiché.
- File locale, reprise, détection de conflits et récupération des suppressions en
  conflit. Les contenus locaux peuvent être conservés dans un nouveau build.
- La formule des fiches est partagée avec le comparateur, avec bornage 1–18.
  Le comparateur affiche explicitement la vitesse d'attaque **de base**, sans
  appliquer à cette valeur un coefficient de croissance additif inadapté.
  La fiche historique reste intacte : sa formule de vitesse d'attaque aux niveaux
  supérieurs nécessite une correction séparée avec validation des ratios Riot.

Validation intermédiaire : neuf groupes de tests Firestore réussis localement et
dans GitHub Actions ; revue statique B et absence de nouveaux listeners/réseau
dans les vues compagnon. Six tests natifs de statistiques/inventaire et deux tests
de migration de file locale ajoutés aux douze tests de politique de synchronisation
et aux tests ARAM existants. Au commit `ba88777`, les tests natifs et les builds
simulateur Debug **et** Release ont réussi sous Xcode 26.6 dans
[la validation de phase B](https://github.com/RaphaelV0/LeagueDex/actions/runs/38747092310).

## Phase C — Quiz et champion du jour

- Six catégories : illustration, description, compétence/passif, objet, rôle et
  statistiques de base. Les données viennent exclusivement des modèles déjà chargés.
- Deux ou quatre choix selon la difficulté ; pas de génération si les données
  ne permettent pas dix questions distinctes. Les compétences peuvent être
  préchargées par lots limités à huit champions, uniquement à la demande.
- Les choix n'ont pas de doublons de libellé ; les questions de rôles excluent les
  autres rôles réels du même champion, et les questions statistiques refusent une
  égalité pour la première place. Les descriptions masquent le nom de la réponse.
- Score personnel : 100 points par bonne réponse, historique immuable synchronisé,
  statistiques calculées depuis les résultats du compte. Aucun gain de valeur réelle.
- Le champion du jour vient du **catalogue Data Dragon complet du patch 14.18.1**,
  pas d'un résultat Firestore partiel. Le jour change à **00:00 UTC**. Les IDs uniques
  triés sont indexés par `FNV1a64("champion:" + YYYY-MM-DD) % nombreIDs`.
  Le hash, le générateur pseudo-aléatoire et le mélange sont explicitement définis.
- Un défi quotidien de rôle est généré depuis ce même catalogue et cette même date.
  Son résultat a l'ID `daily-YYYY-MM-DD` ; les règles interdisent toute réécriture.
  Les horloges d'appareil doivent être réglées correctement. Aucun classement ni
  récompense sensible ne repose sur la date ou la validation cliente.
- Les images de questions n'annoncent pas la solution à VoiceOver ; les catégories
  textuelles sont proposées pour jouer sans reconnaissance visuelle.

## Phase D — Carte communautaire avec modération (suite après interruption)

- Les lieux publics restent dans `venues/{venueID}`. Lecture pour comptes
  authentifiés ; **écriture réservée aux administrateurs** dotés d'un custom
  claim `admin: true`, attribué uniquement côté Admin SDK.
- Un utilisateur connecté crée une proposition sous
  `users/{uid}/venueProposals/{YYYY-M-D}` (date en UTC, mois et jour sans
  zéro initial). Les règles calculent la date depuis `request.time` :
  **une seule proposition par compte et par jour UTC**, y compris en cas
  de changement d'horloge sur l'iPhone. Les propositions sont immuables côté client.
- Les coordonnées sont recherchées via Apple Plans et confirmées par l'utilisateur
  avant soumission. Types, longueurs et coordonnées sont validés **dans les règles**.
- Historique des propositions avec les statuts `pending`, `approved` ou
  `rejected`. Seul un administrateur peut changer le statut et renseigner
  `reviewedAt` / `reviewedBy`; le contenu de la proposition ne peut pas
  être modifié lors de cette étape.
- Un signalement par lieu et par jour UTC est autorisé sous
  `users/{uid}/venueReports/{venueID}_{YYYY-M-D}`, avec motif énuméré.
  Le signalement est privé et immuable ; les administrateurs peuvent le consulter.
- Recherche de lieu par nom, ville ou adresse et filtres de distance 10/25/50/100 km
  basés sur la position GPS si elle est autorisée.
- Les lieux existants, la lecture Firestore en temps réel, les horaires fournis,
  le téléphone, le site web et les itinéraires Apple Plans sont conservés.

### Publication et modération — étapes côté Firebase

1. Déployer après revue les nouvelles `firestore.rules` via Firebase CLI
   depuis un environnement autorisé. Rien n'a été déployé en production.
2. Consulter les `venueProposals` des comptes dans une console d'administration
   sécurisée, un outil de confiance ou via Admin SDK ; éviter de manipuler
   les données sensibles depuis un client public.
3. Vérifier qu'un lieu est réel, que l'adresse et les horaires sont pertinents,
   et qu'il n'existe pas déjà dans `venues`.
4. Depuis un environnement administrateur, créer le document public
   `venues/{venueID}` en recopiant **uniquement** les champs autorisés
   du modèle `DBVenue` (nom, adresse, lat/lon, type et champs facultatifs).
5. Marquer la proposition `approved` avec `reviewedAt` (timestamp serveur)
   et `reviewedBy` (UID modérateur). En cas de refus, choisir `rejected`.
   Le statut `approved` ne publie **pas automatiquement** le lieu.
6. Les signalements sont à examiner par un modérateur ; seul celui-ci peut
   corriger ou supprimer un lieu public.

**Limite assumée :** le dépôt ne fournit pas encore de tableau de bord
administrateur ni de Cloud Function de publication atomique. La modération
reste une opération administrative manuelle à sécuriser avant diffusion.
La date UTC et une proposition quotidienne limitent le spam sans remplacer
une vraie politique anti-abus (App Check, vérification d'adresse, surveillance,
quotas côté serveur et modération).

### Recette de la phase D

- [ ] Création avec compte A, apparition en « En attente de modération » dans
      son historique, invisibilité sur la carte publique avant approbation.
- [ ] Compte B : impossible de lire l'historique du compte A.
- [ ] Deuxième proposition le même jour : refus serveur.
- [ ] Modérateur : approbation/refus sans modification possible du contenu initial.
- [ ] Vérifier la création publique du lieu via procédure administrateur.
- [ ] Signalement d'un lieu : un par jour et par lieu, lecture privée.
- [ ] Recherche/filtrage, GPS refusé, historique hors ligne, itinéraires Apple Plans.
- [ ] Tests Firestore Emulator, compilation Xcode Debug/Release et tests iPhone.

## Configuration Firebase nécessaire

1. Conserver le projet Firebase et le `GoogleService-Info.plist` actuels.
2. Activer **Authentication → Sign-in method → Email/Password** dans ce projet.
   Les comptes existants et leurs `uid` restent inchangés.
3. Examiner et tester les règles versionnées avant déploiement. Ne jamais remplacer
   les règles par une autorisation publique pour résoudre une erreur de permission.
4. Déployer explicitement les règles et les index avec le CLI Firebase configuré
   sur le bon projet. Aucun déploiement de production n'est effectué par ce travail.
5. Les privilèges administrateur/modérateur se donnent uniquement avec Admin SDK
   dans un environnement de confiance, jamais depuis une application cliente.

Les catalogues et documents existants ne sont ni effacés ni réécrits par l'app.
Firestore assure son cache persistant iOS ; les données privées sont toujours
requêtées sous le `uid` connecté. La file locale des builds est également nommée
par `uid`. Les mots de passe et jetons ne sont jamais stockés dans UserDefaults.

## Synchronisation des contenus privés

| Chemin sous `users/{uid}` | Contenu et résolution |
|---|---|
| `favorites/{championID}` | `championID`, `selected`, horodatage serveur ; suppression logique |
| `builds/{id}` | Nom, champion, jusqu'à six IDs d'objets, `revision`, `mutationID`, `deleted`, création et modification serveur |
| `comparisons/{id}` | Deux IDs de champions et niveau 1–18 ; ID stable par paire/niveau |
| `quizRuns/{id}` | Catégorie, difficulté, score, bonnes réponses, total, date et clé quotidienne ; création seule |

Les builds sont mis en file localement par compte avant transmission. Une
transaction compare la révision lue à celle du serveur. Un conflit conserve
l'édition locale et exige de conserver une copie ou de recharger la version
synchronisée. Les suppressions conservent une révision, ce qui protège contre la
résurrection par un appareil resté hors ligne.

Chaque écriture possède un `mutationID` : si le serveur a validé l'opération juste
avant un arrêt de l'app, sa répétition est reconnue. Une édition pendant une
opération en cours conserve aussi l'identifiant de son prédécesseur dans la file
locale ; cela distingue sa propre validation perdue d'une modification concurrente.
Les callbacks d'une ancienne session ne réécrivent pas la file d'une nouvelle.

Ces collections de contenus sont nouvelles. Les favoris locaux sont migrés par
l'app ; aucune migration destructive des données utilisateur existantes n'est
nécessaire. Le décodeur de la file locale accepte les entrées antérieures sans
`mutationID` et leur attribue un identifiant avant la première transmission.

## Sources de référence

- [Authentification Firebase iOS](https://firebase.google.com/docs/auth/ios/start)
- [Cache et écritures hors ligne Firestore](https://firebase.google.com/docs/firestore/manage-data/enable-offline)

## Recette iPhone avant fusion

- Connexion, inscription, mot de passe oublié, restauration après relance,
  refus réseau et changement de compte sans fuite d'affichage.
- Deux appareils : ajout/retrait simultané de favoris, migration avec tombstone,
  sauvegarde locale conservée après refus de règles et interruption réseau.
- ARAM : secouer catalogue et fiche, plusieurs secousses rapides, remplacement de
  la fiche unique, retour arrière, changement d'onglet et passage en arrière-plan.
  Aucun déclenchement dans les sections compagnon, objets ou lieux.
- Galerie de skins plein écran, zoom et retour à la même fiche.
- Petit iPhone et iPad, orientations, safe areas, VoiceOver, Dynamic Type maximum,
  Réduire les animations et refus de localisation.

## Limites à respecter

Les résultats de quiz personnels saisis par un client ne constituent pas une
preuve de performance vérifiée par serveur. Aucun classement compétitif ni gain
monétaire n'est attribué sur cette base. Un système de récompenses à valeur réelle
exigerait un moteur serveur indépendant.

Le cache peut être évincé par iOS sous pression de stockage ; la première ouverture
d'une donnée jamais téléchargée nécessite une connexion. La restauration d'une
session déjà enregistrée fonctionne hors ligne, la première connexion nécessite
Firebase Authentication.
