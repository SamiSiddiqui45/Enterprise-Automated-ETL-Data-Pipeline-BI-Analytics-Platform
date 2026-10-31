-- ============================================================================
-- Script: 02_create_schemas.sql
-- Project: Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform
-- Purpose: Safely create schemas (stg, dw, etl) in AnalyticsDW
-- Author: Senior Data Engineer & Database Architect
-- ============================================================================

USE AnalyticsDW;
GO

-- 1. Staging Schema: Landing area for raw ingested source data
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'stg')
BEGIN
    EXEC('CREATE SCHEMA stg;');
    PRINT 'Schema [stg] created.';
END
ELSE
BEGIN
    PRINT 'Schema [stg] already exists.';
END
GO

-- 2. Data Warehouse Schema: Star Schema dimensions and fact tables
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'dw')
BEGIN
    EXEC('CREATE SCHEMA dw;');
    PRINT 'Schema [dw] created.';
END
ELSE
BEGIN
    PRINT 'Schema [dw] already exists.';
END
GO

-- 3. ETL Audit Schema: Pipeline tracking, run logs, and quarantined rejected records
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'etl')
BEGIN
    EXEC('CREATE SCHEMA etl;');
    PRINT 'Schema [etl] created.';
END
ELSE
BEGIN
    PRINT 'Schema [etl] already exists.';
END
GO
