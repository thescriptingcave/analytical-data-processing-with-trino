# Analytical Data Platform with SQL

A local analytical data platform for learning and experimenting with:

- Trino
- Apache Iceberg
- PostgreSQL JDBC catalog
- MinIO object storage
- Parquet
- SQL analytics
- Iceberg metadata and partitioning

The project is designed to run entirely in Docker and provide a reproducible environment for exploring a modern lakehouse-style architecture on a local machine.

---

## Architecture

```text
                    ┌──────────────┐
                    │    Trino     │
                    │ Query Engine │
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐
                    │   Iceberg    │
                    │ Table Format │
                    └──────┬───────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
       ┌─────────────┐           ┌─────────────┐
       │ PostgreSQL  │           │    MinIO    │
       │ JDBC Catalog│           │S3-compatible│
       │  metadata   │           │   storage   │
       └─────────────┘           └──────┬──────┘
                                       │
                              ┌────────┴────────┐
                              │                 │
                           Parquet          Iceberg
                            data            metadata
```

### Component responsibilities

**Trino**

The SQL query engine. Trino is the primary interface for creating, querying, and modifying Iceberg tables.

**Apache Iceberg**

The table format. Iceberg manages table schemas, snapshots, partition specifications, manifests, and data-file references.

**PostgreSQL**

PostgreSQL is used only as the backend for the Iceberg JDBC catalog.

It does **not** store the analytical dataset.

**MinIO**

MinIO provides S3-compatible object storage. Iceberg stores both Parquet data files and Iceberg metadata files in the MinIO `warehouse` bucket.

**Parquet**

Parquet is the physical columnar file format used for analytical table data.

In short:

```text
MinIO    = object storage
Parquet  = data file format
Iceberg  = table format
Postgres = catalog metadata backend
Trino    = SQL query engine
```

---

# Prerequisites

Install:

- Docker Desktop
- Docker Compose
- Git
- Make

The project has been tested with Docker Desktop on macOS.

Verify the required tools:

```bash
docker --version
docker compose version
git --version
make --version
```

---

# Quick Start

Clone the repository:

```bash
git clone <repository-url>
cd analytical_dp_with_sql
```

Start and initialize the entire platform:

```bash
make setup
```

`make setup` performs the complete initialization workflow:

```text
Start Docker services
        ↓
Wait for Trino
        ↓
Initialize Iceberg schema and tables
        ↓
Load synthetic analytical data
        ↓
Verify expected row counts
```

A successful installation ends with:

```text
PASS: customers = 5000
PASS: products = 500
PASS: orders = 100000
PASS: order_items = 300000
PASS: events = 500000
PASS: total rows = 905500
STACK VERIFICATION PASSED
```

---

# Dataset

The project creates five Iceberg tables.

| Table | Rows | Partitioning |
|---|---:|---|
| `customers` | 5,000 | None |
| `products` | 500 | None |
| `orders` | 100,000 | Month of `order_ts` |
| `order_items` | 300,000 | None |
| `events` | 500,000 | Month of `event_ts` |
| **Total** | **905,500** | |

The data is synthetic and intended for SQL, Iceberg, partitioning, metadata, and analytical-engineering exercises.

---

# Iceberg Table Design

## Customers

```text
customer_id
name
email
signup_ts
region
```

This is a small dimension-style table and does not require partitioning.

## Products

```text
product_id
name
category
unit_price
```

This is also small enough that partitioning would add unnecessary complexity.

## Orders

```text
order_id
customer_id
order_ts
amount
status
region
category
```

Orders are partitioned by:

```sql
month(order_ts)
```

This allows Trino and Iceberg to eliminate irrelevant partitions when queries restrict `order_ts`.

Example:

```sql
SELECT
    region,
    COUNT(*) AS order_count,
    ROUND(SUM(amount), 2) AS total_revenue
FROM orders
WHERE order_ts >= TIMESTAMP '2025-06-01 00:00:00'
  AND order_ts <  TIMESTAMP '2025-07-01 00:00:00'
GROUP BY region
ORDER BY total_revenue DESC;
```

