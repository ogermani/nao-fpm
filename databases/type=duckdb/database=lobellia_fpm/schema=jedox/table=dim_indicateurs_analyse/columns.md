# dim_indicateurs_analyse — colonnes
> 74 lignes. Mesures du cube Analyse (format pcwat). Mesures hétérogènes (€, J/H, €/jour, %).

| Colonne | Type | Description |
|---|---|---|
| `parent` | VARCHAR | Élément parent (vide = racine) |
| `child` | VARCHAR | Code mesure (= valeur dans `analyse.indicateurs_analyse`) |
| `weight` | VARCHAR | Poids de consolidation |
| `alias` | VARCHAR | Libellé lisible (ex: `Production Régie (J/H)`) |
| `type` | VARCHAR | `C` (mesure consolidée) / `N` (mesure de base) — dérivé |

> ⚠️ **Filtrer UNE SEULE mesure** dans toute requête : les unités ne sont pas homogènes.
> Les 38 mesures présentes dans `jedox.analyse` (export `useRules=true`) incluent les mesures
> dérivées (YTD, RAF, TJM, Taux…) déjà calculées par les règles Jedox.
