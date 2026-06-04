# Règles de gestion — cube Analyse (LOBELLIA)

> Le cube Analyse est piloté par **26 règles Jedox**. Le Parquet exporté contient les **38 mesures
> de base** mais **pas les mesures dérivées** — les règles n'ont pas été appliquées à l'export.
>
> Les mesures dérivées sont recalculées dans **`jedox.analyse_calc`** (modèle dbt, format wide).
> Ce fichier décrit la logique métier en français clair. Les formules Jedox brutes sont dans
> `LOBELLIA.jds` (lignes 156316–156377).
>
> **Résumé : quelle table utiliser ?**
> - Mesures de base (`Production (€ HT)`, `Jours_imputés`, `TJM Annuel`…) → `jedox.analyse`
> - Mesures dérivées (`tjm`, `prod_val_forfait`, `taux_utilisation`…) → `jedox.analyse_calc`

---

## 1. Production Régie — Cumuls YTD

### Mesures concernées
`Cumul_prod_val_regie`, `Cumul_prod_jh_regie`

### Logique
Ces deux mesures sont des **alias du YTD** : elles lisent directement la cellule YTD correspondante
du cube plutôt que de re-sommer les mois.

```
Cumul_prod_val_regie  [pour un mois YYYY-MM]  =  Prod_val_regie  [période YYYY-MM_YTD]
Cumul_prod_jh_regie   [pour un mois YYYY-MM]  =  Jours_produits_regie  [période YYYY-MM_YTD]
```

### ⚠️ Contraintes
- Pour lire le cumul régie à fin juin 2025 : `WHERE indicateurs_analyse = 'Cumul_prod_val_regie'
  AND periode = '2025-06_YTD'` — **ou** `WHERE indicateurs_analyse = 'Prod_val_regie' AND periode =
  '2025-06_YTD'` (équivalent).
- Ne jamais sommer `Prod_val_regie` sur plusieurs périodes YYYY pour obtenir un cumul : c'est annuel,
  pas mensuel.

---

## 2. Production Forfait — Calcul mensuel & ventilation

### Mesures concernées
`Calcul_prod_val_forfait`, `Cumul_prod_val_forfait`, `Calcul_jours_produits_forfait`,
`Cumul_prod_jh_forfait`, `Jours_produits_forfait`, `Prod_val_forfait`

### Logique — Trois cas selon la position du mois vs la FPM courante

Pour un mois donné et une version FPM :

| Cas | Condition | Source |
|---|---|---|
| **Passé** | Mois < mois courant de la FPM | Données reprises de la **FPM précédente** (`PreviousFpm`) |
| **Courant** | Mois = mois courant de la FPM | Cumul différentiel : `Cumul_M - Cumul_{M-1}` |
| **Futur** | Mois > mois courant de la FPM | Budget forfait restant ou valorisation des jours consommés |

> **"Mois courant de la FPM"** = attribut `currentmonth` de `dim_version_fpm` (ex: `2025-06`
> pour `FPM_2025_06`).

### Ventilation entre imputations d'un projet
Quand un projet forfait possède plusieurs imputations enfants, la production calculée du projet
parent est **divisée équitablement** entre les imputations actives (date de fin ≥ mois courant FPM) :
```
Prod_val_forfait [imputation enfant]  =  Calcul_prod_val_forfait [projet parent]
                                         ÷ (nombre d'imputations enfants actives)
```

### ⚠️ Contraintes
- Pour un mois antérieur à la FPM courante, la production forfait reflète la **FPM précédente**,
  pas la version en cours. Comparer deux versions FPM est donc pertinent pour voir les révisions.
- `Cumul_prod_val_forfait` et `Cumul_prod_jh_forfait` s'appliquent aux imputations **Forfait
  uniquement** (`forfait_regie = 'Forfait'`). Elles valent NULL pour la régie.

---

## 3. Cumuls YTD & Year-To-Go (RAFs)

### Mesures concernées
`Production € (YTD)`, `Jours produits (YTD)`,
`Production (Raf année)`, `Jours produits (Raf année)`,
`Jours consommés (YTD)`

### Logique YTD — accumulation récursive mensuelle

```
Production € (YTD) [mois YYYY-MM]  =  Production (€ HT) [mois YYYY-MM]
                                     + Production € (YTD) [mois YYYY-(MM-1)]
```

**Condition clé :** cette accumulation ne se produit que si l'année du mois (`YYYY`) correspond à
l'**année de la FPM courante** (extraite des 4 derniers caractères du code version FPM). Pour les
autres années, la règle retourne **0**.

`Jours produits (YTD)` : même mécanique, pour les jours.

`Jours consommés (YTD)` : récupère directement `Jours_consommés` au format `YYYY-MM_YTD`.

### Logique RAF année — reste à facturer annuel

```
Production (Raf année) [mois YYYY-MM]  =  Production (€ HT) [mois YYYY-MM]
                                          + Production (Raf année) [mois YYYY-(MM-1)]
```

