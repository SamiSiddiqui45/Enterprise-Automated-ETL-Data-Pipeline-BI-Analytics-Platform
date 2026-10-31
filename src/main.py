"""
src/main.py
ETL Pipeline Orchestrator and CLI Entry Point.
Executes extraction, validation, transformation, staging, dimensional loading,
fact loading, audit tracking, and financial reconciliation.
"""

import sys
import argparse
import time
from pathlib import Path
import pyodbc

from src.config import setup_logger, get_db_connection, SOURCE_CSV_PATH, CSV_ENCODING
from src.extract import extract_data
from src.validate import validate_records
from src.transform import transform_data
from src.load import load_staging, load_dimensions, load_fact
from src.audit import start_pipeline_run, complete_pipeline_run, log_rejected_records

logger = setup_logger("ETLPipeline.Main")


def run_reconciliation(conn: pyodbc.Connection) -> bool:
    """
    Executes the reconciliation queries against SQL Server and prints results to console.
    Returns True if all reconciliation tests pass, False otherwise.
    """
    logger.info("Executing automated financial & metric reconciliation against warehouse...")
    cursor = conn.cursor()

    query = """
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
    """

    cursor.execute(query)
    rows = cursor.fetchall()

    print("\n" + "=" * 90)
    print("                     FINANCIAL & METRIC RECONCILIATION REPORT")
    print("=" * 90)
    header = f"{'Metric Name':<28} | {'Expected':<14} | {'Actual':<14} | {'Variance':<12} | {'Status':<8}"
    print(header)
    print("-" * 90)

    all_passed = True
    for r in rows:
        metric, exp, act, var, status = r[0], str(r[1]), str(r[2]), str(r[3]), str(r[4])
        print(f"{metric:<28} | {exp:<14} | {act:<14} | {var:<12} | {status:<8}")
        if status != "PASSED":
            all_passed = False

    print("=" * 90 + "\n")
    return all_passed


def main():
    parser = argparse.ArgumentParser(description="Enterprise Superstore Automated ETL Pipeline")
    parser.add_argument("--csv-path", type=str, default=str(SOURCE_CSV_PATH), help="Path to source CSV file")
    parser.add_argument("--encoding", type=str, default=CSV_ENCODING, help="Source CSV encoding")
    parser.add_argument("--skip-reconciliation", action="store_true", help="Skip post-load reconciliation query")
    args = parser.parse_args()

    start_time = time.time()
    csv_file = Path(args.csv_path)

    print("\n" + "#" * 80)
    print("       ENTERPRISE AUTOMATED ETL PIPELINE - DATA WAREHOUSE INGESTION")
    print("#" * 80)
    logger.info(f"Starting ETL execution for source: {csv_file}")

    conn = None
    run_id = None
    try:
        # 1. Establish Database Connection
        conn = get_db_connection()
        logger.info("Connected to SQL Server successfully.")

        # 2. Extract Data
        raw_df, meta = extract_data(file_path=csv_file, encoding=args.encoding)

        # 3. Initialize Audit Run
        run_id = start_pipeline_run(
            conn=conn,
            source_file_name=meta["source_file"],
            source_row_count=meta["row_count"],
        )

        # 4. Validate Data
        valid_df, rejected_records = validate_records(df_raw=raw_df)

        # 5. Quarantine Rejected Records (if any)
        if rejected_records:
            log_rejected_records(conn=conn, run_id=run_id, rejected_records=rejected_records)

        # 6. Transform Data
        fact_df, dimensions_dict = transform_data(valid_df=valid_df)

        # 7. Load Staging Table
        staging_count = load_staging(conn=conn, raw_df=raw_df, run_id=run_id)

        # 8. Load Dimensions
        dim_counts = load_dimensions(conn=conn, dimensions_dict=dimensions_dict, run_id=run_id)

        # 9. Load Fact Table
        fact_count = load_fact(conn=conn, fact_df=fact_df, run_id=run_id)

        # 10. Finalize Audit Record
        counts_summary = {
            "staging": staging_count,
            "dim_customer": dim_counts.get("dim_customer", 0),
            "dim_product": dim_counts.get("dim_product", 0),
            "dim_geography": dim_counts.get("dim_geography", 0),
            "dim_ship_mode": dim_counts.get("dim_ship_mode", 0),
            "fact": fact_count,
            "rejected": len(rejected_records),
        }
        complete_pipeline_run(
            conn=conn,
            run_id=run_id,
            status="SUCCESS",
            counts=counts_summary,
            error_message=None,
        )

        elapsed = round(time.time() - start_time, 2)
        print("\n" + "=" * 70)
        print("                  ETL EXECUTION SUMMARY (RUN ID: {})".format(run_id))
        print("=" * 70)
        print(f" Source File:         {meta['source_file']}")
        print(f" Source Rows Read:    {meta['row_count']:,}")
        print(f" Staging Rows Loaded: {staging_count:,}")
        print(f" Dimension Customers: {dim_counts.get('dim_customer', 0):,}")
        print(f" Dimension Products:  {dim_counts.get('dim_product', 0):,}")
        print(f" Dimension Geography: {dim_counts.get('dim_geography', 0):,}")
        print(f" Dimension ShipModes: {dim_counts.get('dim_ship_mode', 0):,}")
        print(f" Fact Rows Loaded:    {fact_count:,}")
        print(f" Quarantined Rows:    {len(rejected_records):,}")
        print(f" Status:              SUCCESS")
        print(f" Total Runtime:       {elapsed} seconds")
        print("=" * 70 + "\n")

        # 11. Run Automated Reconciliation
        if not args.skip_reconciliation:
            reconciliation_ok = run_reconciliation(conn=conn)
            if not reconciliation_ok:
                logger.warning("Reconciliation reported one or more metric mismatches.")
            else:
                logger.info("All reconciliation metrics matched 100% with source benchmarks.")

    except Exception as e:
        logger.error(f"ETL Execution FAILED: {e}", exc_info=True)
        if conn and run_id:
            try:
                complete_pipeline_run(
                    conn=conn,
                    run_id=run_id,
                    status="FAILED",
                    counts={},
                    error_message=str(e),
                )
            except Exception as audit_err:
                logger.error(f"Failed to record failure in audit table: {audit_err}")
        sys.exit(1)
    finally:
        if conn:
            conn.close()
            logger.info("Database connection closed cleanly.")


if __name__ == "__main__":
    main()
