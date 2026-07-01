# Runbook — FIFA World Cup Socioeconomic Pipeline

> Complete step-by-step guide to run the entire pipeline from scratch on a new machine.

---

## Prerequisites

### Software

| Tool | Version | Notes |
|------|---------|-------|
| Python | 3.10+ | 3.11+ recommended (avoid `datetime.UTC` issues on 3.10) |
| Jupyter Notebook / JupyterLab | Any | Or VS Code with Jupyter extension |
| Git | Any | |
| ODBC Driver 17 for SQL Server | 17 | Required for Azure SQL connection |
| SSMS (optional) | Any | For manual SQL verification |

### Python packages

Install all dependencies from the project root:

```bash
pip install -r requirements.txt
```

Key packages: `pandas`, `numpy`, `python-dotenv`, `sqlalchemy`, `pyodbc`

### ODBC Driver 17

**Windows:**
```
Download from Microsoft: https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server
```

**Mac (Homebrew):**
```bash
brew install msodbcsql17
```

**Linux (Ubuntu/Debian):**
```bash
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql17
```

---

## Step 0 — Clone the repo and configure environment

```bash
# 1. Clone
git clone <repo-url>
cd fifa-worldcup-socioeconomic-analysis

# 2. Create virtual environment (recommended)
python -m venv .venv
source .venv/bin/activate        # Mac/Linux
.venv\Scripts\activate           # Windows

# 3. Install dependencies
pip install -r requirements.txt
```

### Create `.env` file

Create a file named `.env` at the project root (never commit this):

```
SQL_DATABASE=<your-database-name>
SQL_PASSWORD=<your-sql-password>
```

- `SQL_DATABASE`: find in SSMS → Object Explorer → your server → Databases
- `SQL_PASSWORD`: provided by your team lead (Sébastien)
- Server is hardcoded in the notebook: `sebastien-sql.database.windows.net`
- Username is hardcoded: `sqladmin`

Verify `.env` is in `.gitignore` before any `git push`.

---

## Step 1 — Place raw data files

The `data/` directory is not committed to Git. Raw source files must be placed manually.

**Expected directory structure:**

```
data/
├── raw/
│   ├── fifa_world_cup/
│   │   └── wcmatches.csv                                          ← Kaggle download
│   └── world_bank_data/
│       ├── API_POP/
│       │   └── API_SP.POP.TOTL_DS2_en_csv_v2_450890.csv          ← World Bank download
│       └── API_GDP/
│           └── API_NY.GDP.MKTP.CD_DS2_en_csv_v2_446954.csv       ← World Bank download
└── utils/
    ├── country_mapping.json                                        ← Already in repo
    └── country_confederations.json                                 ← Already in repo
```

**Download sources:**
- WC matches: https://www.kaggle.com/datasets/evangower/fifa-world-cup → download `wcmatches.csv`
- Population: https://data.worldbank.org/indicator/SP.POP.TOTL → Download → CSV
- GDP per capita: https://data.worldbank.org/indicator/NY.GDP.PCAP.CD → Download → CSV

---

## Step 2 — Bronze Layer

Run the three Bronze notebooks **in any order** (no dependencies between them).

**Navigate to notebooks folder:**
```
cd fifa-worldcup-socioeconomic-analysis
```

### 2a. Bronze — World Cup matches

Open and run all cells: `notebooks/bronze_worldcup.ipynb`

Expected output: `data/bronze/bronze_wc_matches.csv`

Verify:
- No errors in any cell
- File exists at `data/bronze/bronze_wc_matches.csv`
- Shape should be ~900 rows (all WC editions 1930–2022)

### 2b. Bronze — Population

Open and run all cells: `notebooks/bronze_pop.ipynb`

Expected output: `data/bronze/bronze_pop.csv`

Verify:
- No errors
- File exists at `data/bronze/bronze_pop.csv`
- Shape: ~17,000 rows (wide format, ~270 countries × ~60 years)

### 2c. Bronze — GDP

Open and run all cells: `notebooks/bronze_gpd.ipynb`

Expected output: `data/bronze/bronze_gdp.csv`

Verify:
- No errors
- File exists at `data/bronze/bronze_gdp.csv`
- Same shape as population

---

## Step 3 — Silver Layer

Run Silver notebooks **after Bronze**. Population/GDP notebook must run before Gold.

### 3a. Silver — World Cup matches

Open and run all cells: `notebooks/silver_worldcup.ipynb`

Expected output: `data/silver/silver_wc_output.csv`

**What it does:** filters to 1998–2018, standardizes column names, parses dates, corrects team name typos (China PR→China, FR Yugoslavia→Serbia, Portagul→Portugal, Columbia→Colombia), quarantines rows missing year or date.

Verify:
- No errors
- `data/silver/silver_wc_output.csv` exists
- `data/silver/silver_wc_summary.txt` exists
- Expected: ~384 rows (matches 1998–2018 only)
- `home_team` and `away_team` must never be equal on the same row (was a known bug — verify)

