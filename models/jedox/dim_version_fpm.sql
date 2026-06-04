-- généré depuis dim_version_fpm.parquet (dimension pcwat — base LOBELLIA)
-- pcwat : :parent / :child / :weight + attributs (passés tels quels) + type dérivé (C/N).
-- ⚠️ Attributs FPM connus via les règles (.jds) : CurrentMonth, CurrentMonthValue1, PreviousFpm,
--    NextFpm, NextMonth, Année — à aliaser en snake_case après le 1er export.
with raw as (
    select * from read_parquet({{ src('dim_version_fpm.parquet') }})
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
