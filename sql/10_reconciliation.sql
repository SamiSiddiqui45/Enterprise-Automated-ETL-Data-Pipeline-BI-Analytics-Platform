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
