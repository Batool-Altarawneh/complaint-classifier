import os
import snowflake.connector
from dotenv import load_dotenv

load_dotenv()  # read .env into environment variables

def get_connection():
    """Return an open Snowflake connection using credentials from environment."""
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database=os.environ["SNOWFLAKE_DATABASE"],
        schema=os.environ["SNOWFLAKE_SCHEMA"],
        role=os.environ["SNOWFLAKE_ROLE"],
    )


if __name__ == "__main__":
    # Quick self-test: connect, confirm identity, count the clean table
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT CURRENT_USER(), CURRENT_WAREHOUSE(), CURRENT_DATABASE()")
    print("Connected as:", cur.fetchone())
    cur.execute("SELECT COUNT(*) FROM COMPLAINTS_CLEAN")
    print("COMPLAINTS_CLEAN rows:", cur.fetchone()[0])
    cur.close()
    conn.close()