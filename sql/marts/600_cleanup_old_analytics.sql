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

PRINT 'Removendo a cadeia antiga de views analiticas.';
GO

DROP VIEW IF EXISTS mart.vw_contract_portfolio;
DROP VIEW IF EXISTS mart.vw_executive_summary;
DROP VIEW IF EXISTS mart.vw_action_priority_queue;
DROP VIEW IF EXISTS mart.vw_action_priority_queue_monthly;
DROP VIEW IF EXISTS mart.vw_contract_risk_drivers;
DROP VIEW IF EXISTS mart.vw_contract_risk_score;
DROP VIEW IF EXISTS mart.vw_margin_loss_bridge;
DROP VIEW IF EXISTS mart.vw_contract_monthly_performance;
DROP VIEW IF EXISTS mart.vw_contract_monthly_base;
GO

DROP VIEW IF EXISTS mart.calc_contract_portfolio;
DROP VIEW IF EXISTS mart.calc_executive_summary;
DROP VIEW IF EXISTS mart.calc_action_priority_queue;
DROP VIEW IF EXISTS mart.calc_action_priority_queue_monthly;
DROP VIEW IF EXISTS mart.calc_contract_risk_drivers;
DROP VIEW IF EXISTS mart.calc_contract_risk_score;
DROP VIEW IF EXISTS mart.calc_margin_loss_bridge;
DROP VIEW IF EXISTS mart.calc_contract_monthly_performance;
DROP VIEW IF EXISTS mart.calc_contract_monthly_base;
GO

DROP PROCEDURE IF EXISTS mart.usp_refresh_analytical_marts;
DROP PROCEDURE IF EXISTS mart.usp_refresh_executive_summary;
GO

DROP TABLE IF EXISTS mart.contract_portfolio_data;
DROP TABLE IF EXISTS mart.executive_summary_snapshot;
DROP TABLE IF EXISTS mart.executive_summary_data;
DROP TABLE IF EXISTS mart.action_priority_queue_data;
DROP TABLE IF EXISTS mart.action_priority_queue_monthly_data;
DROP TABLE IF EXISTS mart.contract_risk_drivers_data;
DROP TABLE IF EXISTS mart.contract_risk_score_data;
DROP TABLE IF EXISTS mart.margin_loss_bridge_data;
DROP TABLE IF EXISTS mart.contract_monthly_performance_data;
DROP TABLE IF EXISTS mart.contract_monthly_base_data;
GO

IF NOT EXISTS (SELECT 1 FROM dw.fact_revenue)
    THROW 51500, 'A camada DW nao possui receita carregada.', 1;

IF NOT EXISTS (SELECT 1 FROM dw.fact_contract_cost)
    THROW 51501, 'A camada DW nao possui custos carregados.', 1;

IF NOT EXISTS (SELECT 1 FROM dw.fact_operation)
    THROW 51502, 'A camada DW nao possui dados operacionais.', 1;

PRINT 'Limpeza concluida. Os dados do DW foram preservados.';
GO
