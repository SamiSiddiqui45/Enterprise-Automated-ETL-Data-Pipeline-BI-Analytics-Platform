# Data Warehouse Data Dictionary

## 1. Schema: `stg` (Staging Layer)

### Table: `stg.OrdersRaw`
*Landing table for raw source CSV transactions.*

| Column Name | Data Type | Nullable | Description |
| :--- | :--- | :---: | :--- |
| `StagingID` | `INT IDENTITY(1,1)` | No | Internal surrogate primary key for staging rows. |
| `RowID` | `INT` | No | Original row identifier from source CSV (`Row ID`). |
| `OrderID` | `VARCHAR(50)` | No | Original transaction order identifier (e.g. `CA-2016-152156`). |
| `OrderDateRaw` | `VARCHAR(50)` | No | Raw string representation of the order date. |
| `ShipDateRaw` | `VARCHAR(50)` | No | Raw string representation of the shipping date. |
| `ShipMode` | `VARCHAR(50)` | No | Shipping method (e.g. `Second Class`). |
| `CustomerID` | `VARCHAR(50)` | No | Customer natural key (e.g. `CG-12520`). |
| `CustomerName` | `VARCHAR(100)` | No | Full name of the customer. |
| `Segment` | `VARCHAR(50)` | No | Market customer segment (`Consumer`, `Corporate`, `Home Office`). |
| `Country` | `VARCHAR(50)` | No | Destination country (`United States`). |
| `City` | `VARCHAR(100)` | No | Destination city name. |
| `State` | `VARCHAR(100)` | No | Destination US state. |
| `PostalCodeRaw` | `VARCHAR(20)` | No | Raw postal code string from file. |
| `Region` | `VARCHAR(50)` | No | Geographic sales region (`Central`, `East`, `South`, `West`). |
| `ProductID` | `VARCHAR(50)` | No | Product natural key (e.g. `FUR-BO-10001798`). |
| `Category` | `VARCHAR(50)` | No | Top-level product category (`Furniture`, `Office Supplies`, `Technology`). |
| `SubCategory` | `VARCHAR(50)` | No | Product sub-category (17 distinct categories). |
| `ProductName` | `VARCHAR(255)` | No | Full descriptive title of the product item. |
| `SalesRaw` | `VARCHAR(50)` | No | Raw sales amount as formatted in the CSV. |
| `QuantityRaw` | `VARCHAR(50)` | No | Raw units sold as formatted in the CSV. |
| `DiscountRaw` | `VARCHAR(50)` | No | Raw discount applied as formatted in the CSV. |
| `ProfitRaw` | `VARCHAR(50)` | No | Raw net profit earned as formatted in the CSV. |
| `ETLRunID` | `BIGINT` | No | Foreign identifier linking to `etl.PipelineRuns`. |
| `IngestionTimestamp` | `DATETIME2(3)` | No | UTC timestamp when the record was inserted. |

---

## 2. Schema: `dw` (Dimensional Warehouse Layer)

### Table: `dw.DimDate`
*Continuous calendar dimension spanning 2013-01-01 through 2020-12-31 (2,922 rows).*

| Column Name | Data Type | Nullable | Constraint | Description |
| :--- | :--- | :---: | :---: | :--- |
| `DateKey` | `INT` | No | PK | Surrogate calendar key formatted as integer `YYYYMMDD`. |
| `FullDate` | `DATE` | No | UNIQUE | Standard SQL calendar date (`YYYY-MM-DD`). |
| `Year` | `SMALLINT` | No | - | Four-digit calendar year (e.g. `2016`). |
| `Quarter` | `TINYINT` | No | - | Quarter index (`1`, `2`, `3`, `4`). |
| `QuarterName` | `CHAR(2)` | No | - | Quarter label (`Q1`, `Q2`, `Q3`, `Q4`). |
| `Month` | `TINYINT` | No | - | Month index (`1` to `12`). |
| `MonthName` | `VARCHAR(20)` | No | - | Full month name (e.g. `November`). |
| `MonthShort` | `CHAR(3)` | No | - | Three-letter month abbreviation (e.g. `Nov`). |
| `YearMonth` | `CHAR(7)` | No | - | Standard year-month identifier (e.g. `2016-11`). |
| `WeekOfYear` | `TINYINT` | No | - | ISO week number of the year (`1` to `53`). |
| `DayOfMonth` | `TINYINT` | No | - | Day index within month (`1` to `31`). |
| `DayOfWeek` | `TINYINT` | No | - | Day of week index (`1` = Sunday, `7` = Saturday). |
| `DayOfWeekName` | `VARCHAR(20)` | No | - | Name of weekday (e.g. `Tuesday`). |
| `IsWeekend` | `BIT` | No | - | Boolean flag: `1` for Saturday/Sunday, `0` for Weekday. |

