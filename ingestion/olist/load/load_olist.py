import subprocess
from pathlib import Path

import pandas as pd

SOURCE_DIR = Path("ingestion/olist/source")
BATCH_SIZE = 1000


TABLES = {
    "customers": {
        "file": "olist_customers_dataset.csv",
        "columns": [
            ("customer_id", "customer_id", "string"),
            ("customer_unique_id", "customer_unique_id", "string"),
            ("customer_zip_code_prefix", "customer_zip_code_prefix", "integer"),
            ("customer_city", "customer_city", "string"),
            ("customer_state", "customer_state", "string"),
        ],
    },
    "orders": {
        "file": "olist_orders_dataset.csv",
        "columns": [
            ("order_id", "order_id", "string"),
            ("customer_id", "customer_id", "string"),
            ("order_status", "order_status", "string"),
            ("order_purchase_timestamp", "order_purchase_timestamp", "timestamp"),
            ("order_approved_at", "order_approved_at", "timestamp"),
            (
                "order_delivered_carrier_date",
                "order_delivered_carrier_date",
                "timestamp",
            ),
            (
                "order_delivered_customer_date",
                "order_delivered_customer_date",
                "timestamp",
            ),
            (
                "order_estimated_delivery_date",
                "order_estimated_delivery_date",
                "timestamp",
            ),
        ],
    },
    "order_items": {
        "file": "olist_order_items_dataset.csv",
        "columns": [
            ("order_id", "order_id", "string"),
            ("order_item_id", "order_item_id", "integer"),
            ("product_id", "product_id", "string"),
            ("seller_id", "seller_id", "string"),
            ("shipping_limit_date", "shipping_limit_date", "timestamp"),
            ("price", "price", "decimal"),
            ("freight_value", "freight_value", "decimal"),
        ],
    },
    "order_payments": {
        "file": "olist_order_payments_dataset.csv",
        "columns": [
            ("order_id", "order_id", "string"),
            ("payment_sequential", "payment_sequential", "integer"),
            ("payment_type", "payment_type", "string"),
            ("payment_installments", "payment_installments", "integer"),
            ("payment_value", "payment_value", "decimal"),
        ],
    },
    "order_reviews": {
        "file": "olist_order_reviews_dataset.csv",
        "columns": [
            ("review_id", "review_id", "string"),
            ("order_id", "order_id", "string"),
            ("review_score", "review_score", "integer"),
            ("review_comment_title", "review_comment_title", "string"),
            ("review_comment_message", "review_comment_message", "string"),
            ("review_creation_date", "review_creation_date", "timestamp"),
            ("review_answer_timestamp", "review_answer_timestamp", "timestamp"),
        ],
    },
    "products": {
        "file": "olist_products_dataset.csv",
        "columns": [
            ("product_id", "product_id", "string"),
            ("product_category_name", "product_category_name", "string"),
            ("product_name_lenght", "product_name_length", "integer"),
            (
                "product_description_lenght",
                "product_description_length",
                "integer",
            ),
            ("product_photos_qty", "product_photos_qty", "integer"),
            ("product_weight_g", "product_weight_g", "integer"),
            ("product_length_cm", "product_length_cm", "integer"),
            ("product_height_cm", "product_height_cm", "integer"),
            ("product_width_cm", "product_width_cm", "integer"),
        ],
    },
    "sellers": {
        "file": "olist_sellers_dataset.csv",
        "columns": [
            ("seller_id", "seller_id", "string"),
            ("seller_zip_code_prefix", "seller_zip_code_prefix", "integer"),
            ("seller_city", "seller_city", "string"),
            ("seller_state", "seller_state", "string"),
        ],
    },
    "product_category_translation": {
        "file": "product_category_name_translation.csv",
        "columns": [
            (
                "product_category_name",
                "product_category_name",
                "string",
            ),
            (
                "product_category_name_english",
                "product_category_name_english",
                "string",
            ),
        ],
    },
    "geolocation": {
        "file": "olist_geolocation_dataset.csv",
        "columns": [
            (
                "geolocation_zip_code_prefix",
                "geolocation_zip_code_prefix",
                "integer",
            ),
            ("geolocation_lat", "geolocation_lat", "double"),
            ("geolocation_lng", "geolocation_lng", "double"),
            ("geolocation_city", "geolocation_city", "string"),
            ("geolocation_state", "geolocation_state", "string"),
        ],
    },
}


def sql_literal(value, value_type):
    if pd.isna(value):
        return "NULL"

    if value_type == "string":
        escaped = str(value).replace("'", "''")
        return f"'{escaped}'"

    if value_type == "integer":
        return str(int(value))

    if value_type in {"double", "decimal"}:
        return str(value)

    if value_type == "timestamp":
        escaped = str(value).replace("'", "''")
        return f"TIMESTAMP '{escaped}'"

    raise ValueError(f"Unsupported type: {value_type}")


def execute_sql(sql):
    result = subprocess.run(
        [
            "docker",
            "compose",
            "exec",
            "-T",
            "trino",
            "trino",
        ],
        input=sql,
        text=True,
        check=False,
    )

    if result.returncode != 0:
        raise RuntimeError("Trino command failed")


def load_table(table_name, config):
    path = SOURCE_DIR / config["file"]

    print(f"\nChecking {table_name}")
    print(f"Source: {path}")

    df = pd.read_csv(path, dtype=str)
    source_rows = len(df)
    target_rows = get_table_count(table_name)

    if target_rows == source_rows:
        print(f"Skipping {table_name}: already complete with {target_rows:,} rows")
        return

    if target_rows != 0:
        raise RuntimeError(
            f"Cannot safely resume {table_name}: "
            f"source has {source_rows:,} rows but "
            f"target contains {target_rows:,} rows"
        )

    print(f"Loading {table_name}: {source_rows:,} rows")

    source_columns = [source for source, _, _ in config["columns"]]

    destination_columns = [destination for _, destination, _ in config["columns"]]

    df = df[source_columns]

    total_rows = len(df)

    for start in range(0, total_rows, BATCH_SIZE):
        batch = df.iloc[start : start + BATCH_SIZE]

        rows = []

        for row in batch.itertuples(index=False, name=None):
            literals = []

            for value, (_, _, value_type) in zip(
                row,
                config["columns"],
                strict=True,
            ):
                literals.append(sql_literal(value, value_type))

            rows.append("(" + ", ".join(literals) + ")")

        column_sql = ", ".join(destination_columns)

        sql = f"""
        INSERT INTO iceberg.olist.{table_name}
            ({column_sql})
        VALUES
            {",\n".join(rows)}
        """

        execute_sql(sql)

        loaded = min(start + BATCH_SIZE, total_rows)

        print(
            f"  {loaded:,}/{total_rows:,}",
            end="\r",
            flush=True,
        )

    print(f"  {total_rows:,}/{total_rows:,} loaded")


def get_table_count(table_name):
    result = subprocess.run(
        [
            "docker",
            "compose",
            "exec",
            "-T",
            "trino",
            "trino",
            "--output-format",
            "TSV",
            "--execute",
            f"SELECT COUNT(*) FROM iceberg.olist.{table_name}",
        ],
        capture_output=True,
        text=True,
        check=True,
    )

    return int(result.stdout.strip().strip('"'))


def main():
    tables_to_load = [
        "customers",
        "orders",
        "order_items",
        "order_payments",
        "order_reviews",
        "products",
        "sellers",
        "product_category_translation",
        "geolocation",
    ]

    for table_name in tables_to_load:
        load_table(table_name, TABLES[table_name])


if __name__ == "__main__":
    main()
