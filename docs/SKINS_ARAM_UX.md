# LeagueDex — Galerie plein écran et pile ARAM

## Modifications

- La galerie des skins permet maintenant d'ouvrir chaque vignette via un bouton accessible.
- Une vue plein écran présente l'illustration Riot en grand, avec bouton « Fermer », pincement pour zoomer et double toucher pour agrandir/réinitialiser.
- L'illustration plein écran continue d'utiliser le cache d'images LeagueDex existant.
- Le shake ouvre une **unique présentation ARAM plein écran** ; les secousses suivantes changent le champion affiché sans modifier la pile de navigation.
- L'ARAM utilise maintenant une seule présentation `fullScreenCover(isPresented:)` avec un champion actif ; changer de champion ne rouvre pas la présentation.
- L'identité de la présentation reste stable entre les tirages. Si le champion disparaît du catalogue, une erreur avec réessai remplace le chargement sans fin et **Fermer ARAM** reste accessible.
- La fiche ARAM se reconstruit à chaque tirage pour repartir du haut de l'écran (nouvelle identité de vue) ; aucune animation de pile ne doit laisser une fiche partiellement visible.
- Le bouton **Fermer ARAM** ramène au catalogue Champions. Les fiches des tirages précédents ne sont jamais empilées.
- Deux surfaces peuvent recevoir la notification pendant une transition (catalogue et plein écran) ; une seule logique de tirage ignore les doublons d'événement et applique un délai de 0,45 seconde. Le tirage choisit toujours dans le catalogue complet, même avec des filtres actifs.

## Vérifications sur iPhone

- [ ] Fiche champion → Galerie → toucher une image → illustration ouverte en plein écran.
- [ ] Pincer pour zoomer, double toucher pour agrandir ou revenir à la taille initiale, puis fermer.
- [ ] Répéter avec plusieurs skins et un champion dont le skin est nommé « default ».
- [ ] Tester le chargement hors ligne et les erreurs d'image avec le cache existant.
- [ ] Après un lancement à froid et le chargement du catalogue, effectuer le premier shake : la fiche s'ouvre directement, sans rester sur « Ouverture du champion… ». Fermer puis recommencer.
- [ ] Depuis le catalogue : secouer → fiche A plein écran ; secouer → fiche B ; secouer → fiche C. **Fermer ARAM** revient directement au catalogue.
- [ ] Secouer depuis une fiche ouverte manuellement : la fiche ARAM est présentée plein écran et Fermer revient au catalogue, sans ancienne fiche intermédiaire.
- [ ] Secouer rapidement pendant l'ouverture, depuis le haut puis le bas d'une fiche : vérifier que le nouvel écran est complet, que son image et son titre correspondent au champion tiré et que le scroll repart en haut.
- [ ] Ouvrir l'image d'un skin en plein écran depuis une fiche ARAM puis revenir à la fiche ; vérifier les barres de navigation et les zones sûres.
- [ ] Répéter 20 secousses espacées d'au moins 1 s, puis 0,35–0,5 s sur iPhone : aucun écran décalé, rogné ou à moitié affiché.
- [ ] Vérifier qu'une secousse ne déclenche rien depuis les onglets Objets et Lieux.
- [ ] Tester avec VoiceOver et l'option Réduire les animations.
- [ ] Compiler Debug et Release dans Xcode.

Les contrôles statiques portent sur le diff et la présence des fonctionnalités. Aucun test simulateur ni test de capteur sur iPhone n'a été réalisé dans cet environnement.

La procédure complète et les tests natifs sont détaillés dans [ARAM_RELIABILITY.md](ARAM_RELIABILITY.md).

Le 15 octobre 2026, une lecture REST de la collection `champions` du projet indiqué dans `GoogleService-Info.plist` a réussi depuis cet environnement. Les deux documents demandés, Aatrox et Ahri, contenaient leurs champs de détails et `isDetailLoaded: true`. Le bundle ID du fichier Firebase correspond à celui des configurations Debug et Release. Ce contrôle confirme l'accès serveur en lecture au moment de la vérification ; il ne remplace pas un essai de l'application sur iPhone.
