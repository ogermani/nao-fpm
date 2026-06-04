# Dimensions & JOIN patterns — cube Analyse (LOBELLIA / FPM)

> ⚠️ Squelette à compléter après le 1er export (inspecter les `columns.md` générés pour aliaser
> les attributs réels dans `models/jedox/dim_*.sql`).

## Format pcwat
```
parent | child | weight | <attributs> | type ('C' consolidé / 'N' feuille)
```
- `child` = valeur présente dans le cube `jedox.analyse`. `parent` NULL = racine.
- `type` dérivé : `'C'` si `child` est parent d'une autre ligne, sinon `'N'`.
- **Multi-parent** → `DISTINCT` avant tout JOIN d'attribut.

## Les 6 dimensions

| Table | Clé dans le cube | Attributs attendus | Notes |
|---|---|---|---|
| `dim_periode` | `analyse.periode` | YearValue, QuarterValue, MonthValue, PreviousMonth, JoursOuvrés, YearToDate | grain mensuel |
| `dim_version_fpm` | `analyse.version_fpm` | CurrentMonth, PreviousFpm, NextFpm, Année | forecast glissant |
| `dim_imputation` | `analyse.imputation` | isProjet, ForfaitRegie, StartDateValue, EndDateValue | régie vs forfait |
| `dim_organisation` | `analyse.organisation` | (à inspecter) | BU / départements |
| `dim_ressource` | `analyse.ressource` | (à inspecter) | + Total Ressources / Surproduction |
| `dim_indicateurs_analyse` | `analyse.indicateurs_analyse` | (à inspecter) | mesures hétérogènes |

## Pattern JOIN (libellé)
```sql
-- production € HT par ressource (feuilles), version FPM et mois donnés
SELECT r.name AS ressource, SUM(a.value_num) AS production_eur
FROM jedox.analyse a
JOIN (SELECT DISTINCT child, name, type FROM jedox.dim_ressource) r
  ON r.child = a.ressource
WHERE a.indicateurs_analyse = 'Production (€ HT)'
  AND a.version_fpm = :version_fpm
  AND a.periode = :periode
  AND r.type = 'N'                 -- feuilles uniquement (pas de Total Ressources)
GROUP BY r.name
ORDER BY production_eur DESC;
```

## Roll-up d'un sous-arbre (feuilles uniquement)
```sql
WITH RECURSIVE sub AS (
  SELECT child FROM jedox.dim_organisation WHERE child = :racine
  UNION ALL
  SELECT d.child FROM jedox.dim_organisation d JOIN sub ON d.parent = sub.child
)
SELECT SUM(a.value_num)
FROM jedox.analyse a
WHERE a.organisation IN (SELECT DISTINCT child FROM sub)
  AND a.organisation IN (SELECT child FROM jedox.dim_organisation WHERE type = 'N')
  AND a.indicateurs_analyse = :mesure
  AND a.version_fpm = :version_fpm;
```
