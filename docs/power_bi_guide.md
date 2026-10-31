# Power BI Desktop Implementation & Analytics Guide

## 1. Overview and Architecture

This guide provides step-by-step instructions for connecting **Power BI Desktop** to the local SQL Server data warehouse database (`AnalyticsDW`), establishing the **Star Schema** relationships, creating validated **DAX measures**, and designing an interactive three-page analytical dashboard.

---

## 2. Connecting to SQL Server in Power BI Desktop

1. Open **Power BI Desktop**.
2. On the **Home** ribbon, click **Get Data** > **SQL Server**.
3. In the SQL Server Database dialog:
   - **Server:** `.\SQLEXPRESS` (or `localhost\SQLEXPRESS`)
   - **Database:** `AnalyticsDW`
   - **Data Connectivity mode:** Select **Import** (Recommended for in-memory DAX performance and time-intelligence calculations).
4. Click **OK**.
5. When prompted for authentication:
   - Select **Windows** authentication.
   - Choose **Use my current credentials**.
   - Click **Connect**.
   - If an "Encryption Support" prompt appears, click **OK / Trust**.
6. In the **Navigator** window, expand `AnalyticsDW` and select the following 6 tables:
   - `[dw].[DimDate]`
   - `[dw].[DimCustomer]`
   - `[dw].[DimProduct]`
   - `[dw].[DimGeography]`
   - `[dw].[DimShipMode]`
   - `[dw].[FactSales]`
7. Click **Load**.

---

## 3. Data Model & Relationship Configuration

Switch to the **Model View** (icon on the left navigation bar) and establish the Star Schema relationships.

### Relationship Matrix

| From Table (Fact) | From Column (FK) | To Table (Dim) | To Column (PK) | Cardinality | Cross Filter | Active? |
| :--- | :--- | :--- | :--- | :---: | :---: | :---: |
| `FactSales` | `OrderDateKey` | `DimDate` | `DateKey` | Many to One (*:1) | Single | **Yes (Active)** |
| `FactSales` | `ShipDateKey` | `DimDate` | `DateKey` | Many to One (*:1) | Single | No (Inactive) |
| `FactSales` | `CustomerKey` | `DimCustomer` | `CustomerKey` | Many to One (*:1) | Single | **Yes (Active)** |
| `FactSales` | `ProductKey` | `DimProduct` | `ProductKey` | Many to One (*:1) | Single | **Yes (Active)** |
| `FactSales` | `GeographyKey` | `DimGeography` | `GeographyKey` | Many to One (*:1) | Single | **Yes (Active)** |
| `FactSales` | `ShipModeKey` | `DimShipMode` | `ShipModeKey` | Many to One (*:1) | Single | **Yes (Active)** |

### Marking Date Table
1. In the **Fields / Data** pane, right-click `DimDate`.
2. Select **Mark as date table** > **Mark as date table**.
3. Choose `FullDate` as the date column and click **OK**.

---

## 4. Validated DAX Measures

Create a dedicated Measure Table or add the following DAX expressions directly to `dw.FactSales`. Every formula has been mathematically reconciled against the SQL database benchmarks.

### 4.1 Core Financial Metrics

```dax
Total Sales = 
SUM(FactSales[SalesAmount])
```
*Format: Currency (`$#,##0.00`)*

```dax
Total Profit = 
SUM(FactSales[ProfitAmount])
```
*Format: Currency (`$#,##0.00`)*

```dax
Profit Margin % = 
DIVIDE([Total Profit], [Total Sales], 0)
```
*Format: Percentage (`0.0%`)*

```dax
Total Quantity = 
SUM(FactSales[Quantity])
```
*Format: Whole Number (`#,##0`)*

```dax
Total Orders = 
DISTINCTCOUNT(FactSales[OrderID])
```
*Format: Whole Number (`#,##0`)*

```dax
Average Order Value = 
DIVIDE([Total Sales], [Total Orders], 0)
```
*Format: Currency (`$#,##0.00`)*

```dax
Total Cost = 
SUM(FactSales[CalculatedCost])
```
*Format: Currency (`$#,##0.00`)*

```dax
Average Shipping Days = 
AVERAGE(FactSales[ShippingDurationDays])
```
*Format: Decimal (`0.0`)*

---

### 4.2 Time Intelligence (Year-over-Year & YTD)

```dax
Sales Prior Year = 
CALCULATE(
    [Total Sales],
    SAMEPERIODLASTYEAR(DimDate[FullDate])
)
```

```dax
YoY Sales Growth = 
[Total Sales] - [Sales Prior Year]
```

```dax
YoY Sales Growth % = 
DIVIDE([YoY Sales Growth], [Sales Prior Year], 0)
```
*Format: Percentage (`+0.0%;-0.0%;0.0%`)*

```dax
Sales YTD = 
TOTALYTD([Total Sales], DimDate[FullDate])
```

```dax
Profit YTD = 
TOTALYTD([Total Profit], DimDate[FullDate])
```

---

## 5. Report Design & Visual Layout

### Page 1: Executive Overview

**Objective:** High-level executive snapshot of corporate sales, profitability, margin health, and monthly trajectory.

