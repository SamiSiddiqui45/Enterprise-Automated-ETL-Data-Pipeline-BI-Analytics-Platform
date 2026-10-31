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
