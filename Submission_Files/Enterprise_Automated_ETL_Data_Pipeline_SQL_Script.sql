-- ============================================================================
-- Project: Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform
-- Author: Sami Siddiqui (@SamiSiddiqui45)
-- Target Database Engine: Microsoft SQL Server Express (.\SQLEXPRESS)
-- Database Name: AnalyticsDW
-- Purpose: Complete Master Database Setup, Schemas, Star Schema, Fact Table,
--          Audit Tables, Performance Indexes, Validation & Reconciliation Queries
-- ============================================================================


-- ============================================================================
-- SECTION: sql/01_create_database.sql
-- ============================================================================
-- ============================================================================
-- Script: 01_create_database.sql
-- Project: Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform
-- Purpose: Safely create AnalyticsDW database if it does not exist
-- Author: Senior Data Engineer & Database Architect
-- ============================================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'AnalyticsDW')
BEGIN
    PRINT 'Creating database AnalyticsDW...';
    CREATE DATABASE AnalyticsDW
    COLLATE SQL_Latin1_General_CP1_CI_AS;
    PRINT 'Database AnalyticsDW created successfully.';
END
ELSE
BEGIN
    PRINT 'Database AnalyticsDW already exists. Skipping creation to protect existing state.';
END
GO



-- ============================================================================
-- SECTION: sql/02_create_schemas.sql
-- ============================================================================
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



-- ============================================================================
-- SECTION: sql/03_create_staging.sql
-- ============================================================================
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



-- ============================================================================
-- SECTION: sql/04_create_dimensions.sql
-- ============================================================================
-- ============================================================================
-- Script: 04_create_dimensions.sql
-- Project: Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform
-- Purpose: Create and initialize dimension tables (DimDate, DimCustomer, DimProduct, DimGeography, DimShipMode)
-- Author: Senior Data Engineer & Database Architect
-- ============================================================================

USE AnalyticsDW;
GO

