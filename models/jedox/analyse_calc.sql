-- analyse_calc — cube Analyse enrichi par les règles de gestion (base LOBELLIA)
--
-- Recalcule dans DuckDB les mesures dérivées du cube Analyse que l'export Jedox
-- ne matérialise pas (règles Jedox non appliquées dans le Parquet).
--
-- Format LARGE (wide) : 1 ligne par (periode YYYY × version_fpm × imputation × organisation × ressource).
-- Les mesures de base deviennent des colonnes ; les mesures dérivées sont ajoutées en fin.
-- Grain : YYYY uniquement (données annuelles).
--
-- Règles implémentées :
--   prod_val_forfait           = Production (€ HT) − Prod_val_regie
--   jours_produits_forfait     = Jours produits (J/H) − Jours_produits_regie
--   tjm                        = COALESCE(TJM Mensuel, TJM Annuel)
--   tjm_achete                 = COALESCE(TJM Mensuel Acheté, TJM Annuel Acheté)
--   jours_produits_redresses   = Régie→jours_regie, Forfait→jours_imputés, autre→jours_jh  [règle 22]
--   production_theorique       = Régie→prod réelle, Forfait (hors Surproduction)→redressé×TJM  [règle 24]
--   tjm_theorique              = production_theorique / ROUND(jours_redresses, 2)  [règle 26]
--   taux_utilisation           = Jours Produits & Absences / jours_ouvres_annuels  [règle 4]
--
-- Non implémenté (nécessite grain mensuel ou données manquantes) :
--   YTD/RAF année/prev année, Taux présence, Potentiel de prod, Surproduction (production_theorique≈NULL)

