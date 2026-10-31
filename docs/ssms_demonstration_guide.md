# SQL Server Management Studio (SSMS) 20 Demonstration Guide

## 1. Introduction

This guide is designed for your university instructor demonstration. It provides exact, step-by-step instructions on navigating **SQL Server Management Studio (SSMS) 20**, inspecting database objects, reviewing the Star Schema, and executing the validation and analytical queries.

---

## 2. Connecting to the Database in SSMS 20

1. Launch **SQL Server Management Studio 20** from the Windows Start menu or shortcut.
2. In the **Connect to Server** dialog box:
   - **Server type:** `Database Engine`
   - **Server name:** `.\SQLEXPRESS` (or `localhost\SQLEXPRESS`)
   - **Authentication:** `Windows Authentication`
   - **Encryption:** `Optional` or `Mandatory` (Check `Trust server certificate` if prompted)
3. Click **Connect**.
4. In the **Object Explorer** pane (left side), expand the **Databases** folder.
5. You will see **`AnalyticsDW`**.

---

## 3. Inspecting Database Objects in Object Explorer

### 3.1 Schemas and Table Organization
Expand `AnalyticsDW` > `Tables`. You will see 9 tables organized across three logical schemas:

1. **Staging Schema (`stg`)**:
   - `stg.OrdersRaw` — Ingestion landing area preserving all 21 raw CSV fields, batch ID, and UTC timestamp.
2. **Data Warehouse Schema (`dw`)**:
   - `dw.DimDate` — Continuous calendar dimension (2013–2020) with year, month, quarter, day of week.
   - `dw.DimCustomer` — 793 customer accounts with natural key `CustomerID`, full name, and segment.
   - `dw.DimProduct` — 1,894 products with natural key `ProductID`, name, category, and subcategory.
   - `dw.DimGeography` — 632 geographic locations with 5-digit zero-padded postal code, city, state, region.
   - `dw.DimShipMode` — 4 fulfillment modes (`Standard Class`, `Second Class`, `First Class`, `Same Day`).
   - `dw.FactSales` — 9,994 atomic sales transactions with foreign keys, sales, quantity, discount, profit, cost, margin, and shipping duration.
3. **Audit Schema (`etl`)**:
   - `etl.PipelineRuns` — Execution history tracking start/end times, status, row counts, and error messages.
   - `etl.RejectedRecords` — Data quality quarantine table holding invalid rows and rejection reasons.

---

## 4. Key Architectural Elements to Show the Instructor

### 4.1 Primary Keys, Foreign Keys, and Constraints
1. In Object Explorer, expand `dw.FactSales` > **Keys**:
   - `PK_dw_FactSales` (Clustered Primary Key)
   - `FK_dw_FactSales_OrderDate` (Foreign Key referencing `dw.DimDate.DateKey`)
   - `FK_dw_FactSales_ShipDate` (Foreign Key referencing `dw.DimDate.DateKey`)
   - `FK_dw_FactSales_Customer` (Foreign Key referencing `dw.DimCustomer.CustomerKey`)
   - `FK_dw_FactSales_Product` (Foreign Key referencing `dw.DimProduct.ProductKey`)
   - `FK_dw_FactSales_Geography` (Foreign Key referencing `dw.DimGeography.GeographyKey`)
   - `FK_dw_FactSales_ShipMode` (Foreign Key referencing `dw.DimShipMode.ShipModeKey`)
2. Expand `dw.FactSales` > **Constraints**:
   - `UQ_dw_FactSales_SourceRowID` (Enforces idempotency and guarantees 1:1 trace to source Row ID).

### 4.2 Data Types & Decimal Precision
Show the instructor that currency and percentages use exact fixed-point decimals rather than floating point:
- `SalesAmount`: `DECIMAL(12, 4)`
- `ProfitAmount`: `DECIMAL(12, 4)`
- `CalculatedCost`: `DECIMAL(12, 4)`
- `DiscountRate`: `DECIMAL(5, 4)`
- `PostalCode`: `VARCHAR(5)` with zero padding preserved (e.g. `'01040'` instead of integer `1040`).

---

## 5. Live Demonstration Query Script Walkthrough

In SSMS, open and run the provided SQL scripts located in the `sql/` directory:

### Step 1: Execute Table Validation & Row Counts
- In SSMS, click **File** > **Open** > **File...** > select `sql/08_validation_queries.sql`.
- Click **Execute** (or press `F5`).
- **Show the instructor:**
  - Table row count summary (9,994 Fact records, 793 Customers, 1,894 Products, 632 Geographies).
  - All 6 Orphan Foreign Key checks return **`0`** (100% referential integrity).
  - Temporal check returns **`0`** invalid sequences (`Ship Date >= Order Date`).
  - Postal code check returns **`0`** invalid lengths (all exactly 5 digits).

### Step 2: Execute Business Analytics Queries
- Open `sql/09_analytical_queries.sql` and execute (`F5`).
- **Show the instructor:**
  - **Query 1 (Executive KPIs):** Total Orders (`5,009`), Total Sales (`$2,297,200.86`), Total Profit (`$286,397.02`), Average Order Value (`$458.61`).
  - **Query 2 (Category Breakdown):** Technology generates highest profit ($145.5K) while Furniture suffers lower margin (2.5%) due to heavy discount losses on Tables (-$17.7K).
  - **Query 3 (Top Products):** Canon imageCLASS 2200 Advanced Copier ($25,200 profit).
  - **Query 4 (Monthly Trend):** Continuous 48 months of daily transactions demonstrating seasonal Q4 spikes.

### Step 3: Execute Financial Reconciliation
- Open `sql/10_reconciliation.sql` and execute (`F5`).
- **Show the instructor:**
  - The reconciliation table compares the fact table aggregates directly against the source CSV benchmarks.
  - Every single metric shows **`Variance = 0.0000`** and **`Status = PASSED`**.

### Step 4: Show Audit Lineage & Idempotency
Run the following query in a New Query window:
```sql
SELECT RunID, StartTime, EndTime, Status, SourceFileName, SourceRowCount, FactRowCount, StagingRowCount
FROM etl.PipelineRuns
ORDER BY RunID;
```
Explain:
- "Here you can see the audit log of our pipeline runs. In Run 1, 9,994 rows were ingested. When Run 2 was executed to test pipeline resilience, the pipeline safely staged the batch without duplicating a single fact row."
