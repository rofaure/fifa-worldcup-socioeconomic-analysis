DROP PROCEDURE IF EXISTS usp_create_fact_wc_match;
GO

CREATE PROCEDURE usp_create_fact_wc_match
AS
BEGIN
    SET NOCOUNT ON;

    DROP TABLE IF EXISTS fact_wc_match;

    CREATE TABLE fact_wc_match (
        match_country_id INT PRIMARY KEY,
        year_id INT NOT NULL,
        tournament_id INT NOT NULL,
        host_country_id INT NOT NULL,
        team_country_id INT NOT NULL,
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

    ALTER TABLE fact_wc_match
    ADD CONSTRAINT FK_fact_wc_match_year FOREIGN KEY (year_id) REFERENCES dim_date(year_id);

    ALTER TABLE fact_wc_match
    ADD CONSTRAINT FK_fact_wc_match_tournament FOREIGN KEY (tournament_id) REFERENCES dim_tournament(tournament_id);

    ALTER TABLE fact_wc_match
    ADD CONSTRAINT FK_fact_wc_match_host_country FOREIGN KEY (host_country_id) REFERENCES dim_country(country_id);

    ALTER TABLE fact_wc_match
    ADD CONSTRAINT FK_fact_wc_match_team_country FOREIGN KEY (team_country_id) REFERENCES dim_country(country_id);

    -- Summary Log
    INSERT INTO etl_golden_logs (table_name, columns, foreign_keys, log_timestamp, status)
    VALUES (
        'fact_wc_match',
        'match_country_id, year_id, tournament_id, host_country_id, team_country_id, goals_scored, goals_conceded, goal_difference, outcome, stage, performance_stars, is_host, population, gdp_per_capita_usd',
        'FK_fact_wc_match_year (year_id -> dim_date), FK_fact_wc_match_tournament (tournament_id -> dim_tournament), FK_fact_wc_match_host_country (host_country_id -> dim_country), FK_fact_wc_match_team_country (team_country_id -> dim_country)',
        GETDATE(),
        'CREATED'
    );

END;

