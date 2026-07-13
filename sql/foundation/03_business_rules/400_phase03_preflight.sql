USE master;
GO

IF DB_ID(N'margem_em_risco') IS NULL
BEGIN
    THROW 51000, 'Banco margem_em_risco nao encontrado. Execute as fases anteriores antes da Fase 03.', 1;
END;
GO

USE margem_em_risco;
GO

DECLARE @missing_objects NVARCHAR(2000) = N'';

IF OBJECT_ID(N'dw.dim_contract', N'U') IS NULL
BEGIN
    SET @missing_objects = @missing_objects + N'dw.dim_contract; ';
END;
IF OBJECT_ID(N'dw.fact_revenue', N'U') IS NULL
BEGIN
    SET @missing_objects = @missing_objects + N'dw.fact_revenue; ';
END;
IF OBJECT_ID(N'dw.fact_contract_cost', N'U') IS NULL
BEGIN
    SET @missing_objects = @missing_objects + N'dw.fact_contract_cost; ';
END;
IF OBJECT_ID(N'dw.fact_operation', N'U') IS NULL
BEGIN
    SET @missing_objects = @missing_objects + N'dw.fact_operation; ';
END;
IF OBJECT_ID(N'dw.fact_sla', N'U') IS NULL
BEGIN
    SET @missing_objects = @missing_objects + N'dw.fact_sla; ';
END;
IF OBJECT_ID(N'dw.fact_adjustment', N'U') IS NULL
BEGIN
    SET @missing_objects = @missing_objects + N'dw.fact_adjustment; ';
END;
IF OBJECT_ID(N'mart.vw_contract_monthly_base', N'V') IS NULL
BEGIN
    SET @missing_objects = @missing_objects + N'mart.vw_contract_monthly_base; ';
END;

IF LEN(@missing_objects) > 0
BEGIN
    DECLARE @object_error NVARCHAR(2048) = N'Objetos obrigatorios ausentes: ' + @missing_objects;
    THROW 51001, @object_error, 1;
END;

IF (SELECT COUNT(*) FROM dw.dim_contract WHERE is_current = 1) < 10
BEGIN
    THROW 51002, 'Carga de contratos incompleta. A Fase 03 espera pelo menos 10 contratos atuais.', 1;
END;

IF (SELECT COUNT(*) FROM dw.fact_revenue) < 10
BEGIN
    THROW 51003, 'Carga financeira incompleta. Conclua o processamento da Fase 02 antes de continuar.', 1;
END;

IF (SELECT COUNT(*) FROM dw.fact_contract_cost) < 50
BEGIN
    THROW 51004, 'Carga de custos incompleta. Conclua o processamento da Fase 02 antes de continuar.', 1;
END;

PRINT 'Preflight da Fase 03 concluido.';
GO
