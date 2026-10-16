# ARAM — mode shake simplifié

## Correctif — UIKit détecte le shake mais le champion ne change pas

Le problème signalé sur iPhone n'était plus un manque de réception du mouvement :
`[LeagueDex ARAM] UIKit shake received` s'affichait à chaque secousse,
sans nouveau champion à l'écran.

L'abonnement `SwiftUI.onReceive` du catalogue ou de la présentation pouvait
cesser de traiter les notifications durant `fullScreenCover`. La sélection
est désormais centralisée dans **`ARAMShakeController`** (`@StateObject`
à la racine de Champions) avec **un seul abonnement Combine conservé** tout
le temps où l'onglet existe.

Le contrôleur reçoit `UIDevice.deviceDidShakeNotification` sans dépendre du
cycle de vie d'une vue SwiftUI, utilise le noyau `ARAMState` existant pour
éviter les doublons, puis publie `currentChampionID` et `revision`.
La vue ARAM (`@ObservedObject`) est mise à jour directement quand ces
propriétés changent. Le `fullScreenCover` est présenté une seule fois.

### Diagnostic sur un vrai iPhone (Xcode Debug)

Lors d'un shake accepté, les trois messages suivants doivent apparaître,
dans cet ordre :

```text
[LeagueDex ARAM] UIKit shake received
[LeagueDex ARAM] Event delivered to controller; tabActive=true, gallery=false, closing=false, champions=...
[LeagueDex ARAM] Champion tiré: ..., révision 1
```

Les shakes suivants doivent conduire à `révision 2`, `révision 3`, etc.
Si seul le premier log apparaît, la notification n'atteint pas le contrôleur.
Si le deuxième apparaît mais pas le troisième, la ligne explique si l'onglet
n'est pas actif, si la galerie est ouverte, si une fermeture est en cours,
ou si le tirage a été ignoré. Lors du test, espacer deux shakes d'au moins
0,5 seconde.

Aucun bouton de relance n'a été ajouté. Le cache et les autres
fonctionnalités ne sont pas modifiés.

## Comportement demandé

- Dans **Champions**, secouer l'iPhone ouvre immédiatement la fiche d'un champion choisi au hasard dans **tout** le catalogue chargé.
- Sur cette fiche ARAM, secouer de nouveau la remplace par un nouveau champion ; les anciennes fiches ne restent pas empilées.
- Une fiche ouverte manuellement permet également de démarrer ARAM par shake.
- Fermer ARAM ramène au catalogue et ne conserve aucune fiche ARAM en arrière-plan.
- Les autres onglets ne réagissent pas aux shakes. Un événement en arrière-plan est ignoré.
- Aucun bouton de tirage ou de relance n'est ajouté (seul **Fermer ARAM** apparaît).
- Sur un catalogue d'au moins deux champions, un nouveau tirage ne retourne pas le champion affiché juste avant.
- Une recherche ou un filtre sans résultat n'empêche plus ARAM de sélectionner parmi les champions du catalogue complet.

## Implémentation

`ARAMState` ne possède qu'un champion actuellement sélectionné, une révision de fiche et une protection contre les doublons d'événement (minimum 0,45 seconde). Il n'y a plus d'états d'ouverture/fermeture ni de session différée.

`ChampionsView` possède une unique présentation `fullScreenCover(isPresented:)`, et la vue pleine page reçoit la même notification shake que le catalogue. Les deux peuvent coexister pendant une transition : `ARAMState` ignore les doubles notifications. Chaque changement de révision reconstruit uniquement la fiche champion (scroll, niveau, compétence), pas la présentation.

La détection UIKit `UIWindow.motionEnded` n'exige plus `isKeyWindow` pendant les transitions plein écran ; elle vérifie que la scène est au premier plan et appelle `super.motionEnded`.

Si une galerie de skin est ouverte, le dernier shake est conservé puis appliqué à la fermeture de la galerie pour ne pas mélanger l'image du skin avec la fiche de son champion.

