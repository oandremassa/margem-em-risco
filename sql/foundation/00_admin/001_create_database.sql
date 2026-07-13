/*
Projeto: Margem em Risco
Objetivo: criar o banco local usado pelo projeto.
Execução: SQL Server / SSMS / sqlcmd.
*/

USE master;
GO

IF DB_ID(N'margem_em_risco') IS NULL
BEGIN
    CREATE DATABASE margem_em_risco;
END;
GO

ALTER DATABASE margem_em_risco SET RECOVERY SIMPLE;
GO

USE margem_em_risco;
GO
