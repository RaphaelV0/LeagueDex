# ARAM — fiabilisation et validation

Base : `main`, commit `6946d347b45d36a482050f1cad3b7c92756b44f4`.
Branche : `codex/aram-reliability`.

## Diagnostic et choix

Le commit de base a supprimé les coordonnées globales et les débordements de safe area de la bannière. Ces corrections sont conservées : le `GeometryReader` reste local, avec une hauteur bornée et une image rognée dans ses propres dimensions.

Il restait deux abonnements aux shakes, un booléen de présentation indépendant de l'identifiant sélectionné, une temporisation de 0,8 s pouvant ignorer des gestes distincts, et une remise à zéro du chemin de navigation à chaque tirage. Une sélection absente pouvait laisser le plein écran sur « Ouverture du champion… » sans bouton Fermer.

`ChampionsView` possède désormais un unique `ARAMState` et un seul abonnement aux notifications UIKit. La notification contient un UUID et l'horodatage monotone de l'événement. Le traitement est direct, sans passage par un état « dernier événement » susceptible de fusionner deux notifications en attente. Les onglets inactifs et l'application en arrière-plan ne tirent aucun champion.

Le noyau Foundation gère les phases `idle`, `opening`, `presented`, `closing`, l'identité stable de session et la révision de chaque tirage. Une notification déjà traitée et les événements espacés de moins de 0,3 s sont ignorés. Les gestes distincts espacés d'au moins 0,35 s restent acceptés. Ce seuil devra être confirmé sur appareil.

Pendant l'ouverture, le champion est remplacé dans la même session. Pendant la fermeture ou une galerie de skin, chaque geste accepté effectue sa sélection ; seul le résultat le plus récent reste en attente. Il est présenté après le véritable `onDismiss`, jamais sous une autre présentation. Fermer explicitement annule les tirages différés antérieurs ; un nouveau geste pendant la fermeture peut ouvrir une nouvelle session après sa fin. Un changement d'onglet ou un passage en arrière-plan efface le résultat différé.

Le catalogue applique toujours recherche, rôle, favoris et tri. Un premier tirage depuis le catalogue respecte ces filtres. Comme avant, les tirages depuis une fiche ou une session utilisent tout le catalogue et évitent le dernier champion lorsque des alternatives existent. Un catalogue réduit à un champion reste utilisable. Aucun bouton de tirage ou de relance n'est ajouté.

Le chemin normal n'est vidé que lors de l'entrée effective dans ARAM depuis une fiche manuelle. Les relances ne modifient jamais ce chemin. La session garde son identité ; seule la fiche change d'identité à chaque révision, ce qui réinitialise le scroll, le niveau, la compétence sélectionnée et la galerie. Le fondu de 0,18 s remplace les révélations indépendantes des sections ; il disparaît avec Réduire les animations. Les couleurs et composants du thème sont conservés.

## Chargement et données

- Un téléchargement de détails appartient au modèle et est partagé par identifiant de champion. Changer de fiche n'annule plus une requête utile aux retours suivants.
- Les détails sont appliqués immédiatement en mémoire, aux seuls champs du champion concerné, puis synchronisés avec Firestore. Les favoris, statistiques et métadonnées courants ne sont pas remplacés par une ancienne copie.
- Le cache de session protège contre les snapshots incomplets ou une écriture refusée. Une correction complète et confirmée du serveur reste acceptée. Les erreurs de détails disposent d'un réessai local, sans bloquer les statistiques.
- Une collection vide en cache ou des documents indécodables ne déclenchent plus l'import initial. Un import exige une confirmation serveur, une seconde lecture avant écriture et une transaction qui abandonne si un document cible existe déjà.
- Les images et erreurs portent une clé URL/résolution et une identité de requête. Une ancienne tâche ne peut pas réafficher l'image d'un autre champion. Un succès mémoire est visible dès la première frame.
- Les téléchargements d'images simultanés sont mutualisés par URL ; un abonné annulé ne coupe pas les autres. Le décodage reste hors du MainActor. Les caches existants sont conservés : 48 Mio/150 images en mémoire, 160 Mio/30 jours sur disque. Un tampon d'octets borné à 8 Mio évite les doublons pendant le décodage et la persistance ; ses entrées sont réutilisées au plus 5 s.
- L'identité SwiftUI d'un skin utilise champion + numéro, sans changer son encodage Firestore.

Aucune migration de schéma, modification des règles ou écriture sur la base distante n'a été effectuée pendant ce travail. La version Data Dragon reste `14.18.1`. Armurerie, Carte, favoris locaux, calculs des niveaux 1 à 18 et zoom de galerie sont conservés.

