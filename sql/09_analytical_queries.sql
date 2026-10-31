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
