"""
Monte la base DuckDB sur disque entièrement en RAM, puis requête en mémoire.

Le fichier `poc-data/lobellia_fpm.duckdb` reste la **source durable** sur disque.
Cet utilitaire en fait une copie 100 % en RAM (catalogue + données), via le pattern DuckDB :

    ATTACH '<db>' AS disk (READ_ONLY);
    COPY FROM DATABASE disk TO memory;   -- clone tout dans la base in-memory
    DETACH disk;                          -- on coupe le disque : tout est en RAM (et modifiable)

La connexion retournée est une base `:memory:` **modifiable** (utile pour des calculs jetables,
ex: recalcul de règles). Aucune écriture sur le fichier disque (ATTACH en READ_ONLY).

Usage CLI :
    python duckdb_mem.py "SELECT COUNT(*) FROM jedox.analyse"
    python duckdb_mem.py                     # résumé (schémas/tables/lignes) + temps de mount

Note perfs : à ~30 Mo, DuckDB bufferise déjà la base disque → gain marginal. L'intérêt grandit
avec la volumétrie. Nao, lui, lit toujours le fichier disque en lecture seule (inchangé).
"""

from __future__ import annotations

import sys
import time
from pathlib import Path

import duckdb

DB = Path(__file__).resolve().parent / "poc-data" / "lobellia_fpm.duckdb"


def connect_in_memory(
    db_path: Path | str = DB,
    source_read_only: bool = True,
) -> duckdb.DuckDBPyConnection:
    """Retourne une connexion DuckDB :memory: préchargée depuis `db_path`.

    Toute la base disque (schémas + tables) est clonée en RAM puis le disque est détaché :
    les requêtes suivantes ne touchent plus le fichier. La connexion est modifiable.
    """
    path = Path(db_path)
    if not path.exists():
        raise FileNotFoundError(
            f"Base introuvable : {path}\n"
            "Charge-la d'abord : python dbt build --profiles-dir ."
        )

    con = duckdb.connect(":memory:")
    ro = " (READ_ONLY)" if source_read_only else ""
    con.execute(f"ATTACH '{path}' AS disk{ro}")
    con.execute("COPY FROM DATABASE disk TO memory")
    con.execute("DETACH disk")
    return con


def _summary(con: duckdb.DuckDBPyConnection) -> None:
    rows = con.execute(
        """
        SELECT table_schema, COUNT(*) AS n_tables
        FROM information_schema.tables
        WHERE table_schema NOT IN ('information_schema', 'pg_catalog')
        GROUP BY 1 ORDER BY 1
        """
    ).fetchall()
    total = sum(n for _, n in rows)
    print(f"Schémas en RAM ({total} tables) :")
    for schema, n in rows:
        print(f"  - {schema}: {n} tables")


def main() -> None:
    sys.stdout.reconfigure(line_buffering=True)

    t0 = time.perf_counter()
    con = connect_in_memory()
    t_mount = (time.perf_counter() - t0) * 1000
    print(f"✅ Base montée en RAM en {t_mount:.0f} ms  (source: {DB.name}, lecture seule)\n")

    query = sys.argv[1] if len(sys.argv) > 1 else None
    if not query:
        _summary(con)
        print("\nAstuce : python duckdb_mem.py \"SELECT ... FROM jedox.<table>\"")
        return

    t1 = time.perf_counter()
    result = con.execute(query)
    cols = [d[0] for d in result.description] if result.description else []
    data = result.fetchall()
    dt = (time.perf_counter() - t1) * 1000

    if cols:
        print(" | ".join(cols))
        print("-" * 60)
    for row in data[:100]:
        print(" | ".join("" if v is None else str(v) for v in row))
    if len(data) > 100:
        print(f"... ({len(data):,} lignes au total, 100 affichées)")
    print(f"\n⏱  Requête en RAM : {dt:.1f} ms — {len(data):,} ligne(s)")


if __name__ == "__main__":
    main()
