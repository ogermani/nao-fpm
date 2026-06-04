# Règles agent — LOBELLIA / cube Analyse (Jedox FPM)

## Langue et style
- Réponds en **français**.
- Si une question est ambiguë (ex: "la production" = quelle version FPM ? quelle période ? quelle
  mesure ?), **pose une question avant** de répondre.
- Quand tu produis du SQL, ajoute un commentaire en tête expliquant les hypothèses métier retenues.

## Style SQL
- Indentation 2 espaces, mots-clés en MAJUSCULES, alias courts (`a` cube analyse, `d` dimension).
- Évite `SELECT *`. **Toujours préfixer le schema** (`jedox.analyse`, `jedox.dim_ressource`…).

## Source de données

Base DuckDB `lobellia_fpm`, schéma **`jedox`** (source Jedox EPM `LOBELLIA`, **français**).

### Tables principales

| Table | Format | Usage |
|---|---|---|
| `jedox.analyse` | **Tall** (Indicateurs Analyse en colonne) | Mesures de base, grain YYYY + YYYY-MM_YTD. Filtrer `indicateurs_analyse`. |
| `jedox.analyse_calc` | **Wide** (1 colonne/mesure, grain YYYY) | Mesures dérivées recalculées + attributs dims. **Préférer pour toute analyse FPM.** |
| `jedox.dim_periode` | pcwat | Hiérarchie temps, attribut `jours_ouvres` |
| `jedox.dim_version_fpm` | pcwat | Versions FPM, attributs `previousfpm`, `currentmonth` |
| `jedox.dim_imputation` | pcwat | Projets/imputations, attributs `forfait_regie`, `is_projet` |
| `jedox.dim_organisation` | pcwat | BU / entités |
| `jedox.dim_ressource` | pcwat | Collaborateurs |
| `jedox.dim_indicateurs_analyse` | pcwat | Catalogue des mesures (utile pour `jedox.analyse`) |

**Règle de choix :**
- Question sur une mesure dérivée (`TJM`, `taux_utilisation`, `prod_val_forfait`…) → **`jedox.analyse_calc`**
- Question sur une mesure de base ou besoin du grain YTD (`YYYY-MM_YTD`) → **`jedox.analyse`**

Détails : `semantics/jedox_taxonomy.md` (valeurs des axes) et `semantics/jedox_dimensions.md`
(hiérarchies, JOIN/roll-up). Glossaire métier FPM : `semantics/glossaire.md`.

## Règles cube `jedox.analyse` (à appliquer SYSTÉMATIQUEMENT)

1. **Filtrer UNE `indicateurs_analyse`** : les mesures sont **hétérogènes** (`Production (€ HT)` = €,
   `Jours produits (J/H)` = jours, `TJM` = €/jour, `Taux dutilisation` = %, …) → **jamais** les
   additionner entre elles.
2. **Agréger sur `value_num`** (DOUBLE), jamais `value_raw` (VARCHAR).
3. **`version_fpm` : utiliser la FPM courante par défaut.** Si l'utilisateur ne précise pas de version
   FPM, utiliser automatiquement la FPM de Production la plus récente (≤ date du jour) :
   ```sql
   SELECT child FROM jedox.dim_version_fpm
   WHERE type_version = 'Production'
     AND currentmonth <= strftime(current_date, '%Y-%m')
   ORDER BY currentmonth DESC LIMIT 1
   ```
   Mentionner dans la réponse quelle FPM a été retenue (ex : *"j'utilise la FPM de juin 2026"*).
   Ne jamais mélanger deux versions FPM dans une même somme.
4. **Grain mensuel `YYYY-MM`** (2020-01 → 2030-12). Toujours filtrer une plage de mois cohérente.
   Pour un cumul annuel → sommer les 12 mois ou utiliser la colonne `*_ytd` de `jedox.analyse_calc`.
   Ne **jamais** mélanger des mois de versions FPM différentes dans une agrégation.
5. **Ressource** : exclure les nœuds consolidés (`Total Ressources`) et l'élément technique
   `Surproduction` sauf demande explicite → sinon double-comptage. Filtrer les feuilles (`type='N'`).
6. **Imputation** : distinguer **régie** et **forfait** via l'attribut `ForfaitRegie`, et les vrais
   projets via `isProjet`. Beaucoup de règles du cube ne s'appliquent qu'au forfait/projet.

## Règles dimensions (à appliquer SYSTÉMATIQUEMENT)

7. **Ne pas sommer aveuglément une dimension entière** : les feuilles coexistent avec des nœuds
   consolidés (`type='C'`) déjà agrégés. Pour un total granulaire → roll-up d'un seul sous-arbre via
   CTE récursive restreinte à `type='N'` ; pour un total déjà agrégé → lire le nœud consolidé.
8. **Multi-parent** : un même `child` peut appartenir à plusieurs hiérarchies → `SELECT DISTINCT
   child, attribut` avant un JOIN, et `WHERE type='N'` quand on collecte les feuilles d'un sous-arbre.
9. **Libellés** : joindre l'attribut `name` de la dimension pour rendre un code lisible
   (ex: `ressource`, `imputation` peuvent être des codes).

## Mesures dérivées — recalculées dans `jedox.analyse_calc`

Le Parquet exporté ne contient **pas** les mesures calculées par les 26 règles Jedox. Elles sont
recalculées dans le modèle dbt `jedox.analyse_calc` (format wide, grain YYYY).

**Mesures disponibles dans `jedox.analyse_calc` (grain YYYY-MM) :**
- `marge_ht` = `marge_ht_regie + marge_ht_forfait`
- `tjm` = `COALESCE(tjm_mensuel, tjm_annuel)` [règle 15]
- `tjm_achete` = `COALESCE(tjm_mensuel_achete, tjm_annuel_achete)` [règle 16]
- `jours_produits_redresses` : Régie→jours_regie · Forfait→jours_imputés [règle 22]
- `production_theorique` : Régie→prod_val_regie · Forfait→redressé×TJM [règle 24]
- `tjm_theorique` = `production_theorique / ROUND(jours_redresses, 2)` [règle 26]
- `taux_utilisation` = `Jours Produits & Absences / jours_ouvres` [règle 4 — mensuel]
- `taux_utilisation_ytd` = cumul annuel via window function
- `*_ytd` : YTD accumulés par année pour les mesures clés (prod_val_regie, jours_produits_regie, jours_imputes, jours_consommes, jours_produits_redresses, marge_ht) [règles 9-10]
- Attributs dims pré-joints : `forfait_regie`, `bu`, `cdp`, `client_name`, `fpm_alias`, `previousfpm`…

**Non recalculé** :
- `Production (€ HT)` et `Jours produits (J/H)` (totaux régie+forfait calculés par règles Jedox)
- `Production (prev année)`, Taux présence, Potentiel de prod

→ Voir `semantics/jedox_regles_cube.md` pour la logique complète de chaque règle.

## Orchestration — où trouver les détails

| Sujet | Fichier |
|---|---|
| **Taxonomie** (versions FPM, mesures, périodes, axes) | `semantics/jedox_taxonomy.md` |
| **Règles de gestion** (logique de calcul de chaque mesure) | `semantics/jedox_regles_cube.md` |
| **Dimensions** (hiérarchies, attributs, roll-up, pièges) | `semantics/jedox_dimensions.md` |
| **Glossaire** FPM (régie/forfait, TJM, staffing, RAF) | `semantics/glossaire.md` |
| Détails par table (colonnes, aperçu) | `databases/type=duckdb/database=lobellia_fpm/schema=jedox/table=<t>/` |
