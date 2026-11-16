# Mes consommations

Tracker public et open data de mes consommations : jauges Claude (session 5 h et semaine), électricité, carburant (Renault Trafic 2012) et gaz.
Pour consommer mieux, il faut d'abord mesurer, puis partager les données.

- **Le site** : `index.html` (GitHub Pages), lisible sur téléphone et ordi.
- **Les données** : fichiers CSV dans `data/`, réutilisables librement.
- **La saisie** : je le dis à Claude (« plein de 130 €, 72 L, 182 340 km »), qui ajoute la ligne. Les consignes sont dans `CLAUDE.md`.
- **Le collecteur Claude** : `collecteur/claude_usage.py` relève toutes les 30 min les deux jauges d'usage et les pousse dans `data/claude.csv`.

## Installer le collecteur (sur l'ordi où Claude Code est connecté)

```bash
git clone https://github.com/Gamgie/ODM.git ~/ODM
python3 collecteur/claude_usage.py --no-git           # test : doit afficher « Relevé : [...] »
```

Puis lancer automatiquement toutes les 30 minutes : `crontab -e` et ajouter

```
*/30 * * * * cd ~/ODM && /usr/bin/python3 collecteur/claude_usage.py >> ~/ODM/collecteur/log.txt 2>&1
```

Il faut que `git push` marche sans mot de passe depuis ce dossier (clé SSH ou gestionnaire d'identifiants).
Le script lit le jeton de Claude Code (Trousseau macOS ou `~/.claude/.credentials.json`) et interroge `api.anthropic.com/api/oauth/usage`, un endpoint **non documenté** qui peut changer. Il n'appelle aucun modèle, donc ne consomme pas de crédit.
