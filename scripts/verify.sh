#!/usr/bin/env bash
set -euo pipefail

check_count() {
  local table="$1"
  local expected="$2"

  local actual
  actual=$(
    docker compose exec -T trino \
      trino --catalog iceberg --schema analytics \
      --output-format TSV \
      --execute "SELECT COUNT(*) FROM ${table}"
  )

  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: ${table} expected ${expected}, got ${actual}"
    exit 1
  fi

  echo "PASS: ${table} = ${actual}"
}

check_count customers 5000
check_count products 500
check_count orders 100000
check_count order_items 300000
check_count events 500000

total=$(
  docker compose exec -T trino \
    trino --catalog iceberg --schema analytics \
    --output-format TSV \
    --execute "
      SELECT
          (SELECT COUNT(*) FROM customers)
        + (SELECT COUNT(*) FROM products)
        + (SELECT COUNT(*) FROM orders)
        + (SELECT COUNT(*) FROM order_items)
        + (SELECT COUNT(*) FROM events)
    "
)

if [[ "$total" != "905500" ]]; then
  echo "FAIL: total rows expected 905500, got ${total}"
  exit 1
fi

echo "PASS: total rows = ${total}"
echo "STACK VERIFICATION PASSED"