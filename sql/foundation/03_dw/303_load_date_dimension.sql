USE margem_em_risco;
GO

SET NOCOUNT ON;

DECLARE @start_date DATE = '2023-01-01';
DECLARE @end_date   DATE = '2027-12-31';

;WITH date_series AS
(
    SELECT @start_date AS full_date

    UNION ALL

    SELECT DATEADD(DAY, 1, full_date)
    FROM date_series
    WHERE full_date < @end_date
)
INSERT INTO dw.dim_date
(
    date_key,
    full_date,
    day_number,
    month_number,
    month_name_pt,
    quarter_number,
    year_number,
    year_month,
    month_start_date,
    month_end_date,
    is_weekend
)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), full_date, 112)),
    full_date,
    DAY(full_date),
    MONTH(full_date),
    CASE MONTH(full_date)
        WHEN 1 THEN 'Janeiro'
        WHEN 2 THEN 'Fevereiro'
        WHEN 3 THEN 'Março'
        WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Maio'
        WHEN 6 THEN 'Junho'
        WHEN 7 THEN 'Julho'
        WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Setembro'
        WHEN 10 THEN 'Outubro'
        WHEN 11 THEN 'Novembro'
        WHEN 12 THEN 'Dezembro'
    END,
    DATEPART(QUARTER, full_date),
    YEAR(full_date),
    CONVERT(CHAR(7), full_date, 120),
    DATEFROMPARTS(YEAR(full_date), MONTH(full_date), 1),
    EOMONTH(full_date),
    CASE WHEN DATEDIFF(DAY, '19000101', full_date) % 7 IN (5, 6) THEN 1 ELSE 0 END
FROM date_series AS source_date
WHERE NOT EXISTS
(
    SELECT 1
    FROM dw.dim_date AS target_date
    WHERE target_date.full_date = source_date.full_date
)
OPTION (MAXRECURSION 0);
GO
