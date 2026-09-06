# Olist Ingestion Validation

## 1. Purpose

This document records the validation process used to accept the Olist
Brazilian E-Commerce dataset after ingestion into Apache Iceberg through
Trino.

The purpose of validation is to establish that the loader did more than
complete successfully. A successful write proves that data was written;
it does not prove that the correct data was written.

The acceptance process therefore validates the dataset at several
levels:

1.  Source-to-target row-count reconciliation
2.  Logical-key uniqueness
3.  Composite-key uniqueness
4.  Referential integrity
5.  Parent-child relationship coverage
6.  Known source-data exceptions
7.  Persistence across normal container recreation

The validated target is the `iceberg.olist` schema.

------------------------------------------------------------------------

## 2. Platform Context

The ingestion path is:

``` text
Olist CSV files
      |
      v
Python loader
      |
      | SQL via Trino CLI
      v
Trino
      |
      | Iceberg connector
      v
Apache Iceberg
   /        \
  /          \
PostgreSQL   MinIO
catalog      object storage
             (Iceberg metadata + Parquet)
```

The Python loader does not write directly to MinIO. It submits SQL to
Trino. Trino's Iceberg connector manages the Iceberg transaction, table
metadata, partitioning, and data-file writes.

------------------------------------------------------------------------

## 3. Source Baseline

The source CSV files were profiled before ingestion. The following row
counts became the expected target baseline.

  Table                            Expected rows
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

The source profiling also established the expected logical keys,
relationships, coverage gaps, and known category-translation gaps used
below.

------------------------------------------------------------------------

## 4. Row-Count Reconciliation

After ingestion, every Iceberg table was counted and compared with its
source CSV.

### Verified result

All nine target tables exactly matched their source row counts.

**Total target rows: 1,550,922**

This establishes completeness at the row-count level, but row counts
alone are not sufficient to establish correctness.

------------------------------------------------------------------------

## 5. Logical-Key and Composite-Key Validation

Apache Iceberg is being used as an analytical table format. The project
does not rely on database-enforced primary-key constraints for these
tables. Logical uniqueness is therefore verified explicitly.

### Validation SQL

``` sql
SELECT
    'customers.customer_id' AS check_name,
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_count
FROM iceberg.olist.customers

UNION ALL

SELECT
    'orders.order_id',
    COUNT(*) - COUNT(DISTINCT order_id)
FROM iceberg.olist.orders

UNION ALL

SELECT
    'products.product_id',
    COUNT(*) - COUNT(DISTINCT product_id)
FROM iceberg.olist.products

UNION ALL

SELECT
    'sellers.seller_id',
    COUNT(*) - COUNT(DISTINCT seller_id)
FROM iceberg.olist.sellers

UNION ALL

SELECT
    'category_translation.product_category_name',
    COUNT(*) - COUNT(DISTINCT product_category_name)
FROM iceberg.olist.product_category_translation

UNION ALL

SELECT
    'order_items.(order_id,order_item_id)',
    COUNT(*) - COUNT(
        DISTINCT ROW(order_id, order_item_id)
    )
FROM iceberg.olist.order_items

UNION ALL

SELECT
    'payments.(order_id,payment_sequential)',
    COUNT(*) - COUNT(
        DISTINCT ROW(order_id, payment_sequential)
    )
FROM iceberg.olist.order_payments

UNION ALL

SELECT
    'reviews.(review_id,order_id)',
    COUNT(*) - COUNT(
        DISTINCT ROW(review_id, order_id)
    )
FROM iceberg.olist.order_reviews

ORDER BY check_name;
```

### Verified result

  Logical key                                    Duplicate count
  -------------------------------------------- -----------------
  category_translation.product_category_name                   0
  customers.customer_id                                        0
  order_items.(order_id, order_item_id)                        0
  orders.order_id                                              0
  payments.(order_id, payment_sequential)                      0
  products.product_id                                          0
  reviews.(review_id, order_id)                                0
  sellers.seller_id                                            0

**Result: PASS**

No duplicate logical or composite keys were introduced during ingestion.

------------------------------------------------------------------------

## 6. Referential-Integrity Validation

The next validation confirms that child records reference valid parent
records.

### Relationships tested

-   orders -\> customers
-   order_items -\> orders
-   order_items -\> products
-   order_items -\> sellers
-   order_payments -\> orders
-   order_reviews -\> orders

### Validation SQL

