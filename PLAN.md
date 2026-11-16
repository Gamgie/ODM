# ODM — plan vers un bilan carbone personnel complet

*Rédigé le 16/11/2026. Document de référence pour le développement (y compris en mode `/goal`).*

## 1. Objectif

Connaître **précisément** mon empreinte carbone annuelle (en kg CO₂e), poste par poste, en combinant :
- une **estimation de base** pour ce qui se mesure mal (alimentation, achats, services publics) ;
- des **mesures réelles** pour ce qui se mesure (électricité, carburant, gaz, trajets, IA), qui remplacent l'estimation dès qu'elles existent ;
- une **saisie sans effort** : site, photo, conversation avec Claude (comme Ogma), et des collecteurs qui vont chercher l'information seuls.

Données publiques et partageables, méthode transparente, chaque chiffre traçable jusqu'à son facteur d'émission et sa source.

Repère : l'empreinte moyenne d'un Français est d'environ 8 à 9 t CO₂e/an ; l'objectif de neutralité vise ~2 t en 2050 (ordre de grandeur cité par Selectra et Nos Gestes Climat, à confirmer avec la source ADEME/SDES la plus récente).

## 2. Ce qui existe déjà (références étudiées)

| Outil | Ce qu'il apporte | Ce qu'on en reprend |
|---|---|---|
| **Nos Gestes Climat** (ADEME, open source, modèle en Publicodes) | Questionnaire de 10 min couvrant tous les postes, empreinte carbone et eau, données ADEME | Liste des postes, questions de base, hypothèses par défaut. Le modèle étant open source, réutiliser ses règles plutôt que les réinventer (dépôt et licence à vérifier en phase 2) |
| **MyCO2** (Carbone 4) | Approche « empreinte individuelle » comparée à l'empreinte moyenne française, ateliers | Le principe de comparaison à la moyenne et la part « services publics » non pilotable |
| **Base Empreinte** (ADEME, ex-Base Carbone) | Base publique de référence des facteurs d'émission, en téléchargement et API | **Source principale des facteurs** (identifiant de la ligne conservé pour chaque facteur) |
| **API Impact CO2** (ADEME, impactco2.fr) | Facteurs de ~170 gestes et objets du quotidien (transports, numérique, alimentation…) ; clé sur demande | Calcul des trajets (avion, train, voiture) et objets courants |
| **Mistral × Carbone 4 × ADEME** (ACV, juillet 2025) | ~1,1 g CO₂e pour une réponse de 400 tokens, entraînement + inférence | Ordre de grandeur haut pour l'IA |
| **Google (Gemini)** | 0,03 g CO₂e par requête médiane (inférence seule, méthode market-based) | Ordre de grandeur bas |
| **EcoLogits** (GenAI Impact) | Estimation par tokens et taille de modèle, avec incertitude | Méthode de calcul de l'IA par tokens |

À voir : le simulateur d'**Alex Andrix** (URL à fournir).

## 3. Ce qui manque à ODM aujourd'hui

ODM suit des **quantités** (kWh, litres, %) mais ne calcule **aucune émission**, et ne couvre qu'une petite partie de l'empreinte.

