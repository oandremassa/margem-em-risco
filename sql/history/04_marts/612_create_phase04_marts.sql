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

IF OBJECT_ID(N'mart.usp_refresh_analytical_marts', N'P') IS NULL
    THROW 51630, N'A camada materializada da Fase 03 não foi encontrada.', 1;
GO

IF OBJECT_ID(N'mart.management_action_effect_data', N'U') IS NULL
BEGIN
    CREATE TABLE mart.management_action_effect_data
    (
        management_action_key  BIGINT NOT NULL,
        contract_key           INT NOT NULL,
        contract_code          VARCHAR(20) NOT NULL,
        action_code            VARCHAR(30) NOT NULL,
        action_name_pt         NVARCHAR(120) NOT NULL,
        start_date             DATE NOT NULL,
        completion_date        DATE NOT NULL,
        months_before          INT NOT NULL,
        months_after           INT NOT NULL,
        margin_before_pct      DECIMAL(18,4) NULL,
        margin_after_pct       DECIMAL(18,4) NULL,
        margin_delta_pp        DECIMAL(18,2) NULL,
        overtime_before_pct    DECIMAL(18,4) NULL,
        overtime_after_pct     DECIMAL(18,4) NULL,
        coverage_before_pct    DECIMAL(18,4) NULL,
        coverage_after_pct     DECIMAL(18,4) NULL,
        sla_before_pct         DECIMAL(18,4) NULL,
        sla_after_pct          DECIMAL(18,4) NULL,
        actual_impact_amount   DECIMAL(18,2) NULL,
        refreshed_at           DATETIME2(0) NOT NULL,

        CONSTRAINT PK_management_action_effect_data
            PRIMARY KEY (management_action_key)
    );
END;
GO

IF OBJECT_ID(N'mart.contract_timeline_data', N'U') IS NULL
BEGIN
    CREATE TABLE mart.contract_timeline_data
    (
        timeline_key        BIGINT IDENTITY(1,1) NOT NULL,
        reference_date      DATE NOT NULL,
        reference_month     DATE NOT NULL,
        contract_key        INT NOT NULL,
        contract_code       VARCHAR(20) NOT NULL,
        event_type          VARCHAR(30) NOT NULL,
        event_severity      VARCHAR(20) NOT NULL,
        event_title         NVARCHAR(160) NOT NULL,
        event_detail        NVARCHAR(700) NULL,
        impact_amount       DECIMAL(18,2) NULL,
        source_key          VARCHAR(100) NOT NULL,
        refreshed_at        DATETIME2(0) NOT NULL,

        CONSTRAINT PK_contract_timeline_data
            PRIMARY KEY (timeline_key)
    );

    CREATE INDEX IX_contract_timeline_contract_date
        ON mart.contract_timeline_data(contract_key, reference_date);
END;
GO

