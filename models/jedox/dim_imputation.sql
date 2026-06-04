-- généré depuis dim_imputation.parquet (dimension pcwat — base LOBELLIA)
-- pcwat : :parent / :child / :weight + attributs (passés tels quels) + type dérivé (C/N).
-- ⚠️ Attributs connus via les règles (.jds) : isProjet, ForfaitRegie, StartDateValue, EndDateValue —
--    à aliaser en snake_case après le 1er export.
with raw as (
    select * from read_parquet({{ src('dim_imputation.parquet') }})
),
parents as (
    select distinct ":parent" as parent from raw where ":parent" is not null and ":parent" <> ''
)
select
    raw.":parent" as parent,
    raw.":child"  as child,
    raw.":weight" as weight,
    raw.* exclude (":parent", ":child", ":weight"),
    case when raw.":child" in (select parent from parents) then 'C' else 'N' end as type
from raw