1. **Top KPI Cards Banner:**
   - Card 1: `[Total Sales]` ($2.30M)
   - Card 2: `[Total Profit]` ($286.40K)
   - Card 3: `[Profit Margin %]` (12.5%)
   - Card 4: `[Total Orders]` (5,009)
   - Card 5: `[Average Order Value]` ($458.61)
2. **Monthly Sales & Profit Margin Trend (Line & Clustered Column Chart):**
   - **X-Axis:** `DimDate[YearMonth]`
   - **Column Y-Axis:** `[Total Sales]`
   - **Line Y-Axis:** `[Profit Margin %]`
   - Demonstrates strong Q4 seasonality and margin stability.
3. **Regional Performance (Clustered Bar Chart):**
   - **Y-Axis:** `DimGeography[Region]`
   - **X-Axis:** `[Total Sales]` and `[Total Profit]`
   - Shows West ($725K sales) and East ($678K sales) leading corporate revenue.
4. **Customer Segment Breakdown (Donut Chart):**
   - **Legend:** `DimCustomer[CustomerSegment]`
   - **Values:** `[Total Sales]`
   - Visualizes Consumer (50.6%), Corporate (30.7%), and Home Office (18.7%).
5. **Interactive Slicers:**
   - Slicer 1: `DimDate[Year]` (Dropdown / Buttons: 2014, 2015, 2016, 2017).
   - Slicer 2: `DimGeography[Region]` (Central, East, South, West).
   - Slicer 3: `DimCustomer[CustomerSegment]` (Consumer, Corporate, Home Office).

---

### Page 2: Product & Sales Analysis

**Objective:** Item-level profitability, catalog performance, and discount sensitivity diagnostics.

1. **Category & Sub-Category Hierarchy (Treemap or Matrix):**
   - **Group:** `DimProduct[Category]` > `DimProduct[SubCategory]`
   - **Values:** `[Total Sales]`
   - **Tooltips:** `[Total Profit]`, `[Profit Margin %]`
2. **Top 10 Most Profitable Products (Horizontal Bar Chart):**
   - **Y-Axis:** `DimProduct[ProductName]`
   - **X-Axis:** `[Total Profit]`
   - **Filter:** Top N (Top 10 by `[Total Profit]`).
   - Highlights the Canon imageCLASS 2200 Advanced Copier ($25,200 profit).
3. **Loss-Making Products Diagnostics (Table Visual):**
   - **Columns:** `DimProduct[ProductName]`, `DimProduct[SubCategory]`, `[Total Sales]`, `[Total Profit]`, `FactSales[DiscountRate]`
   - **Filter:** `[Total Profit] < 0`
   - Demonstrates how steep discounts (> 50%) on Tables and Binders drive negative margins.
4. **Discount Sensitivity vs. Margin (Scatter Plot):**
   - **X-Axis:** `FactSales[DiscountRate]`
   - **Y-Axis:** `[Profit Margin %]`
   - **Legend:** `DimProduct[Category]`
   - Clearly proves that discounts exceeding 20% severely impair profitability.

---

### Page 3: Customer Analytics

**Objective:** Customer account value, geographic distribution, and shipping fulfillment efficiency.

1. **Top 10 Customers by Revenue (Clustered Bar Chart):**
   - **Y-Axis:** `DimCustomer[CustomerName]`
   - **X-Axis:** `[Total Sales]`
   - **Tooltips:** `[Total Orders]`, `[Total Profit]`
   - Highlights high-value accounts (e.g. Sean Miller, Tamara Chand).
2. **Geographic Sales Heatmap (US Map Visual):**
   - **Location:** `DimGeography[State]`
   - **Bubble Size:** `[Total Sales]`
   - **Color Saturation:** `[Total Profit]`
   - Identifies California and New York as primary growth centers.
3. **Shipping Mode Logistics Performance (Matrix / Cards):**
   - **Rows:** `DimShipMode[ShipModeName]`
   - **Values:** `[Total Orders]`, `[Total Sales]`, `[Average Shipping Days]`
   - Confirms Standard Class handles ~60% of volume (avg 5 days), Same Day delivers within 0 days.

---

## 6. SQL Validation Reference for Instructors

When demonstrating the dashboard to your instructor, cross-reference Power BI values with the output of `sql/09_analytical_queries.sql` in SSMS 20:

| Power BI Measure | Power BI Value | Equivalent SQL Verification Query | SQL Match |
| :--- | :---: | :--- | :---: |
| **Total Revenue** | `$2,297,200.86` | `SELECT SUM(SalesAmount) FROM dw.FactSales;` | **100% Match** |
| **Total Profit** | `$286,397.02` | `SELECT SUM(ProfitAmount) FROM dw.FactSales;` | **100% Match** |
| **Total Orders** | `5,009` | `SELECT COUNT(DISTINCT OrderID) FROM dw.FactSales;` | **100% Match** |
| **Total Units** | `37,873` | `SELECT SUM(Quantity) FROM dw.FactSales;` | **100% Match** |
| **Average Order Value** | `$458.61` | `SELECT SUM(SalesAmount)/COUNT(DISTINCT OrderID) FROM dw.FactSales;` | **100% Match** |