CREATE OR ALTER PROCEDURE mart.usp_refresh_management_action_effect
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    TRUNCATE TABLE mart.management_action_effect_data;

    INSERT INTO mart.management_action_effect_data
    (
        management_action_key,
        contract_key,
        contract_code,
        action_code,
        action_name_pt,
        start_date,
        completion_date,
        months_before,
        months_after,
        margin_before_pct,
        margin_after_pct,
        margin_delta_pp,
        overtime_before_pct,
        overtime_after_pct,
        coverage_before_pct,
        coverage_after_pct,
        sla_before_pct,
        sla_after_pct,
        actual_impact_amount,
        refreshed_at
    )
    SELECT
        management_action.management_action_key,
        management_action.contract_key,
        contract.contract_code,
        action.action_code,
        action.action_name_pt,
        start_date.full_date,
        completion_date.full_date,
        before_period.month_count,
        after_period.month_count,
        before_period.margin_pct,
        after_period.margin_pct,
        CONVERT
        (
            DECIMAL(18,2),
            (after_period.margin_pct - before_period.margin_pct) * 100
        ),
        before_period.overtime_pct,
        after_period.overtime_pct,
        before_period.coverage_pct,
        after_period.coverage_pct,
        before_period.sla_pct,
        after_period.sla_pct,
        management_action.actual_impact_amount,
        SYSDATETIME()
    FROM dw.fact_management_action AS management_action
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_key = management_action.contract_key
    INNER JOIN dw.dim_action AS action
        ON action.action_key = management_action.action_key
    INNER JOIN dw.dim_date AS start_date
        ON start_date.date_key = management_action.start_date_key
    INNER JOIN dw.dim_date AS completion_date
        ON completion_date.date_key = management_action.completion_date_key
    OUTER APPLY
    (
        SELECT
            COUNT(*) AS month_count,
            AVG(performance.contribution_margin_pct) AS margin_pct,
            AVG(performance.overtime_rate) AS overtime_pct,
            AVG(performance.coverage_rate) AS coverage_pct,
            AVG
            (
                CASE
                    WHEN performance.incident_count = 0 THEN 1.0000
                    ELSE performance.sla_compliance_rate
                END
            ) AS sla_pct
        FROM mart.vw_contract_monthly_performance AS performance
        WHERE performance.contract_key = management_action.contract_key
          AND performance.reference_month BETWEEN
              DATEADD
              (
                  MONTH,
                  -3,
                  DATEFROMPARTS(YEAR(start_date.full_date), MONTH(start_date.full_date), 1)
              )
              AND
              DATEADD
              (
                  MONTH,
                  -1,
                  DATEFROMPARTS(YEAR(start_date.full_date), MONTH(start_date.full_date), 1)
              )
    ) AS before_period
    OUTER APPLY
    (
        SELECT
            COUNT(*) AS month_count,
            AVG(performance.contribution_margin_pct) AS margin_pct,
            AVG(performance.overtime_rate) AS overtime_pct,
            AVG(performance.coverage_rate) AS coverage_pct,
            AVG
            (
                CASE
                    WHEN performance.incident_count = 0 THEN 1.0000
                    ELSE performance.sla_compliance_rate
                END
            ) AS sla_pct
        FROM mart.vw_contract_monthly_performance AS performance
        WHERE performance.contract_key = management_action.contract_key
          AND performance.reference_month BETWEEN
              DATEADD
              (
                  MONTH,
                  1,
                  DATEFROMPARTS
                  (
                      YEAR(completion_date.full_date),
                      MONTH(completion_date.full_date),
                      1
                  )
              )
              AND
              DATEADD
              (
                  MONTH,
                  3,
                  DATEFROMPARTS
                  (
                      YEAR(completion_date.full_date),
                      MONTH(completion_date.full_date),
                      1
                  )
              )
    ) AS after_period
    WHERE management_action.action_status = 'COMPLETED'
      AND management_action.start_date_key IS NOT NULL
      AND management_action.completion_date_key IS NOT NULL
      AND before_period.month_count > 0
      AND after_period.month_count > 0;
END;
GO

