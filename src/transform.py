"""
src/transform.py
Data transformation module: normalizes strings, standardizes postal codes,
generates integer date keys, calculates derived metrics, and extracts dimension entities.
"""

from typing import Dict, Any, Tuple
import pandas as pd
import numpy as np
from src.config import setup_logger

logger = setup_logger("ETLPipeline.Transform")


def normalize_postal_code(val: Any) -> str:
    """Safely formats postal codes into zero-padded 5-character US ZIP strings."""
    if pd.isna(val):
        return "00000"
    raw_str = str(val).strip().split(".")[0]  # Remove trailing float decimals if present
    # Keep only digits
    digits = "".join(ch for ch in raw_str if ch.isdigit())
    if not digits:
        return "00000"
    return digits.zfill(5)[:5]


def transform_data(valid_df: pd.DataFrame) -> Tuple[pd.DataFrame, Dict[str, pd.DataFrame]]:
    """
    Transforms clean validated records into warehouse-ready fact and dimension representations.

    Args:
        valid_df: Validated DataFrame from validate_records.

    Returns:
        Tuple containing:
            - fact_df: Transformed records ready for dw.FactSales
            - dimensions_dict: Dictionary containing DataFrames for:
                - 'dim_customer'
                - 'dim_product'
                - 'dim_geography'
                - 'dim_ship_mode'
    """
    logger.info(f"Transforming {len(valid_df):,} validated records for warehouse loading.")

    df = valid_df.copy()

    # 1. Standardize Whitespace for Text Columns
    text_cols = [
        "Order ID", "Ship Mode", "Customer ID", "Customer Name", "Segment",
        "Country", "City", "State", "Region", "Product ID", "Category",
        "Sub-Category", "Product Name"
    ]
    for col in text_cols:
        df[col] = df[col].astype(str).str.strip()

    # 2. Normalize Postal Codes to 5-Digit Zero-Padded Strings
    df["NormalizedPostalCode"] = df["Postal Code"].apply(normalize_postal_code)

    # 3. Generate Integer Date Keys (YYYYMMDD)
    df["OrderDateKey"] = (
        df["Order_Date_DT"].dt.year * 10000 +
        df["Order_Date_DT"].dt.month * 100 +
        df["Order_Date_DT"].dt.day
    ).astype(int)

    df["ShipDateKey"] = (
        df["Ship_Date_DT"].dt.year * 10000 +
        df["Ship_Date_DT"].dt.month * 100 +
        df["Ship_Date_DT"].dt.day
    ).astype(int)

    # 4. Calculate Derived Metrics
    # Shipping duration in calendar days
    df["ShippingDurationDays"] = (df["Ship_Date_DT"] - df["Order_Date_DT"]).dt.days.astype(int)

    # Calculated Cost (Documented estimated derived metric: Sales - Profit)
    df["CalculatedCost"] = (df["Sales"] - df["Profit"]).round(4)

    # Safe Profit Margin (Zero division safeguard)
    df["ProfitMargin"] = np.where(
        df["Sales"] > 0,
        (df["Profit"] / df["Sales"]).round(4),
        0.0
    )

    # 5. Extract Unique Dimension DataFrames
    # Customer Dimension
    dim_customer = df[["Customer ID", "Customer Name", "Segment"]].drop_duplicates().copy()
    dim_customer.rename(columns={
        "Customer ID": "CustomerID",
        "Customer Name": "CustomerName",
        "Segment": "CustomerSegment",
    }, inplace=True)

    # Product Dimension (Preserves all 1,894 unique ProductID, ProductName, Category, SubCategory tuples)
    dim_product = df[["Product ID", "Product Name", "Category", "Sub-Category"]].drop_duplicates().copy()
    dim_product.rename(columns={
        "Product ID": "ProductID",
        "Product Name": "ProductName",
        "Category": "Category",
        "Sub-Category": "SubCategory",
    }, inplace=True)

    # Geography Dimension (Unique PostalCode, City, State, Region, Country)
    dim_geography = df[["NormalizedPostalCode", "City", "State", "Region", "Country"]].drop_duplicates().copy()
    dim_geography.rename(columns={
        "NormalizedPostalCode": "PostalCode",
    }, inplace=True)

    # Ship Mode Dimension
    dim_ship_mode = df[["Ship Mode"]].drop_duplicates().copy()
    dim_ship_mode.rename(columns={
        "Ship Mode": "ShipModeName",
    }, inplace=True)

    dimensions_dict = {
        "dim_customer": dim_customer,
        "dim_product": dim_product,
        "dim_geography": dim_geography,
        "dim_ship_mode": dim_ship_mode,
    }

    logger.info(
        f"Transform complete: {len(df):,} fact records prepared. "
        f"Extracted dimensions -> Customers: {len(dim_customer):,}, "
        f"Products: {len(dim_product):,}, Geographies: {len(dim_geography):,}, "
        f"Ship Modes: {len(dim_ship_mode):,}."
    )

    return df, dimensions_dict