with

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. PIVOT — une ligne par (YYYY, version_fpm, imputation, organisation, ressource)
-- ─────────────────────────────────────────────────────────────────────────────
pivot_base as (
  select
    periode,
    version_fpm,
    imputation,
    organisation,
    ressource,
    -- Production
    max(case when indicateurs_analyse = 'Production (€ HT)'        then value_num end) as production_eur,
    max(case when indicateurs_analyse = 'Prod_val_regie'            then value_num end) as prod_val_regie,
    -- Jours
    max(case when indicateurs_analyse = 'Jours produits (J/H)'     then value_num end) as jours_produits_jh,
    max(case when indicateurs_analyse = 'Jours_produits_regie'      then value_num end) as jours_produits_regie,
    max(case when indicateurs_analyse = 'Jours_imputés'            then value_num end) as jours_imputes,
    max(case when indicateurs_analyse = 'Jours_consommés'          then value_num end) as jours_consommes,
    max(case when indicateurs_analyse = 'Jours produits (RAF)'     then value_num end) as jours_produits_raf,
    -- TJM
    max(case when indicateurs_analyse = 'TJM Annuel'               then value_num end) as tjm_annuel,
    max(case when indicateurs_analyse = 'TJM Mensuel'              then value_num end) as tjm_mensuel,
    max(case when indicateurs_analyse = 'TJM Annuel Acheté'        then value_num end) as tjm_annuel_achete,
    max(case when indicateurs_analyse = 'TJM Mensuel Acheté'       then value_num end) as tjm_mensuel_achete,
    -- RAF
    max(case when indicateurs_analyse = 'Production (RAF)'         then value_num end) as production_raf,
    max(case when indicateurs_analyse = 'RAF_jours_produits_regie' then value_num end) as raf_jours_produits_regie,
    max(case when indicateurs_analyse = 'Raf_prod_val_regie'       then value_num end) as raf_prod_val_regie,
    max(case when indicateurs_analyse = 'Raf_prod_jh_forfait'      then value_num end) as raf_prod_jh_forfait,
    max(case when indicateurs_analyse = 'Raf_prod_val_forfait'     then value_num end) as raf_prod_val_forfait,
    -- Marge
    max(case when indicateurs_analyse = 'Marge HT'                 then value_num end) as marge_ht,
    max(case when indicateurs_analyse = 'Marge HT Régie'           then value_num end) as marge_ht_regie,
    max(case when indicateurs_analyse = 'Marge HT Forfait'         then value_num end) as marge_ht_forfait,
    -- Valorisation
    max(case when indicateurs_analyse = 'Valorisation_jours_conso' then value_num end) as valorisation_jours_conso,
    max(case when indicateurs_analyse = 'Valorisation'             then value_num end) as valorisation,
    -- Autres
    max(case when indicateurs_analyse = 'Effectif mensuel'         then value_num end) as effectif_mensuel,
    max(case when indicateurs_analyse = 'Jours Vendus'             then value_num end) as jours_vendus,
    max(case when indicateurs_analyse = 'Jours Achetés'            then value_num end) as jours_achetes,
    max(case when indicateurs_analyse = 'Jours Achetés (Raf)'     then value_num end) as jours_achetes_raf,
    max(case when indicateurs_analyse = 'Montant Acheté (Raf)'    then value_num end) as montant_achete_raf
  from {{ ref('analyse') }}
  where length(periode) = 4  -- grain YYYY uniquement (exclut All Months, ~, YYYY-MM_YTD)
  group by 1, 2, 3, 4, 5
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Jours Produits & Absences au niveau consolidé (imputation='1' = total projets)
--    Utilisé pour le taux d'utilisation (règle 4) — déjà calculé par Jedox
-- ─────────────────────────────────────────────────────────────────────────────
jours_produits_absences as (
  select
    periode,
    version_fpm,
    organisation,
    ressource,
    value_num as jours_produits_et_absences
  from {{ ref('analyse') }}
  where indicateurs_analyse = 'Jours Produits & Absences'
    and imputation = '1'  -- nœud consolidé total projets + congés
    and length(periode) = 4
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Attributs dim_imputation (DISTINCT : multi-parent possible)
-- ─────────────────────────────────────────────────────────────────────────────
imp as (
  select distinct
    child,
    forfait_regie,
    is_projet,
    bu,
    cdp,
    client_id,
    client_name,
    name       as imputation_name
  from {{ ref('dim_imputation') }}
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Jours ouvrés annuels depuis dim_periode (nœud YYYY, jours_ouvres > 0)
-- ─────────────────────────────────────────────────────────────────────────────
jours_ouvres as (
  select child as periode, jours_ouvres
  from {{ ref('dim_periode') }}
  where length(child) = 4 and jours_ouvres > 0
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Attributs dim_version_fpm
-- ─────────────────────────────────────────────────────────────────────────────
fpm as (
  select distinct child, annee, mois, alias, currentmonth, previousfpm, nextfpm, type_version
  from {{ ref('dim_version_fpm') }}
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Pivot enrichi avec attributs dimensionnels et premières mesures dérivées
-- ─────────────────────────────────────────────────────────────────────────────
enriched as (
  select
    p.*,
    -- Attributs imputation
    i.forfait_regie,
    i.is_projet,
    i.bu,
    i.cdp,
    i.client_id,
    i.client_name,
    i.imputation_name,
    -- Attributs version FPM
    f.annee          as fpm_annee,
    f.mois           as fpm_mois,
    f.alias          as fpm_alias,
    f.currentmonth   as fpm_currentmonth,
    f.previousfpm,
    f.nextfpm,
    f.type_version   as fpm_type,
    -- Jours ouvrés annuels (pour taux d'utilisation)
    jo.jours_ouvres  as jours_ouvres_annuels,
    -- ── Mesures dérivées simples ──────────────────────────────────────────────
    -- Production forfait (règle : prod totale − prod régie)
    p.production_eur - coalesce(p.prod_val_regie, 0)            as prod_val_forfait,
    -- Jours produits forfait
    p.jours_produits_jh - coalesce(p.jours_produits_regie, 0)   as jours_produits_forfait,
    -- TJM composite (règle 15 : mensuel prioritaire, sinon annuel)
    coalesce(p.tjm_mensuel, p.tjm_annuel)                        as tjm,
    -- TJM Acheté composite (règle 16)
    coalesce(p.tjm_mensuel_achete, p.tjm_annuel_achete)          as tjm_achete,
    -- ── Jours produits redressés (règle 22) ───────────────────────────────────
    --   Régie   → jours réellement produits (facturation au temps)
    --   Forfait → jours imputés dans les feuilles de temps
    --   Autre   → jours produits J/H (par défaut)
    case
      when i.forfait_regie = 'Régie'   then p.jours_produits_regie
      when i.forfait_regie = 'Forfait' then p.jours_imputes
      else                                  p.jours_produits_jh
    end                                                           as jours_produits_redresses
  from pivot_base p
  left join imp i  on i.child = p.imputation
  left join jours_ouvres jo on jo.periode = p.periode
  left join fpm f  on f.child = p.version_fpm
)

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Mesures dérivées dépendant des étapes précédentes
-- ─────────────────────────────────────────────────────────────────────────────
select
  e.*,
  -- Jours Produits & Absences (déjà calculé par Jedox au niveau total)
  jpa.jours_produits_et_absences,

  -- ── Production théorique (règle 24) ──────────────────────────────────────
  --   Régie              → production réelle (€ HT)
  --   Forfait, ≠ Surprod → jours redressés × TJM
  --   Surproduction      → NULL (nécessite agrégation croisée, non calculable ici)
  case
    when e.forfait_regie != 'Forfait'     then e.production_eur
    when e.ressource = 'Surproduction'    then null
    when e.tjm is not null
     and e.jours_produits_redresses is not null then e.jours_produits_redresses * e.tjm
    else null
  end                                                              as production_theorique,

  -- ── TJM théorique (règle 26) ─────────────────────────────────────────────
  --   = production_theorique / ROUND(jours_redresses, 2)
  --   NULL si jours redressés = 0
  case
    when coalesce(round(case
           when e.forfait_regie = 'Régie'   then e.jours_produits_regie
           when e.forfait_regie = 'Forfait' then e.jours_imputes
           else e.jours_produits_jh
         end, 2), 0) = 0  then null
    when e.forfait_regie != 'Forfait'  then
      e.production_eur
      / round(e.jours_produits_redresses, 2)
    when e.ressource = 'Surproduction' then null
    when e.tjm is not null then e.tjm  -- production_theorique/redresses = tjm (par construction)
    else null
  end                                                              as tjm_theorique,

  -- ── Taux d'utilisation (règle 4) ─────────────────────────────────────────
  --   = Jours Produits & Absences [imputation='1'] / JoursOuvrés [année]
  --   "Jours Produits & Absences" est la somme (jours produits redressés + congés)
  --   déjà calculée par Jedox sur le nœud consolidé imputation='1'.
  case
    when coalesce(e.jours_ouvres_annuels, 0) = 0 then null
    else jpa.jours_produits_et_absences / e.jours_ouvres_annuels
  end                                                              as taux_utilisation

from enriched e
left join jours_produits_absences jpa
  on  jpa.periode      = e.periode
  and jpa.version_fpm  = e.version_fpm
  and jpa.organisation = e.organisation
  and jpa.ressource    = e.ressource
