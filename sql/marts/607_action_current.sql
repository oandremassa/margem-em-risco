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

PRINT N'Criando camada materializada: fila atual de prioridades';
GO

CREATE OR ALTER VIEW mart.calc_action_priority_queue
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


SELECT TOP (0) *
INTO mart.action_priority_queue_data
FROM mart.calc_action_priority_queue;
GO

INSERT INTO mart.action_priority_queue_data
SELECT *
FROM mart.calc_action_priority_queue;
GO

CREATE UNIQUE CLUSTERED INDEX CIX_action_priority_queue_data
ON mart.action_priority_queue_data (contract_key);
GO

CREATE OR ALTER VIEW mart.vw_action_priority_queue
AS
SELECT *
FROM mart.action_priority_queue_data;
GO

IF (SELECT COUNT(*) FROM mart.action_priority_queue_data) <> 10
    THROW 51517, 'A fila atual deveria conter 10 contratos.', 1;
GO

PRINT N'Camada concluida: fila atual de prioridades';
GO
