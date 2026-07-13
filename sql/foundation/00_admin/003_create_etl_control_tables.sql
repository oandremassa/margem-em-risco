USE margem_em_risco;
GO

IF OBJECT_ID(N'etl.batch_control', N'U') IS NULL
BEGIN
    CREATE TABLE etl.batch_control
    (
        batch_id            INT IDENTITY(1,1) NOT NULL,
        source_name         VARCHAR(100) NOT NULL,
        source_file         VARCHAR(255) NOT NULL,
        reference_period    DATE NULL,
        started_at          DATETIME2(0) NOT NULL
            CONSTRAINT DF_batch_control_started_at DEFAULT SYSDATETIME(),
        finished_at         DATETIME2(0) NULL,
        status              VARCHAR(20) NOT NULL,
        rows_received       INT NULL,
        rows_loaded         INT NULL,
        rows_rejected       INT NULL,
        error_message       NVARCHAR(2000) NULL,

        CONSTRAINT PK_batch_control PRIMARY KEY (batch_id),
        CONSTRAINT CK_batch_control_status
            CHECK (status IN ('RUNNING', 'SUCCESS', 'FAILED', 'PARTIAL')),
        CONSTRAINT CK_batch_control_counts
            CHECK
            (
                (rows_received IS NULL OR rows_received >= 0)
                AND (rows_loaded IS NULL OR rows_loaded >= 0)
                AND (rows_rejected IS NULL OR rows_rejected >= 0)
            )
    );
END;
GO

IF OBJECT_ID(N'etl.rejected_record', N'U') IS NULL
BEGIN
    CREATE TABLE etl.rejected_record
    (
        rejection_id        BIGINT IDENTITY(1,1) NOT NULL,
        batch_id            INT NOT NULL,
        source_table        VARCHAR(128) NOT NULL,
        source_record_id    VARCHAR(100) NULL,
        source_row_number   INT NULL,
        field_name          VARCHAR(128) NULL,
        received_value      NVARCHAR(1000) NULL,
        rejection_reason    NVARCHAR(1000) NOT NULL,
        rejected_at         DATETIME2(0) NOT NULL
            CONSTRAINT DF_rejected_record_rejected_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_rejected_record PRIMARY KEY (rejection_id),
        CONSTRAINT FK_rejected_record_batch
            FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id),
        CONSTRAINT CK_rejected_record_row_number
            CHECK (source_row_number IS NULL OR source_row_number > 0)
    );
END;
GO

IF OBJECT_ID(N'etl.test_result', N'U') IS NULL
BEGIN
    CREATE TABLE etl.test_result
    (
        test_result_id      BIGINT IDENTITY(1,1) NOT NULL,
        batch_id            INT NULL,
        test_name           VARCHAR(150) NOT NULL,
        test_group          VARCHAR(50) NOT NULL,
        expected_result     VARCHAR(100) NULL,
        actual_result       VARCHAR(100) NULL,
        passed              BIT NOT NULL,
        executed_at         DATETIME2(0) NOT NULL
            CONSTRAINT DF_test_result_executed_at DEFAULT SYSDATETIME(),
        details             NVARCHAR(1000) NULL,

        CONSTRAINT PK_test_result PRIMARY KEY (test_result_id),
        CONSTRAINT FK_test_result_batch
            FOREIGN KEY (batch_id) REFERENCES etl.batch_control(batch_id)
    );
END;
GO
