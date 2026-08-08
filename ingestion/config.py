"""
All connection details come from environment variables (.env, gitignored).
Never hardcode credentials here.
"""
import os
from dotenv import load_dotenv

load_dotenv()

# --- AWS S3 ---
AWS_REGION = os.environ["AWS_REGION"]
S3_BUCKET = os.environ["S3_BUCKET"]
S3_LANDING_PREFIX = os.environ.get("S3_LANDING_PREFIX", "landing/v1/")

# --- Snowflake ---
SNOWFLAKE_ACCOUNT = os.environ["SNOWFLAKE_ACCOUNT"]
SNOWFLAKE_USER = os.environ["SNOWFLAKE_USER"]
SNOWFLAKE_PASSWORD = os.environ["SNOWFLAKE_PASSWORD"]
SNOWFLAKE_WAREHOUSE = os.environ["SNOWFLAKE_WAREHOUSE"]
SNOWFLAKE_DATABASE = os.environ["SNOWFLAKE_DATABASE"]
SNOWFLAKE_SCHEMA = os.environ.get("SNOWFLAKE_RAW_SCHEMA", "RAW")

# --- Local paths ---
LOCAL_DATA_DIR = os.environ.get("LOCAL_DATA_DIR", "../data/raw")

# --- Source file registry (V1 scope: 4 files -> 4 raw tables) ---
# Mapping files (carrier_mapping.csv, warehouse_mapping.csv) are NOT here —
# they load as dbt seeds in Day 3, not through this ingestion pipeline.
# exception_notes_log.csv is out of scope entirely for V1.
SOURCE_FILES = {
    "sap_sales_orders": {
        "filename": "sap_sales_orders.csv",
        "type": "csv",
        "header_rows": 2,  # technical code row + description row
        "required_columns": [
            "VBELN", "ERDAT", "KUNNR", "MATNR", "KWMENG", "WERKS", "VDATU",
            "EDATU", "VSBED", "LPRIO", "AUFT_STATUS",
        ],
        "raw_table": "SAP_SALES_ORDERS",
    },
    "sap_ewm_warehouse_events": {
        "filename": "sap_ewm_warehouse_events.csv",
        "type": "csv",
        "header_rows": 1,
        "required_columns": ["TANUM", "VBELN", "LGNUM", "VORGA", "CONFIRM_TS", "MENGE_CONF"],
        "raw_table": "SAP_EWM_WAREHOUSE_EVENTS",
    },
    "transportation_tracking": {
        "filename": "transportation_tracking.xlsx",
        "type": "xlsx",
        "sheet_name": "Shipments",
        "required_sheets": ["Shipments", "Notes"],
        "required_columns": [
            "Shipment Ref", "Carrier", "Ship Date", "Planned Delivery Date",
            "Actual Delivery Date", "Freight Cost (JPY)", "Status",
        ],
        "raw_table": "TRANSPORTATION_TRACKING",
    },
    "carrier_invoices": {
        "filename": "carrier_invoices.csv",
        "type": "csv",
        "header_rows": 1,
        "required_columns": [
            "BELNR", "LIFNR", "VBELN_REF", "BUDAT", "RECHNUNGSDATUM", "WRBTR", "WAERS",
        ],
        "raw_table": "CARRIER_INVOICES",
    },
}
