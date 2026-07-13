USE margem_em_risco;
GO

SET NOCOUNT ON;

DELETE FROM etl.test_result
WHERE test_group = 'PHASE_02';

DECLARE @actual_int INT;
DECLARE @actual_decimal DECIMAL(18,4);

SELECT @actual_int = COUNT(*)
FROM dw.dim_date
WHERE full_date BETWEEN '2023-01-01' AND '2027-12-31';

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('Dimensão de datas carregada', 'PHASE_02', '1826', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 1826 THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*) FROM dw.dim_client WHERE client_status = 'ACTIVE';
INSERT INTO etl.test_result VALUES
(NULL, 'Clientes mestres carregados', 'PHASE_02', '8', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 8 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT @actual_int = COUNT(*) FROM dw.dim_service WHERE service_status = 'ACTIVE';
INSERT INTO etl.test_result VALUES
(NULL, 'Serviços mestres carregados', 'PHASE_02', '6', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 6 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT @actual_int = COUNT(*) FROM dw.dim_contract WHERE is_current = 1;
INSERT INTO etl.test_result VALUES
(NULL, 'Contratos atuais carregados', 'PHASE_02', '10', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 10 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT @actual_int = COUNT(*) FROM dw.fact_revenue WHERE date_key = 20250101;
INSERT INTO etl.test_result VALUES
(NULL, 'Medições válidas de janeiro de 2025', 'PHASE_02', '10', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 10 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT @actual_int = COUNT(*) FROM dw.fact_contract_cost WHERE date_key = 20250101;
INSERT INTO etl.test_result VALUES
(NULL, 'Lançamentos de custo válidos de janeiro de 2025', 'PHASE_02', '56', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 56 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT @actual_int = COUNT(*) FROM dw.fact_operation WHERE date_key = 20250101;
INSERT INTO etl.test_result VALUES
(NULL, 'Registros operacionais válidos de janeiro de 2025', 'PHASE_02', '21', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 21 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT @actual_int = COUNT(*) FROM dw.fact_sla WHERE opened_date_key BETWEEN 20250101 AND 20250131;
INSERT INTO etl.test_result VALUES
(NULL, 'Ocorrências de SLA válidas de janeiro de 2025', 'PHASE_02', '15', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 15 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT @actual_int = COUNT(*) FROM dw.fact_adjustment;
INSERT INTO etl.test_result VALUES
(NULL, 'Processos de reajuste válidos', 'PHASE_02', '5', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 5 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

;WITH latest_batch AS
(
    SELECT
        source_name,
        MAX(batch_id) AS batch_id
    FROM etl.batch_control
    WHERE source_name IN
    (
        'contract_register',
        'monthly_measurements',
        'operational_costs',
        'workforce_control',
        'sla_incidents',
        'contract_adjustments'
    )
    GROUP BY source_name
)
SELECT @actual_int = SUM(batch.rows_rejected)
FROM latest_batch
INNER JOIN etl.batch_control AS batch
    ON batch.batch_id = latest_batch.batch_id;

INSERT INTO etl.test_result VALUES
(NULL, 'Rejeições controladas da carga inicial', 'PHASE_02', '12', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 12 THEN 1 ELSE 0 END, SYSDATETIME(),
 N'Duas linhas inválidas foram incluídas em cada arquivo para testar as regras de qualidade.');

SELECT @actual_decimal = contribution_margin_pct
FROM mart.vw_contract_monthly_base
WHERE contract_code = 'CT-001'
  AND reference_month = '2025-01-01';

INSERT INTO etl.test_result VALUES
(NULL, 'CT-001 com margem inferior a 3%', 'PHASE_02', '< 0.0300', CONVERT(VARCHAR(100), @actual_decimal),
 CASE WHEN @actual_decimal < 0.0300 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT @actual_decimal = contribution_margin
FROM mart.vw_contract_monthly_base
WHERE contract_code = 'CT-005'
  AND reference_month = '2025-01-01';

INSERT INTO etl.test_result VALUES
(NULL, 'CT-005 com margem negativa', 'PHASE_02', '< 0', CONVERT(VARCHAR(100), @actual_decimal),
 CASE WHEN @actual_decimal < 0 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT @actual_decimal = contribution_margin_pct
FROM mart.vw_contract_monthly_base
WHERE contract_code = 'CT-007'
  AND reference_month = '2025-01-01';

INSERT INTO etl.test_result VALUES
(NULL, 'CT-007 como contrato saudável', 'PHASE_02', '> 0.2000', CONVERT(VARCHAR(100), @actual_decimal),
 CASE WHEN @actual_decimal > 0.2000 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT @actual_decimal = revenue_penalties
FROM mart.vw_contract_monthly_base
WHERE contract_code = 'CT-004'
  AND reference_month = '2025-01-01';

INSERT INTO etl.test_result VALUES
(NULL, 'CT-004 com R$ 22 mil em multas', 'PHASE_02', '22000.0000', CONVERT(VARCHAR(100), @actual_decimal),
 CASE WHEN @actual_decimal = 22000.0000 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT @actual_decimal = overtime_rate
FROM mart.vw_contract_monthly_base
WHERE contract_code = 'CT-009'
  AND reference_month = '2025-01-01';

INSERT INTO etl.test_result VALUES
(NULL, 'CT-009 com pressão de horas adicionais', 'PHASE_02', '> 0.0500', CONVERT(VARCHAR(100), @actual_decimal),
 CASE WHEN @actual_decimal > 0.0500 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT @actual_int = COUNT(*)
FROM etl.batch_control
WHERE batch_id IN
(
    SELECT MAX(batch_id)
    FROM etl.batch_control
    WHERE source_name IN
    (
        'contract_register',
        'monthly_measurements',
        'operational_costs',
        'workforce_control',
        'sla_incidents',
        'contract_adjustments'
    )
    GROUP BY source_name
)
AND status NOT IN ('SUCCESS', 'PARTIAL');

INSERT INTO etl.test_result VALUES
(NULL, 'Últimos lotes encerrados sem falha', 'PHASE_02', '0', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 0 THEN 1 ELSE 0 END, SYSDATETIME(), NULL);

SELECT
    test_name,
    expected_result,
    actual_result,
    passed,
    details
FROM etl.test_result
WHERE test_group = 'PHASE_02'
ORDER BY test_result_id;

SELECT
    batch_id,
    source_name,
    source_file,
    reference_period,
    status,
    rows_received,
    rows_loaded,
    rows_rejected,
    error_message
FROM etl.batch_control
WHERE batch_id IN
(
    SELECT MAX(batch_id)
    FROM etl.batch_control
    WHERE source_name IN
    (
        'contract_register',
        'monthly_measurements',
        'operational_costs',
        'workforce_control',
        'sla_incidents',
        'contract_adjustments'
    )
    GROUP BY source_name
)
ORDER BY batch_id;
GO
