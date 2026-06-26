# Data Sources — FIFA World Cup Socioeconomic Analysis (1998–2022)

> **PBI-01** | Owner: All | Status: Done

---

## Source 1 — FIFA World Cup Match Results

| Field | Value |
|-------|-------|
| **Name** | FIFA World Cup (evangower) |
| **URL** | https://www.kaggle.com/datasets/evangower/fifa-world-cup |
| **Source type** | Downloadable public dataset (Kaggle CSV) |
| **Grain** | One row per match |
| **Coverage** | 1930–2022 (filtered to 1998–2022 in Silver) |
| **License** | Public domain |

**Key columns**

| Column | Description |
|--------|-------------|
| `Year` | Tournament year |
| `Stage` | Match stage (Group stage, Round of 16, Quarter-final, Semi-final, Final) |
| `Home Team Name` | Name of home team |
| `Away Team Name` | Name of away team |
| `Home Team Goals` | Goals scored by home team |
| `Away Team Goals` | Goals scored by away team |
| `Win conditions` | Extra time / penalty details if applicable |

**Expected join keys**
- `Home Team Name` / `Away Team Name` → standardized to `iso_code` via `dim_country_mapping` (Silver)
- `Year` → joins to `dim_tournament` and `dim_socioeconomic`

**Known limitations**
- Team names are not ISO-standardized (e.g. "USA", "South Korea", "Ivory Coast" vary across editions)
- No individual player or confederation data
- Coverage ends at 2022; does not include 2026

**Fallback plan**
If Kaggle download fails: use [FIFA World Cup 1930–2022 All Match Dataset](https://www.kaggle.com/datasets/jahaidulislam/fifa-world-cup-1930-2022-all-match-dataset) as a direct substitute with equivalent columns.

---

## Source 2 — World Bank Population Data

| Field | Value |
|-------|-------|
| **Name** | Population, total |
| **URL** | https://data.worldbank.org/indicator/SP.POP.TOTL |
| **Source type** | Open data portal (World Bank, CSV download) |
| **Grain** | One row per country per year |
| **Coverage** | 1960–2022 (filtered to 1998–2022 in Silver) |
| **License** | CC BY 4.0 |

**Key columns**

| Column | Description |
|--------|-------------|
| `Country Name` | Full country name |
| `Country Code` | ISO 3166-1 alpha-3 code |
| `[Year]` | Wide format — one column per year (unpivoted in Silver) |

**Expected join keys**
- `Country Code` (ISO alpha-3) → primary join key to all other sources
- `Year` → joins to `fact_wc_match` and `dim_socioeconomic`

**Known limitations**
- Raw file is in wide format (years as columns) — requires unpivoting in Silver
- Includes non-country aggregates (e.g. "World", "Euro area") — must be filtered out
- Some small territories have missing values for certain years

**Fallback plan**
If World Bank portal is unavailable: same data accessible via [Our World in Data](https://ourworldindata.org/grapher/population) or the pre-packaged [Kaggle World Bank Population dataset](https://www.kaggle.com/datasets/gemartin/world-bank-data-1960-to-2016).

---

## Source 3 — World Bank GDP per Capita

| Field | Value |
|-------|-------|
| **Name** | GDP per capita (current US$) |
| **URL** | https://data.worldbank.org/indicator/NY.GDP.PCAP.CD |
| **Source type** | Open data portal (World Bank, CSV download) |
| **Grain** | One row per country per year |
| **Coverage** | 1960–2022 (filtered to 1998–2022 in Silver) |
| **License** | CC BY 4.0 |

**Key columns**

| Column | Description |
|--------|-------------|
| `Country Name` | Full country name |
| `Country Code` | ISO 3166-1 alpha-3 code |
| `[Year]` | Wide format — one column per year (unpivoted in Silver) |

**Expected join keys**
- `Country Code` (ISO alpha-3) → primary join key to all other sources
- `Year` → joins to `fact_wc_match` and `dim_socioeconomic`

**Known limitations**
- Same wide format as Population — requires identical unpivoting logic in Silver
- GDP values in current USD (not inflation-adjusted) — comparisons across years should be interpreted with caution
- Missing values for some countries/years (e.g. conflict zones, newly independent states)

**Fallback plan**
If World Bank portal is unavailable: same data accessible via [Our World in Data GDP per capita](https://ourworldindata.org/grapher/gdp-per-capita-worldbank) or [Kaggle Global GDP Per Capita 1990–2023](https://www.kaggle.com/datasets/gauravkumar2525/global-gdp-per-capita-1990-2023-world-bank).

---

## Join Strategy Summary

```
fact_wc_match  ──── team_name ────▶ dim_country_mapping ──── iso_code ────▶ dim_country
                                                                               │
                                                              iso_code + year  ▼
                                                                          dim_socioeconomic
                                                                   (population + gdp_per_capita)
```

| Source | Join key produced | Joins to |
|--------|-------------------|----------|
| WC Match Results | `team_name` (raw) | `dim_country_mapping.team_name` |
| dim_country_mapping (Silver) | `iso_code` | All dimension tables |
| Population | `Country Code` (ISO) + `Year` | `dim_socioeconomic` |
| GDP per capita | `Country Code` (ISO) + `Year` | `dim_socioeconomic` |
