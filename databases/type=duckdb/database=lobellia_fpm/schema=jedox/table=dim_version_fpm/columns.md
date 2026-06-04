# dim_version_fpm — colonnes
> 87 lignes. Versions FPM (scénarios de prévision mensuel glissant).

| Colonne | Type | Description |
|---|---|---|
| `parent` | VARCHAR | Élément parent (vide pour toutes — dim plate, pas de hiérarchie) |
| `child` | VARCHAR | Code version FPM (ex: `FPM_2025_06`, = valeur dans `analyse.version_fpm`) |
| `weight` | VARCHAR | Poids (`1.0` standard) |
| `alias` | VARCHAR | Libellé long (ex: `FPM juin 25`) |
| `alias_simple` | VARCHAR | Code court (ex: `06_25`) |
| `mois` | VARCHAR | Numéro de mois (ex: `6`) |
| `annee` | VARCHAR | Année (ex: `2025`) |
| `previousmonth` | VARCHAR | Mois précédent au format `YYYY-MM` |
| `nextmonth` | VARCHAR | Mois suivant au format `YYYY-MM` |
| `currentmonth` | VARCHAR | Mois courant de la FPM au format `YYYY-MM` |
| `currentmonthvalue1` | DOUBLE | Timestamp Unix du mois courant |
| `afficher` | DOUBLE | Flag d'affichage (`1.0` = visible) |
| `previousfpm` | VARCHAR | Code de la FPM précédente (ex: `FPM_2025_05`) |
| `nextfpm` | VARCHAR | Code de la FPM suivante |
| `type_version` | VARCHAR | `Production` (standard) ou `Simulation` |
| `type` | VARCHAR | `C` (consolidé) / `N` (feuille) — tous `N` (dim plate) |
