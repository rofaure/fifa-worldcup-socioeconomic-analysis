# fifa-worldcup-socioeconomic-analysis
FIFA World Cup performance analysis (1998–2022) enriched with World Bank population and GDP per capita data, built on a Bronze/Silver/Gold Medallion pipeline with Power BI reporting.

# FIFA World Cup Performance vs. Country Development Indicators (1998–2022)

## Business Case

Does a country's socioeconomic profile influence its football performance at the FIFA World Cup?
This project investigates whether population size and economic wealth (GDP per capita) correlate
with World Cup results across all tournaments from 1998 to 2022, using a Medallion pipeline to
produce a clean, analysis-ready Gold layer.

## Data Sources

| Source | Provider | Description | Join Key |
|--------|----------|-------------|----------|
| WC Match Results | Kaggle (evangower) | Match-level results for every World Cup 1998–2022: teams, scores, stages, host country. Grain: one row per match. | `team_name`, `year` |
| Population by country | World Bank | Total population per country per year. | `iso_code`, `year` |
| GDP per capita by country | World Bank | Economic output per person per country per year. | `iso_code`, `year` |

## Business Questions

- Do wealthier countries (higher GDP per capita) consistently advance further in the tournament?
- Do larger populations produce stronger national teams, or do small countries overperform?
- Which confederations (UEFA, CONMEBOL, etc.) dominate, and does that correlate with regional economic development?
- How has the balance of power shifted across the 1998–2022 editions — are emerging economies closing the gap?

## Target Audience

Sports analysts, football federations, and journalists covering the intersection of sport and socioeconomics.
