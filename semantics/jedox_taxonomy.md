# Taxonomie — cube Analyse (LOBELLIA / FPM)

> Renseigné depuis l'inspection directe des Parquet (`dbt build` pas encore lancé).
> Compléter la section mesures après `nao sync` en inspectant `databases/.../dim_indicateurs_analyse/preview.md`.

## Cube `jedox.analyse`

Grain : **Version FPM × Période × Imputation × Organisation × Ressource × Indicateurs Analyse → value_num**.
11 500 001 lignes. Export avec `useRules=true` → mesures dérivées matérialisées.

| Colonne | Rôle | Valeurs présentes |
|---|---|---|
| `version_fpm` | Scénario de prévision | `FPM_2022_05` → `FPM_2026_07` (52 versions Production + 3 Simulation) |
| `periode` | Période | `YYYY` annuel (2020–2030) · `YYYY-MM_YTD` (cumuls) · `All Months` (total) · `~` (technique) |
| `imputation` | Code imputation / projet | code numérique (IdCastor) ou libellé |
| `organisation` | BU / entité | `Total Groupe LOBELLIA`, `LOBELLIA Conseil`, `BU Finance & Industrie`, `BU Public`, `BU Services`, `LOBELLIA Lyon`, `9EXT`, `ASTILLIA`… |
| `ressource` | Collaborateur | code Jedox (libellé dans `dim_ressource.nom_complet`) |
| `indicateurs_analyse` | Mesure | 38 mesures distinctes — **hétérogènes** (€, J/H, €/jour, %) |
| `value_raw` | Valeur brute (VARCHAR) | toutes parsables en DOUBLE |
| `value_num` | Valeur numérique (DOUBLE) | 100 % non NULL |

## Versions FPM (`dim_version_fpm`) — 87 membres

Format : `FPM_YYYY_MM` (Production) ou `FPM_YYYY_MM_Simu_NN` (Simulation).
Toutes les versions sont des **racines** (pas de hiérarchie parent-enfant).

| Attribut | Rôle |
|---|---|
| `alias` | Libellé court (ex: `FPM mai 26`) |
| `alias_simple` | Code court (ex: `05_26`) |
| `mois` / `annee` | Mois et année du forecast |
| `currentmonth` | Mois de référence au format `YYYY-MM` |
| `currentmonthvalue1` | Timestamp Unix du mois courant |
| `previousfpm` / `nextfpm` | Navigation entre forecasts |
| `type_version` | `Production` (standard) ou `Simulation` |

**Plage disponible dans les faits** : `FPM_2022_05` → `FPM_2026_07` (52 versions Production + 3 Simulation).

➡️ Pour "la dernière FPM" → filtrer sur `type_version = 'Production'` et prendre la plus récente.
➡️ Pour comparer deux forecasts successifs, utiliser `previousfpm` / `nextfpm`.

## Mesures (`dim_indicateurs_analyse`) — 38 présentes dans les faits

⚠️ **Hétérogènes** → **en filtrer une seule** (cf. RULES.md §1).

| Famille | Mesures disponibles dans le cube | Unité |
|---|---|---|
| **Production €** | `Production (€ HT)`, `Prod_val_regie`, `Marge HT`, `Marge HT Régie`, `Marge HT Forfait`, `Valorisation`, `Valorisation Acheté`, `Valorisation Vendu`, `Valorisation_jours_conso`, `Budget (€ HT)`, `Budget_val_regie`, `Budget_val_forfait`, `Production (RAF)`, `Raf_prod_val_regie`, `Raf_prod_val_forfait`, `Montant Acheté (Raf)`, `Montant Acheté (YTD)` | € HT |
| **Jours** | `Jours produits (J/H)`, `Jours_imputés`, `Jours_consommés`, `Jours_produits_regie`, `Jours absences`, `Jours Vendus`, `Jours Achetés`, `Jours Produits & Absences`, `Budget (J/H)`, `Budget_jh_regie`, `Budget_jh_forfait`, `Jours produits (RAF)`, `RAF_jours_produits_regie`, `Raf_prod_jh_forfait`, `Jours Achetés (Raf)`, `Jours Achetés (YTD)` | J/H |
| **TJM** | `TJM Annuel`, `TJM Mensuel`, `TJM Annuel Acheté`, `TJM Mensuel Acheté` | €/jour |
| **Effectifs** | `Effectif mensuel` | ETP |

> Les mesures consolidées (`TJM` global, `Taux dutilisation`, `Taux présence`, `Potentiel de prod`,
> `Production theorique`, YTD mensuels…) existent dans `dim_indicateurs_analyse` (type `C`) mais
> ne sont **pas toutes** dans les faits — vérifier avec `SELECT DISTINCT indicateurs_analyse FROM jedox.analyse`.

## Périodes (`dim_periode`) — 2 624 membres

**Grain de base : ANNUEL**. Les données sont stockées à la maille `YYYY` (2020–2030).

| Format | Description | Exemple |
|---|---|---|
| `YYYY` | Année (grain de base des faits) | `2025` |
| `YYYY-MM_YTD` | Cumul depuis janvier jusqu'au mois MM | `2025-06_YTD` |
| `All Months` | Racine / total général | — |
| `~` | Élément technique Jedox | — |

Attributs utiles : `yearvalue`, `quartervalue`, `monthvalue`, `previousmonth`, `nextmonth`,
`yeartodate`, `yeartogo`, `jours_ouvres`, `currentmonthvalue1`, `timeaggregation`.

➡️ Pour une année : `WHERE periode = '2025'`. Pour un cumul à fin juin : `WHERE periode = '2025-06_YTD'`.

## Organisation (`dim_organisation`) — 18 membres

Hiérarchie : `Total Groupe LOBELLIA` → `LOBELLIA Conseil` / `9EXT` / `ASTILLIA` → BUs.

| Attribut | Rôle |
|---|---|
| `name` | Libellé complet |
| `code` | Code court (ex: `1LOB`) |
| `id_name` | Identifiant lisible |
| `groupe` | Groupe de reporting |

## Ressource (`dim_ressource`) — 478 membres

Collaborateurs (feuilles `type='N'`) + nœuds : `Total Ressources`, `Surproduction`, `RessourcesFutures`, `Ressource~`.

| Attribut | Rôle |
|---|---|
| `nom_complet` | Prénom Nom |
| `nom` | Nom seul |
| `email` | Email |
| `organisation` | BU de rattachement |
| `poste` | Intitulé de poste |
| `societe` | Société (LOBELLIA Conseil, Lyon…) |
| `sous_traitant` | Flag sous-traitant |
| `start_date` / `end_date` | Dates d'entrée / sortie |

## Imputation (`dim_imputation`) — 3 949 membres

| Attribut | Rôle |
|---|---|
| `id_castor` | Identifiant interne |
| `name` | Libellé du projet / imputation |
| `client_name` / `client_id` | Client associé |
| `bu` | BU porteuse |
| `cdp` | Chef de projet |
| `is_projet` | `'1'` si vrai projet (vs imputation interne) |
| `forfait_regie` | `'Forfait'` ou `'Régie'` (blank si non projet) |
| `start_date` / `end_date` | Dates du projet |
| `start_date_value` / `end_date_value` | Timestamps Unix correspondants |
| `is_actif` | Flag projet actif |
