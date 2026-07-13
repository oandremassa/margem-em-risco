USE margem_em_risco;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF SCHEMA_ID(N'config') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA config AUTHORIZATION dbo;');
END;
GO

IF OBJECT_ID(N'config.risk_parameter', N'U') IS NULL
BEGIN
    CREATE TABLE config.risk_parameter
    (
        parameter_code      VARCHAR(60) NOT NULL,
        parameter_value     DECIMAL(18,6) NOT NULL,
        parameter_unit      VARCHAR(20) NOT NULL,
        parameter_group     VARCHAR(30) NOT NULL,
        description_pt      NVARCHAR(300) NOT NULL,
        updated_at          DATETIME2(0) NOT NULL
            CONSTRAINT DF_risk_parameter_updated_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_risk_parameter PRIMARY KEY (parameter_code),
        CONSTRAINT CK_risk_parameter_value CHECK (parameter_value >= 0)
    );
END;
GO

IF OBJECT_ID(N'config.loss_recovery_rate', N'U') IS NULL
BEGIN
    CREATE TABLE config.loss_recovery_rate
    (
        loss_code           VARCHAR(50) NOT NULL,
        loss_name_pt        NVARCHAR(120) NOT NULL,
        recovery_rate       DECIMAL(9,4) NOT NULL,
        loss_nature         VARCHAR(20) NOT NULL,
        description_pt      NVARCHAR(300) NOT NULL,
        updated_at          DATETIME2(0) NOT NULL
            CONSTRAINT DF_loss_recovery_updated_at DEFAULT SYSDATETIME(),

        CONSTRAINT PK_loss_recovery_rate PRIMARY KEY (loss_code),
        CONSTRAINT CK_loss_recovery_rate CHECK (recovery_rate BETWEEN 0 AND 1),
        CONSTRAINT CK_loss_recovery_nature CHECK (loss_nature IN ('DIRECT', 'ESTIMATE'))
    );
END;
GO
