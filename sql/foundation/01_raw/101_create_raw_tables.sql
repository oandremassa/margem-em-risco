USE margem_em_risco;
GO

IF OBJECT_ID(N'raw.contract_register', N'U') IS NULL
BEGIN
    CREATE TABLE raw.contract_register
    (
        raw_contract_id          BIGINT IDENTITY(1,1) NOT NULL,
        batch_id                 INT NOT NULL,
        contract_code            VARCHAR(100) NULL,
        client_code              VARCHAR(100) NULL,
        client_name              NVARCHAR(255) NULL,
        unit_code                VARCHAR(100) NULL,
        service_code             VARCHAR(100) NULL,
        manager_code             VARCHAR(100) NULL,
        contract_status          VARCHAR(100) NULL,
        billing_model            VARCHAR(100) NULL,
        complexity_level         VARCHAR(100) NULL,
        start_date               VARCHAR(50) NULL,
        end_date                 VARCHAR(50) NULL,
        renewal_date             VARCHAR(50) NULL,
        base_monthly_amount      VARCHAR(100) NULL,
        contracted_positions     VARCHAR(100) NULL,
        contracted_hours         VARCHAR(100) NULL,
        target_margin_pct        VARCHAR(100) NULL,
        adjustment_base_month    VARCHAR(100) NULL,
        adjustment_index         VARCHAR(100) NULL,
        state_code               VARCHAR(50) NULL,
        source_row_number        INT NULL,
        loaded_at                DATETIME2(0) NOT NULL
            CONSTRAINT DF_raw_contract_loaded_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_raw_contract_register PRIMARY KEY (raw_contract_id),
        CONSTRAINT FK_raw_contract_register_batch
            FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id)
    );
END;
GO

IF OBJECT_ID(N'raw.monthly_measurements', N'U') IS NULL
BEGIN
    CREATE TABLE raw.monthly_measurements
    (
        raw_measurement_id       BIGINT IDENTITY(1,1) NOT NULL,
        batch_id                 INT NOT NULL,
        contract_code            VARCHAR(100) NULL,
        reference_period         VARCHAR(50) NULL,
        measurement_number       VARCHAR(100) NULL,
        contracted_amount        VARCHAR(100) NULL,
        additional_services      VARCHAR(100) NULL,
        reimbursements           VARCHAR(100) NULL,
        commercial_discounts     VARCHAR(100) NULL,
        deductions               VARCHAR(100) NULL,
        penalties                VARCHAR(100) NULL,
        invoiced_amount          VARCHAR(100) NULL,
        received_amount          VARCHAR(100) NULL,
        invoice_date             VARCHAR(50) NULL,
        payment_date             VARCHAR(50) NULL,
        source_row_number        INT NULL,
        loaded_at                DATETIME2(0) NOT NULL
            CONSTRAINT DF_raw_measurement_loaded_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_raw_monthly_measurements PRIMARY KEY (raw_measurement_id),
        CONSTRAINT FK_raw_monthly_measurements_batch
            FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id)
    );
END;
GO

IF OBJECT_ID(N'raw.operational_costs', N'U') IS NULL
BEGIN
    CREATE TABLE raw.operational_costs
    (
        raw_cost_id              BIGINT IDENTITY(1,1) NOT NULL,
        batch_id                 INT NOT NULL,
        contract_code            VARCHAR(100) NULL,
        unit_code                VARCHAR(100) NULL,
        reference_period         VARCHAR(50) NULL,
        cost_group               NVARCHAR(150) NULL,
        cost_category            NVARCHAR(150) NULL,
        cost_subcategory         NVARCHAR(150) NULL,
        actual_amount            VARCHAR(100) NULL,
        budget_amount            VARCHAR(100) NULL,
        source_system            VARCHAR(100) NULL,
        recurring_flag           NVARCHAR(50) NULL,
        extraordinary_flag       NVARCHAR(50) NULL,
        allocation_flag          NVARCHAR(50) NULL,
        entry_type               NVARCHAR(50) NULL,
        source_row_number        INT NULL,
        loaded_at                DATETIME2(0) NOT NULL
            CONSTRAINT DF_raw_cost_loaded_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_raw_operational_costs PRIMARY KEY (raw_cost_id),
        CONSTRAINT FK_raw_operational_costs_batch
            FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id)
    );
