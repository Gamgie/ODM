# Tracker de consommations — notes pour Claude

Site statique (`index.html`, GitHub Pages depuis `main`) relié à Supabase. Voir `README.md` pour l'architecture et la mise en place.

- Pas de build, pas de framework : HTML + JS vanilla, Chart.js et supabase-js chargés depuis un CDN avec version figée.
- Interface et textes en français.
- À chaque modification du site : incrémenter `VERSION` dans `index.html` **et** `version.json` (les téléphones gardent la page en cache ; la page se recharge seule quand `version.json` annonce plus récent).
- Toute évolution de la base passe par `supabase/schema.sql`, qui doit rester relançable sans erreur (`if not exists`, `drop policy if exists`, `create or replace`).
- Sécurité : lecture publique, écriture limitée à `auth.uid()` par les règles RLS. Ne jamais mettre la clé `service_role` dans le dépôt. `config.js` ne contient que des valeurs publiques.
- Le collecteur (`collecteur/claude_usage.py`) écrit via la fonction `ajouter_releve_claude` et une clé par utilisateur ; `collecteur/config.json` n'est jamais commité.

## Modèle de données (`releves`)
| categorie | valeur | autres champs |
|---|---|---|
| `electricite` | index du compteur (kWh, cumulé) | |
| `carburant` | compteur kilométrique | `litres`, `euros`, `plein_complet` (L/100 calculé entre deux pleins complets), `lieu` |
| `gaz` | — | `euros`, `kg` ; une ligne = une nouvelle bonbonne |

Photos : jamais stockées. Le navigateur les réduit et les envoie à la fonction `supabase/functions/lire-photo` (Deno, SDK Anthropic, sortie JSON validée par Zod), qui renvoie les valeurs lues ; l'utilisateur vérifie avant d'enregistrer.
