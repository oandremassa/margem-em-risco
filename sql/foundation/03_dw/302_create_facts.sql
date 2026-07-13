USE margem_em_risco;
GO

IF OBJECT_ID(N'dw.fact_revenue', N'U') IS NULL
BEGIN
    CREATE TABLE dw.fact_revenue
    (
        revenue_key              BIGINT IDENTITY(1,1) NOT NULL,
        date_key                 INT NOT NULL,
        contract_key             INT NOT NULL,
        batch_id                 INT NOT NULL,
        measurement_number       VARCHAR(30) NOT NULL,
        contracted_amount        DECIMAL(18,2) NOT NULL,
        additional_services      DECIMAL(18,2) NOT NULL,
        reimbursements           DECIMAL(18,2) NOT NULL,
        commercial_discounts     DECIMAL(18,2) NOT NULL,
        deductions               DECIMAL(18,2) NOT NULL,
        penalties                DECIMAL(18,2) NOT NULL,
        gross_revenue            DECIMAL(18,2) NOT NULL,
        net_revenue              DECIMAL(18,2) NOT NULL,
        invoiced_amount          DECIMAL(18,2) NOT NULL,
        received_amount          DECIMAL(18,2) NULL,
        invoice_date             DATE NULL,
        payment_date             DATE NULL,
        payment_days             INT NULL,
        loaded_at                DATETIME2(0) NOT NULL
            CONSTRAINT DF_fact_revenue_loaded_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_fact_revenue PRIMARY KEY (revenue_key),
        CONSTRAINT UQ_fact_revenue_measurement UNIQUE
            (contract_key, date_key, measurement_number),
        CONSTRAINT FK_fact_revenue_date FOREIGN KEY (date_key) REFERENCES dw.dim_date(date_key),
        CONSTRAINT FK_fact_revenue_contract FOREIGN KEY (contract_key) REFERENCES dw.dim_contract(contract_key),
        CONSTRAINT FK_fact_revenue_batch FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id),
        CONSTRAINT CK_fact_revenue_nonnegative CHECK
        (
            contracted_amount >= 0
            AND additional_services >= 0
            AND reimbursements >= 0
            AND commercial_discounts >= 0
            AND deductions >= 0
            AND penalties >= 0
            AND gross_revenue >= 0
            AND invoiced_amount >= 0
            AND (received_amount IS NULL OR received_amount >= 0)
        ),
        CONSTRAINT CK_fact_revenue_formula CHECK
        (
            gross_revenue = contracted_amount + additional_services + reimbursements
            AND net_revenue = gross_revenue - commercial_discounts - deductions - penalties
        )
    );
END;
GO

IF OBJECT_ID(N'dw.fact_contract_cost', N'U') IS NULL
BEGIN
    CREATE TABLE dw.fact_contract_cost
    (
        contract_cost_key        BIGINT IDENTITY(1,1) NOT NULL,
        date_key                 INT NOT NULL,
        contract_key             INT NOT NULL,
        unit_key                 INT NOT NULL,
        cost_category_key        INT NOT NULL,
        batch_id                 INT NOT NULL,
        actual_amount            DECIMAL(18,2) NOT NULL,
        budget_amount            DECIMAL(18,2) NULL,
        source_system            VARCHAR(30) NOT NULL,
        is_recurring             BIT NOT NULL,
        is_extraordinary         BIT NOT NULL,
        is_allocation            BIT NOT NULL,
        entry_type               VARCHAR(20) NOT NULL,
        loaded_at                DATETIME2(0) NOT NULL
            CONSTRAINT DF_fact_cost_loaded_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_fact_contract_cost PRIMARY KEY (contract_cost_key),
        CONSTRAINT FK_fact_cost_date FOREIGN KEY (date_key) REFERENCES dw.dim_date(date_key),
        CONSTRAINT FK_fact_cost_contract FOREIGN KEY (contract_key) REFERENCES dw.dim_contract(contract_key),
        CONSTRAINT FK_fact_cost_unit FOREIGN KEY (unit_key) REFERENCES dw.dim_unit(unit_key),
        CONSTRAINT FK_fact_cost_category FOREIGN KEY (cost_category_key) REFERENCES dw.dim_cost_category(cost_category_key),
        CONSTRAINT FK_fact_cost_batch FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id),
        CONSTRAINT CK_fact_cost_entry_type CHECK (entry_type IN ('DEBIT', 'REVERSAL')),
        CONSTRAINT CK_fact_cost_sign CHECK
        (
            (entry_type = 'DEBIT' AND actual_amount >= 0)
            OR (entry_type = 'REVERSAL' AND actual_amount <= 0)
        )
    );
