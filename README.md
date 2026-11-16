# Mes consommations

Tracker public et open data de consommations : jauges Claude (session 5 h et semaine), électricité, carburant et gaz.
Pour consommer mieux, il faut d'abord mesurer, puis partager les données.

**Site :** https://gamgie.github.io/ODM/

## Architecture

| Élément | Rôle |
|---|---|
| `index.html` + `config.js` | Le site (GitHub Pages) : graphiques publics, connexion, ajout de relevés avec photo |
| Supabase | Base de données, comptes, stockage des photos (offre gratuite) |
| `supabase/schema.sql` | Tables et règles d'accès : lecture publique, chacun n'écrit que ses lignes |
| `collecteur/claude_usage.py` | Script sur l'ordi : relève les jauges Claude toutes les 30 min et les envoie |

Les photos sont réduites (≈1600 px) et ré-encodées dans le navigateur avant l'envoi, ce qui retire leurs métadonnées (dont la position GPS).

## Mise en place (une seule fois)

### 1. Supabase
1. Créer un compte sur https://supabase.com puis **New project** (région Europe, mot de passe de base au choix).
2. **SQL Editor** → coller tout `supabase/schema.sql` → **Run**.
3. **Authentication → Users → Add user → Create new user** : ton e-mail et un mot de passe, cocher *Auto Confirm User*.
4. (Facultatif) **SQL Editor** → coller `supabase/import_releves_initiaux.sql` → **Run** pour reprendre les premiers relevés.
5. Noter trois valeurs :
   - **Project URL** et clé **publishable** (ou *anon public*) : bouton **Connect** ou **Project Settings → API**. Jamais la clé *secret* / *service_role*.
   - ton **User UID** : Authentication → Users.

### 2. Le site
Mettre ces trois valeurs dans `config.js` (elles ne sont pas secrètes), puis activer GitHub Pages : Settings → Pages → *Deploy from a branch* → `main` / `(root)`.

### 3. Le collecteur Claude (Windows)
Prérequis : Python (python.org, cocher *Add to PATH*) et Claude Code connecté sur l'ordi.

```powershell
git clone https://github.com/Gamgie/ODM.git $HOME\ODM
py $HOME\ODM\collecteur\claude_usage.py --test     # doit afficher « Relevé (non envoyé) : ... »
copy $HOME\ODM\collecteur\config.exemple.json $HOME\ODM\collecteur\config.json
notepad $HOME\ODM\collecteur\config.json           # URL, clé publishable, clé collecteur (site → Mon compte)
py $HOME\ODM\collecteur\claude_usage.py            # doit afficher « OK 5h=... »
schtasks /Create /SC MINUTE /MO 30 /TN "ODM collecteur" /TR "pyw $HOME\ODM\collecteur\claude_usage.py"
```

Journal : `collecteur\log.txt`. Arrêter : `schtasks /Delete /TN "ODM collecteur"`.
Sur macOS ou Linux, même script, lancé par `cron` ou `launchd`.

L'endpoint `api.anthropic.com/api/oauth/usage` n'est **pas documenté** par Anthropic et peut changer. Il n'appelle aucun modèle : le collecteur ne consomme pas de crédit.

## À venir
- Création de compte et gestion de compte par utilisateur, page publique par pseudo.
- Comparaison entre utilisateurs.

## Contribuer
Chaque évolution passe par une branche et une pull request vers `main`.
