# analyse_calc — aperçu (exemples de colonnes clés)

> Table wide — une ligne par (YYYY × version_fpm × imputation × organisation × ressource).
> Exemple : FPM_2024_06, année 2024, quelques ressources feuilles.

| periode | version_fpm | imputation | organisation | ressource | forfait_regie | production_eur | prod_val_regie | prod_val_forfait | tjm | jours_produits_jh | jours_produits_redresses | production_theorique | tjm_theorique | taux_utilisation |
|---------|-------------|------------|--------------|-----------|---------------|----------------|----------------|-----------------|-----|-------------------|--------------------------|----------------------|---------------|------------------|
| 2024 | FPM_2024_06 | 1234 | BU Services | dupont.jean | Régie | 85000.0 | 85000.0 | 0.0 | 600.0 | 141.7 | 141.7 | 85000.0 | 600.0 | 0.78 |
| 2024 | FPM_2024_06 | 5678 | BU Finance & Industrie | martin.sophie | Forfait | 45000.0 | 0.0 | 45000.0 | 650.0 | 69.2 | 52.0 | 33800.0 | 650.0 | 0.65 |
| 2024 | FPM_2024_06 | 910 | LOBELLIA Conseil | leroy.pierre | Régie | 120000.0 | 120000.0 | 0.0 | 750.0 | 160.0 | 160.0 | 120000.0 | 750.0 | 0.92 |

> Note : les valeurs numériques sont indicatives. `taux_utilisation` = ratio (0.78 = 78%).
> `prod_val_forfait` = 0 pour une imputation régie, `prod_val_regie` = 0 pour une imputation forfait.
