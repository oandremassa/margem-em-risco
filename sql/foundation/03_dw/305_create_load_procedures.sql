USE margem_em_risco;
GO

CREATE OR ALTER PROCEDURE etl.usp_load_contract_batch
    @batch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    UPDATE target_contract
    SET
        client_key = client.client_key,
        manager_key = manager.manager_key,
        primary_service_key = service.service_key,
        contract_status = source_contract.contract_status,
        billing_model = source_contract.billing_model,
        complexity_level = source_contract.complexity_level,
        start_date = source_contract.start_date,
        end_date = source_contract.end_date,
        renewal_date = source_contract.renewal_date,
        base_monthly_amount = source_contract.base_monthly_amount,
        contracted_positions = source_contract.contracted_positions,
        contracted_hours = source_contract.contracted_hours,
        target_margin_pct = source_contract.target_margin_pct,
        adjustment_base_month = source_contract.adjustment_base_month,
        adjustment_index = source_contract.adjustment_index,
        row_hash = source_contract.row_hash
    FROM dw.dim_contract AS target_contract
    INNER JOIN staging.stg_contract AS source_contract
        ON source_contract.contract_code = target_contract.contract_code
       AND source_contract.batch_id = @batch_id
    INNER JOIN dw.dim_client AS client
        ON client.client_code = source_contract.client_code
    INNER JOIN dw.dim_manager AS manager
        ON manager.manager_code = source_contract.manager_code
    INNER JOIN dw.dim_service AS service
        ON service.service_code = source_contract.service_code
    WHERE target_contract.is_current = 1
      AND target_contract.valid_from = source_contract.valid_from
      AND target_contract.row_hash <> source_contract.row_hash;

    UPDATE target_contract
    SET
        valid_to = DATEADD(DAY, -1, source_contract.valid_from),
        is_current = 0
    FROM dw.dim_contract AS target_contract
    INNER JOIN staging.stg_contract AS source_contract
        ON source_contract.contract_code = target_contract.contract_code
       AND source_contract.batch_id = @batch_id
    WHERE target_contract.is_current = 1
      AND target_contract.row_hash <> source_contract.row_hash
      AND source_contract.valid_from > target_contract.valid_from;

    INSERT INTO dw.dim_contract
    (
        contract_code,
        client_key,
        manager_key,
        primary_service_key,
        contract_status,
        billing_model,
        complexity_level,
        start_date,
        end_date,
        renewal_date,
        base_monthly_amount,
        contracted_positions,
        contracted_hours,
        target_margin_pct,
        adjustment_base_month,
        adjustment_index,
        valid_from,
        valid_to,
        is_current,
        row_hash
    )
    SELECT
        source_contract.contract_code,
        client.client_key,
        manager.manager_key,
        service.service_key,
        source_contract.contract_status,
        source_contract.billing_model,
        source_contract.complexity_level,
        source_contract.start_date,
        source_contract.end_date,
        source_contract.renewal_date,
        source_contract.base_monthly_amount,
        source_contract.contracted_positions,
        source_contract.contracted_hours,
        source_contract.target_margin_pct,
        source_contract.adjustment_base_month,
        source_contract.adjustment_index,
        source_contract.valid_from,
        NULL,
        1,
        source_contract.row_hash
    FROM staging.stg_contract AS source_contract
    INNER JOIN dw.dim_client AS client
        ON client.client_code = source_contract.client_code
    INNER JOIN dw.dim_manager AS manager
        ON manager.manager_code = source_contract.manager_code
    INNER JOIN dw.dim_service AS service
        ON service.service_code = source_contract.service_code
    LEFT JOIN dw.dim_contract AS current_contract
        ON current_contract.contract_code = source_contract.contract_code
       AND current_contract.is_current = 1
    WHERE source_contract.batch_id = @batch_id
      AND current_contract.contract_key IS NULL;

    DELETE target_bridge
    FROM dw.bridge_contract_service AS target_bridge
    INNER JOIN dw.dim_contract AS current_contract
        ON current_contract.contract_key = target_bridge.contract_key
       AND current_contract.is_current = 1
    INNER JOIN staging.stg_contract AS source_contract
        ON source_contract.contract_code = current_contract.contract_code
       AND source_contract.batch_id = @batch_id;

    INSERT INTO dw.bridge_contract_service
    (
        contract_key,
        service_key,
        revenue_share_pct,
        cost_share_pct,
        is_primary_service,
        valid_from,
        valid_to
    )
    SELECT
        current_contract.contract_key,
        current_contract.primary_service_key,
        1.0000,
        1.0000,
        1,
        current_contract.valid_from,
        current_contract.valid_to
    FROM dw.dim_contract AS current_contract
    INNER JOIN staging.stg_contract AS source_contract
        ON source_contract.contract_code = current_contract.contract_code
       AND source_contract.batch_id = @batch_id
    WHERE current_contract.is_current = 1;

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_load_revenue_batch
    @batch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    DELETE target_revenue
    FROM dw.fact_revenue AS target_revenue
    INNER JOIN dw.dim_contract AS target_contract
        ON target_contract.contract_key = target_revenue.contract_key
    WHERE EXISTS
    (
        SELECT 1
        FROM staging.stg_measurement AS source_measurement
        WHERE source_measurement.batch_id = @batch_id
          AND source_measurement.contract_code = target_contract.contract_code
          AND target_revenue.date_key =
              CONVERT(INT, CONVERT(CHAR(8), source_measurement.reference_month, 112))
    );

    INSERT INTO dw.fact_revenue
    (
        date_key,
        contract_key,
        batch_id,
        measurement_number,
        contracted_amount,
        additional_services,
        reimbursements,
        commercial_discounts,
        deductions,
        penalties,
        gross_revenue,
        net_revenue,
        invoiced_amount,
        received_amount,
        invoice_date,
        payment_date,
        payment_days
    )
    SELECT
        date_dim.date_key,
        contract.contract_key,
        @batch_id,
        source_measurement.measurement_number,
        source_measurement.contracted_amount,
        source_measurement.additional_services,
        source_measurement.reimbursements,
        source_measurement.commercial_discounts,
        source_measurement.deductions,
        source_measurement.penalties,
        source_measurement.gross_revenue,
        source_measurement.net_revenue,
        source_measurement.invoiced_amount,
        source_measurement.received_amount,
        source_measurement.invoice_date,
        source_measurement.payment_date,
        source_measurement.payment_days
    FROM staging.stg_measurement AS source_measurement
    INNER JOIN dw.dim_date AS date_dim
        ON date_dim.full_date = source_measurement.reference_month
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_code = source_measurement.contract_code
       AND source_measurement.reference_month BETWEEN contract.valid_from AND COALESCE(contract.valid_to, '9999-12-31')
    WHERE source_measurement.batch_id = @batch_id;

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_load_cost_batch
    @batch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    DELETE target_cost
    FROM dw.fact_contract_cost AS target_cost
    INNER JOIN dw.dim_contract AS target_contract
        ON target_contract.contract_key = target_cost.contract_key
    WHERE EXISTS
    (
        SELECT 1
        FROM staging.stg_cost AS source_cost
        WHERE source_cost.batch_id = @batch_id
          AND source_cost.contract_code = target_contract.contract_code
          AND target_cost.date_key = CONVERT(INT, CONVERT(CHAR(8), source_cost.reference_month, 112))
    );

    INSERT INTO dw.fact_contract_cost
    (
        date_key,
        contract_key,
        unit_key,
        cost_category_key,
        batch_id,
        actual_amount,
        budget_amount,
        source_system,
        is_recurring,
        is_extraordinary,
        is_allocation,
        entry_type
    )
    SELECT
        date_dim.date_key,
        contract.contract_key,
        unit.unit_key,
        category.cost_category_key,
        @batch_id,
        source_cost.actual_amount,
        source_cost.budget_amount,
        source_cost.source_system,
        source_cost.is_recurring,
        source_cost.is_extraordinary,
        source_cost.is_allocation,
        source_cost.entry_type
    FROM staging.stg_cost AS source_cost
    INNER JOIN dw.dim_date AS date_dim
        ON date_dim.full_date = source_cost.reference_month
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_code = source_cost.contract_code
       AND source_cost.reference_month BETWEEN contract.valid_from AND COALESCE(contract.valid_to, '9999-12-31')
    INNER JOIN dw.dim_unit AS unit
        ON unit.unit_code = source_cost.unit_code
       AND unit.client_key = contract.client_key
    INNER JOIN dw.dim_cost_category AS category
        ON category.cost_group = source_cost.cost_group
       AND category.cost_category = source_cost.cost_category
       AND category.cost_subcategory = source_cost.cost_subcategory
    WHERE source_cost.batch_id = @batch_id;

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_load_operation_batch
    @batch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    DELETE target_operation
    FROM dw.fact_operation AS target_operation
    INNER JOIN staging.stg_operation AS source_operation
        ON source_operation.batch_id = @batch_id
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_key = target_operation.contract_key
       AND contract.contract_code = source_operation.contract_code
    INNER JOIN dw.dim_unit AS unit
        ON unit.unit_key = target_operation.unit_key
       AND unit.unit_code = source_operation.unit_code
    INNER JOIN dw.dim_role AS role
        ON role.role_key = target_operation.role_key
       AND role.role_code = source_operation.role_code
    WHERE target_operation.date_key =
        CONVERT(INT, CONVERT(CHAR(8), source_operation.reference_month, 112));

    INSERT INTO dw.fact_operation
    (
        date_key,
        contract_key,
        unit_key,
        role_key,
        batch_id,
        planned_positions,
        filled_positions,
        uncovered_positions,
        average_headcount,
        planned_hours,
        regular_hours,
        overtime_hours,
        absence_hours,
        leave_days,
        hires,
        terminations,
        open_positions,
        average_replacement_days,
        emergency_coverage_cost
    )
    SELECT
        date_dim.date_key,
        contract.contract_key,
        unit.unit_key,
        role.role_key,
        @batch_id,
        source_operation.planned_positions,
        source_operation.filled_positions,
        source_operation.uncovered_positions,
        source_operation.average_headcount,
        source_operation.planned_hours,
        source_operation.regular_hours,
        source_operation.overtime_hours,
        source_operation.absence_hours,
        source_operation.leave_days,
        source_operation.hires,
        source_operation.terminations,
        source_operation.open_positions,
        source_operation.average_replacement_days,
        source_operation.emergency_coverage_cost
    FROM staging.stg_operation AS source_operation
    INNER JOIN dw.dim_date AS date_dim
        ON date_dim.full_date = source_operation.reference_month
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_code = source_operation.contract_code
       AND source_operation.reference_month BETWEEN contract.valid_from AND COALESCE(contract.valid_to, '9999-12-31')
    INNER JOIN dw.dim_unit AS unit
        ON unit.unit_code = source_operation.unit_code
       AND unit.client_key = contract.client_key
    INNER JOIN dw.dim_role AS role
        ON role.role_code = source_operation.role_code
    WHERE source_operation.batch_id = @batch_id;

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_load_sla_batch
    @batch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    DELETE target_sla
    FROM dw.fact_sla AS target_sla
    INNER JOIN staging.stg_sla_incident AS source_sla
        ON source_sla.batch_id = @batch_id
       AND source_sla.incident_number = target_sla.incident_number;

    INSERT INTO dw.fact_sla
    (
        opened_date_key,
        closed_date_key,
        contract_key,
        unit_key,
        incident_type_key,
        batch_id,
        incident_number,
        opened_at,
        closed_at,
        agreed_deadline_hours,
        resolution_hours,
        severity,
        incident_status,
        resolved_within_sla,
        is_recurrence,
        deduction_amount,
        penalty_amount,
        emergency_cost
    )
    SELECT
        opened_date.date_key,
        closed_date.date_key,
        contract.contract_key,
        unit.unit_key,
        incident_type.incident_type_key,
        @batch_id,
        source_sla.incident_number,
        source_sla.opened_at,
        source_sla.closed_at,
        source_sla.agreed_deadline_hours,
        source_sla.resolution_hours,
        source_sla.severity,
        source_sla.incident_status,
        source_sla.resolved_within_sla,
        source_sla.is_recurrence,
        source_sla.deduction_amount,
        source_sla.penalty_amount,
        source_sla.emergency_cost
    FROM staging.stg_sla_incident AS source_sla
    INNER JOIN dw.dim_date AS opened_date
        ON opened_date.full_date = CONVERT(DATE, source_sla.opened_at)
    LEFT JOIN dw.dim_date AS closed_date
        ON closed_date.full_date = CONVERT(DATE, source_sla.closed_at)
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_code = source_sla.contract_code
       AND CONVERT(DATE, source_sla.opened_at) BETWEEN contract.valid_from AND COALESCE(contract.valid_to, '9999-12-31')
    INNER JOIN dw.dim_unit AS unit
        ON unit.unit_code = source_sla.unit_code
       AND unit.client_key = contract.client_key
    INNER JOIN dw.dim_incident_type AS incident_type
        ON incident_type.incident_category = source_sla.incident_category
       AND incident_type.incident_subcategory = source_sla.incident_subcategory
       AND incident_type.root_cause = source_sla.root_cause
    WHERE source_sla.batch_id = @batch_id;

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_load_adjustment_batch
    @batch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    DELETE target_adjustment
    FROM dw.fact_adjustment AS target_adjustment
    INNER JOIN staging.stg_adjustment AS source_adjustment
        ON source_adjustment.batch_id = @batch_id
       AND source_adjustment.adjustment_number = target_adjustment.adjustment_number;

    INSERT INTO dw.fact_adjustment
    (
        expected_date_key,
        requested_date_key,
        approved_date_key,
        contract_key,
        batch_id,
        adjustment_number,
        process_type,
        requested_pct,
        approved_pct,
        previous_amount,
        approved_amount,
        is_retroactive,
        retroactive_amount,
        process_status,
        pending_reason
    )
    SELECT
        expected_date.date_key,
        requested_date.date_key,
        approved_date.date_key,
        contract.contract_key,
        @batch_id,
        source_adjustment.adjustment_number,
        source_adjustment.process_type,
        source_adjustment.requested_pct,
        source_adjustment.approved_pct,
        source_adjustment.previous_amount,
        source_adjustment.approved_amount,
        source_adjustment.is_retroactive,
        source_adjustment.retroactive_amount,
        source_adjustment.process_status,
        source_adjustment.pending_reason
    FROM staging.stg_adjustment AS source_adjustment
    INNER JOIN dw.dim_date AS expected_date
        ON expected_date.full_date = source_adjustment.expected_date
    LEFT JOIN dw.dim_date AS requested_date
        ON requested_date.full_date = source_adjustment.requested_date
    LEFT JOIN dw.dim_date AS approved_date
        ON approved_date.full_date = source_adjustment.approved_date
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_code = source_adjustment.contract_code
       AND source_adjustment.expected_date BETWEEN contract.valid_from AND COALESCE(contract.valid_to, '9999-12-31')
    WHERE source_adjustment.batch_id = @batch_id;

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_finish_batch
    @batch_id INT,
    @raw_table SYSNAME,
    @staging_table SYSNAME
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @received INT;
    DECLARE @loaded INT;
    DECLARE @rejected INT;
    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'SELECT @count_out = COUNT(*) FROM ' + QUOTENAME(PARSENAME(@raw_table, 2))
             + N'.' + QUOTENAME(PARSENAME(@raw_table, 1)) + N' WHERE batch_id = @batch_id_in;';

    EXEC sys.sp_executesql
        @sql,
        N'@batch_id_in INT, @count_out INT OUTPUT',
        @batch_id_in = @batch_id,
        @count_out = @received OUTPUT;

    SET @sql = N'SELECT @count_out = COUNT(*) FROM ' + QUOTENAME(PARSENAME(@staging_table, 2))
             + N'.' + QUOTENAME(PARSENAME(@staging_table, 1)) + N' WHERE batch_id = @batch_id_in;';

    EXEC sys.sp_executesql
        @sql,
        N'@batch_id_in INT, @count_out INT OUTPUT',
        @batch_id_in = @batch_id,
        @count_out = @loaded OUTPUT;

    SELECT @rejected = COUNT(*)
    FROM etl.rejected_record
    WHERE batch_id = @batch_id;

    UPDATE etl.batch_control
    SET
        finished_at = SYSDATETIME(),
        status = CASE WHEN @rejected > 0 THEN 'PARTIAL' ELSE 'SUCCESS' END,
        rows_received = @received,
        rows_loaded = @loaded,
        rows_rejected = @rejected,
        error_message = NULL
    WHERE batch_id = @batch_id;
END;
GO
