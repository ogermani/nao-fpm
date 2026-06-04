-- dim_periode — dimension temporelle du cube Analyse (base LOBELLIA)
-- pcwat : parent / child / weight + attributs aliasés en snake_case + type dérivé (C/N)
-- Grain du cube : ANNUEL (YYYY) + YTD (YYYY-MM_YTD). Pas de grain mensuel brut.
with raw as (
    select
        ":parent"           as parent,
        ":child"            as child,
        ":weight"           as weight,
        "Name"              as name,
        "Description"       as description,
        "TimeAggregation"   as timeaggregation,
        "NextYear"          as nextyear,
        "PreviousYear"      as previousyear,
        "QuarterValue"      as quartervalue,
        "NextMonth"         as nextmonth,
        "PreviousMonth"     as previousmonth,
        "MonthValue"        as monthvalue,
        "YearValue"         as yearvalue,
        "YearToDate"        as yeartodate,
        "YearToGo"          as yeartogo,
        "MonthYearValue"    as monthyearvalue,
        "CurrentMonthValue1" as currentmonthvalue1,
        "CurrentYear"       as currentyear,
        "JoursOuvrés"       as jours_ouvres
    from read_parquet({{ src('dim_periode.parquet') }})
),
parents as (
    select distinct parent from raw where parent is not null and parent <> ''
)
select
    raw.*,
    case when raw.child in (select parent from parents) then 'C' else 'N' end as type
from raw
