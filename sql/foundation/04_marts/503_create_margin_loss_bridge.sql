USE margem_em_risco;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW mart.vw_margin_loss_bridge
AS
WITH loss_source AS
(
    SELECT
        performance.reference_month,
        performance.date_key,
        performance.contract_key,
        performance.contract_code,
        'OVERTIME_EXCESS' AS loss_code,
        performance.overtime_excess_cost AS loss_amount,
        CAST(0 AS BIT) AS is_estimate,
        N'Custo realizado de horas adicionais menos o orçamento da mesma categoria.' AS calculation_note
    FROM mart.vw_contract_monthly_performance AS performance

    UNION ALL

    SELECT
        performance.reference_month,
        performance.date_key,
        performance.contract_key,
        performance.contract_code,
        'EMERGENCY_COVERAGE_EXCESS',
        performance.emergency_coverage_excess_cost,
        CAST(0 AS BIT),
        N'Custo realizado de cobertura emergencial menos o orçamento da mesma categoria.'
    FROM mart.vw_contract_monthly_performance AS performance

    UNION ALL

    SELECT
        performance.reference_month,
        performance.date_key,
        performance.contract_key,
        performance.contract_code,
        'SLA_FINANCIAL_LOSS',
        performance.sla_financial_loss,
        CAST(0 AS BIT),
        N'Soma das glosas e multas ligadas às ocorrências de SLA do período.'
    FROM mart.vw_contract_monthly_performance AS performance

    UNION ALL

    SELECT
        performance.reference_month,
        performance.date_key,
        performance.contract_key,
        performance.contract_code,
        'COMMERCIAL_DISCOUNT',
        performance.commercial_discounts,
        CAST(0 AS BIT),
        N'Descontos comerciais concedidos na medição mensal.'
    FROM mart.vw_contract_monthly_performance AS performance

    UNION ALL

    SELECT
        performance.reference_month,
        performance.date_key,
        performance.contract_key,
        performance.contract_code,
        'OTHER_EXTRAORDINARY_COST',
        performance.other_extraordinary_cost,
        CAST(0 AS BIT),
        N'Custos extraordinários diferentes de horas adicionais e cobertura emergencial.'
    FROM mart.vw_contract_monthly_performance AS performance

    UNION ALL

    SELECT
        performance.reference_month,
        performance.date_key,
        performance.contract_key,
        performance.contract_code,
        'ADJUSTMENT_DELAY_ESTIMATE',
        performance.adjustment_delay_estimate,
        CAST(1 AS BIT),
        N'Percentual solicitado aplicado ao valor anterior e multiplicado pelos meses vencidos.'
    FROM mart.vw_contract_monthly_performance AS performance

    UNION ALL

    SELECT
        performance.reference_month,
        performance.date_key,
        performance.contract_key,
        performance.contract_code,
        'UNBILLED_SCOPE_ESTIMATE',
        performance.unbilled_scope_estimate,
        CAST(1 AS BIT),
        N'Horas executadas acima do previsto, valorizadas pela receita contratada por hora. Só é calculado sem faturamento adicional.'
    FROM mart.vw_contract_monthly_performance AS performance
)
SELECT
    loss.reference_month,
    loss.date_key,
    loss.contract_key,
    loss.contract_code,
    loss.loss_code,
    recovery.loss_name_pt,
    recovery.loss_nature,
    loss.is_estimate,
    CONVERT(DECIMAL(18,2), loss.loss_amount) AS loss_amount,
    recovery.recovery_rate,
    CONVERT(DECIMAL(18,2), loss.loss_amount * recovery.recovery_rate) AS recoverable_amount,
    loss.calculation_note
FROM loss_source AS loss
INNER JOIN config.loss_recovery_rate AS recovery
    ON recovery.loss_code = loss.loss_code
WHERE loss.loss_amount > 0;
GO
