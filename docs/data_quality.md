# Data Quality — Invalid Row Handling

> **PBI-09** | Owner: All | Layer: Silver

---

## Overview

During the Silver cleaning step, every row is evaluated against a set of quality rules. Rows that fail are **quarantined** into a dedicated rejected file rather than silently dropped. This ensures full traceability between raw Bronze input and clean Silver output.

---

## Quarantine Pattern

```
Bronze (raw)
    │
    ▼
Silver STG — quality checks applied
    │
    ├── valid rows   → data/silver/valid_*.csv          (consumed by Gold)
    └── invalid rows → data/silver/rejected/rejected_*.csv   (quarantined)
```

Each invalid row keeps all its original columns plus one additional column: `review_reason`.

---

## review_reason — Priority Rules

Rules are evaluated in priority order. The **first** matching rule wins; subsequent rules are skipped for that row.

### silver_population_gdp

| Priority | review_reason | Condition |
|----------|--------------|-----------|
| 1 | `MISSING_COUNTRY_NAME` | `country_name` is null |
| 2 | `MISSING_COUNTRY_CODE` | `country_code` is null |
| 3 | `MISSING_POPULATION` | `population` is null |
| 4 | `MISSING_GDP` | `gdp_per_capita_usd` is null |
| 5 | `INVALID_POPULATION` | `population` < 0 |
| 6 | `INVALID_GDP` | `gdp_per_capita_usd` < 0 |

### silver_wc_matches _(to be completed)_

| Priority | review_reason | Condition |
|----------|--------------|-----------|
| 1 | `MISSING_YEAR` | `year` is null |
| 2 | `OUT_OF_RANGE_YEAR` | `year` not in 1998–2018 |
| 3 | `MISSING_TEAM_NAME` | `home_team` or `away_team` is null |
| 4 | `MISSING_GOALS` | `home_goals` or `away_goals` is null |
| 5 | `UNMAPPED_COUNTRY` | team name not found in `country_mapping.json` |

---

## Rejected Output Files

| File | Content |
|------|---------|
| `data/silver/rejected/rejected_socioeconomics.csv` | Invalid population / GDP rows |
| `data/silver/rejected/rejected_wc_matches.csv` | Invalid WC match rows _(to be added)_ |

All rejected files include the full original columns + `review_reason`.

---

## Known Exclusions (Documented)

Some rows are excluded by design — not quality failures.

| Exclusion | Where applied | Reason |
|-----------|--------------|--------|
| World Bank aggregate rows (`WLD`, `EUU`, `LCN`, etc.) | `silver_population_gdp` Cell 11 | Not countries — regional/income aggregates |
| Years outside 1998–2018 | `silver_population_gdp` Cell 12 | Project scope: World Cup editions 1998–2018 only |
| "United Kingdom" row | `silver_population_gdp` Cell 14 | Replaced by England / Wales / Scotland / Northern Ireland (see below) |
| North Korea | Silver join | `MISSING_GDP` in `silver_socioeconomics` — World Bank has no GDP data for North Korea. Participated in 1 WC edition only (2010); insufficient data for meaningful socioeconomic analysis. Excluded from global analysis. |

---

## Special Case — UK Nations Split

The World Bank dataset contains a single **"United Kingdom"** row. The WC dataset treats England, Wales, Scotland, and Northern Ireland as separate teams. To enable the join, the UK row is split into 4 nation rows using ONS census population shares (stable over 1998–2018):

| Nation | Population share | GDP per capita |
|--------|-----------------|----------------|
| England | 84.0 % | = UK value |
| Scotland | 8.4 % | = UK value |
| Wales | 4.7 % | = UK value |
| Northern Ireland | 2.9 % | = UK value |

**GDP per capita is kept identical across all 4 nations** (approximation — nation-level GDP per capita data is not available in the World Bank dataset).

The original "United Kingdom" row is removed from the output. It does not appear in rejected — it is a documented transformation, not a quality exclusion.

---

## Validation Summary

Each Silver notebook writes a `validation_summary.txt` alongside the outputs:

```
data/silver/validation_summary.txt
```

