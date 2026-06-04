# analyse — colonnes
> 11 500 001 lignes. Cube Analyse (suivi FPM / production). Export useRules=true.

| Colonne | Type | Description |
|---|---|---|
| `periode` | VARCHAR | Période : `YYYY` (annuel), `YYYY-MM_YTD` (cumul), `All Months` (total), `~` (technique) |
| `version_fpm` | VARCHAR | Version FPM : `FPM_YYYY_MM` (Production) ou `FPM_YYYY_MM_Simu_NN` (Simulation) |
| `imputation` | VARCHAR | Code imputation / projet (= `child` de `dim_imputation`) |
| `organisation` | VARCHAR | BU / entité (= `child` de `dim_organisation`) |
| `ressource` | VARCHAR | Collaborateur ou nœud (= `child` de `dim_ressource`) |
| `indicateurs_analyse` | VARCHAR | Mesure — **hétérogène** (€, J/H, €/jour, %) : en filtrer UNE |
| `value_raw` | VARCHAR | Valeur brute Jedox (toujours parsable en DOUBLE) |
| `value_num` | DOUBLE | Cast numérique de `value_raw` (100 % non NULL) |