| Poste (part typique d'une empreinte française*) | État ODM | À ajouter |
|---|---|---|
| **Transports** (~25-30 %) : voiture, avion, train, bus, vélo | Carburant du Trafic seulement | Trajets avion et train (distance ou origine–destination), autres véhicules, covoiturage, conversion litres → CO₂e |
| **Logement** (~20-25 %) : électricité, chauffage, construction | Électricité (kWh), gaz en bouteille (dates) | Facteurs CO₂e, chauffage (bois, fioul…), surface et part de construction/équipement amortie |
| **Alimentation** (~20-25 %) | Rien | Questionnaire d'habitudes (régime, viande/semaine, local/saison) + saisie optionnelle de repas |
| **Biens de consommation** (~10-15 %) : vêtements, électronique, mobilier | Rien | Achats ponctuels (objet → facteur), ou dépenses en € par catégorie (ratios monétaires ADEME) |
| **Numérique et IA** | Jauges Claude en % | Fabrication des appareils amortie, usage, **conversion IA → CO₂e** (§ 5) |
| **Services publics et sociétaux** (~10-15 %, non pilotable) | Rien | Forfait par habitant (valeur ADEME/Carbone 4) pour un total comparable |

\* *Ordres de grandeur indicatifs à remplacer par les valeurs de la source retenue (Nos Gestes Climat ou Carbone 4) en phase 1.*

## 4. Principes de calcul

1. **Une activité = une quantité × un facteur d'émission.** Ex. 72,4 L de gazole × facteur gazole (kg CO₂e/L) ; 1 200 km d'avion × facteur avion selon la distance.
2. **Les facteurs sont des données, pas du code** : table `facteurs` avec valeur, unité, incertitude, source, identifiant Base Empreinte, date. On peut mettre à jour un facteur et tout se recalcule.
3. **Mesure > estimation** : pour chaque poste, si des mesures couvrent la période, elles remplacent l'estimation du questionnaire ; sinon l'estimation s'applique. L'interface dit toujours lequel des deux est utilisé.
4. **Incertitude affichée** : chaque total a une fourchette (surtout l'IA et l'alimentation).
5. **Périodes** : bilan annuel glissant, mensuel, et comparaison à la moyenne française.

## 5. L'IA : méthode proposée

Anthropic ne publie pas, à ma connaissance, de chiffre par requête (à vérifier en phase 4). On estime donc :

```
CO₂e ≈ tokens × énergie par token (selon taille de modèle) × PUE du datacenter × intensité carbone de l'électricité
       + part de fabrication du matériel
```

- **Tokens** : exacts pour Claude Code (les journaux locaux `~/.claude/projects/*.jsonl` contiennent l'usage par requête ; le collecteur peut les additionner). Pour l'appli et le web, seule la jauge en % est connue : conversion en tokens **très incertaine**, affichée comme fourchette.
- **Énergie par token** : méthode EcoLogits ; bornes basse (Google, 0,03 g/requête) et haute (Mistral, ~1,1 g/400 tokens) pour situer le résultat.
- Ajouter la **fabrication des appareils** (laptop, desktop, téléphone) amortie sur leur durée de vie : souvent bien plus que l'usage.

## 6. Saisie et collecte

| Canal | Pour quoi | État |
|---|---|---|
| Site : formulaire + photo lue par Claude | Relevés, pleins, tickets | ✅ (à étendre aux nouveaux postes) |
| **Conversation avec Claude (serveur MCP « ODM »)** | « J'ai pris le TGV Lyon–Paris », « plein de 130 € » en vocal sur mobile | À faire : serveur MCP distant (fonction Supabase), branché comme connecteur personnalisé dans claude.ai, outils `ajouter_activite`, `bilan`, `chercher_facteur` |
| Collecteur PC | Jauges Claude ✅ ; tokens Claude Code (journaux locaux) | À étendre |
| Courriels (via Ogma ou Gmail) | Billets de train et d'avion, factures d'énergie | À étudier : détection des confirmations de réservation |
| Relevé bancaire (CSV) | Achats → catégories → ratios monétaires | À étudier, plus tard |
| Questionnaire de base | Alimentation, logement, achats, habitudes | À faire (repris de Nos Gestes Climat) |

## 7. Architecture cible

- **Base** : Supabase (gardé). Nouvelles tables : `activites` (date, poste, sous-poste, quantité, unité, facteur_id, kg CO₂e, source de la donnée), `facteurs`, `profils` (questionnaire, pseudo public). Les `releves` actuels sont convertis en activités (vue ou migration).
- **Calcul** : fonction SQL ou module JS partagé site / MCP, testé contre des cas connus (Nos Gestes Climat comme témoin).
- **Front** : HTML/JS sans build (comme aujourd'hui), pages : bilan (camembert par poste, évolution, comparaison à la moyenne), saisie, questionnaire, méthode et sources.
- **Hébergement** : sortir de `gamgie.github.io/ODM` vers une adresse sur ton site. Le plus simple : un sous-domaine (ex. `conso.tonsite.fr`) pointé vers GitHub Pages (CNAME), rien d'autre à changer ; ou copie des fichiers sur ton hébergement (à décider selon la technologie de ton site).
- **Comptes** : inscription par e-mail, gestion du compte, page publique par pseudo, comparaison entre utilisateurs (reporté de l'étape précédente).

## 8. Phases

Chaque phase se termine par une condition vérifiable, utilisable telle quelle avec `/goal`. Rien n'est poussé sans tests passés.

| Phase | Contenu | Condition de fin (pour `/goal`) | Besoin de toi |
|---|---|---|---|
| **0. Autonomie** | Accès pour que je déploie seul | Je peux lancer une migration SQL et déployer la fonction photo depuis la session | Un jeton d'accès Supabase (Account → Access Tokens), saisi via le formulaire sécurisé — jamais dans le chat |
| **1. Facteurs et CO₂e** | Table `facteurs` (Base Empreinte), calcul CO₂e des relevés existants : électricité, gazole, gaz en bouteille | Le site affiche les kg CO₂e par poste pour les données existantes, chaque chiffre lié à sa source ; tests de calcul passés | Valider les facteurs retenus |
| **2. Bilan complet de base** | Questionnaire (modèle Nos Gestes Climat), forfait services publics, page bilan annuel avec comparaison à la moyenne | Total annuel et répartition par poste affichés après questionnaire ; écart < 10 % avec Nos Gestes Climat sur 2 profils de test | Remplir le questionnaire |
| **3. Transports** | Trajets avion/train/voiture (origine–destination ou distance), API Impact CO2 ou facteurs ADEME | Ajout d'un trajet Lyon–Paris en train et en avion, CO₂e conforme à impactco2.fr | Clé API Impact CO2 (si utilisée) |
| **4. IA et numérique** | Tokens Claude Code par le collecteur, conversion jauges → fourchette, appareils amortis | Bilan « numérique et IA » avec fourchette basse/haute et méthode documentée | Liste de tes appareils (modèle, année) |
| **5. Saisie par conversation** | Serveur MCP ODM (fonction Supabase), connecteur dans claude.ai | Depuis claude.ai, « j'ai fait un plein de 50 € » crée l'activité et renvoie le CO₂e | Ajouter le connecteur dans claude.ai |
| **6. Collecte automatique** | Billets dans les courriels (via Ogma), relevé bancaire CSV | Un billet de train reçu par mail apparaît comme activité à valider | Accès choisi (Ogma ou Gmail) |
| **7. Ton site et les comptes** | Domaine propre, inscription, profils publics, comparaison | Le site répond sur ton domaine ; un 2ᵉ compte de test s'inscrit et ne voit/écrit que ses données | Accès DNS ou hébergement de ton site |

## 9. Ce qui reste hors de portée du mode autonome

- Créer des comptes, payer, saisir des clés : toujours toi, via les formulaires sécurisés.
- Prendre la main sur ton ordinateur : possible seulement si tu partages un dossier avec cette session via Remote Control (appli de bureau Claude → Paramètres → Claude Code) ; cette fonction n'est pas disponible pour tous les comptes. Utile surtout pour tester l'installateur Windows ; le reste se teste depuis la session (navigateur simulé, Postgres local, Deno).
- Le crédit : chaque tour de `/goal` consomme ta jauge hebdomadaire. Lancer une phase à la fois, avec une limite de tours.

## 10. Questions ouvertes

1. URL du site d'Alex Andrix.
2. Ton site perso : adresse, technologie (WordPress, statique…), et où tu veux ODM (sous-domaine, page).
3. Logement : surface, mode de chauffage (électrique, bois, gaz en bouteille pour quoi : cuisson ? chauffage ?).
4. Autres véhicules, et fréquence des trajets en train / avion.
5. Ordre des phases : commencer par 1 (CO₂e de l'existant) puis 2 (bilan complet) ?

## Sources

- [Nos Gestes Climat — à propos](https://nosgestesclimat.fr/en/a-propos), [empreinte carbone](https://nosgestesclimat.fr/empreinte-climat)
- [Carbone 4 — MyCO2](https://www.carbone4.com/en/myco2), [méthodologie de l'empreinte moyenne](https://www.carbone4.com/en/press-releases/communicate-myco2-average-footprint-trends-methodology)
- [ABC — analyse des calculateurs d'empreinte individuelle](https://abc-transitionbascarbone.fr/wp-content/uploads/2022/03/analyse-des-calculateurs-dempreinte-carbone-individuelle-a-lorigine-de-nos-gestes-climat-vf-.pdf)
- [Base Carbone / Base Empreinte sur data.gouv.fr](https://www.data.gouv.fr/dataservices/base-carbone-r), [API Impact CO2](https://www.data.gouv.fr/dataservices/api-impact-co2)
- [Hugging Face — ce que publient les entreprises d'IA](https://huggingface.co/blog/sasha/environmental-impact-disclosures), [Sustainability by Numbers — empreinte de ChatGPT/Gemini](https://www.sustainabilitybynumbers.com/p/ai-footprint-august-2025), [étude Google](https://arxiv.org/html/2508.15734v1)
- [Selectra — empreinte carbone moyenne](https://climate.selectra.com/fr/empreinte-carbone)
