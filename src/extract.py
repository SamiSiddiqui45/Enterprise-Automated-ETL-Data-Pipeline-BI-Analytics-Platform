"""
src/extract.py
Data extraction module: safely reads and validates raw source CSV.
"""

from pathlib import Path
from typing import Tuple, Dict, Any
import pandas as pd
from src.config import setup_logger, EXPECTED_COLUMNS, CSV_ENCODING, SOURCE_CSV_PATH

logger = setup_logger("ETLPipeline.Extract")


def extract_data(file_path: Path = SOURCE_CSV_PATH, encoding: str = CSV_ENCODING) -> Tuple[pd.DataFrame, Dict[str, Any]]:
    """
    Reads source CSV file with proper character encoding and header validation.

    Args:
        file_path: Path to the raw CSV file.
        encoding: File character encoding (default: cp1252/windows-1252).

    Returns:
        Tuple containing:
            - Extracted raw pandas DataFrame
            - Metadata dictionary (file name, file size, row count, column count)
    
    Raises:
        FileNotFoundError: If the source CSV does not exist.
        ValueError: If required columns are missing or file is empty.
    """
    logger.info(f"Initiating extraction from: {file_path}")

    path_obj = Path(file_path)
    if not path_obj.exists():
        err_msg = f"Source CSV file does not exist at specified path: {path_obj}"
        logger.error(err_msg)
        raise FileNotFoundError(err_msg)

    file_size_bytes = path_obj.stat().st_size
    logger.info(f"Verified source file presence. Size: {file_size_bytes:,} bytes.")

    try:
        # Read CSV with exact encoding
        df = pd.read_csv(path_obj, encoding=encoding, dtype=str)
    except Exception as e:
        logger.error(f"Failed to read CSV with encoding '{encoding}': {e}")
        raise

    # Check for empty file
    if df.empty:
        err_msg = f"Source CSV at {path_obj} is empty (0 records)."
        logger.error(err_msg)
        raise ValueError(err_msg)

    # Validate required headers
    missing_cols = [col for col in EXPECTED_COLUMNS if col not in df.columns]
    if missing_cols:
        err_msg = f"Source CSV is missing required headers: {missing_cols}"
        logger.error(err_msg)
        raise ValueError(err_msg)

    extra_cols = [col for col in df.columns if col not in EXPECTED_COLUMNS]
    if extra_cols:
        logger.warning(f"Source CSV contains additional unexpected columns: {extra_cols}")

    metadata = {
        "source_file": str(path_obj.name),
        "source_path": str(path_obj.resolve()),
        "file_size_bytes": file_size_bytes,
        "row_count": len(df),
        "column_count": len(df.columns),
        "columns": list(df.columns),
    }

    logger.info(
        f"Extraction complete. Successfully loaded {len(df):,} rows and {len(df.columns)} columns."
    )
    return df, metadata
