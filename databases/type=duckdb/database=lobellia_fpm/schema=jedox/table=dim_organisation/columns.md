# dim_organisation — colonnes
> 18 lignes. BU / entités (format pcwat).

| Colonne | Type | Description |
|---|---|---|
| `parent` | VARCHAR | Élément parent (vide = racine) |
| `child` | VARCHAR | Entité (= valeur dans `analyse.organisation`) |
| `weight` | VARCHAR | Poids de consolidation |
| `name` | VARCHAR | Libellé complet |
| `code` | VARCHAR | Code court (ex: `1LOB` pour LOBELLIA Conseil) |
| `id_name` | VARCHAR | Identifiant lisible |
| `country` | VARCHAR | Pays |
| `currency` | VARCHAR | Devise de référence |
| `groupe` | VARCHAR | Groupe de reporting (ex: `LOB_Org_BU_Finance & Industrie`) |
| `type` | VARCHAR | `C` (consolidé) / `N` (feuille) — dérivé |
