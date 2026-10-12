# LeagueDex — Galerie plein écran et pile ARAM

## Modifications

- La galerie des skins permet maintenant d'ouvrir chaque vignette via un bouton accessible.
- Une vue plein écran présente l'illustration Riot en grand, avec bouton « Fermer », pincement pour zoomer et double toucher pour agrandir/réinitialiser.
- L'illustration plein écran continue d'utiliser le cache d'images LeagueDex existant.
- Chaque tirage ARAM par secousse définit un chemin de navigation avec **une seule fiche champion** : `navigationPath = [chosen.id]`.
- Le retour depuis la dernière fiche ARAM ramène au catalogue. Les champions obtenus lors des secousses précédentes ne s'empilent plus.
- Le délai anti-doublon de 0,8 seconde et les filtres du catalogue sont conservés.

## Vérifications sur iPhone

- [ ] Fiche champion → Galerie → toucher une image → illustration ouverte en plein écran.
- [ ] Pincer pour zoomer, double toucher pour agrandir ou revenir à la taille initiale, puis fermer.
- [ ] Répéter avec plusieurs skins et un champion dont le skin est nommé « default ».
- [ ] Tester le chargement hors ligne et les erreurs d'image avec le cache existant.
- [ ] Depuis le catalogue : secouer → fiche A ; secouer → fiche B ; secouer → fiche C ; Retour → catalogue **directement**.
- [ ] Secouer depuis une fiche ouverte manuellement : remplacer la fiche actuelle et revenir au catalogue.
- [ ] Vérifier qu'une secousse ne déclenche rien depuis les onglets Objets et Lieux.
- [ ] Tester avec VoiceOver et l'option Réduire les animations.
- [ ] Compiler Debug et Release dans Xcode.

Les contrôles statiques portent sur le diff et la présence des fonctionnalités. Aucun test simulateur ni test de capteur sur iPhone n'a été réalisé dans cet environnement.
