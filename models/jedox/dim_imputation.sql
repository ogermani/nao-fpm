-- dim_imputation — projets / imputations (base LOBELLIA)
-- pcwat : parent / child / weight + attributs aliasés en snake_case + type dérivé (C/N)
-- Attributs clés pour les règles du cube : is_projet, forfait_regie, start_date_value, end_date_value.
with raw as (
    select
        ":parent"         as parent,
        ":child"          as child,
        ":weight"         as weight,
        "IdCastor"        as id_castor,
        "Name"            as name,
        "ClientId"        as client_id,
        "ClientName"      as client_name,
        "ClientAndName"   as client_and_name,
        "TypeImputation"  as type_imputation,
        "Orga"            as orga,
        "BU"              as bu,
        "CdP"             as cdp,
        "Tri"             as tri,
        "ForceDisplay"    as force_display,
        "isClient"        as is_client,
        "isProjet"        as is_projet,
        "ForfaitRegie"    as forfait_regie,
        "StartDate"       as start_date,
        "EndDate"         as end_date,
        "StartDateValue"  as start_date_value,
        "EndDateValue"    as end_date_value,
        "isActif"         as is_actif
    from read_parquet({{ src('dim_imputation.parquet') }})
),
parents as (
    select distinct parent from raw where parent is not null and parent <> ''
)
select
    raw.*,
    case when raw.child in (select parent from parents) then 'C' else 'N' end as type
from raw
