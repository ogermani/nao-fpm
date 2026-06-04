# dim_ressource — colonnes
> 478 lignes. Collaborateurs + nœuds techniques (format pcwat).

| Colonne | Type | Description |
|---|---|---|
| `parent` | VARCHAR | Élément parent (vide = racine) |
| `child` | VARCHAR | Identifiant collaborateur (= valeur dans `analyse.ressource`) |
| `weight` | VARCHAR | Poids de consolidation |
| `nom_complet` | VARCHAR | Prénom Nom du collaborateur |
| `email` | VARCHAR | Adresse e-mail |
| `start_date` | VARCHAR | Date d'entrée |
| `end_date` | VARCHAR | Date de sortie |
| `organisation` | VARCHAR | BU de rattachement |
| `poste` | VARCHAR | Intitulé de poste |
| `id_castor` | VARCHAR | Identifiant Castor (outil de staffing) |
| `societe` | VARCHAR | Société (LOBELLIA Conseil, Lyon…) |
| `tri` | VARCHAR | Clé de tri |
| `sous_traitant` | VARCHAR | Flag sous-traitant |
| `nom` | VARCHAR | Nom seul |
| `ancien_nom_complet` | VARCHAR | Ancien nom (après changement) |
| `type` | VARCHAR | `C` (nœud consolidé) / `N` (feuille = collaborateur réel) — dérivé |

> Nœuds techniques à exclure des totaux : `Total Ressources`, `Surproduction`,
> `RessourcesFutures`, `Ressource~`. Filtrer `type = 'N'` pour les seuls collaborateurs.
