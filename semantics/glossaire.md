# Glossaire métier — FPM / cube Analyse (LOBELLIA)

## Concepts Jedox / techniques

| Terme | Définition |
|---|---|
| **Cube** | Table de faits Jedox multidimensionnelle. Ici `jedox.analyse`. |
| **Dimension (`dim_*`)** | Axe d'analyse hiérarchique en format pcwat. `child` = valeur présente dans le cube. |
| **pcwat** | Format d'export Jedox : `parent`, `child`, `weight`, attributs + `type` dérivé (`C`/`N`). |
| **type C / N** | `C` = nœud consolidé (a des enfants), `N` = feuille (stockée dans le cube). |
| **`~`** | Élément technique Jedox (placeholder) — à exclure systématiquement des analyses. |
| **`useRules=true`** | L'export Jedox matérialise les cellules calculées par les règles dans le Parquet. |

## Concepts FPM / métier

| Terme | Définition |
|---|---|
| **FPM** | Financial Performance Management. Processus de forecast mensuel glissant de la production. |
| **Version FPM** | Photo de prévision arrêtée à un mois donné. Format `FPM_YYYY_MM`. Chaque version couvre l'ensemble de l'année. |
| **FPM courante** | La version FPM active, identifiée par l'attribut `currentmonth` de `dim_version_fpm`. |
| **FPM précédente** | Attribut `previousfpm` de `dim_version_fpm`. Utilisé par les règles Jedox pour reprendre les données historiques du forfait. |
| **Régie** | Mode de facturation au temps passé (jours × TJM). Attribut `forfait_regie = 'Régie'`. |
| **Forfait** | Prix fixe pour un périmètre défini. Production reconnue à l'avancement. Attribut `forfait_regie = 'Forfait'`. |
| **Imputation** | Axe projet / affaire. `is_projet = '1'` pour les vrais projets ; `'0'` pour les imputations internes (congés, formation…). |
| **Congés** | Imputation spéciale `child = 'Congés'` dans `dim_imputation`. Porte les jours d'absence. |

## Mesures — jours

| Terme | Définition |
|---|---|
| **Jours produits (J/H)** | Jours de production reconnus (régie = jours facturés ; forfait = jours de production calculés par règles). |
| **Jours_imputés** | Jours saisis par les collaborateurs dans les feuilles de temps (timesheet). Peut différer des jours produits en forfait. |
| **Jours_consommés** | Jours effectivement consommés / valorisés (sous-ensemble des jours imputés, après filtres métier). |
| **Jours Vendus** | Jours vendus contractuellement (hors absences et internes). |
| **Jours Achetés** | Jours achetés à des sous-traitants. |
| **Jours absences** | Jours d'absence (congés, RTT, maladie…) portés par l'imputation `'Congés'`. |
| **Jours produits (redressé par ressource)** | Normalisation : Régie = J/H produits ; Forfait = jours imputés. Sert de base au taux d'utilisation et au TJM théorique. |

## Mesures — production & marge

| Terme | Définition |
|---|---|
| **Production (€ HT)** | Valorisation de la production (jours produits × TJM pour la régie ; montant reconnu pour le forfait). |
| **Prod_val_regie** | Production valorisée en régie uniquement. |
| **Prod_val_forfait** | Production valorisée en forfait uniquement (ventilée entre imputations). |
| **Marge HT** | Marge brute totale = Production − coûts directs (régie + forfait). |
| **Marge HT Régie** | Marge brute régie. |
| **Marge HT Forfait** | Marge brute forfait. |
| **Valorisation** | Valorisation interne des jours consommés (coût × TJM interne). |
| **Valorisation_jours_conso** | Valorisation des jours consommés (base de la production forfait en mois courant). |

## Mesures — TJM

| Terme | Définition |
|---|---|
| **TJM** | Taux Journalier Moyen (€/jour). Priorité : TJM Mensuel si disponible, sinon TJM Annuel de décembre. |
| **TJM Mensuel** | TJM saisi ou importé pour un mois donné. |
| **TJM Annuel** | TJM annuel de référence (valeur de décembre). |
| **TJM Acheté** | TJM de coût d'achat des sous-traitants (même logique mensuel/annuel). |
| **TJM théorique** | TJM implicite = Production théorique ÷ Jours redressés. Peut être NULL si jours = 0. |

## Mesures — cumuls & prévisions

| Terme | Définition |
|---|---|
| **YTD** (Year To Date) | Cumul depuis janvier de l'année courante (attribut FPM). Mesures déjà calculées dans le cube (`… (YTD)`). **Ne pas re-sommer.** |
| **RAF** (Reste À Faire) | Production ou jours restant à réaliser / à facturer (`Raf_prod_*`, `RAF_jours_*`). |
| **RAF année** | Accumulation du reste à facturer sur l'année courante (exclu de décembre). = `Production (Raf année)` / `Jours produits (Raf année)`. |
| **Production (prev année)** | Prévision annuelle totale = YTD + RAF année. Indique la projection de fin d'année à date de la FPM. |
| **Cumul_prod_val_regie** | = `Prod_val_regie` lu au grain YTD. Alias du cumul régie. |
| **Cumul_prod_jh_regie** | = `Jours_produits_regie` lu au grain YTD. Alias du cumul jours régie. |

## Mesures — taux & capacité

| Terme | Définition |
|---|---|
| **Taux dutilisation** | (Jours produits redressés + Jours absences congés) ÷ JoursOuvrés. Mesure la capacité utilisée. |
| **Taux présence** | Indicateur de présence effective de la ressource sur la période (1 = présent). |
| **Potentiel de prod** | Capacité de production non utilisée = jours disponibles × TJM poste × taux présence. Dépend de l'attribut `poste` (peut être NULL). |
| **Jours Produits & Absences** | = Jours absences congés + Jours produits redressés. Numérateur du taux d'utilisation. |

## Nœuds techniques à connaître

| Nœud | Dimension | Rôle | À faire |
|---|---|---|---|
| `Total Ressources` | `dim_ressource` | Racine de la dim, nœud de consolidation | Exclure des listes collaborateurs |
| `Surproduction` | `dim_ressource` | Écart de production forfait non affectable nominativement | Exclure des totaux collaborateurs |
| `RessourcesFutures` | `dim_ressource` | Ressources non encore nommées (ToBeDefined) | Exclure si analyse nominative |
| `Congés` | `dim_imputation` | Imputation des absences | Filtrer pour isoler les absences |
| `Total Groupe LOBELLIA` | `dim_organisation` | Racine organisation | Exclure si analyse par BU |
| `All Months` | `dim_periode` | Total toutes périodes | Exclure si analyse temporelle |

## Processus de l'application (source `.jds`)
Le modèle Jedox complet (saisie budget, budget RH, workflow, mapping FPM, suivi facturation,
sous-traitance, production…) dépasse le périmètre de ce POC, centré sur le **cube Analyse**.
Référence : `LOBELLIA.jds` (script de création de la base, ~12 Mo).
