USE margem_em_risco;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW mart.vw_action_priority_queue_monthly
AS
WITH loss_summary AS
(
    SELECT
        reference_month,
        contract_key,
        SUM(loss_amount) AS identified_loss_amount,
        SUM(recoverable_amount) AS recoverable_amount,
        SUM(CASE WHEN loss_code = 'OVERTIME_EXCESS' THEN loss_amount ELSE 0 END) AS overtime_loss,
        SUM(CASE WHEN loss_code = 'EMERGENCY_COVERAGE_EXCESS' THEN loss_amount ELSE 0 END) AS coverage_loss,
        SUM(CASE WHEN loss_code = 'SLA_FINANCIAL_LOSS' THEN loss_amount ELSE 0 END) AS sla_loss,
        SUM(CASE WHEN loss_code = 'ADJUSTMENT_DELAY_ESTIMATE' THEN loss_amount ELSE 0 END) AS adjustment_loss,
        SUM(CASE WHEN loss_code = 'UNBILLED_SCOPE_ESTIMATE' THEN loss_amount ELSE 0 END) AS scope_loss
    FROM mart.vw_margin_loss_bridge
    GROUP BY
        reference_month,
        contract_key
),
action_base AS
(
    SELECT
        risk.*,
        performance.open_adjustment_number,
        performance.latest_approved_adjustment_delay_days,
        performance.latest_approved_retroactive_amount,
        performance.overtime_excess_cost,
        performance.emergency_coverage_excess_cost,
        COALESCE(loss.identified_loss_amount, 0) AS identified_loss_amount,
        COALESCE(loss.recoverable_amount, 0) AS recoverable_amount,
        COALESCE(loss.overtime_loss, 0) AS overtime_loss,
        COALESCE(loss.coverage_loss, 0) AS coverage_loss,
        COALESCE(loss.sla_loss, 0) AS sla_loss,
        COALESCE(loss.adjustment_loss, 0) AS adjustment_loss,
        COALESCE(loss.scope_loss, 0) AS scope_loss,
        CASE
            WHEN risk.contribution_margin_pct < 0
             AND risk.contract_risk_score >= 65
             AND (risk.days_to_renewal IS NULL OR risk.days_to_renewal <= parameter.non_renewal_review_days)
                THEN 'ASSESS_NON_RENEWAL'
            WHEN risk.adjustment_overdue_days >= parameter.adjustment_warn_days
                THEN 'REQUEST_ADJUSTMENT'
            WHEN performance.latest_approved_adjustment_delay_days >= parameter.adjustment_high_days
             AND performance.latest_approved_retroactive_amount > 0
                THEN 'REVIEW_RETROACTIVE'
            WHEN risk.coverage_rate < parameter.coverage_critical
             AND risk.open_positions > 0
                THEN 'REINFORCE_COVERAGE'
            WHEN risk.execution_overrun_rate >= parameter.scope_overrun_warn
             AND risk.unbilled_scope_estimate > 0
                THEN 'FORMALIZE_SCOPE'
            WHEN risk.quality_risk_score >= 60
             AND risk.incident_count > 0
                THEN 'SLA_RECOVERY_PLAN'
            WHEN risk.overtime_rate >= parameter.overtime_high
                THEN 'REVIEW_SCHEDULE'
            WHEN risk.margin_gap_pct <= -parameter.margin_gap_high
                THEN 'RENEGOTIATE_PRICE'
            WHEN risk.contract_risk_score < parameter.risk_attention_min
             AND risk.margin_gap_pct >= 0
                THEN 'EXPAND'
            ELSE 'MAINTAIN'
        END AS recommended_action_code
    FROM mart.vw_contract_risk_score AS risk
    INNER JOIN mart.vw_contract_monthly_performance AS performance
        ON performance.reference_month = risk.reference_month
       AND performance.contract_key = risk.contract_key
    CROSS JOIN config.vw_current_risk_parameters AS parameter
    LEFT JOIN loss_summary AS loss
        ON loss.reference_month = risk.reference_month
       AND loss.contract_key = risk.contract_key
),
action_values AS
(
    SELECT
        action_base.*,
        CASE action_base.recommended_action_code
            WHEN 'ASSESS_NON_RENEWAL' THEN
                CASE
                    WHEN action_base.contribution_margin < 0
                    THEN ABS(action_base.contribution_margin) * 12
                    ELSE action_base.margin_leakage_amount * 12
                END
            WHEN 'REQUEST_ADJUSTMENT' THEN action_base.adjustment_loss
            WHEN 'REVIEW_RETROACTIVE' THEN action_base.latest_approved_retroactive_amount
            WHEN 'REINFORCE_COVERAGE' THEN action_base.coverage_loss + action_base.overtime_loss
            WHEN 'SLA_RECOVERY_PLAN' THEN action_base.sla_loss
            WHEN 'FORMALIZE_SCOPE' THEN action_base.scope_loss
            WHEN 'REVIEW_SCHEDULE' THEN action_base.overtime_loss
            WHEN 'RENEGOTIATE_PRICE' THEN action_base.margin_leakage_amount
            ELSE 0
        END AS action_impact_amount,
        CASE action_base.recommended_action_code
            WHEN 'ASSESS_NON_RENEWAL' THEN 0.8500
            WHEN 'REQUEST_ADJUSTMENT' THEN 0.7000
            WHEN 'REVIEW_RETROACTIVE' THEN 0.8000
            WHEN 'REINFORCE_COVERAGE' THEN 0.4500
            WHEN 'SLA_RECOVERY_PLAN' THEN 0.3500
            WHEN 'FORMALIZE_SCOPE' THEN 0.6000
            WHEN 'REVIEW_SCHEDULE' THEN 0.5000
            WHEN 'RENEGOTIATE_PRICE' THEN 0.5500
            WHEN 'EXPAND' THEN 0.3000
            ELSE 0.1000
        END AS action_recoverability_rate,
        CASE action_base.recommended_action_code
            WHEN 'ASSESS_NON_RENEWAL' THEN 95
            WHEN 'REQUEST_ADJUSTMENT' THEN
                CASE
                    WHEN action_base.adjustment_overdue_days >= 180 THEN 100
                    WHEN action_base.adjustment_overdue_days >= 90 THEN 80
                    ELSE 60
                END
            WHEN 'REVIEW_RETROACTIVE' THEN 75
            WHEN 'REINFORCE_COVERAGE' THEN action_base.operational_risk_score
            WHEN 'SLA_RECOVERY_PLAN' THEN action_base.quality_risk_score
            WHEN 'FORMALIZE_SCOPE' THEN 70
            WHEN 'REVIEW_SCHEDULE' THEN action_base.operational_risk_score
            WHEN 'RENEGOTIATE_PRICE' THEN action_base.financial_risk_score
            WHEN 'EXPAND' THEN 30
            ELSE 10
        END AS action_urgency_score
    FROM action_base
),
normalized AS
(
    SELECT
        action_values.*,
        MAX(action_values.action_impact_amount) OVER
        (
            PARTITION BY action_values.reference_month
        ) AS max_action_impact_amount
    FROM action_values
)
SELECT
    normalized.reference_month,
    normalized.date_key,
    normalized.contract_key,
    normalized.contract_code,
    normalized.client_code,
    normalized.client_name,
    normalized.service_name,
    normalized.manager_name,
    normalized.net_revenue,
    normalized.contribution_margin,
    normalized.contribution_margin_pct,
    normalized.target_margin_pct,
    normalized.margin_gap_pct,
    normalized.margin_leakage_amount,
    normalized.contract_risk_score,
    normalized.risk_class,
    normalized.days_to_renewal,
    normalized.identified_loss_amount,
    normalized.recoverable_amount,
    normalized.recommended_action_code,
    action.action_name_pt AS recommended_action_name_pt,
    action.default_owner_area AS owner_area,
    CONVERT(DECIMAL(18,2), normalized.action_impact_amount) AS action_impact_amount,
    normalized.action_recoverability_rate,
    CONVERT
    (
        DECIMAL(18,2),
        normalized.action_impact_amount * normalized.action_recoverability_rate
    ) AS action_recoverable_amount,
    CONVERT(DECIMAL(9,2), normalized.action_urgency_score) AS action_urgency_score,
    CONVERT
    (
        DECIMAL(9,2),
        COALESCE
        (
            100.0 * normalized.action_impact_amount
            / NULLIF(normalized.max_action_impact_amount, 0),
            0
        ) * 0.4000
        + normalized.contract_risk_score * 0.3000
        + normalized.action_urgency_score * 0.2000
        + normalized.action_recoverability_rate * 100 * 0.1000
    ) AS action_priority_score,
    CASE normalized.recommended_action_code
        WHEN 'ASSESS_NON_RENEWAL' THEN N'Margem negativa e risco elevado. O contrato precisa ser reprecificado ou retirado da carteira.'
        WHEN 'REQUEST_ADJUSTMENT' THEN N'Existe reajuste pendente com atraso e exposição financeira estimada.'
        WHEN 'REVIEW_RETROACTIVE' THEN N'O reajuste foi aprovado com atraso. A retroatividade precisa ser conferida e cobrada.'
        WHEN 'REINFORCE_COVERAGE' THEN N'A cobertura de postos está abaixo do limite e há vagas abertas.'
        WHEN 'SLA_RECOVERY_PLAN' THEN N'Falhas de SLA, reincidência ou ocorrências críticas estão pressionando o resultado.'
        WHEN 'FORMALIZE_SCOPE' THEN N'As horas executadas superam o previsto sem faturamento adicional registrado.'
        WHEN 'REVIEW_SCHEDULE' THEN N'As horas adicionais estão acima do limite definido para a operação.'
        WHEN 'RENEGOTIATE_PRICE' THEN N'A margem permanece distante da meta mesmo sem um evento operacional dominante.'
        WHEN 'EXPAND' THEN N'O contrato está acima da meta e apresenta baixo risco operacional e financeiro.'
        ELSE N'Não há desvio material que justifique intervenção imediata.'
    END AS action_reason_pt
FROM normalized
INNER JOIN dw.dim_action AS action
    ON action.action_code = normalized.recommended_action_code;
GO

CREATE OR ALTER VIEW mart.vw_action_priority_queue
AS
WITH latest_month AS
(
    SELECT MAX(reference_month) AS reference_month
    FROM mart.vw_action_priority_queue_monthly
)
SELECT
    queue.*,
    ROW_NUMBER() OVER
    (
        ORDER BY
            queue.action_priority_score DESC,
            queue.action_impact_amount DESC,
            queue.contract_code
    ) AS portfolio_priority_rank
FROM mart.vw_action_priority_queue_monthly AS queue
CROSS JOIN latest_month
WHERE queue.reference_month = latest_month.reference_month;
GO
