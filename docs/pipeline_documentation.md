# Pipeline Documentation — FIFA World Cup Socioeconomic Analysis (1998–2018)

> **Project**: Week 8 Mini-Project — Medallion Architecture  
> **Team**: 4 members  
> **Scope**: FIFA World Cup performance (1998–2018) × country socioeconomic indicators (population, GDP per capita)

---

## Architecture Overview

The pipeline follows a **Medallion Architecture** with three layers: Bronze → Silver → Gold.

```
Raw Sources
    │
    ├── Kaggle CSV (WC match results)
    ├── World Bank CSV (Population)
    └── World Bank CSV (GDP per capita)
    │
    ▼
Bronze Layer   data/bronze/        ← raw data + metadata, no transforms
    │
    ▼
Silver Layer   data/silver/        ← cleaned, typed, quarantine pattern
    │
    ▼
Gold Layer     Azure SQL Server    ← star schema, fact + dim tables
    │
    ▼
Power BI       (planned)
```

All credentials are stored in `.env` (never committed). Raw source files live in `data/raw/` (never committed).

---

## Bronze Layer

**Notebooks**: `bronze_worldcup.ipynb`, `bronze_pop.ipynb`, `bronze_gpd.ipynb`  
**Output directory**: `data/bronze/`  
**Principle**: Load as-is. Zero transformations. Only add provenance metadata.

### What each notebook does

#### `bronze_worldcup.ipynb`
- Source: `data/raw/fifa_world_cup/wcmatches.csv` (Kaggle — 1930–2022, all WC editions)
- Output: `data/bronze/bronze_wc_matches.csv`
- Adds three metadata columns: `source_name = "fifa_world_cup_archive"`, `load_timestamp`, `run_id` (UUID)
- No filtering, no column renaming, no type casting

#### `bronze_pop.ipynb`
- Source: `data/raw/world_bank_data/API_POP/API_SP.POP.TOTL_DS2_en_csv_v2_450890.csv`
- Output: `data/bronze/bronze_pop.csv`
- World Bank CSV has 4 header rows → loaded with `skiprows=4`
- Adds: `source_name = "pop.worldbank"`, `load_timestamp`, `run_id`
- Raw wide format preserved (one column per year)

#### `bronze_gpd.ipynb` 
- Source: `data/raw/world_bank_data/API_GDP/API_NY.GDP.MKTP.CD_DS2_en_csv_v2_446954.csv`
- Output: `data/bronze/bronze_gdp.csv`
- Same wide format as population, `skiprows=4`
- Adds: `source_name`, `load_timestamp`, `run_id`

### Bronze output schema

| File | Key columns |
|------|-------------|
| `bronze_wc_matches.csv` | `year`, `country`, `city`, `stage`, `home_team`, `away_team`, `home_score`, `away_score`, `winning_team`, `losing_team`, `date`, + metadata |
| `bronze_pop.csv` | `Country Name`, `Country Code`, `1960`…`2022` (wide), + metadata |
| `bronze_gdp.csv` | `Country Name`, `Country Code`, `1960`…`2022` (wide), + metadata |

### Design decisions
- No deduplication, no null handling, no type conversion at Bronze — this is the immutable audit trail
- If Silver identifies a data issue, the fix goes into the raw source and Bronze is re-run (never patching Silver directly)

---

## Silver Layer

**Notebooks**: `silver_worldcup.ipynb`, `silver_population_gdp.ipynb`  
**Cross-check notebook**: `silver_bronze_check.ipynb`  
**Output directory**: `data/silver/`  
**Principle**: Clean, type-cast, standardize. Quarantine invalid rows — never silently drop.

### `silver_worldcup.ipynb`

Reads `data/bronze/bronze_wc_matches.csv` and produces `data/silver/silver_wc_output.csv`.

**Steps:**

1. **Load** — reads `bronze_wc_matches.csv`
2. **Column standardization** — strips, lowercases, replaces spaces with `_`
3. **String normalization** — strips whitespace from all string columns
4. **Date parsing** — parses `date` → `date_clean` (datetime), `load_timestamp` → `load_timestamp_clean`; extracts `year` from `date_clean`
5. **Year filter** — keeps 1998–2018 only (`year.between(1998, 2018)`)
6. **Team name corrections** — applied inline via `.replace()`:
   - `China PR` → `China`
   - `FR Yugoslavia` → `Serbia`
   - `Portagul` → `Portugal`
   - `Columbia` → `Colombia`
   (applied to `home_team`, `away_team`, `winning_team`, `losing_team`)
7. **Quality flags** — adds `review_reason` column:
   - `MISSING_YEAR` if `year` is null
   - `MISSING_DATE` if `date_clean` is null
8. **Output selection** — keeps only: `year`, `country`, `city`, `stage`, `home_team`, `away_team`, `home_score`, `away_score`, `winning_team`, `losing_team`, `date_clean`, `source_name`, `load_timestamp_clean`, `run_id`
9. **Save** — writes `silver_wc_output.csv`; writes `silver_wc_summary.txt` (row counts)

### `silver_population_gdp.ipynb`