Les catalogues, la connexion Firebase, les builds, le quiz, les favoris, la carte et le cache d'images ne sont pas modifiés.

## Correctif — shakes qui ne fonctionnent qu'une fois

Sur iPhone, `UIResponder.motionEnded` est remis au *first responder* UIKit.
La méthode de secours `UIWindow.motionEnded` n'est donc pas garantie d'être
appelée après la présentation plein écran SwiftUI : le shake initial peut ouvrir
l'ARAM mais les secousses suivantes peuvent ne plus atteindre le sélecteur.

Le récepteur `ShakeEventReceiver` (un petit `UIViewControllerRepresentable`)
se déclare premier répondant dans son `viewDidAppear`, abandonne ce statut à
sa disparition et se réactive lorsque l'identité du champion ARAM change.
Il est monté sur trois surfaces : catalogue actif, fiche de champion ouverte
manuellement depuis Champions, et navigation ARAM en plein écran. La
présentation ARAM ne détruit pas son récepteur lors des tirages.

Le secours `UIWindow` reste disponible si un autre objet de l'interface
transmet son mouvement à la fenêtre. Tous les récepteurs déclenchent la même
notification et le noyau `ARAMState` ignore les doubles déclenchements.
Aucune détection n'est activée pour les autres onglets.

### Vérifier la chaîne réelle sur Xcode

1. Brancher **un véritable iPhone**, lancer le scheme LeagueDex en Debug.
2. Ouvrir Champions puis secouer une fois : chercher les deux messages :
   `[LeagueDex ARAM] UIKit shake received` et
   `[LeagueDex ARAM] Champion tiré: …, révision 1`.
3. Sans fermer ARAM, secouer à nouveau après environ une seconde :
   chercher une **nouvelle** paire de messages et une révision 2, puis 3, etc.
4. Si le premier message est absent, le geste n'arrive pas au récepteur UIKit.
   Si le premier apparaît sans le second, le filtrage de l'événement empêche
   le tirage ; vérifier l'onglet et l'état de l'application.
5. Tester également une fiche ouverte manuellement, puis les onglets
   Accueil / Objets / Lieux où ARAM doit rester inactif.

Les messages sont compilés uniquement en Debug. Aucun nouveau mécanisme
automatique, bouton de tirage ou écriture Firebase n'a été ajouté.

## Vérifications

### Automatisées

Le noyau est inclus dans le package Swift existant :

```bash
swift test --parallel
bash scripts/validate-ios.sh
```

La seconde commande requiert Xcode et un simulateur iOS compatible. Les tests de `ARAMState` vérifient le premier tirage, 20 tirages successifs, le changement de champion, les doublons de notification, le délai anti-double déclenchement, le catalogue vide, un seul champion, les IDs répétés et la fermeture/réouverture.

### Sur iPhone réel

1. Attendre que la liste de champions soit chargée puis secouer dans l'onglet Champions : une fiche apparaît.
2. Secouer à nouveau au moins cinq fois : le champion change et la nouvelle fiche part du haut, avec sa bonne image et ses statistiques.
3. Fermer ARAM : retour direct au catalogue ; la navigation manuelle doit encore fonctionner.
4. Ouvrir manuellement une fiche puis secouer : ARAM s'affiche ; secouer à nouveau fonctionne.
5. Activer un filtre ne donnant aucun résultat : secouer doit quand même choisir un champion dans le catalogue chargé.
6. Ouvrir la galerie d'un skin, zoomer, secouer, puis fermer la galerie : la nouvelle fiche apparaît sans galerie résiduelle.
7. Secouer dans Accueil, Objets et Lieux : aucun tirage.
8. Répéter sur appareil réel avec VoiceOver, Réduire les animations, connexion lente et après verrouillage/déverrouillage.

**Le simulateur ne reproduit pas forcément le geste physique réel.** Les validations Swift et CI ne garantissent pas la réception du shake sur tous les iPhone.