## Order Items

```text
item_id
order_id
product_id
quantity
line_total
```

This table is intentionally unpartitioned for the current project scale.

## Events

```text
event_id
event_ts
customer_id
event_type
page
device
```

Events are partitioned by:

```sql
month(event_ts)
```

Monthly partitioning provides useful pruning while avoiding excessive partition cardinality.

---

# Using Trino

Open the Trino CLI:

```bash
make trino
```

The CLI opens with:

```text
catalog: iceberg
schema: analytics
```

Example:

```sql
SELECT COUNT(*)
FROM orders;
```

Expected result:

```text
100000
```

List tables:

```sql
SHOW TABLES;
```

Expected:

```text
customers
events
order_items
orders
products
```

---

# Example Queries

## Revenue by region

```sql
SELECT
    region,
    COUNT(*) AS orders,
    ROUND(SUM(amount), 2) AS revenue
FROM orders
GROUP BY region
ORDER BY revenue DESC;
```

## Orders by month

```sql
SELECT
    date_trunc('month', order_ts) AS month,
    COUNT(*) AS order_count,
    ROUND(SUM(amount), 2) AS revenue
FROM orders
GROUP BY 1
ORDER BY 1;
```

## Top product categories

```sql
SELECT
    category,
    COUNT(*) AS order_count,
    ROUND(SUM(amount), 2) AS revenue
FROM orders
GROUP BY category
ORDER BY revenue DESC;
```

## Event activity

```sql
SELECT
    event_type,
    COUNT(*) AS event_count
FROM events
GROUP BY event_type
ORDER BY event_count DESC;
```

---

# Partition Pruning

One of the primary Iceberg concepts demonstrated by this project is partition pruning.

```sql
EXPLAIN ANALYZE
SELECT
    COUNT(*)
FROM orders
WHERE order_ts >= TIMESTAMP '2025-06-01 00:00:00'
  AND order_ts <  TIMESTAMP '2025-07-01 00:00:00';
```

Inspect the execution plan for:

- Input rows
- Physical input
- Splits
- Predicate constraints

Compare that result to the same aggregation without the `WHERE` clause.

---

# Iceberg Metadata

Iceberg exposes metadata tables through Trino.

```sql
SELECT * FROM "orders$snapshots";
SELECT * FROM "orders$history";
SELECT * FROM "orders$files";
SELECT * FROM "orders$partitions";
```

These expose snapshots, files, partition statistics, manifests, and table history.

---

# MinIO

MinIO API:

```text
http://localhost:9000
```

MinIO Console:

```text
http://localhost:9001
```

Default local-development credentials:

```text
username: minio
password: minio123
```

Primary bucket:

```text
warehouse
```

Iceberg stores table data and metadata under table-specific paths:

```text
analytics/
  orders-<uuid>/
    data/
      order_ts_month=2025-06/
        <file>.parquet
    metadata/
      <version>.metadata.json
      <manifest>.avro
      <snapshot>.avro
```

---

# PostgreSQL JDBC Catalog

PostgreSQL stores Iceberg catalog information in:

```text
iceberg_catalog
```

Relevant catalog tables include:

```text
iceberg_tables
iceberg_namespace_properties
```

PostgreSQL does **not** contain the 905,500 analytical rows. Those rows reside in Parquet files in MinIO.

---

# Built-in Trino Datasets

The repository also enables:

```text
tpch
tpcds
```

Example:

```sql
SELECT *
FROM tpch.tiny.customer
LIMIT 10;
```

These datasets are generated by Trino and are independent of the Iceberg/MinIO dataset.

---

# Project Commands

```bash
make setup   # Full setup, load, and verification
make up      # Start services
make wait    # Wait for Trino
make init    # Create Iceberg schema and tables
make load    # Load synthetic data
make verify  # Assert expected row counts
make trino   # Open Trino CLI
make ps      # Show service status
make logs    # Follow Trino logs
make down    # Stop services, preserving volumes
make purge   # Remove services and project volumes
```