END;
GO

IF OBJECT_ID(N'raw.workforce_control', N'U') IS NULL
BEGIN
    CREATE TABLE raw.workforce_control
    (
        raw_operation_id         BIGINT IDENTITY(1,1) NOT NULL,
        batch_id                 INT NOT NULL,
        contract_code            VARCHAR(100) NULL,
        unit_code                VARCHAR(100) NULL,
        role_code                VARCHAR(100) NULL,
        reference_period         VARCHAR(50) NULL,
        planned_positions        VARCHAR(100) NULL,
        filled_positions         VARCHAR(100) NULL,
        average_headcount        VARCHAR(100) NULL,
        planned_hours            VARCHAR(100) NULL,
        regular_hours            VARCHAR(100) NULL,
        overtime_hours           VARCHAR(100) NULL,
        absence_hours            VARCHAR(100) NULL,
        leave_days               VARCHAR(100) NULL,
        hires                    VARCHAR(100) NULL,
        terminations             VARCHAR(100) NULL,
        open_positions           VARCHAR(100) NULL,
        average_replacement_days VARCHAR(100) NULL,
        emergency_coverage_cost  VARCHAR(100) NULL,
        source_row_number        INT NULL,
        loaded_at                DATETIME2(0) NOT NULL
            CONSTRAINT DF_raw_operation_loaded_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_raw_workforce_control PRIMARY KEY (raw_operation_id),
        CONSTRAINT FK_raw_workforce_control_batch
            FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id)
    );
END;
GO

IF OBJECT_ID(N'raw.sla_incidents', N'U') IS NULL
BEGIN
    CREATE TABLE raw.sla_incidents
    (
        raw_incident_id          BIGINT IDENTITY(1,1) NOT NULL,
        batch_id                 INT NOT NULL,
        incident_number          VARCHAR(100) NULL,
        contract_code            VARCHAR(100) NULL,
        unit_code                VARCHAR(100) NULL,
        incident_category        NVARCHAR(150) NULL,
        incident_subcategory     NVARCHAR(150) NULL,
        root_cause               NVARCHAR(150) NULL,
        opened_at                VARCHAR(50) NULL,
        closed_at                VARCHAR(50) NULL,
        agreed_deadline_hours    VARCHAR(100) NULL,
        severity                 NVARCHAR(100) NULL,
        incident_status          NVARCHAR(100) NULL,
        recurrence_flag          NVARCHAR(50) NULL,
        deduction_amount         VARCHAR(100) NULL,
        penalty_amount           VARCHAR(100) NULL,
        emergency_cost           VARCHAR(100) NULL,
        source_row_number        INT NULL,
        loaded_at                DATETIME2(0) NOT NULL
            CONSTRAINT DF_raw_incident_loaded_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_raw_sla_incidents PRIMARY KEY (raw_incident_id),
        CONSTRAINT FK_raw_sla_incidents_batch
            FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id)
    );
END;
GO

IF OBJECT_ID(N'raw.contract_adjustments', N'U') IS NULL
BEGIN
    CREATE TABLE raw.contract_adjustments
    (
        raw_adjustment_id        BIGINT IDENTITY(1,1) NOT NULL,
        batch_id                 INT NOT NULL,
        adjustment_number        VARCHAR(100) NULL,
        contract_code            VARCHAR(100) NULL,
        process_type             NVARCHAR(100) NULL,
        expected_date            VARCHAR(50) NULL,
        requested_date           VARCHAR(50) NULL,
        approved_date            VARCHAR(50) NULL,
        requested_pct            VARCHAR(100) NULL,
        approved_pct             VARCHAR(100) NULL,
        previous_amount          VARCHAR(100) NULL,
        approved_amount          VARCHAR(100) NULL,
        retroactive_flag         NVARCHAR(50) NULL,
        retroactive_amount       VARCHAR(100) NULL,
        process_status           NVARCHAR(100) NULL,
        pending_reason           NVARCHAR(500) NULL,
        source_row_number        INT NULL,
        loaded_at                DATETIME2(0) NOT NULL
            CONSTRAINT DF_raw_adjustment_loaded_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_raw_contract_adjustments PRIMARY KEY (raw_adjustment_id),
        CONSTRAINT FK_raw_contract_adjustments_batch
            FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id)
    );
END;
GO
