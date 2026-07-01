
DROP TABLE IF EXISTS fact_wc_match;
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'etl_golden_logs')
BEGIN
    CREATE TABLE etl_golden_logs (
        log_id INT IDENTITY(1,1) PRIMARY KEY,
        table_name VARCHAR(100),
        columns VARCHAR(MAX),
        foreign_keys VARCHAR(MAX),
        log_timestamp DATETIME,
        status VARCHAR(50)
    );
END;
GO

EXEC usp_create_dim_tables;
EXEC usp_create_fact_wc_match;
GO