USE margem_em_risco;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW mart.vw_contract_monthly_performance
AS
WITH revenue_detail AS
(
    SELECT
        date_key,
        contract_key,
        SUM(contracted_amount) AS contracted_amount,
        SUM(additional_services) AS additional_services,
        SUM(reimbursements) AS reimbursements,
        AVG(CONVERT(DECIMAL(18,4), payment_days)) AS average_payment_days
    FROM dw.fact_revenue
    GROUP BY
        date_key,
        contract_key
),
cost_detail AS
(
    SELECT
        cost.date_key,
        cost.contract_key,
        SUM(CASE WHEN category.cost_subcategory = 'Horas adicionais' THEN cost.actual_amount ELSE 0 END) AS overtime_cost,
        SUM(CASE WHEN category.cost_subcategory = 'Horas adicionais' THEN COALESCE(cost.budget_amount, 0) ELSE 0 END) AS overtime_budget,
        SUM(CASE WHEN category.cost_subcategory = 'Cobertura emergencial' THEN cost.actual_amount ELSE 0 END) AS emergency_coverage_cost_accounting,
        SUM(CASE WHEN category.cost_subcategory = 'Cobertura emergencial' THEN COALESCE(cost.budget_amount, 0) ELSE 0 END) AS emergency_coverage_budget,
        SUM
        (
            CASE
                WHEN cost.is_extraordinary = 1
                 AND category.cost_subcategory NOT IN ('Horas adicionais', 'Cobertura emergencial')
                THEN cost.actual_amount
                ELSE 0
            END
        ) AS other_extraordinary_cost
    FROM dw.fact_contract_cost AS cost
    INNER JOIN dw.dim_cost_category AS category
        ON category.cost_category_key = cost.cost_category_key
    GROUP BY
        cost.date_key,
        cost.contract_key
)
SELECT
    base.reference_month,
    EOMONTH(base.reference_month) AS reference_month_end,
    base.date_key,
    base.contract_key,
    base.contract_code,
    base.client_code,
    base.client_name,
    base.business_segment,
    base.service_code,
    base.service_name,
    base.manager_code,
    base.manager_name,
    base.complexity_level,
    contract.contract_status,
    contract.billing_model,
    contract.start_date,
    contract.end_date,
    contract.renewal_date,
    DATEDIFF(DAY, EOMONTH(base.reference_month), contract.renewal_date) AS days_to_renewal,
    base.target_margin_pct,
    base.gross_revenue,
    base.net_revenue,
    revenue_detail.contracted_amount,
    revenue_detail.additional_services,
    revenue_detail.reimbursements,
    revenue_detail.average_payment_days,
    base.total_cost,
    base.budget_cost,
    base.extraordinary_cost,
    cost_detail.overtime_cost,
    cost_detail.overtime_budget,
    CASE
        WHEN cost_detail.overtime_cost > cost_detail.overtime_budget
        THEN cost_detail.overtime_cost - cost_detail.overtime_budget
        ELSE 0
    END AS overtime_excess_cost,
    cost_detail.emergency_coverage_cost_accounting,
    cost_detail.emergency_coverage_budget,
    CASE
        WHEN cost_detail.emergency_coverage_cost_accounting > cost_detail.emergency_coverage_budget
        THEN cost_detail.emergency_coverage_cost_accounting - cost_detail.emergency_coverage_budget
        ELSE 0
    END AS emergency_coverage_excess_cost,
    cost_detail.other_extraordinary_cost,
    base.contribution_margin,
    base.contribution_margin_pct,
    base.margin_gap_pct,
    base.net_revenue * base.target_margin_pct AS target_margin_amount,
    CASE
        WHEN (base.net_revenue * base.target_margin_pct) > base.contribution_margin
        THEN (base.net_revenue * base.target_margin_pct) - base.contribution_margin
        ELSE 0
    END AS margin_leakage_amount,
    CONVERT
    (
        DECIMAL(18,4),
        base.extraordinary_cost / NULLIF(base.net_revenue, 0)
    ) AS extraordinary_cost_rate,
    base.commercial_discounts,
    CONVERT
    (
        DECIMAL(18,4),
        base.commercial_discounts / NULLIF(base.gross_revenue, 0)
    ) AS commercial_discount_rate,
    base.deductions,
    base.revenue_penalties,
    base.invoiced_amount,
    base.received_amount,
    base.planned_positions,
    base.filled_positions,
    base.uncovered_positions,
    base.coverage_rate,
    base.planned_hours,
    base.regular_hours,
    base.overtime_hours,
    base.overtime_rate,
    base.absence_hours,
    base.absenteeism_rate,
    base.open_positions,
    CONVERT
    (
        DECIMAL(18,4),
        base.open_positions / NULLIF(base.planned_positions, 0)
    ) AS vacancy_rate,
    base.average_replacement_days,
    base.emergency_coverage_cost,
    CASE
        WHEN base.regular_hours > base.planned_hours
        THEN base.regular_hours - base.planned_hours
        ELSE 0
    END AS execution_overrun_hours,
    CONVERT
    (
        DECIMAL(18,4),
        CASE
            WHEN base.regular_hours > base.planned_hours
            THEN (base.regular_hours - base.planned_hours) / NULLIF(base.planned_hours, 0)
            ELSE 0
        END
    ) AS execution_overrun_rate,
    CASE
        WHEN base.regular_hours > base.planned_hours
         AND COALESCE(revenue_detail.additional_services, 0) = 0
        THEN
            (base.regular_hours - base.planned_hours)
            * (revenue_detail.contracted_amount / NULLIF(base.planned_hours, 0))
        ELSE 0
    END AS unbilled_scope_estimate,
    base.incident_count,
    base.critical_incident_count,
    base.recurrent_incident_count,
    CONVERT
    (
        DECIMAL(18,4),
        base.recurrent_incident_count / NULLIF(base.incident_count, 0)
    ) AS recurrence_rate,
    base.sla_compliance_rate,
    base.sla_deduction_amount,
    base.sla_penalty_amount,
    base.sla_emergency_cost,
    base.sla_deduction_amount + base.sla_penalty_amount AS sla_financial_loss,
    base.open_adjustment_count,
    base.latest_open_adjustment_expected_date,
    open_adjustment.adjustment_number AS open_adjustment_number,
    open_adjustment.process_type AS open_adjustment_type,
    open_adjustment.requested_pct AS open_adjustment_requested_pct,
    open_adjustment.previous_amount AS open_adjustment_previous_amount,
    CASE
        WHEN open_adjustment.expected_date IS NOT NULL
        THEN DATEDIFF(DAY, open_adjustment.expected_date, EOMONTH(base.reference_month))
        ELSE 0
    END AS adjustment_overdue_days,
    CASE
        WHEN open_adjustment.expected_date IS NOT NULL
         AND EOMONTH(base.reference_month) >= open_adjustment.expected_date
        THEN
            open_adjustment.previous_amount
            * COALESCE(open_adjustment.requested_pct, 0)
            * (DATEDIFF(MONTH, open_adjustment.expected_date, EOMONTH(base.reference_month)) + 1)
        ELSE 0
    END AS adjustment_delay_estimate,
    base.approved_retroactive_amount,
    approved_adjustment.adjustment_number AS latest_approved_adjustment_number,
    approved_adjustment.approval_delay_days AS latest_approved_adjustment_delay_days,
    approved_adjustment.retroactive_amount AS latest_approved_retroactive_amount
