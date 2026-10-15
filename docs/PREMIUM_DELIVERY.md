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
  Son interprétation historique de la croissance de vitesse d'attaque est conservée
  conformément à la demande de réutiliser les formules ; elle ne simule pas les
  multiplicateurs, ratios et effets de combat de Riot. Une révision de cette formule
  doit être validée séparément sur toutes les fiches et comparaisons.

Validation intermédiaire : neuf groupes de tests Firestore réussis localement et
dans GitHub Actions ; revue statique B et absence de nouveaux listeners/réseau
dans les vues compagnon. Six tests natifs de statistiques/inventaire et deux tests
de migration de file locale ajoutés aux douze tests de politique de synchronisation
et aux tests ARAM existants. Leur exécution est confiée à la CI macOS.

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
