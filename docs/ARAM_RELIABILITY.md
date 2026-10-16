# ARAM — mode shake simplifié

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