END;
GO

IF OBJECT_ID(N'dw.fact_operation', N'U') IS NULL
BEGIN
    CREATE TABLE dw.fact_operation
    (
        operation_key             BIGINT IDENTITY(1,1) NOT NULL,
        date_key                  INT NOT NULL,
        contract_key              INT NOT NULL,
        unit_key                  INT NOT NULL,
        role_key                  INT NOT NULL,
        batch_id                  INT NOT NULL,
        planned_positions         DECIMAL(10,2) NOT NULL,
        filled_positions          DECIMAL(10,2) NOT NULL,
        uncovered_positions       DECIMAL(10,2) NOT NULL,
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
        loaded_at                 DATETIME2(0) NOT NULL
            CONSTRAINT DF_fact_operation_loaded_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_fact_operation PRIMARY KEY (operation_key),
        CONSTRAINT UQ_fact_operation_business UNIQUE
            (date_key, contract_key, unit_key, role_key),
        CONSTRAINT FK_fact_operation_date FOREIGN KEY (date_key) REFERENCES dw.dim_date(date_key),
        CONSTRAINT FK_fact_operation_contract FOREIGN KEY (contract_key) REFERENCES dw.dim_contract(contract_key),
        CONSTRAINT FK_fact_operation_unit FOREIGN KEY (unit_key) REFERENCES dw.dim_unit(unit_key),
        CONSTRAINT FK_fact_operation_role FOREIGN KEY (role_key) REFERENCES dw.dim_role(role_key),
        CONSTRAINT FK_fact_operation_batch FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id),
        CONSTRAINT CK_fact_operation_nonnegative CHECK
        (
            planned_positions >= 0
            AND filled_positions >= 0
            AND uncovered_positions >= 0
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
        )
    );
END;
GO

