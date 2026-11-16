# Tracker de consommations — notes pour Claude

Site statique (`index.html`) publié sur **https://odm.gamgie.com** (Vercel, à chaque push sur `main` ; GitHub Pages reste un miroir) et relié à Supabase. Voir `README.md` pour l'architecture et la mise en place.

- Pas de build, pas de framework : HTML + JS vanilla, Chart.js et supabase-js chargés depuis un CDN avec version figée.
- Interface et textes en français.
- À chaque modification du site : incrémenter `VERSION` dans `index.html` **et** `version.json` (les téléphones gardent la page en cache ; la page se recharge seule quand `version.json` annonce plus récent).
- Toute évolution de la base passe par `supabase/schema.sql`, qui doit rester relançable sans erreur (`if not exists`, `drop policy if exists`, `create or replace`).
- Sécurité : lecture publique, écriture limitée à `auth.uid()` par les règles RLS. Ne jamais mettre la clé `service_role` dans le dépôt. `config.js` ne contient que des valeurs publiques.
- Le collecteur (`collecteur/claude_usage.py`, installé sous Windows par `collecteur/installer.ps1`) écrit via la fonction `ajouter_releve_claude` avec une clé **par appareil** (`cles_collecteur`) ; un relevé à moins de 10 min d'un autre est ignoré. `config.json` n'est jamais commité.

## Modèle de données (`releves`)
| categorie | valeur | autres champs |
|---|---|---|
| `electricite` | index du compteur (kWh, cumulé) | |
| `carburant` | compteur kilométrique | `litres`, `euros`, `plein_complet` (L/100 calculé entre deux pleins complets), `lieu` |
| `gaz` | — | `euros`, `kg` ; une ligne = une nouvelle bonbonne |

Photos : jamais stockées. Le navigateur les réduit et les envoie à la fonction `supabase/functions/lire-photo` (Deno, SDK Anthropic, sortie JSON validée par Zod), qui renvoie les valeurs lues ; l'utilisateur vérifie avant d'enregistrer.

## Accès (environnement cloud « ODM »)
Les sessions sur l'environnement **ODM** ont deux jetons injectés par le proxy (ne jamais les demander ni les écrire) :
- **Supabase Management API** (`api.supabase.com`) — projet `jwseyltlaeweprwlooib` (région eu-west-3).
  - SQL : `POST /v1/projects/jwseyltlaeweprwlooib/database/query` avec `{"query": "..."}` — appliquer `supabase/schema.sql` ainsi, après `bash tests/db.test.sh`.
  - Fonction photo : slug **`dynamic-endpoint`** (nom affiché `lire-photo`), vérification JWT désactivée (la fonction vérifie elle-même la connexion). Secret `ANTHROPIC_API_KEY` en place. Déploiement par l'API à vérifier lors de la première utilisation.
  - Auth : `site_url` = https://odm.gamgie.com ; **inscription désactivée** jusqu'à la phase « comptes ».
- **Vercel** (`api.vercel.com`) — équipe `team_chqYdY0oHIbA7UxNPKV1S6e2` (gamgie), projet **`odm`** relié à `Gamgie/ODM`, production = `main`, site statique sans build, domaine `odm.gamgie.com` (DNS chez Wix : CNAME `odm` → `1fd4d6bac5e7c5c5.vercel-dns-017.com`). `*.vercel.app` n'est pas joignable depuis la session : vérifier sur `odm.gamgie.com`.
- Wix (DNS de gamgie.com) : pas d'accès, modifications faites par Clément.

Avant chaque push : `node tests/ui.test.js`, `bash tests/db.test.sh`, `bash tests/fonction.test.sh` (voir `tests/README.md`).