### 3b. Silver — Population + GDP

Open and run all cells: `notebooks/silver_population_gdp.ipynb`

**Important: run this notebook with a fresh kernel (Kernel → Restart & Run All).** Running individual cells out of order (especially the UK split cell) can produce duplicate rows.

Expected outputs:
- `data/silver/valid_socioeconomics.csv`
- `data/silver/rejected/rejected_socioeconomics.csv`
- `data/silver/validation_summary.txt`

**What it does:** unpivots wide→long, merges pop+GDP, filters aggregates and years, applies country name mapping, splits UK into 4 nations, quarantines rows with missing/invalid values.

Verify:
- `valid_socioeconomics.csv` exists
- Check `validation_summary.txt` for row counts
- UK nations (England, Scotland, Wales, Northern Ireland) should each have 21 rows
- North Korea should appear in `rejected_socioeconomics.csv` with `MISSING_GDP`

### 3c. Silver cross-check (optional but recommended)

Open and run all cells: `notebooks/silver_bronze_check.ipynb`

This runs 10 quality checks across all Bronze and Silver outputs. Review the printed results:
- All files should be found (check 1)
- No unexpected nulls in key columns (check 5)
- No business key duplicates (check 6)
- Country alignment check (check 9) — must show 0 missing countries (after corrections already applied)

---

## Step 4 — Gold Layer

### 4a. SQL Server setup — schema creation

Before loading data, the schema must exist in Azure SQL Server.

Connect to `sebastien-sql.database.windows.net` via SSMS, then run the SQL scripts in this order:

```sql
-- Step 1: Run final_dw.sql
-- Creates etl_golden_logs, then calls both stored procedures
-- (this calls usp_create_dim_tables and usp_create_fact_wc_match)
```

Run `sql/final_dw.sql` in SSMS. This will:
1. Drop `fact_wc_match` if it exists
2. Create `etl_golden_logs` table (if not exists)
3. Execute `usp_create_dim_tables` → creates `dim_date`, `dim_country`, `dim_tournament`
4. Execute `usp_create_fact_wc_match` → creates `fact_wc_match` with FK constraints
5. Execute `sp_validate_gold_layer` → runs initial validation (will show empty tables)

### 4b. Load dim tables

Dim tables are loaded by teammates via `notebooks/gold_dim.ipynb`. This must run **before** the fact table to satisfy FK constraints.

Coordinate with your team to confirm dim tables are populated before proceeding to 4c.

Verify in SSMS:
```sql
SELECT COUNT(*) FROM dbo.dim_date;         -- expected: 6 rows (1998,2002,2006,2010,2014,2018)
SELECT COUNT(*) FROM dbo.dim_country;      -- expected: ~70 rows
SELECT COUNT(*) FROM dbo.dim_tournament;   -- expected: 6 rows
```

### 4c. Gold — Fact table

Open and run all cells: `notebooks/gold_model.ipynb`

**Prerequisites:** `.env` file must exist with `SQL_DATABASE` and `SQL_PASSWORD`.

**What it does:**
1. Loads `silver_wc_output.csv` and `valid_socioeconomics.csv`
2. Unpivots WC matches wide→long (1 row per team per match)
3. Computes `goal_difference` and `outcome` (win/loss/draw)
4. Sets `is_host = 1` where `team_country == host_country` for that match
5. Computes `performance_stars` (max stage reached per team × year)
6. Joins socioeconomics on `team_country + year`
7. Generates FK IDs (year_id, tournament_id, host_country_id, team_country_id)
8. Inserts PK `match_country_id` (1–768)
9. Loads to `dbo.fact_wc_match` via SQLAlchemy (`if_exists="replace"`)
10. Verifies row count via SQL SELECT COUNT(*)

Expected output:
- `dbo.fact_wc_match` loaded with **768 rows**
- Console output: `Loaded 768 rows into dbo.fact_wc_match`
- 3 rows will have null `population` and `gdp_per_capita_usd` (North Korea, documented exclusion)

**If you get a PendingRollbackError:**
A previous failed transaction left the connection in an invalid state. The notebook has `engine.dispose()` before `to_sql()` to reset the connection pool — ensure this cell is present. If the error persists, restart the kernel and re-run from the connection cell.

**If you get `Login failed (28000)`:**
Check `.env` for correct `SQL_DATABASE` and `SQL_PASSWORD` values. Verify the database name in SSMS Object Explorer.

### 4d. Add FK constraints (if not already added by stored procedure)

The stored procedure `usp_create_fact_wc_match` adds FK constraints automatically when the table is first created via SQL. However, `to_sql()` in Python uses `if_exists="replace"` which drops and recreates the table without constraints. After loading, re-run FK constraints:

