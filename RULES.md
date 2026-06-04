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

- **1 cube** : `jedox.analyse` — Période × Version FPM × Imputation × Organisation × Ressource ×
  Indicateurs Analyse → `value_num` (suivi de production / staffing).
- **6 dimensions** pcwat : `dim_periode`, `dim_version_fpm`, `dim_imputation`, `dim_organisation`,
  `dim_ressource`, `dim_indicateurs_analyse`.

Détails : `semantics/jedox_taxonomy.md` (valeurs des axes) et `semantics/jedox_dimensions.md`
(hiérarchies, JOIN/roll-up). Glossaire métier FPM : `semantics/glossaire.md`.

## Règles cube `jedox.analyse` (à appliquer SYSTÉMATIQUEMENT)

1. **Filtrer UNE `indicateurs_analyse`** : les mesures sont **hétérogènes** (`Production (€ HT)` = €,
   `Jours produits (J/H)` = jours, `TJM` = €/jour, `Taux dutilisation` = %, …) → **jamais** les
   additionner entre elles.
2. **Agréger sur `value_num`** (DOUBLE), jamais `value_raw` (VARCHAR).
3. **Filtrer une `version_fpm` explicite** : c'est un forecast mensuel glissant. Ne jamais mélanger
   deux versions FPM dans une même somme (chacune est une photo de prévision à une date donnée).
4. **Grain de base : ANNUEL (`YYYY`)**. Le cube stocke les données à la maille annuelle (2020–2030).
   Les cumuls YTD (`YYYY-MM_YTD`, ex: `2025-06_YTD`) sont disponibles, calculés par les règles Jedox.
   Ne **jamais** additionner une mesure annuelle et une mesure YTD. Pour un cumul annuel d'un flux
   (production, jours) → utiliser l'année (`periode = '2025'`) ou le YTD de décembre (`2025-12_YTD`).
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

## Mesures dérivées (rappel — cube exporté avec `useRules=true`)

Le cube Analyse est piloté par ~130 règles Jedox (production régie/forfait, cumuls YTD, TJM théorique,
taux d'utilisation/présence, comparaison à la FPM précédente via l'attribut `PreviousFpm`…). Les
valeurs dérivées sont **déjà matérialisées** dans le Parquet exporté → les lire directement comme
n'importe quelle `indicateurs_analyse`, **ne pas les recalculer**.

## Orchestration — où trouver les détails

| Sujet | Fichier |
|---|---|
| **Taxonomie** (versions FPM, mesures, périodes, axes) | `semantics/jedox_taxonomy.md` |
| **Dimensions** (hiérarchies, attributs, roll-up) | `semantics/jedox_dimensions.md` |
| **Glossaire** FPM (régie/forfait, TJM, staffing, RAF) | `semantics/glossaire.md` |
| Détails par table (auto-générés) | `databases/type=duckdb/database=lobellia_fpm/schema=jedox/table=<t>/` |
