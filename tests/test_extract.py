"""
tests/test_extract.py
Unit tests for data extraction module.
"""

from pathlib import Path
import pytest
from src.extract import extract_data
from src.config import EXPECTED_COLUMNS, SOURCE_CSV_PATH


def test_extract_real_csv_success():
    """Verify that extract_data successfully reads the canonical source CSV."""
    df, meta = extract_data(file_path=SOURCE_CSV_PATH)
    assert not df.empty
    assert len(df) == 9994
    assert len(df.columns) == 21
    assert meta["row_count"] == 9994
    assert meta["column_count"] == 21
    for col in EXPECTED_COLUMNS:
        assert col in df.columns


def test_extract_missing_file_raises_error(tmp_path: Path):
    """Verify that attempting to extract a non-existent file raises FileNotFoundError."""
    missing_file = tmp_path / "non_existent_superstore.csv"
    with pytest.raises(FileNotFoundError):
        extract_data(file_path=missing_file)


def test_extract_empty_file_raises_error(tmp_path: Path):
    """Verify that attempting to extract an empty CSV raises ValueError."""
    empty_file = tmp_path / "empty.csv"
    empty_file.write_text("", encoding="utf-8")
    with pytest.raises(ValueError):
        extract_data(file_path=empty_file)


def test_extract_missing_columns_raises_error(tmp_path: Path):
    """Verify that a CSV missing required columns raises ValueError."""
    bad_csv = tmp_path / "bad_columns.csv"
    bad_csv.write_text("Row ID,Order ID,Sales\n1,CA-101,50.0\n", encoding="utf-8")
    with pytest.raises(ValueError) as excinfo:
        extract_data(file_path=bad_csv)
    assert "missing required headers" in str(excinfo.value)
