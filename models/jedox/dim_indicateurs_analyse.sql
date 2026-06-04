-- dim_indicateurs_analyse — mesures du cube Analyse (base LOBELLIA)
-- pcwat : parent / child / weight + attribut alias + type dérivé (C/N)
-- 74 membres. Mesures hétérogènes (€, J/H, €/jour, %) → en filtrer UNE à la fois (cf. RULES.md).
-- Les mesures dérivées (TJM, YTD, Taux, RAF…) sont calculées par les ~130 règles Jedox et
-- matérialisées dans le Parquet (export useRules=true).
with raw as (
    select
        ":parent" as parent,
        ":child"  as child,
        ":weight" as weight,
        "Alias"   as alias
    from read_parquet({{ src('dim_indicateurs_analyse.parquet') }})
),
parents as (
    select distinct parent from raw where parent is not null and parent <> ''
)
select
    raw.*,
    case when raw.child in (select parent from parents) then 'C' else 'N' end as type
from raw
