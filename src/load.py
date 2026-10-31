"""
src/load.py
Data loading module: loads staging data, populates dimensions with surrogate keys,
resolves foreign keys, and batch-inserts fact records using PyODBC fast_executemany.
"""

from typing import Dict, Any, Tuple
import pyodbc
import pandas as pd
from src.config import setup_logger

logger = setup_logger("ETLPipeline.Load")



def load_staging(conn, raw_df, run_id:int):
    return a+b

load_staging(10, 15)

def load_staging(conn: pyodbc.Connection, raw_df: pd.DataFrame, run_id: int) -> int:
    """
    Loads raw CSV records into stg.OrdersRaw for auditability and lineage tracking.

    Args:
        conn: Live database connection.
        raw_df: Raw extracted DataFrame.
        run_id: Active ETL Pipeline RunID.

    Returns:
        Number of records loaded into staging.
    """
    logger.info(f"Loading {len(raw_df):,} raw records into stg.OrdersRaw...")
    cursor = conn.cursor()

    query = """
    INSERT INTO stg.OrdersRaw (
        RowID, OrderID, OrderDateRaw, ShipDateRaw, ShipMode,
        CustomerID, CustomerName, Segment, Country, City,
        State, PostalCodeRaw, Region, ProductID, Category,
        SubCategory, ProductName, SalesRaw, QuantityRaw, DiscountRaw,
        ProfitRaw, ETLRunID, IngestionTimestamp
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, SYSUTCDATETIME());
    """

    records = [
        (
            int(row["Row ID"]),
            str(row["Order ID"]),
            str(row["Order Date"]),
            str(row["Ship Date"]),
            str(row["Ship Mode"]),
            str(row["Customer ID"]),
            str(row["Customer Name"]),
            str(row["Segment"]),
            str(row["Country"]),
            str(row["City"]),
            str(row["State"]),
            str(row["Postal Code"]),
            str(row["Region"]),
            str(row["Product ID"]),
            str(row["Category"]),
            str(row["Sub-Category"]),
            str(row["Product Name"]),
            str(row["Sales"]),
            str(row["Quantity"]),
            str(row["Discount"]),
            str(row["Profit"]),
            run_id,
        )
        for _, row in raw_df.iterrows()
    ]

    cursor.fast_executemany = True
    cursor.executemany(query, records)
    conn.commit()
    logger.info(f"Staging load successful: {len(records):,} rows written to stg.OrdersRaw.")
    return len(records)


