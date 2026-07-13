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

IF SCHEMA_ID(N'seed') IS NULL
    EXEC(N'CREATE SCHEMA seed AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'seed.cost_template', N'U') IS NULL
BEGIN
    CREATE TABLE seed.cost_template
    (
        contract_code          VARCHAR(20) NOT NULL,
        unit_key               INT NOT NULL,
        cost_category_key      INT NOT NULL,
        baseline_budget_amount DECIMAL(18,2) NOT NULL,
        source_system          VARCHAR(30) NOT NULL,
        is_recurring           BIT NOT NULL,
        is_extraordinary       BIT NOT NULL,
        is_allocation          BIT NOT NULL,

        CONSTRAINT PK_seed_cost_template
            PRIMARY KEY (contract_code, unit_key, cost_category_key)
    );
END;
GO

IF OBJECT_ID(N'seed.operation_template', N'U') IS NULL
BEGIN
    CREATE TABLE seed.operation_template
    (
        contract_code                    VARCHAR(20) NOT NULL,
        unit_key                         INT NOT NULL,
        role_key                         INT NOT NULL,
        baseline_planned_positions       DECIMAL(10,2) NOT NULL,
        baseline_planned_hours           DECIMAL(18,2) NOT NULL,
        baseline_emergency_coverage_cost DECIMAL(18,2) NOT NULL,

        CONSTRAINT PK_seed_operation_template
            PRIMARY KEY (contract_code, unit_key, role_key)
    );
END;
GO

IF OBJECT_ID(N'seed.contract_profile', N'U') IS NULL
BEGIN
    CREATE TABLE seed.contract_profile
    (
        contract_code               VARCHAR(20) NOT NULL,
        unit_key                    INT NOT NULL,
        normal_cost_factor          DECIMAL(9,4) NOT NULL,
        primary_incident_type_key   INT NOT NULL,
        secondary_incident_type_key INT NOT NULL,
        scenario_code               VARCHAR(40) NOT NULL,
        scenario_note               NVARCHAR(500) NOT NULL,

        CONSTRAINT PK_seed_contract_profile
            PRIMARY KEY (contract_code),
        CONSTRAINT CK_seed_profile_cost_factor
            CHECK (normal_cost_factor BETWEEN 0.5000 AND 2.0000)
    );
END;
GO

IF OBJECT_ID(N'seed.contract_month_plan', N'U') IS NULL
BEGIN
    CREATE TABLE seed.contract_month_plan
    (
        reference_month             DATE NOT NULL,
        contract_code               VARCHAR(20) NOT NULL,
        contracted_amount           DECIMAL(18,2) NOT NULL,
        additional_services         DECIMAL(18,2) NOT NULL,
        reimbursements              DECIMAL(18,2) NOT NULL,
        commercial_discount_rate    DECIMAL(9,4) NOT NULL,
        base_cost_factor            DECIMAL(9,4) NOT NULL,
        labor_factor                DECIMAL(9,4) NOT NULL,
        overtime_factor             DECIMAL(9,4) NOT NULL,
        coverage_factor             DECIMAL(9,4) NOT NULL,
        material_factor             DECIMAL(9,4) NOT NULL,
        other_cost_factor           DECIMAL(9,4) NOT NULL,
        position_factor             DECIMAL(9,4) NOT NULL,
        coverage_rate               DECIMAL(9,4) NOT NULL,
        overtime_rate               DECIMAL(9,4) NOT NULL,
        absenteeism_rate            DECIMAL(9,4) NOT NULL,
        vacancy_rate                DECIMAL(9,4) NOT NULL,
        replacement_days            DECIMAL(10,2) NOT NULL,
        execution_overrun_rate      DECIMAL(9,4) NOT NULL,
        incident_count              INT NOT NULL,
        critical_incident_count     INT NOT NULL,
        recurrent_incident_count    INT NOT NULL,
        sla_miss_count              INT NOT NULL,
        sla_financial_loss          DECIMAL(18,2) NOT NULL,
        one_time_extra_cost         DECIMAL(18,2) NOT NULL,
        event_code                  VARCHAR(50) NOT NULL,
        event_note                  NVARCHAR(500) NOT NULL,

        CONSTRAINT PK_seed_contract_month_plan
            PRIMARY KEY (reference_month, contract_code),
        CONSTRAINT CK_seed_plan_rates CHECK
        (
            commercial_discount_rate BETWEEN 0 AND 1
            AND coverage_rate BETWEEN 0 AND 1
            AND overtime_rate BETWEEN 0 AND 1
            AND absenteeism_rate BETWEEN 0 AND 1
            AND vacancy_rate BETWEEN 0 AND 1
            AND execution_overrun_rate BETWEEN 0 AND 1
        ),
        CONSTRAINT CK_seed_plan_counts CHECK
        (
            incident_count >= 0
            AND critical_incident_count BETWEEN 0 AND incident_count
            AND recurrent_incident_count BETWEEN 0 AND incident_count
            AND sla_miss_count BETWEEN 0 AND incident_count
        )
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM seed.cost_template)
BEGIN
    DECLARE @baseline_cost_date_key INT =
    (
        SELECT MIN(date_key)
        FROM dw.fact_contract_cost
    );

    INSERT INTO seed.cost_template
    (
        contract_code,
        unit_key,
        cost_category_key,
        baseline_budget_amount,
        source_system,
        is_recurring,
        is_extraordinary,
        is_allocation
    )
    SELECT
        contract.contract_code,
        cost.unit_key,
        cost.cost_category_key,
        COALESCE(cost.budget_amount, ABS(cost.actual_amount)),
        cost.source_system,
        cost.is_recurring,
        cost.is_extraordinary,
        cost.is_allocation
    FROM dw.fact_contract_cost AS cost
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_key = cost.contract_key
    WHERE cost.date_key = @baseline_cost_date_key;
END;
GO

IF NOT EXISTS (SELECT 1 FROM seed.operation_template)
BEGIN
    DECLARE @baseline_operation_date_key INT =
    (
        SELECT MIN(date_key)
        FROM dw.fact_operation
    );

    INSERT INTO seed.operation_template
    (
        contract_code,
        unit_key,
        role_key,
        baseline_planned_positions,
        baseline_planned_hours,
        baseline_emergency_coverage_cost
    )
    SELECT
        contract.contract_code,
        operation.unit_key,
        operation.role_key,
        operation.planned_positions,
        operation.planned_hours,
        operation.emergency_coverage_cost
    FROM dw.fact_operation AS operation
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_key = operation.contract_key
    WHERE operation.date_key = @baseline_operation_date_key;
END;
GO

IF (SELECT COUNT(*) FROM seed.cost_template) <> 56
    THROW 51600, N'O modelo de custos deveria conter 56 linhas de referência.', 1;

IF (SELECT COUNT(*) FROM seed.operation_template) <> 21
    THROW 51601, N'O modelo operacional deveria conter 21 linhas de referência.', 1;
GO

TRUNCATE TABLE seed.contract_profile;
GO

INSERT INTO seed.contract_profile
(
    contract_code,
    unit_key,
    normal_cost_factor,
    primary_incident_type_key,
    secondary_incident_type_key,
    scenario_code,
    scenario_note
)
SELECT
    profile.contract_code,
    unit.unit_key,
    profile.normal_cost_factor,
    primary_incident.incident_type_key,
    secondary_incident.incident_type_key,
    profile.scenario_code,
    profile.scenario_note
FROM
(
    VALUES
    ('CT-001', 'U001', CONVERT(DECIMAL(9,4), 1.0000),
        N'Cobertura', N'Posto descoberto', N'Absenteísmo',
        N'Cobertura', N'Atraso na substituição', N'Equipe de cobertura insuficiente',
        'COVERAGE_RECOVERY',
        N'Pressão de cobertura em 2025 e recuperação depois de um plano operacional.'),
    ('CT-002', 'U002', CONVERT(DECIMAL(9,4), 0.9400),
        N'Qualidade', N'Falha de limpeza', N'Procedimento não seguido',
        N'Atendimento', N'Atraso no atendimento', N'Troca de turno',
        'DELAYED_ADJUSTMENT',
        N'Operação estável com reajuste aprovado depois da data prevista.'),
    ('CT-003', 'U003', CONVERT(DECIMAL(9,4), 0.9750),
        N'Escopo', N'Atividade não prevista', N'Solicitação informal do cliente',
        N'Cobertura', N'Posto descoberto', N'Vagas em aberto',
        'SCOPE_FORMALIZATION',
        N'Execução acima do escopo até a formalização comercial no fim de 2025.'),
    ('CT-004', 'U004', CONVERT(DECIMAL(9,4), 1.1000),
        N'Manutenção', N'Atraso no atendimento', N'Escala técnica insuficiente',
        N'SLA', N'Prazo não cumprido', N'Falha de supervisão',
        'SLA_RECOVERY',
        N'Deterioração de SLA em 2025 seguida de plano de recuperação.'),
    ('CT-005', 'U005', CONVERT(DECIMAL(9,4), 1.1800),
        N'Cobertura', N'Posto descoberto', N'Deslocamento entre lojas',
        N'Qualidade', N'Falha de limpeza', N'Equipe incompleta',
        'STRUCTURAL_DEFICIT',
        N'Contrato pulverizado, com descontos e custo de deslocamento acima do preço.'),
    ('CT-006', 'U006', CONVERT(DECIMAL(9,4), 1.0150),
        N'Atendimento', N'Atraso no atendimento', N'Troca de turno',
        N'Manutenção', N'Falha de equipamento', N'Desgaste natural',
        'ONE_OFF_EVENT',
        N'Operação estável com um custo extraordinário isolado em novembro de 2024.'),
    ('CT-007', 'U007', CONVERT(DECIMAL(9,4), 0.9800),
        N'Atendimento', N'Solicitação administrativa', N'Demanda pontual',
        N'Atendimento', N'Atraso no atendimento', N'Pico operacional',
        'HEALTHY_REFERENCE',
        N'Contrato saudável, com expansão de escopo em 2026.'),
    ('CT-008', 'U008', CONVERT(DECIMAL(9,4), 0.9950),
        N'Atendimento', N'Fila na recepção', N'Pico de visitantes',
        N'Atendimento', N'Atraso no atendimento', N'Pico operacional',
        'PENDING_ADJUSTMENT',
        N'Receita sem reajuste enquanto os custos de pessoal avançam.'),
    ('CT-009', 'U009', CONVERT(DECIMAL(9,4), 1.1070),
        N'Cobertura', N'Posto descoberto', N'Vagas em aberto',
        N'Qualidade', N'Falha de limpeza', N'Equipe incompleta',
        'WORKFORCE_WARNING',
        N'Vagas e absenteísmo aparecem antes da perda financeira mais forte.'),
    ('CT-010', 'U010', CONVERT(DECIMAL(9,4), 1.0430),
        N'Manutenção', N'Falha de equipamento', N'Desgaste natural',
        N'Atendimento', N'Atraso no atendimento', N'Pico operacional',
        'STABLE_LARGE_CONTRACT',
        N'Contrato relevante, com repactuação aprovada e operação estável.')
) AS profile
(
    contract_code,
    unit_code,
    normal_cost_factor,
    primary_category,
    primary_subcategory,
    primary_root_cause,
    secondary_category,
    secondary_subcategory,
    secondary_root_cause,
    scenario_code,
    scenario_note
)
INNER JOIN dw.dim_unit AS unit
    ON unit.unit_code = profile.unit_code
INNER JOIN dw.dim_incident_type AS primary_incident
    ON primary_incident.incident_category = profile.primary_category
   AND primary_incident.incident_subcategory = profile.primary_subcategory
   AND primary_incident.root_cause = profile.primary_root_cause
INNER JOIN dw.dim_incident_type AS secondary_incident
    ON secondary_incident.incident_category = profile.secondary_category
   AND secondary_incident.incident_subcategory = profile.secondary_subcategory
   AND secondary_incident.root_cause = profile.secondary_root_cause;
GO

IF (SELECT COUNT(*) FROM seed.contract_profile) <> 10
    THROW 51602, N'Os dez contratos não foram mapeados na tabela de cenários.', 1;
GO
