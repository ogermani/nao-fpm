-- généré depuis cube_analyse.parquet (cube Analyse, base LOBELLIA — FPM)
-- grain : Période × Version FPM × Imputation × Organisation × Ressource × Indicateurs Analyse
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
