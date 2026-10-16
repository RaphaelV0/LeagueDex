# Tests de sécurité Firestore

Cette version Master 2 vérifie uniquement les besoins de l'application :

- authentification obligatoire pour lire les catalogues de champions, objets et lieux ;
- écriture des champions et objets réservée aux administrateurs ;
- création de lieux `venues` autorisée aux comptes connectés si nom, adresse, type, coordonnées, auteur et horodatage serveur sont valides ; modification et suppression des lieux réservées aux administrateurs ;
- favoris privés, modifiables par leur propriétaire uniquement ;
- refus de lecture/écriture des chemins retirés (builds, quiz, comparaisons, propositions de lieux).

Les tests utilisent `demo-leaguedex` sur l'émulateur local et n'affectent pas le projet Firebase de production.

```bash
npm ci
npm run test:rules
```

Les règles sont dans `firestore.rules`. Leur déploiement dans le vrai projet Firebase doit être contrôlé manuellement.
