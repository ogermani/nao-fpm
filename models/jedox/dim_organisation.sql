-- dim_organisation — BU / départements (base LOBELLIA)
-- pcwat : parent / child / weight + attributs aliasés en snake_case + type dérivé (C/N)
-- 18 membres : Total Groupe LOBELLIA → LOBELLIA Conseil / 9EXT / ASTILLIA → BUs / équipes.
with raw as (
    select
        ":parent"  as parent,
        ":child"   as child,
        ":weight"  as weight,
        "Name"     as name,
        "Code"     as code,
        "ID_Name"  as id_name,
        "Country"  as country,
        "Currency" as currency,
        "Groupe"   as groupe
    from read_parquet({{ src('dim_organisation.parquet') }})
),
parents as (
    select distinct parent from raw where parent is not null and parent <> ''
)
select
    raw.*,
    case when raw.child in (select parent from parents) then 'C' else 'N' end as type
from raw
