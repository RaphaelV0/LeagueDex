# Lot 1 — Stabilisation : vérifications

## Tests de régression manuels à exécuter dans Xcode

- [ ] Build Debug sur simulateur iPhone avec SDK iOS compatible avec le projet.
- [ ] Catalogue champions : premier démarrage (Firestore vide), chargement des images, recherche et filtres.
- [ ] Catalogue champions : couper le réseau avant lancement, vérifier le message d'erreur et le bouton Réessayer.
- [ ] Armurerie : chargement normal, recherche, fiche objet, affichage des prix et textes.
- [ ] Armurerie : hors-ligne, message d'erreur puis reprise.
- [ ] Favoris : favoris existants présents lors du premier lancement migrés sur l'appareil, persistance après relancement.
- [ ] Favoris : modifier un favori depuis une fiche, vérifier qu'aucune écriture Firestore n'est effectuée sur `isFavorite`.
- [ ] Favoris : vérifier le comportement sur un deuxième appareil avec un stockage local séparé.
- [ ] Champion détail : compétences, skins, astuces et statistiques chargés à la demande.
- [ ] Ouvrir rapidement plusieurs fois une fiche non chargée : contrôler la déduplication des requêtes.
- [ ] Images : vérifier deux URLs distinctes avec le même dernier composant, notamment les différents skins.
- [ ] Images : réseau perdu en chargement et relance ; vérifier les illustrations.
- [ ] ARAM : secouer l'iPhone, tirer un champion parmi les filtres actifs et vérifier sa fiche.
- [ ] Carte : autorisation de localisation, marqueurs, distance et ouverture des itinéraires Apple Plans.
- [ ] VoiceOver et grandes tailles de texte sur les erreurs et les actions de reprise.

## Contrôles techniques recommandés

- Contrôler dans la console Firebase qu'une action Favoris n'écrit plus dans la collection partagée.
- Vérifier le budget mémoire image avec Instruments / Allocations et le comportement disque du cache.
- Vérifier le comportement d'import lorsqu'une collection Firestore est vide ou qu'une requête réseau échoue.
- Vérifier les règles de sécurité Firestore : la migration locale n'efface pas l'ancien champ distant.
- Mesurer les temps de chargement avant/après sur appareil.

## Limites connues du lot 1

- La version Data Dragon est centralisée mais reste intentionnellement fixée à 14.18.1. Actualiser le catalogue demande une migration de données et une validation dédiée.
- Les favoris sont isolés par installation via UserDefaults, pas synchronisés entre appareils. La migration importe une seule fois les favoris du document historique, sans suppression de celui-ci.
- Le cache image utilise une limite mémoire, mais aucune politique de purge disque selon l'âge ou la taille totale n'est encore intégrée.
- Les échecs de chargement des détails individuels ne disposent pas encore d'un bouton Réessayer dédié : la navigation permet de réessayer au prochain chargement.
- Aucun build Xcode ni test simulateur n'a été exécuté dans cet environnement Linux.
