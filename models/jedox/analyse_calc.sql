-- analyse_calc — cube Analyse enrichi par les règles de gestion (base LOBELLIA)
--
-- Recalcule dans DuckDB les mesures dérivées des 26 règles Jedox absentes du Parquet.
--
-- Format LARGE (wide) : 1 ligne par (YYYY-MM × version_fpm × imputation × organisation × ressource).
-- Grain : YYYY-MM (mensuel — données disponibles de 2020-01 à 2030-12).
--
-- Règles implémentées :
--   marge_ht                   = Marge HT Régie + Marge HT Forfait       [agrégat]
--   tjm                        = COALESCE(TJM Mensuel, TJM Annuel)        [règle 15]
--   tjm_achete                 = COALESCE(TJM Mensuel Acheté, TJM Annuel Acheté) [règle 16]
--   jours_produits_redresses   = Régie→jours_regie, Forfait→jours_imputés [règle 22]
--   production_theorique       = Régie→prod_val_regie, Forfait→redressé×TJM [règle 24]
--   tjm_theorique              = production_theorique / ROUND(jours_redresses, 2) [règle 26]
--   taux_utilisation           = Jours Produits & Absences / jours_ouvres [règle 4]
--   *_ytd                      = cumul YTD par année, via window function  [règles 9-10]
--
-- Non implémenté :
--   Production (€ HT) et Jours produits (J/H) : mesures totales régie+forfait calculées
--     par règles Jedox (prod forfait complexe), absentes du Parquet de base.
--   Taux présence    : logique de date complexe par ressource.
--   Potentiel de prod: nécessite le cube Taux_TJ (non chargé).
--   Surproduction dans production_theorique : agrégation croisée → NULL.

