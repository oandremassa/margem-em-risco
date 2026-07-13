USE margem_em_risco;
GO

SET NOCOUNT ON;
GO

PRINT N'Últimos 12 meses — visão executiva';
SELECT
    reference_month,
    net_revenue,
    contribution_margin,
    contribution_margin_pct,
    margin_leakage_amount,
    recoverable_amount,
    revenue_at_risk,
    critical_contract_count,
    high_risk_contract_count,
    contracts_requiring_action
FROM mart.vw_executive_summary
WHERE reference_month >= '2025-07-01'
ORDER BY reference_month;
GO

PRINT N'Carteira atual — junho de 2026';
SELECT
    portfolio_priority_rank,
    contract_code,
    client_name,
    contribution_margin_pct,
    target_margin_pct,
    contract_risk_score,
    risk_class,
    main_risk_driver_pt,
    recommended_action_name_pt,
    action_recoverable_amount
FROM mart.vw_contract_portfolio
ORDER BY portfolio_priority_rank;
GO

PRINT N'Ações concluídas — comparação antes e depois';
SELECT
    contract_code,
    action_name_pt,
    start_date,
    completion_date,
    margin_before_pct,
    margin_after_pct,
    margin_delta_pp,
    overtime_before_pct,
    overtime_after_pct,
    coverage_before_pct,
    coverage_after_pct,
    sla_before_pct,
    sla_after_pct,
    actual_impact_amount
FROM mart.vw_management_action_effect
ORDER BY completion_date, contract_code;
GO

PRINT N'Linha do tempo — eventos mais recentes';
SELECT TOP (40)
    reference_date,
    contract_code,
    event_type,
    event_severity,
    event_title,
    event_detail,
    impact_amount
FROM mart.vw_contract_timeline
ORDER BY reference_date DESC, contract_code, timeline_key DESC;
GO

PRINT N'Evolução dos contratos usados na narrativa';
SELECT
    reference_month,
    contract_code,
    contribution_margin_pct,
    target_margin_pct,
    coverage_rate,
    overtime_rate,
    absenteeism_rate,
    sla_compliance_rate,
    adjustment_overdue_days,
    margin_trend
FROM mart.vw_contract_risk_score
WHERE contract_code IN ('CT-001', 'CT-003', 'CT-004', 'CT-005', 'CT-008', 'CT-009')
  AND reference_month IN
  (
      '2024-07-01',
      '2025-01-01',
      '2025-07-01',
      '2025-12-01',
      '2026-03-01',
      '2026-06-01'
  )
ORDER BY contract_code, reference_month;
GO
