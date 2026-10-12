# LeagueDex — Lot 3 : refonte UX avancée

Branche : `design/lot-3-advanced-ux`
Base : `design/lot-2-runeterra-foundations` (contient les lots 1 et 2)

## Périmètre réalisé

### Catalogue Champions
- Filtres par rôle et favoris existants préservés.
- Recherche par nom, tri A–Z / Z–A, nombre de résultats.
- Grille adaptative selon la largeur et bouton de réinitialisation des filtres.
- Tirage ARAM accessible par bouton et toujours par secousse de l'appareil.

### Fiche champion
- Raccourcis de navigation vers compétences, statistiques, astuces et skins.
- Niveau 1–18 réglable en un geste avec un slider, ainsi que raccourcis 1 et 18.
- Compétences accessibles via boutons dans un défilement horizontal.
- Galerie des skins avec LazyHStack et affichage de l'histoire du champion, lorsqu'elle est disponible.
- Données de statistiques, conseils alliés/ennemis, skins et favoris conservées.

### Armurerie
- Recherche sur le nom et le texte de description courte.
- Filtres par coût total (1–1500, 1501–3000, 3001+), trois tris.
- Compteur de résultats et remise à zéro des filtres.
- Prix de la fiche présentés en grille adaptative pour les petits écrans.

### Carte e-sport
- Les trois lieux et leurs coordonnées sont inchangés.
- Filtrage Tous / Bars e-sport / Salles LAN.
- Liste de sélection des lieux, recentrage sur un lieu ou sur la position GPS.
- Indication si localisation refusée ; calcul de distance et itinéraire Apple Plans préservés.

## Tests fonctionnels à effectuer dans Xcode

- [ ] L'application compile en Debug et Release sur le SDK installé.
- [ ] Onglets et navigation retour, y compris après plusieurs fiches.
- [ ] Recherche Champions, rôles, favoris et remise à zéro ; compter les résultats.
- [ ] Tri A–Z / Z–A en changeant de filtre et en modifiant le terme recherché.
- [ ] Tirage ARAM par bouton **et** par secousse ; respecter les filtres actifs.
- [ ] Fiche champion : les quatre raccourcis atteignent les sections présentes.
- [ ] Niveau 1, 9 et 18 : vérifier la mise à jour de toutes les statistiques dynamiques.
- [ ] Vérifier les cinq compétences, descriptions, astuces et galerie, y compris les champions avec peu de skins ou d'astuces.
- [ ] Favoris : ajouter/retirer, revenir à la liste, fermer et relancer.
- [ ] Armurerie : filtres 1500 / 1501 / 3000 / 3001 ; tri et recherche.
- [ ] Vérifier prix et description d'une fiche après chaque filtre.
- [ ] Carte : trois lieux visibles, deux bars et une salle LAN ; sélectionner par pin et par menu.
- [ ] Carte : recentrer sur un lieu, puis sur la position GPS ; fermer la fiche.
- [ ] Carte : avec permission GPS autorisée, refusée ou non déterminée.
- [ ] Carte : ouvrir Apple Plans et lancer un itinéraire vers chaque lieu.
- [ ] Test réseau lent / hors ligne : erreurs, retours et boutons Réessayer hérités du lot 1.

## Formats et accessibilité

- [ ] Petit iPhone, grand iPhone, tailles de texte augmentées ; pas de débordement.
- [ ] VoiceOver : lecture des champs, sélection des filtres, raccourcis et actions ARAM.
- [ ] Préférence Réduire les animations : vérifier la navigation rapide et le recentrage de la carte.
- [ ] Navigation avec une seule main ; zone tactile et tab bar.
- [ ] Instruments : défilement du catalogue, de l'armurerie et de la galerie.

## Contrôles réalisés sans Xcode

- [x] Vérification des délimiteurs des quatre fichiers SwiftUI modifiés.
- [x] Vérification statique de la présence des parcours historiques dans les quatre vues.
- [x] Diff limité aux écrans du lot 3 et à la documentation (avant fusion).

## Limites connues

La liste e-sport est toujours constituée de trois lieux statiques : ce lot améliore **leur découverte**, pas la source des données. Le modèle Item ne fournit ni catégories complètes, ni arbres de construction : aucun filtre fictif sur ces données n'a été ajouté.

Aucun build Xcode, test UI automatisé ni mesure Instruments n'a pu être exécuté dans cet environnement. Ne pas fusionner avant ces validations.
