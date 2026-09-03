SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM iceberg.analytics.customers

UNION ALL

SELECT 'products', COUNT(*)
FROM iceberg.analytics.products

UNION ALL

SELECT 'orders', COUNT(*)
FROM iceberg.analytics.orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM iceberg.analytics.order_items

UNION ALL

SELECT 'events', COUNT(*)
FROM iceberg.analytics.events

ORDER BY table_name;

SELECT
    (SELECT COUNT(*) FROM iceberg.analytics.customers)
  + (SELECT COUNT(*) FROM iceberg.analytics.products)
  + (SELECT COUNT(*) FROM iceberg.analytics.orders)
  + (SELECT COUNT(*) FROM iceberg.analytics.order_items)
  + (SELECT COUNT(*) FROM iceberg.analytics.events)
    AS total_rows;