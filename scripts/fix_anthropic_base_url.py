"""
Réapplique le fix du endpoint Anthropic dans la base interne de Nao.

Bug: au démarrage, project_llm_config.base_url est NULL pour provider='anthropic',
ce qui fait appeler https://api.anthropic.com/messages (sans /v1) -> 404 "Not Found".
Fix: forcer base_url = https://api.anthropic.com/v1.

Le fichier db.sqlite vit dans le package nao_core (recréé à chaque réinstall/upgrade),
donc ce script est à relancer après un `pip install`/`nao upgrade`.

Usage:
    python scripts/fix_anthropic_base_url.py
    # puis redémarrer `nao chat` (la config est mise en cache au démarrage).

Idempotent. N'écrit rien si la valeur est déjà correcte.
"""

from __future__ import annotations

import sqlite3
import sys
from importlib.util import find_spec
from pathlib import Path

CORRECT_BASE_URL = "https://api.anthropic.com/v1"


def locate_db() -> Path | None:
    """Trouve nao_core/bin/db.sqlite dans l'environnement Python courant."""
    spec = find_spec("nao_core")
    if spec and spec.origin:
        candidate = Path(spec.origin).parent / "bin" / "db.sqlite"
        if candidate.exists():
            return candidate
    # Repli: chercher dans un éventuel .venv du repo
    repo = Path(__file__).resolve().parent.parent
    hits = list(repo.glob(".venv/**/nao_core/bin/db.sqlite"))
    return hits[0] if hits else None


def main() -> None:
    db = locate_db()
    if db is None:
        print("ERROR: db.sqlite de nao_core introuvable. "
              "Active le venv et installe nao-core d'abord.", file=sys.stderr)
        sys.exit(1)

    print(f"db.sqlite: {db}")
    con = sqlite3.connect(str(db))
    cur = con.cursor()

    # La table peut ne pas exister tant que `nao chat` n'a pas tourné une 1re fois.
    exists = cur.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='project_llm_config'"
    ).fetchone()
    if not exists:
        print("⚠️  Table project_llm_config absente. "
              "Lance `nao chat` une fois (et saisis ta clé), puis relance ce script.")
        con.close()
        return

    rows = cur.execute(
        "SELECT id, base_url FROM project_llm_config WHERE provider='anthropic'"
    ).fetchall()
    if not rows:
        print("ℹ️  Aucune config 'anthropic' encore enregistrée. "
              "Saisis ta clé dans l'UI Nao, puis relance ce script.")
        con.close()
        return

    to_fix = [r for r in rows if r[1] != CORRECT_BASE_URL]
    if not to_fix:
        print(f"✅ Déjà correct ({len(rows)} ligne(s) anthropic, base_url = {CORRECT_BASE_URL}).")
        con.close()
        return

    cur.execute(
        "UPDATE project_llm_config SET base_url=? WHERE provider='anthropic'",
        (CORRECT_BASE_URL,),
    )
    con.commit()
    print(f"✅ {cur.rowcount} ligne(s) corrigée(s) → base_url = {CORRECT_BASE_URL}")
    print("➡️  Redémarre `nao chat` pour que la config soit rechargée.")
    con.close()


if __name__ == "__main__":
    main()
