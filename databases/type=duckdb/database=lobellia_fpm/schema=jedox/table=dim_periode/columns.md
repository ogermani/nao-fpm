# dim_periode — colonnes
> 2 624 lignes. Dimension temporelle (format pcwat).

| Colonne | Type | Description |
|---|---|---|
| `parent` | VARCHAR | Élément parent (vide = racine) |
| `child` | VARCHAR | Élément lui-même (= valeur dans `analyse.periode`) |
| `weight` | VARCHAR | Poids de consolidation (standard : `1.0`) |
| `name` | VARCHAR | Libellé |
| `description` | VARCHAR | Description |
| `timeaggregation` | VARCHAR | Type d'agrégation (`Data Total Element` pour les éléments techniques) |
| `nextyear` | VARCHAR | Année suivante |
| `previousyear` | VARCHAR | Année précédente |
| `quartervalue` | VARCHAR | Trimestre parent |
| `nextmonth` | VARCHAR | Mois suivant |
| `previousmonth` | VARCHAR | Mois précédent |
| `monthvalue` | VARCHAR | Numéro de mois |
| `yearvalue` | VARCHAR | Année (ex: `2025`) |
| `yeartodate` | VARCHAR | Élément YTD correspondant (ex: `2025-06_YTD`) |
| `yeartogo` | VARCHAR | Élément Year-To-Go correspondant |
| `monthyearvalue` | VARCHAR | Type de période (`Year`, `Month`…) |
| `currentmonthvalue1` | DOUBLE | Timestamp Unix du mois (pour tri/comparaison) |
| `currentyear` | VARCHAR | Année courante |
| `jours_ouvres` | DOUBLE | Jours ouvrés du mois (0 pour les nœuds non mensuels) |
| `type` | VARCHAR | `C` (consolidé) / `N` (feuille) — dérivé |