CREATE OR ALTER PROCEDURE mart.usp_refresh_contract_timeline
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    TRUNCATE TABLE mart.contract_timeline_data;

    WITH plan_change AS
    (
        SELECT
            month_plan.reference_month,
            month_plan.contract_code,
            month_plan.event_code,
            month_plan.event_note,
            LAG(month_plan.event_code) OVER
            (
                PARTITION BY month_plan.contract_code
                ORDER BY month_plan.reference_month
            ) AS previous_event_code
        FROM seed.contract_month_plan AS month_plan
    )
    INSERT INTO mart.contract_timeline_data
    (
        reference_date,
        reference_month,
        contract_key,
        contract_code,
        event_type,
        event_severity,
        event_title,
        event_detail,
        impact_amount,
        source_key,
        refreshed_at
    )
    SELECT
        plan_change.reference_month,
        plan_change.reference_month,
        contract.contract_key,
        plan_change.contract_code,
        'BUSINESS_EVENT',
        CASE
            WHEN plan_change.event_code LIKE '%CRITICAL%' THEN 'CRITICAL'
            WHEN plan_change.event_code LIKE '%DETERIORATION%'
              OR plan_change.event_code LIKE '%HIGH%'
              OR plan_change.event_code LIKE '%DEFICIT%'
                THEN 'HIGH'
            WHEN plan_change.event_code LIKE '%ACTION%'
              OR plan_change.event_code LIKE '%PENDING%'
              OR plan_change.event_code LIKE '%WARNING%'
                THEN 'ATTENTION'
            ELSE 'INFORMATION'
        END,
        REPLACE(plan_change.event_code, '_', ' '),
        plan_change.event_note,
        NULL,
        CONCAT
        (
            'PLAN-',
            plan_change.contract_code,
            '-',
            CONVERT(CHAR(6), plan_change.reference_month, 112)
        ),
        SYSDATETIME()
    FROM plan_change
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_code = plan_change.contract_code
       AND contract.is_current = 1
    WHERE plan_change.event_code <> 'ROUTINE'
      AND
      (
          plan_change.previous_event_code IS NULL
          OR plan_change.previous_event_code <> plan_change.event_code
      );

    INSERT INTO mart.contract_timeline_data
    (
        reference_date,
        reference_month,
        contract_key,
        contract_code,
        event_type,
        event_severity,
        event_title,
        event_detail,
        impact_amount,
        source_key,
        refreshed_at
    )
    SELECT
        event_date.full_date,
        event_date.month_start_date,
        adjustment.contract_key,
        contract.contract_code,
        'ADJUSTMENT',
        CASE adjustment.process_status
            WHEN 'APPROVED' THEN 'INFORMATION'
            WHEN 'REQUESTED' THEN 'ATTENTION'
            WHEN 'PENDING' THEN 'HIGH'
            ELSE 'INFORMATION'
        END,
        CONCAT
        (
            CASE adjustment.process_type
                WHEN 'ADJUSTMENT' THEN N'Reajuste'
                WHEN 'REPACTUATION' THEN N'Repactuação'
                ELSE N'Renegociação'
            END,
            N' — ',
            CASE adjustment.process_status
                WHEN 'APPROVED' THEN N'aprovado'
                WHEN 'REQUESTED' THEN N'solicitado'
                WHEN 'PENDING' THEN N'pendente'
                ELSE LOWER(adjustment.process_status)
            END
        ),
        adjustment.pending_reason,
        CASE
            WHEN adjustment.process_status = 'APPROVED'
                THEN adjustment.retroactive_amount
            ELSE adjustment.previous_amount * COALESCE(adjustment.requested_pct, 0)
        END,
        adjustment.adjustment_number,
        SYSDATETIME()
    FROM dw.fact_adjustment AS adjustment
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_key = adjustment.contract_key
    INNER JOIN dw.dim_date AS event_date
        ON event_date.date_key =
            COALESCE
            (
                adjustment.approved_date_key,
                adjustment.requested_date_key,
                adjustment.expected_date_key
            );

    INSERT INTO mart.contract_timeline_data
    (
        reference_date,
        reference_month,
        contract_key,
        contract_code,
        event_type,
        event_severity,
        event_title,
        event_detail,
        impact_amount,
        source_key,
        refreshed_at
    )
    SELECT
        recommendation_date.full_date,
        recommendation_date.month_start_date,
        management_action.contract_key,
        contract.contract_code,
        'MANAGEMENT_ACTION',
        CASE management_action.action_status
            WHEN 'COMPLETED' THEN 'INFORMATION'
            WHEN 'IN_PROGRESS' THEN 'ATTENTION'
            ELSE 'INFORMATION'
        END,
        action.action_name_pt,
        CONCAT
        (
            N'Status: ',
            management_action.action_status,
            N'. Resultado: ',
            COALESCE(management_action.standardized_result, N'não informado'),
            N'.'
        ),
        COALESCE
        (
            management_action.actual_impact_amount,
            management_action.estimated_impact_amount
        ),
        CONCAT('ACTION-', management_action.management_action_key),
        SYSDATETIME()
    FROM dw.fact_management_action AS management_action
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_key = management_action.contract_key
    INNER JOIN dw.dim_action AS action
        ON action.action_key = management_action.action_key
    INNER JOIN dw.dim_date AS recommendation_date
        ON recommendation_date.date_key = management_action.recommendation_date_key;

    INSERT INTO mart.contract_timeline_data
    (
        reference_date,
        reference_month,
        contract_key,
        contract_code,
        event_type,
        event_severity,
        event_title,
        event_detail,
        impact_amount,
        source_key,
        refreshed_at
    )
    SELECT
        sla.opened_at,
        opened_date.month_start_date,
        sla.contract_key,
        contract.contract_code,
        'SLA',
        sla.severity,
        CONCAT(N'Ocorrência crítica — ', incident_type.incident_subcategory),
        incident_type.root_cause,
        sla.deduction_amount + sla.penalty_amount + sla.emergency_cost,
        sla.incident_number,
        SYSDATETIME()
    FROM dw.fact_sla AS sla
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_key = sla.contract_key
    INNER JOIN dw.dim_incident_type AS incident_type
        ON incident_type.incident_type_key = sla.incident_type_key
    INNER JOIN dw.dim_date AS opened_date
        ON opened_date.date_key = sla.opened_date_key
    WHERE sla.severity = 'CRITICAL';

    WITH risk_change AS
    (
        SELECT
            risk.*,
            LAG(risk.risk_class) OVER
            (
                PARTITION BY risk.contract_key
                ORDER BY risk.reference_month
            ) AS previous_risk_class
        FROM mart.vw_contract_risk_score AS risk
    )
    INSERT INTO mart.contract_timeline_data
    (
        reference_date,
        reference_month,
        contract_key,
        contract_code,
        event_type,
        event_severity,
        event_title,
        event_detail,
        impact_amount,
        source_key,
        refreshed_at
    )
    SELECT
        risk_change.reference_month,
        risk_change.reference_month,
        risk_change.contract_key,
        risk_change.contract_code,
        'RISK_CHANGE',
        risk_change.risk_class,
        CONCAT(N'Risco alterado para ', risk_change.risk_class),
        CONCAT
        (
            N'Índice: ',
            CONVERT(VARCHAR(20), risk_change.contract_risk_score),
            N'. Margem: ',
            CONVERT(VARCHAR(30), risk_change.contribution_margin_pct * 100),
            N'%.'
        ),
        risk_change.margin_leakage_amount,
        CONCAT
        (
            'RISK-',
            risk_change.contract_code,
            '-',
            CONVERT(CHAR(6), risk_change.reference_month, 112)
        ),
        SYSDATETIME()
    FROM risk_change
    WHERE risk_change.risk_class IN ('HIGH', 'CRITICAL')
      AND
      (
          risk_change.previous_risk_class IS NULL
          OR risk_change.previous_risk_class <> risk_change.risk_class
      );
