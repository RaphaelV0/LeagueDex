# Lot 2 — Design system Runeterra : validation

Cette branche inclut aussi le **lot 1** (branche parente `stabilization/lot-1-foundations`). Aucune modification directe de `main`.

## Design system

Les composants et couleurs partagés se trouvent dans `LeagueDex/DesignSystem/LeagueTheme.swift` :

| Token | Couleur |
|---|---|
| background | `#080E18` |
| surface | `#111C2B` |
| elevated | `#1D3042` |
| gold | `#C6A66B` |
| cyan | `#48C7D9` |
| text | `#F4F0E7` |
| muted | `#9BAEC3` |

Composants : `leagueSurface`, `LeagueSectionHeader`, `LeagueFilterChip`, `LeagueActionButtonStyle`, `LeagueLoadingState`, `LeagueEmptyState` et `LeagueErrorState`. Les cartes de champions, stats, coûts et icônes de compétences utilisent la même identité visuelle.

Les onglets natifs restent en place, avec le thème sombre principal. Aucun framework UI tiers ajouté.

## Tests UX / non-régression recommandés sur iPhone

- [ ] Onglets Champions / Objets / Lieux : changement rapide, états actifs, safe areas, clavier et retour arrière.
- [ ] iPhone de petite largeur : les cinq icônes de compétences, les trois coûts d'objet et les filtres ne débordent pas.
- [ ] Réglages système Texte plus grand / VoiceOver : labels de champions, boutons Compétences, ARAM, favoris et Réessayer.
- [ ] Accessibilité « Réduire les animations » : interactions de boutons et changement de compétence.
- [ ] Mode sombre : contraste des cartes, textes secondaires, fonds de listes, navigation, boutons et carte.
- [ ] Champion : recherche, rôles, favoris, détail, niveau 1–18, sorts, conseils, skins.
- [ ] ARAM : bouton dé visible dans la barre d'outils **et** secousse, respect des filtres.
- [ ] Armurerie : liste, recherche, états vides, coûts et détails.
- [ ] Carte : pins, sélection, fermeture, distance et ouverture Plans.
- [ ] Hors ligne / erreur de chargement : message lisible, bouton Réessayer.
- [ ] Comportement des images et favoris après mise à jour depuis la version du lot 1.

## Contrôles techniques

- [ ] Compiler l'app en Debug puis Release avec le schéma `LeagueDex` dans Xcode.
- [ ] Vérifier les warnings SwiftUI et l'absence de nouveaux problèmes d'isolation d'acteur.
- [ ] Inspecter les prévisualisations et captures en tailles d'écrans variées.
- [ ] Mesurer les performances de la grille et du détail (Instruments).

## Hors périmètre

- Refonte ergonomique complète des fiches (sélecteur de niveau, parcours avancés).
- Authentification Riot et historiques de matchs, absents du catalogue actuel.
- Prise en charge Android.
- Changement du target iOS actuellement fixé dans le projet Xcode (différent du README).

**La validation statique des délimiteurs des fichiers Swift modifiés a été réalisée, mais aucun build iOS n'a pu être exécuté dans l'environnement de travail.**
