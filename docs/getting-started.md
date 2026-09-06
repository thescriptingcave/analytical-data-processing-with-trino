# Getting Started

This guide describes how to bring the Analytical Data Platform up from a
fresh clone and, optionally, load the Olist Brazilian E-Commerce dataset
used for the SQL learning exercises.

## 1. Architecture

``` text
Trino
  |
  | Iceberg connector
  v
Apache Iceberg
  |                |
  | JDBC           | S3-compatible storage
  v                v
PostgreSQL        MinIO
catalog           Iceberg metadata + Parquet data
```

The repository supports two datasets:

-   `iceberg.analytics` --- synthetic learning data created by the
    repository setup workflow.
-   `iceberg.olist` --- Olist e-commerce data loaded from source CSV
    files supplied separately by the user.

> The Olist source CSV files are not stored in this repository. A fresh
> clone must obtain them separately before running the Olist ingestion
> workflow.

## 2. Prerequisites

Install Git, Docker with Docker Compose, and `uv`.

``` bash
git --version
docker --version
docker compose version
uv --version
make --version
```

Docker must be running before starting the platform.

## 3. Clone and Prepare the Repository

``` bash
git clone <repository-url>
cd analytical_dp_with_sql
uv sync
```

Replace `<repository-url>` with the GitHub URL for this repository. The
project includes `pyproject.toml` and `uv.lock`; `uv sync` creates or
synchronizes the Python environment.

## 4. Start the Platform

``` bash
make up
make wait
make ps
```

The expected platform services are Trino, PostgreSQL, and MinIO.

## 5. Initialize the Synthetic Learning Dataset

The existing repository workflow creates and loads `iceberg.analytics`.

``` bash
make init
make load
make verify
```

Or run the combined workflow:

``` bash
make setup
```

`make setup` starts the services, waits for Trino, initializes the
synthetic dataset, loads it, and verifies it.

Expected synthetic row counts:

  Table                  Rows
  ------------- -------------
  customers             5,000
  products                500
  orders              100,000
  order_items         300,000
  events              500,000
  **Total**       **905,500**

# Olist Dataset Setup

The remaining steps are required only when using the Olist dataset.

## 6. Obtain the Olist CSV Files

Obtain the Olist Brazilian E-Commerce source dataset separately and
place these files under `ingestion/olist/source/`:

``` text
product_category_name_translation.csv
olist_sellers_dataset.csv
olist_products_dataset.csv
olist_orders_dataset.csv
olist_order_reviews_dataset.csv
olist_order_payments_dataset.csv
olist_order_items_dataset.csv
olist_geolocation_dataset.csv
olist_customers_dataset.csv
```

Do not add the raw source CSV files to Git.

## 7. Optional Source Profiling

The profiling scripts establish the source baseline before ingestion:

``` bash
uv run python ingestion/olist/profiling/profile_sources.py
uv run python ingestion/olist/profiling/profile_relationships.py
```

They are used to inspect row counts, logical keys, null behavior, and
source relationships.

## 8. Create the Olist Iceberg Schema and Tables

``` bash
docker compose exec -T trino trino   < ingestion/olist/ddl/01_create_schema.sql

docker compose exec -T trino trino   < ingestion/olist/ddl/02_create_tables.sql
```

The target namespace is `iceberg.olist`. The `orders` table uses Iceberg
month partitioning on `order_purchase_timestamp`.

## 9. Load Olist

Run the canonical loader:

``` bash
uv run python ingestion/olist/load/load_olist.py
```

The loader reads the CSV files with Python/pandas, generates typed SQL
inserts, and sends those statements to Trino. Trino's Iceberg connector
handles Iceberg commits, metadata, partitioning, and Parquet writes to
MinIO.

The Python loader does **not** write directly to MinIO.

Before loading a table, the loader checks whether the target already
contains rows. It refuses to load a non-empty target, protecting an
existing dataset from accidental duplicate ingestion.

## 10. Expected Olist Row Counts

  Table                                     Rows
  ------------------------------ ---------------
  customers                               99,441
  geolocation                          1,000,163
  order_items                            112,650
  order_payments                         103,886
  order_reviews                           99,224
  orders                                  99,441
  product_category_translation                71
  products                                32,951
  sellers                                  3,095
  **Total**                        **1,550,922**

These values are the project's known-good ingestion baseline.

## 11. Validate the Olist Load

Successful loader execution is not sufficient proof of correctness. The
validation sequence is:

``` text
source/target row counts
        ↓
logical and composite keys
        ↓
referential integrity
        ↓
relationship coverage
        ↓
known source exceptions
        ↓
persistence
        ↓
INGESTION ACCEPTED
```

The complete SQL, expected results, and acceptance criteria are
documented in:

``` text
docs/olist-ingestion/05-data-validation.md
```

Known validated source characteristics include:

-   775 orders without order-item records
-   1 order without a payment record
-   768 orders without a review
-   2 product categories without English translations

These are source-data characteristics, not ingestion failures.

## 12. Query Trino

Open the Trino CLI:

``` bash
make trino
```

For Olist, use fully qualified table names such as:

``` sql
SELECT COUNT(*)
FROM iceberg.olist.orders;
```

A useful first time-series query is:

``` sql
SELECT
    date_trunc('month', order_purchase_timestamp) AS month,
    COUNT(*) AS order_count
FROM iceberg.olist.orders
GROUP BY 1
ORDER BY 1;
```

## 13. Normal Shutdown and Restart

To stop the platform while preserving its named volumes:

``` bash
make down
```

Restart with:

``` bash
make up
make wait
```

The Olist dataset has been verified to remain queryable after normal
container recreation.

## 14. Destructive Reset Warning

The repository also contains:

``` bash
make purge
```

This uses Docker Compose volume removal and is **destructive**.

The recoverable analytical state depends on both the PostgreSQL JDBC
catalog and the MinIO Iceberg warehouse. Do not use `make purge` when
the current local dataset must be preserved.

Persistence is not the same as backup. A separate backup/bootstrap
workflow may be added later.

## 15. Known-Good State

After complete setup and Olist ingestion:

``` text
Platform
--------
Trino        running
PostgreSQL   running
MinIO        running

Iceberg namespaces
------------------
iceberg.analytics   synthetic learning dataset
iceberg.olist       Olist analytical dataset

Validated rows
--------------
analytics             905,500
olist               1,550,922
```

Once validation passes, the Olist ingestion layer is considered frozen.
Changes to its DDL or loader should be driven by a verified defect or a
concrete analytical requirement.

## 16. Learning Workflow

The primary objective after setup is analytical SQL rather than
infrastructure development:

``` text
business question
      ↓
time-series aggregation
      ↓
CTE
      ↓
window function
      ↓
interpretation
      ↓
Iceberg execution behavior
```

Topics include time-series SQL, CTEs, window functions, month-over-month
comparisons, cumulative metrics, moving averages, missing and partial
periods, Iceberg partition pruning, snapshots, metadata, and practical
Iceberg behavior in Trino.

Infrastructure should remain stable unless an analytical requirement
creates a concrete need for a change.
