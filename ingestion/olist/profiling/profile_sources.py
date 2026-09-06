from pathlib import Path

import pandas as pd


SOURCE_DIR = Path("ingestion/olist/source")


def profile_csv(path: Path) -> None:
    df = pd.read_csv(path, dtype=str)

    print("=" * 72)
    print(path.name)
    print("=" * 72)

    print(f"Rows:    {len(df):,}")
    print(f"Columns: {len(df.columns)}")

    print("\nCOLUMN PROFILE")
    print("-" * 72)

    for column in df.columns:
        null_count = df[column].isna().sum()
        non_null_count = df[column].notna().sum()
        unique_count = df[column].nunique(dropna=True)

        print(
            f"{column:<40}"
            f"non-null={non_null_count:>8,}  "
            f"null={null_count:>8,}  "
            f"unique={unique_count:>8,}"
        )

    print()


def main() -> None:
    files = sorted(SOURCE_DIR.glob("*.csv"))

    if not files:
        raise SystemExit(f"No CSV files found in {SOURCE_DIR}")

    print(f"Found {len(files)} CSV files.\n")

    for path in files:
        profile_csv(path)


if __name__ == "__main__":
    main()