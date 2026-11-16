# Tests

À lancer depuis la racine du dépôt avant chaque `git push` (le mode `/goal` s'arrête si un test échoue).

| Commande | Ce qui est testé | Besoins |
|---|---|---|
| `node tests/ui.test.js` | Le site dans Chromium, avec Supabase simulé (`stub-supabase.js`) : affichage, saisie avec virgule, photo (rotation, cadrage, contexte), Mon compte (appareils, installateur), mise à jour automatique | Playwright (préinstallé dans les sessions Claude Code) |
| `bash tests/db.test.sh` | `supabase/schema.sql` sur un Postgres local imitant Supabase (`db-mock.sql`), appliqué deux fois, puis les règles d'accès (`db-assertions.sql`) | Postgres installé, droits root (utilisateur `postgres`) |
| `bash tests/fonction.test.sh` | `supabase/functions/lire-photo` dans Deno, contre un faux Supabase et une fausse API Anthropic (`fonction-mock.js`) : types, refus sans connexion, lecture, contexte, format de la requête à Claude, CORS | Node et npm (Deno 2.5.6 téléchargé au premier lancement) |

Ajouter un test à chaque nouvelle fonctionnalité. Le site simulé contient les relevés réels de novembre 2026 (électricité 408 → 469,40 kWh, deux pleins) : les valeurs attendues des tests en dépendent.
