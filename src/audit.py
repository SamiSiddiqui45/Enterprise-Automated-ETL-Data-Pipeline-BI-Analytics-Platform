"""
src/audit.py
ETL audit, execution logging, and quarantine recording module.
"""

from typing import List, Dict, Any, Optional
import pyodbc
from src.config import setup_logger

logger = setup_logger("ETLPipeline.Audit")


def start_pipeline_run(conn: pyodbc.Connection, source_file_name: str, source_row_count: int) -> int:
    """
    Creates an initial execution record in etl.PipelineRuns with status 'RUNNING'.

    Args:
        conn: Live database connection.
        source_file_name: Name of the input CSV.
        source_row_count: Number of records in the raw source file.

    Returns:
        The generated RunID.
    """
    cursor = conn.cursor()
    query = """
    INSERT INTO etl.PipelineRuns (
        StartTime, Status, SourceFileName, SourceRowCount
    )
    OUTPUT INSERTED.RunID
    VALUES (SYSUTCDATETIME(), 'RUNNING', ?, ?);
    """
    cursor.execute(query, (source_file_name, source_row_count))
    row = cursor.fetchone()
    run_id = int(row[0])
    conn.commit()
    logger.info(f"Initialized ETL Pipeline RunID: {run_id} for source: {source_file_name}")
    return run_id


def complete_pipeline_run(
    conn: pyodbc.Connection,
    run_id: int,
    status: str,
    counts: Dict[str, int],
    error_message: Optional[str] = None
) -> None:
    """
    Updates the execution record in etl.PipelineRuns with completion status and metrics.

    Args:
        conn: Live database connection.
        run_id: Pipeline RunID to update.
        status: 'SUCCESS', 'FAILED', or 'PARTIAL'.
        counts: Dictionary with counts for staging, dimensions, fact, rejected.
        error_message: Optional error message string if failed.
    """
    cursor = conn.cursor()
    query = """
    UPDATE etl.PipelineRuns
    SET EndTime = SYSUTCDATETIME(),
        Status = ?,
        StagingRowCount = ?,
        DimCustomerCount = ?,
        DimProductCount = ?,
        DimGeographyCount = ?,
        DimShipModeCount = ?,
        FactRowCount = ?,
        RejectedRowCount = ?,
        ErrorMessage = ?
    WHERE RunID = ?;
    """
    cursor.execute(
        query,
        (
            status,
            counts.get("staging", 0),
            counts.get("dim_customer", 0),
            counts.get("dim_product", 0),
            counts.get("dim_geography", 0),
            counts.get("dim_ship_mode", 0),
            counts.get("fact", 0),
            counts.get("rejected", 0),
            error_message,
            run_id,
        )
    )
    conn.commit()
    logger.info(f"Finalized Pipeline RunID: {run_id} with Status: '{status}'.")


def log_rejected_records(
    conn: pyodbc.Connection,
    run_id: int,
    rejected_records: List[Dict[str, Any]]
) -> int:
    """
    Inserts quarantined records into etl.RejectedRecords for data quality auditing.

    Args:
        conn: Live database connection.
        run_id: Pipeline RunID.
        rejected_records: List of rejected record dictionaries.

    Returns:
        Number of rejected records inserted.
    """
    if not rejected_records:
        logger.info("No rejected records to log. 100% of rows passed validation.")
        return 0

    cursor = conn.cursor()
    query = """
    INSERT INTO etl.RejectedRecords (
        ETLRunID, SourceRowID, OrderID, RejectionReason,
        RejectedColumn, RejectedValue, RawRecordJSON, LoggedAt
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, SYSUTCDATETIME());
    """
    records_to_insert = [
        (
            run_id,
            r.get("SourceRowID"),
            r.get("OrderID"),
            r.get("RejectionReason"),
            r.get("RejectedColumn"),
            r.get("RejectedValue"),
            r.get("RawRecordJSON"),
        )
        for r in rejected_records
    ]

    cursor.fast_executemany = True
    cursor.executemany(query, records_to_insert)
    conn.commit()
    logger.warning(f"Quarantined {len(records_to_insert):,} invalid records into etl.RejectedRecords.")
    return len(records_to_insert)
