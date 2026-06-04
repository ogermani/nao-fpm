-- dim_version_fpm — scénarios de prévision FPM (base LOBELLIA)
-- pcwat : parent / child / weight + attributs aliasés en snake_case + type dérivé (C/N)
-- 87 membres : 84 versions Production (FPM_YYYY_MM), 3 Simulation. Tous racines (parent vide).
with raw as (
    select
        ":parent"       as parent,
        ":child"        as child,
        ":weight"       as weight,
        "Alias"         as alias,
        "Alias_simple"  as alias_simple,
        "Mois"          as mois,
        "Année"         as annee,
        "PreviousMonth" as previousmonth,
        "NextMonth"     as nextmonth,
        "CurrentMonth"  as currentmonth,
        "CurrentMonthValue1" as currentmonthvalue1,
        "Afficher"      as afficher,
        "PreviousFpm"   as previousfpm,
        "NextFpm"       as nextfpm,
        "Type Version"  as type_version
    from read_parquet({{ src('dim_version_fpm.parquet') }})
),
parents as (
    select distinct parent from raw where parent is not null and parent <> ''
)
select
    raw.*,
    case when raw.child in (select parent from parents) then 'C' else 'N' end as type
from raw