IF OBJECT_ID(N'dw.fact_sla', N'U') IS NULL
BEGIN
    CREATE TABLE dw.fact_sla
    (
        sla_key                  BIGINT IDENTITY(1,1) NOT NULL,
        opened_date_key          INT NOT NULL,
        closed_date_key          INT NULL,
        contract_key             INT NOT NULL,
        unit_key                 INT NOT NULL,
        incident_type_key        INT NOT NULL,
        batch_id                 INT NOT NULL,
        incident_number          VARCHAR(30) NOT NULL,
        opened_at                DATETIME2(0) NOT NULL,
        closed_at                DATETIME2(0) NULL,
        agreed_deadline_hours    DECIMAL(10,2) NOT NULL,
        resolution_hours         DECIMAL(18,2) NULL,
        severity                 VARCHAR(20) NOT NULL,
        incident_status          VARCHAR(20) NOT NULL,
        resolved_within_sla      BIT NOT NULL,
        is_recurrence            BIT NOT NULL,
        deduction_amount         DECIMAL(18,2) NOT NULL,
        penalty_amount           DECIMAL(18,2) NOT NULL,
        emergency_cost           DECIMAL(18,2) NOT NULL,
        loaded_at                DATETIME2(0) NOT NULL
            CONSTRAINT DF_fact_sla_loaded_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_fact_sla PRIMARY KEY (sla_key),
        CONSTRAINT UQ_fact_sla_incident UNIQUE (incident_number),
        CONSTRAINT FK_fact_sla_opened_date FOREIGN KEY (opened_date_key) REFERENCES dw.dim_date(date_key),
        CONSTRAINT FK_fact_sla_closed_date FOREIGN KEY (closed_date_key) REFERENCES dw.dim_date(date_key),
        CONSTRAINT FK_fact_sla_contract FOREIGN KEY (contract_key) REFERENCES dw.dim_contract(contract_key),
        CONSTRAINT FK_fact_sla_unit FOREIGN KEY (unit_key) REFERENCES dw.dim_unit(unit_key),
        CONSTRAINT FK_fact_sla_incident_type FOREIGN KEY (incident_type_key) REFERENCES dw.dim_incident_type(incident_type_key),
        CONSTRAINT FK_fact_sla_batch FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id),
        CONSTRAINT CK_fact_sla_dates CHECK (closed_at IS NULL OR closed_at >= opened_at),
        CONSTRAINT CK_fact_sla_nonnegative CHECK
        (
            agreed_deadline_hours >= 0
            AND (resolution_hours IS NULL OR resolution_hours >= 0)
            AND deduction_amount >= 0
            AND penalty_amount >= 0
            AND emergency_cost >= 0
        ),
        CONSTRAINT CK_fact_sla_severity CHECK
            (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
        CONSTRAINT CK_fact_sla_status CHECK
            (incident_status IN ('OPEN', 'IN_PROGRESS', 'CLOSED', 'CANCELLED'))
    );
END;
GO

IF OBJECT_ID(N'dw.fact_adjustment', N'U') IS NULL
BEGIN
    CREATE TABLE dw.fact_adjustment
    (
        adjustment_key           BIGINT IDENTITY(1,1) NOT NULL,
        expected_date_key        INT NOT NULL,
        requested_date_key       INT NULL,
        approved_date_key        INT NULL,
        contract_key             INT NOT NULL,
        batch_id                 INT NOT NULL,
        adjustment_number        VARCHAR(30) NOT NULL,
        process_type             VARCHAR(30) NOT NULL,
        requested_pct            DECIMAL(9,4) NULL,
        approved_pct             DECIMAL(9,4) NULL,
        previous_amount          DECIMAL(18,2) NOT NULL,
        approved_amount          DECIMAL(18,2) NULL,
        is_retroactive           BIT NOT NULL,
        retroactive_amount       DECIMAL(18,2) NOT NULL,
        process_status           VARCHAR(20) NOT NULL,
        pending_reason           NVARCHAR(500) NULL,
        loaded_at                DATETIME2(0) NOT NULL
            CONSTRAINT DF_fact_adjustment_loaded_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_fact_adjustment PRIMARY KEY (adjustment_key),
        CONSTRAINT UQ_fact_adjustment_number UNIQUE (adjustment_number),
        CONSTRAINT FK_fact_adjustment_expected_date FOREIGN KEY (expected_date_key) REFERENCES dw.dim_date(date_key),
        CONSTRAINT FK_fact_adjustment_requested_date FOREIGN KEY (requested_date_key) REFERENCES dw.dim_date(date_key),
        CONSTRAINT FK_fact_adjustment_approved_date FOREIGN KEY (approved_date_key) REFERENCES dw.dim_date(date_key),
        CONSTRAINT FK_fact_adjustment_contract FOREIGN KEY (contract_key) REFERENCES dw.dim_contract(contract_key),
        CONSTRAINT FK_fact_adjustment_batch FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id),
        CONSTRAINT CK_fact_adjustment_process_type CHECK
            (process_type IN ('ADJUSTMENT', 'REPACTUATION', 'RENEGOTIATION')),
        CONSTRAINT CK_fact_adjustment_status CHECK
            (process_status IN ('PENDING', 'REQUESTED', 'APPROVED', 'REJECTED', 'CANCELLED')),
        CONSTRAINT CK_fact_adjustment_percentages CHECK
        (
            (requested_pct IS NULL OR requested_pct BETWEEN 0 AND 1)
            AND (approved_pct IS NULL OR approved_pct BETWEEN 0 AND 1)
        ),
        CONSTRAINT CK_fact_adjustment_amounts CHECK
        (
            previous_amount > 0
            AND (approved_amount IS NULL OR approved_amount > 0)
            AND retroactive_amount >= 0
        )
    );
