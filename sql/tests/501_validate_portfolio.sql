USE margem_em_risco;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @latest_month DATE =
(
    SELECT MAX(mes_referencia)
    FROM bi.vw_desempenho_mensal
);

IF @latest_month <> '2026-06-01'
    THROW 51901, N'A maior competência deveria ser junho de 2026.', 1;

IF
(
    SELECT COUNT(*)
    FROM bi.vw_calendario
    WHERE data BETWEEN '2024-07-01' AND '2026-06-30'
) <> 730
    THROW 51902, N'O calendário deveria cobrir 730 dias entre julho de 2024 e junho de 2026.', 1;

IF (SELECT COUNT(*) FROM bi.vw_contratos) <> 10
    THROW 51903, N'A dimensão de contratos deveria conter 10 contratos.', 1;

IF (SELECT COUNT(*) FROM bi.vw_desempenho_mensal) <> 240
    THROW 51904, N'O desempenho mensal deveria conter 240 linhas.', 1;

IF EXISTS
(
    SELECT mes_referencia, chave_contrato
    FROM bi.vw_desempenho_mensal
    GROUP BY mes_referencia, chave_contrato
    HAVING COUNT(*) > 1
)
    THROW 51905, N'Existe duplicidade na granularidade contrato e competência.', 1;

IF (SELECT COUNT(*) FROM bi.vw_portfolio_atual) <> 10
    THROW 51906, N'O portfólio atual deveria conter uma linha por contrato.', 1;

IF EXISTS
(
    SELECT 1
    FROM bi.vw_portfolio_atual
    WHERE classe_risco NOT IN (N'Baixo', N'Atenção', N'Alto', N'Crítico')
       OR classe_risco IS NULL
)
    THROW 51907, N'Existe classe de risco nula ou fora do domínio esperado.', 1;

IF EXISTS
(
    SELECT 1
    FROM bi.vw_portfolio_atual
    WHERE margem_pct < -1 OR margem_pct > 1
       OR meta_margem_pct < 0 OR meta_margem_pct > 1
)
    THROW 51908, N'Existe percentual de margem fora do intervalo esperado.', 1;

DECLARE
    @revenue_monthly DECIMAL(18,2),
    @revenue_portfolio DECIMAL(18,2),
    @margin_monthly DECIMAL(18,2),
    @margin_portfolio DECIMAL(18,2);

SELECT
    @revenue_monthly = SUM(receita_liquida),
    @margin_monthly = SUM(margem_contribuicao)
FROM bi.vw_desempenho_mensal
WHERE mes_referencia = @latest_month;

SELECT
    @revenue_portfolio = SUM(receita_liquida),
    @margin_portfolio = SUM(margem_contribuicao)
FROM bi.vw_portfolio_atual;

IF ABS(COALESCE(@revenue_monthly, 0) - COALESCE(@revenue_portfolio, 0)) > 0.01
    THROW 51909, N'A receita do portfólio não concilia com a competência mais recente.', 1;

IF ABS(COALESCE(@margin_monthly, 0) - COALESCE(@margin_portfolio, 0)) > 0.01
    THROW 51910, N'A margem do portfólio não concilia com a competência mais recente.', 1;

IF NOT EXISTS (SELECT 1 FROM bi.vw_fila_acoes)
    THROW 51911, N'A fila de ações está vazia.', 1;

IF NOT EXISTS (SELECT 1 FROM bi.vw_linha_tempo)
    THROW 51912, N'A linha do tempo está vazia.', 1;

IF NOT EXISTS (SELECT 1 FROM bi.vw_efeito_acoes)
    THROW 51913, N'A análise de efeito das ações está vazia.', 1;

SELECT
    N'Competência mais recente' AS verificacao,
    CONVERT(NVARCHAR(30), @latest_month, 23) AS resultado
UNION ALL
SELECT N'Dias no calendário', CONVERT(NVARCHAR(30), COUNT(*))
FROM bi.vw_calendario
UNION ALL
SELECT N'Contratos', CONVERT(NVARCHAR(30), COUNT(*))
FROM bi.vw_contratos
UNION ALL
SELECT N'Linhas contrato-mês', CONVERT(NVARCHAR(30), COUNT(*))
FROM bi.vw_desempenho_mensal
UNION ALL
SELECT N'Eventos na linha do tempo', CONVERT(NVARCHAR(30), COUNT(*))
FROM bi.vw_linha_tempo;

SELECT
    @latest_month AS mes_referencia,
    @revenue_portfolio AS receita_liquida,
    @margin_portfolio AS margem_contribuicao,
    CASE WHEN @revenue_portfolio = 0 THEN NULL
         ELSE @margin_portfolio / @revenue_portfolio END AS margem_pct,
    3 * SUM(CASE WHEN score_risco >= 60 THEN receita_liquida ELSE 0 END)
        AS receita_em_risco_90_dias,
    SUM(CASE WHEN score_risco >= 60 THEN valor_recuperavel ELSE 0 END)
        AS valor_recuperavel
FROM bi.vw_portfolio_atual;

PRINT N'Validação final concluída sem divergências.';
GO

