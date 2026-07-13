USE margem_em_risco;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW mart.vw_contract_risk_score
AS
WITH observed AS
(
    SELECT
        performance.*,
        parameter.*,
        CASE
            WHEN performance.margin_gap_pct >= 0 THEN 0
            WHEN performance.contribution_margin_pct < 0
              OR ABS(performance.margin_gap_pct) >= parameter.margin_gap_critical THEN 100
            WHEN ABS(performance.margin_gap_pct) >= parameter.margin_gap_high THEN 75
            WHEN ABS(performance.margin_gap_pct) >= parameter.margin_gap_warn THEN 40
            ELSE 15
        END AS score_margin_gap,
        CASE
            WHEN COALESCE(performance.extraordinary_cost_rate, 0) >= parameter.extra_cost_critical THEN 100
            WHEN COALESCE(performance.extraordinary_cost_rate, 0) >= parameter.extra_cost_high THEN 75
            WHEN COALESCE(performance.extraordinary_cost_rate, 0) >= parameter.extra_cost_warn THEN 40
            ELSE 0
        END AS score_extraordinary_cost,
        CASE
            WHEN COALESCE(performance.overtime_rate, 0) >= parameter.overtime_critical THEN 100
            WHEN COALESCE(performance.overtime_rate, 0) >= parameter.overtime_high THEN 75
            WHEN COALESCE(performance.overtime_rate, 0) >= parameter.overtime_warn THEN 40
            ELSE 0
        END AS score_overtime,
        CASE
            WHEN performance.coverage_rate IS NULL THEN 0
            WHEN performance.coverage_rate < parameter.coverage_critical THEN 100
            WHEN performance.coverage_rate < parameter.coverage_high THEN 75
            WHEN performance.coverage_rate < parameter.coverage_warn THEN 40
            ELSE 0
        END AS score_coverage,
        CASE
            WHEN COALESCE(performance.execution_overrun_rate, 0) >= parameter.scope_overrun_critical THEN 100
            WHEN COALESCE(performance.execution_overrun_rate, 0) >= parameter.scope_overrun_high THEN 75
            WHEN COALESCE(performance.execution_overrun_rate, 0) >= parameter.scope_overrun_warn THEN 40
            ELSE 0
        END AS score_scope_overrun,
        CASE
            WHEN performance.incident_count = 0 THEN 0
            WHEN COALESCE(performance.sla_compliance_rate, 0) >= parameter.sla_target THEN 0
            WHEN COALESCE(performance.sla_compliance_rate, 0) >= parameter.sla_high THEN 40
            WHEN COALESCE(performance.sla_compliance_rate, 0) >= parameter.sla_critical THEN 75
            ELSE 100
        END AS score_sla_compliance,
        CASE
            WHEN performance.critical_incident_count >= 2 THEN 100
            WHEN performance.critical_incident_count = 1 THEN 70
            ELSE 0
        END AS score_critical_incidents,
        CASE
            WHEN COALESCE(performance.recurrence_rate, 0) >= 0.5000 THEN 100
            WHEN COALESCE(performance.recurrence_rate, 0) >= 0.2500 THEN 60
            WHEN COALESCE(performance.recurrence_rate, 0) > 0 THEN 30
            ELSE 0
        END AS score_recurrence,
        CASE
            WHEN performance.adjustment_overdue_days >= parameter.adjustment_critical_days THEN 100
            WHEN performance.adjustment_overdue_days >= parameter.adjustment_high_days THEN 75
            WHEN performance.adjustment_overdue_days >= parameter.adjustment_warn_days THEN 40
            ELSE 0
        END AS score_adjustment_delay,
        CASE
            WHEN performance.days_to_renewal IS NULL THEN 0
            WHEN performance.days_to_renewal <= parameter.renewal_critical_days THEN 100
            WHEN performance.days_to_renewal <= parameter.renewal_high_days THEN 75
            WHEN performance.days_to_renewal <= parameter.renewal_warn_days THEN 40
            ELSE 0
        END AS score_renewal_proximity,
        CASE
            WHEN COALESCE(performance.commercial_discount_rate, 0) >= 0.0500 THEN 100
            WHEN COALESCE(performance.commercial_discount_rate, 0) >= 0.0200 THEN 60
            WHEN COALESCE(performance.commercial_discount_rate, 0) > 0 THEN 25
            ELSE 0
        END AS score_commercial_discount,
        CASE
            WHEN COALESCE(performance.absenteeism_rate, 0) >= parameter.absence_critical THEN 100
            WHEN COALESCE(performance.absenteeism_rate, 0) >= parameter.absence_high THEN 75
            WHEN COALESCE(performance.absenteeism_rate, 0) >= parameter.absence_warn THEN 40
            ELSE 0
        END AS score_absenteeism,
        CASE
            WHEN COALESCE(performance.vacancy_rate, 0) >= parameter.vacancy_critical THEN 100
            WHEN COALESCE(performance.vacancy_rate, 0) >= parameter.vacancy_high THEN 75
            WHEN COALESCE(performance.vacancy_rate, 0) >= parameter.vacancy_warn THEN 40
            ELSE 0
        END AS score_vacancies,
        CASE
            WHEN COALESCE(performance.average_replacement_days, 0) >= parameter.replacement_critical_days THEN 100
            WHEN COALESCE(performance.average_replacement_days, 0) >= parameter.replacement_high_days THEN 75
            WHEN COALESCE(performance.average_replacement_days, 0) >= parameter.replacement_warn_days THEN 40
            ELSE 0
        END AS score_replacement_time
    FROM mart.vw_contract_monthly_performance AS performance
    CROSS JOIN config.vw_current_risk_parameters AS parameter
),
pillar_scores AS
(
    SELECT
        observed.*,
        CONVERT
        (
            DECIMAL(9,2),
            observed.score_margin_gap * 0.7500
            + observed.score_extraordinary_cost * 0.2500
        ) AS financial_risk_score,
        CONVERT
        (
            DECIMAL(9,2),
            observed.score_overtime * 0.4500
            + observed.score_coverage * 0.3500
            + observed.score_scope_overrun * 0.2000
        ) AS operational_risk_score,
        CONVERT
        (
            DECIMAL(9,2),
            observed.score_sla_compliance * 0.5000
            + observed.score_critical_incidents * 0.3000
            + observed.score_recurrence * 0.2000
        ) AS quality_risk_score,
        CONVERT
        (
            DECIMAL(9,2),
            observed.score_adjustment_delay * 0.5000
            + observed.score_renewal_proximity * 0.3000
            + observed.score_commercial_discount * 0.2000
        ) AS contractual_risk_score,
        CONVERT
        (
            DECIMAL(9,2),
            observed.score_absenteeism * 0.5000
            + observed.score_vacancies * 0.3000
            + observed.score_replacement_time * 0.2000
        ) AS people_risk_score
    FROM observed
),
final_score AS
(
    SELECT
        pillar_scores.*,
        CONVERT
        (
            DECIMAL(9,2),
            pillar_scores.financial_risk_score * pillar_scores.weight_financial
            + pillar_scores.operational_risk_score * pillar_scores.weight_operational
            + pillar_scores.quality_risk_score * pillar_scores.weight_quality
            + pillar_scores.contractual_risk_score * pillar_scores.weight_contractual
            + pillar_scores.people_risk_score * pillar_scores.weight_people
        ) AS contract_risk_score,
        COUNT(*) OVER
        (
            PARTITION BY pillar_scores.contract_key
            ORDER BY pillar_scores.reference_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS months_in_history,
        pillar_scores.contribution_margin_pct
        - LAG(pillar_scores.contribution_margin_pct, 2) OVER
        (
            PARTITION BY pillar_scores.contract_key
            ORDER BY pillar_scores.reference_month
        ) AS margin_change_3m
    FROM pillar_scores
)
SELECT
    final_score.reference_month,
    final_score.reference_month_end,
    final_score.date_key,
    final_score.contract_key,
    final_score.contract_code,
    final_score.client_code,
    final_score.client_name,
    final_score.business_segment,
    final_score.service_code,
    final_score.service_name,
    final_score.manager_code,
    final_score.manager_name,
    final_score.complexity_level,
    final_score.contract_status,
    final_score.renewal_date,
    final_score.days_to_renewal,
    final_score.net_revenue,
    final_score.total_cost,
    final_score.contribution_margin,
    final_score.contribution_margin_pct,
    final_score.target_margin_pct,
    final_score.margin_gap_pct,
    final_score.margin_leakage_amount,
    final_score.extraordinary_cost,
    final_score.extraordinary_cost_rate,
    final_score.coverage_rate,
    final_score.overtime_rate,
    final_score.execution_overrun_rate,
    final_score.absenteeism_rate,
    final_score.open_positions,
    final_score.vacancy_rate,
    final_score.average_replacement_days,
    final_score.incident_count,
    final_score.critical_incident_count,
    final_score.recurrence_rate,
    final_score.sla_compliance_rate,
    final_score.sla_financial_loss,
    final_score.adjustment_overdue_days,
    final_score.adjustment_delay_estimate,
    final_score.commercial_discount_rate,
    final_score.unbilled_scope_estimate,
    final_score.score_margin_gap,
    final_score.score_extraordinary_cost,
    final_score.score_overtime,
    final_score.score_coverage,
    final_score.score_scope_overrun,
    final_score.score_sla_compliance,
    final_score.score_critical_incidents,
    final_score.score_recurrence,
    final_score.score_adjustment_delay,
    final_score.score_renewal_proximity,
    final_score.score_commercial_discount,
    final_score.score_absenteeism,
    final_score.score_vacancies,
    final_score.score_replacement_time,
    final_score.financial_risk_score,
    final_score.operational_risk_score,
    final_score.quality_risk_score,
    final_score.contractual_risk_score,
    final_score.people_risk_score,
    final_score.contract_risk_score,
    CASE
        WHEN final_score.contract_risk_score >= final_score.risk_critical_min THEN 'CRITICAL'
        WHEN final_score.contract_risk_score >= final_score.risk_high_min THEN 'HIGH'
        WHEN final_score.contract_risk_score >= final_score.risk_attention_min THEN 'ATTENTION'
        ELSE 'LOW'
    END AS risk_class,
    CASE
        WHEN final_score.months_in_history < 3 THEN 'INSUFFICIENT_HISTORY'
        WHEN final_score.margin_change_3m <= -0.0300 THEN 'DETERIORATING_FAST'
        WHEN final_score.margin_change_3m < -0.0100 THEN 'DETERIORATING'
        WHEN final_score.margin_change_3m >= 0.0300 THEN 'IMPROVING_FAST'
        WHEN final_score.margin_change_3m > 0.0100 THEN 'IMPROVING'
        ELSE 'STABLE'
    END AS margin_trend,
    final_score.months_in_history,
    final_score.margin_change_3m
FROM final_score;
GO
