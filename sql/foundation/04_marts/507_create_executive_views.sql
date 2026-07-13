USE margem_em_risco;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW mart.vw_executive_summary
AS
WITH loss AS
(
    SELECT
        reference_month,
        SUM(loss_amount) AS identified_loss_amount,
        SUM(recoverable_amount) AS recoverable_amount,
        SUM(CASE WHEN is_estimate = 0 THEN loss_amount ELSE 0 END) AS direct_loss_amount,
        SUM(CASE WHEN is_estimate = 1 THEN loss_amount ELSE 0 END) AS estimated_exposure_amount
    FROM mart.vw_margin_loss_bridge
    GROUP BY reference_month
),
action AS
(
    SELECT
        reference_month,
        SUM(action_impact_amount) AS action_impact_amount,
        SUM(action_recoverable_amount) AS action_recoverable_amount,
        SUM(CASE WHEN recommended_action_code NOT IN ('MAINTAIN', 'EXPAND') THEN 1 ELSE 0 END) AS contracts_requiring_action
    FROM mart.vw_action_priority_queue_monthly
    GROUP BY reference_month
)
SELECT
    risk.reference_month,
    COUNT(*) AS active_contract_count,
    SUM(risk.net_revenue) AS net_revenue,
    SUM(risk.total_cost) AS total_cost,
    SUM(risk.contribution_margin) AS contribution_margin,
    CONVERT
    (
        DECIMAL(18,4),
        SUM(risk.contribution_margin) / NULLIF(SUM(risk.net_revenue), 0)
    ) AS contribution_margin_pct,
    SUM(risk.margin_leakage_amount) AS margin_leakage_amount,
    COALESCE(loss.identified_loss_amount, 0) AS identified_loss_amount,
    COALESCE(loss.direct_loss_amount, 0) AS direct_loss_amount,
    COALESCE(loss.estimated_exposure_amount, 0) AS estimated_exposure_amount,
    COALESCE(loss.recoverable_amount, 0) AS recoverable_amount,
    SUM(CASE WHEN risk.contract_risk_score >= 60 THEN risk.net_revenue ELSE 0 END) AS revenue_at_risk,
    SUM(CASE WHEN risk.risk_class = 'CRITICAL' THEN 1 ELSE 0 END) AS critical_contract_count,
    SUM(CASE WHEN risk.risk_class = 'HIGH' THEN 1 ELSE 0 END) AS high_risk_contract_count,
    SUM(CASE WHEN risk.risk_class = 'ATTENTION' THEN 1 ELSE 0 END) AS attention_contract_count,
    SUM(CASE WHEN risk.risk_class = 'LOW' THEN 1 ELSE 0 END) AS low_risk_contract_count,
    COALESCE(action.contracts_requiring_action, 0) AS contracts_requiring_action,
    COALESCE(action.action_impact_amount, 0) AS action_impact_amount,
    COALESCE(action.action_recoverable_amount, 0) AS action_recoverable_amount
FROM mart.vw_contract_risk_score AS risk
LEFT JOIN loss
    ON loss.reference_month = risk.reference_month
LEFT JOIN action
    ON action.reference_month = risk.reference_month
GROUP BY
    risk.reference_month,
    loss.identified_loss_amount,
    loss.direct_loss_amount,
    loss.estimated_exposure_amount,
    loss.recoverable_amount,
    action.contracts_requiring_action,
    action.action_impact_amount,
    action.action_recoverable_amount;
GO

CREATE OR ALTER VIEW mart.vw_contract_portfolio
AS
WITH latest_month AS
(
    SELECT MAX(reference_month) AS reference_month
    FROM mart.vw_contract_risk_score
),
top_driver AS
(
    SELECT
        driver.reference_month,
        driver.contract_key,
        driver.driver_name_pt,
        driver.driver_score,
        driver.estimated_impact_amount
    FROM mart.vw_contract_risk_drivers AS driver
    WHERE driver.driver_rank = 1
)
SELECT
    risk.reference_month,
    risk.contract_key,
    risk.contract_code,
    risk.client_code,
    risk.client_name,
    risk.business_segment,
    risk.service_code,
    risk.service_name,
    risk.manager_code,
    risk.manager_name,
    risk.complexity_level,
    risk.net_revenue,
    risk.contribution_margin,
    risk.contribution_margin_pct,
    risk.target_margin_pct,
    risk.margin_gap_pct,
    risk.margin_leakage_amount,
    risk.contract_risk_score,
    risk.risk_class,
    risk.financial_risk_score,
    risk.operational_risk_score,
    risk.quality_risk_score,
    risk.contractual_risk_score,
    risk.people_risk_score,
    risk.margin_trend,
    risk.renewal_date,
    risk.days_to_renewal,
    driver.driver_name_pt AS main_risk_driver_pt,
    driver.driver_score AS main_risk_driver_score,
    driver.estimated_impact_amount AS main_risk_driver_impact,
    queue.recommended_action_code,
    queue.recommended_action_name_pt,
    queue.action_impact_amount,
    queue.action_recoverable_amount,
    queue.action_priority_score,
    queue.portfolio_priority_rank
FROM mart.vw_contract_risk_score AS risk
CROSS JOIN latest_month
LEFT JOIN top_driver AS driver
    ON driver.reference_month = risk.reference_month
   AND driver.contract_key = risk.contract_key
LEFT JOIN mart.vw_action_priority_queue AS queue
    ON queue.reference_month = risk.reference_month
   AND queue.contract_key = risk.contract_key
WHERE risk.reference_month = latest_month.reference_month;
GO
