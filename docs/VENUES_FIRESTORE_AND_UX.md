# LeagueDex — Correctifs accueil / ARAM / lieux communautaires

## Comportements livrés
- Un seul défilement pour l'écran Champions, des cartes à largeur contrainte et une barre de recherche intégrée à la navigation.
- ARAM déclenché **uniquement en secouant l'iPhone**, depuis le catalogue Champions ou chaque fiche champion. Aucun bouton de relance n'est affiché. Une seule destination est ajoutée pour chaque geste.
- Carte alimentée par les trois lieux embarqués et par un `addSnapshotListener` sur **Firestore `venues`**.
- Ajout direct à Firestore après vérification de l'adresse par Apple Plans et confirmation d'un repère.
- Les fiches de lieux affichent coordonnées, adresse, distance GPS, horaires déclarés, notes, téléphone et site web (si renseignés), ainsi que l'itinéraire Apple Plans.
- Les horaires inconnus sont indiqués « Horaires non renseignés » et ne sont jamais inventés.

## Structure des documents Firestore

Collection : `venues`. Les documents sont générés avec un ID unique par Firebase.

| Champ | Type | Description |
|---|---|---|
| name | string | Nom du lieu |
| address | string | Adresse résolue par Apple Plans puis confirmée |
| latitude / longitude | number | Coordonnées du repère trouvé |
| type | string | Bar E-sport, Salle LAN, Autre lieu gaming |
| openingHours | string, facultatif | Horaires déclaratifs ; ne pas interpréter comme « ouvert maintenant » |
| phone | string, facultatif | Téléphone |
| website | string, facultatif | Site web |
| details | string, facultatif | Informations pratiques |
| source | string | "community" pour un ajout depuis l'app |
| createdAt | timestamp | Horodatage serveur pour la gestion des contributions |

Les champs facultatifs maintiennent la compatibilité des documents existants.

## IMPORTANT : règles Firestore et sécurité

Cette fonctionnalité écrit **directement** depuis l'app sur la collection `venues`. Sans authentification ni validation serveur, autoriser librement les écritures de tous les clients expose la base à des données fausses, doublons et spam. Les contrôles SwiftUI ajoutés sont **uniquement côté client et ne sécurisent pas Firestore**.

- Vérifier les règles Firestore déployées avant la publication : lecture nécessaire sur `venues` et autorisation contrôlée de création de documents.
- Ne pas ouvrir `allow write: if true` sur toute la base pour résoudre une erreur « Permission denied ».
- Pour une application publique, intégrer idéalement **Firebase Authentication**, une validation des types/longueurs côté règles et un contrôle des contributions (modération et quotas).
- Les règles et accès au projet Firebase **ne sont pas stockés dans ce dépôt** : aucune règle n'a été changée ou déployée automatiquement ici.
- L'application affiche les erreurs de permission Firestore au lieu d'annoncer faussement un succès.

## Tests Xcode / iPhone à effectuer

- [ ] Compilation Debug et Release et absence de warning bloquant Swift 6.
- [ ] Accueil : petit iPhone, Dynamic Type, cartes sans débordement ni doublon de scroll, recherche, favoris, rôles, tri.
- [ ] ARAM : secouer depuis le catalogue, ouvrir une fiche, secouer de nouveau sur la fiche, puis revenir en arrière. Aucun bouton de tirage ou de relance.
- [ ] Secouer l'iPhone sur les onglets Objets et Lieux : aucun tirage ARAM ne doit se produire.
- [ ] Plusieurs secousses rapides : vérifier qu'il n'y a pas plusieurs navigations simultanées.
- [ ] Depuis le catalogue, vérifier le respect des filtres lors d'un tirage ; depuis une fiche, éviter de retomber sur le même champion.
- [ ] Carte : les trois lieux embarqués restent visibles même si Firestore est indisponible.
- [ ] Création : renseigner nom, adresse, type, horaires, notes et téléphone ; vérifier la position ; enregistrer dans Firestore.
- [ ] Vérifier dans la console Firebase que le document est créé dans `venues` avec un ID unique.
- [ ] Revenir à la carte et sur un second appareil, vérifier la synchronisation en temps réel.
- [ ] Tester une adresse introuvable, une adresse ambiguë, un doublon, une perte de réseau et un refus des règles Firestore.
- [ ] Ouvrir une épingle : vérifier horaires, infos, téléphone, site web, distance et itinéraire Apple Plans.
- [ ] Tester un lieu sans horaires : afficher « Horaires non renseignés », sans valeur inventée.
- [ ] Vérifier le fonctionnement de la carte si l'utilisateur refuse l'autorisation GPS.
- [ ] Tester VoiceOver, affichage en texte large, réduction des animations.

**Aucun build Xcode ou test Firebase réel n'a été exécuté depuis cet environnement.**
