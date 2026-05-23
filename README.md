# PLS-SEM Data Pipeline

A reproducible analysis pipeline for **Likert-scale survey data** built around the
**Theory of Planned Behavior (TPB)** and estimated with **Partial Least Squares
Structural Equation Modeling (PLS-SEM)**.

It covers the full path from raw questionnaire export to publication-ready
results: cleaning, subgroup splitting, PLS-SEM estimation with bootstrapping,
quality/reliability reporting, an independent cross-validation in a second
statistical tool, and path-diagram figures.

> **No data is included in this repository.** The pipeline was originally built
> for confidential survey data that is not mine to publish. To run and inspect
> the code, `data_prep/generate_synthetic_data.py` produces **synthetic data with
> the same structure** (same constructs, scale, and demographic fields) so every
> script runs end-to-end without any real responses.

---

## What the code does

| Stage | Script | What it is for |
|-------|--------|----------------|
| 0. Test data | `data_prep/generate_synthetic_data.py` | Generates synthetic raw survey files (correlated TPB items + demographics) so the pipeline is runnable without real data. |
| 1. Cleaning | `data_prep/clean_survey_data.py` | Drops junk/unnamed columns and duplicate respondent rows, reports row counts, writes UTF-8 cleaned CSVs. |
| 2. Analysis | `analysis/run_plssem.R` | Estimates PLS-SEM (R `seminr`) across many demographic subgroups × two structural models, with 5000-resample bootstrapping; exports a multi-tab Excel report. |
| 3. Subgroup focus | `analysis/run_metro_grouping.R` | Re-runs the analysis for one specific urban-stratification grouping and exports tidy CSVs. |
| 4. Cross-validation | `crossval/cross_validate.sas` | Independently reproduces the descriptives, reliability, correlation, t-test and EFA layers in SAS — a second-tool check on the numbers. |
| 5. Figures | `figures/draw_path_diagrams.py` | Draws TPB structural path diagrams (β, t-values, significance, supported/not-supported styling). |

## The model

Four reflective TPB constructs, each measured by multiple Likert items:

- **AT** — Attitude
- **SN** — Subjective Norm
- **PBC** — Perceived Behavioral Control
- **BI** — Behavioral Intention
- **E** — an optional fifth construct used in an extended model

Baseline structural model (5 paths): `AT → PBC`, `SN → PBC`, `AT → BI`,
`SN → BI`, `PBC → BI`. The extended model adds `E → AT/SN/PBC/BI`.

## Expected data schema

The cleaning and analysis scripts expect one row per respondent with:

- **Indicator columns**: `AT1`–`AT12`, `SN1`–`SN12`, `PBC1`–`PBC12`,
  `BI1`–`BI12`, `E1`–`E13` — integer Likert responses (1–5).
- **Demographic columns**: `City`, `District`, `Gender`, `Education`, `Age`,
  `Income`, `Res_Year`, `Member_12`, `Member_65` — integer category codes,
  used for subgroup splitting.

`generate_synthetic_data.py` documents and produces exactly this schema.

## How to run

```bash
# 1. install Python deps
pip install -r requirements.txt

# 2. create synthetic raw data (written to ./synthetic_data/, git-ignored)
python data_prep/generate_synthetic_data.py

# 3. clean the raw files
python data_prep/clean_survey_data.py --folder synthetic_data

# 4. run the PLS-SEM analysis (requires R + the 'seminr' package)
Rscript analysis/run_plssem.R

# 5. draw the path diagrams
python figures/draw_path_diagrams.py
```

The SAS cross-validation (`crossval/cross_validate.sas`) is run inside SAS;
edit the two path macros at the top first.

## Tools

Python (pandas, numpy, matplotlib) · R (`seminr`, `dplyr`, `openxlsx`) · SAS
(`PROC CORR`, `PROC FACTOR`, `PROC TTEST`).

## Disclaimer

For educational and research-portfolio use only. This repository contains no
real survey data; output from the synthetic generator is fabricated and has no
scientific meaning. See [DISCLAIMER.md](DISCLAIMER.md) for the full terms,
including methodological risk, data-ethics responsibilities, limitation of
liability, and the "as-is" warranty.

## License

MIT — see [LICENSE](LICENSE).
