
-- Validation SQL for gold layer: fact_wc_matches and related dimensions
-- 1) Compare number of matches and teams by tournament
-- 2) Check team/country attributes: population>0, gdp>0,
--    performance_stars between 1 and 6, is_host in (0,1)

IF OBJECT_ID('dbo.sp_validate_gold_layer', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_validate_gold_layer;
GO

CREATE PROCEDURE dbo.sp_validate_gold_layer
AS
BEGIN
    SET NOCOUNT ON;

    -- Matches per tournament
    WITH matches_per_tournament AS (
        SELECT
            tournament_id,
            COUNT(*)/2 AS matches_count -- since 2 rows per match
        FROM fact_wc_match
        GROUP BY tournament_id
    ),
    
    -- Teams per tournament derived from match team references
    teams_per_tournament AS (
        SELECT
            tournament_id,
            COUNT(DISTINCT team_country_id) AS teams_count
        FROM fact_wc_match
        GROUP BY tournament_id
    )
    
    SELECT
        m.tournament_id,
        m.matches_count,
        t.teams_count,
        dt.num_matches AS tournament_match_count,
        dt.num_teams AS tournament_teams_count
    FROM matches_per_tournament m
    LEFT JOIN teams_per_tournament t
        ON m.tournament_id = t.tournament_id
    LEFT JOIN dim_tournament dt
        ON m.tournament_id = dt.tournament_id
    WHERE dt.tournament_id IS NULL OR dt.num_matches != m.matches_count OR dt.num_teams != t.teams_count
    ORDER BY m.tournament_id;

    DECLARE @missing_rows INT = @@ROWCOUNT;

    -- 1) population must be positive
    SELECT match_country_id, year_id, dc.country_name, stage, population
    FROM fact_wc_match fm
    JOIN dim_country dc ON fm.team_country_id = dc.country_id
    WHERE dc.country_name != 'North Korea' AND (population IS NULL OR population <= 0)
    ORDER BY team_country_id;

    DECLARE @population_issues INT = @@ROWCOUNT;

    -- 2) gdp must be positive
    SELECT match_country_id, year_id, dc.country_name, stage, gdp_per_capita_usd
    FROM fact_wc_match fm
    JOIN dim_country dc ON fm.team_country_id = dc.country_id
    WHERE dc.country_name != 'North Korea' AND (gdp_per_capita_usd IS NULL OR gdp_per_capita_usd <= 0)
    ORDER BY team_country_id;

    DECLARE @gdp_issues INT = @@ROWCOUNT;

    -- 3) performance_stars between 1 and 6 (inclusive)
    SELECT match_country_id, year_id, team_country_id, stage, performance_stars
    FROM fact_wc_match
    WHERE performance_stars IS NULL
         OR performance_stars < 1
         OR performance_stars > 6
    ORDER BY team_country_id;

    -- 4) is_host must be 0 or 1
    SELECT match_country_id, year_id, team_country_id, stage, is_host
    FROM fact_wc_match
    WHERE is_host NOT IN (0,1)
         OR is_host IS NULL
    ORDER BY team_country_id;

    -- 5) Cross-check: all team_ids referenced in fact_wc_matches exist in dim_country
    SELECT DISTINCT fm.team_country_id
    FROM fact_wc_match fm
    LEFT JOIN dim_country dc ON fm.team_country_id = dc.country_id
    WHERE dc.country_id IS NULL;

    -- 6) Each tournament_id belongs to only one year_id
    SELECT *
    FROM (
        SELECT tournament_id, RANK() OVER(PARTITION BY tournament_id ORDER BY year_id) as year_rank
        FROM fact_wc_match
    )t
    WHERE year_rank > 1

    DECLARE @tournament_year_issue INT = @@ROWCOUNT;

    -- 7) 6 unique tournament_id
    DECLARE @unique_tournament_id INT = (SELECT COUNT(DISTINCT tournament_id) FROM fact_wc_match);

    -- Validation Summary
    DECLARE @performance_issues INT = (SELECT COUNT(*) FROM fact_wc_match WHERE performance_stars IS NULL OR performance_stars < 1 OR performance_stars > 6);
    DECLARE @is_host_issues INT = (SELECT COUNT(*) FROM fact_wc_match WHERE is_host NOT IN (0,1) OR is_host IS NULL);
    DECLARE @team_exists_issues INT = (SELECT COUNT(DISTINCT fm.team_country_id) FROM fact_wc_match fm LEFT JOIN dim_country dc ON fm.team_country_id = dc.country_id WHERE dc.country_id IS NULL);
    DECLARE @validation_status VARCHAR(20) = CASE WHEN @population_issues + @gdp_issues + @performance_issues + @is_host_issues + @team_exists_issues + @tournament_year_issue > 0 THEN 'FAIL' ELSE 'PASS' END;

    DROP TABLE IF EXISTS validation_summary;
    CREATE TABLE validation_summary (
        validation_id INT IDENTITY(1,1) PRIMARY KEY,
        validation_type VARCHAR(100),
        validation_issues_count INT
    );

    INSERT INTO validation_summary (validation_type, validation_issues_count)
    VALUES
    ('Missing Matches/Teams per Tournament', @missing_rows),
    ('Population Issues', @population_issues),
    ('GDP Issues', @gdp_issues),
    ('Performance Stars Issues', @performance_issues),
    ('Is Host Issues', @is_host_issues),
    ('Team Exists Issues', @team_exists_issues),
    ('Tournament in more than on year', @tournament_year_issue),
    ('Number of different tournaments', @unique_tournament_id);

    INSERT INTO etl_golden_logs (table_name, columns, foreign_keys, log_timestamp, status)
    VALUES (
        'validation_summary',
        'validation_type, validation_issues_count',
        'fact_wc_match, dim_country, dim_tournament',
        GETDATE(),
        @validation_status
    );
END;
GO