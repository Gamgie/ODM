# Tracker de consommations — consignes pour Claude

Site statique public (GitHub Pages) : `index.html` lit les CSV de `data/`.
Quand je te dis une consommation, **ajoute une ligne à la fin du bon CSV** (une ligne par commit, message court en français, ex. « Plein 12/11 »). Ne modifie pas les lignes existantes sauf si je te demande une correction.

Dates au format `AAAA-MM-JJ`, nombres avec un **point** décimal, pas d'unité dans les cellules. Champ vide = rien entre les virgules. Si une valeur contient une virgule, mets-la entre guillemets.
Si une info manque (ex. le kilométrage d'un plein), demande-la une fois ; si je ne l'ai pas, laisse le champ vide.

## data/carburant.csv — Renault Trafic 2 (2012, 90 ch, diesel)
`date,km,litres,euros,plein_complet,lieu,note`
- `km` : compteur kilométrique total au moment du plein.
- `plein_complet` : `oui` si le réservoir est rempli à ras, sinon `non` (la conso L/100 se calcule entre deux pleins complets).
- Photo de ticket : lis la date, les litres, le montant et le lieu sur la photo. Garde seulement les chiffres. Si je demande de garder la photo, enregistre-la dans `data/tickets/AAAA-MM-JJ.jpg` et mets ce nom de fichier dans `note`.

Exemple : `2026-11-15,182340,72.4,130.00,oui,Lyon 7e,`

## data/electricite.csv — compteur non connecté, relevé environ tous les 4 jours
`date,index_kwh,note`
- `index_kwh` : le chiffre affiché au compteur (index cumulé), pas une consommation.

Exemple : `2026-11-15,12345,`

## data/gaz.csv — bonbonne
`date,evenement,prix_eur,kg,note`
- `evenement` : `nouvelle bonbonne` à chaque changement (la durée se calcule entre deux changements).

Exemple : `2026-11-15,nouvelle bonbonne,,13,`

## data/claude.csv — rempli automatiquement
Ne pas éditer à la main : le collecteur `collecteur/claude_usage.py` l'alimente depuis l'ordi.