**Exception :** la règle n'accumule **pas** en décembre (mois de clôture — ce serait le total
annuel). Le RAF année vaut NULL en décembre.

### ⚠️ Contraintes
- **YTD = 0 hors année FPM courante** : si vous filtrez `version_fpm = 'FPM_2025_06'`, les mesures
  `… (YTD)` sont correctes pour les périodes 2025 et nulles/0 pour 2024 ou 2026.
- **Ne jamais re-sommer des YTD** : `Production € (YTD)` à `2025-06_YTD` est déjà le cumul
  janvier→juin. Sommer les 6 mois de 2025-01_YTD à 2025-06_YTD est une erreur.
- Le grain des mesures YTD dans les faits est `YYYY-MM_YTD`, **pas** `YYYY-MM`. Ces deux grains
  coexistent dans la colonne `periode` du cube.

---

## 4. Prévision annuelle (production "prev année")

### Mesures concernées
`Production (prev année)`, `Jours produits (prev année)`

### Logique

```
Production (prev année)  =  Production (Raf année)  +  Production € (YTD)
```

Cela donne une **prévision annuelle complète** : ce qui a déjà été produit (YTD) + ce qui reste à
produire d'ici la fin de l'année (RAF année).

Cette mesure est calculée pour le **mois courant de la version FPM** (attribut `currentmonth` de
`dim_version_fpm`). Elle s'applique uniquement aux versions Production (pas Simulation).

### Cas d'usage typique
> "Quelle est la prévision de production annuelle pour 2025 selon la FPM de juin 2025 ?"
> → `WHERE indicateurs_analyse = 'Production (prev année)' AND version_fpm = 'FPM_2025_06'`
> → lire la valeur à la période `2025` (annuelle) ou `2025-06_YTD` selon ce que le cube expose.

---

## 5. TJM (Taux Journalier Moyen)

### Mesures concernées
`TJM`, `TJM Annuel`, `TJM Mensuel`, `TJM Acheté`, `TJM Annuel Acheté`, `TJM Mensuel Acheté`,
`TJM theorique`

### Logique TJM principal

```
TJM  =  TJM Mensuel     si TJM Mensuel existe pour (version FPM, mois)
     =  TJM Annuel      sinon   [valeur de décembre de l'année, = TJM annuel figé]
```

- `TJM Mensuel` : taux mensuel saisi / importé (peut varier d'un mois à l'autre).
- `TJM Annuel` : taux annuel de référence (valeur de décembre).
- `TJM Acheté` / `TJM Annuel Acheté` / `TJM Mensuel Acheté` : même mécanique pour les **sous-traitants**.

### Logique TJM théorique

```
TJM theorique  =  Production theorique  ÷  Jours produits (redressé par ressource)  [arrondi 2 déc.]
```

C'est le TJM **implicite** calculé a posteriori depuis la production théorique.

### ⚠️ Contraintes
- `TJM` n'est défini qu'au niveau de la ressource (feuille). Ne pas sommer des TJM entre ressources
  (ce sont des taux, pas des montants).
- Pour le TJM moyen d'une équipe : `SUM(Production (€ HT)) / SUM(Jours produits (J/H))`.

---

## 6. Jours redressés par ressource & Surproduction

### Mesures concernées
`Jours produits (redressé par ressource)`, `Production theorique`, `TJM theorique`

### Logique — Redressement selon type d'imputation

La mesure `Jours produits (redressé par ressource)` normalise les jours selon le mode de facturation :

| Type de l'imputation | Ressource | Valeur |
|---|---|---|
| **Régie** | Toutes (sauf Surproduction) | `Jours produits (J/H)` — jours facturés réels |
| **Forfait** | Toutes (sauf Surproduction) | `Jours_imputés` — jours saisis dans les temps |
| **Forfait** | `Surproduction` | `Total Ressources (J/H)` − `Total Ressources (Jours_imputés)` |

### Logique — Surproduction

`Surproduction` est un **nœud technique** de `dim_ressource` qui absorbe l'écart de production
forfait non affectable à une ressource nominative. Pour le forfait, la somme des jours imputés
individuellement peut différer du total reconnu → l'écart va dans `Surproduction`.

### Logique — Production théorique

```
Production theorique [régie]                  =  Production (€ HT)
Production theorique [forfait, ≠ Surproduction]  =  Jours redressés × TJM
Production theorique [forfait, Surproduction]    =  Production (€ HT) [Total Ressources]
                                                    − Σ Production theorique [autres ressources]
```

### ⚠️ Contraintes
- **Exclure `Surproduction`** des listings de ressources et des totaux collaborateurs (nœud technique).
- Pour le total réel d'une équipe, filtrer `ressource != 'Surproduction'` ou joindre
  `dim_ressource WHERE type = 'N' AND child NOT IN ('Surproduction', 'Total Ressources', ...)`.