```sql
ALTER TABLE dbo.fact_wc_match
    ADD CONSTRAINT FK_fact_wc_match_year
    FOREIGN KEY (year_id) REFERENCES dbo.dim_date(year_id);

ALTER TABLE dbo.fact_wc_match
    ADD CONSTRAINT FK_fact_wc_match_tournament
    FOREIGN KEY (tournament_id) REFERENCES dbo.dim_tournament(tournament_id);

ALTER TABLE dbo.fact_wc_match
    ADD CONSTRAINT FK_fact_wc_match_host_country
    FOREIGN KEY (host_country_id) REFERENCES dbo.dim_country(country_id);

ALTER TABLE dbo.fact_wc_match
    ADD CONSTRAINT FK_fact_wc_match_team_country
    FOREIGN KEY (team_country_id) REFERENCES dbo.dim_country(country_id);
```

### 4e. Run Gold validation

Run the validation stored procedure in SSMS:

```sql
EXEC dbo.sp_validate_gold_layer;
SELECT * FROM validation_summary;
SELECT * FROM etl_golden_logs ORDER BY log_timestamp DESC;
```

All checks should pass (`validation_issues_count = 0`) except:
- Population/GDP checks — 3 rows for North Korea (expected, documented exclusion)

---

## Step 5 — Git commit

After each layer completes successfully:

```bash
# Bronze
git checkout -b feat/bronze-ingestion
git add notebooks/bronze_worldcup.ipynb notebooks/bronze_pop.ipynb notebooks/bronze_gpd.ipynb
git commit -m "feat(bronze): add raw ingestion notebooks for WC matches, population, GDP"
git push origin feat/bronze-ingestion

# Silver
git checkout -b feat/silver-cleaning
git add notebooks/silver_worldcup.ipynb notebooks/silver_population_gdp.ipynb notebooks/silver_bronze_check.ipynb
git commit -m "feat(silver): add cleaning notebooks with quarantine pattern and UK nations split"
git push origin feat/silver-cleaning

# Gold
git checkout -b feat/gold-fact-table
git add notebooks/gold_model.ipynb
git commit -m "feat(gold): add fact_wc_match notebook with SQLAlchemy load to Azure SQL"
git push origin feat/gold-fact-table
```

Then open a pull request for each branch. Never push directly to `main`.

---

## Troubleshooting

### UK split warning `'United Kingdom' introuvable`
**Cause**: UK split cell was run more than once in the same kernel session (UK row already replaced on first run).  
**Fix**: Kernel → Restart & Run All. Do not re-run individual cells.

### `datetime.UTC` AttributeError
**Cause**: `datetime.UTC` was introduced in Python 3.11. Code uses `timezone.utc` instead.  
**Fix**: Ensure notebook uses `from datetime import timezone` and `datetime.now(timezone.utc)`.

### `DeprecationWarning: datetime.utcnow()`
**Cause**: `datetime.utcnow()` deprecated in Python 3.12.  
**Fix**: Replace with `datetime.now(timezone.utc)`.

### `PendingRollbackError` on `to_sql()`
**Cause**: A prior failed transaction left SQLAlchemy in a bad state.  
**Fix**: `engine.dispose()` is already in the notebook before `to_sql()`. If error persists, restart kernel.

### `Login failed (error 28000)`
**Cause**: Wrong database name or password in `.env`.  
**Fix**: Verify `SQL_DATABASE` matches what SSMS shows in Object Explorer. Confirm password with team lead.

### `Group D ` trailing space in stage column
**Cause**: Stage values in source CSV have trailing whitespace.  
**Fix**: `df_long["stage"] = df_long["stage"].str.strip()` is applied in `gold_model.ipynb` before the stage_stars mapping.

### Silver WC output: `home_team == away_team` on same row
**Cause**: Bug in the silver notebook (Brazil vs Brazil issue). Occurred when the home/away unpivot was applied to an already-unpivoted DataFrame.  
**Fix**: Restart silver_worldcup.ipynb kernel and re-run all cells cleanly.

### North Korea null values in fact table
**Expected behavior**: 3 rows with null `population` and `gdp_per_capita_usd` correspond to North Korea's 3 matches in 2010. This is a documented exclusion (World Bank has no GDP data for North Korea). These rows are intentionally kept in the fact table and excluded from socioeconomic analysis queries.

---

## Full pipeline run order (quick reference)

```
1. bronze_worldcup.ipynb      → data/bronze/bronze_wc_matches.csv
2. bronze_pop.ipynb           → data/bronze/bronze_pop.csv
3. bronze_gpd.ipynb           → data/bronze/bronze_gdp.csv
4. silver_worldcup.ipynb      → data/silver/silver_wc_output.csv
5. silver_population_gdp.ipynb → data/silver/valid_socioeconomics.csv
6. silver_bronze_check.ipynb  → quality report (optional)
7. SSMS: run sql/final_dw.sql → creates schema + stored procedures
8. gold_dim.ipynb (teammates) → populates dim_date, dim_country, dim_tournament
9. gold_model.ipynb           → loads dbo.fact_wc_match (768 rows)
10. SSMS: ALTER TABLE         → re-adds FK constraints after Python load
11. SSMS: EXEC sp_validate_gold_layer → final validation
```