### Table: `dw.DimCustomer`
*Customer accounts dimension (793 rows).*

| Column Name | Data Type | Nullable | Constraint | Description |
| :--- | :--- | :---: | :---: | :--- |
| `CustomerKey` | `INT IDENTITY(1,1)` | No | PK | Surrogate primary key for customer dimension. |
| `CustomerID` | `VARCHAR(50)` | No | UNIQUE | Natural customer identifier (e.g. `CG-12520`). |
| `CustomerName` | `VARCHAR(100)` | No | - | Full name of the purchasing customer. |
| `CustomerSegment` | `VARCHAR(50)` | No | - | Market classification (`Consumer`, `Corporate`, `Home Office`). |
| `ETLRunID` | `BIGINT` | No | - | RunID during which this record was inserted. |
| `LoadedAt` | `DATETIME2(3)` | No | - | UTC timestamp of record creation. |

### Table: `dw.DimProduct`
*Product catalog dimension (1,894 rows).*

| Column Name | Data Type | Nullable | Constraint | Description |
| :--- | :--- | :---: | :---: | :--- |
| `ProductKey` | `INT IDENTITY(1,1)` | No | PK | Surrogate primary key for product dimension. |
| `ProductID` | `VARCHAR(50)` | No | - | Natural item identifier (e.g. `FUR-BO-10001798`). |
| `ProductName` | `VARCHAR(255)` | No | - | Complete product title. |
| `Category` | `VARCHAR(50)` | No | - | Product department category (`Furniture`, `Office Supplies`, `Technology`). |
| `SubCategory` | `VARCHAR(50)` | No | - | Specific product sub-category (e.g. `Chairs`, `Paper`, `Phones`). |
| `ETLRunID` | `BIGINT` | No | - | RunID during which this record was inserted. |
| `LoadedAt` | `DATETIME2(3)` | No | - | UTC timestamp of record creation. |

### Table: `dw.DimGeography`
*Geographic locations dimension (632 rows).*

| Column Name | Data Type | Nullable | Constraint | Description |
| :--- | :--- | :---: | :---: | :--- |
| `GeographyKey` | `INT IDENTITY(1,1)` | No | PK | Surrogate primary key for geography dimension. |
| `PostalCode` | `VARCHAR(5)` | No | - | Normalized 5-digit zero-padded US ZIP code (e.g. `01040`). |
| `City` | `VARCHAR(100)` | No | - | City name. |
| `State` | `VARCHAR(100)` | No | - | US State name (49 states represented). |
| `Region` | `VARCHAR(50)` | No | - | Broad US territory (`Central`, `East`, `South`, `West`). |
| `Country` | `VARCHAR(50)` | No | - | Country name (`United States`). |
| `ETLRunID` | `BIGINT` | No | - | RunID during which this record was inserted. |
| `LoadedAt` | `DATETIME2(3)` | No | - | UTC timestamp of record creation. |

### Table: `dw.DimShipMode`
*Fulfillment logistics channel dimension (4 rows).*

| Column Name | Data Type | Nullable | Constraint | Description |
| :--- | :--- | :---: | :---: | :--- |
| `ShipModeKey` | `INT IDENTITY(1,1)` | No | PK | Surrogate primary key for ship mode dimension. |
| `ShipModeName` | `VARCHAR(50)` | No | UNIQUE | Shipping delivery speed (`Standard Class`, `Second Class`, `First Class`, `Same Day`). |
| `ETLRunID` | `BIGINT` | No | - | RunID during which this record was inserted. |
| `LoadedAt` | `DATETIME2(3)` | No | - | UTC timestamp of record creation. |

### Table: `dw.FactSales`
*Atomic retail sales transaction line-items (9,994 rows).*

