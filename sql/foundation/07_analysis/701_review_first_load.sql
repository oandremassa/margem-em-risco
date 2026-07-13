USE margem_em_risco;
GO

SELECT
    reference_month,
    contract_code,
    client_name,
    service_name,
    net_revenue,
    total_cost,
    contribution_margin,
    contribution_margin_pct,
    target_margin_pct,
    margin_gap_pct,
    overtime_rate,
    absenteeism_rate,
    open_positions,
    critical_incident_count,
    revenue_penalties,
    open_adjustment_count
FROM mart.vw_contract_monthly_base
WHERE reference_month = '2025-01-01'
ORDER BY contribution_margin_pct;
GO

SELECT
    batch.batch_id,
    batch.source_name,
    batch.status,
    batch.rows_received,
    batch.rows_loaded,
    batch.rows_rejected
FROM etl.batch_control AS batch
WHERE batch.batch_id IN
(
    SELECT MAX(batch_id)
    FROM etl.batch_control
    WHERE source_name IN
    (
        'contract_register',
        'monthly_measurements',
        'operational_costs',
        'workforce_control',
        'sla_incidents',
        'contract_adjustments'
    )
    GROUP BY source_name
)
ORDER BY batch.batch_id;
GO

SELECT
    batch.source_name,
    rejected.source_row_number,
    rejected.received_value,
    rejected.rejection_reason
FROM etl.rejected_record AS rejected
INNER JOIN etl.batch_control AS batch
    ON batch.batch_id = rejected.batch_id
WHERE rejected.batch_id IN
(
    SELECT MAX(batch_id)
    FROM etl.batch_control
    WHERE source_name IN
    (
        'contract_register',
        'monthly_measurements',
        'operational_costs',
        'workforce_control',
        'sla_incidents',
        'contract_adjustments'
    )
    GROUP BY source_name
)
ORDER BY
    batch.source_name,
    rejected.source_row_number;
GO
