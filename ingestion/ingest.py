"""
Day 2 — Extract and Load.

Reads the 4 V1 transactional source files, validates their structure,
uploads the original files to S3 (landing zone, untouched), and loads them
into Snowflake RAW tables with source values preserved as-is (FR-V1-007).

No ingestion metadata (source filename, ingestion timestamp, pipeline run ID)
is added here — that's deferred to V4 per project decision.

Run: python ingest.py
"""
import os
import sys
import boto3
import pandas as pd
from snowflake.connector import connect
from snowflake.connector.pandas_tools import write_pandas

import config
from validators import validate_source, ValidationError


def upload_to_s3(local_path: str, filename: str):
    s3 = boto3.client("s3", region_name=config.AWS_REGION)
    key = f"{config.S3_LANDING_PREFIX}{filename}"
    s3.upload_file(local_path, config.S3_BUCKET, key)
    print(f"  uploaded to s3://{config.S3_BUCKET}/{key}")


def load_dataframe(local_path: str, spec: dict) -> pd.DataFrame:
    if spec["type"] == "csv":
        skiprows = [1] if spec.get("header_rows", 1) == 2 else None
        df = pd.read_csv(local_path, dtype=str, skiprows=skiprows)
    elif spec["type"] == "xlsx":
        df = pd.read_excel(local_path, sheet_name=spec["sheet_name"], dtype=str)
    else:
        raise ValueError(f"Unknown file type: {spec['type']}")
    # normalize column names for Snowflake (unquoted identifiers are uppercased anyway)
    df.columns = [c.strip().upper().replace(" ", "_").replace("(", "").replace(")", "") for c in df.columns]
    return df


def load_to_snowflake(conn, df: pd.DataFrame, table_name: str):
    cur = conn.cursor()
    cur.execute(f"USE DATABASE {config.SNOWFLAKE_DATABASE}")
    cur.execute(f"USE SCHEMA {config.SNOWFLAKE_SCHEMA}")
    # simple overwrite each run — raw layer isn't incremental in V1 (that's V4 scope)
    success, nchunks, nrows, _ = write_pandas(
        conn, df, table_name=table_name, auto_create_table=True, overwrite=True
    )
    print(f"  loaded {nrows} rows into {config.SNOWFLAKE_SCHEMA}.{table_name} (success={success})")


def main():
    failures = []

    print("Step 1: structural validation")
    for key, spec in config.SOURCE_FILES.items():
        local_path = os.path.join(config.LOCAL_DATA_DIR, spec["filename"])
        try:
            validate_source(local_path, spec)
            print(f"  OK: {spec['filename']}")
        except ValidationError as e:
            print(f"  FAILED: {e}")
            failures.append(spec["filename"])

    if failures:
        print(f"\nAborting: {len(failures)} file(s) failed validation: {failures}")
        sys.exit(1)

    print("\nStep 2: upload to S3")
    for key, spec in config.SOURCE_FILES.items():
        local_path = os.path.join(config.LOCAL_DATA_DIR, spec["filename"])
        upload_to_s3(local_path, spec["filename"])

    print("\nStep 3: load into Snowflake RAW")
    conn = connect(
        account=config.SNOWFLAKE_ACCOUNT,
        user=config.SNOWFLAKE_USER,
        password=config.SNOWFLAKE_PASSWORD,
        warehouse=config.SNOWFLAKE_WAREHOUSE,
        database=config.SNOWFLAKE_DATABASE,
        schema=config.SNOWFLAKE_SCHEMA,
    )
    try:
        for key, spec in config.SOURCE_FILES.items():
            local_path = os.path.join(config.LOCAL_DATA_DIR, spec["filename"])
            print(f"  processing {spec['filename']} -> {spec['raw_table']}")
            df = load_dataframe(local_path, spec)
            load_to_snowflake(conn, df, spec["raw_table"])
    finally:
        conn.close()

    print("\nDone. All 4 files validated, landed in S3, and loaded to Snowflake RAW.")


if __name__ == "__main__":
    main()
