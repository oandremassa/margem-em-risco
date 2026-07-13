/*
Recria somente o banco do projeto.
Nenhum outro banco da instancia e alterado.
*/
USE master;
GO

IF DB_ID(N'margem_em_risco') IS NOT NULL
BEGIN
    ALTER DATABASE margem_em_risco SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE margem_em_risco;
END;
GO

CREATE DATABASE margem_em_risco;
GO

ALTER DATABASE margem_em_risco SET RECOVERY SIMPLE;
GO

USE margem_em_risco;
GO