Reads both World Bank bronze files and produces `data/silver/valid_socioeconomics.csv` + `data/silver/rejected/rejected_socioeconomics.csv`.

**Steps:**

1. **Load** — reads `bronze_pop.csv` and `bronze_gdp.csv` (`skiprows=4`)
2. **Unpivot (melt)** — wide → long: year columns (1998–2018 only) become rows. Columns: `Country Name`, `Country Code`, `year`, `population` / `gdp_per_capita_usd`
3. **Merge** — population long df merged with GDP long df on `Country Name` + `year` (left join)
4. **Column rename** — `Country Name` → `country_name`, `Country Code` → `country_code`
5. **Type casting** — `country_name` as string/stripped/title-cased, `country_code` as string/stripped/upper, `population` and `gdp_per_capita_usd` as numeric
6. **Aggregate filter** — removes World Bank non-country rows: `WLD`, `EUU`, `LCN`, `EAS`, `SAS`, `SSA`, `MEA`, `NAC`, `ECS`, `OED`, `HIC`, `MIC`, `LMC`, `UMC`, `LIC`
7. **Year filter** — keeps 1998–2018
8. **Country name mapping** — loads `data/utils/country_mapping.json`, applies case-insensitive lookup to standardize World Bank names → WC team names (e.g. `Korea, Rep.` → `South Korea`)
9. **UK Nations split** — the World Bank has a single `United Kingdom` row. It is split into 4 rows using ONS census population shares (stable 1998–2018):

   | Nation | Share | Country code |
   |--------|-------|--------------|
   | England | 84.0% | ENG |
   | Scotland | 8.4% | SCO |
   | Wales | 4.7% | WAL |
   | Northern Ireland | 2.9% | NIR |

   GDP per capita is kept identical across all 4 nations (per-person metric, unchanged by splitting). The original `United Kingdom` row is removed.

10. **Quality rules** (priority order — first match wins):

    | Priority | review_reason | Condition |
    |----------|--------------|-----------|
    | 1 | `MISSING_COUNTRY_NAME` | `country_name` is null |
    | 2 | `MISSING_COUNTRY_CODE` | `country_code` is null |
    | 3 | `MISSING_POPULATION` | `population` is null |
    | 4 | `MISSING_GDP` | `gdp_per_capita_usd` is null |
    | 5 | `INVALID_POPULATION` | `population` < 0 |
    | 6 | `INVALID_GDP` | `gdp_per_capita_usd` < 0 |

11. **Valid/rejected split** — valid rows (no `review_reason`) saved to `valid_socioeconomics.csv`; rejected rows saved to `rejected/rejected_socioeconomics.csv` with `review_reason` column
12. **Metadata** — valid rows get `source_name = "API_POP + API_GDP"`, `load_timestamp` (UTC)
13. **Validation summary** — writes `data/silver/validation_summary.txt` with row counts and rejection breakdown

### Silver output files

| File | Content |
|------|---------|
| `data/silver/silver_wc_output.csv` | Clean WC match data, 1998–2018 |
| `data/silver/valid_socioeconomics.csv` | Clean population + GDP, 1998–2018, per country per year |
| `data/silver/rejected/rejected_socioeconomics.csv` | Invalid rows with `review_reason` |
| `data/silver/validation_summary.txt` | Row count audit trail |
| `data/silver/silver_wc_summary.txt` | WC pipeline row counts |

### Known exclusions

| Item | Reason |
|------|--------|
| World Bank aggregates (`WLD`, `EUU`, etc.) | Not countries — regional/income aggregates |
| Years outside 1998–2018 | Project scope |
| `United Kingdom` row | Replaced by 4 nation rows |
| North Korea | `MISSING_GDP` in World Bank. Only 1 WC edition (2010). Insufficient for analysis. 3 null rows remain in `fact_wc_match` for population/gdp columns. |

### Cross-check notebook (`silver_bronze_check.ipynb`)

Runs 10 quality topics after each pipeline run:

1. File availability (all expected files exist)
2. Row and column counts (+ retention %)
3. Column audit (unexpected renames or additions)
4. Year coverage (1998–2018, 21 years expected)
5. Null values (top 5 null columns per dataset)
6. Duplicate checks (full-row + business key)
7. Business rule checks (positive scores, valid dates, positive population/GDP, 3-char country codes)
8. Rejected row summary (breakdown by `review_reason`)
9. Country alignment (WC team names vs socioeconomics — missing countries surfaced here)
10. Metadata quality (`source_name`, `load_timestamp`, `run_id` presence)

---

## Gold Layer

**Notebook**: `gold_model.ipynb` (fact table — Robin)  
**Notebook**: `gold_dim.ipynb` (dim tables — teammates)  
**SQL**: `sql/dim_tables.sql`, `sql/fact_table.sql`, `sql/final_dw.sql`, `sql/gold_validation.sql`  
**Target**: Azure SQL Server (`sebastien-sql.database.windows.net`)  
**Schema**: `dbo`

### Star schema

```
                    dim_date
                  (year_id PK)
                       │
                       │ year_id (FK)
                       │
dim_country ───── fact_wc_match ───── dim_tournament
(country_id PK)  (match_country_id PK)  (tournament_id PK)
    ▲                   │
    │           host_country_id (FK)
    └───────────────────┘
    (role-playing dimension)
```

