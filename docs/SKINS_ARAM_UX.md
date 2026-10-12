# LeagueDex — Galerie plein écran et pile ARAM

## Modifications

- La galerie des skins permet maintenant d'ouvrir chaque vignette via un bouton accessible.
- Une vue plein écran présente l'illustration Riot en grand, avec bouton « Fermer », pincement pour zoomer et double toucher pour agrandir/réinitialiser.
- L'illustration plein écran continue d'utiliser le cache d'images LeagueDex existant.
- Le shake ouvre une **unique présentation ARAM plein écran** ; les secousses suivantes changent le champion affiché sans modifier la pile de navigation.
- La fiche ARAM se reconstruit à chaque tirage pour repartir du haut de l'écran (nouvelle identité de vue) ; aucune animation de pile ne doit laisser une fiche partiellement visible.
- Le bouton **Fermer ARAM** ramène au catalogue Champions. Les fiches des tirages précédents ne sont jamais empilées.
- Le délai anti-doublon de 0,8 seconde et les filtres du catalogue sont conservés.

## Vérifications sur iPhone

- [ ] Fiche champion → Galerie → toucher une image → illustration ouverte en plein écran.
- [ ] Pincer pour zoomer, double toucher pour agrandir ou revenir à la taille initiale, puis fermer.
- [ ] Répéter avec plusieurs skins et un champion dont le skin est nommé « default ».
- [ ] Tester le chargement hors ligne et les erreurs d'image avec le cache existant.
- [ ] Depuis le catalogue : secouer → fiche A plein écran ; secouer → fiche B ; secouer → fiche C. **Fermer ARAM** revient directement au catalogue.
- [ ] Secouer depuis une fiche ouverte manuellement : la fiche ARAM est présentée plein écran et Fermer revient au catalogue, sans ancienne fiche intermédiaire.
- [ ] Secouer rapidement pendant l'ouverture, depuis le haut puis le bas d'une fiche : vérifier que le nouvel écran est complet, que son image et son titre correspondent au champion tiré et que le scroll repart en haut.
- [ ] Ouvrir l'image d'un skin en plein écran depuis une fiche ARAM puis revenir à la fiche ; vérifier les barres de navigation et les zones sûres.
- [ ] Répéter 10 secousses espacées d'au moins 0,8 s sur iPhone : aucun écran décalé, rogné ou à moitié affiché.
- [ ] Vérifier qu'une secousse ne déclenche rien depuis les onglets Objets et Lieux.
- [ ] Tester avec VoiceOver et l'option Réduire les animations.
- [ ] Compiler Debug et Release dans Xcode.

Les contrôles statiques portent sur le diff et la présence des fonctionnalités. Aucun test simulateur ni test de capteur sur iPhone n'a été réalisé dans cet environnement.
