from pathlib import Path

import pandas as pd


SOURCE = Path("ingestion/olist/source")


def load(filename):
    return pd.read_csv(SOURCE / filename, dtype=str)


customers = load("olist_customers_dataset.csv")
orders = load("olist_orders_dataset.csv")
items = load("olist_order_items_dataset.csv")
payments = load("olist_order_payments_dataset.csv")
reviews = load("olist_order_reviews_dataset.csv")
products = load("olist_products_dataset.csv")
sellers = load("olist_sellers_dataset.csv")
translations = load("product_category_name_translation.csv")


def relationship(
    child,
    child_column,
    parent,
    parent_column,
    description,
):
    child_values = set(child[child_column].dropna())
    parent_values = set(parent[parent_column].dropna())

    missing = child_values - parent_values

    print(f"\n{description}")
    print("-" * 72)
    print(f"Distinct child values: {len(child_values):,}")
    print(f"Distinct parent values: {len(parent_values):,}")
    print(f"Missing from parent:    {len(missing):,}")

    if missing:
        print("Sample missing values:")
        for value in sorted(missing)[:5]:
            print(f"  {value}")


print("=" * 72)
print("COMPOSITE KEY CHECKS")
print("=" * 72)

print(
    "order_items duplicate (order_id, order_item_id):",
    items.duplicated(["order_id", "order_item_id"]).sum(),
)

print(
    "payments duplicate (order_id, payment_sequential):",
    payments.duplicated(["order_id", "payment_sequential"]).sum(),
)


print("\n" + "=" * 72)
print("REFERENTIAL INTEGRITY")
print("=" * 72)

relationship(
    orders,
    "customer_id",
    customers,
    "customer_id",
    "orders.customer_id -> customers.customer_id",
)

relationship(
    items,
    "order_id",
    orders,
    "order_id",
    "order_items.order_id -> orders.order_id",
)

relationship(
    items,
    "product_id",
    products,
    "product_id",
    "order_items.product_id -> products.product_id",
)

relationship(
    items,
    "seller_id",
    sellers,
    "seller_id",
    "order_items.seller_id -> sellers.seller_id",
)

relationship(
    payments,
    "order_id",
    orders,
    "order_id",
    "payments.order_id -> orders.order_id",
)

relationship(
    reviews,
    "order_id",
    orders,
    "order_id",
    "reviews.order_id -> orders.order_id",
)

relationship(
    products,
    "product_category_name",
    translations,
    "product_category_name",
    "products.category -> category translation",
)


print("\n" + "=" * 72)
print("ORDER COVERAGE")
print("=" * 72)

order_ids = set(orders["order_id"])

for name, frame in [
    ("order_items", items),
    ("payments", payments),
    ("reviews", reviews),
]:
    represented = set(frame["order_id"])
    missing = order_ids - represented

    print(
        f"{name:<15} "
        f"orders represented={len(represented):>6,}  "
        f"orders without records={len(missing):>6,}"
    )


print("\n" + "=" * 72)
print("REVIEW DUPLICATES")
print("=" * 72)

print(
    "Duplicate review_id rows:",
    reviews["review_id"].duplicated().sum(),
)

print(
    "Duplicate order_id rows:",
    reviews["order_id"].duplicated().sum(),
)

print(
    "Duplicate (review_id, order_id) pairs:",
    reviews.duplicated(["review_id", "order_id"]).sum(),
)