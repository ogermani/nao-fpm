# nao-fpm

POC [Nao](https://docs.getnao.io/) sur la base Jedox EPM **`LOBELLIA`**, périmètre **FPM** : le cube
**`Analyse`** (suivi de production / staffing) et ses 6 dimensions. Charge cube + dimensions dans un
DuckDB local (`poc-data/lobellia_fpm.duckdb`) via **dbt** (`models/jedox/`) et expose une couche
sémantique pour l'agent Nao.

> Repris de la logique des projets `nao-labellium` et `nao-lobellia-starter-kit` (Jedox seul).

## Le cube Analyse

`CUBE_CREATE("Analyse"; 0; Période, Version FPM, Imputation, Organisation, Ressource, Indicateurs Analyse)`

→ `jedox.analyse` + 6 dimensions pcwat (`dim_periode`, `dim_version_fpm`, `dim_imputation`,
`dim_organisation`, `dim_ressource`, `dim_indicateurs_analyse`).

## Démarrage rapide (Mac)

```bash
# 1. Exporter depuis Jedox : importer extract_analyse.xml dans Integrator, lancer j_export_analyse
#    → déposer cube_analyse.parquet + dim_*.parquet dans poc-data/

# 2. Bootstrap complet
chmod +x scripts/setup_mac.sh
./scripts/setup_mac.sh

# 3. Lancer le chat
export ANTHROPIC_API_KEY="$(cat ~/.anthropic_key)"
PYTHONIOENCODING=utf-8 .venv/bin/nao chat
# UI: http://localhost:5005
```

## Chargement manuel (dbt)

```bash
# transformations Jedox → schema jedox du DuckDB (+ tests). Lancer depuis la racine du projet.
.venv/bin/dbt build --profiles-dir .
.venv/bin/nao sync                 # génère columns.md / preview.md par table
```

Un modèle SQL par cube/dimension dans `models/jedox/`. ⚠️ Sous Python 3.14, forcer
`mashumaro==3.22` après l'install (cf. `requirements.txt`).

Pour requêter la base **en RAM** : `.venv/bin/python duckdb_mem.py "SELECT ..."`.

Le job d'export Jedox Integrator est [extract_analyse.xml](extract_analyse.xml). Voir
[CLAUDE.md](CLAUDE.md) pour l'architecture et [RULES.md](RULES.md) pour les conventions de requête.
