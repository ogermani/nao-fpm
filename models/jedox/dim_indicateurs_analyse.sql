-- généré depuis dim_indicateurs_analyse.parquet (dimension pcwat — base LOBELLIA)
-- pcwat : :parent / :child / :weight + attributs (passés tels quels) + type dérivé (C/N).
-- Dimension des mesures du cube Analyse (Production €, Jours produits, TJM, Taux d'utilisation...).
-- Mesures hétérogènes → en filtrer UNE à la fois (cf. RULES.md). Beaucoup sont calculées par règles.
with raw as (
    select * from read_parquet({{ src('dim_indicateurs_analyse.parquet') }})
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
