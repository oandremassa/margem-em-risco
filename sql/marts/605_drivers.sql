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

PRINT N'Criando camada materializada: fatores de risco';
GO

CREATE OR ALTER VIEW mart.calc_contract_risk_drivers
AS
WITH loss AS
(
    SELECT
        reference_month,
        contract_key,
        SUM(CASE WHEN loss_code = 'OVERTIME_EXCESS' THEN loss_amount ELSE 0 END) AS overtime_loss,
        SUM(CASE WHEN loss_code = 'EMERGENCY_COVERAGE_EXCESS' THEN loss_amount ELSE 0 END) AS coverage_loss,
        SUM(CASE WHEN loss_code = 'SLA_FINANCIAL_LOSS' THEN loss_amount ELSE 0 END) AS sla_loss,
        SUM(CASE WHEN loss_code = 'ADJUSTMENT_DELAY_ESTIMATE' THEN loss_amount ELSE 0 END) AS adjustment_loss,
        SUM(CASE WHEN loss_code = 'UNBILLED_SCOPE_ESTIMATE' THEN loss_amount ELSE 0 END) AS scope_loss,
        SUM(CASE WHEN loss_code = 'COMMERCIAL_DISCOUNT' THEN loss_amount ELSE 0 END) AS discount_loss
    FROM mart.vw_margin_loss_bridge
    GROUP BY
        reference_month,
        contract_key
),
risk_parameterized AS
(
    SELECT
        risk.*,
        parameter.margin_gap_warn,
        parameter.extra_cost_warn,
        parameter.overtime_warn,
        parameter.coverage_warn,
        parameter.scope_overrun_warn,
        parameter.sla_target,
        parameter.adjustment_warn_days,
        parameter.renewal_warn_days,
        parameter.absence_warn,
        parameter.vacancy_warn,
        parameter.replacement_warn_days,
        COALESCE(loss.overtime_loss, 0) AS overtime_loss,
        COALESCE(loss.coverage_loss, 0) AS coverage_loss,
        COALESCE(loss.sla_loss, 0) AS sla_loss,
        COALESCE(loss.adjustment_loss, 0) AS adjustment_loss,
        COALESCE(loss.scope_loss, 0) AS scope_loss,
        COALESCE(loss.discount_loss, 0) AS discount_loss
    FROM mart.vw_contract_risk_score AS risk
    CROSS JOIN config.vw_current_risk_parameters AS parameter
    LEFT JOIN loss
        ON loss.reference_month = risk.reference_month
       AND loss.contract_key = risk.contract_key
),
driver_source AS
(
    SELECT
        reference_month,
        date_key,
        contract_key,
        contract_code,
        'FINANCIAL' AS risk_pillar,
        'MARGIN_GAP' AS driver_code,
        N'Desvio da margem' AS driver_name_pt,
        margin_gap_pct AS observed_value,
        -margin_gap_warn AS reference_value,
        score_margin_gap AS driver_score,
        margin_leakage_amount AS estimated_impact_amount
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'FINANCIAL', 'EXTRAORDINARY_COST', N'Custos extraordinários',
        extraordinary_cost_rate, extra_cost_warn, score_extraordinary_cost, extraordinary_cost
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'OPERATIONAL', 'OVERTIME', N'Horas adicionais',
        overtime_rate, overtime_warn, score_overtime, overtime_loss
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'OPERATIONAL', 'COVERAGE', N'Cobertura de postos',
        coverage_rate, coverage_warn, score_coverage, coverage_loss
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'OPERATIONAL', 'SCOPE_OVERRUN', N'Execução acima do contratado',
        execution_overrun_rate, scope_overrun_warn, score_scope_overrun, scope_loss
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'QUALITY', 'SLA_COMPLIANCE', N'Cumprimento de SLA',
        sla_compliance_rate, sla_target, score_sla_compliance, sla_loss
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'QUALITY', 'CRITICAL_INCIDENTS', N'Ocorrências críticas',
        CONVERT(DECIMAL(18,4), critical_incident_count), 0, score_critical_incidents, sla_loss
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'QUALITY', 'RECURRENCE', N'Reincidência de ocorrências',
        recurrence_rate, 0, score_recurrence, sla_loss
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'CONTRACTUAL', 'ADJUSTMENT_DELAY', N'Reajuste pendente',
        CONVERT(DECIMAL(18,4), adjustment_overdue_days), adjustment_warn_days, score_adjustment_delay, adjustment_loss
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'CONTRACTUAL', 'RENEWAL_PROXIMITY', N'Renovação próxima',
        CONVERT(DECIMAL(18,4), days_to_renewal), renewal_warn_days, score_renewal_proximity, 0
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'CONTRACTUAL', 'COMMERCIAL_DISCOUNT', N'Descontos comerciais',
        commercial_discount_rate, 0, score_commercial_discount, discount_loss
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'PEOPLE', 'ABSENTEEISM', N'Absenteísmo',
        absenteeism_rate, absence_warn, score_absenteeism, coverage_loss
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'PEOPLE', 'VACANCIES', N'Vagas abertas',
        vacancy_rate, vacancy_warn, score_vacancies, coverage_loss
    FROM risk_parameterized

    UNION ALL

    SELECT reference_month, date_key, contract_key, contract_code,
        'PEOPLE', 'REPLACEMENT_TIME', N'Tempo de reposição',
        average_replacement_days, replacement_warn_days, score_replacement_time, coverage_loss
    FROM risk_parameterized
),
ranked AS
(
    SELECT
        driver_source.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY driver_source.reference_month, driver_source.contract_key
            ORDER BY
                driver_source.driver_score DESC,
                driver_source.estimated_impact_amount DESC,
                driver_source.driver_code
        ) AS driver_rank
    FROM driver_source
    WHERE driver_source.driver_score > 0
)
SELECT
    reference_month,
    date_key,
    contract_key,
    contract_code,
    risk_pillar,
    driver_code,
    driver_name_pt,
    observed_value,
    reference_value,
    driver_score,
    estimated_impact_amount,
    driver_rank
FROM ranked;
GO


SELECT TOP (0) *
INTO mart.contract_risk_drivers_data
FROM mart.calc_contract_risk_drivers;
GO

INSERT INTO mart.contract_risk_drivers_data
SELECT *
FROM mart.calc_contract_risk_drivers;
GO

CREATE UNIQUE CLUSTERED INDEX CIX_contract_risk_drivers_data
ON mart.contract_risk_drivers_data (date_key, contract_key, driver_code);
GO

CREATE OR ALTER VIEW mart.vw_contract_risk_drivers
AS
SELECT *
FROM mart.contract_risk_drivers_data;
GO

IF NOT EXISTS (SELECT 1 FROM mart.contract_risk_drivers_data)
    THROW 51515, 'Os fatores de risco ficaram vazios.', 1;
GO

PRINT N'Camada concluida: fatores de risco';
GO
