# dim_imputation — colonnes
> 3 949 lignes. Projets / imputations (format pcwat). Multi-parent : DISTINCT avant JOIN.

| Colonne | Type | Description |
|---|---|---|
| `parent` | VARCHAR | Élément parent (vide = racine) |
| `child` | VARCHAR | Code imputation (= valeur dans `analyse.imputation`) |
| `weight` | VARCHAR | Poids de consolidation |
| `id_castor` | VARCHAR | Identifiant Castor (outil de staffing interne) |
| `name` | VARCHAR | Libellé du projet ou de l'imputation |
| `client_id` | VARCHAR | Id client (= `child` du client dans `dim_imputation`) |
| `client_name` | VARCHAR | Nom du client |
| `client_and_name` | VARCHAR | Libellé `Client - Projet` |
| `type_imputation` | VARCHAR | Type d'imputation |
| `orga` | VARCHAR | Code organisation porteuse |
| `bu` | VARCHAR | BU porteuse (ex: `BU Finance & Industrie`) |
| `cdp` | VARCHAR | Code Chef de Projet |
| `tri` | VARCHAR | Clé de tri |
| `force_display` | VARCHAR | Flag d'affichage forcé |
| `is_client` | VARCHAR | `'1'` si nœud client, `'0'` sinon |
| `is_projet` | VARCHAR | `'1'` si vrai projet, `'0'` sinon |
| `forfait_regie` | VARCHAR | `'Forfait'`, `'Régie'`, ou vide (imputations internes) |
| `start_date` | VARCHAR | Date de début (texte, ex: `2024-01-01`) |
| `end_date` | VARCHAR | Date de fin (texte) |
| `start_date_value` | DOUBLE | Date de début en timestamp Unix |
| `end_date_value` | DOUBLE | Date de fin en timestamp Unix |
| `is_actif` | VARCHAR | Flag projet actif |
| `type` | VARCHAR | `C` (consolidé) / `N` (feuille) — dérivé |
