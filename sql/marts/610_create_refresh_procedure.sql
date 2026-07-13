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

CREATE OR ALTER PROCEDURE mart.usp_refresh_analytical_marts
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        TRUNCATE TABLE mart.contract_monthly_base_data;
        INSERT INTO mart.contract_monthly_base_data
        SELECT * FROM mart.calc_contract_monthly_base;

        TRUNCATE TABLE mart.contract_monthly_performance_data;
        INSERT INTO mart.contract_monthly_performance_data
        SELECT * FROM mart.calc_contract_monthly_performance;

        TRUNCATE TABLE mart.margin_loss_bridge_data;
        INSERT INTO mart.margin_loss_bridge_data
        SELECT * FROM mart.calc_margin_loss_bridge;

        TRUNCATE TABLE mart.contract_risk_score_data;
        INSERT INTO mart.contract_risk_score_data
        SELECT * FROM mart.calc_contract_risk_score;

        TRUNCATE TABLE mart.contract_risk_drivers_data;
        INSERT INTO mart.contract_risk_drivers_data
        SELECT * FROM mart.calc_contract_risk_drivers;

        TRUNCATE TABLE mart.action_priority_queue_monthly_data;
        INSERT INTO mart.action_priority_queue_monthly_data
        SELECT * FROM mart.calc_action_priority_queue_monthly;

        TRUNCATE TABLE mart.action_priority_queue_data;
        INSERT INTO mart.action_priority_queue_data
        SELECT * FROM mart.calc_action_priority_queue;

        TRUNCATE TABLE mart.executive_summary_data;
        INSERT INTO mart.executive_summary_data
        SELECT * FROM mart.calc_executive_summary;

        TRUNCATE TABLE mart.contract_portfolio_data;
        INSERT INTO mart.contract_portfolio_data
        SELECT * FROM mart.calc_contract_portfolio;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
