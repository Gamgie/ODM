# Tracker de consommations — notes pour Claude

Site statique (`index.html`, GitHub Pages depuis `main`) relié à Supabase. Voir `README.md` pour l'architecture et la mise en place.

- Pas de build, pas de framework : HTML + JS vanilla, Chart.js et supabase-js chargés depuis un CDN avec version figée.
- Interface et textes en français.
- Toute évolution de la base passe par `supabase/schema.sql`, qui doit rester relançable sans erreur (`if not exists`, `drop policy if exists`, `create or replace`).
- Sécurité : lecture publique, écriture limitée à `auth.uid()` par les règles RLS. Ne jamais mettre la clé `service_role` dans le dépôt. `config.js` ne contient que des valeurs publiques.
- Le collecteur (`collecteur/claude_usage.py`) écrit via la fonction `ajouter_releve_claude` et une clé par utilisateur ; `collecteur/config.json` n'est jamais commité.

## Modèle de données (`releves`)
| categorie | valeur | autres champs |
|---|---|---|
| `electricite` | index du compteur (kWh, cumulé) | |
| `carburant` | compteur kilométrique | `litres`, `euros`, `plein_complet` (L/100 calculé entre deux pleins complets), `lieu` |
| `gaz` | — | `euros`, `kg` ; une ligne = une nouvelle bonbonne |

Photos : bucket public `photos`, chemin `<user_id>/<date>-<categorie>-<horodatage>.jpg`, référencé dans `releves.photo`.
