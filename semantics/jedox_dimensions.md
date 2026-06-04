# Dimensions & JOIN patterns — cube Analyse (LOBELLIA / FPM)

## Format pcwat
```
parent | child | weight | <attributs aliasés> | type ('C' consolidé / 'N' feuille)
```
- `child` = valeur présente dans le cube `jedox.analyse`. `parent` vide = racine.
- `type` dérivé : `'C'` si `child` est parent d'une autre ligne, sinon `'N'` (feuille).
- ⚠️ **Multi-parent** (notamment `dim_imputation`) → `SELECT DISTINCT child, attribut` avant tout JOIN.

## Les 6 dimensions — catalogue complet

| Table | Lignes | Clé dans `analyse` | Attributs aliasés | Notes |
|---|---|---|---|---|
| `dim_periode` | 2 624 | `analyse.periode` | `name`, `yearvalue`, `quartervalue`, `monthvalue`, `previousmonth`, `nextmonth`, `yeartodate`, `yeartogo`, `jours_ouvres`, `currentmonthvalue1`, `timeaggregation` | grain annuel (`YYYY`) + YTD |
| `dim_version_fpm` | 87 | `analyse.version_fpm` | `alias`, `alias_simple`, `mois`, `annee`, `currentmonth`, `currentmonthvalue1`, `previousfpm`, `nextfpm`, `afficher`, `type_version` | forecast glissant ; toutes racines |
| `dim_imputation` | 3 949 | `analyse.imputation` | `id_castor`, `name`, `client_id`, `client_name`, `bu`, `cdp`, `is_projet`, `forfait_regie`, `start_date`, `end_date`, `start_date_value`, `end_date_value`, `is_actif`, `orga`, `tri` | régie vs forfait ; multi-parent |
| `dim_organisation` | 18 | `analyse.organisation` | `name`, `code`, `id_name`, `country`, `currency`, `groupe` | BU / entités |
| `dim_ressource` | 478 | `analyse.ressource` | `nom_complet`, `nom`, `email`, `organisation`, `poste`, `societe`, `sous_traitant`, `start_date`, `end_date`, `id_castor`, `tri`, `ancien_nom_complet` | + nœuds techniques |
| `dim_indicateurs_analyse` | 74 | `analyse.indicateurs_analyse` | `alias` | mesures hétérogènes |

## Patterns de requête

### JOIN libellé ressource
```sql
-- Production € HT par collaborateur (feuilles), pour une version FPM et une année
SELECT
  r.nom_complet                 AS ressource,
  SUM(a.value_num)              AS production_eur
FROM jedox.analyse a
JOIN (SELECT DISTINCT child, nom_complet FROM jedox.dim_ressource WHERE type = 'N') r
  ON r.child = a.ressource
WHERE a.indicateurs_analyse = 'Production (€ HT)'
  AND a.version_fpm        = 'FPM_2025_06'
  AND a.periode            = '2025'          -- grain annuel
GROUP BY r.nom_complet
ORDER BY production_eur DESC;
```

### Filtrer régie vs forfait via dim_imputation
```sql
-- Jours produits Régie, projets actifs, BU Finance & Industrie
SELECT
  i.name                        AS projet,
  SUM(a.value_num)              AS jours_produits
FROM jedox.analyse a
JOIN (SELECT DISTINCT child, name, forfait_regie, bu FROM jedox.dim_imputation
      WHERE is_projet = '1' AND forfait_regie = 'Régie' AND bu = 'BU Finance & Industrie') i
  ON i.child = a.imputation
WHERE a.indicateurs_analyse = 'Jours_produits_regie'
  AND a.version_fpm = 'FPM_2025_06'
  AND a.periode = '2025'
GROUP BY i.name
ORDER BY jours_produits DESC;
```

### YTD — cumul à fin juin
```sql
-- Production cumulée YTD à fin juin 2025 par BU
SELECT
  a.organisation,
  SUM(a.value_num)              AS production_ytd_eur
FROM jedox.analyse a
WHERE a.indicateurs_analyse = 'Production (€ HT)'
  AND a.version_fpm = 'FPM_2025_06'
  AND a.periode = '2025-06_YTD'         -- cumul jan→jun 2025
  AND a.organisation NOT IN ('Total Groupe LOBELLIA', 'LOBELLIA Conseil', '~')
GROUP BY a.organisation
ORDER BY production_ytd_eur DESC;
```

### Roll-up d'un sous-arbre d'organisation (feuilles)
```sql
WITH RECURSIVE sub AS (
  SELECT child FROM jedox.dim_organisation WHERE child = 'LOBELLIA Conseil'
  UNION ALL
  SELECT d.child FROM jedox.dim_organisation d JOIN sub ON d.parent = sub.child
)
SELECT SUM(a.value_num) AS total
FROM jedox.analyse a
WHERE a.organisation IN (
        SELECT DISTINCT s.child FROM sub s
        JOIN jedox.dim_organisation d ON d.child = s.child AND d.type = 'N'
      )
  AND a.indicateurs_analyse = 'Production (€ HT)'
  AND a.version_fpm = 'FPM_2025_06'
  AND a.periode = '2025';
```

## ⚠️ Pièges fréquents

1. **Ne jamais additionner plusieurs `indicateurs_analyse`** : unités hétérogènes.
2. **Nœuds de consolidation dans les faits** : `Total Groupe LOBELLIA`, `Total Ressources`,
   `All Months`… sont présents dans le cube (export `celltype="both"`) → les exclure explicitement
   ou filtrer sur `type='N'` dans la dimension correspondante.
3. **`Surproduction`** (dans `dim_ressource`) : nœud technique qui porte l'écart de production
   forfait non affectable. À exclure des totaux collaborateurs.
4. **`~`** : élément technique Jedox présent dans plusieurs dims (`periode`, `organisation`,
   `ressource`) → toujours exclure.
5. **Versions Simulation** (`FPM_2026_01_Simu_01`…) : forecasts alternatifs. Ne pas mélanger avec
   les versions Production dans une même agrégation.
6. **Multi-parent** sur `dim_imputation` : un même projet peut apparaître sous plusieurs nœuds
   parents → `DISTINCT child` avant tout JOIN d'attribut.
