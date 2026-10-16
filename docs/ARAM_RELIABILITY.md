# ARAM — test et explication pour la soutenance

## Fonctionnement

Dans l'onglet **Champions**, secouer l'iPhone tire un champion au hasard parmi le catalogue chargé depuis Firebase (ou son cache hors ligne). Il s'affiche dans **une seule fiche plein écran**. Une autre secousse remplace le champion dans cette fiche, sans ouvrir de nouvelle page et en évitant le champion précédent si le catalogue contient plusieurs choix.

La même action est disponible sur les fiches ouvertes manuellement depuis l'onglet Champions. Fermer ARAM ramène au catalogue. Les autres onglets ne peuvent pas déclencher ARAM. Il n'existe pas de bouton de relance.

## Implémentation en quelques éléments

- `Utils/DeviceShakeViewModifier.swift` reçoit le mouvement UIKit `motionEnded(.motionShake)` et crée une notification. Le timestamp est mesuré à la réception avec `ProcessInfo.processInfo.systemUptime` : l'horodatage brut des événements UIKit peut être ancien ou répété.
- `Services/ARAMShakeController.swift` conserve **un abonnement Combine unique** pendant toute la session, même lorsque la fiche ARAM est ouverte.
- `ARAMCore/ARAMState.swift` sélectionne un ID au hasard, écarte les doublons et évite deux sélections accidentelles à moins de 0,45 seconde.
- `Views/Champions/ChampionsView.swift` présente **un seul** `fullScreenCover`. Chaque changement de révision rafraîchit la fiche courante.
- Si une galerie de skins est ouverte, le dernier tirage est reporté après sa fermeture.

## Recette sur iPhone physique

1. Se connecter et attendre la liste des champions.
2. Secouer une fois dans Champions : une fiche complète s'affiche.
3. Secouer dix fois en espaçant les gestes d'environ une seconde : **chaque secousse doit changer le champion** et la révision dans les logs Debug doit augmenter.
4. Fermer ARAM, ouvrir manuellement une fiche, secouer : ARAM démarre et peut être relancé par d'autres secousses.
5. Vérifier qu'aucun tirage ne se produit dans Objets, Lieux ou Compte.
6. Ouvrir un skin en grand et secouer : après fermeture de la galerie, le dernier champion tiré apparaît.
7. Tester le mode avion après chargement initial des données, puis reconnecter Internet.

Logs utiles : `[LeagueDex ARAM] UIKit shake received` et `[LeagueDex ARAM] Champion tiré: …, révision N`. Un rejet indique en Debug sa cause : horodatage invalide, événement répété ou délai trop court.

`swift test --parallel` valide le tirage, les doublons, les horloges et les filtres ; **seul un test sur iPhone peut confirmer la détection physique des secousses**.
