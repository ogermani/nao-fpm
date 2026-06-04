# Taxonomie — cube Analyse (LOBELLIA / FPM)

> ⚠️ Squelette à compléter après le 1er export (`dbt build` + `nao sync`), en inspectant
> `databases/.../schema=jedox/table=*/preview.md`.

## Versions FPM (`dim_version_fpm`)
Forecast mensuel glissant : chaque version FPM est une photo de prévision à une date donnée.
Attributs connus (via règles `.jds`) : `CurrentMonth`, `CurrentMonthValue1`, `PreviousFpm`,
`NextFpm`, `NextMonth`, `Année`.

- [ ] Lister les versions réelles et leur convention de nommage.
- [ ] Identifier la version courante / la dernière FPM publiée.

## Mesures (`dim_indicateurs_analyse`)
Hétérogènes → **en filtrer une seule** (cf. RULES.md §1). Familles repérées dans le `.jds` :

| Famille | Exemples de mesures | Unité |
|---|---|---|
| Production | `Production (€ HT)`, `Prod_val_regie`, `Prod_val_forfait`, `Production theorique` | € |
| Jours | `Jours produits (J/H)`, `Jours_imputés`, `Jours_produits_forfait`, `Jours absences` | jours |
| Cumuls | `… (YTD)`, `Cumul_prod_val_*`, `Production € (YTD)` | € / jours |
| Tarif | `TJM`, `TJM Annuel`, `TJM Mensuel`, `TJM théorique`, `TJM Acheté` | €/jour |
| Taux | `Taux dutilisation`, `Taux présence`, `Potentiel de prod` | % |

- [ ] Lister l'arbre complet des mesures + repérer feuilles (`type='N'`) vs consolidés.

## Périodes (`dim_periode`)
Grain mensuel `YYYY-MM` → trimestre → année. Attributs : `YearValue`, `QuarterValue`, `MonthValue`,
`PreviousMonth`, `NextMonth`, `YearToDate`, `JoursOuvrés`, `CurrentMonthValue1`.

- [ ] Bornes temporelles réelles (1er / dernier mois chargé).

## Ressource (`dim_ressource`)
Collaborateurs (feuilles) + nœuds `Total Ressources` et `Surproduction` (technique, voir règles).

## Imputation (`dim_imputation`)
Projets / imputations. Attributs clés : `isProjet`, `ForfaitRegie` (Forfait / Régie),
`StartDateValue`, `EndDateValue`.

## Organisation (`dim_organisation`)
BU / départements / hiérarchie interne.
