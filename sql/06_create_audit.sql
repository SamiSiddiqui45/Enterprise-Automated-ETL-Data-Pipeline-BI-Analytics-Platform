-- ============================================================================
-- Script: 06_create_audit.sql
-- Project: Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform
-- Purpose: Create audit tables for ETL orchestration, run logs, and rejected records
-- Author: Senior Data Engineer & Database Architect
-- ============================================================================

USE AnalyticsDW;
GO

-- 1. Pipeline Execution Log
IF NOT EXISTS (SELECT * FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'etl' AND t.name = 'PipelineRuns')
BEGIN
    CREATE TABLE etl.PipelineRuns (
        RunID               BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_etl_PipelineRuns PRIMARY KEY CLUSTERED,
        StartTime           DATETIME2(3) NOT NULL CONSTRAINT DF_etl_PipelineRuns_StartTime DEFAULT SYSUTCDATETIME(),
        EndTime             DATETIME2(3) NULL,
        Status              VARCHAR(20) NOT NULL, -- 'RUNNING', 'SUCCESS', 'FAILED', 'PARTIAL'
        SourceFileName      VARCHAR(255) NOT NULL,
        SourceRowCount      INT NULL,
        StagingRowCount     INT NULL,
        DimCustomerCount    INT NULL,
        DimProductCount     INT NULL,
        DimGeographyCount   INT NULL,
        DimShipModeCount    INT NULL,
        FactRowCount        INT NULL,
        RejectedRowCount    INT NULL,
        ErrorMessage        NVARCHAR(MAX) NULL
    );
    PRINT 'Table [etl].[PipelineRuns] created.';
END
ELSE
BEGIN
    PRINT 'Table [etl].[PipelineRuns] already exists.';
END
GO

-- 2. Quarantined Rejected Records
IF NOT EXISTS (SELECT * FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'etl' AND t.name = 'RejectedRecords')
BEGIN
    CREATE TABLE etl.RejectedRecords (
        RejectionID         BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_etl_RejectedRecords PRIMARY KEY CLUSTERED,
        ETLRunID            BIGINT NOT NULL,
        SourceRowID         INT NULL,
        OrderID             VARCHAR(50) NULL,
        RejectionReason     VARCHAR(255) NOT NULL,
        RejectedColumn      VARCHAR(100) NULL,
        RejectedValue       NVARCHAR(500) NULL,
        RawRecordJSON       NVARCHAR(MAX) NULL,
        LoggedAt            DATETIME2(3) NOT NULL CONSTRAINT DF_etl_RejectedRecords_LoggedAt DEFAULT SYSUTCDATETIME()
    );
    PRINT 'Table [etl].[RejectedRecords] created.';
END
ELSE
BEGIN
    PRINT 'Table [etl].[RejectedRecords] already exists.';
END
GO
