-- Snowflake setup + raw CFPB data load
-- Creates a cost-controlled warehouse, database, RAW schema, and raw table.
-- Data loaded via Snowsight UI (24,619 rows). See README for reproducibility URL.

-- Purpose:
-- Set up the main Snowflake objects for the CFPB complaint classification project.
-- This script creates a small warehouse, a project database, and a RAW schema
-- where I will load the original complaint CSV before doing any cleaning.

-- I am using ACCOUNTADMIN here because this setup step needs permission
-- to create warehouses, databases, and schemas.
USE ROLE ACCOUNTADMIN;


-- Create a dedicated warehouse for this project.
-- The warehouse is the compute engine in Snowflake, so this is the part
-- that can use trial credits while queries are running.
CREATE WAREHOUSE IF NOT EXISTS COMPLAINTS_WH
  WAREHOUSE_SIZE = 'XSMALL'       -- smallest size, enough for this dataset and cheaper to run
  AUTO_SUSPEND = 60               -- stop the warehouse after 60 seconds of no activity
  AUTO_RESUME = TRUE              -- start it again automatically when I run a query
  INITIALLY_SUSPENDED = TRUE;     -- keep it stopped when created so it does not use credits immediately


-- Create the main database for the project.
-- This keeps all complaint-classification objects in one place.
CREATE DATABASE IF NOT EXISTS COMPLAINTS_DB;


-- Create a RAW schema for the original source data.
-- RAW means the data will be loaded as-is before cleaning or modeling.
CREATE SCHEMA IF NOT EXISTS COMPLAINTS_DB.RAW;


-- Set the working context for the rest of the session.
-- After this, Snowflake knows which warehouse, database, and schema I want to use.
USE WAREHOUSE COMPLAINTS_WH;
USE DATABASE COMPLAINTS_DB;
USE SCHEMA COMPLAINTS_DB.RAW;



-- ------------------------------------------------------------
-- Create the raw complaints table
-- ------------------------------------------------------------
-- This table matches the 16 columns from the original CFPB CSV file.
-- I am using clean snake_case column names so the columns are easier
-- to query later in SQL and Python.
--
-- For the RAW layer, I am keeping all columns as STRING on purpose.
-- This avoids changing the source data too early. Any date parsing,
-- cleaning, or type conversion will happen later in the cleaned layer.

CREATE OR REPLACE TABLE COMPLAINTS_DB.RAW.COMPLAINTS_RAW (
    date_received                   STRING,
    product                         STRING,
    sub_product                     STRING,
    issue                           STRING,
    sub_issue                       STRING,
    consumer_complaint_narrative    STRING,
    company_public_response         STRING,
    company                         STRING,
    state                           STRING,
    zip_code                        STRING,
    tags                            STRING,
    submitted_via                   STRING,
    date_sent_to_company            STRING,
    company_response_to_consumer    STRING,
    timely_response                 STRING,
    complaint_id                    STRING
);

-- ------------------------------------------------------------
-- Verify the raw data load
-- ------------------------------------------------------------
-- I am checking the table directly in Snowflake to make sure the CSV
-- was loaded correctly and that the counts match what I already saw in pandas.
--
-- Important:
-- Run only this verification section after loading the CSV.
-- Do not rerun the CREATE OR REPLACE TABLE statement above, because it would
-- recreate the table and remove the loaded rows.

-- Set the context again so I know these checks are running in the right place.
USE WAREHOUSE COMPLAINTS_WH;
USE DATABASE COMPLAINTS_DB;
USE SCHEMA RAW;


-- 1) Check the total number of rows.
-- Expected result: 24,619 rows.
SELECT 
    COUNT(*) AS total_rows
FROM COMPLAINTS_RAW;


-- 2) Check the Product distribution.
-- This should match the pandas output from the raw CSV exploration.
-- Expected top counts:
-- Debt collection = 7,761
-- Checking or savings account = 4,773
-- Credit card = 4,413
-- Money transfer, virtual currency, or money service = 1,817
-- Mortgage = 1,698
-- Vehicle loan or lease = 1,209
SELECT 
    product,
    COUNT(*) AS complaint_count
FROM COMPLAINTS_RAW
GROUP BY product
ORDER BY complaint_count DESC;


-- 3) Spot-check a few complaint narratives.
-- I am checking that the long text loaded as real text and did not get
-- broken into extra rows because of commas or line breaks inside the complaint.
SELECT 
    product,
    LEFT(consumer_complaint_narrative, 80) AS narrative_start
FROM COMPLAINTS_RAW
LIMIT 5;


-- 4) Extra quality check: confirm narratives are not missing.
-- Expected result: 0 missing narratives.
SELECT
    COUNT(*) AS total_rows,
    COUNT(consumer_complaint_narrative) AS non_empty_narratives,
    COUNT(*) - COUNT(consumer_complaint_narrative) AS missing_narratives
FROM COMPLAINTS_RAW;

