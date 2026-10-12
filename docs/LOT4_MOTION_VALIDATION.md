# LeagueDex — Lot 4 : animations et finitions premium

**Branche :** `design/lot-4-premium-motion`  
**Base :** `design/lot-3-advanced-ux` (contient déjà les lots 1 à 3).  
**Périmètre :** SwiftUI uniquement, sans modification de l'architecture ni suppression de fonctionnalité.

## Modifications

| Composant / écran | Intervention | Limite de performance |
|---|---|---|
| `DesignSystem/LeagueMotion.swift` | Motion tokens (180, 240, 280 ms), entrée progressive, style pressable réutilisable | Révélation réservée à quelques sections, jamais à chaque cellule d'une liste |
| `LeagueFilterChip` | Transition de la sélection + état pressed | Pas de déplacement du contenu |
| Catalogue Champions | Skeleton en grille lors du premier chargement, bouton ARAM avec libellé « Tirage… », feedback pressed sur cartes | Les cellules du catalogue n'ont pas d'animation de défilement |
| Fiche champion | Entrée légère du hero et des sections, transition des compétences, barre de niveau animée, image hero en placeholder skeleton | Respect de « Réduire les animations » |
| Armurerie | Skeleton de lignes pendant le premier chargement, entrée discrète des contenus de détail, feedback haptique sur filtre, skeleton image | Pas de shimmer GPU pour les listes complètes |
| Stats | Nombres animés discrètement lors du changement de niveau | Animation à 180 ms et désactivable |
| Carte e-sport | Sélection des pins, panneau et haptique de sélection | Pas de transitions sur le défilement de carte |

La pulsation de skeleton dure environ 1 s et ne s'exécute que pendant le chargement initial. Elle reste statique quand l'option système « Réduire les animations » est activée.

## Scénarios de validation Xcode

- [ ] **Compiler Debug et Release**, vérifier les API SwiftUI disponibles pour la cible du projet.
- [ ] Première ouverture avec cache vide : skeleton Champions visible, puis remplacé par les cartes.
- [ ] Première ouverture Armurerie avec cache vide : skeleton en liste, puis vrais objets.
- [ ] Hors ligne / réseau instable : l'affichage des erreurs et le bouton « Réessayer » restent accessibles.
- [ ] Retour aux listes et recherche intensive : pas de saccades ni réanimation de chaque ligne.
- [ ] ARAM : bouton et secousse, un seul tirage pendant le chargement et accès à la fiche.
- [ ] Fiche champion : sections, compétences, galerie, animation légère des valeurs de stats et niveau 1 à 18.
- [ ] Armurerie : prix, filtres, tri, description d'objet et action retour.
- [ ] Carte : filtrage, sélection de pins et de lieux, réouverture/fermeture du panneau, recentrage et Apple Plans.
- [ ] **Réduire les animations** : pas de pulsation ni déplacement de composants ; toutes les actions restent fonctionnelles.
- [ ] **VoiceOver** : skeleton annoncé comme « Chargement », accès aux boutons sans annonce excessive.
- [ ] **Texte agrandi / petit iPhone** : skeletons non débordants, noms de champions, bouton ARAM et armurerie.
- [ ] Instruments : FPS lors des scrolls, CPU du skeleton pendant chargement et allocations mémoire.

## Non-régressions et limites

- Aucun accès au build iOS ni à un simulateur Xcode depuis ce travail ; les vérifications statiques ne remplacent pas les tests de compilation.
- Les animations de navigation restent natives (`NavigationStack` / `TabView`) ; pas de navigation personnalisée coûteuse.
- Aucun changement des données Firestore, de la version Data Dragon, de l'ARAM, des lieux ou des favoris.
- **Ne pas fusionner avant les tests Xcode**. Aucune pull request créée pour ce lot, conformément à la demande.
