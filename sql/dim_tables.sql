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
