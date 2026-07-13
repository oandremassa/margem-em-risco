USE margem_em_risco;
GO

SET NOCOUNT ON;
GO

DECLARE @tests TABLE
(
    test_name NVARCHAR(160) NOT NULL,
    expected_value INT NOT NULL,
    actual_value INT NOT NULL,
    passed BIT NOT NULL
);

INSERT INTO @tests
SELECT
    N'Portfólio atual contém 10 contratos',
    10,
    COUNT(*),
    IIF(COUNT(*) = 10, 1, 0)
FROM bi.vw_portfolio_atual;

INSERT INTO @tests
SELECT
    N'Histórico possui 24 competências',
    24,
    COUNT(DISTINCT mes_referencia),
    IIF(COUNT(DISTINCT mes_referencia) = 24, 1, 0)
FROM bi.vw_desempenho_mensal;

INSERT INTO @tests
SELECT
    N'Histórico possui 240 linhas contrato-mês',
    240,
    COUNT(*),
    IIF(COUNT(*) = 240, 1, 0)
FROM bi.vw_desempenho_mensal;

INSERT INTO @tests
SELECT
    N'Fila atual contém um registro por contrato',
    10,
    COUNT(*),
    IIF(COUNT(*) = 10, 1, 0)
FROM bi.vw_fila_acoes;

INSERT INTO @tests
SELECT
    N'Resumo executivo possui 24 competências',
    24,
    COUNT(*),
    IIF(COUNT(*) = 24, 1, 0)
FROM bi.vw_resumo_executivo;

INSERT INTO @tests
SELECT
    N'Calendário cobre julho de 2024 a junho de 2026',
    730,
    COUNT(*),
    IIF(COUNT(*) = 730, 1, 0)
FROM bi.vw_calendario
WHERE data BETWEEN '2024-07-01' AND '2026-06-30';

INSERT INTO @tests
SELECT
    N'Join entre desempenho e risco não duplicou contrato-mês',
    240,
    COUNT(DISTINCT CONCAT(CONVERT(CHAR(8), chave_data), '|', chave_contrato)),
    IIF
    (
        COUNT(*) = 240
        AND COUNT(DISTINCT CONCAT(CONVERT(CHAR(8), chave_data), '|', chave_contrato)) = 240,
        1,
        0
    )
FROM bi.vw_desempenho_mensal;

SELECT
    test_name,
    expected_value,
    actual_value,
    passed
FROM @tests
ORDER BY test_name;

IF EXISTS
(
    SELECT 1
    FROM @tests
    WHERE passed = 0
)
BEGIN
    THROW 51700, N'A camada de consumo do Power BI falhou em um ou mais testes.', 1;
END;

PRINT N'Camada de consumo do Power BI validada.';
GO
