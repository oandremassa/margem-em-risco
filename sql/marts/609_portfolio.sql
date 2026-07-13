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

PRINT N'Criando camada materializada: portfolio atual';
GO

CREATE OR ALTER VIEW mart.calc_contract_portfolio
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


SELECT TOP (0) *
INTO mart.contract_portfolio_data
FROM mart.calc_contract_portfolio;
GO

INSERT INTO mart.contract_portfolio_data
SELECT *
FROM mart.calc_contract_portfolio;
GO

CREATE UNIQUE CLUSTERED INDEX CIX_contract_portfolio_data
ON mart.contract_portfolio_data (contract_key);
GO

CREATE OR ALTER VIEW mart.vw_contract_portfolio
AS
SELECT *
FROM mart.contract_portfolio_data;
GO

IF (SELECT COUNT(*) FROM mart.contract_portfolio_data) <> 10
    THROW 51519, 'O portfolio deveria conter 10 contratos.', 1;
GO

PRINT N'Camada concluida: portfolio atual';
GO