**Warning:** `make purge` removes this project's PostgreSQL and MinIO persistent volumes.

---

# Persistence

A normal:

```bash
make down
make up
make wait
make verify
```

preserves the Iceberg catalog and warehouse data.

For a clean-room rebuild:

```bash
make purge
make setup
```

No manual database initialization should be required.

---

# Configuration

The project includes `.env.example`:

```env
POSTGRES_DB=iceberg
POSTGRES_USER=iceberg
POSTGRES_PASSWORD=iceberg

MINIO_ROOT_USER=minio
MINIO_ROOT_PASSWORD=minio123
```

These credentials are intended only for local development and learning.

To customize:

```bash
cp .env.example .env
```

Then edit `.env`.

---

# Project Structure

```text
.
├── .env.example
├── .github/
├── .gitignore
├── .vscode/
├── Makefile
├── README.md
├── data/
│   └── data.sql
├── ddl/
│   ├── reset.sql
│   ├── schema.sql
│   └── verify.sql
├── docker-compose.yml
├── etc/
│   ├── catalog/
│   │   ├── iceberg.properties
│   │   ├── tpcds.properties
│   │   └── tpch.properties
│   ├── config.properties
│   ├── jvm.config
│   ├── log.properties
│   └── node.properties
├── images/
│   ├── dbeaver.png
│   └── tpch_erd.png
├── init/
│   └── iceberg-catalog.sql
└── scripts/
    └── verify.sh
```

---

# Docker Services

The Compose stack contains four services:

- **PostgreSQL** — stores the Iceberg JDBC catalog
- **MinIO** — stores Parquet data and Iceberg metadata
- **createbuckets** — one-shot MinIO client that creates the `warehouse` bucket
- **Trino** — provides the SQL engine and Iceberg connector

---

# Verification

`scripts/verify.sh` asserts:

```text
customers    5000
products      500
orders     100000
order_items 300000
events      500000
```

Total:

```text
905500
```

A mismatch causes verification to fail with a non-zero exit status.

---

# Troubleshooting

Check container state:

```bash
docker compose ps -a
```

Typical healthy state:

```text
postgres       healthy
minio          healthy
createbuckets  exited (0)
trino          running
```

Test Trino:

```bash
docker compose exec -T trino trino --execute "SELECT 1"
```

Test the Iceberg catalog:

```bash
docker compose exec -T trino   trino --catalog iceberg   --execute "SHOW SCHEMAS"
```

Expected:

```text
analytics
information_schema
system
```

View Trino logs:

```bash
docker compose logs trino
```

Avoid broad cleanup commands such as:

```bash
docker volume prune
```

unless you explicitly intend to affect unrelated Docker projects.

---

# Versioning

The stack pins its primary runtime components:

```text
Trino: 483
PostgreSQL: 16
MinIO: pinned release image
MinIO Client: pinned release image
```

Trino 483 uses Apache Iceberg 1.11.0 internally.

---

# What This Project Is For

This repository is a practical learning environment for:

- Trino SQL
- Apache Iceberg
- lakehouse architecture
- object storage
- Parquet
- partition pruning
- Iceberg metadata
- snapshots
- analytical SQL
- query execution analysis
- reproducible Docker-based data platforms

---

# What This Project Is Not

This is not intended to be a production deployment.

The local configuration favors simplicity and visibility over production concerns such as authentication, TLS, secret management, distributed Trino clusters, high availability, enterprise authorization, and production observability.

---

# Learning Path

```text
1. Query Iceberg tables with Trino
2. Understand Parquet vs Iceberg
3. Inspect Iceberg metadata
4. Study snapshots and table history
5. Explore partition pruning
6. Compare partitioned and unpartitioned scans
7. Study query plans with EXPLAIN ANALYZE
8. Explore TPCH/TPCDS
9. Experiment with table evolution
10. Study Iceberg maintenance operations
```

---

# License

Add the appropriate project license before public distribution.
