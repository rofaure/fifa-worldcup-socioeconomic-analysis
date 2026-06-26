# fifa-worldcup-socioeconomic-analysis
FIFA World Cup performance analysis (1998–2018) enriched with World Bank population and GDP per capita data, built on a Bronze/Silver/Gold Medallion pipeline with Power BI reporting.

# FIFA World Cup Performance vs. Country Development Indicators (1998–2018)

## Business Case

Does a country's socioeconomic profile influence its football performance at the FIFA World Cup?
This project investigates whether population size and economic wealth (GDP per capita) correlate
with World Cup results across all tournaments from 1998 to 2018, using a Medallion pipeline to
produce a clean, analysis-ready Gold layer.

## Data Sources

| Source | Provider | Description | Join Key | Link Source |
|--------|----------|-------------|----------|-------------|
| WC Match Results | Kaggle (evangower) | Match-level results for every World Cup 1998–2022: teams, scores, stages, host country. Grain: one row per match. | `team_name`, `year` | https://www.kaggle.com/datasets/evangower/fifa-world-cup |
| Population by country | World Bank | Total population per country per year. | `iso_code`, `year` | https://data.worldbank.org/indicator/SP.POP.TOTL?utm_source=chatgpt.com |
| GDP per capita by country | World Bank | Economic output per person per country per year. | `iso_code`, `year` | https://data.worldbank.org/indicator/NY.GDP.MKTP.CD?utm_source=chatgpt.com |

## Business Questions

- Do wealthier countries (higher GDP per capita) consistently advance further in the tournament?
- Do larger populations produce stronger national teams, or do small countries overperform?
- Which confederations (UEFA, CONMEBOL, etc.) dominate, and does that correlate with regional economic development?
- How has the balance of power shifted across the 1998–2018 editions — are emerging economies closing the gap?
- Is there any relationship between a country's population and its World Cup performance?
- How have the World Cup results changed over time?
- which countries are improving the most their level ? Is it linked with population or GDP growth ?
- which are the best football teams ever ?

## Target Audience

Sports analysts, football federations, and journalists covering the intersection of sport and socioeconomics.

## Extras
- Countries ranking by year : https://www.kaggle.com/datasets/cashncarry/fifaworldranking?select=fifa_ranking-2024-06-20.csv
- Weather for each match

## Project Structure
fifa-worldcup-socioeconomic-analysis/

│

├── data/

│   ├── bronze/          # raw ingested data + source metadata

│   ├── silver/          # cleaned, typed, standardized data

│   │   └── rejected/    # rejected/quarantine rows

│   └── gold/            # reporting-ready tables

│

├── notebooks/           # one notebook per PBI

├── sql/                 # Gold table creation + validation queries

├── tests/               # validation checks per layer

├── docs/                # architecture, sources, runbook, gold model

├── powerbi/             # report screenshots

│

├── .env.example

├── requirements.txt

└── BACKLOG.md

## Architecture

`Source → Bronze → Silver → Gold → Power BI`

- **Bronze**: raw data as-is, with ingestion metadata
- **Silver**: cleaned, typed, standardized, join keys validated
- **Gold**: star schema ready for Power BI reporting

## Setup

```bash
git clone https://github.com/TON_USERNAME/fifa-worldcup-socioeconomic-analysis.git
cd fifa-worldcup-socioeconomic-analysis
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env  # fill in your credentials
```

## Team

| Member | Responsibility |
|--------|----------------|
| Member A | Bronze/Silver WC match results + Gold fact table |
| Member B | Bronze/Silver Population + dim_country |
| Member C | Bronze/Silver GDP + Power BI |
| Member D | Join key standardization + validation + dim_tournament |