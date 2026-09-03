CREATE SCHEMA IF NOT EXISTS iceberg.analytics;

CREATE TABLE iceberg.analytics.orders (
    order_id       BIGINT,
    customer_id    BIGINT,
    order_ts       TIMESTAMP,
    amount         DOUBLE,
    status         VARCHAR(20),
    region         VARCHAR(20),
    category       VARCHAR(30)
)
WITH (
    format = 'PARQUET',
    partitioning = ARRAY['month(order_ts)']
);

CREATE TABLE iceberg.analytics.customers (
    customer_id    BIGINT,
    name           VARCHAR(100),
    email          VARCHAR(200),
    signup_ts      TIMESTAMP,
    region         VARCHAR(20)
)
WITH (
    format = 'PARQUET'
);

CREATE TABLE iceberg.analytics.products (
    product_id     BIGINT,
    name           VARCHAR(200),
    category       VARCHAR(30),
    unit_price     DOUBLE
)
WITH (
    format = 'PARQUET'
);

CREATE TABLE iceberg.analytics.order_items (
    item_id        BIGINT,
    order_id       BIGINT,
    product_id     BIGINT,
    quantity       INTEGER,
    line_total     DOUBLE
)
WITH (
    format = 'PARQUET'
);

CREATE TABLE iceberg.analytics.events (
    event_id       BIGINT,
    event_ts       TIMESTAMP,
    customer_id    BIGINT,
    event_type     VARCHAR(30),
    page           VARCHAR(200),
    device         VARCHAR(20)
)
WITH (
    format = 'PARQUET',
    partitioning = ARRAY['month(event_ts)']
);