"""
tests/test_validate.py
Unit tests for data validation and quarantine module.
"""

import pandas as pd
from src.validate import validate_records


def test_validate_records_clean_dataset(sample_valid_raw_df: pd.DataFrame):
    """Verify that a valid dataset produces 100% valid records and 0 rejections."""
    valid_df, rejected = validate_records(sample_valid_raw_df)
    assert len(valid_df) == 3
    assert len(rejected) == 0
    assert valid_df["Row ID"].dtype == int
    assert valid_df["Sales"].dtype == float
    assert valid_df["Quantity"].dtype == int
    assert valid_df["Discount"].dtype == float
    assert valid_df["Profit"].dtype == float


def test_validate_records_catches_anomalies(sample_invalid_raw_df: pd.DataFrame):
    """Verify that anomalous rows are properly quarantined with clear rejection reasons."""
    valid_df, rejected = validate_records(sample_invalid_raw_df)

    assert len(valid_df) == 0
    assert len(rejected) >= 4

    reasons = [r["RejectionReason"] for r in rejected]
    assert any("QUANTITY" in r for r in reasons)
    assert any("DISCOUNT" in r for r in reasons)
    assert any("PRECEDES" in r for r in reasons)
    assert any("DUPLICATE_SOURCE_ROW_ID" in r for r in reasons)


def test_validate_records_catches_null_keys(sample_valid_raw_df: pd.DataFrame):
    """Verify that null business keys are rejected."""
    corrupt_df = sample_valid_raw_df.copy()
    corrupt_df.at[0, "Order ID"] = ""  # Empty string key

    valid_df, rejected = validate_records(corrupt_df)
    assert len(valid_df) == 2
    assert len(rejected) == 1
    assert "NULL_OR_EMPTY_ORDER_ID" in rejected[0]["RejectionReason"]