- `TJM theorique` peut être NULL ou infini si `Jours produits (redressé par ressource)` = 0.

---

## 7. Taux d'utilisation & Taux de présence

### Mesures concernées
`Taux dutilisation`, `Taux présence`, `Potentiel de prod`, `Jours Produits & Absences`

### Logique

```
Jours Produits & Absences  =  Jours absences [imputation = 'Congés']
                             + Jours produits (redressé par ressource) [imputation = '1']

Taux dutilisation  =  Jours Produits & Absences  ÷  JoursOuvrés [attribut de dim_periode]
```

```
Taux présence  =  1   si la ressource est en poste sur la période
                      (pas de date de fin, ou dates cohérentes)
              =  [valeur existante]   sinon   (STET — ne modifie pas)
```

```
Potentiel de prod  =  max(0,  JoursOuvrés − Jours utilisés)
                     × TJM selon le poste de la ressource
                     × Taux présence
```

### ⚠️ Contraintes
- `Taux dutilisation` et `Taux présence` sont des **ratios** (%) → ne jamais les sommer entre
  ressources. Pour un taux moyen d'équipe, faire la moyenne pondérée (ou recalculer depuis les jours).
- `Potentiel de prod` dépend de l'attribut `poste` de `dim_ressource` et du cube `Taux_TJ` (non
  chargé dans ce POC). Il peut être **NULL ou 0** si la ressource n'a pas de poste renseigné.
- `JoursOuvrés` est un attribut de `dim_periode` (`jours_ouvres`) — il s'applique au mois.
  Pour une maille annuelle, il faut sommer les jours ouvrés des mois de l'année.
- `Jours absences` avec l'imputation `'Congés'` : c'est une imputation spéciale (code `Congés`),
  pas un projet. Filtrer `imputation = 'Congés'` pour isoler les absences.

---

## 8. Mesures issues du cube intermédiaire Analyse_Calcul

Le cube `Analyse_Calcul` est un cube technique Jedox. Ses calculs sont **présents directement
dans `jedox.analyse`** (ils font partie des 38 mesures de base exportées).

| Mesure dans `jedox.analyse` | Description |
|---|---|
| `RAF_jours_produits_regie` | Jours régie restant à facturer |
| `Raf_prod_val_regie` | Valeur € régie restant à facturer |
| `Raf_prod_jh_forfait` | Jours forfait restant à produire |
| `Raf_prod_val_forfait` | Valeur € forfait restant à produire |
| `Marge HT` | Marge brute totale (régie + forfait) |
| `Marge HT Régie` | Marge brute régie |
| `Marge HT Forfait` | Marge brute forfait |
| `Jours_consommés` | Jours saisis dans les feuilles de temps (≠ produits) |
| `Jours Vendus` | Jours vendus contractuellement |

Ces mesures se lisent dans `jedox.analyse` en filtrant sur `indicateurs_analyse`, ou dans
`jedox.analyse_calc` comme colonnes directes (`raf_prod_val_regie`, `marge_ht`, etc.).

---

## Synthèse — Quelle table et quelle mesure pour quelle question ?

| Question | Table | Colonne / filtre | Période |
|---|---|---|---|
| Production facturée sur l'année | `jedox.analyse_calc` | `production_eur` | `YYYY` |
| Production régie seule | `jedox.analyse_calc` | `prod_val_regie` | `YYYY` |
| Production forfait seule | `jedox.analyse_calc` | `prod_val_forfait` | `YYYY` |
| Production cumulée à fin juin | `jedox.analyse` | `indicateurs_analyse='Production (€ HT)'` | `YYYY-06_YTD` |
| TJM d'un collaborateur | `jedox.analyse_calc` | `tjm` | `YYYY` |
| TJM moyen d'une équipe | `jedox.analyse_calc` | `SUM(production_eur)/SUM(jours_produits_jh)` | `YYYY` |
| TJM théorique (prod/jours redressés) | `jedox.analyse_calc` | `tjm_theorique` | `YYYY` |
| Jours imputés vs produits | `jedox.analyse_calc` | `jours_imputes`, `jours_produits_jh` | `YYYY` |
| Jours redressés (régie/forfait) | `jedox.analyse_calc` | `jours_produits_redresses` | `YYYY` |
| Taux d'utilisation d'un collaborateur | `jedox.analyse_calc` | `taux_utilisation` | `YYYY` |
| RAF sur un projet forfait | `jedox.analyse_calc` | `raf_prod_val_forfait` | `YYYY` |
| Marge brute par projet | `jedox.analyse_calc` | `marge_ht`, `marge_ht_regie`, `marge_ht_forfait` | `YYYY` |
| Comparaison deux FPM successives | `jedox.analyse_calc` | même colonne, deux `version_fpm` | `YYYY` |
| Liste des projets forfait actifs | `jedox.dim_imputation` | `WHERE forfait_regie='Forfait' AND is_actif='1'` | — |
