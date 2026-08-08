"""
Structural validation — FR-V1-006.

Confirms required files, sheets, and columns exist BEFORE anything is loaded
into Snowflake. This does not check data quality (that's dbt's job in Day 3+),
only that the file is structurally what we expect.
"""
import os
import pandas as pd


class ValidationError(Exception):
    pass


def validate_file_exists(filepath: str):
    if not os.path.isfile(filepath):
        raise ValidationError(f"Required source file not found: {filepath}")


def validate_csv_structure(filepath: str, required_columns: list, header_rows: int = 1):
    """
    header_rows=2 handles sap_sales_orders.csv's technical-code-row +
    description-row layout — we read using the first row as the header,
    since that's the row dbt/Snowflake will actually key off, and just
    confirm the second row (descriptions) is present as expected.
    """
    df = pd.read_csv(filepath, dtype=str, nrows=5)
    missing = [c for c in required_columns if c not in df.columns]
    if missing:
        raise ValidationError(f"{filepath}: missing required columns {missing}")

    if header_rows == 2:
        with open(filepath, encoding="utf-8") as f:
            f.readline()
            second_line = f.readline()
        if not second_line.strip():
            raise ValidationError(f"{filepath}: expected a description row (row 2) but found none")


def validate_xlsx_structure(filepath: str, required_sheets: list, sheet_name: str, required_columns: list):
    xl = pd.ExcelFile(filepath)
    missing_sheets = [s for s in required_sheets if s not in xl.sheet_names]
    if missing_sheets:
        raise ValidationError(f"{filepath}: missing required sheet(s) {missing_sheets}")

    df = xl.parse(sheet_name, nrows=5)
    missing_cols = [c for c in required_columns if c not in df.columns]
    if missing_cols:
        raise ValidationError(f"{filepath} [{sheet_name}]: missing required columns {missing_cols}")


def validate_source(local_path: str, spec: dict):
    """Dispatches to the right validator based on file type. Raises ValidationError on failure."""
    validate_file_exists(local_path)
    if spec["type"] == "csv":
        validate_csv_structure(local_path, spec["required_columns"], spec.get("header_rows", 1))
    elif spec["type"] == "xlsx":
        validate_xlsx_structure(
            local_path, spec["required_sheets"], spec["sheet_name"], spec["required_columns"]
        )
    else:
        raise ValidationError(f"Unknown file type in spec: {spec['type']}")
