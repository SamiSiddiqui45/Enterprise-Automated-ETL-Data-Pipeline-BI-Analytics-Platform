"""
tests/test_transform.py
Unit tests for data transformation and metric calculations.
"""

import pandas as pd
from src.transform import normalize_postal_code, transform_data
from src.validate import validate_records


def test_normalize_postal_code():
    """Verify that postal codes are correctly formatted as 5-character zero-padded strings."""
    assert normalize_postal_code(1040) == "01040"
    assert normalize_postal_code("1040") == "01040"
    assert normalize_postal_code("90036") == "90036"
    assert normalize_postal_code(90036) == "90036"
    assert normalize_postal_code("7090.0") == "07090"
    assert normalize_postal_code(None) == "00000"


def test_transform_data_calculations(sample_valid_raw_df: pd.DataFrame):
    """Verify metric calculations, date keys, and dimensional extraction."""
    valid_df, _ = validate_records(sample_valid_raw_df)
    fact_df, dims = transform_data(valid_df)

    # Check Date Keys
    assert fact_df.at[0, "OrderDateKey"] == 20161108
    assert fact_df.at[0, "ShipDateKey"] == 20161111

    # Check Shipping Duration (Nov 11 - Nov 8 = 3 days)
    assert fact_df.at[0, "ShippingDurationDays"] == 3

    # Check Calculated Cost (261.96 - 41.9136 = 220.0464)
    expected_cost = round(261.96 - 41.9136, 4)
    assert abs(fact_df.at[0, "CalculatedCost"] - expected_cost) < 0.0001

    # Check Profit Margin (41.9136 / 261.96 = 0.1600)
    expected_margin = round(41.9136 / 261.96, 4)
    assert abs(fact_df.at[0, "ProfitMargin"] - expected_margin) < 0.0001

    # Check Dimension Extractions
    assert "dim_customer" in dims
    assert "dim_product" in dims
    assert "dim_geography" in dims
    assert "dim_ship_mode" in dims

    assert len(dims["dim_customer"]) == 2  # Claire Gute and Darrin Van Huff
    assert len(dims["dim_product"]) == 3
    assert len(dims["dim_ship_mode"]) == 1  # Second Class