FROM mart.vw_contract_monthly_base AS base
INNER JOIN dw.dim_contract AS contract
    ON contract.contract_key = base.contract_key
LEFT JOIN revenue_detail
    ON revenue_detail.date_key = base.date_key
   AND revenue_detail.contract_key = base.contract_key
LEFT JOIN cost_detail
    ON cost_detail.date_key = base.date_key
   AND cost_detail.contract_key = base.contract_key
OUTER APPLY
(
    SELECT TOP (1)
        adjustment.adjustment_number,
        adjustment.process_type,
        adjustment.requested_pct,
        adjustment.previous_amount,
        expected_date.full_date AS expected_date
    FROM dw.fact_adjustment AS adjustment
    INNER JOIN dw.dim_date AS expected_date
        ON expected_date.date_key = adjustment.expected_date_key
    WHERE adjustment.contract_key = base.contract_key
      AND adjustment.process_status IN ('PENDING', 'REQUESTED')
      AND expected_date.full_date <= EOMONTH(base.reference_month)
    ORDER BY
        expected_date.full_date,
        adjustment.adjustment_key
) AS open_adjustment
OUTER APPLY
(
    SELECT TOP (1)
        adjustment.adjustment_number,
        DATEDIFF(DAY, expected_date.full_date, approved_date.full_date) AS approval_delay_days,
        adjustment.retroactive_amount
    FROM dw.fact_adjustment AS adjustment
    INNER JOIN dw.dim_date AS expected_date
        ON expected_date.date_key = adjustment.expected_date_key
    INNER JOIN dw.dim_date AS approved_date
        ON approved_date.date_key = adjustment.approved_date_key
    WHERE adjustment.contract_key = base.contract_key
      AND adjustment.process_status = 'APPROVED'
      AND approved_date.full_date <= EOMONTH(base.reference_month)
    ORDER BY
        approved_date.full_date DESC,
        adjustment.adjustment_key DESC
) AS approved_adjustment;
GO
