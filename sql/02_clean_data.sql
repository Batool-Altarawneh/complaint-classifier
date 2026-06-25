-- Cleaning layer: derive modeling-ready table from RAW.COMPLAINTS_RAW
-- Filters to top 6 products, normalizes whitespace, adds narrative_length,
-- and assigns a deterministic stratified 80/20 train/test split.
-- Result: COMPLAINTS_DB.CLEAN.COMPLAINTS_CLEAN (21,671 rows).

-- Cleaning layer: derive a modeling-ready table from RAW.COMPLAINTS_RAW
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPLAINTS_WH;
USE DATABASE COMPLAINTS_DB;

-- Create a CLEAN schema to hold the derived, modeling-ready table
CREATE SCHEMA IF NOT EXISTS COMPLAINTS_DB.CLEAN;

-- Inspect: confirm the top-6 product counts we're about to filter to
SELECT product, COUNT(*) AS n
FROM COMPLAINTS_DB.RAW.COMPLAINTS_RAW
GROUP BY product
ORDER BY n DESC;


CREATE OR REPLACE TABLE COMPLAINTS_DB.CLEAN.COMPLAINTS_CLEAN AS
SELECT
    complaint_id,
    date_received,
    product AS product,
    -- collapse all whitespace runs (newlines, tabs, multi-space) to single spaces, then trim
    TRIM(REGEXP_REPLACE(consumer_complaint_narrative, '\\s+', ' ')) AS narrative,
    -- length of the cleaned narrative, for EDA
    LENGTH(TRIM(REGEXP_REPLACE(consumer_complaint_narrative, '\\s+', ' '))) AS narrative_length
FROM COMPLAINTS_DB.RAW.COMPLAINTS_RAW
WHERE product IN (
    'Debt collection',
    'Checking or savings account',
    'Credit card',
    'Money transfer, virtual currency, or money service',
    'Mortgage',
    'Vehicle loan or lease'
)
AND consumer_complaint_narrative IS NOT NULL
AND TRIM(consumer_complaint_narrative) <> '';

SELECT COUNT(*) AS clean_rows
FROM COMPLAINTS_DB.CLEAN.COMPLAINTS_CLEAN;

SELECT product, narrative_length, LEFT(narrative, 100) AS preview
FROM COMPLAINTS_DB.CLEAN.COMPLAINTS_CLEAN
LIMIT 5;


-- Class distribution with percentages (the imbalance evidence)
SELECT
    product,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM COMPLAINTS_DB.CLEAN.COMPLAINTS_CLEAN
GROUP BY product
ORDER BY n DESC;


-- Narrative length distribution by product
SELECT
    product,
    COUNT(*)                          AS n,
    MIN(narrative_length)             AS min_len,
    ROUND(AVG(narrative_length))      AS avg_len,
    MEDIAN(narrative_length)          AS median_len,
    MAX(narrative_length)             AS max_len
FROM COMPLAINTS_DB.CLEAN.COMPLAINTS_CLEAN
GROUP BY product
ORDER BY avg_len DESC;



CREATE OR REPLACE TABLE COMPLAINTS_DB.CLEAN.COMPLAINTS_CLEAN AS
SELECT
    complaint_id,
    date_received,
    product,
    narrative,
    narrative_length,
    -- stratified 80/20 label: rank rows within each product, deterministically
    CASE
        WHEN ROW_NUMBER() OVER (
                 PARTITION BY product
                 ORDER BY HASH(complaint_id)
             )
             <= 0.8 * COUNT(*) OVER (PARTITION BY product)
        THEN 'train'
        ELSE 'test'
    END AS split
FROM COMPLAINTS_DB.CLEAN.COMPLAINTS_CLEAN;

-- Verify: overall split should be ~80/20, and proportions preserved per class
SELECT
    split,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM COMPLAINTS_DB.CLEAN.COMPLAINTS_CLEAN
GROUP BY split;

-- Per-class check: each product should be ~80/20 across train/test
SELECT
    product,
    split,
    COUNT(*) AS n,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY product), 1) AS pct_within_product
FROM COMPLAINTS_DB.CLEAN.COMPLAINTS_CLEAN
GROUP BY product, split
ORDER BY product, split;