def load_dimensions(
    conn: pyodbc.Connection,
    dimensions_dict: Dict[str, pd.DataFrame],
    run_id: int
) -> Dict[str, int]:
    """
    Loads distinct dimension records into dw schema with idempotency safeguards.

    Args:
        conn: Live database connection.
        dimensions_dict: Dictionary of dimension DataFrames.
        run_id: Active ETL Pipeline RunID.

    Returns:
        Dictionary of row counts inserted per dimension.
    """
    cursor = conn.cursor()
    counts = {}

    # 1. DimCustomer
    dim_cust = dimensions_dict["dim_customer"]
    logger.info(f"Checking {len(dim_cust):,} customer records against dw.DimCustomer...")
    cust_query = """
    INSERT INTO dw.DimCustomer (CustomerID, CustomerName, CustomerSegment, ETLRunID, LoadedAt)
    SELECT ?, ?, ?, ?, SYSUTCDATETIME()
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.DimCustomer WHERE CustomerID = ?
    );
    """
    cust_data = [
        (r["CustomerID"], r["CustomerName"], r["CustomerSegment"], run_id, r["CustomerID"])
        for _, r in dim_cust.iterrows()
    ]
    cursor.fast_executemany = True
    cursor.executemany(cust_query, cust_data)
    conn.commit()

    cursor.execute("SELECT COUNT(*) FROM dw.DimCustomer;")
    counts["dim_customer"] = int(cursor.fetchone()[0])
    logger.info(f"dw.DimCustomer current total count: {counts['dim_customer']:,}")

    # 2. DimProduct
    dim_prod = dimensions_dict["dim_product"]
    logger.info(f"Checking {len(dim_prod):,} product records against dw.DimProduct...")
    prod_query = """
    INSERT INTO dw.DimProduct (ProductID, ProductName, Category, SubCategory, ETLRunID, LoadedAt)
    SELECT ?, ?, ?, ?, ?, SYSUTCDATETIME()
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.DimProduct 
        WHERE ProductID = ? AND ProductName = ? AND Category = ? AND SubCategory = ?
    );
    """
    prod_data = [
        (
            r["ProductID"], r["ProductName"], r["Category"], r["SubCategory"], run_id,
            r["ProductID"], r["ProductName"], r["Category"], r["SubCategory"]
        )
        for _, r in dim_prod.iterrows()
    ]
    cursor.fast_executemany = True
    cursor.executemany(prod_query, prod_data)
    conn.commit()

    cursor.execute("SELECT COUNT(*) FROM dw.DimProduct;")
    counts["dim_product"] = int(cursor.fetchone()[0])
    logger.info(f"dw.DimProduct current total count: {counts['dim_product']:,}")

    # 3. DimGeography
    dim_geo = dimensions_dict["dim_geography"]
    logger.info(f"Checking {len(dim_geo):,} geography records against dw.DimGeography...")
    geo_query = """
    INSERT INTO dw.DimGeography (PostalCode, City, State, Region, Country, ETLRunID, LoadedAt)
    SELECT ?, ?, ?, ?, ?, ?, SYSUTCDATETIME()
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.DimGeography 
        WHERE PostalCode = ? AND City = ? AND State = ? AND Country = ?
    );
    """
    geo_data = [
        (
            r["PostalCode"], r["City"], r["State"], r["Region"], r["Country"], run_id,
            r["PostalCode"], r["City"], r["State"], r["Country"]
        )
        for _, r in dim_geo.iterrows()
    ]
    cursor.fast_executemany = True
    cursor.executemany(geo_query, geo_data)
    conn.commit()

    cursor.execute("SELECT COUNT(*) FROM dw.DimGeography;")
    counts["dim_geography"] = int(cursor.fetchone()[0])
    logger.info(f"dw.DimGeography current total count: {counts['dim_geography']:,}")

    # 4. DimShipMode
    dim_ship = dimensions_dict["dim_ship_mode"]
    logger.info(f"Checking {len(dim_ship):,} ship mode records against dw.DimShipMode...")
    ship_query = """
    INSERT INTO dw.DimShipMode (ShipModeName, ETLRunID, LoadedAt)
    SELECT ?, ?, SYSUTCDATETIME()
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.DimShipMode WHERE ShipModeName = ?
    );
    """
    ship_data = [(r["ShipModeName"], run_id, r["ShipModeName"]) for _, r in dim_ship.iterrows()]
    cursor.fast_executemany = True
    cursor.executemany(ship_query, ship_data)
    conn.commit()

    cursor.execute("SELECT COUNT(*) FROM dw.DimShipMode;")
    counts["dim_ship_mode"] = int(cursor.fetchone()[0])
    logger.info(f"dw.DimShipMode current total count: {counts['dim_ship_mode']:,}")

    return counts


def get_dimension_lookup_maps(conn: pyodbc.Connection) -> Dict[str, Dict]:
    """
    Retrieves surrogate key mapping dictionaries from database for all dimensions.
    """
    cursor = conn.cursor()

    # Customer Lookup
    cursor.execute("SELECT CustomerID, CustomerKey FROM dw.DimCustomer;")
    cust_map = {row[0]: row[1] for row in cursor.fetchall()}

    # Product Lookup
    cursor.execute("SELECT ProductID, ProductName, Category, SubCategory, ProductKey FROM dw.DimProduct;")
    prod_map = {(row[0], row[1], row[2], row[3]): row[4] for row in cursor.fetchall()}

    # Geography Lookup
    cursor.execute("SELECT PostalCode, City, State, Country, GeographyKey FROM dw.DimGeography;")
    geo_map = {(row[0], row[1], row[2], row[3]): row[4] for row in cursor.fetchall()}

    # ShipMode Lookup
    cursor.execute("SELECT ShipModeName, ShipModeKey FROM dw.DimShipMode;")
    ship_map = {row[0]: row[1] for row in cursor.fetchall()}

    return {
        "customer": cust_map,
        "product": prod_map,
        "geography": geo_map,
        "ship_mode": ship_map,
    }