``` sql
SELECT
    'orders -> customers' AS relationship,
    COUNT(DISTINCT o.customer_id) AS child_keys,
    COUNT(DISTINCT c.customer_id) AS matched_keys,
    COUNT(DISTINCT CASE
        WHEN c.customer_id IS NULL THEN o.customer_id
    END) AS missing_parent_keys
FROM iceberg.olist.orders o
LEFT JOIN iceberg.olist.customers c
    ON o.customer_id = c.customer_id

UNION ALL

SELECT
    'order_items -> orders',
    COUNT(DISTINCT oi.order_id),
    COUNT(DISTINCT o.order_id),
    COUNT(DISTINCT CASE
        WHEN o.order_id IS NULL THEN oi.order_id
    END)
FROM iceberg.olist.order_items oi
LEFT JOIN iceberg.olist.orders o
    ON oi.order_id = o.order_id

UNION ALL

SELECT
    'order_items -> products',
    COUNT(DISTINCT oi.product_id),
    COUNT(DISTINCT p.product_id),
    COUNT(DISTINCT CASE
        WHEN p.product_id IS NULL THEN oi.product_id
    END)
FROM iceberg.olist.order_items oi
LEFT JOIN iceberg.olist.products p
    ON oi.product_id = p.product_id

UNION ALL

SELECT
    'order_items -> sellers',
    COUNT(DISTINCT oi.seller_id),
    COUNT(DISTINCT s.seller_id),
    COUNT(DISTINCT CASE
        WHEN s.seller_id IS NULL THEN oi.seller_id
    END)
FROM iceberg.olist.order_items oi
LEFT JOIN iceberg.olist.sellers s
    ON oi.seller_id = s.seller_id

UNION ALL

SELECT
    'payments -> orders',
    COUNT(DISTINCT p.order_id),
    COUNT(DISTINCT o.order_id),
    COUNT(DISTINCT CASE
        WHEN o.order_id IS NULL THEN p.order_id
    END)
FROM iceberg.olist.order_payments p
LEFT JOIN iceberg.olist.orders o
    ON p.order_id = o.order_id

UNION ALL

SELECT
    'reviews -> orders',
    COUNT(DISTINCT r.order_id),
    COUNT(DISTINCT o.order_id),
    COUNT(DISTINCT CASE
        WHEN o.order_id IS NULL THEN r.order_id
    END)
FROM iceberg.olist.order_reviews r
LEFT JOIN iceberg.olist.orders o
    ON r.order_id = o.order_id

ORDER BY relationship;
```

### Verified result

  Relationship                 Child keys   Matched keys   Missing parent keys
  -------------------------- ------------ -------------- ---------------------
  order_items -\> orders           98,666         98,666                     0
  order_items -\> products         32,951         32,951                     0
  order_items -\> sellers           3,095          3,095                     0
  orders -\> customers             99,441         99,441                     0
  payments -\> orders              99,440         99,440                     0
  reviews -\> orders               98,673         98,673                     0

**Result: PASS**

Every child key represented in these relationships resolves to a valid
parent.

### Referential integrity is not coverage

For example, `payments -> orders` has zero missing parents. That means
every payment belongs to a valid order.

It does **not** mean every order has a payment.

That distinction is tested separately.

------------------------------------------------------------------------

## 7. Parent-Child Coverage Validation

The source profiling identified legitimate cases where a parent order
has no corresponding child record.

### Validation SQL

``` sql
SELECT
    'orders_without_items' AS check_name,
    COUNT(*) AS missing_count
FROM iceberg.olist.orders o
LEFT JOIN iceberg.olist.order_items oi
    ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL

UNION ALL

SELECT
    'orders_without_payments',
    COUNT(*)
FROM iceberg.olist.orders o
LEFT JOIN iceberg.olist.order_payments p
    ON o.order_id = p.order_id
WHERE p.order_id IS NULL

UNION ALL

SELECT
    'orders_without_reviews',
    COUNT(*)
FROM iceberg.olist.orders o
LEFT JOIN iceberg.olist.order_reviews r
    ON o.order_id = r.order_id
WHERE r.order_id IS NULL

ORDER BY check_name;
```

### Verified result

  Coverage check              Count
  ------------------------- -------
  Orders without items          775
  Orders without payments         1
  Orders without reviews        768

These values exactly match the source profile.

**Result: PASS**

These are source-data characteristics, not ingestion defects. Preserving
them is evidence that the loader did not silently alter the dataset.

