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

PRINT 'Validando a camada materializada.';
GO

DECLARE @failure_count INT = 0;

IF (SELECT COUNT(*) FROM mart.vw_contract_monthly_performance) <> 10
BEGIN
    PRINT 'FALHA: desempenho mensal';
    SET @failure_count += 1;
END;

IF (SELECT COUNT(*) FROM mart.vw_contract_risk_score) <> 10
BEGIN
    PRINT 'FALHA: score de risco';
    SET @failure_count += 1;
END;

IF (SELECT COUNT(*) FROM mart.vw_action_priority_queue) <> 10
BEGIN
    PRINT 'FALHA: fila de prioridade';
    SET @failure_count += 1;
END;

IF NOT EXISTS (SELECT 1 FROM mart.vw_executive_summary)
BEGIN
    PRINT 'FALHA: resumo executivo';
    SET @failure_count += 1;
END;

IF COALESCE((SELECT recommended_action_code FROM mart.vw_action_priority_queue WHERE contract_code = 'CT-001'), 'MISSING') <> 'REINFORCE_COVERAGE'
BEGIN
    PRINT 'FALHA: CT-001';
    SET @failure_count += 1;
END;

IF COALESCE((SELECT recommended_action_code FROM mart.vw_action_priority_queue WHERE contract_code = 'CT-002'), 'MISSING') <> 'REVIEW_RETROACTIVE'
BEGIN
    PRINT 'FALHA: CT-002';
    SET @failure_count += 1;
END;

IF COALESCE((SELECT recommended_action_code FROM mart.vw_action_priority_queue WHERE contract_code = 'CT-003'), 'MISSING') <> 'FORMALIZE_SCOPE'
BEGIN
    PRINT 'FALHA: CT-003';
    SET @failure_count += 1;
END;

IF COALESCE((SELECT recommended_action_code FROM mart.vw_action_priority_queue WHERE contract_code = 'CT-004'), 'MISSING') <> 'SLA_RECOVERY_PLAN'
BEGIN
    PRINT 'FALHA: CT-004';
    SET @failure_count += 1;
END;

IF COALESCE((SELECT recommended_action_code FROM mart.vw_action_priority_queue WHERE contract_code = 'CT-005'), 'MISSING') <> 'ASSESS_NON_RENEWAL'
BEGIN
    PRINT 'FALHA: CT-005';
    SET @failure_count += 1;
END;

IF COALESCE((SELECT recommended_action_code FROM mart.vw_action_priority_queue WHERE contract_code = 'CT-007'), 'MISSING') <> 'EXPAND'
BEGIN
    PRINT 'FALHA: CT-007';
    SET @failure_count += 1;
END;

IF COALESCE((SELECT recommended_action_code FROM mart.vw_action_priority_queue WHERE contract_code = 'CT-008'), 'MISSING') <> 'REQUEST_ADJUSTMENT'
BEGIN
    PRINT 'FALHA: CT-008';
    SET @failure_count += 1;
END;

IF COALESCE((SELECT recommended_action_code FROM mart.vw_action_priority_queue WHERE contract_code = 'CT-009'), 'MISSING') <> 'REINFORCE_COVERAGE'
BEGIN
    PRINT 'FALHA: CT-009';
    SET @failure_count += 1;
END;

IF @failure_count > 0
    THROW 51550, 'A camada materializada foi criada, mas existem testes com falha.', 1;

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
    action_recoverable_amount
FROM mart.vw_action_priority_queue
ORDER BY portfolio_priority_rank;

PRINT 'Todos os testes da camada materializada passaram.';
GO
