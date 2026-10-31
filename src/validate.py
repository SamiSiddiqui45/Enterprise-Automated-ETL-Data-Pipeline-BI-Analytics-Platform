"""
src/validate.py
Data validation and quality assurance module: detects invalid rows,
type discrepancies, constraint violations, and records quarantine entries.
"""

import json
from typing import Tuple, List, Dict, Any
import pandas as pd
import numpy as np
from src.config import setup_logger

logger = setup_logger("ETLPipeline.Validate")


def validate_records(df_raw: pd.DataFrame) -> Tuple[pd.DataFrame, List[Dict[str, Any]]]:
    """
    Validates extracted raw data against data types, business constraints,
    temporal sequence, and key uniqueness.

    Args:
        df_raw: Raw DataFrame as extracted from CSV.

    Returns:
        Tuple containing:
            - Validated DataFrame with clean, typed columns
            - List of rejected record dictionaries ready for etl.RejectedRecords
    """
    logger.info(f"Starting data validation across {len(df_raw):,} raw records.")

    valid_indices = set(df_raw.index)
    rejected_records: List[Dict[str, Any]] = []

    def reject_row(idx: int, reason: str, col: str = None, val: Any = None):
        """Helper to mark an index as rejected and append audit details."""
        if idx in valid_indices:
            valid_indices.remove(idx)
        raw_dict = df_raw.loc[idx].to_dict()
        source_row_id = raw_dict.get("Row ID")
        try:
            source_row_id = int(source_row_id) if source_row_id is not None else None
        except ValueError:
            source_row_id = None

        rejected_records.append({
            "SourceRowID": source_row_id,
            "OrderID": str(raw_dict.get("Order ID", "")),
            "RejectionReason": reason,
            "RejectedColumn": col,
            "RejectedValue": str(val) if val is not None else None,
            "RawRecordJSON": json.dumps(raw_dict, default=str),
        })

    # 1. Check for Duplicate Row IDs in Source
    duplicate_row_ids = df_raw[df_raw.duplicated(subset=["Row ID"], keep=False)]
    if not duplicate_row_ids.empty:
        for idx, row in duplicate_row_ids.iterrows():
            reject_row(idx, "DUPLICATE_SOURCE_ROW_ID", "Row ID", row["Row ID"])
        logger.warning(f"Detected {len(duplicate_row_ids)} duplicate Row ID entries.")

    # 2. Check for Missing Critical Business Keys
    critical_cols = [
        "Row ID", "Order ID", "Customer ID", "Product ID", "Order Date", "Ship Date",
        "Sales", "Quantity", "Discount", "Profit"
    ]
    for col in critical_cols:
        null_mask = df_raw[col].isna() | (df_raw[col].astype(str).str.strip() == "")
        for idx in df_raw[null_mask].index:
            if idx in valid_indices:
                reject_row(idx, f"NULL_OR_EMPTY_{col.upper().replace(' ', '_')}", col, df_raw.at[idx, col])

    # 3. Numeric Conversions and Domain Constraints
    for idx in list(valid_indices):
        # Validate Row ID
        try:
            r_id = int(df_raw.at[idx, "Row ID"])
            if r_id <= 0:
                reject_row(idx, "INVALID_ROW_ID_NON_POSITIVE", "Row ID", r_id)
                continue
        except (ValueError, TypeError):
            reject_row(idx, "ROW_ID_NOT_INTEGER", "Row ID", df_raw.at[idx, "Row ID"])
            continue

        # Validate Sales
        try:
            sales = float(df_raw.at[idx, "Sales"])
            if sales < 0.0:
                reject_row(idx, "NEGATIVE_SALES_AMOUNT", "Sales", sales)
                continue
        except (ValueError, TypeError):
            reject_row(idx, "SALES_NOT_NUMERIC", "Sales", df_raw.at[idx, "Sales"])
            continue

        # Validate Quantity
        try:
            qty = int(df_raw.at[idx, "Quantity"])
            if qty <= 0:
                reject_row(idx, "QUANTITY_NON_POSITIVE", "Quantity", qty)
                continue
        except (ValueError, TypeError):
            reject_row(idx, "QUANTITY_NOT_INTEGER", "Quantity", df_raw.at[idx, "Quantity"])
            continue

        # Validate Discount
        try:
            disc = float(df_raw.at[idx, "Discount"])
            if disc < 0.0 or disc > 1.0:
                reject_row(idx, "DISCOUNT_OUT_OF_BOUNDS_0_TO_1", "Discount", disc)
                continue
        except (ValueError, TypeError):
            reject_row(idx, "DISCOUNT_NOT_NUMERIC", "Discount", df_raw.at[idx, "Discount"])
            continue

        # Validate Profit
        try:
            _ = float(df_raw.at[idx, "Profit"])
        except (ValueError, TypeError):
            reject_row(idx, "PROFIT_NOT_NUMERIC", "Profit", df_raw.at[idx, "Profit"])
            continue

    # 4. Explicit Date Parsing and Temporal Consistency
    for idx in list(valid_indices):
        order_date_str = str(df_raw.at[idx, "Order Date"]).strip()
        ship_date_str = str(df_raw.at[idx, "Ship Date"]).strip()

        try:
            order_dt = pd.to_datetime(order_date_str, format="%m/%d/%Y", errors="raise")
        except Exception:
            reject_row(idx, "INVALID_ORDER_DATE_FORMAT", "Order Date", order_date_str)
            continue

        try:
            ship_dt = pd.to_datetime(ship_date_str, format="%m/%d/%Y", errors="raise")
        except Exception:
            reject_row(idx, "INVALID_SHIP_DATE_FORMAT", "Ship Date", ship_date_str)
            continue

        if ship_dt < order_dt:
            reject_row(idx, "SHIP_DATE_PRECEDES_ORDER_DATE", "Ship Date", f"Order: {order_date_str}, Ship: {ship_date_str}")
            continue

    # Create Clean Validated DataFrame
    valid_df = df_raw.loc[sorted(list(valid_indices))].copy()

    # Cast Clean Data to Proper Types
    valid_df["Row ID"] = valid_df["Row ID"].astype(int)
    valid_df["Sales"] = valid_df["Sales"].astype(float)
    valid_df["Quantity"] = valid_df["Quantity"].astype(int)
    valid_df["Discount"] = valid_df["Discount"].astype(float)
    valid_df["Profit"] = valid_df["Profit"].astype(float)
    valid_df["Order_Date_DT"] = pd.to_datetime(valid_df["Order Date"], format="%m/%d/%Y")
    valid_df["Ship_Date_DT"] = pd.to_datetime(valid_df["Ship Date"], format="%m/%d/%Y")

    logger.info(
        f"Validation summary: {len(valid_df):,} rows valid (PASS), "
        f"{len(rejected_records):,} rows rejected (QUARANTINED)."
    )
    return valid_df, rejected_records
