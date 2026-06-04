#!/usr/bin/env bash
# setup_mac.sh — Bootstrap du POC Nao "LOBELLIA - FPM" sur Mac (Jedox seul).
#
# Pré-requis:
#   - Python 3.10+ installé (brew install python@3.13 si besoin)
#   - Les extraits Parquet/CSV Jedox de LOBELLIA (cube Analyse / FPM) déposés dans poc-data/
#     (cubes: <Nom>_cubes.parquet ; dimensions: dim_<nom>.parquet ou dim_<nom>.csv)
#   - ~/.anthropic_key contenant ta clé API Anthropic
#
# Usage:
#   chmod +x scripts/setup_mac.sh
#   ./scripts/setup_mac.sh
#
# Ce script:
#   1. Crée un venv Python (.venv)
#   2. Installe les dépendances (requirements.txt) + override mashumaro (compat py3.14)
#   3. dbt build (cubes + dimensions Jedox -> schema jedox du DuckDB)
#   4. Initialise Nao + sync
#   5. Applique le fix endpoint Anthropic

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

echo "▶ Repo: $REPO_DIR"

if [ ! -f "$HOME/.anthropic_key" ]; then
  cat <<EOF
❌ ~/.anthropic_key ABSENT.

Crée le fichier:
  echo -n "sk-ant-api03-..." > ~/.anthropic_key
  chmod 600 ~/.anthropic_key
EOF
  exit 1
fi

# 1. Venv
if [ ! -d ".venv" ]; then
  echo "▶ Création du venv (.venv)..."
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
echo "▶ Venv actif: $(which python)"

# 2. Dépendances
echo "▶ Installation des dépendances..."
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
# Override Python 3.14 : dbt épingle mashumaro <3.18 (casse à l'import sous 3.14) → forcer 3.22.
echo "▶ Override mashumaro (compat Python 3.14)..."
pip install --upgrade "mashumaro==3.22" --quiet

# 3. Chargement Jedox via dbt (cubes + dimensions → schema jedox)
if ls poc-data/*.parquet 1>/dev/null 2>&1 || ls poc-data/dim_*.csv 1>/dev/null 2>&1; then
  echo "▶ dbt build (transformations Jedox → DuckDB) ..."
  dbt build --profiles-dir .
else
  echo "⏭  Skip dbt build (aucun extrait trouvé dans poc-data/)."
  echo "   Dépose les fichiers de LOBELLIA (cube Analyse / FPM) dans poc-data/ puis relance ce script."
fi

# 5. Init + sync Nao
if [ ! -f "nao_config.yaml" ] || ! grep -q "databases" nao_config.yaml; then
  echo "▶ nao init ..."
  PYTHONIOENCODING=utf-8 nao init --yes
fi

echo "▶ nao sync ..."
PYTHONIOENCODING=utf-8 nao sync

# Fix endpoint Anthropic (base_url NULL -> /messages sans /v1 -> 404 Not Found).
# Idempotent ; ne corrige que si une config 'anthropic' existe déjà.
echo "▶ fix endpoint Anthropic (base_url) ..."
python scripts/fix_anthropic_base_url.py || true

cat <<EOF

✅ Setup terminé.

Prochaines étapes:
  1. Lancer le chat:
       export ANTHROPIC_API_KEY="\$(cat ~/.anthropic_key)"
       PYTHONIOENCODING=utf-8 nao chat
  2. Ouvrir http://localhost:5005
  3. Sign up (premier compte = admin)
  4. Admin → Models → Anthropic → coller ta clé + choisir un modèle Claude
  5. Si bug 404 sur l URL Anthropic, voir le fix base_url dans CLAUDE.md
EOF
