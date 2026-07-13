USE margem_em_risco;
GO

IF OBJECT_ID(N'staging.stg_contract', N'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_contract
    (
        stg_contract_id           BIGINT IDENTITY(1,1) NOT NULL,
        raw_contract_id           BIGINT NOT NULL,
        batch_id                  INT NOT NULL,
        contract_code             VARCHAR(20) NOT NULL,
        client_code               VARCHAR(20) NOT NULL,
        client_name               NVARCHAR(150) NOT NULL,
        unit_code                 VARCHAR(20) NOT NULL,
        service_code              VARCHAR(20) NOT NULL,
        manager_code              VARCHAR(20) NOT NULL,
        contract_status           VARCHAR(30) NOT NULL,
        billing_model             VARCHAR(30) NOT NULL,
        complexity_level          VARCHAR(20) NOT NULL,
        start_date                DATE NOT NULL,
        end_date                  DATE NULL,
        renewal_date              DATE NULL,
        base_monthly_amount       DECIMAL(18,2) NOT NULL,
        contracted_positions      DECIMAL(10,2) NOT NULL,
        contracted_hours          DECIMAL(18,2) NOT NULL,
        target_margin_pct         DECIMAL(9,4) NOT NULL,
        adjustment_base_month     TINYINT NULL,
        adjustment_index          VARCHAR(30) NULL,
        state_code                CHAR(2) NOT NULL,
        valid_from                DATE NOT NULL,
        row_hash                  VARBINARY(32) NOT NULL,
        record_status             VARCHAR(20) NOT NULL,

        CONSTRAINT PK_stg_contract PRIMARY KEY (stg_contract_id),
        CONSTRAINT UQ_stg_contract_batch_code UNIQUE (batch_id, contract_code),
        CONSTRAINT CK_stg_contract_margin CHECK (target_margin_pct BETWEEN 0 AND 1),
        CONSTRAINT CK_stg_contract_positions CHECK (contracted_positions >= 0),
        CONSTRAINT CK_stg_contract_hours CHECK (contracted_hours >= 0),
        CONSTRAINT CK_stg_contract_amount CHECK (base_monthly_amount > 0),
        CONSTRAINT CK_stg_contract_month CHECK
            (adjustment_base_month IS NULL OR adjustment_base_month BETWEEN 1 AND 12),
        CONSTRAINT CK_stg_contract_status CHECK
            (record_status IN ('VALID', 'REJECTED'))
    );
END;
GO

IF OBJECT_ID(N'staging.stg_measurement', N'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_measurement
    (
        stg_measurement_id        BIGINT IDENTITY(1,1) NOT NULL,
        raw_measurement_id        BIGINT NOT NULL,
        batch_id                  INT NOT NULL,
        contract_code             VARCHAR(20) NOT NULL,
        reference_month           DATE NOT NULL,
        measurement_number        VARCHAR(30) NOT NULL,
        contracted_amount         DECIMAL(18,2) NOT NULL,
        additional_services       DECIMAL(18,2) NOT NULL,
        reimbursements            DECIMAL(18,2) NOT NULL,
        commercial_discounts      DECIMAL(18,2) NOT NULL,
        deductions                DECIMAL(18,2) NOT NULL,
        penalties                 DECIMAL(18,2) NOT NULL,
        gross_revenue             AS
            (contracted_amount + additional_services + reimbursements) PERSISTED,
        net_revenue               AS
            (contracted_amount + additional_services + reimbursements
             - commercial_discounts - deductions - penalties) PERSISTED,
        invoiced_amount           DECIMAL(18,2) NOT NULL,
        received_amount           DECIMAL(18,2) NULL,
        invoice_date              DATE NULL,
        payment_date              DATE NULL,
        payment_days              AS
            (CASE
                WHEN invoice_date IS NOT NULL AND payment_date IS NOT NULL
                THEN DATEDIFF(DAY, invoice_date, payment_date)
             END) PERSISTED,
        record_status             VARCHAR(20) NOT NULL,

        CONSTRAINT PK_stg_measurement PRIMARY KEY (stg_measurement_id),
        CONSTRAINT UQ_stg_measurement_business
            UNIQUE (batch_id, contract_code, reference_month, measurement_number),
        CONSTRAINT CK_stg_measurement_nonnegative CHECK
        (
            contracted_amount >= 0
            AND additional_services >= 0
            AND reimbursements >= 0
            AND commercial_discounts >= 0
            AND deductions >= 0
            AND penalties >= 0
            AND invoiced_amount >= 0
            AND (received_amount IS NULL OR received_amount >= 0)
        ),
        CONSTRAINT CK_stg_measurement_status CHECK
            (record_status IN ('VALID', 'REJECTED'))
    );
END;
GO

IF OBJECT_ID(N'staging.stg_cost', N'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_cost
    (
        stg_cost_id               BIGINT IDENTITY(1,1) NOT NULL,
        raw_cost_id               BIGINT NOT NULL,
        batch_id                  INT NOT NULL,
        contract_code             VARCHAR(20) NOT NULL,
        unit_code                 VARCHAR(20) NOT NULL,
        reference_month           DATE NOT NULL,
        cost_group                NVARCHAR(60) NOT NULL,
        cost_category             NVARCHAR(80) NOT NULL,
        cost_subcategory          NVARCHAR(100) NOT NULL,
        actual_amount             DECIMAL(18,2) NOT NULL,
        budget_amount             DECIMAL(18,2) NULL,
        source_system             VARCHAR(30) NOT NULL,
        is_recurring              BIT NOT NULL,
        is_extraordinary          BIT NOT NULL,
        is_allocation             BIT NOT NULL,
        entry_type                VARCHAR(20) NOT NULL,
        record_status             VARCHAR(20) NOT NULL,

        CONSTRAINT PK_stg_cost PRIMARY KEY (stg_cost_id),
        CONSTRAINT CK_stg_cost_entry_type CHECK (entry_type IN ('DEBIT', 'REVERSAL')),
        CONSTRAINT CK_stg_cost_status CHECK (record_status IN ('VALID', 'REJECTED')),
        CONSTRAINT CK_stg_cost_sign CHECK
        (
            (entry_type = 'DEBIT' AND actual_amount >= 0)
            OR (entry_type = 'REVERSAL' AND actual_amount <= 0)
        )
    );
END;
GO

IF OBJECT_ID(N'staging.stg_operation', N'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_operation
    (
        stg_operation_id          BIGINT IDENTITY(1,1) NOT NULL,
        raw_operation_id          BIGINT NOT NULL,
        batch_id                  INT NOT NULL,
        contract_code             VARCHAR(20) NOT NULL,
        unit_code                 VARCHAR(20) NOT NULL,
        role_code                 VARCHAR(20) NOT NULL,
        reference_month           DATE NOT NULL,
        planned_positions         DECIMAL(10,2) NOT NULL,
        filled_positions          DECIMAL(10,2) NOT NULL,
        uncovered_positions       AS
            (CASE
                WHEN planned_positions - filled_positions > 0
                THEN planned_positions - filled_positions
                ELSE CONVERT(DECIMAL(10,2), 0)
             END) PERSISTED,
        average_headcount         DECIMAL(10,2) NULL,
        planned_hours             DECIMAL(18,2) NOT NULL,
        regular_hours             DECIMAL(18,2) NOT NULL,
        overtime_hours            DECIMAL(18,2) NOT NULL,
        absence_hours             DECIMAL(18,2) NOT NULL,
        leave_days                INT NOT NULL,
        hires                     INT NOT NULL,
        terminations              INT NOT NULL,
        open_positions            INT NOT NULL,
        average_replacement_days  DECIMAL(10,2) NULL,
        emergency_coverage_cost   DECIMAL(18,2) NOT NULL,
        record_status             VARCHAR(20) NOT NULL,

        CONSTRAINT PK_stg_operation PRIMARY KEY (stg_operation_id),
        CONSTRAINT UQ_stg_operation_business
            UNIQUE (batch_id, contract_code, unit_code, role_code, reference_month),
        CONSTRAINT CK_stg_operation_nonnegative CHECK
        (
            planned_positions >= 0
            AND filled_positions >= 0
            AND (average_headcount IS NULL OR average_headcount >= 0)
            AND planned_hours >= 0
            AND regular_hours >= 0
            AND overtime_hours >= 0
            AND absence_hours >= 0
            AND leave_days >= 0
            AND hires >= 0
            AND terminations >= 0
            AND open_positions >= 0
            AND (average_replacement_days IS NULL OR average_replacement_days >= 0)
            AND emergency_coverage_cost >= 0
        ),
        CONSTRAINT CK_stg_operation_status CHECK
            (record_status IN ('VALID', 'REJECTED'))
    );
END;
GO

IF OBJECT_ID(N'staging.stg_sla_incident', N'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_sla_incident
    (
        stg_incident_id           BIGINT IDENTITY(1,1) NOT NULL,
        raw_incident_id           BIGINT NOT NULL,
        batch_id                  INT NOT NULL,
        incident_number           VARCHAR(30) NOT NULL,
        contract_code             VARCHAR(20) NOT NULL,
        unit_code                 VARCHAR(20) NOT NULL,
        incident_category         NVARCHAR(80) NOT NULL,
        incident_subcategory      NVARCHAR(100) NOT NULL,
        root_cause                NVARCHAR(100) NOT NULL,
        opened_at                 DATETIME2(0) NOT NULL,
        closed_at                 DATETIME2(0) NULL,
        agreed_deadline_hours     DECIMAL(10,2) NOT NULL,
        severity                  VARCHAR(20) NOT NULL,
        incident_status           VARCHAR(20) NOT NULL,
        is_recurrence             BIT NOT NULL,
        deduction_amount          DECIMAL(18,2) NOT NULL,
        penalty_amount            DECIMAL(18,2) NOT NULL,
        emergency_cost            DECIMAL(18,2) NOT NULL,
        resolution_hours          AS
            (CASE
                WHEN closed_at IS NOT NULL
                THEN CONVERT(DECIMAL(18,2), DATEDIFF(MINUTE, opened_at, closed_at) / 60.0)
             END) PERSISTED,
        resolved_within_sla       AS
            (CASE
                WHEN closed_at IS NULL THEN CONVERT(BIT, 0)
                WHEN DATEDIFF(MINUTE, opened_at, closed_at) / 60.0 <= agreed_deadline_hours
                    THEN CONVERT(BIT, 1)
                ELSE CONVERT(BIT, 0)
             END) PERSISTED,
        record_status             VARCHAR(20) NOT NULL,

        CONSTRAINT PK_stg_sla_incident PRIMARY KEY (stg_incident_id),
        CONSTRAINT UQ_stg_sla_incident_business
            UNIQUE (batch_id, incident_number),
        CONSTRAINT CK_stg_sla_dates CHECK (closed_at IS NULL OR closed_at >= opened_at),
        CONSTRAINT CK_stg_sla_nonnegative CHECK
        (
            agreed_deadline_hours >= 0
            AND deduction_amount >= 0
            AND penalty_amount >= 0
            AND emergency_cost >= 0
        ),
        CONSTRAINT CK_stg_sla_severity CHECK
            (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
        CONSTRAINT CK_stg_sla_status CHECK
            (incident_status IN ('OPEN', 'IN_PROGRESS', 'CLOSED', 'CANCELLED')),
        CONSTRAINT CK_stg_sla_record_status CHECK
            (record_status IN ('VALID', 'REJECTED'))
    );
END;
GO

IF OBJECT_ID(N'staging.stg_adjustment', N'U') IS NULL
BEGIN
    CREATE TABLE staging.stg_adjustment
    (
        stg_adjustment_id         BIGINT IDENTITY(1,1) NOT NULL,
        raw_adjustment_id         BIGINT NOT NULL,
        batch_id                  INT NOT NULL,
        adjustment_number         VARCHAR(30) NOT NULL,
        contract_code             VARCHAR(20) NOT NULL,
        process_type              VARCHAR(30) NOT NULL,
        expected_date             DATE NOT NULL,
        requested_date            DATE NULL,
        approved_date             DATE NULL,
        requested_pct             DECIMAL(9,4) NULL,
        approved_pct              DECIMAL(9,4) NULL,
        previous_amount           DECIMAL(18,2) NOT NULL,
        approved_amount           DECIMAL(18,2) NULL,
        is_retroactive            BIT NOT NULL,
        retroactive_amount        DECIMAL(18,2) NOT NULL,
        process_status            VARCHAR(20) NOT NULL,
        pending_reason            NVARCHAR(500) NULL,
        record_status             VARCHAR(20) NOT NULL,

        CONSTRAINT PK_stg_adjustment PRIMARY KEY (stg_adjustment_id),
        CONSTRAINT UQ_stg_adjustment_business
            UNIQUE (batch_id, adjustment_number),
        CONSTRAINT CK_stg_adjustment_process_type CHECK
            (process_type IN ('ADJUSTMENT', 'REPACTUATION', 'RENEGOTIATION')),
        CONSTRAINT CK_stg_adjustment_process_status CHECK
            (process_status IN ('PENDING', 'REQUESTED', 'APPROVED', 'REJECTED', 'CANCELLED')),
        CONSTRAINT CK_stg_adjustment_percentages CHECK
        (
            (requested_pct IS NULL OR requested_pct BETWEEN 0 AND 1)
            AND (approved_pct IS NULL OR approved_pct BETWEEN 0 AND 1)
        ),
        CONSTRAINT CK_stg_adjustment_amounts CHECK
        (
            previous_amount > 0
            AND (approved_amount IS NULL OR approved_amount > 0)
            AND retroactive_amount >= 0
        ),
        CONSTRAINT CK_stg_adjustment_record_status CHECK
            (record_status IN ('VALID', 'REJECTED'))
    );
END;
GO
