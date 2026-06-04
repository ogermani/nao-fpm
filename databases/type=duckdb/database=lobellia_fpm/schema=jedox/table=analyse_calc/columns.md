# analyse_calc — colonnes
> Cube Analyse enrichi (format wide). Grain YYYY × version_fpm × imputation × organisation × ressource.
> Recalcule les règles Jedox absentes du Parquet. **Préférer cette table pour toute analyse FPM.**

## Clés de dimension

| Colonne | Type | Description |
|---|---|---|
| `periode` | VARCHAR | Année (`YYYY`) — grain annuel uniquement |
| `version_fpm` | VARCHAR | Version FPM (ex: `FPM_2025_06`) |
| `imputation` | VARCHAR | Code imputation / projet |
| `organisation` | VARCHAR | BU / entité |
| `ressource` | VARCHAR | Collaborateur ou nœud |

## Attributs de dimension (pré-joints)

| Colonne | Source | Description |
|---|---|---|
| `forfait_regie` | `dim_imputation` | `'Régie'`, `'Forfait'`, ou vide |
| `is_projet` | `dim_imputation` | `'1'` si vrai projet |
| `bu` | `dim_imputation` | BU porteuse |
| `cdp` | `dim_imputation` | Chef de projet |
| `client_id` | `dim_imputation` | Id client |
| `client_name` | `dim_imputation` | Nom du client |
| `imputation_name` | `dim_imputation` | Libellé de l'imputation |
| `fpm_annee` | `dim_version_fpm` | Année du forecast |
| `fpm_mois` | `dim_version_fpm` | Mois du forecast |
| `fpm_alias` | `dim_version_fpm` | Libellé (ex: `FPM juin 25`) |
| `fpm_currentmonth` | `dim_version_fpm` | Mois de référence `YYYY-MM` |
| `previousfpm` | `dim_version_fpm` | Code de la FPM précédente |
| `nextfpm` | `dim_version_fpm` | Code de la FPM suivante |
| `fpm_type` | `dim_version_fpm` | `Production` ou `Simulation` |
| `jours_ouvres_annuels` | `dim_periode` | Jours ouvrés de l'année |

## Mesures de base (depuis `jedox.analyse`)

| Colonne | Unité | Description |
|---|---|---|
| `production_eur` | € HT | Production totale (régie + forfait) |
| `prod_val_regie` | € HT | Production régie valorisée |
| `jours_produits_jh` | J/H | Jours produits totaux |
| `jours_produits_regie` | J/H | Jours produits régie |
| `jours_imputes` | J/H | Jours saisis dans les feuilles de temps |
| `jours_consommes` | J/H | Jours consommés / valorisés |
| `jours_produits_raf` | J/H | Jours produits — Reste À Faire |
| `tjm_annuel` | €/j | TJM annuel de référence |
| `tjm_mensuel` | €/j | TJM mensuel (si saisi) |
| `tjm_annuel_achete` | €/j | TJM annuel sous-traitants |
| `tjm_mensuel_achete` | €/j | TJM mensuel sous-traitants |
| `production_raf` | € HT | Production — Reste À Facturer |
| `raf_jours_produits_regie` | J/H | RAF jours régie |
| `raf_prod_val_regie` | € HT | RAF valeur régie |
| `raf_prod_jh_forfait` | J/H | RAF jours forfait |
| `raf_prod_val_forfait` | € HT | RAF valeur forfait |
| `marge_ht` | € HT | Marge brute totale |
| `marge_ht_regie` | € HT | Marge brute régie |
| `marge_ht_forfait` | € HT | Marge brute forfait |
| `valorisation_jours_conso` | € HT | Valorisation des jours consommés |
| `valorisation` | € HT | Valorisation interne |
| `effectif_mensuel` | ETP | Effectif mensuel |
| `jours_vendus` | J/H | Jours vendus contractuellement |
| `jours_achetes` | J/H | Jours achetés (sous-traitants) |
| `jours_achetes_raf` | J/H | RAF jours achetés |
| `montant_achete_raf` | € HT | RAF montant acheté |

## Mesures dérivées (règles Jedox recalculées)

| Colonne | Règle | Unité | Description |
|---|---|---|---|
| `prod_val_forfait` | — | € HT | `production_eur − prod_val_regie` |
| `jours_produits_forfait` | — | J/H | `jours_produits_jh − jours_produits_regie` |
| `tjm` | 15 | €/j | `COALESCE(tjm_mensuel, tjm_annuel)` |
| `tjm_achete` | 16 | €/j | `COALESCE(tjm_mensuel_achete, tjm_annuel_achete)` |
| `jours_produits_redresses` | 22 | J/H | Régie→jours_regie · Forfait→jours_imputés |
| `jours_produits_et_absences` | (Jedox) | J/H | Déjà calculé par Jedox au nœud consolidé |
| `production_theorique` | 24 | € HT | Régie→prod réelle · Forfait→redressé×TJM · Surprod→NULL |
| `tjm_theorique` | 26 | €/j | `production_theorique / ROUND(jours_redresses, 2)` |
| `taux_utilisation` | 4 | ratio | `jours_produits_et_absences / jours_ouvres_annuels` |

> ⚠️ `taux_utilisation` est un ratio (ex: `0.85` = 85%), pas un pourcentage.
> Ne jamais sommer `taux_utilisation` entre ressources — calculer la moyenne pondérée.
