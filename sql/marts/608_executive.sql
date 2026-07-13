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

PRINT N'Criando camada materializada: resumo executivo';
GO

CREATE OR ALTER VIEW mart.calc_executive_summary
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


SELECT TOP (0) *
INTO mart.executive_summary_data
FROM mart.calc_executive_summary;
GO

INSERT INTO mart.executive_summary_data
SELECT *
FROM mart.calc_executive_summary;
GO

CREATE UNIQUE CLUSTERED INDEX CIX_executive_summary_data
ON mart.executive_summary_data (reference_month);
GO

CREATE OR ALTER VIEW mart.vw_executive_summary
AS
SELECT *
FROM mart.executive_summary_data;
GO

IF NOT EXISTS (SELECT 1 FROM mart.executive_summary_data)
    THROW 51518, 'O resumo executivo ficou vazio.', 1;
GO

PRINT N'Camada concluida: resumo executivo';
GO
