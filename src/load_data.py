"""Load train and test data from Snowflake into pandas DataFrames.

This file uses the Snowflake connection helper from db.py.
The data already has a fixed train/test split created in Snowflake.
"""

from db import get_connection


def load_split():
    """Load the train and test sets from COMPLAINTS_CLEAN.

    Returns:
        train_df: pandas DataFrame containing rows where split = 'train'
        test_df: pandas DataFrame containing rows where split = 'test'
    """

    # Open a connection to Snowflake using the credentials from .env
    conn = get_connection()

    try:
        # Create a cursor. The cursor is used to run SQL queries.
        cur = conn.cursor()

        # Load the training data.
        # We select only the columns needed for modeling and evaluation.
        cur.execute("""
            SELECT
                complaint_id,
                product,
                narrative,
                narrative_length
            FROM COMPLAINTS_CLEAN
            WHERE split = 'train'
        """)

        # Convert the Snowflake query result directly into a pandas DataFrame.
        train_df = cur.fetch_pandas_all()

        # Load the test data using the same columns.
        # This test set must stay separate so we can evaluate the model fairly.
        cur.execute("""
            SELECT
                complaint_id,
                product,
                narrative,
                narrative_length
            FROM COMPLAINTS_CLEAN
            WHERE split = 'test'
        """)

        # Convert the test query result into a pandas DataFrame.
        test_df = cur.fetch_pandas_all()

        # Close the cursor after finishing the queries.
        cur.close()

    finally:
        # close the Snowflake connection, so we do not leave connections open.
        conn.close()

    return train_df, test_df


if __name__ == "__main__":
    

    train_df, test_df = load_split()

    print("=== SHAPES ===")
    print(f"Train: {train_df.shape}")
    print(f"Test:  {test_df.shape}")

    print("\n=== COLUMNS ===")
    print(train_df.columns.tolist())

    print("\n=== TRAIN class distribution ===")
    print(train_df["PRODUCT"].value_counts())

    print("\n=== TEST class distribution ===")
    print(test_df["PRODUCT"].value_counts())