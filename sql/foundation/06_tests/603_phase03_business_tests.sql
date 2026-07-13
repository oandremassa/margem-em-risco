USE margem_em_risco;
GO

SET NOCOUNT ON;
GO

DELETE FROM etl.test_result
WHERE test_group = 'PHASE_03';
GO

DECLARE @actual_int INT;
DECLARE @actual_decimal DECIMAL(18,4);
DECLARE @actual_text VARCHAR(100);

SELECT @actual_decimal = SUM(parameter_value)
FROM config.risk_parameter
WHERE parameter_code IN
(
    'WEIGHT_FINANCIAL',
    'WEIGHT_OPERATIONAL',
    'WEIGHT_QUALITY',
    'WEIGHT_CONTRACTUAL',
    'WEIGHT_PEOPLE'
);

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('Pesos do indice somam 100%', 'PHASE_03', '1.0000', CONVERT(VARCHAR(100), @actual_decimal),
 CASE WHEN @actual_decimal = 1.0000 THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*)
FROM mart.vw_contract_risk_score
WHERE reference_month = '2025-01-01';

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('Score calculado para os contratos da carga inicial', 'PHASE_03', '10', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 10 THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*)
FROM mart.vw_contract_risk_score
WHERE contract_risk_score < 0
   OR contract_risk_score > 100;

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('Scores dentro da faixa de 0 a 100', 'PHASE_03', '0', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 0 THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*)
FROM mart.vw_margin_loss_bridge
WHERE loss_amount <= 0
   OR recoverable_amount < 0
   OR recoverable_amount > loss_amount;

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('Perdas e valores recuperaveis consistentes', 'PHASE_03', '0', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 0 THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*)
FROM mart.vw_action_priority_queue;

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('Fila atual possui um registro por contrato', 'PHASE_03', '10', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 10 THEN 1 ELSE 0 END, NULL);

SELECT @actual_int = COUNT(*)
FROM
(
    SELECT contract_key
    FROM mart.vw_action_priority_queue
    GROUP BY contract_key
    HAVING COUNT(*) > 1
) AS duplicated;

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('Fila atual sem contratos duplicados', 'PHASE_03', '0', CONVERT(VARCHAR(100), @actual_int),
 CASE WHEN @actual_int = 0 THEN 1 ELSE 0 END, NULL);

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-001';

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('CT-001 prioriza cobertura', 'PHASE_03', 'REINFORCE_COVERAGE', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'REINFORCE_COVERAGE' THEN 1 ELSE 0 END, NULL);

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-002';

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('CT-002 cobra retroatividade', 'PHASE_03', 'REVIEW_RETROACTIVE', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'REVIEW_RETROACTIVE' THEN 1 ELSE 0 END, NULL);

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-003';

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('CT-003 formaliza escopo adicional', 'PHASE_03', 'FORMALIZE_SCOPE', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'FORMALIZE_SCOPE' THEN 1 ELSE 0 END, NULL);

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-004';

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('CT-004 recebe plano de recuperacao de SLA', 'PHASE_03', 'SLA_RECOVERY_PLAN', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'SLA_RECOVERY_PLAN' THEN 1 ELSE 0 END, NULL);

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-005';

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('CT-005 passa por avaliacao de nao renovacao', 'PHASE_03', 'ASSESS_NON_RENEWAL', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'ASSESS_NON_RENEWAL' THEN 1 ELSE 0 END, NULL);

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-007';

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('CT-007 aparece como oportunidade de expansao', 'PHASE_03', 'EXPAND', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'EXPAND' THEN 1 ELSE 0 END, NULL);

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-008';

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('CT-008 prioriza reajuste pendente', 'PHASE_03', 'REQUEST_ADJUSTMENT', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'REQUEST_ADJUSTMENT' THEN 1 ELSE 0 END, NULL);

SET @actual_text = NULL;
SELECT @actual_text = recommended_action_code
FROM mart.vw_action_priority_queue
WHERE contract_code = 'CT-009';

INSERT INTO etl.test_result
(test_name, test_group, expected_result, actual_result, passed, details)
VALUES
('CT-009 recebe reforco de cobertura', 'PHASE_03', 'REINFORCE_COVERAGE', COALESCE(@actual_text, 'NULL'),
 CASE WHEN @actual_text = 'REINFORCE_COVERAGE' THEN 1 ELSE 0 END, NULL);

SELECT
    test_name,
    expected_result,
    actual_result,
    passed,
    details
FROM etl.test_result
WHERE test_group = 'PHASE_03'
ORDER BY test_result_id;

IF EXISTS
(
    SELECT 1
    FROM etl.test_result
    WHERE test_group = 'PHASE_03'
      AND passed = 0
)
BEGIN
    THROW 51020, 'A Fase 03 foi criada, mas um ou mais testes de negocio falharam.', 1;
END;
GO
