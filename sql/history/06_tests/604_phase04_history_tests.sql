USE margem_em_risco;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DELETE FROM etl.test_result
WHERE test_group = 'PHASE_04';
GO

DECLARE @tests TABLE
(
    test_name        VARCHAR(150),
    expected_result  VARCHAR(100),
    actual_result    VARCHAR(100),
    passed           BIT,
    details          NVARCHAR(1000)
);

DECLARE @actual_int INT;
DECLARE @actual_decimal DECIMAL(18,4);
DECLARE @actual_text VARCHAR(100);

SELECT @actual_int = COUNT(*) FROM dw.fact_revenue;
INSERT INTO @tests VALUES
('24 meses de receita', '240', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 240 THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*) FROM dw.fact_contract_cost;
INSERT INTO @tests VALUES
('Custos mensais e evento pontual', '1345', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 1345 THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*) FROM dw.fact_operation;
INSERT INTO @tests VALUES
('Histórico operacional', '504', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 504 THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*) FROM mart.vw_contract_monthly_performance;
INSERT INTO @tests VALUES
('Desempenho mensal materializado', '240', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 240 THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*) FROM mart.vw_contract_risk_score;
INSERT INTO @tests VALUES
('Score mensal materializado', '240', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 240 THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*) FROM mart.vw_executive_summary;
INSERT INTO @tests VALUES
('Resumo executivo por competência', '24', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 24 THEN 1 ELSE 0 END, NULL);

SELECT @actual_text = CONVERT(VARCHAR(10), MAX(reference_month), 23)
FROM mart.vw_executive_summary;
INSERT INTO @tests VALUES
('Última competência', '2026-06-01', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = '2026-06-01' THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*)
FROM mart.vw_contract_risk_score
WHERE reference_month = '2026-06-01'
  AND margin_trend = 'INSUFFICIENT_HISTORY';
INSERT INTO @tests VALUES
('Tendência de três meses disponível', '0', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 0 THEN 1 ELSE 0 END, NULL);

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-002';
INSERT INTO @tests VALUES
('CT-002 sem recomendação já encerrada', 'MAINTAIN', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'MAINTAIN' THEN 1 ELSE 0 END,
 N'A retroatividade foi conferida em fevereiro de 2025.');

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-005';
INSERT INTO @tests VALUES
('CT-005 em avaliação de não renovação', 'ASSESS_NON_RENEWAL', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'ASSESS_NON_RENEWAL' THEN 1 ELSE 0 END, NULL);

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-007';
INSERT INTO @tests VALUES
('CT-007 elegível para expansão', 'EXPAND', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'EXPAND' THEN 1 ELSE 0 END, NULL);

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-008';
INSERT INTO @tests VALUES
('CT-008 com reajuste pendente', 'REQUEST_ADJUSTMENT', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'REQUEST_ADJUSTMENT' THEN 1 ELSE 0 END, NULL);

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-009';
INSERT INTO @tests VALUES
('CT-009 com necessidade de cobertura', 'REINFORCE_COVERAGE', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'REINFORCE_COVERAGE' THEN 1 ELSE 0 END, NULL);

DECLARE @ct001_dec_margin DECIMAL(18,4) =
(
    SELECT contribution_margin_pct
    FROM mart.vw_contract_monthly_performance
    WHERE contract_code = 'CT-001'
      AND reference_month = '2025-12-01'
);

DECLARE @ct001_jun_margin DECIMAL(18,4) =
(
    SELECT contribution_margin_pct
    FROM mart.vw_contract_monthly_performance
    WHERE contract_code = 'CT-001'
      AND reference_month = '2026-06-01'
);

INSERT INTO @tests VALUES
('CT-001 melhora depois da ação',
 'Margem jun/26 maior que dez/25',
 CONCAT
 (
     CONVERT(VARCHAR(30), @ct001_dec_margin),
     ' -> ',
     CONVERT(VARCHAR(30), @ct001_jun_margin)
 ),
 CASE WHEN @ct001_jun_margin > @ct001_dec_margin THEN 1 ELSE 0 END,
 N'Compara o pior trecho com o período posterior ao plano de cobertura.');

DECLARE @ct004_sla_before DECIMAL(18,4) =
(
    SELECT AVG
    (
        CASE
            WHEN incident_count = 0 THEN CONVERT(DECIMAL(18,4), 1.0000)
            ELSE sla_compliance_rate
        END
    )
    FROM mart.vw_contract_monthly_performance
    WHERE contract_code = 'CT-004'
      AND reference_month BETWEEN '2025-01-01' AND '2025-06-01'
);

