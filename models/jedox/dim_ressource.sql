-- dim_ressource — collaborateurs (base LOBELLIA)
-- pcwat : parent / child / weight + attributs aliasés en snake_case + type dérivé (C/N)
-- 478 membres. Nœuds techniques : 'Total Ressources', 'Surproduction', 'RessourcesFutures'.
-- Filtrer type='N' pour ne garder que les collaborateurs réels (pas les nœuds de consolidation).
with raw as (
    select
        ":parent"            as parent,
        ":child"             as child,
        ":weight"            as weight,
        "Nom complet"        as nom_complet,
        "email"              as email,
        "StartDate"          as start_date,
        "EndDate"            as end_date,
        "Organisation"       as organisation,
        "Poste"              as poste,
        "IdCastor"           as id_castor,
        "Societe"            as societe,
        "Tri"                as tri,
        "SousTraitant"       as sous_traitant,
        "Nom"                as nom,
        "Ancien Nom Complet" as ancien_nom_complet
    from read_parquet({{ src('dim_ressource.parquet') }})
),
parents as (
    select distinct parent from raw where parent is not null and parent <> ''
)
select
    raw.*,
    case when raw.child in (select parent from parents) then 'C' else 'N' end as type
from raw
