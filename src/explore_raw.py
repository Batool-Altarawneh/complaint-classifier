import pandas as pd


df = pd.read_csv("data/raw/complaints_raw.csv", dtype=str)

print("=== SHAPE ===")
print(f"Rows: {len(df):,}   Columns: {df.shape[1]}")

print("\n=== COLUMNS ===")
print(list(df.columns))

print("\n=== PRODUCT DISTRIBUTION ===")
print(df["Product"].value_counts(dropna=False))

print("\n=== NARRATIVE COMPLETENESS ===")
nar = df["Consumer complaint narrative"]
print(f"Non-empty narratives: {nar.notna().sum():,} of {len(df):,}")
print(f"Missing narratives:   {nar.isna().sum():,}")