END;
GO

CREATE OR ALTER PROCEDURE mart.usp_refresh_phase04_marts
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    EXEC mart.usp_refresh_analytical_marts;

    /*
    A retroatividade do CT-002 foi conferida e encerrada em fevereiro de 2025.
    A regra original identifica corretamente o atraso, mas não conhecia o
    encerramento da ação. O ajuste abaixo evita manter uma recomendação já
    concluída nos meses seguintes.
    */
    UPDATE queue
    SET
        recommended_action_code = 'MAINTAIN',
        recommended_action_name_pt = maintain_action.action_name_pt,
        owner_area = maintain_action.default_owner_area,
        action_impact_amount = 0,
        action_recoverability_rate = 0.1000,
        action_recoverable_amount = 0,
        action_urgency_score = 10,
        action_priority_score = 10,
        action_reason_pt = N'A retroatividade já foi conferida e recebida. Não há nova pendência no período.'
    FROM mart.action_priority_queue_monthly_data AS queue
    CROSS JOIN
    (
        SELECT action_name_pt, default_owner_area
        FROM dw.dim_action
        WHERE action_code = 'MAINTAIN'
    ) AS maintain_action
    WHERE queue.recommended_action_code = 'REVIEW_RETROACTIVE'
      AND EXISTS
      (
          SELECT 1
          FROM dw.fact_management_action AS management_action
          INNER JOIN dw.dim_action AS completed_action
              ON completed_action.action_key = management_action.action_key
          INNER JOIN dw.dim_date AS completion_date
              ON completion_date.date_key = management_action.completion_date_key
          WHERE management_action.contract_key = queue.contract_key
            AND completed_action.action_code = 'REVIEW_RETROACTIVE'
            AND management_action.action_status = 'COMPLETED'
            AND completion_date.full_date <= EOMONTH(queue.reference_month)
      );

    TRUNCATE TABLE mart.action_priority_queue_data;
    INSERT INTO mart.action_priority_queue_data
    SELECT * FROM mart.calc_action_priority_queue;

    TRUNCATE TABLE mart.executive_summary_data;
    INSERT INTO mart.executive_summary_data
    SELECT * FROM mart.calc_executive_summary;

    TRUNCATE TABLE mart.contract_portfolio_data;
    INSERT INTO mart.contract_portfolio_data
    SELECT * FROM mart.calc_contract_portfolio;

    EXEC mart.usp_refresh_management_action_effect;
    EXEC mart.usp_refresh_contract_timeline;
END;
GO

CREATE OR ALTER VIEW mart.vw_management_action_effect
AS
SELECT
    management_action_key,
    contract_key,
    contract_code,
    action_code,
    action_name_pt,
    start_date,
    completion_date,
    months_before,
    months_after,
    margin_before_pct,
    margin_after_pct,
    margin_delta_pp,
    overtime_before_pct,
    overtime_after_pct,
    coverage_before_pct,
    coverage_after_pct,
    sla_before_pct,
    sla_after_pct,
    actual_impact_amount,
    refreshed_at
FROM mart.management_action_effect_data;
GO

CREATE OR ALTER VIEW mart.vw_contract_timeline
AS
SELECT
    timeline_key,
    reference_date,
    reference_month,
    contract_key,
    contract_code,
    event_type,
    event_severity,
    event_title,
    event_detail,
    impact_amount,
    source_key,
    refreshed_at
FROM mart.contract_timeline_data;
GO

CREATE OR ALTER VIEW mart.vw_contract_event_annotation
AS
SELECT
    month_plan.reference_month,
    contract.contract_key,
    month_plan.contract_code,
    month_plan.event_code,
    month_plan.event_note
FROM seed.contract_month_plan AS month_plan
INNER JOIN dw.dim_contract AS contract
    ON contract.contract_code = month_plan.contract_code
   AND contract.is_current = 1;
GO

EXEC mart.usp_refresh_phase04_marts;
GO