def load_fact(conn: pyodbc.Connection, fact_df: pd.DataFrame, run_id: int) -> int:
    """
    Resolves surrogate keys and batch-inserts records into dw.FactSales.
    Employs safe idempotent insertion: skips source rows that are already loaded.

    Args:
        conn: Live database connection.
        fact_df: Transformed DataFrame.
        run_id: Active ETL Pipeline RunID.

    Returns:
        Number of fact records inserted.
    """
    logger.info(f"Resolving foreign keys for {len(fact_df):,} fact records...")
    maps = get_dimension_lookup_maps(conn)

    cust_map = maps["customer"]
    prod_map = maps["product"]
    geo_map = maps["geography"]
    ship_map = maps["ship_mode"]

    fact_records = []
    unmapped_errors = 0

    for idx, r in fact_df.iterrows():
        # Resolve CustomerKey
        c_key = cust_map.get(r["Customer ID"])
        if c_key is None:
            logger.error(f"Unmapped Customer: {r['Customer ID']} at Row ID {r['Row ID']}")
            unmapped_errors += 1

        # Resolve ProductKey
        p_tuple = (r["Product ID"], r["Product Name"], r["Category"], r["Sub-Category"])
        p_key = prod_map.get(p_tuple)
        if p_key is None:
            logger.error(f"Unmapped Product: {p_tuple} at Row ID {r['Row ID']}")
            unmapped_errors += 1

        # Resolve GeographyKey
        g_tuple = (r["NormalizedPostalCode"], r["City"], r["State"], r["Country"])
        g_key = geo_map.get(g_tuple)
        if g_key is None:
            logger.error(f"Unmapped Geography: {g_tuple} at Row ID {r['Row ID']}")
            unmapped_errors += 1

        # Resolve ShipModeKey
        s_key = ship_map.get(r["Ship Mode"])
        if s_key is None:
            logger.error(f"Unmapped ShipMode: {r['Ship Mode']} at Row ID {r['Row ID']}")
            unmapped_errors += 1

        if c_key and p_key and g_key and s_key:
            fact_records.append((
                int(r["Row ID"]),
                str(r["Order ID"]),
                int(r["OrderDateKey"]),
                int(r["ShipDateKey"]),
                int(c_key),
                int(p_key),
                int(g_key),
                int(s_key),
                float(r["Sales"]),
                int(r["Quantity"]),
                float(r["Discount"]),
                float(r["Profit"]),
                float(r["CalculatedCost"]),
                float(r["ProfitMargin"]),
                int(r["ShippingDurationDays"]),
                int(run_id),
                int(r["Row ID"])  # for WHERE NOT EXISTS check
            ))

    if unmapped_errors > 0:
        err_msg = f"Failed to map surrogate keys for {unmapped_errors} dimension references."
        logger.error(err_msg)
        raise ValueError(err_msg)

    logger.info(f"All {len(fact_records):,} fact records successfully mapped to dimension keys.")

    cursor = conn.cursor()
    fact_query = """
    INSERT INTO dw.FactSales (
        SourceRowID, OrderID, OrderDateKey, ShipDateKey, CustomerKey,
        ProductKey, GeographyKey, ShipModeKey, SalesAmount, Quantity,
        DiscountRate, ProfitAmount, CalculatedCost, ProfitMargin,
        ShippingDurationDays, ETLRunID, LoadedAt
    )
    SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, SYSUTCDATETIME()
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.FactSales WHERE SourceRowID = ?
    );
    """

    cursor.fast_executemany = True
    cursor.executemany(fact_query, fact_records)
    conn.commit()

    cursor.execute("SELECT COUNT(*) FROM dw.FactSales;")
    total_facts = int(cursor.fetchone()[0])
    logger.info(f"dw.FactSales load complete. Total rows in Fact table: {total_facts:,}")

    return len(fact_records)
