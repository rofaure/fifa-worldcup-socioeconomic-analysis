# Medallion Architecture Plan
# FIFA World Cup Socioeconomic Analysis (1998–2018)

---

## Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DATA SOURCES                                │
│                                                                     │
│  [Kaggle CSV]          [World Bank CSV]       [World Bank CSV]      │
│  WC Match Results      Population by Country  GDP per Capita        │
│  (fifa_world_cup)      (API_POP)              (API_GDP)             │
└────────────┬───────────────────┬──────────────────────┬────────────┘
             │                   │                      │
             ▼                   ▼                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         BRONZE LAYER                                │
│                       data/bronze/                                  │
│                                                                     │
│  bronze_wc_matches.csv     bronze_population.csv  bronze_gdp.csv   │
│  + source_name             + source_name          + source_name     │
│    "fifa_world_cup"          "API_POP"              "API_GDP"       │
│  + load_timestamp          + load_timestamp       + load_timestamp  │
│  + run_id                  + run_id               + run_id          │
│                                                                     │
│  Raw data as-is. No transformations. Original structure preserved.  │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         SILVER LAYER (Python cleaning)              │
│                       data/silver/                                  │
│                                                                     │
│  STAGING TABLES (intermediate)                                      │
│                                                                     │
│  stg_wc_matches                  stg_population_gdp                │
│  - filter 1998–2018              - unpivot (year becomes rows)     │
│  - standardize column names      - filter 1998–2018                │
│  - fix dtypes                    - filter out non-country rows     │
│  - handle nulls                  - handle nulls                    │
│  - join key: country_name+year   - join key: country_name+year     │
│  - check distinct country names  - check distinct country names    │
│                                                                     │
│  SILVER OUTPUTS (cleaned tables)                                    │
│                                                                     │
│  silver_wc_matches               silver_socioeconomics             │
│  - valid_wc_matches.csv          (stg_population + stg_gdp joined  │
│  - rejected_wc_matches.csv        on country_name + year)          │
│                                  - valid_socioeconomics.csv        │
│                                  - rejected_socioeconomics.csv     │
│                                                                     │
│  country_mapping.csv             validation_summary.txt            │
│  - wc_team_name                  - row counts per source           │
│  - standardized_country_name     - null counts per column          │
│  Maps WC team names to World     - rejection_reason counts         │
│  Bank country names:                                               │
│  "Ivory Coast"→"Cote d'Ivoire"                                     │
│  "South Korea"→"Korea, Rep."                                       │
│  "USA"→"United States"                                             │
│  "England"→"United Kingdom"                                        │
│  "Czech Republic"→"Czechia"                                        │
│  "Serbia and Montenegro"→"Serbia"                                  │
│  "Trinidad and Tobago"→"Trinidad and Tobago"                       │
│                                                                     │
│  Cleaned, typed, standardized. Reliable join keys. Rejected rows   │
│  quarantined and documented.                                        │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         GOLD LAYER (modeling)                       │
│                       data/gold/                                    │
│                                                                     │
│  FactTable                                                          │
│  Grain: 1 row = 1 team × 1 match                                    │
│  - match_country_id (PK)                                            │
│  - date_id (FK → DimDate)                                           │
│  - tournament_id (FK → DimTournament)                               │
│  - country_id (FK → DimCountry)                                     │
│  - goals_scored, goals_conceded, goal_difference                    │
│  - win_flag, draw_flag, loss_flag, advanced_flag                    │
│  - stage, role (home/away), result                                  │
│  - performance_stars (1–6, see StageStars below)                    │
│  - match_city, stadium                                              │
│  - is_host (1/0 — team is host country of tournament)               │
│  - population, gdp_per_capita_usd (from silver_socioeconomics)      │
│                                                                     │
│  DimDate                         DimTournament                      │
│  - date_id (PK)                  - tournament_id (PK)               │
│  - year                          - year                             │
│  - decade                        - edition_name                     │
│  - tournament_year (boolean)     - host_country                     │
│                                  - nb_teams                         │
│                                  - nb_matches                       │
│                                                                     │
│  DimLocation                                                        │
│  - location_id (PK)                                                 │ 
│  - country_name                                                     │
│  - confederation (UEFA/CONMEBOL/etc.)                               │
│  - region                                                           │
│  - capital_city                                                     │
│                                                                     │
│  StageStars (column in FactTable)                                   │
│  Group Stage (eliminated) → 1 ⭐                                    │
│  Round of 16              → 2 ⭐⭐                                 │
│  Quarter-final            → 3 ⭐⭐⭐                              │
│  Semi-final               → 4 ⭐⭐⭐⭐                           │
│  Runner-up                → 5 ⭐⭐⭐⭐⭐                         │
│  Winner                   → 6 ⭐⭐⭐⭐⭐⭐                      │
│                                                                    │
│  Reporting-ready star schema. Answers all business questions.      │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          POWER BI                                   │
│                       powerbi/                                      │
│                                                                     │
│  Page 1: Tournament Performance by Country                          │
│  - Stage reached per country per edition                            │
│  - Top performers by performance_stars                              │
│  - Filters: year, confederation, stage                              │
│                                                                     │
│  Page 2: Socioeconomic vs Performance                               │
│  - GDP per capita vs performance_stars (scatter)                    │
│  - Population vs goals scored                                       │
│  - Confederation breakdown                                          │
│                                                                     │
│  Source: Gold layer only. No direct connection to Bronze or raw.    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## What Changes Between Layers

| Layer | Data Quality | Transformations Applied |
|-------|-------------|------------------------|
| **Bronze** | Raw as-is | None — only source metadata added (`source_name`, `load_timestamp`, `run_id`) |
| **Silver** | Cleaned and reliable | STG: filter 1998–2018, fix dtypes, unpivot wide format, handle nulls, check distinct country names. Outputs: `silver_wc_matches` + `silver_socioeconomics` (population + GDP joined on `country_name + year`), country mapping applied, rejected rows quarantined |
| **Gold** | Reporting-ready | Star schema built, FactTable joined from Silver outputs, `performance_stars` calculated, `is_host` flag added, dimensions populated |

---

## Python Notebooks — Layer Mapping

| Notebook | Layer |
|----------|-------|
| `01_bronze_wc_matches.ipynb` | Bronze |
| `02_bronze_population.ipynb` | Bronze | 
| `03_bronze_gdp.ipynb` | Bronze |
| `04_silver_stg_wc_matches.ipynb` | Silver STG | 
| `05_silver_stg_population_gdp.ipynb` | Silver STG | 
| `06_silver_socioeconomics.ipynb` | Silver (join stg_population_gdp) |
| `07_silver_country_mapping.ipynb` | Silver (country_mapping) |
| `08_gold_model.ipynb` | Gold |

---

## SQL — Layer Mapping

| Script | Purpose |
|--------|---------|
| `sql/create_gold_tables.sql` | Create and populate Gold tables from Silver outputs |
| `sql/validation_queries.sql` | Row count checks, key completeness, null checks, orphan key checks |

---

## Key Engineering Challenges

| Challenge | Layer | Solution |
|-----------|-------|----------|
| Team name inconsistency across sources | Silver | `country_mapping.csv` — WC team names standardized to World Bank country names |
| World Bank data in wide format (year as columns) | Silver STG | Unpivot using `pandas.melt()` |
| Non-country rows in World Bank data (e.g. "World", "Euro area") | Silver STG | Filter on valid country names only |
| Missing GDP/population for some countries/years | Silver | Document and quarantine in rejected output |
| Identifying host country per match | Gold | Join `match_city` to `DimTournament.host_country` |
