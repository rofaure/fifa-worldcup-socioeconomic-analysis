DROP TABLE IF EXISTS fact_wc_match;

CREATE TABLE fact_wc_match (
    match_country_id INT PRIMARY KEY,
    year_id INT NOT NULL FOREIGN KEY REFERENCES dim_date(year_id),
    tournament_id INT NOT NULL FOREIGN KEY REFERENCES dim_tournament(tournament_id),
    host_country_id INT NOT NULL FOREIGN KEY REFERENCES dim_country(country_id),
    team_country_id INT NOT NULL FOREIGN KEY REFERENCES dim_country(country_id),
    goals_scored INT NOT NULL,
    goals_conceded INT NOT NULL,
    goal_difference INT NOT NULL,
    outcome VARCHAR(50) NOT NULL,
    stage VARCHAR(50) NOT NULL,
    performance_stars INT NOT NULL,
    is_host INT NOT NULL,
    population INT NOT NULL,
    gdp_per_capita_usd DECIMAL(18,2) NOT NULL
);