| Column Name | Data Type | Nullable | Constraint | Description |
| :--- | :--- | :---: | :---: | :--- |
| `FactSalesKey` | `BIGINT IDENTITY(1,1)` | No | PK | Surrogate primary key for the sales fact record. |
| `SourceRowID` | `INT` | No | UNIQUE | Original row identifier from source CSV for 1:1 traceability. |
| `OrderID` | `VARCHAR(50)` | No | - | Natural order transaction code (e.g. `CA-2016-152156`). |
| `OrderDateKey` | `INT` | No | FK -> `DimDate` | Surrogate key for order date (`YYYYMMDD`). Active link in Power BI. |
| `ShipDateKey` | `INT` | No | FK -> `DimDate` | Surrogate key for ship date (`YYYYMMDD`). Inactive role-playing link. |
| `CustomerKey` | `INT` | No | FK -> `DimCustomer` | Surrogate key linking to customer account. |
| `ProductKey` | `INT` | No | FK -> `DimProduct` | Surrogate key linking to product catalog item. |
| `GeographyKey` | `INT` | No | FK -> `DimGeography` | Surrogate key linking to geographic destination. |
| `ShipModeKey` | `INT` | No | FK -> `DimShipMode` | Surrogate key linking to shipping mode. |
| `SalesAmount` | `DECIMAL(12,4)` | No | - | Gross transaction revenue generated ($). |
| `Quantity` | `INT` | No | - | Total physical units purchased. |
| `DiscountRate` | `DECIMAL(5,4)` | No | - | Discount applied as percentage ratio (e.g. `0.2000` for 20%). |
| `ProfitAmount` | `DECIMAL(12,4)` | No | - | Net profit or loss realized ($). |
| `CalculatedCost` | `DECIMAL(12,4)` | No | - | Derived cost estimate calculated as `SalesAmount - ProfitAmount`. |
| `ProfitMargin` | `DECIMAL(7,4)` | No | - | Safe profit margin ratio calculated as `ProfitAmount / SalesAmount`. |
| `ShippingDurationDays` | `INT` | No | - | Elapsed days from order date to ship date. |
| `ETLRunID` | `BIGINT` | No | - | Ingestion execution identifier from `etl.PipelineRuns`. |
| `LoadedAt` | `DATETIME2(3)` | No | - | UTC timestamp when fact record was committed. |

---

## 3. Schema: `etl` (Audit and Governance Layer)

### Table: `etl.PipelineRuns`
*Execution telemetry tracking all batch runs.*

| Column Name | Data Type | Nullable | Description |
| :--- | :--- | :---: | :--- |
| `RunID` | `BIGINT IDENTITY(1,1)` | No | Unique execution run identifier. |
| `StartTime` | `DATETIME2(3)` | No | Run initialization UTC timestamp. |
| `EndTime` | `DATETIME2(3)` | Yes | Run completion UTC timestamp. |
| `Status` | `VARCHAR(20)` | No | Execution status (`RUNNING`, `SUCCESS`, `FAILED`). |
| `SourceFileName` | `VARCHAR(255)` | No | Source CSV filename ingested. |
| `SourceRowCount` | `INT` | Yes | Count of records read from CSV file. |
| `StagingRowCount` | `INT` | Yes | Count of records committed to staging table. |
| `DimCustomerCount` | `INT` | Yes | Count of active customer dimension rows. |
| `DimProductCount` | `INT` | Yes | Count of active product dimension rows. |
| `DimGeographyCount` | `INT` | Yes | Count of active geography dimension rows. |
| `DimShipModeCount` | `INT` | Yes | Count of active ship mode dimension rows. |
| `FactRowCount` | `INT` | Yes | Count of records committed to fact table. |
| `RejectedRowCount` | `INT` | Yes | Count of records quarantined to `etl.RejectedRecords`. |
| `ErrorMessage` | `NVARCHAR(MAX)` | Yes | Detailed error stack trace if run failed. |

### Table: `etl.RejectedRecords`
*Quarantine table storing corrupt or invalid records.*

| Column Name | Data Type | Nullable | Description |
| :--- | :--- | :---: | :--- |
| `RejectionID` | `BIGINT IDENTITY(1,1)` | No | Unique rejection identifier. |
| `ETLRunID` | `BIGINT` | No | RunID during which the error occurred. |
| `SourceRowID` | `INT` | Yes | Offending source row ID. |
| `OrderID` | `VARCHAR(50)` | Yes | Offending order ID. |
| `RejectionReason` | `VARCHAR(255)` | No | Data quality rule violated (e.g. `NEGATIVE_SALES_AMOUNT`). |
| `RejectedColumn` | `VARCHAR(100)` | Yes | Specific column that triggered failure. |
| `RejectedValue` | `NVARCHAR(500)` | Yes | Corrupt value extracted from input. |
| `RawRecordJSON` | `NVARCHAR(MAX)` | Yes | Full serialized JSON payload of the raw row for troubleshooting. |
| `LoggedAt` | `DATETIME2(3)` | No | UTC timestamp when quarantined. |
