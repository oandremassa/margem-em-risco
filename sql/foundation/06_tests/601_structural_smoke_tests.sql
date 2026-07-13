USE margem_em_risco;
GO

SET NOCOUNT ON;

DECLARE @results TABLE
(
    test_name       VARCHAR(150) NOT NULL,
    expected_value  INT NOT NULL,
    actual_value    INT NOT NULL,
    passed          BIT NOT NULL
);

INSERT INTO @results (test_name, expected_value, actual_value, passed)
SELECT
    'Schemas obrigatorios',
    5,
    COUNT(*),
    CASE WHEN COUNT(*) = 5 THEN 1 ELSE 0 END
FROM sys.schemas
WHERE name IN ('etl', 'raw', 'staging', 'dw', 'mart');

INSERT INTO @results (test_name, expected_value, actual_value, passed)
SELECT
    'Tabelas de controle ETL',
    3,
    COUNT(*),
    CASE WHEN COUNT(*) = 3 THEN 1 ELSE 0 END
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = 'etl'
  AND t.name IN ('batch_control', 'rejected_record', 'test_result');

INSERT INTO @results (test_name, expected_value, actual_value, passed)
SELECT
    'Tabelas raw principais',
    6,
    COUNT(*),
    CASE WHEN COUNT(*) = 6 THEN 1 ELSE 0 END
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = 'raw'
  AND t.name IN
  (
      'contract_register',
      'monthly_measurements',
      'operational_costs',
      'workforce_control',
      'sla_incidents',
      'contract_adjustments'
  );

INSERT INTO @results (test_name, expected_value, actual_value, passed)
SELECT
    'Dimensoes principais',
    10,
    COUNT(*),
    CASE WHEN COUNT(*) = 10 THEN 1 ELSE 0 END
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = 'dw'
  AND t.name IN
  (
      'dim_date',
      'dim_client',
      'dim_unit',
      'dim_service',
      'dim_role',
      'dim_manager',
      'dim_cost_category',
      'dim_incident_type',
      'dim_action',
      'dim_contract'
  );

INSERT INTO @results (test_name, expected_value, actual_value, passed)
SELECT
    'Tabelas fato',
    6,
    COUNT(*),
    CASE WHEN COUNT(*) = 6 THEN 1 ELSE 0 END
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = 'dw'
  AND t.name IN
  (
      'fact_revenue',
      'fact_contract_cost',
      'fact_operation',
      'fact_sla',
      'fact_adjustment',
      'fact_management_action'
  );

SELECT test_name, expected_value, actual_value, passed
FROM @results
ORDER BY test_name;

IF EXISTS (SELECT 1 FROM @results WHERE passed = 0)
    THROW 51000, 'Falha nos testes estruturais.', 1;
GO
