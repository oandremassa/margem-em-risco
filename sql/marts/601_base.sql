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

PRINT N'Criando camada materializada: base mensal de contratos';
GO

CREATE OR ALTER VIEW mart.calc_contract_monthly_base
AS
WITH revenue AS
(
    SELECT
        date_key,
        contract_key,
        SUM(gross_revenue) AS gross_revenue,
        SUM(net_revenue) AS net_revenue,
        SUM(commercial_discounts) AS commercial_discounts,
        SUM(deductions) AS deductions,
        SUM(penalties) AS revenue_penalties,
        SUM(invoiced_amount) AS invoiced_amount,
        SUM(received_amount) AS received_amount
    FROM dw.fact_revenue
    GROUP BY
        date_key,
        contract_key
),
cost AS
(
    SELECT
        date_key,
        contract_key,
        SUM(actual_amount) AS total_cost,
        SUM(budget_amount) AS budget_cost,
        SUM(CASE WHEN is_extraordinary = 1 THEN actual_amount ELSE 0 END) AS extraordinary_cost
    FROM dw.fact_contract_cost
    GROUP BY
        date_key,
        contract_key
),
operation AS
(
    SELECT
        date_key,
        contract_key,
        SUM(planned_positions) AS planned_positions,
        SUM(filled_positions) AS filled_positions,
        SUM(uncovered_positions) AS uncovered_positions,
        SUM(planned_hours) AS planned_hours,
        SUM(regular_hours) AS regular_hours,
        SUM(overtime_hours) AS overtime_hours,
        SUM(absence_hours) AS absence_hours,
        SUM(open_positions) AS open_positions,
        AVG(average_replacement_days) AS average_replacement_days,
        SUM(emergency_coverage_cost) AS emergency_coverage_cost
    FROM dw.fact_operation
    GROUP BY
        date_key,
        contract_key
),
sla AS
(
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), DATEFROMPARTS(YEAR(opened_at), MONTH(opened_at), 1), 112)) AS date_key,
        contract_key,
        COUNT(*) AS incident_count,
        SUM(CASE WHEN severity = 'CRITICAL' THEN 1 ELSE 0 END) AS critical_incident_count,
        SUM(CASE WHEN resolved_within_sla = 1 THEN 1 ELSE 0 END) AS incidents_within_sla,
        SUM(CASE WHEN is_recurrence = 1 THEN 1 ELSE 0 END) AS recurrent_incident_count,
        SUM(deduction_amount) AS sla_deduction_amount,
        SUM(penalty_amount) AS sla_penalty_amount,
        SUM(emergency_cost) AS sla_emergency_cost
    FROM dw.fact_sla
    GROUP BY
        CONVERT(INT, CONVERT(CHAR(8), DATEFROMPARTS(YEAR(opened_at), MONTH(opened_at), 1), 112)),
        contract_key
),
adjustment AS
(
    SELECT
        contract_key,
        SUM(CASE WHEN process_status IN ('PENDING', 'REQUESTED') THEN 1 ELSE 0 END) AS open_adjustment_count,
        MAX(CASE WHEN process_status IN ('PENDING', 'REQUESTED') THEN expected_date.full_date END) AS latest_open_adjustment_expected_date,
        SUM(CASE WHEN process_status = 'APPROVED' THEN retroactive_amount ELSE 0 END) AS approved_retroactive_amount
    FROM dw.fact_adjustment AS fact_adjustment
    INNER JOIN dw.dim_date AS expected_date
        ON expected_date.date_key = fact_adjustment.expected_date_key
    GROUP BY contract_key
)
SELECT
    date_dim.month_start_date AS reference_month,
    revenue.date_key,
    contract.contract_key,
    contract.contract_code,
    client.client_code,
    client.client_name,
    client.business_segment,
    service.service_code,
    service.service_name,
    manager.manager_code,
    manager.manager_name,
    contract.complexity_level,
    contract.target_margin_pct,
    revenue.gross_revenue,
    revenue.net_revenue,
    COALESCE(cost.total_cost, 0) AS total_cost,
    COALESCE(cost.budget_cost, 0) AS budget_cost,
    COALESCE(cost.extraordinary_cost, 0) AS extraordinary_cost,
    revenue.net_revenue - COALESCE(cost.total_cost, 0) AS contribution_margin,
    CONVERT
    (
        DECIMAL(18,4),
        (revenue.net_revenue - COALESCE(cost.total_cost, 0))
        / NULLIF(revenue.net_revenue, 0)
    ) AS contribution_margin_pct,
    CONVERT
    (
        DECIMAL(18,4),
        (
            (revenue.net_revenue - COALESCE(cost.total_cost, 0))
            / NULLIF(revenue.net_revenue, 0)
        ) - contract.target_margin_pct
    ) AS margin_gap_pct,
    revenue.commercial_discounts,
    revenue.deductions,
    revenue.revenue_penalties,
    revenue.invoiced_amount,
    revenue.received_amount,
    COALESCE(operation.planned_positions, 0) AS planned_positions,
    COALESCE(operation.filled_positions, 0) AS filled_positions,
    COALESCE(operation.uncovered_positions, 0) AS uncovered_positions,
    CONVERT
    (
        DECIMAL(18,4),
        COALESCE(operation.filled_positions, 0)
        / NULLIF(operation.planned_positions, 0)
    ) AS coverage_rate,
    COALESCE(operation.planned_hours, 0) AS planned_hours,
    COALESCE(operation.regular_hours, 0) AS regular_hours,
    COALESCE(operation.overtime_hours, 0) AS overtime_hours,
    CONVERT
    (
        DECIMAL(18,4),
        COALESCE(operation.overtime_hours, 0)
        / NULLIF(operation.regular_hours, 0)
    ) AS overtime_rate,
    COALESCE(operation.absence_hours, 0) AS absence_hours,
    CONVERT
    (
        DECIMAL(18,4),
        COALESCE(operation.absence_hours, 0)
        / NULLIF(operation.planned_hours, 0)
    ) AS absenteeism_rate,
    COALESCE(operation.open_positions, 0) AS open_positions,
    operation.average_replacement_days,
    COALESCE(operation.emergency_coverage_cost, 0) AS emergency_coverage_cost,
    COALESCE(sla.incident_count, 0) AS incident_count,
    COALESCE(sla.critical_incident_count, 0) AS critical_incident_count,
    COALESCE(sla.recurrent_incident_count, 0) AS recurrent_incident_count,
    CONVERT
    (
        DECIMAL(18,4),
        COALESCE(sla.incidents_within_sla, 0)
        / NULLIF(sla.incident_count, 0)
    ) AS sla_compliance_rate,
    COALESCE(sla.sla_deduction_amount, 0) AS sla_deduction_amount,
    COALESCE(sla.sla_penalty_amount, 0) AS sla_penalty_amount,
    COALESCE(sla.sla_emergency_cost, 0) AS sla_emergency_cost,
    COALESCE(adjustment.open_adjustment_count, 0) AS open_adjustment_count,
    adjustment.latest_open_adjustment_expected_date,
    COALESCE(adjustment.approved_retroactive_amount, 0) AS approved_retroactive_amount
