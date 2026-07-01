
DROP PROCEDURE IF EXISTS usp_create_dim_tables;
GO

CREATE PROCEDURE usp_create_dim_tables
AS
BEGIN
    SET NOCOUNT ON;
    DROP TABLE IF EXISTS fact_x;
    DROP TABLE IF EXISTS dim_date;
    DROP TABLE IF EXISTS dim_country;
    DROP TABLE IF EXISTS dim_tournament;

    CREATE TABLE dim_date (
        year_id INT PRIMARY KEY,
        year INT NOT NULL
    );

    CREATE TABLE dim_country (
        country_id INT PRIMARY KEY,
        country_name VARCHAR(50),
        confederation VARCHAR(50)
    );

    CREATE TABLE dim_tournament (
        tournament_id INT PRIMARY KEY,
        tournament_name VARCHAR(50),
        num_matches INT,
        num_teams INT
    );

    -- Summary Log
    INSERT INTO etl_golden_logs (table_name, columns, foreign_keys, log_timestamp, status)
    VALUES (
        'dim_date, dim_country, dim_tournament',
        'year_id, year, country_id, country_name, confederation, tournament_id, tournament_name, num_matches, num_teams',
        'N/A',
        GETDATE(),
        'CREATED'
    );  
END;
