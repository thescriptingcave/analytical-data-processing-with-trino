-- ============================================================
-- Analytical Data Platform - Trino / Iceberg Data Loader
--
-- Target catalog/schema are supplied by the Trino CLI:
--   --catalog iceberg --schema analytics
--
-- Dataset:
--   customers      5,000 rows
--   products         500 rows
--   orders        100,000 rows
--   order_items   300,000 rows
--   events        500,000 rows
--
-- Row generation uses Trino's sequence TABLE FUNCTION.
-- ============================================================

DELETE FROM analytics.events;
DELETE FROM analytics.order_items;
DELETE FROM analytics.orders;
DELETE FROM analytics.products;
DELETE FROM analytics.customers;

-- Customers: 5,000
INSERT INTO analytics.customers
SELECT
    CAST(sequential_number AS BIGINT) AS customer_id,
    'Customer_' || CAST(sequential_number AS VARCHAR) AS name,
    'cust' || CAST(sequential_number AS VARCHAR) || '@example.com' AS email,
    date_add(
        'day',
        CAST(floor(rand() * 900) AS BIGINT),
        TIMESTAMP '2022-01-01 00:00:00'
    ) AS signup_ts,
    element_at(
        ARRAY['us-east', 'us-west', 'eu', 'apac'],
        CAST(floor(rand() * 4) AS INTEGER) + 1
    ) AS region
FROM TABLE(sequence(start => 1, stop => 5000));

-- Products: 500
INSERT INTO analytics.products
SELECT
    CAST(sequential_number AS BIGINT) AS product_id,
    'Product_' || CAST(sequential_number AS VARCHAR) AS name,
    element_at(
        ARRAY['electronics', 'clothing', 'food', 'toys', 'books'],
        CAST(floor(rand() * 5) AS INTEGER) + 1
    ) AS category,
    round(rand() * 495 + 5, 2) AS unit_price
FROM TABLE(sequence(start => 1, stop => 500));

-- Orders: 100,000
INSERT INTO analytics.orders
SELECT
    CAST(sequential_number AS BIGINT) AS order_id,
    CAST(floor(rand() * 5000) AS BIGINT) + 1 AS customer_id,
    date_add(
        'second',
        CAST(floor(rand() * 86400) AS BIGINT),
        date_add(
            'day',
            CAST(floor(rand() * 730) AS BIGINT),
            TIMESTAMP '2024-01-01 00:00:00'
        )
    ) AS order_ts,
    round(rand() * 500 + 5, 2) AS amount,
    element_at(
        ARRAY['pending', 'paid', 'shipped', 'delivered', 'cancelled'],
        CAST(floor(rand() * 5) AS INTEGER) + 1
    ) AS status,
    element_at(
        ARRAY['us-east', 'us-west', 'eu', 'apac'],
        CAST(floor(rand() * 4) AS INTEGER) + 1
    ) AS region,
    element_at(
        ARRAY['electronics', 'clothing', 'food', 'toys', 'books'],
        CAST(floor(rand() * 5) AS INTEGER) + 1
    ) AS category
FROM TABLE(sequence(start => 1, stop => 100000));

-- Order items: exactly 300,000 rows / 3 per order
INSERT INTO analytics.order_items
SELECT
    CAST(sequential_number AS BIGINT) AS item_id,
    CAST(floor((sequential_number - 1) / 3.0) + 1 AS BIGINT) AS order_id,
    CAST(floor(rand() * 500) AS BIGINT) + 1 AS product_id,
    CAST(floor(rand() * 4) AS INTEGER) + 1 AS quantity,
    round(rand() * 500 + 5, 2) AS line_total
FROM TABLE(sequence(start => 1, stop => 300000));

-- Events: 500,000
INSERT INTO analytics.events
SELECT
    CAST(sequential_number AS BIGINT) AS event_id,
    date_add(
        'second',
        CAST(floor(rand() * 86400) AS BIGINT),
        date_add(
            'day',
            CAST(floor(rand() * 730) AS BIGINT),
            TIMESTAMP '2024-01-01 00:00:00'
        )
    ) AS event_ts,
    CAST(floor(rand() * 5000) AS BIGINT) + 1 AS customer_id,
    element_at(
        ARRAY['page_view', 'click', 'add_to_cart', 'checkout', 'purchase'],
        CAST(floor(rand() * 5) AS INTEGER) + 1
    ) AS event_type,
    '/page/' || CAST(CAST(floor(rand() * 100) AS INTEGER) AS VARCHAR) AS page,
    element_at(
        ARRAY['mobile', 'desktop', 'tablet'],
        CAST(floor(rand() * 3) AS INTEGER) + 1
    ) AS device
FROM TABLE(sequence(start => 1, stop => 500000));
