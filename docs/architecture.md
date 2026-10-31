# System Architecture & Technical Design

## 1. Executive Summary

The **Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform** is a multi-tier data platform engineered to ingest, clean, validate, transform, warehouse, and visualize enterprise retail transaction data.

The system is built on Microsoft SQL Server 2025 Express, Python 3.12, Pandas, PyODBC, and Power BI Desktop.

---

## 2. End-to-End Pipeline Architecture

```mermaid
flowchart TD
    subgraph Source["Source Layer"]
        CSV["archive (1)/Sample - Superstore.csv<br/>(9,994 Rows, 21 Columns, CP1252)"]
    end

    subgraph PythonETL["Python 3.12 Automated ETL Pipeline"]
        Extract["src/extract.py<br/>Reads CSV with encoding safety<br/>Validates header contracts"]
        Validate["src/validate.py<br/>Constraint verification<br/>Null checks, domain bounds, temporal order"]
        Quarantine["etl.RejectedRecords<br/>Quarantines bad records with JSON trace"]
        Transform["src/transform.py<br/>ZIP zero-padding, date keys YYYYMMDD<br/>Derived metrics: Cost, Margin %, ShippingDays"]
        Load["src/load.py<br/>PyODBC fast_executemany batching<br/>Dimension surrogate key resolution"]
        Audit["src/audit.py<br/>Records execution telemetry in etl.PipelineRuns"]
    end

    subgraph SQLServer["Microsoft SQL Server Express (AnalyticsDW)"]
        subgraph StagingSchema["Schema: stg"]
            StgOrders["stg.OrdersRaw<br/>Full source lineage & batch tracking"]
        end
        subgraph WarehouseSchema["Schema: dw (Star Schema)"]
            DimDate["dw.DimDate (Calendar 2013-2020)"]
            DimCust["dw.DimCustomer (793 Customers)"]
            DimProd["dw.DimProduct (1,894 Products)"]
            DimGeo["dw.DimGeography (632 Locations)"]
            DimShip["dw.DimShipMode (4 Modes)"]
            FactSales["dw.FactSales (9,994 Fact Rows)"]
        end
        subgraph AuditSchema["Schema: etl"]
            AuditRuns["etl.PipelineRuns"]
            AuditRej["etl.RejectedRecords"]
        end
    end

    subgraph Analytics["Business Intelligence Layer"]
        PBI["Power BI Desktop<br/>Executive Overview | Product Analytics | Customer Analytics"]
        SSMS["SSMS 20<br/>Verification & Analytical Queries"]
    end

    CSV --> Extract
    Extract --> Validate
    Validate -->|Invalid Rows| Quarantine
    Validate -->|Valid Rows| Transform
    Transform --> StgOrders
    Transform --> Load
    Load --> DimDate
    Load --> DimCust
    Load --> DimProd
    Load --> DimGeo
    Load --> DimShip
    Load --> FactSales
    Load --> AuditRuns
    FactSales --> PBI
    FactSales --> SSMS
```

---

## 3. Layered Design Principles

### 3.1 Raw Source Layer
- **Source:** `archive (1)/Sample - Superstore.csv`.
- **Character Encoding:** Windows-1252 (`cp1252`), preserving non-breaking spaces and Windows typographic symbols.
- **Rule of Non-Destruction:** Raw source files are read-only and never modified or deleted.

### 3.2 Staging Layer (`stg`)
- **Table:** `stg.OrdersRaw`.
- Retains 100% of the raw source attributes as strings/raw representations.
- Appends operational metadata: `ETLRunID` and `IngestionTimestamp` for end-to-end data lineage.
- Staging records can be reloaded across multiple runs without affecting warehouse consistency.

### 3.3 Dimensional Warehouse Layer (`dw`)
- Implemented as a **Star Schema** centered on `dw.FactSales`.
- Dimensions use integer surrogate primary keys (`IDENTITY(1,1)`).
- Natural keys (`CustomerID`, `ProductID`, `PostalCode`) are preserved.
- Temporal attributes are connected via integer surrogate keys (`YYYYMMDD`) to `dw.DimDate`.

### 3.4 Audit & Quarantine Layer (`etl`)
- **`etl.PipelineRuns`**: Tracks run status (`RUNNING`, `SUCCESS`, `FAILED`), timestamps, runtime durations, and row counts across all pipeline stages.
- **`etl.RejectedRecords`**: Quarantines any invalid rows with exact failure reasons, column names, offending values, and the complete raw row serialized as JSON.

---

## 4. Key Architectural Decisions

1. **Surrogate Key Strategy for Product Dimension:**
   - Profiling revealed that 32 `Product ID` codes have minor naming variations across the 4-year span.
   - To preserve 100% of historical product names and avoid dropping or overwriting data, `dw.DimProduct` models unique `(ProductID, ProductName, Category, SubCategory)` tuples (1,894 unique rows) with surrogate key `ProductKey`.
2. **Postal Code Normalization:**
   - Raw postal codes stored as integers drop leading zeros (e.g. `1040`).
   - The transformation pipeline normalizes postal codes to 5-digit zero-padded strings (`01040`) stored as `VARCHAR(5)`.
3. **Idempotency & Re-run Safety:**
   - `dw.FactSales` enforces a unique constraint on `SourceRowID`.
   - Repeated pipeline runs insert new batches into staging while skipping already-loaded transactions in the fact table, guaranteeing that reruns never introduce duplicate transactions.
4. **Financial Arithmetic Precision:**
   - All monetary fields (`SalesAmount`, `ProfitAmount`, `CalculatedCost`) use `DECIMAL(12, 4)`.
   - All discount rates use `DECIMAL(5, 4)`.
   - Floating-point accumulation errors are eliminated.
