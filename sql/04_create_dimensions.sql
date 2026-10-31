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