## Vérifications reproductibles

Sur un Mac disposant de Swift 6 et de Xcode compatible avec la cible iOS 26.5 du projet :

```sh
swift test --parallel
bash scripts/validate-ios.sh
```

Le package teste les mêmes fichiers `LeagueDex/ARAMCore` que ceux compilés automatiquement par la cible iOS. Il ne dépend pas de Firebase. Les tests Swift Testing couvrent notamment 20 gestes distincts, un seul appel au sélecteur par geste, doublons, temporisation, filtrage, catalogue vide ou singleton, ouverture, fermeture, callbacks périmés, galerie et contexte inactif.

Le script exécute les tests natifs, résout les packages Firebase puis compile Debug et Release pour le simulateur sans signature. Le workflow GitHub `iOS validation` exécute ce script sur `macos-26` avec Xcode 26.6 à l'ouverture d'une PR vers `main`. Cette version est référencée dans l'[inventaire officiel des runners](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md).

Dans l'environnement Windows de rédaction, Swift et Xcode ne sont pas disponibles. Les tests natifs et compilations n'y ont donc pas été exécutés. La revue croisée du code, le contrôle des abonnements/chemins d'appel et `git diff --check` sont les vérifications locales. Les résultats CI doivent être consultés séparément ; aucune réussite de compilation ni de test capteur n'est déduite de ces contrôles.

## Checklist sur iPhone réel avant fusion

- [ ] Relever modèle d'iPhone, version iOS, configuration, état réseau et résultat CI. Installer un build propre ; attendre le catalogue puis faire le premier shake. Une fiche complète et un bouton Fermer doivent apparaître.
- [ ] Faire **20 gestes distincts**, espacés d'au moins 1 s, puis refaire à environ 0,35–0,5 s. Toujours une seule fiche ; le dernier champion tiré doit correspondre au titre, splash, sorts, conseils, statistiques et skins.
- [ ] Descendre en bas d'une fiche, régler le niveau sur 18, sélectionner un sort, puis secouer : retour en haut, niveau 1, passif du nouveau champion et aucune image de la fiche précédente.
- [ ] Secouer pendant l'ouverture, pendant un chargement lent d'image et immédiatement après Fermer. Aucun écran partiel ni empilement ; un geste reçu pendant la fermeture ne rouvre qu'après sa fin.
- [ ] Ouvrir un skin depuis ARAM ; zoomer par pincement et double toucher. Secouer plusieurs fois : le skin et son titre restent cohérents. Fermer la galerie : le dernier tirage différé s'affiche en haut.
- [ ] Répéter depuis une galerie ouverte dans une fiche normale. ARAM attend la fermeture de la galerie puis s'ouvre ; Fermer ARAM ramène au catalogue.
- [ ] Fermer ARAM après 20 tirages, puis rouvrir par shake. Aucun retour aux fiches précédentes ; navigation manuelle aller/retour toujours fonctionnelle.
- [ ] Vérifier recherche, chacun des rôles, tri et favoris locaux ; premier tirage dans les résultats filtrés. Tester aucun résultat et un seul résultat.
- [ ] Secouer sur Armurerie et Carte, changer d'onglet, verrouiller puis réactiver l'app : aucune ouverture ou sélection différée indésirable.
- [ ] Activer Réduire les animations, VoiceOver et le texte le plus grand ; vérifier les zones sûres, portrait/paysage et un petit écran. Pas de titre rogné, bouton Fermer toujours accessible.
- [ ] Revenir plusieurs fois aux mêmes champions avec réseau lent, mode avion et cache chaud. Aucun téléchargement de détails répété après succès ; aucun clignotement d'image déjà en mémoire. Une erreur réseau doit rester récupérable.
- [ ] Dans un projet/émulateur Firestore de test : cache initial vide hors ligne, documents invalides, import concurrent, lecture autorisée/écriture refusée, correction serveur des détails. Aucune réimportation destructive ; détails téléchargés encore visibles si la persistance échoue.
- [ ] Profiler 20 à 100 tirages avec Instruments (Allocations, Time Profiler, Network) sur le même appareil : pas de croissance continue des fiches ou abonnements, cache borné et pas de décodage image sur le thread principal. Ne pas annoncer un gain chiffré sans mesure.

La PR reste en brouillon jusqu'à la réussite des compilations/tests et de cette validation sur appareil. La fusion dans `main` se fait après ces vérifications.