-- 1. DimDate: Continuous Calendar Dimension
IF NOT EXISTS (SELECT * FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dw' AND t.name = 'DimDate')
BEGIN
    CREATE TABLE dw.DimDate (
        DateKey         INT NOT NULL CONSTRAINT PK_dw_DimDate PRIMARY KEY CLUSTERED, -- YYYYMMDD
        FullDate        DATE NOT NULL CONSTRAINT UQ_dw_DimDate_FullDate UNIQUE,
        [Year]          SMALLINT NOT NULL,
        [Quarter]       TINYINT NOT NULL,
        QuarterName     CHAR(2) NOT NULL,      -- 'Q1', 'Q2', 'Q3', 'Q4'
        [Month]         TINYINT NOT NULL,
        MonthName       VARCHAR(20) NOT NULL,  -- 'January', 'February', etc.
        MonthShort      CHAR(3) NOT NULL,      -- 'Jan', 'Feb', etc.
        YearMonth       CHAR(7) NOT NULL,      -- '2016-11'
        WeekOfYear      TINYINT NOT NULL,
        DayOfMonth      TINYINT NOT NULL,
        DayOfWeek       TINYINT NOT NULL,      -- 1 = Sunday, 7 = Saturday
        DayOfWeekName   VARCHAR(20) NOT NULL,  -- 'Monday', 'Tuesday', etc.
        IsWeekend       BIT NOT NULL           -- 1 = Weekend, 0 = Weekday
    );
    PRINT 'Table [dw].[DimDate] created.';
END
ELSE
BEGIN
    PRINT 'Table [dw].[DimDate] already exists.';
END
GO

-- Populate DimDate continuously from 2013-01-01 through 2020-12-31 if empty
IF NOT EXISTS (SELECT 1 FROM dw.DimDate)
BEGIN
    PRINT 'Populating dw.DimDate with calendar dates (2013-2020)...';
    WITH DateRange AS (
        SELECT CAST('2013-01-01' AS DATE) AS CalendarDate
        UNION ALL
        SELECT DATEADD(day, 1, CalendarDate)
        FROM DateRange
        WHERE CalendarDate < '2020-12-31'
    )
    INSERT INTO dw.DimDate (
        DateKey,
        FullDate,
        [Year],
        [Quarter],
        QuarterName,
        [Month],
        MonthName,
        MonthShort,
        YearMonth,
        WeekOfYear,
        DayOfMonth,
        DayOfWeek,
        DayOfWeekName,
        IsWeekend
    )
    SELECT
        CAST(CONVERT(VARCHAR(8), CalendarDate, 112) AS INT) AS DateKey,
        CalendarDate AS FullDate,
        DATEPART(year, CalendarDate) AS [Year],
        DATEPART(quarter, CalendarDate) AS [Quarter],
        'Q' + CAST(DATEPART(quarter, CalendarDate) AS CHAR(1)) AS QuarterName,
        DATEPART(month, CalendarDate) AS [Month],
        DATENAME(month, CalendarDate) AS MonthName,
        LEFT(DATENAME(month, CalendarDate), 3) AS MonthShort,
        LEFT(CONVERT(VARCHAR(10), CalendarDate, 120), 7) AS YearMonth,
        DATEPART(week, CalendarDate) AS WeekOfYear,
        DATEPART(day, CalendarDate) AS DayOfMonth,
        DATEPART(weekday, CalendarDate) AS DayOfWeek,
        DATENAME(weekday, CalendarDate) AS DayOfWeekName,
        CASE WHEN DATEPART(weekday, CalendarDate) IN (1, 7) THEN 1 ELSE 0 END AS IsWeekend
    FROM DateRange
    OPTION (MAXRECURSION 3500);

    PRINT 'Calendar dimension successfully populated with ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' dates.';
END
GO

-- 2. DimCustomer: Customer Dimension
IF NOT EXISTS (SELECT * FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dw' AND t.name = 'DimCustomer')
BEGIN
    CREATE TABLE dw.DimCustomer (
        CustomerKey     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dw_DimCustomer PRIMARY KEY CLUSTERED,
        CustomerID      VARCHAR(50) NOT NULL CONSTRAINT UQ_dw_DimCustomer_CustomerID UNIQUE,
        CustomerName    VARCHAR(100) NOT NULL,
        CustomerSegment VARCHAR(50) NOT NULL,
        ETLRunID        BIGINT NOT NULL,
        LoadedAt        DATETIME2(3) NOT NULL CONSTRAINT DF_dw_DimCustomer_LoadedAt DEFAULT SYSUTCDATETIME()
    );
    PRINT 'Table [dw].[DimCustomer] created.';
END
ELSE
BEGIN
    PRINT 'Table [dw].[DimCustomer] already exists.';
END
GO

-- 3. DimProduct: Product Dimension
IF NOT EXISTS (SELECT * FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dw' AND t.name = 'DimProduct')
BEGIN
    CREATE TABLE dw.DimProduct (
        ProductKey      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dw_DimProduct PRIMARY KEY CLUSTERED,
        ProductID       VARCHAR(50) NOT NULL,
        ProductName     VARCHAR(255) NOT NULL,
        Category        VARCHAR(50) NOT NULL,
        SubCategory     VARCHAR(50) NOT NULL,
        ETLRunID        BIGINT NOT NULL,
        LoadedAt        DATETIME2(3) NOT NULL CONSTRAINT DF_dw_DimProduct_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_dw_DimProduct_BusinessKey UNIQUE (ProductID, ProductName, Category, SubCategory)
    );
    PRINT 'Table [dw].[DimProduct] created.';
END
ELSE
BEGIN
    PRINT 'Table [dw].[DimProduct] already exists.';
END
GO

-- 4. DimGeography: Geography Dimension
IF NOT EXISTS (SELECT * FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dw' AND t.name = 'DimGeography')
BEGIN
    CREATE TABLE dw.DimGeography (
        GeographyKey    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dw_DimGeography PRIMARY KEY CLUSTERED,
        PostalCode      VARCHAR(5) NOT NULL,
        City            VARCHAR(100) NOT NULL,
        [State]         VARCHAR(100) NOT NULL,
        Region          VARCHAR(50) NOT NULL,
        Country         VARCHAR(50) NOT NULL,
        ETLRunID        BIGINT NOT NULL,
        LoadedAt        DATETIME2(3) NOT NULL CONSTRAINT DF_dw_DimGeography_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_dw_DimGeography_Location UNIQUE (PostalCode, City, [State], Country)
    );
    PRINT 'Table [dw].[DimGeography] created.';
END
ELSE
BEGIN
    PRINT 'Table [dw].[DimGeography] already exists.';
END
GO

-- 5. DimShipMode: Fulfillment Channel Dimension
IF NOT EXISTS (SELECT * FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dw' AND t.name = 'DimShipMode')
BEGIN
    CREATE TABLE dw.DimShipMode (
        ShipModeKey     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dw_DimShipMode PRIMARY KEY CLUSTERED,
        ShipModeName    VARCHAR(50) NOT NULL CONSTRAINT UQ_dw_DimShipMode_ShipModeName UNIQUE,
        ETLRunID        BIGINT NOT NULL,
        LoadedAt        DATETIME2(3) NOT NULL CONSTRAINT DF_dw_DimShipMode_LoadedAt DEFAULT SYSUTCDATETIME()
    );
    PRINT 'Table [dw].[DimShipMode] created.';
END
ELSE
BEGIN
    PRINT 'Table [dw].[DimShipMode] already exists.';
END
GO



-- ============================================================================
-- SECTION: sql/05_create_fact.sql
-- ============================================================================
-- ============================================================================
-- Script: 05_create_fact.sql
-- Project: Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform
-- Purpose: Create dw.FactSales table representing atomic sales line-item transactions
-- Author: Senior Data Engineer & Database Architect
-- ============================================================================

USE AnalyticsDW;
GO

IF NOT EXISTS (SELECT * FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'dw' AND t.name = 'FactSales')
BEGIN
    CREATE TABLE dw.FactSales (
        FactSalesKey            BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_dw_FactSales PRIMARY KEY CLUSTERED,
        SourceRowID             INT NOT NULL CONSTRAINT UQ_dw_FactSales_SourceRowID UNIQUE,
        OrderID                 VARCHAR(50) NOT NULL,
        OrderDateKey            INT NOT NULL,
        ShipDateKey             INT NOT NULL,
        CustomerKey             INT NOT NULL,
        ProductKey              INT NOT NULL,
        GeographyKey            INT NOT NULL,
        ShipModeKey             INT NOT NULL,
        SalesAmount             DECIMAL(12,4) NOT NULL,
        Quantity                INT NOT NULL,
        DiscountRate            DECIMAL(5,4) NOT NULL,
        ProfitAmount            DECIMAL(12,4) NOT NULL,
        CalculatedCost          DECIMAL(12,4) NOT NULL, -- Documented derived metric: SalesAmount - ProfitAmount
        ProfitMargin            DECIMAL(7,4) NOT NULL,  -- Documented safe calculation: ProfitAmount / NULLIF(SalesAmount, 0)
        ShippingDurationDays    INT NOT NULL,           -- DATEDIFF(day, OrderDate, ShipDate)
        ETLRunID                BIGINT NOT NULL,
        LoadedAt                DATETIME2(3) NOT NULL CONSTRAINT DF_dw_FactSales_LoadedAt DEFAULT SYSUTCDATETIME(),

        -- Referential Integrity Constraints
        CONSTRAINT FK_dw_FactSales_OrderDate FOREIGN KEY (OrderDateKey) REFERENCES dw.DimDate(DateKey),
        CONSTRAINT FK_dw_FactSales_ShipDate FOREIGN KEY (ShipDateKey) REFERENCES dw.DimDate(DateKey),
        CONSTRAINT FK_dw_FactSales_Customer FOREIGN KEY (CustomerKey) REFERENCES dw.DimCustomer(CustomerKey),
        CONSTRAINT FK_dw_FactSales_Product FOREIGN KEY (ProductKey) REFERENCES dw.DimProduct(ProductKey),
        CONSTRAINT FK_dw_FactSales_Geography FOREIGN KEY (GeographyKey) REFERENCES dw.DimGeography(GeographyKey),
        CONSTRAINT FK_dw_FactSales_ShipMode FOREIGN KEY (ShipModeKey) REFERENCES dw.DimShipMode(ShipModeKey)
    );
    PRINT 'Table [dw].[FactSales] created with referential integrity constraints.';
END
ELSE
BEGIN
    PRINT 'Table [dw].[FactSales] already exists.';
END
GO



-- ============================================================================
-- SECTION: sql/06_create_audit.sql
-- ============================================================================
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



-- ============================================================================
-- SECTION: sql/07_create_indexes_constraints.sql
-- ============================================================================
-- ============================================================================
-- Script: 07_create_indexes_constraints.sql
-- Project: Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform
-- Purpose: Create non-clustered indexes for Star Schema query performance
-- Author: Senior Data Engineer & Database Architect
-- ============================================================================

USE AnalyticsDW;
GO

-- 1. Fact Table Foreign Key Indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactSales_OrderDateKey' AND object_id = OBJECT_ID('dw.FactSales'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_FactSales_OrderDateKey ON dw.FactSales(OrderDateKey);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactSales_ShipDateKey' AND object_id = OBJECT_ID('dw.FactSales'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_FactSales_ShipDateKey ON dw.FactSales(ShipDateKey);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactSales_CustomerKey' AND object_id = OBJECT_ID('dw.FactSales'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_FactSales_CustomerKey ON dw.FactSales(CustomerKey);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactSales_ProductKey' AND object_id = OBJECT_ID('dw.FactSales'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_FactSales_ProductKey ON dw.FactSales(ProductKey);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactSales_GeographyKey' AND object_id = OBJECT_ID('dw.FactSales'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_FactSales_GeographyKey ON dw.FactSales(GeographyKey);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactSales_ShipModeKey' AND object_id = OBJECT_ID('dw.FactSales'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_FactSales_ShipModeKey ON dw.FactSales(ShipModeKey);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactSales_OrderID' AND object_id = OBJECT_ID('dw.FactSales'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_FactSales_OrderID ON dw.FactSales(OrderID);
END
GO

-- 2. Dimension Slicer & Hierarchy Indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DimProduct_Category_SubCategory' AND object_id = OBJECT_ID('dw.DimProduct'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimProduct_Category_SubCategory ON dw.DimProduct(Category, SubCategory);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DimGeography_Region_State' AND object_id = OBJECT_ID('dw.DimGeography'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimGeography_Region_State ON dw.DimGeography(Region, [State]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DimCustomer_Segment' AND object_id = OBJECT_ID('dw.DimCustomer'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimCustomer_Segment ON dw.DimCustomer(CustomerSegment);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DimDate_Year_Month' AND object_id = OBJECT_ID('dw.DimDate'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DimDate_Year_Month ON dw.DimDate([Year], [Month]);
END
GO

-- 3. Staging and Audit Indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_stg_OrdersRaw_RowID' AND object_id = OBJECT_ID('stg.OrdersRaw'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_stg_OrdersRaw_RowID ON stg.OrdersRaw(RowID);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_stg_OrdersRaw_ETLRunID' AND object_id = OBJECT_ID('stg.OrdersRaw'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_stg_OrdersRaw_ETLRunID ON stg.OrdersRaw(ETLRunID);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_etl_RejectedRecords_ETLRunID' AND object_id = OBJECT_ID('etl.RejectedRecords'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_etl_RejectedRecords_ETLRunID ON etl.RejectedRecords(ETLRunID);
END
GO

PRINT 'Star Schema and staging performance indexes verified/created.';
GO



-- ============================================================================
-- SECTION: sql/08_validation_queries.sql
-- ============================================================================
-- ============================================================================
-- Script: 08_validation_queries.sql
-- Project: Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform
-- Purpose: Validate warehouse integrity, row counts, FK constraints, and data quality
-- Author: Senior Data Engineer & Database Architect
-- ============================================================================

USE AnalyticsDW;
GO

PRINT '====================================================================';
PRINT '1. WAREHOUSE TABLE ROW COUNTS';
PRINT '====================================================================';
SELECT 
    'stg.OrdersRaw' AS TableName, COUNT(*) AS [RowCount] FROM stg.OrdersRaw
UNION ALL
SELECT 'dw.DimDate', COUNT(*) FROM dw.DimDate
UNION ALL
SELECT 'dw.DimCustomer', COUNT(*) FROM dw.DimCustomer
UNION ALL
SELECT 'dw.DimProduct', COUNT(*) FROM dw.DimProduct
UNION ALL
SELECT 'dw.DimGeography', COUNT(*) FROM dw.DimGeography
UNION ALL
SELECT 'dw.DimShipMode', COUNT(*) FROM dw.DimShipMode
UNION ALL
SELECT 'dw.FactSales', COUNT(*) FROM dw.FactSales
UNION ALL
SELECT 'etl.PipelineRuns', COUNT(*) FROM etl.PipelineRuns
UNION ALL
SELECT 'etl.RejectedRecords', COUNT(*) FROM etl.RejectedRecords;
GO

PRINT '====================================================================';
PRINT '2. ORPHAN FOREIGN KEY CHECKS (Must return 0 for all)';
PRINT '====================================================================';
SELECT 
    (SELECT COUNT(*) FROM dw.FactSales f LEFT JOIN dw.DimDate d ON f.OrderDateKey = d.DateKey WHERE d.DateKey IS NULL) AS OrphanOrderDates,
    (SELECT COUNT(*) FROM dw.FactSales f LEFT JOIN dw.DimDate d ON f.ShipDateKey = d.DateKey WHERE d.DateKey IS NULL) AS OrphanShipDates,
    (SELECT COUNT(*) FROM dw.FactSales f LEFT JOIN dw.DimCustomer c ON f.CustomerKey = c.CustomerKey WHERE c.CustomerKey IS NULL) AS OrphanCustomers,
    (SELECT COUNT(*) FROM dw.FactSales f LEFT JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey WHERE p.ProductKey IS NULL) AS OrphanProducts,
    (SELECT COUNT(*) FROM dw.FactSales f LEFT JOIN dw.DimGeography g ON f.GeographyKey = g.GeographyKey WHERE g.GeographyKey IS NULL) AS OrphanGeographies,
    (SELECT COUNT(*) FROM dw.FactSales f LEFT JOIN dw.DimShipMode s ON f.ShipModeKey = s.ShipModeKey WHERE s.ShipModeKey IS NULL) AS OrphanShipModes;
GO

PRINT '====================================================================';
PRINT '3. TEMPORAL INTEGRITY CHECK (ShipDateKey >= OrderDateKey)';
PRINT '====================================================================';
SELECT 
    COUNT(*) AS InvalidTemporalSequences,
    MIN(ShippingDurationDays) AS MinShippingDays,
    MAX(ShippingDurationDays) AS MaxShippingDays,
    AVG(CAST(ShippingDurationDays AS FLOAT)) AS AvgShippingDays
FROM dw.FactSales
WHERE ShipDateKey < OrderDateKey;
GO

PRINT '====================================================================';
PRINT '4. POSTAL CODE NORMALIZATION CHECK (All must be 5 characters)';
PRINT '====================================================================';
SELECT 
    COUNT(*) AS NonFiveCharPostalCodes,
    MIN(LEN(PostalCode)) AS MinLen,
    MAX(LEN(PostalCode)) AS MaxLen
FROM dw.DimGeography
WHERE LEN(PostalCode) <> 5;
GO

PRINT '====================================================================';
PRINT '5. DUPLICATE SOURCE ROW ID CHECK (Must return 0)';
PRINT '====================================================================';
SELECT SourceRowID, COUNT(*) AS Occurrences
FROM dw.FactSales
GROUP BY SourceRowID
HAVING COUNT(*) > 1;
GO



-- ============================================================================
-- SECTION: sql/09_analytical_queries.sql
-- ============================================================================
-- ============================================================================
-- Script: 09_analytical_queries.sql
-- Project: Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform
-- Purpose: Analytical SQL queries demonstrating business intelligence and Star Schema joins
-- Author: Senior Data Engineer & Database Architect
-- ============================================================================

USE AnalyticsDW;
GO

PRINT '====================================================================';
PRINT 'QUERY 1: EXECUTIVE KPI SUMMARY';
PRINT '====================================================================';
SELECT 
    COUNT(DISTINCT f.OrderID)                       AS TotalOrders,
    COUNT(*)                                        AS TotalLineItems,
    SUM(f.SalesAmount)                              AS TotalRevenue,
    SUM(f.Quantity)                                 AS TotalUnitsSold,
    SUM(f.ProfitAmount)                             AS TotalNetProfit,
    ROUND(SUM(f.ProfitAmount) / SUM(f.SalesAmount) * 100.0, 2) AS OverallProfitMarginPct,
    ROUND(SUM(f.SalesAmount) / COUNT(DISTINCT f.OrderID), 2)   AS AverageOrderValue
FROM dw.FactSales f;
GO

PRINT '====================================================================';
PRINT 'QUERY 2: PRODUCT CATEGORY & SUB-CATEGORY PERFORMANCE';
PRINT '====================================================================';
SELECT 
    p.Category,
    p.SubCategory,
    COUNT(DISTINCT f.OrderID)                       AS OrderCount,
    SUM(f.Quantity)                                 AS UnitsSold,
    ROUND(SUM(f.SalesAmount), 2)                    AS TotalSales,
    ROUND(SUM(f.ProfitAmount), 2)                   AS TotalProfit,
    ROUND(SUM(f.ProfitAmount) / SUM(f.SalesAmount) * 100.0, 2) AS ProfitMarginPct,
    ROUND(AVG(f.DiscountRate) * 100.0, 2)           AS AvgDiscountPct
FROM dw.FactSales f
JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.Category, p.SubCategory
ORDER BY TotalProfit DESC;
GO

PRINT '====================================================================';
PRINT 'QUERY 3: TOP 10 MOST PROFITABLE PRODUCTS';
PRINT '====================================================================';
SELECT TOP 10
    p.ProductID,
    p.ProductName,
    p.Category,
    p.SubCategory,
    SUM(f.Quantity)                                 AS UnitsSold,
    ROUND(SUM(f.SalesAmount), 2)                    AS TotalSales,
    ROUND(SUM(f.ProfitAmount), 2)                   AS TotalProfit,
    ROUND(SUM(f.ProfitAmount) / SUM(f.SalesAmount) * 100.0, 2) AS MarginPct
FROM dw.FactSales f
JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.ProductID, p.ProductName, p.Category, p.SubCategory
ORDER BY TotalProfit DESC;
GO

PRINT '====================================================================';
PRINT 'QUERY 4: BOTTOM 10 LOSS-MAKING PRODUCTS (DISCOUNT IMPACT)';
PRINT '====================================================================';
SELECT TOP 10
    p.ProductID,
    p.ProductName,
    p.Category,
    p.SubCategory,
    ROUND(SUM(f.SalesAmount), 2)                    AS TotalSales,
    ROUND(SUM(f.ProfitAmount), 2)                   AS TotalLoss,
    ROUND(AVG(f.DiscountRate) * 100.0, 2)           AS AvgDiscountPct
FROM dw.FactSales f
JOIN dw.DimProduct p ON f.ProductKey = p.ProductKey
GROUP BY p.ProductID, p.ProductName, p.Category, p.SubCategory
HAVING SUM(f.ProfitAmount) < 0
ORDER BY TotalLoss ASC;
GO

PRINT '====================================================================';
PRINT 'QUERY 5: REGIONAL & SEGMENT REVENUE MATRIX';
PRINT '====================================================================';
SELECT 
    g.Region,
    c.CustomerSegment,
    COUNT(DISTINCT f.OrderID)                       AS Orders,
    ROUND(SUM(f.SalesAmount), 2)                    AS TotalSales,
    ROUND(SUM(f.ProfitAmount), 2)                   AS TotalProfit,
    ROUND(SUM(f.ProfitAmount) / SUM(f.SalesAmount) * 100.0, 2) AS MarginPct
FROM dw.FactSales f
JOIN dw.DimGeography g ON f.GeographyKey = g.GeographyKey
JOIN dw.DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY g.Region, c.CustomerSegment
ORDER BY g.Region, TotalSales DESC;
GO

PRINT '====================================================================';
PRINT 'QUERY 6: MONTHLY SALES TREND OVER TIME (USING DimDate)';
PRINT '====================================================================';
SELECT 
    d.[Year],
    d.[Month],
    d.MonthName,
    COUNT(DISTINCT f.OrderID)                       AS MonthlyOrders,
    ROUND(SUM(f.SalesAmount), 2)                    AS MonthlySales,
    ROUND(SUM(f.ProfitAmount), 2)                   AS MonthlyProfit
FROM dw.FactSales f
JOIN dw.DimDate d ON f.OrderDateKey = d.DateKey
GROUP BY d.[Year], d.[Month], d.MonthName
ORDER BY d.[Year], d.[Month];
GO



-- ============================================================================
-- SECTION: sql/10_reconciliation.sql
-- ============================================================================
-- ============================================================================
-- Script: 10_reconciliation.sql
-- Project: Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform
-- Purpose: Reconcile loaded warehouse numbers against source dataset benchmarks
-- Author: Senior Data Engineer & Database Architect
-- ============================================================================

USE AnalyticsDW;
GO

PRINT '====================================================================';
PRINT 'FINANCIAL & METRIC RECONCILIATION: SOURCE BENCHMARK VS. FACT TABLE';
PRINT '====================================================================';

WITH Benchmark AS (
    SELECT 
        9994                    AS ExpectedRows,
        5009                    AS ExpectedDistinctOrders,
        793                     AS ExpectedDistinctCustomers,
        37873                   AS ExpectedQuantity,
        CAST(2297200.8603 AS DECIMAL(18,4)) AS ExpectedSales,
        CAST(286397.0217 AS DECIMAL(18,4))  AS ExpectedProfit
),
ActualFact AS (
    SELECT 
        COUNT(*)                                AS ActualRows,
        COUNT(DISTINCT OrderID)                 AS ActualDistinctOrders,
        COUNT(DISTINCT CustomerKey)             AS ActualDistinctCustomers,
        SUM(Quantity)                           AS ActualQuantity,
        SUM(SalesAmount)                        AS ActualSales,
        SUM(ProfitAmount)                       AS ActualProfit
    FROM dw.FactSales
)
SELECT 
    'Transaction Rows'          AS MetricName,
    b.ExpectedRows              AS ExpectedValue,
    a.ActualRows                AS ActualValue,
    (a.ActualRows - b.ExpectedRows) AS Variance,
    CASE WHEN a.ActualRows = b.ExpectedRows THEN 'PASSED' ELSE 'FAILED' END AS ReconciliationStatus
FROM Benchmark b CROSS JOIN ActualFact a

UNION ALL

SELECT 
    'Distinct Orders',
    b.ExpectedDistinctOrders,
    a.ActualDistinctOrders,
    (a.ActualDistinctOrders - b.ExpectedDistinctOrders),
    CASE WHEN a.ActualDistinctOrders = b.ExpectedDistinctOrders THEN 'PASSED' ELSE 'FAILED' END
FROM Benchmark b CROSS JOIN ActualFact a

UNION ALL

SELECT 
    'Distinct Customers',
    b.ExpectedDistinctCustomers,
    a.ActualDistinctCustomers,
    (a.ActualDistinctCustomers - b.ExpectedDistinctCustomers),
    CASE WHEN a.ActualDistinctCustomers = b.ExpectedDistinctCustomers THEN 'PASSED' ELSE 'FAILED' END
FROM Benchmark b CROSS JOIN ActualFact a

UNION ALL

SELECT 
    'Total Units Sold',
    b.ExpectedQuantity,
    a.ActualQuantity,
    (a.ActualQuantity - b.ExpectedQuantity),
    CASE WHEN a.ActualQuantity = b.ExpectedQuantity THEN 'PASSED' ELSE 'FAILED' END
FROM Benchmark b CROSS JOIN ActualFact a

UNION ALL

SELECT 
    'Total Sales Revenue ($)',
    b.ExpectedSales,
    a.ActualSales,
    (a.ActualSales - b.ExpectedSales),
    CASE WHEN ABS(a.ActualSales - b.ExpectedSales) < 0.01 THEN 'PASSED' ELSE 'FAILED' END
FROM Benchmark b CROSS JOIN ActualFact a

UNION ALL

SELECT 
    'Total Net Profit ($)',
    b.ExpectedProfit,
    a.ActualProfit,
    (a.ActualProfit - b.ExpectedProfit),
    CASE WHEN ABS(a.ActualProfit - b.ExpectedProfit) < 0.01 THEN 'PASSED' ELSE 'FAILED' END
FROM Benchmark b CROSS JOIN ActualFact a;
GO

