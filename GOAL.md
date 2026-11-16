# Lancer le développement en mode `/goal`

Une phase à la fois (voir `PLAN.md` § 8). Chaque tour de `/goal` consomme la jauge hebdomadaire : vérifier la jauge sur le site avant de lancer.

## Prérequis (état au 16/11/2026)
- [x] Environnement cloud **ODM** avec accès Supabase et Vercel (voir `CLAUDE.md` § Accès)
- [x] Tests automatiques dans `tests/` (site, base, fonction photo)
- [x] Projet Vercel `odm` + domaine `odm.gamgie.com` ajouté
- [ ] Enregistrement DNS chez Wix : CNAME `odm` → `1fd4d6bac5e7c5c5.vercel-dns-017.com`
- [ ] Forme d'achat du bois (stères, granulés…) et rythme — utile en phase 1 ou 2

## Commandes prêtes à coller

**Phase 1 — CO₂e de l'existant**
```
/goal Phase 1 de PLAN.md terminée : table facteurs (sources ADEME, identifiants Base Empreinte) appliquée sur Supabase, le site affiche les kg CO₂e par poste pour les relevés existants (électricité, gazole, gaz), total en tête et anneau par poste, export JSON public au même format que https://alexandrix.com/data/carbon-metrics-latest-data.json, nouveaux tests ajoutés et les trois suites de tests/ passent, poussé sur main avec VERSION incrémentée, vérifié en ligne sur odm.gamgie.com. Arrête-toi après 20 tours.
```

**Phase 2 — questionnaire et bilan annuel**
```
/goal Phase 2 de PLAN.md terminée : questionnaire de base (postes et hypothèses de Nos Gestes Climat, licence vérifiée), forfait services publics, page bilan annuel avec comparaison à la moyenne française, écart < 10 % avec Nos Gestes Climat sur 2 profils de test documentés dans tests/, les trois suites passent, poussé sur main avec VERSION incrémentée. Arrête-toi après 25 tours.
```

Les phases suivantes (3 à 7) se formulent de la même façon à partir de la colonne « Condition de fin » de `PLAN.md`.

## Ce que le mode goal ne peut pas faire seul
Créer des comptes, payer, modifier le DNS chez Wix, saisir une clé : il s'arrête et le demande.
