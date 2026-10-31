"""
src/config.py
Configuration loader, database connection factory, and logging setup.
"""

import os
import sys
import logging
from pathlib import Path
from dotenv import load_dotenv
import pyodbc

# Base directory of the project
BASE_DIR = Path(__file__).resolve().parent.parent

# Load environment variables from .env if present
ENV_PATH = BASE_DIR / ".env"
if ENV_PATH.exists():
    load_dotenv(dotenv_path=ENV_PATH)
else:
    load_dotenv()

# Database Configuration
DB_SERVER = os.getenv("DB_SERVER", r".\SQLEXPRESS")
DB_NAME = os.getenv("DB_NAME", "AnalyticsDW")
DB_DRIVER = os.getenv("DB_DRIVER", "ODBC Driver 18 for SQL Server")
DB_TRUSTED_CONNECTION = os.getenv("DB_TRUSTED_CONNECTION", "yes").lower() in ("yes", "true", "1")
DB_TRUST_SERVER_CERTIFICATE = os.getenv("DB_TRUST_SERVER_CERTIFICATE", "yes").lower() in ("yes", "true", "1")
DB_USER = os.getenv("DB_USER", "")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

# File and Source Configuration
DEFAULT_CSV = BASE_DIR / "archive (1)" / "Sample - Superstore.csv"
SOURCE_CSV_PATH = Path(os.getenv("SOURCE_CSV_PATH", str(DEFAULT_CSV)))
if not SOURCE_CSV_PATH.is_absolute():
    SOURCE_CSV_PATH = BASE_DIR / SOURCE_CSV_PATH

CSV_ENCODING = os.getenv("CSV_ENCODING", "cp1252")

# Logging Configuration
LOG_LEVEL_STR = os.getenv("LOG_LEVEL", "INFO").upper()
LOG_LEVEL = getattr(logging, LOG_LEVEL_STR, logging.INFO)
LOG_FILE_PATH = BASE_DIR / os.getenv("LOG_FILE", "logs/pipeline.log")
LOG_FILE_PATH.parent.mkdir(parents=True, exist_ok=True)

# Expected Source CSV Headers
EXPECTED_COLUMNS = [
    "Row ID",
    "Order ID",
    "Order Date",
    "Ship Date",
    "Ship Mode",
    "Customer ID",
    "Customer Name",
    "Segment",
    "Country",
    "City",
    "State",
    "Postal Code",
    "Region",
    "Product ID",
    "Category",
    "Sub-Category",
    "Product Name",
    "Sales",
    "Quantity",
    "Discount",
    "Profit",
]


def setup_logger(name: str = "ETLPipeline") -> logging.Logger:
    """Configures and returns a thread-safe logger writing to file and stdout."""
    logger = logging.getLogger(name)
    if not logger.handlers:
        logger.setLevel(LOG_LEVEL)

        formatter = logging.Formatter(
            fmt="%(asctime)s [%(levelname)s] [%(name)s]: %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )

        # File Handler
        fh = logging.FileHandler(LOG_FILE_PATH, encoding="utf-8")
        fh.setLevel(LOG_LEVEL)
        fh.setFormatter(formatter)
        logger.addHandler(fh)

        # Console Handler
        ch = logging.StreamHandler(sys.stdout)
        ch.setLevel(LOG_LEVEL)
        ch.setFormatter(formatter)
        logger.addHandler(ch)

    return logger


def get_connection_string() -> str:
    """Builds a pyodbc connection string with encryption & driver safety."""
    parts = [
        f"DRIVER={{{DB_DRIVER}}}",
        f"SERVER={DB_SERVER}",
        f"DATABASE={DB_NAME}",
    ]

    if DB_TRUSTED_CONNECTION:
        parts.append("Trusted_Connection=yes")
    elif DB_USER and DB_PASSWORD:
        parts.append(f"UID={DB_USER}")
        parts.append(f"PWD={DB_PASSWORD}")
    else:
        parts.append("Trusted_Connection=yes")

    if DB_TRUST_SERVER_CERTIFICATE:
        parts.append("TrustServerCertificate=yes")

    return ";".join(parts) + ";"


def get_db_connection(autocommit: bool = False) -> pyodbc.Connection:
    """Establishes and returns a live pyodbc connection to SQL Server."""
    conn_str = get_connection_string()
    try:
        conn = pyodbc.connect(conn_str, autocommit=autocommit, timeout=10)
        return conn
    except pyodbc.Error as e:
        logger = logging.getLogger("ETLPipeline.Config")
        logger.error(f"Failed to connect to SQL Server using string: {conn_str}. Error: {e}")
        raise