It contains:
- Run timestamp
- Row counts at each stage (bronze loaded → after filter → valid → rejected)
- Rejection breakdown by `review_reason`

This file is the audit trail for each pipeline run.

---

## Silver/Bronze Cross-Check Notebook

`notebooks/silver_bronze_check.ipynb` runs **10 quality topics** across all Bronze and Silver outputs after each pipeline run.

### Datasets checked

| Key | Path |
|-----|------|
| `bronze_matches` | `data/bronze/bronze_wc_matches.csv` |
| `bronze_pop` | `data/bronze/bronze_pop.csv` |
| `bronze_gdp` | `data/bronze/bronze_gdp.csv` |
| `silver_worldcup` | `data/silver/silver_wc_output.csv` |
| `silver_socio` | `data/silver/valid_socioeconomics.csv` |
| `rejected_socio` | `data/silver/rejected/rejected_socioeconomics.csv` |

### Topics covered

**1. File availability** — confirms each expected file exists before loading.

**2. Row and column counts** — shape of each dataset. Computes retention % for each pipeline:
- `worldcup`: Bronze matches (scoped to 1998–2018) → Silver rows
- `socioeconomics`: valid + rejected total → valid rows

**3. Column audit** — lists all columns per dataset to catch unexpected additions or renames.

**4. Year coverage** — min year, max year, distinct year count per dataset. Expected: 1998–2018 (21 years) for all Silver outputs.

**5. Null values** — counts columns with nulls and total null cells. Surfaces top 5 null columns per dataset.

**6. Duplicate checks** — full-row duplicates + business key duplicates.

| Dataset | Business key |
|---------|-------------|
| `bronze_matches` | `year`, `stage`, `home_team`, `away_team` |
| `silver_worldcup` | `year`, `stage`, `home_team`, `away_team` |
| `silver_socio` | `country_code`, `year` |
| `rejected_socio` | `country_code`, `year` |

**7. Business rule checks**

| Dataset | Check |
|---------|-------|
| `silver_worldcup` | `home_score >= 0`, `away_score >= 0`, `date_clean` parsed |
| `silver_socio` | `population > 0`, `gdp_per_capita_usd > 0`, `country_code` length = 3, `year` between 1998–2018 |

**8. Rejected row summary** — breakdown of `review_reason` counts and share % from `rejected_socioeconomics.csv`.

**9. Country alignment** — compares host countries and team countries from `silver_worldcup` against `silver_socio`. Reports any team or host country present in WC data but missing from socioeconomics.

**10. Metadata quality** — checks presence of `source_name`, `load_timestamp`, `run_id` per dataset, and counts timestamp parse failures and null run IDs.

---

## WC Team Name Corrections

During cross-source validation, 5 team names present in the WC dataset were not found in `silver_socioeconomics`. Investigation revealed 4 typos and 1 data exclusion:

| WC dataset name | Issue | Resolution |
|----------------|-------|------------|
| `China PR` | Non-standard name | Corrected to `China` in `country_mapping.json` |
| `Columbia` | Spelling error | Corrected to `Colombia` in `country_mapping.json` |
| `Portagul` | Spelling error | Corrected to `Portugal` in `country_mapping.json` |
| `FR Yugoslavia` | Dissolved country | Mapped to `Serbia` (World Bank successor state) in `country_mapping.json` |
| `North Korea` | Missing GDP data | Documented exclusion — see Known Exclusions above |

Corrections are applied in `data/utils/country_mapping.json` and handled in `silver_wc_matches.ipynb`.

---

## Correction Logic

Rejected rows are **not corrected automatically**. The pipeline follows a quarantine-and-document approach:

1. Invalid rows are written to `rejected_*.csv` with their `review_reason`
2. A human reviews the rejected file after each run
3. If the source data can be fixed (e.g. a missing value found in another source), the correction is applied in the Bronze layer and the Silver notebook is re-run
4. If no correction is possible, the exclusion is documented here and in `validation_summary.txt`

> Corrections are never applied directly to Silver outputs. All fixes go through Bronze → Silver re-run to maintain layer integrity.
