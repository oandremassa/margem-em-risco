USE margem_em_risco;
GO

SET NOCOUNT ON;
GO

DECLARE @required TABLE
(
    object_name SYSNAME NOT NULL,
    column_name SYSNAME NOT NULL
);

INSERT INTO @required
(
    object_name,
    column_name
)
VALUES
(N'dw.dim_date', N'full_date'),
(N'dw.dim_date', N'date_key'),
(N'dw.dim_date', N'month_start_date'),
(N'dw.dim_date', N'month_number'),
(N'dw.dim_date', N'month_name_pt'),
(N'dw.dim_date', N'quarter_number'),
(N'dw.dim_date', N'year_number'),
(N'dw.dim_date', N'year_month'),
(N'dw.dim_date', N'is_weekend'),

(N'mart.vw_contract_portfolio', N'contract_key'),
(N'mart.vw_contract_portfolio', N'contract_code'),
(N'mart.vw_contract_portfolio', N'client_name'),
(N'mart.vw_contract_portfolio', N'business_segment'),
(N'mart.vw_contract_portfolio', N'service_name'),
(N'mart.vw_contract_portfolio', N'manager_name'),
(N'mart.vw_contract_portfolio', N'complexity_level'),
(N'mart.vw_contract_portfolio', N'renewal_date'),
(N'mart.vw_contract_portfolio', N'target_margin_pct'),

(N'mart.vw_executive_summary', N'reference_month'),
(N'mart.vw_executive_summary', N'active_contract_count'),
(N'mart.vw_executive_summary', N'net_revenue'),
(N'mart.vw_executive_summary', N'total_cost'),
(N'mart.vw_executive_summary', N'contribution_margin'),
(N'mart.vw_executive_summary', N'contribution_margin_pct'),
(N'mart.vw_executive_summary', N'margin_leakage_amount'),
(N'mart.vw_executive_summary', N'identified_loss_amount'),
(N'mart.vw_executive_summary', N'recoverable_amount'),
(N'mart.vw_executive_summary', N'revenue_at_risk'),
(N'mart.vw_executive_summary', N'critical_contract_count'),
(N'mart.vw_executive_summary', N'high_risk_contract_count'),
(N'mart.vw_executive_summary', N'contracts_requiring_action'),

(N'mart.vw_contract_monthly_performance', N'reference_month'),
(N'mart.vw_contract_monthly_performance', N'date_key'),
(N'mart.vw_contract_monthly_performance', N'contract_key'),
(N'mart.vw_contract_monthly_performance', N'contract_code'),
(N'mart.vw_contract_monthly_performance', N'client_name'),
(N'mart.vw_contract_monthly_performance', N'business_segment'),
(N'mart.vw_contract_monthly_performance', N'service_name'),
(N'mart.vw_contract_monthly_performance', N'manager_name'),
(N'mart.vw_contract_monthly_performance', N'complexity_level'),
(N'mart.vw_contract_monthly_performance', N'renewal_date'),
(N'mart.vw_contract_monthly_performance', N'days_to_renewal'),
(N'mart.vw_contract_monthly_performance', N'target_margin_pct'),
(N'mart.vw_contract_monthly_performance', N'gross_revenue'),
(N'mart.vw_contract_monthly_performance', N'net_revenue'),
(N'mart.vw_contract_monthly_performance', N'total_cost'),
(N'mart.vw_contract_monthly_performance', N'contribution_margin'),
(N'mart.vw_contract_monthly_performance', N'contribution_margin_pct'),
(N'mart.vw_contract_monthly_performance', N'margin_gap_pct'),
(N'mart.vw_contract_monthly_performance', N'margin_leakage_amount'),
(N'mart.vw_contract_monthly_performance', N'planned_positions'),
(N'mart.vw_contract_monthly_performance', N'filled_positions'),
(N'mart.vw_contract_monthly_performance', N'uncovered_positions'),
(N'mart.vw_contract_monthly_performance', N'coverage_rate'),
(N'mart.vw_contract_monthly_performance', N'planned_hours'),
(N'mart.vw_contract_monthly_performance', N'regular_hours'),
(N'mart.vw_contract_monthly_performance', N'overtime_hours'),
(N'mart.vw_contract_monthly_performance', N'overtime_rate'),
(N'mart.vw_contract_monthly_performance', N'absence_hours'),
(N'mart.vw_contract_monthly_performance', N'absenteeism_rate'),
(N'mart.vw_contract_monthly_performance', N'open_positions'),
(N'mart.vw_contract_monthly_performance', N'average_replacement_days'),
(N'mart.vw_contract_monthly_performance', N'incident_count'),
(N'mart.vw_contract_monthly_performance', N'critical_incident_count'),
(N'mart.vw_contract_monthly_performance', N'recurrent_incident_count'),
(N'mart.vw_contract_monthly_performance', N'sla_compliance_rate'),
(N'mart.vw_contract_monthly_performance', N'open_adjustment_count'),

(N'mart.vw_contract_risk_score', N'date_key'),
(N'mart.vw_contract_risk_score', N'contract_key'),
(N'mart.vw_contract_risk_score', N'margin_trend'),
(N'mart.vw_contract_risk_score', N'contract_risk_score'),
(N'mart.vw_contract_risk_score', N'risk_class'),

(N'mart.vw_margin_loss_bridge', N'loss_code'),
(N'mart.vw_contract_risk_drivers', N'driver_code'),
(N'mart.vw_action_priority_queue', N'portfolio_priority_rank'),
(N'mart.vw_management_action_effect', N'management_action_key'),
(N'mart.vw_contract_timeline', N'timeline_key');

;WITH missing_object AS
(
    SELECT DISTINCT
        required.object_name
    FROM @required AS required
    WHERE OBJECT_ID(required.object_name) IS NULL
),
missing_column AS
(
    SELECT
        required.object_name,
        required.column_name
    FROM @required AS required
    WHERE OBJECT_ID(required.object_name) IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM sys.columns AS column_metadata
          WHERE column_metadata.object_id = OBJECT_ID(required.object_name)
            AND column_metadata.name = required.column_name
      )
)
SELECT
    N'OBJETO AUSENTE' AS tipo,
    missing_object.object_name AS objeto,
    CAST(NULL AS SYSNAME) AS coluna
FROM missing_object

UNION ALL

SELECT
    N'COLUNA AUSENTE',
    missing_column.object_name,
    missing_column.column_name
FROM missing_column
ORDER BY tipo, objeto, coluna;

IF EXISTS
(
    SELECT 1
    FROM @required AS required
    WHERE OBJECT_ID(required.object_name) IS NULL
       OR NOT EXISTS
       (
           SELECT 1
           FROM sys.columns AS column_metadata
           WHERE column_metadata.object_id = OBJECT_ID(required.object_name)
             AND column_metadata.name = required.column_name
       )
)
BEGIN
    THROW 51710, N'A camada de origem nao possui todos os objetos exigidos pela Fase 05.', 1;
END;

PRINT N'Pré-requisitos da Fase 05 validados.';
GO
