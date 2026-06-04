-- cube Analyse brut (base LOBELLIA — FPM)
-- grain YYYY-MM (mensuel) : 2020-01 → 2030-12, 28 mesures de base
-- Pour les mesures dérivées (tjm, taux_utilisation, YTD…) → utiliser jedox.analyse_calc
select
    "Période"             as periode,
    "Version FPM"         as version_fpm,
    "Imputation"          as imputation,
    "Organisation"        as organisation,
    "Ressource"           as ressource,
    "Indicateurs Analyse" as indicateurs_analyse,
    "#Value"              as value_raw,
    try_cast("#Value" as double) as value_num
from read_parquet({{ src('cube_analyse.parquet') }})
where "Période" != '~'  -- exclure l'élément technique Jedox