DECLARE @ct004_sla_after DECIMAL(18,4) =
(
    SELECT AVG
    (
        CASE
            WHEN incident_count = 0 THEN CONVERT(DECIMAL(18,4), 1.0000)
            ELSE sla_compliance_rate
        END
    )
    FROM mart.vw_contract_monthly_performance
    WHERE contract_code = 'CT-004'
      AND reference_month BETWEEN '2026-01-01' AND '2026-06-01'
);

INSERT INTO @tests VALUES
('CT-004 recupera o SLA',
 'SLA 2026 maior que SLA 1º sem/2025',
 CONCAT
 (
     CONVERT(VARCHAR(30), @ct004_sla_before),
     ' -> ',
     CONVERT(VARCHAR(30), @ct004_sla_after)
 ),
 CASE WHEN @ct004_sla_after > @ct004_sla_before THEN 1 ELSE 0 END,
 NULL);

DECLARE @ct003_before DECIMAL(18,2) =
(
    SELECT SUM(unbilled_scope_estimate)
    FROM mart.vw_contract_monthly_performance
    WHERE contract_code = 'CT-003'
      AND reference_month BETWEEN '2025-07-01' AND '2025-11-01'
);

DECLARE @ct003_after DECIMAL(18,2) =
(
    SELECT SUM(additional_services)
    FROM mart.vw_contract_monthly_performance
    WHERE contract_code = 'CT-003'
      AND reference_month BETWEEN '2025-12-01' AND '2026-06-01'
);

INSERT INTO @tests VALUES
('CT-003 formaliza o escopo',
 'Perda estimada antes e receita adicional depois',
 CONCAT
 (
     CONVERT(VARCHAR(30), @ct003_before),
     ' / ',
     CONVERT(VARCHAR(30), @ct003_after)
 ),
 CASE WHEN @ct003_before > 0 AND @ct003_after > 0 THEN 1 ELSE 0 END,
 NULL);

DECLARE @ct006_nov_margin DECIMAL(18,4) =
(
    SELECT contribution_margin_pct
    FROM mart.vw_contract_monthly_performance
    WHERE contract_code = 'CT-006'
      AND reference_month = '2024-11-01'
);

DECLARE @ct006_dec_margin DECIMAL(18,4) =
(
    SELECT contribution_margin_pct
    FROM mart.vw_contract_monthly_performance
    WHERE contract_code = 'CT-006'
      AND reference_month = '2024-12-01'
);

INSERT INTO @tests VALUES
('CT-006 registra evento pontual',
 'Margem dezembro maior que novembro',
 CONCAT
 (
     CONVERT(VARCHAR(30), @ct006_nov_margin),
     ' -> ',
     CONVERT(VARCHAR(30), @ct006_dec_margin)
 ),
 CASE WHEN @ct006_dec_margin > @ct006_nov_margin THEN 1 ELSE 0 END,
 N'O teste evita tratar um custo isolado como deterioração permanente.');

SELECT @actual_int = COUNT(*)
FROM mart.vw_management_action_effect;
INSERT INTO @tests VALUES
('Análise antes e depois', 'Pelo menos 5 ações concluídas', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int >= 5 THEN 1 ELSE 0 END, NULL);

SET @actual_decimal = NULL;
SELECT @actual_decimal = margin_delta_pp
FROM mart.vw_management_action_effect
WHERE contract_code = 'CT-001'
  AND action_code = 'REINFORCE_COVERAGE';
INSERT INTO @tests VALUES
('Efeito da ação no CT-001', 'Delta de margem positivo', COALESCE(CONVERT(VARCHAR(100), @actual_decimal), 'NULL'),
 CASE WHEN @actual_decimal > 0 THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*)
FROM mart.vw_contract_timeline;
INSERT INTO @tests VALUES
('Linha do tempo dos contratos', 'Mais de 20 eventos', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int > 20 THEN 1 ELSE 0 END, NULL);

DECLARE @batch_id INT =
(
    SELECT MAX(batch_id)
    FROM etl.batch_control
    WHERE source_name = 'phase04_revenue_history'
);

INSERT INTO etl.test_result
(
    batch_id,
    test_name,
    test_group,
    expected_result,
    actual_result,
    passed,
    details
)
SELECT
    @batch_id,
    test_name,
    'PHASE_04',
    expected_result,
    actual_result,
    passed,
    details
FROM @tests;

SELECT
    test_name,
    expected_result,
    actual_result,
    passed,
    details
FROM @tests
ORDER BY test_name;

IF EXISTS (SELECT 1 FROM @tests WHERE passed = 0)
    THROW 51640, N'A Fase 04 foi executada, mas existem testes com falha.', 1;
GO
