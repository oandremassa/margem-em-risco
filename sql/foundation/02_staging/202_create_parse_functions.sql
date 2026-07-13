USE margem_em_risco;
GO

CREATE OR ALTER FUNCTION etl.fn_parse_decimal_br
(
    @value NVARCHAR(100)
)
RETURNS DECIMAL(18,4)
AS
BEGIN
    DECLARE @clean NVARCHAR(100) = LTRIM(RTRIM(@value));
    DECLARE @last_dot INT;

    IF @clean IS NULL OR @clean = N''
        RETURN NULL;

    SET @clean = REPLACE(@clean, N'R$', N'');
    SET @clean = REPLACE(@clean, N'%', N'');
    SET @clean = REPLACE(@clean, N' ', N'');

    IF CHARINDEX(N',', @clean) > 0
    BEGIN
        SET @clean = REPLACE(@clean, N'.', N'');
        SET @clean = REPLACE(@clean, N',', N'.');
    END
    ELSE IF CHARINDEX(N'.', @clean) > 0
    BEGIN
        SET @last_dot = LEN(@clean) - CHARINDEX(N'.', REVERSE(@clean)) + 1;

        IF LEN(@clean) - @last_dot = 3
            SET @clean = REPLACE(@clean, N'.', N'');
    END;

    RETURN TRY_CONVERT(DECIMAL(18,4), @clean);
END;
GO

CREATE OR ALTER FUNCTION etl.fn_parse_percent_br
(
    @value NVARCHAR(100)
)
RETURNS DECIMAL(9,4)
AS
BEGIN
    DECLARE @parsed DECIMAL(18,4) = etl.fn_parse_decimal_br(@value);

    IF @parsed IS NULL
        RETURN NULL;

    IF @parsed > 1
        SET @parsed = @parsed / 100.0;

    RETURN TRY_CONVERT(DECIMAL(9,4), @parsed);
END;
GO

CREATE OR ALTER FUNCTION etl.fn_parse_date_br
(
    @value NVARCHAR(50)
)
RETURNS DATE
AS
BEGIN
    DECLARE @clean NVARCHAR(50) = LTRIM(RTRIM(@value));
    DECLARE @result DATE;

    IF @clean IS NULL OR @clean = N''
        RETURN NULL;

    SET @result = TRY_CONVERT(DATE, @clean, 103);

    IF @result IS NULL
        SET @result = TRY_CONVERT(DATE, @clean, 23);

    IF @result IS NULL
        SET @result = TRY_CONVERT(DATE, @clean, 120);

    RETURN @result;
END;
GO

CREATE OR ALTER FUNCTION etl.fn_parse_month_br
(
    @value NVARCHAR(50)
)
RETURNS DATE
AS
BEGIN
    DECLARE @clean NVARCHAR(50) = LTRIM(RTRIM(@value));
    DECLARE @parsed DATE;
    DECLARE @month_number INT;
    DECLARE @year_number INT;

    IF @clean IS NULL OR @clean = N''
        RETURN NULL;

    IF LEN(@clean) = 7 AND SUBSTRING(@clean, 3, 1) = N'/'
    BEGIN
        SET @month_number = TRY_CONVERT(INT, LEFT(@clean, 2));
        SET @year_number = TRY_CONVERT(INT, RIGHT(@clean, 4));

        IF @month_number BETWEEN 1 AND 12 AND @year_number BETWEEN 2000 AND 2100
            RETURN DATEFROMPARTS(@year_number, @month_number, 1);
    END;

    IF LEN(@clean) = 7 AND SUBSTRING(@clean, 5, 1) = N'-'
    BEGIN
        SET @parsed = TRY_CONVERT(DATE, @clean + N'-01', 23);

        IF @parsed IS NOT NULL
            RETURN @parsed;
    END;

    SET @parsed = etl.fn_parse_date_br(@clean);

    IF @parsed IS NULL
        RETURN NULL;

    RETURN DATEFROMPARTS(YEAR(@parsed), MONTH(@parsed), 1);
END;
GO

CREATE OR ALTER FUNCTION etl.fn_parse_datetime_br
(
    @value NVARCHAR(50)
)
RETURNS DATETIME2(0)
AS
BEGIN
    DECLARE @clean NVARCHAR(50) = LTRIM(RTRIM(@value));
    DECLARE @result DATETIME2(0);

    IF @clean IS NULL OR @clean = N''
        RETURN NULL;

    SET @result = TRY_CONVERT(DATETIME2(0), @clean, 103);

    IF @result IS NULL
        SET @result = TRY_CONVERT(DATETIME2(0), @clean, 120);

    IF @result IS NULL
        SET @result = TRY_CONVERT(DATETIME2(0), @clean, 126);

    RETURN @result;
END;
GO

CREATE OR ALTER FUNCTION etl.fn_parse_bit_pt
(
    @value NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    DECLARE @clean NVARCHAR(50) =
        UPPER(LTRIM(RTRIM(@value))) COLLATE Latin1_General_100_CI_AI;

    IF @clean IS NULL OR @clean = N''
        RETURN NULL;

    IF @clean IN (N'1', N'S', N'SIM', N'Y', N'YES', N'TRUE')
       OR LEFT(@clean, 1) IN (N'S', N'Y', N'T')
        RETURN 1;

    IF @clean IN (N'0', N'N', N'NAO', N'NO', N'FALSE')
       OR LEFT(@clean, 1) IN (N'N', N'F')
        RETURN 0;

    RETURN NULL;
END;
GO