------------------------------------------------------------------------

## 8. Product-Category Translation Validation

Source profiling found two product categories that do not have entries
in the Portuguese-to-English translation file.

### Validation SQL

``` sql
SELECT DISTINCT
    p.product_category_name
FROM iceberg.olist.products p
LEFT JOIN iceberg.olist.product_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL
ORDER BY p.product_category_name;
```

### Verified result

``` text
pc_gamer
portateis_cozinha_e_preparadores_de_alimentos
```

Exactly two untranslated categories were found, matching the source
profile.

**Result: PASS**

Analytical queries that use the translation table should normally use a
`LEFT JOIN` if untranslated categories must remain in the result set.

------------------------------------------------------------------------

## 9. Persistence Validation

A normal Docker Compose shutdown destroys the running containers but
should not destroy the named PostgreSQL and MinIO volumes.

Persistence was tested rather than assumed.

### Test procedure

1.  Query known Olist table counts.
2.  Run a normal Docker Compose shutdown.
3.  Recreate the services.
4.  Wait for Trino to become ready.
5.  Query the Iceberg tables again.

Representative post-restart counts were:

  Table           Rows after restart
  ------------- --------------------
  customers                   99,441
  geolocation              1,000,163
  orders                      99,441

The Iceberg tables remained queryable after container recreation.

**Result: PASS**

This demonstrates persistence across a normal `docker compose down` /
`up` cycle.

### Important limitation

Persistence is not backup.

The platform's recoverable Iceberg state consists of both:

-   PostgreSQL JDBC catalog state
-   MinIO Iceberg warehouse objects

Also, the project's `make purge` command uses volume removal and must be
treated as a destructive reset.

------------------------------------------------------------------------

## 10. Validation Summary

  Validation layer                Result
  ------------------------------- --------
  Source-to-target row counts     PASS
  Logical-key uniqueness          PASS
  Composite-key uniqueness        PASS
  Referential integrity           PASS
  Parent-child coverage           PASS
  Known translation gaps          PASS
  Container restart persistence   PASS

### Acceptance decision

**OLIST INGESTION VALIDATED**

The `iceberg.olist` dataset is accepted as the project's known-good
analytical baseline.

The ingestion layer is now considered **frozen**. Changes to the loader,
DDL, or target model should only be made when a concrete analytical
requirement or verified defect justifies the change.

------------------------------------------------------------------------

## 11. Validation Model

The project used the following progression:

``` text
Loader completed
      |
      v
Correct number of rows?
      |
      v
Logical keys preserved?
      |
      v
Relationships preserved?
      |
      v
Known source characteristics preserved?
      |
      v
Data survives normal restart?
      |
      v
INGESTION ACCEPTED
```

This is deliberately stronger than checking only whether the ingestion
process returned a successful exit code.

------------------------------------------------------------------------

## 12. Lessons Learned

### A successful load is not a validated load

A loader can complete successfully while still duplicating rows,
dropping records, changing relationship cardinality, or incorrectly
transforming values.

### Row counts are necessary but insufficient

Exact row-count reconciliation establishes completeness at one level,
but two datasets with identical row counts can still contain materially
different data.

### Logical constraints must be tested explicitly

Because this analytical Iceberg model does not depend on OLTP-style
primary- and foreign-key enforcement, uniqueness and referential
assumptions are part of the validation contract.

### Referential integrity and coverage answer different questions

Referential integrity asks:

> Does every existing child reference a valid parent?

Coverage asks:

> Does every parent have the expected child record?

Both are necessary to understand the dataset.

### Known anomalies can function as validation evidence

The one order without a payment, 768 orders without reviews, 775 orders
without items, and two untranslated categories were already present in
the source profile. Reproducing those conditions in Iceberg provides
evidence that ingestion preserved the source rather than silently
"fixing" it.

### Persistence and backup are separate concerns

Named Docker volumes preserve state across normal container recreation.
They do not constitute a backup strategy.

------------------------------------------------------------------------

## 13. Next Phase

With ingestion validated and frozen, the project returns to its primary
learning objective:

**time-series SQL, CTEs, window functions, and practical Apache Iceberg
behavior.**

The first analytical progression should use the Olist order timeline to
answer a business question such as:

> How did monthly order volume and revenue change over time?

That progression can introduce monthly aggregation, CTEs, `LAG()`,
month-over-month change, cumulative metrics, moving averages,
partial-period handling, and Iceberg partition pruning.
