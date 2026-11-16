# Mes consommations

Tracker public et open data de consommations : jauges Claude (session 5 h et semaine), électricité, carburant et gaz.
Pour consommer mieux, il faut d'abord mesurer, puis partager les données.

**Site :** https://gamgie.github.io/ODM/

## Architecture

| Élément | Rôle |
|---|---|
| `index.html` + `config.js` | Le site (GitHub Pages) : graphiques publics, connexion, saisie d'un relevé par photo ou à la main |
| Supabase | Base de données et comptes (offre gratuite) |
| `supabase/functions/lire-photo` | Fonction Supabase : envoie la photo à Claude (API Anthropic) et renvoie les valeurs lues |
| `supabase/schema.sql` | Tables et règles d'accès : lecture publique, chacun n'écrit que ses lignes |
| `collecteur/claude_usage.py` | Script sur l'ordi : relève les jauges Claude toutes les 30 min et les envoie |

Les photos sont réduites (1568 px) et ré-encodées dans le navigateur, ce qui retire leurs métadonnées (dont la position GPS), puis lues par Claude et **jamais enregistrées**. Seuls les chiffres validés sont stockés.

## Mise en place (une seule fois)

### 1. Supabase
1. Créer un compte sur https://supabase.com puis **New project** (région Europe, mot de passe de base au choix).
2. **SQL Editor** → coller tout `supabase/schema.sql` → **Run**.
3. **Authentication → Users → Add user → Create new user** : ton e-mail et un mot de passe, cocher *Auto Confirm User*.
4. (Facultatif) **SQL Editor** → coller `supabase/import_releves_initiaux.sql` → **Run** pour reprendre les premiers relevés.
5. Noter trois valeurs :
   - **Project URL** et clé **publishable** (ou *anon public*) : bouton **Connect** ou **Project Settings → API**. Jamais la clé *secret* / *service_role*.
   - ton **User UID** : Authentication → Users.

### 2. La lecture des photos (facultatif)
1. Créer une clé API sur https://platform.claude.com (paiement à l'usage, **distinct de l'abonnement Claude**) et y mettre quelques euros de crédit.
2. Supabase → **Edge Functions → Secrets** : ajouter `ANTHROPIC_API_KEY` avec cette clé.
3. **Edge Functions → Deploy a new function → Via Editor** : nom `lire-photo`, coller `supabase/functions/lire-photo/index.ts`, **Deploy**. Vérifier ensuite la fin de l'URL affichée (Supabase peut garder un nom généré, ex. `dynamic-endpoint`) et la reporter dans `fonction_photo` de `config.js`.

La fonction n'accepte que les comptes connectés. Coût indicatif : environ 1 centime par photo avec Claude Opus 5.5 (constante `MODELE` en haut du fichier ; Claude Haiku 5.5 coûte environ 40 fois moins).

### 3. Le site
Mettre ces trois valeurs dans `config.js` (elles ne sont pas secrètes), puis activer GitHub Pages : Settings → Pages → *Deploy from a branch* → `main` / `(root)`.

### 4. Le collecteur Claude (Windows)
Sur le site, connecté : **Mon compte**, nom de l'ordinateur (ex. `desktop`, `laptop`) → **Installer sur Windows**, puis double-clic sur le fichier téléchargé, sur cet ordinateur.
Une clé par appareil : les jauges sont celles du compte Claude (tous appareils confondus), plusieurs ordinateurs servent seulement à couvrir les moments où l'un est éteint. Un relevé arrivé moins de 10 min après un autre est ignoré.
Le fichier lance `collecteur/installer.ps1`, qui :
1. installe Python si besoin (winget) ;
2. télécharge le collecteur dans `%LOCALAPPDATA%\ODM` avec sa configuration ;
3. installe Claude Code en ligne de commande et ouvre la connexion si besoin (l'appli de bureau ne laisse pas son jeton lisible) ;
4. envoie un premier relevé ;
5. crée la tâche planifiée « ODM collecteur » toutes les 30 min, **autorisée sur batterie** (Windows bloque sinon les tâches d'un portable débranché).

Relancer le fichier met tout à jour. Journal : `%LOCALAPPDATA%\ODM\log.txt`. Arrêter : `Unregister-ScheduledTask -TaskName "ODM collecteur"`.
Sur macOS ou Linux : `claude_usage.py` + `config.json` (clé : Mon compte → Autre système), lancé par `cron` ou `launchd`.

L'endpoint `api.anthropic.com/api/oauth/usage` n'est **pas documenté** par Anthropic et peut changer. Il n'appelle aucun modèle : le collecteur ne consomme pas de crédit.

## À venir
- Création de compte et gestion de compte par utilisateur, page publique par pseudo.
- Comparaison entre utilisateurs.

## Contribuer
Chaque évolution passe par une branche et une pull request vers `main`.
