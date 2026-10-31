-- ============================================================================
-- Script: 03_create_staging.sql
-- Project: Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform
-- Purpose: Create staging table stg.OrdersRaw for landing raw CSV records
-- Author: Senior Data Engineer & Database Architect
-- ============================================================================

USE AnalyticsDW;
GO

IF NOT EXISTS (SELECT * FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'stg' AND t.name = 'OrdersRaw')
BEGIN
    CREATE TABLE stg.OrdersRaw (
        StagingID           INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_stg_OrdersRaw PRIMARY KEY CLUSTERED,
        RowID               INT NOT NULL,
        OrderID             VARCHAR(50) NOT NULL,
        OrderDateRaw        VARCHAR(50) NOT NULL,
        ShipDateRaw         VARCHAR(50) NOT NULL,
        ShipMode            VARCHAR(50) NOT NULL,
        CustomerID          VARCHAR(50) NOT NULL,
        CustomerName        VARCHAR(100) NOT NULL,
        Segment             VARCHAR(50) NOT NULL,
        Country             VARCHAR(50) NOT NULL,
        City                VARCHAR(100) NOT NULL,
        State               VARCHAR(100) NOT NULL,
        PostalCodeRaw       VARCHAR(20) NOT NULL,
        Region              VARCHAR(50) NOT NULL,
        ProductID           VARCHAR(50) NOT NULL,
        Category            VARCHAR(50) NOT NULL,
        SubCategory         VARCHAR(50) NOT NULL,
        ProductName         VARCHAR(255) NOT NULL,
        SalesRaw            VARCHAR(50) NOT NULL,
        QuantityRaw         VARCHAR(50) NOT NULL,
        DiscountRaw         VARCHAR(50) NOT NULL,
        ProfitRaw           VARCHAR(50) NOT NULL,
        ETLRunID            BIGINT NOT NULL,
        IngestionTimestamp  DATETIME2(3) NOT NULL CONSTRAINT DF_stg_OrdersRaw_IngestionTimestamp DEFAULT SYSUTCDATETIME()
    );
    PRINT 'Table [stg].[OrdersRaw] created successfully.';
END
ELSE
BEGIN
    PRINT 'Table [stg].[OrdersRaw] already exists.';
END
GO
