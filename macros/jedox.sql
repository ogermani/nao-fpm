{#- Construit la référence vers un extrait Jedox de poc-data/ (parquet/csv). -#}
{%- macro src(filename) -%}
    '{{ var("poc_data_dir", "poc-data") }}/{{ filename }}'
{%- endmacro -%}

{#-
  Force le schéma à être EXACTEMENT le `+schema` du modèle (ex: `jedox`),
  sans le préfixe `<target.schema>_` que dbt ajoute par défaut.
  Ainsi `jedox.finance`, `jedox.dim_comptes`… restent inchangés pour Nao et duckdb_mem.py.
-#}
{%- macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro -%}