END;
GO

IF OBJECT_ID(N'dw.fact_management_action', N'U') IS NULL
BEGIN
    CREATE TABLE dw.fact_management_action
    (
        management_action_key    BIGINT IDENTITY(1,1) NOT NULL,
        recommendation_date_key  INT NOT NULL,
        start_date_key           INT NULL,
        completion_date_key      INT NULL,
        contract_key             INT NOT NULL,
        action_key               INT NOT NULL,
        batch_id                 INT NULL,
        action_status            VARCHAR(20) NOT NULL,
        estimated_impact_amount  DECIMAL(18,2) NULL,
        actual_impact_amount     DECIMAL(18,2) NULL,
        standardized_result      VARCHAR(50) NULL,
        owner_area               VARCHAR(50) NOT NULL,
        loaded_at                DATETIME2(0) NOT NULL
            CONSTRAINT DF_fact_management_action_loaded_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_fact_management_action PRIMARY KEY (management_action_key),
        CONSTRAINT FK_fact_action_recommendation_date FOREIGN KEY (recommendation_date_key) REFERENCES dw.dim_date(date_key),
        CONSTRAINT FK_fact_action_start_date FOREIGN KEY (start_date_key) REFERENCES dw.dim_date(date_key),
        CONSTRAINT FK_fact_action_completion_date FOREIGN KEY (completion_date_key) REFERENCES dw.dim_date(date_key),
        CONSTRAINT FK_fact_action_contract FOREIGN KEY (contract_key) REFERENCES dw.dim_contract(contract_key),
        CONSTRAINT FK_fact_action_action FOREIGN KEY (action_key) REFERENCES dw.dim_action(action_key),
        CONSTRAINT FK_fact_action_batch FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id),
        CONSTRAINT CK_fact_action_status CHECK
            (action_status IN ('RECOMMENDED', 'PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
        CONSTRAINT CK_fact_action_amounts CHECK
        (
            (estimated_impact_amount IS NULL OR estimated_impact_amount >= 0)
            AND (actual_impact_amount IS NULL OR actual_impact_amount >= 0)
        )
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_fact_revenue_date_contract'
      AND object_id = OBJECT_ID(N'dw.fact_revenue')
)
BEGIN
    CREATE INDEX IX_fact_revenue_date_contract
        ON dw.fact_revenue(date_key, contract_key);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_fact_cost_date_contract'
      AND object_id = OBJECT_ID(N'dw.fact_contract_cost')
)
BEGIN
    CREATE INDEX IX_fact_cost_date_contract
        ON dw.fact_contract_cost(date_key, contract_key)
        INCLUDE (cost_category_key, actual_amount);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_fact_operation_date_contract'
      AND object_id = OBJECT_ID(N'dw.fact_operation')
)
BEGIN
    CREATE INDEX IX_fact_operation_date_contract
        ON dw.fact_operation(date_key, contract_key)
        INCLUDE (planned_hours, overtime_hours, absence_hours, uncovered_positions);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_fact_sla_contract_opened_date'
      AND object_id = OBJECT_ID(N'dw.fact_sla')
)
BEGIN
    CREATE INDEX IX_fact_sla_contract_opened_date
        ON dw.fact_sla(contract_key, opened_date_key)
        INCLUDE (severity, resolved_within_sla, penalty_amount, deduction_amount);
END;
GO
