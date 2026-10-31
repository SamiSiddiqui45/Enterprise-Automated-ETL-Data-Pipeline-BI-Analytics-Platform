# Troubleshooting & Diagnostic Guide

## 1. Common Issues and Resolutions

### 1.1 SQL Server Connection Refused or Instance Not Reachable
**Symptom:**
`pyodbc.OperationalError: ('08001', '[08001] [Microsoft][ODBC Driver 18 for SQL Server]Named Pipes Provider: Could not open a connection to SQL Server [2].')`

**Resolution:**
1. Verify that the SQL Server Express service is running:
   ```powershell
   Get-Service *sql* | Where-Object { $_.Name -like '*SQLEXPRESS*' }
   ```
2. If the service status is `Stopped`, start it in an Administrator PowerShell:
   ```powershell
   Start-Service MSSQL$SQLEXPRESS
   ```
3. Verify your `.env` configuration:
   ```ini
   DB_SERVER=.\SQLEXPRESS
   DB_NAME=AnalyticsDW
   DB_DRIVER=ODBC Driver 18 for SQL Server
   DB_TRUSTED_CONNECTION=yes
   DB_TRUST_SERVER_CERTIFICATE=yes
   ```

---

### 1.2 SSL Certificate Validation Error (ODBC Driver 18)
**Symptom:**
`SSL Provider: The certificate chain was issued by an authority that is not trusted.`

**Resolution:**
In ODBC Driver 18 for SQL Server, encryption is enabled by default. For local SQL Server instances using self-signed development certificates, you must specify `TrustServerCertificate=yes`.  
Verify that `.env` includes:
```ini
DB_TRUST_SERVER_CERTIFICATE=yes
```

---

### 1.3 CSV Encoding Decoding Errors
**Symptom:**
`UnicodeDecodeError: 'utf-8' codec can't decode byte 0xa0 in position 2944: invalid start byte`

**Resolution:**
The source file `archive (1)/Sample - Superstore.csv` contains Windows-1252 non-breaking spaces (byte `0xA0`).  
Always ensure the file is loaded with `encoding="cp1252"` or `encoding="windows-1252"`. Our `src/extract.py` automatically uses `CSV_ENCODING=cp1252`.

---

### 1.4 Missing PyODBC Package
**Symptom:**
`ModuleNotFoundError: No module named 'pyodbc'`

**Resolution:**
Install `pyodbc` into your active Python environment:
```powershell
pip install pyodbc
```

---

### 1.5 Checking Loaded Records & Resetting Test Warehouse
To inspect row counts directly in PowerShell:
```powershell
sqlcmd -S .\SQLEXPRESS -E -d AnalyticsDW -Q "SELECT 'FactSales' AS Tbl, COUNT(*) AS Cnt FROM dw.FactSales;"
```

To re-run the pipeline cleanly:
```powershell
python -m src.main
```
The pipeline uses idempotent insertions (`WHERE NOT EXISTS`), so re-running the command is safe and will not produce duplicate fact records.