### `fact_wc_match` — grain: 1 row = 1 country × 1 match

| Column | Type | Description |
|--------|------|-------------|
| `match_country_id` | INT PK | Surrogate key (sequential 1–768) |
| `year_id` | INT FK → dim_date | Links to tournament year |
| `tournament_id` | INT FK → dim_tournament | Links to tournament edition |
| `host_country_id` | INT FK → dim_country | Country that physically hosted the match |
| `team_country_id` | INT FK → dim_country | Country playing the match |
| `goals_scored` | INT | Goals scored by this team in this match |
| `goals_conceded` | INT | Goals conceded by this team in this match |
| `goal_difference` | INT | goals_scored − goals_conceded |
| `outcome` | VARCHAR | `win`, `loss`, or `draw` |
| `stage` | VARCHAR | Match stage (e.g. `Group A`, `Round of 16`, `Final`) |
| `performance_stars` | INT | Max stage reached in tournament (1–6, see below) |
| `is_host` | INT | 1 if team_country = host_country for this match, else 0 |
| `population` | INT | Country population for that year (from socioeconomics) |
| `gdp_per_capita_usd` | DECIMAL(18,2) | GDP per capita for that year (from socioeconomics) |

**Total rows**: 768 (384 matches × 2 teams per match)

### `dim_date`

| Column | Type |
|--------|------|
| `year_id` | INT PK |
| `year` | INT |

### `dim_country`

| Column | Type |
|--------|------|
| `country_id` | INT PK |
| `country_name` | VARCHAR(50) |
| `confederation` | VARCHAR(50) |

### `dim_tournament`

| Column | Type |
|--------|------|
| `tournament_id` | INT PK |
| `tournament_name` | VARCHAR(50) |
| `num_matches` | INT |
| `num_teams` | INT |

### `performance_stars` — scoring logic

| Stage reached | Stars | Note |
|--------------|-------|------|
| Group stage | 1 | Any group (A–H) |
| Round of 16 | 2 | |
| Quarterfinals | 3 | |
| Semifinals | 4 | Includes third-place losers |
| Final (runner-up) | 5 | |
| Final (winner) | 6 | `stage = "Final"` AND `outcome = "win"` |

Computed as `max(stage_star)` per `team_country × year` — the same value is assigned to every match row for that team in that tournament.

### `is_host` — multi-host handling

`is_host` is computed per match row by comparing `team_country` with `country` (the host field from the WC dataset, which holds the country where that specific match was physically played). This correctly handles the 2002 co-hosted tournament (South Korea vs. Japan): a South Korea match played in South Korea gets `is_host = 1` for South Korea, `is_host = 0` for their opponent.

### FK mapping strategy

FK IDs are generated in `gold_model.ipynb` from sorted unique values:
- `year_map`: `{1998:1, 2002:2, 2006:3, 2010:4, 2014:5, 2018:6}`
- `tournament_map`: same as `year_map` (1:1 tournament per year)
- `country_map`: sorted alphabetical — all countries across `host_country` and `team_country`

**Important**: these mappings must be shared with dim table owners (teammates) to ensure FK consistency between fact and dim tables.

### SQL setup (`sql/`)

| File | Purpose |
|------|---------|
| `final_dw.sql` | Entry point — drops fact, creates `etl_golden_logs`, calls `usp_create_dim_tables` then `usp_create_fact_wc_match`, then runs validation |
| `dim_tables.sql` | Stored procedure `usp_create_dim_tables` — creates `dim_date`, `dim_country`, `dim_tournament` |
| `fact_table.sql` | Stored procedure `usp_create_fact_wc_match` — creates `fact_wc_match` with FK constraints |
| `gold_validation.sql` | Stored procedure `sp_validate_gold_layer` — 7 validation checks, writes results to `validation_summary` and `etl_golden_logs` |

### Gold validation checks (`sp_validate_gold_layer`)

1. Match and team counts per tournament vs. `dim_tournament.num_matches` / `num_teams`
2. `population > 0` for all rows except North Korea
3. `gdp_per_capita_usd > 0` for all rows except North Korea
4. `performance_stars` between 1 and 6
5. `is_host` in (0, 1)
6. All `team_country_id` values exist in `dim_country`
7. Each `tournament_id` maps to exactly one `year_id`

Validation result (`PASS`/`FAIL`) is logged to `etl_golden_logs`.

---

## Supporting Artifacts

| File | Description |
|------|-------------|
| `data/utils/country_mapping.json` | 60-entry dict: World Bank country names → WC team names. Case-insensitive at runtime. |
| `data/utils/country_confederations.json` | Country → confederation mapping (used by dim_country) |
| `docs/data_quality.md` | Full data quality documentation: quarantine pattern, review_reason rules, known exclusions, UK split, WC name corrections |
| `docs/sources.md` | Source descriptions, licenses, known limitations, fallback plans |
| `docs/architecture.md` | Architecture diagram |
| `docs/star_schema.jpeg` | Final star schema diagram |
