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
