"""
tests/test_load.py
Integration tests for SQL Server database connectivity, referential integrity,
and warehouse table persistence.
"""

import pytest
import pyodbc
from src.config import get_db_connection


@pytest.fixture(scope="module")
def db_conn():
    """Provides a live database connection for integration tests."""
    try:
        conn = get_db_connection()
        yield conn
        conn.close()
    except Exception as e:
        pytest.skip(f"SQL Server integration test skipped: Unable to connect ({e})")


def test_db_connection_live(db_conn: pyodbc.Connection):
    """Verify live connectivity and database engine version."""
    cursor = db_conn.cursor()
    cursor.execute("SELECT @@SERVERNAME, DB_NAME();")
    row = cursor.fetchone()
    assert row is not None
    assert row[1] == "AnalyticsDW"


def test_warehouse_table_counts(db_conn: pyodbc.Connection):
    """Verify that expected benchmark row counts exist in warehouse tables."""
    cursor = db_conn.cursor()

    # FactSales must have exactly 9,994 rows
    cursor.execute("SELECT COUNT(*) FROM dw.FactSales;")
    fact_count = cursor.fetchone()[0]
    assert fact_count == 9994

    # DimCustomer must have 793 unique customers
    cursor.execute("SELECT COUNT(*) FROM dw.DimCustomer;")
    cust_count = cursor.fetchone()[0]
    assert cust_count == 793

    # DimProduct must have 1,894 unique product combinations
    cursor.execute("SELECT COUNT(*) FROM dw.DimProduct;")
    prod_count = cursor.fetchone()[0]
    assert prod_count == 1894

    # DimGeography must have 632 unique geographies
    cursor.execute("SELECT COUNT(*) FROM dw.DimGeography;")
    geo_count = cursor.fetchone()[0]
    assert geo_count == 632

    # DimShipMode must have 4 fulfillment channels
    cursor.execute("SELECT COUNT(*) FROM dw.DimShipMode;")
    ship_count = cursor.fetchone()[0]
    assert ship_count == 4


def test_foreign_key_referential_integrity(db_conn: pyodbc.Connection):
    """Verify that dw.FactSales contains ZERO orphaned foreign key references."""
    cursor = db_conn.cursor()

    queries = [
        ("OrderDateKey", "dw.DimDate", "DateKey"),
        ("ShipDateKey", "dw.DimDate", "DateKey"),
        ("CustomerKey", "dw.DimCustomer", "CustomerKey"),
        ("ProductKey", "dw.DimProduct", "ProductKey"),
        ("GeographyKey", "dw.DimGeography", "GeographyKey"),
        ("ShipModeKey", "dw.DimShipMode", "ShipModeKey"),
    ]

    for fk_col, dim_table, pk_col in queries:
        check_query = f"""
        SELECT COUNT(*)
        FROM dw.FactSales f
        LEFT JOIN {dim_table} d ON f.{fk_col} = d.{pk_col}
        WHERE d.{pk_col} IS NULL;
        """
        cursor.execute(check_query)
        orphans = cursor.fetchone()[0]
        assert orphans == 0, f"Detected {orphans} orphaned records for FK {fk_col} referencing {dim_table}!"