with

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. PIVOT — une ligne par (YYYY-MM × version_fpm × imputation × organisation × ressource)
--    Source : jedox.analyse filtré sur grain mensuel uniquement
-- ─────────────────────────────────────────────────────────────────────────────
pivot_base as (
  select
    periode,
    version_fpm,
    imputation,
    organisation,
    ressource,
    -- Production régie (seule disponible au grain mensuel — prod forfait calculée par règles)
    max(case when indicateurs_analyse = 'Prod_val_regie'            then value_num end) as prod_val_regie,
    -- Jours
    max(case when indicateurs_analyse = 'Jours_produits_regie'      then value_num end) as jours_produits_regie,
    max(case when indicateurs_analyse = 'Jours_imputés'            then value_num end) as jours_imputes,
    max(case when indicateurs_analyse = 'Jours_consommés'          then value_num end) as jours_consommes,
    max(case when indicateurs_analyse = 'Jours Produits & Absences' then value_num end) as jours_produits_et_absences,
    max(case when indicateurs_analyse = 'Jours absences'           then value_num end) as jours_absences,
    max(case when indicateurs_analyse = 'Jours Vendus'             then value_num end) as jours_vendus,
    max(case when indicateurs_analyse = 'Jours Achetés'            then value_num end) as jours_achetes,
    max(case when indicateurs_analyse = 'Jours Achetés (Raf)'     then value_num end) as jours_achetes_raf,
    max(case when indicateurs_analyse = 'Jours Achetés (YTD)'     then value_num end) as jours_achetes_ytd,
    -- TJM
    max(case when indicateurs_analyse = 'TJM Annuel'               then value_num end) as tjm_annuel,
    max(case when indicateurs_analyse = 'TJM Mensuel'              then value_num end) as tjm_mensuel,
    max(case when indicateurs_analyse = 'TJM Annuel Acheté'        then value_num end) as tjm_annuel_achete,
    max(case when indicateurs_analyse = 'TJM Mensuel Acheté'       then value_num end) as tjm_mensuel_achete,
    -- RAF
    max(case when indicateurs_analyse = 'RAF_jours_produits_regie' then value_num end) as raf_jours_produits_regie,
    max(case when indicateurs_analyse = 'Raf_prod_val_regie'       then value_num end) as raf_prod_val_regie,
    max(case when indicateurs_analyse = 'Raf_prod_jh_forfait'      then value_num end) as raf_prod_jh_forfait,
    max(case when indicateurs_analyse = 'Raf_prod_val_forfait'     then value_num end) as raf_prod_val_forfait,
    -- Marge (régie et forfait séparément — total calculé en §7)
    max(case when indicateurs_analyse = 'Marge HT Régie'           then value_num end) as marge_ht_regie,
    max(case when indicateurs_analyse = 'Marge HT Forfait'         then value_num end) as marge_ht_forfait,
    -- Valorisation
    max(case when indicateurs_analyse = 'Valorisation_jours_conso' then value_num end) as valorisation_jours_conso,
    max(case when indicateurs_analyse = 'Valorisation'             then value_num end) as valorisation,
    max(case when indicateurs_analyse = 'Valorisation Acheté'      then value_num end) as valorisation_achete,
    max(case when indicateurs_analyse = 'Valorisation Vendu'       then value_num end) as valorisation_vendu,
    -- Montants achetés
    max(case when indicateurs_analyse = 'Montant Acheté (Raf)'    then value_num end) as montant_achete_raf,
    max(case when indicateurs_analyse = 'Montant Acheté (YTD)'    then value_num end) as montant_achete_ytd,
    -- Effectif
    max(case when indicateurs_analyse = 'Effectif mensuel'         then value_num end) as effectif_mensuel
  from {{ ref('analyse') }}
  where length(periode) = 7  -- grain YYYY-MM uniquement
  group by 1, 2, 3, 4, 5
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Attributs dim_imputation (DISTINCT : multi-parent possible)
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
    name as imputation_name
  from {{ ref('dim_imputation') }}
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Jours ouvrés mensuels depuis dim_periode (DISTINCT : multi-parent)
-- ─────────────────────────────────────────────────────────────────────────────
jours_ouvres as (
  select distinct child as periode, jours_ouvres
  from {{ ref('dim_periode') }}
  where length(child) = 7 and jours_ouvres > 0  -- nœuds mensuels YYYY-MM
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Attributs dim_version_fpm
-- ─────────────────────────────────────────────────────────────────────────────
fpm as (
  select distinct child, annee, mois, alias, currentmonth, previousfpm, nextfpm, type_version
  from {{ ref('dim_version_fpm') }}
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Pivot enrichi avec attributs dimensionnels et mesures dérivées de base
-- ─────────────────────────────────────────────────────────────────────────────
enriched as (
  select
    p.*,
    -- Attributs imputation (pré-joints)
    i.forfait_regie,
    i.is_projet,
    i.bu,
    i.cdp,
    i.client_id,
    i.client_name,
    i.imputation_name,
    -- Attributs version FPM (pré-joints)
    f.annee          as fpm_annee,
    f.mois           as fpm_mois,
    f.alias          as fpm_alias,
    f.currentmonth   as fpm_currentmonth,
    f.previousfpm,
    f.nextfpm,
    f.type_version   as fpm_type,
    -- Année et mois extraits de la période (pour les window functions YTD)
    left(p.periode, 4)                              as annee,
    right(p.periode, 2)                             as mois,
    -- Jours ouvrés du mois (pour taux d'utilisation mensuel)
    jo.jours_ouvres,
    -- ── Mesures dérivées simples ──────────────────────────────────────────────
    -- Marge HT totale [agrégat : régie + forfait]
    coalesce(p.marge_ht_regie, 0) + coalesce(p.marge_ht_forfait, 0)  as marge_ht,
    -- TJM composite [règle 15 : mensuel prioritaire, sinon annuel]
    coalesce(p.tjm_mensuel, p.tjm_annuel)                              as tjm,
    -- TJM Acheté composite [règle 16]
    coalesce(p.tjm_mensuel_achete, p.tjm_annuel_achete)               as tjm_achete,
    -- ── Jours produits redressés [règle 22] ───────────────────────────────────
    --   Régie   → jours réellement produits
    --   Forfait → jours imputés dans les feuilles de temps
    --   Autre   → jours produits régie (meilleure approximation disponible)
    case
      when i.forfait_regie = 'Régie'   then p.jours_produits_regie
      when i.forfait_regie = 'Forfait' then p.jours_imputes
      else                                  p.jours_produits_regie
    end                                                                as jours_produits_redresses
  from pivot_base p
  left join imp i         on i.child = p.imputation
  left join jours_ouvres jo on jo.periode = p.periode
  left join fpm f         on f.child = p.version_fpm
),

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. YTD accumulés par année (window functions) [règles 9-10 et dérivées]
--    Partition : (version_fpm, imputation, organisation, ressource, année)
--    Ordre     : période mensuelle croissante
-- ─────────────────────────────────────────────────────────────────────────────
with_ytd as (
  select
    e.*,
    -- YTD production régie
    sum(e.prod_val_regie) over w                    as prod_val_regie_ytd,
    -- YTD jours régie
    sum(e.jours_produits_regie) over w              as jours_produits_regie_ytd,
    -- YTD jours imputés
    sum(e.jours_imputes) over w                     as jours_imputes_ytd,
    -- YTD jours consommés
    sum(e.jours_consommes) over w                   as jours_consommes_ytd,
    -- YTD jours redressés (base du taux utilisation cumulé)
    sum(e.jours_produits_redresses) over w          as jours_produits_redresses_ytd,
    -- YTD marge
    sum(e.marge_ht) over w                          as marge_ht_ytd,
    sum(e.marge_ht_regie) over w                    as marge_ht_regie_ytd
  from enriched e
  window w as (
    partition by e.version_fpm, e.imputation, e.organisation, e.ressource, e.annee
    order by e.periode
    rows between unbounded preceding and current row
  )
)

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Mesures dérivées finales (nécessitent les étapes précédentes)
-- ─────────────────────────────────────────────────────────────────────────────
select
  w.*,

  -- ── Production théorique mensuelle [règle 24] ────────────────────────────
  --   Régie              → prod_val_regie (production réelle facturée)
  --   Forfait, ≠ Surprod → jours redressés × TJM
  --   Surproduction      → NULL (nécessite agrégation croisée)
  case
    when w.forfait_regie != 'Forfait'      then w.prod_val_regie
    when w.ressource = 'Surproduction'     then null
    when w.tjm is not null
     and w.jours_produits_redresses is not null
     then w.jours_produits_redresses * w.tjm
    else null
  end                                                               as production_theorique,

  -- ── TJM théorique mensuel [règle 26] ────────────────────────────────────
  --   = production_theorique / ROUND(jours_redresses, 2)
  case
    when coalesce(round(w.jours_produits_redresses, 2), 0) = 0     then null
    when w.forfait_regie != 'Forfait'      then
      w.prod_val_regie / round(w.jours_produits_redresses, 2)
    when w.ressource = 'Surproduction'     then null
    when w.tjm is not null                 then w.tjm
    else null
  end                                                               as tjm_theorique,

  -- ── Taux d'utilisation mensuel [règle 4] ────────────────────────────────
  --   = Jours Produits & Absences / JoursOuvrés du mois
  --   Note : Jours Produits & Absences est déjà calculé par Jedox dans le cube
  case
    when coalesce(w.jours_ouvres, 0) = 0                           then null
    else w.jours_produits_et_absences / w.jours_ouvres
  end                                                               as taux_utilisation,

  -- ── Taux d'utilisation YTD [cumulé sur l'année] ─────────────────────────
  --   = Σ Jours redressés (YTD) / Σ JoursOuvrés (YTD)
  case
    when coalesce(
      sum(w.jours_ouvres) over (
        partition by w.version_fpm, w.imputation, w.organisation, w.ressource, w.annee
        order by w.periode
        rows between unbounded preceding and current row
      ), 0) = 0 then null
    else
      w.jours_produits_redresses_ytd
      / sum(w.jours_ouvres) over (
          partition by w.version_fpm, w.imputation, w.organisation, w.ressource, w.annee
          order by w.periode
          rows between unbounded preceding and current row
        )
  end                                                               as taux_utilisation_ytd

from with_ytd w
