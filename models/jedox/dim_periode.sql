-- généré depuis dim_periode.parquet (dimension pcwat — base LOBELLIA)
-- pcwat : :parent / :child / :weight + attributs (passés tels quels) + type dérivé (C/N).
-- ⚠️ Après le 1er export, aliaser les attributs utiles en snake_case (cf. dim_periode du starter-kit :
--    timeaggregation, yearvalue, quartervalue, monthvalue, previousmonth, yeartodate, currentmonthvalue1...).
with raw as (
    select * from read_parquet({{ src('dim_periode.parquet') }})
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
