CREATE TABLE IF NOT EXISTS iceberg.olist.customers (
    customer_id              VARCHAR,
    customer_unique_id       VARCHAR,
    customer_zip_code_prefix INTEGER,
    customer_city            VARCHAR,
    customer_state           VARCHAR
)
WITH (
    format = 'PARQUET'
);


CREATE TABLE IF NOT EXISTS iceberg.olist.orders (
    order_id                       VARCHAR,
    customer_id                    VARCHAR,
    order_status                   VARCHAR,
    order_purchase_timestamp       TIMESTAMP,
    order_approved_at              TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP
)
WITH (
    format = 'PARQUET',
    partitioning = ARRAY['month(order_purchase_timestamp)']
);


CREATE TABLE IF NOT EXISTS iceberg.olist.order_items (
    order_id             VARCHAR,
    order_item_id        INTEGER,
    product_id           VARCHAR,
    seller_id            VARCHAR,
    shipping_limit_date  TIMESTAMP,
    price                DECIMAL(12, 2),
    freight_value        DECIMAL(12, 2)
)
WITH (
    format = 'PARQUET'
);


CREATE TABLE IF NOT EXISTS iceberg.olist.order_payments (
    order_id              VARCHAR,
    payment_sequential    INTEGER,
    payment_type          VARCHAR,
    payment_installments  INTEGER,
    payment_value         DECIMAL(12, 2)
)
WITH (
    format = 'PARQUET'
);


CREATE TABLE IF NOT EXISTS iceberg.olist.order_reviews (
    review_id                 VARCHAR,
    order_id                  VARCHAR,
    review_score              INTEGER,
    review_comment_title      VARCHAR,
    review_comment_message    VARCHAR,
    review_creation_date      TIMESTAMP,
    review_answer_timestamp   TIMESTAMP
)
WITH (
    format = 'PARQUET'
);


CREATE TABLE IF NOT EXISTS iceberg.olist.products (
    product_id                  VARCHAR,
    product_category_name       VARCHAR,
    product_name_length         INTEGER,
    product_description_length  INTEGER,
    product_photos_qty          INTEGER,
    product_weight_g            INTEGER,
    product_length_cm           INTEGER,
    product_height_cm           INTEGER,
    product_width_cm            INTEGER
)
WITH (
    format = 'PARQUET'
);


CREATE TABLE IF NOT EXISTS iceberg.olist.sellers (
    seller_id               VARCHAR,
    seller_zip_code_prefix  INTEGER,
    seller_city             VARCHAR,
    seller_state            VARCHAR
)
WITH (
    format = 'PARQUET'
);


CREATE TABLE IF NOT EXISTS iceberg.olist.product_category_translation (
    product_category_name          VARCHAR,
    product_category_name_english  VARCHAR
)
WITH (
    format = 'PARQUET'
);


CREATE TABLE IF NOT EXISTS iceberg.olist.geolocation (
    geolocation_zip_code_prefix  INTEGER,
    geolocation_lat              DOUBLE,
    geolocation_lng              DOUBLE,
    geolocation_city             VARCHAR,
    geolocation_state            VARCHAR
)
WITH (
    format = 'PARQUET'
);