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
