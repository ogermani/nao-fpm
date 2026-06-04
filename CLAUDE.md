# Nao POC — LOBELLIA / cube Analyse (Jedox FPM)

## Objectif
POC Nao (https://docs.getnao.io/) sur la base Jedox **`LOBELLIA`**, périmètre **FPM** : le cube
**`Analyse`** (suivi de production / staffing) et ses 6 dimensions. Même logique que
`nao-lobellia-starter-kit` (Jedox seul, pas de MongoDB) : on charge cube + dimensions dans un
**DuckDB local** via **dbt**, avec une couche sémantique pour piloter l'agent Nao.

Nao ne lit pas Jedox nativement → **dump local DuckDB** (`poc-data/lobellia_fpm.duckdb`).

## Architecture

```
nao-fpm/
├── .venv/                              ← venv Python (nao-core + duckdb + dbt + ...)
├── extract_analyse.xml                 ← JOB Jedox Integrator : export Parquet du cube + dims
├── poc-data/                           ← extraits Jedox + DuckDB (git-ignorés)
│   ├── lobellia_fpm.duckdb             ← base DuckDB locale (schema `jedox`)
│   ├── cube_analyse.parquet            ← cube Analyse (→ jedox.analyse)
│   ├── dim_periode.parquet             ← temps (mois → trimestre → année)
│   ├── dim_version_fpm.parquet         ← versions FPM (forecast mensuel)
│   ├── dim_imputation.parquet          ← imputations / projets
│   ├── dim_organisation.parquet        ← organisation (BU / départements)
│   ├── dim_ressource.parquet           ← ressources (collaborateurs)
│   └── dim_indicateurs_analyse.parquet ← mesures (Production €, Jours produits, TJM…)
├── databases/type=duckdb/database=lobellia_fpm/
│   └── schema=jedox/                   ← tables auto-générées par `nao sync` (columns.md/preview.md)
├── semantics/
│   ├── jedox_taxonomy.md               ← versions, mesures, périodes, axes (à compléter)
│   ├── jedox_dimensions.md             ← pcwat, JOIN patterns, hiérarchies (à compléter)
│   └── glossaire.md                    ← vocabulaire métier FPM (staffing, régie/forfait, TJM…)
├── RULES.md                            ← règles agent (cube Analyse)
├── nao_config.yaml                     ← config DuckDB (db: lobellia_fpm)
├── dbt_project.yml · profiles.yml      ← projet dbt (profile lobellia_fpm, schema jedox)
├── models/jedox/                       ← 1 modèle SQL par cube/dim + schema.yml (tests/descriptions)
├── macros/jedox.sql                    ← macro src() + generate_schema_name (schéma exact `jedox`)
├── duckdb_mem.py                       ← monter la base en RAM pour les requêtes
├── scripts/
│   ├── setup_mac.sh                    ← bootstrap Mac (venv, deps, dbt build, sync, fix Anthropic)
│   └── fix_anthropic_base_url.py       ← réapplique base_url=…/v1 dans le db.sqlite de nao_core
└── requirements.txt                    ← inclut dbt-duckdb
```

## Le cube Analyse (source `.jds`)

Défini dans `LOBELLIA.jds` par :
`CUBE_CREATE("Analyse"; 0; Période, Version FPM, Imputation, Organisation, Ressource, Indicateurs Analyse)`

**6 dimensions** :

| # | Dimension | Rôle |
|---|-----------|------|
| 1 | Période | temps (mois → trimestre → année) |
| 2 | Version FPM | scénarios de prévision (forecast mensuel glissant) |
| 3 | Imputation | projets / imputations (attributs `isProjet`, `ForfaitRegie`, dates) |
| 4 | Organisation | BU / départements |
| 5 | Ressource | collaborateurs (+ nœuds `Total Ressources`, `Surproduction`) |
| 6 | Indicateurs Analyse | mesures (Production €, Jours produits, TJM, Taux d'utilisation…) |

> Le cube est **fortement piloté par règles** (≈130 `RULE_CREATE` dans le `.jds`) : production
> régie/forfait, cumuls YTD, TJM théorique, taux d'utilisation/présence, comparaison à la FPM
> précédente (`PreviousFpm`). Export avec **`useRules=true`** → les mesures dérivées sont
> matérialisées dans le Parquet.

## Flux de chargement

1. **Exporter depuis Jedox** : importer `extract_analyse.xml` dans Jedox Integrator (groupe de
   projets LOBELLIA), vérifier la connexion OLAP (`c_olap_lobellia` → base `LOBELLIA`), lancer le
   job `j_export_analyse`. Récupérer les 7 `*.parquet` et les déposer dans `poc-data/`.
2. **`dbt build --profiles-dir .`** → matérialise cube + dims dans le schéma `jedox`
   (snake_case + `value_num`, `type` C/N dérivé) **et** lance les tests.
3. **`nao sync`** → génère `columns.md` / `preview.md` par table.
4. **Affiner** `models/jedox/dim_*.sql` (aliaser les attributs réels une fois le Parquet inspecté)
   et `semantics/*.md`.

> ⚠️ Lancer `dbt` **depuis la racine** du projet (chemins relatifs) et **arrêter `nao chat`** avant
> (verrou écriture DuckDB).
>
> ⚠️ **Python 3.14** : dbt épingle `mashumaro <3.18` qui casse à l'import sous 3.14 → forcer
> `mashumaro==3.22` après l'install (cf. `requirements.txt` / `setup_mac.sh`).

## Format pcwat (toutes les dims)

```
parent | child | weight | <attributs spécifiques par dim> | type (dérivée: 'C' ou 'N')
```

- `child` = la valeur qu'on retrouve dans le cube. `parent` = NULL si racine.
- `type` = `'C'` si `child` apparaît comme `parent` d'une autre ligne (consolidé), sinon `'N'` (feuille).
- **Multi-parent** : un même `child` peut apparaître sur plusieurs lignes → toujours `DISTINCT` quand
  on récupère un attribut.

> Les modèles `dim_*.sql` passent pour l'instant **tous** les attributs du Parquet tels quels
> (`* EXCLUDE` des 3 colonnes pcwat). Après le 1er export, aliaser les attributs utiles en snake_case
> (cf. `dim_periode.sql` du starter-kit pour le modèle).

## Conventions de requête (détail dans RULES.md)

- Filtrer une **`version_fpm`** explicite (jamais mélanger deux forecasts dans une somme).
- Filtrer **UNE `indicateurs_analyse`** : les mesures sont hétérogènes (€, J/H, TJM, %…).
- Agréger sur `value_num` (DOUBLE), pas `value_raw` (VARCHAR).
- Filtrer les agrégats OLAP (`Total Ressources`, nœuds consolidés) sauf demande de total.
- `DISTINCT` sur les dims (multi-parent) avant un JOIN.

## Requêter la base en mémoire (RAM)

```bash
.venv/bin/python duckdb_mem.py "SELECT COUNT(*) FROM jedox.analyse"   # requête ad hoc en RAM
.venv/bin/python duckdb_mem.py                                        # résumé (schémas/tables)
```

## Lancer Nao chat (Mac)

```bash
cd ~/code/nao-fpm
export ANTHROPIC_API_KEY="$(cat ~/.anthropic_key)"   # optionnel : saisissable dans l'UI
PYTHONIOENCODING=utf-8 .venv/bin/nao chat
# UI: http://localhost:5005  (1er compte = admin)
```

## Bug Nao à mémoriser — endpoint Anthropic

Au démarrage, `project_llm_config.base_url` est `NULL` pour `provider='anthropic'` → Nao appelle
`https://api.anthropic.com/messages` (sans `/v1/`) → **404 / "Not Found"**.

**Fix** : `python scripts/fix_anthropic_base_url.py` (idempotent ; force
`base_url='https://api.anthropic.com/v1'`), **puis redémarrer `nao chat`**. À relancer après tout
`pip install` / `nao upgrade` (recrée `db.sqlite`).

## Setup rapide

```bash
chmod +x scripts/setup_mac.sh
./scripts/setup_mac.sh   # venv + deps + dbt build (si extraits présents) + sync + fix Anthropic
```

## RAF (Reste À Faire)

1. **Lancer le job** `extract_analyse.xml` dans Jedox, déposer les Parquet dans `poc-data/`.
2. **`dbt build`** puis **`nao sync`** ; inspecter les `columns.md` générés.
3. **Aliaser les attributs réels** dans `models/jedox/dim_*.sql` (snake_case).
4. **Compléter `semantics/*.md`** (taxonomie versions FPM, mesures, glossaire staffing).
5. **Affiner `RULES.md`** au vu des premiers tests agent.
6. (Roadmap) Recalcul des règles du cube dans DuckDB (extract base-only `useRules=false`).

## Sécurité
- DuckDB local et extraits Jedox sont git-ignorés (`poc-data/`). Ne jamais commit de données.
- Ne jamais commit la clé Anthropic.
