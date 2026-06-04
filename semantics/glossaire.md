# Glossaire métier — FPM / cube Analyse (LOBELLIA)

> ⚠️ À compléter / valider avec le métier.

- **FPM** : Financial Performance Management. Ici, processus de **forecast mensuel glissant** de la
  production. Une *version FPM* = une photo de prévision arrêtée à un mois donné.
- **Régie** : facturation au temps passé (jours × TJM). Voir attribut `ForfaitRegie = 'Régie'`.
- **Forfait** : prix fixe pour un périmètre. Production reconnue à l'avancement ; règles spécifiques
  de calcul (`Prod_val_forfait`, `Cumul_prod_*_forfait`, RAF). `ForfaitRegie = 'Forfait'`.
- **TJM** : Taux Journalier Moyen (€/jour). Mesures `TJM`, `TJM Annuel/Mensuel`, `TJM théorique`,
  `TJM Acheté` (coût d'achat sous-traitance).
- **Jours produits (J/H)** : jours de production reconnus (≠ jours imputés / saisis dans les temps).
- **Production (€ HT)** : valorisation de la production (jours produits × TJM, ou montant forfait).
- **YTD** (Year To Date) : cumul depuis janvier de l'année. Mesures `… (YTD)` déjà calculées.
- **RAF** (Reste À Faire) : production restante à réaliser sur un projet (`Raf_prod_*`).
- **Surproduction** : nœud technique de `dim_ressource` qui porte l'écart de production non
  affectable à une ressource nominative (cf. règles `Production theorique`).
- **Taux d'utilisation / présence** : indicateurs RH de staffing (jours produits + absences /
  jours ouvrés).
- **Imputation** : axe projet/affaire ; `isProjet` distingue les vrais projets des imputations
  internes (congés, absences…).

## Processus de l'application (source `.jds`)
Le modèle Jedox complet (saisie budget, budget RH, workflow, mapping FPM, suivi facturation,
sous-traitance, production…) dépasse le périmètre de ce POC, centré sur le **cube Analyse**.
Référence : `LOBELLIA.jds` (script de création de la base).
