USE margem_em_risco;
GO

SELECT
    reference_month,
    active_contract_count,
    net_revenue,
    contribution_margin,
    contribution_margin_pct,
    margin_leakage_amount,
    identified_loss_amount,
    recoverable_amount,
    revenue_at_risk,
    critical_contract_count,
    high_risk_contract_count,
    contracts_requiring_action
FROM mart.vw_executive_summary
ORDER BY reference_month;

SELECT
    portfolio_priority_rank,
    contract_code,
    client_name,
    contribution_margin_pct,
    contract_risk_score,
    risk_class,
    recommended_action_name_pt,
    action_impact_amount,
    action_recoverable_amount,
    action_reason_pt
FROM mart.vw_action_priority_queue
ORDER BY portfolio_priority_rank;

SELECT
    contract_code,
    driver_rank,
    risk_pillar,
    driver_name_pt,
    driver_score,
    observed_value,
    reference_value,
    estimated_impact_amount
FROM mart.vw_contract_risk_drivers
WHERE driver_rank <= 3
  AND reference_month = (SELECT MAX(reference_month) FROM mart.vw_contract_risk_drivers)
ORDER BY
    contract_code,
    driver_rank;

SELECT
    contract_code,
    loss_name_pt,
    loss_nature,
    loss_amount,
    recovery_rate,
    recoverable_amount,
    calculation_note
FROM mart.vw_margin_loss_bridge
WHERE reference_month = (SELECT MAX(reference_month) FROM mart.vw_margin_loss_bridge)
ORDER BY
    contract_code,
    loss_amount DESC;
GO