FROM revenue
INNER JOIN dw.dim_date AS date_dim
    ON date_dim.date_key = revenue.date_key
INNER JOIN dw.dim_contract AS contract
    ON contract.contract_key = revenue.contract_key
INNER JOIN dw.dim_client AS client
    ON client.client_key = contract.client_key
INNER JOIN dw.dim_service AS service
    ON service.service_key = contract.primary_service_key
INNER JOIN dw.dim_manager AS manager
    ON manager.manager_key = contract.manager_key
LEFT JOIN cost
    ON cost.date_key = revenue.date_key
   AND cost.contract_key = revenue.contract_key
LEFT JOIN operation
    ON operation.date_key = revenue.date_key
   AND operation.contract_key = revenue.contract_key
LEFT JOIN sla
    ON sla.date_key = revenue.date_key
   AND sla.contract_key = revenue.contract_key
LEFT JOIN adjustment
    ON adjustment.contract_key = revenue.contract_key;
GO


SELECT TOP (0) *
INTO mart.contract_monthly_base_data
FROM mart.calc_contract_monthly_base;
GO

INSERT INTO mart.contract_monthly_base_data
SELECT *
FROM mart.calc_contract_monthly_base;
GO

CREATE UNIQUE CLUSTERED INDEX CIX_contract_monthly_base_data
ON mart.contract_monthly_base_data (date_key, contract_key);
GO

CREATE OR ALTER VIEW mart.vw_contract_monthly_base
AS
SELECT *
FROM mart.contract_monthly_base_data;
GO

IF (SELECT COUNT(*) FROM mart.contract_monthly_base_data) <> 10
    THROW 51510, 'Base mensal deveria conter 10 contratos.', 1;
GO

PRINT N'Camada concluida: base mensal de contratos';
GO
