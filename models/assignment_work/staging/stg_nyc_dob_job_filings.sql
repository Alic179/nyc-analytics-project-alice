-- Clean and standardize DOB NOW job filing data
-- One row per job filing

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_dob_now_job_filings') }}
),

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       * EXCEPT (
           job_filing_number,
           filing_status,
           street_name,
           borough,
           block,
           lot,
           bin,
           bbl,
           commmunity_board,
           zip,
           city,
           state,
           postcode,
           latitude,
           longitude
       ),

       -- Identifiers
       CAST(job_filing_number AS STRING) AS job_filing_number,
       CAST(bbl AS STRING) AS bbl,
       CAST(bin AS STRING) AS bin,
       CAST(block AS STRING) AS block,
       CAST(lot AS STRING) AS lot,

       -- Filing details
       UPPER(TRIM(CAST(filing_status AS STRING))) AS filing_status,

       -- Location - conformed with the 311 staging model
       TRIM(CONCAT(IFNULL(house_no, ''), ' ', IFNULL(street_name, ''))) AS incident_address,
       TRIM(CAST(street_name AS STRING)) AS street_name,

       -- Property ZIP (postcode) is the conformed zip; keep only valid 5-digit values
       CASE
           WHEN LENGTH(CAST(postcode AS STRING)) = 5 THEN CAST(postcode AS STRING)
           ELSE NULL
       END AS zip,

       -- Borough standardized the same way as the 311 model
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN or CITYWIDE'
       END AS borough,

       CAST(commmunity_board AS INT64) AS community_board,
       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,

       -- Applicant details renamed so they are not confused with property location
       CAST(zip AS STRING) AS applicant_zip,
       CAST(city AS STRING) AS applicant_city,
       CAST(state AS STRING) AS applicant_state,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE job_filing_number IS NOT NULL
   AND filing_date IS NOT NULL
   AND borough IS NOT NULL

   -- Deduplicate: keep the most recent status row per job filing
   QUALIFY ROW_NUMBER() OVER (PARTITION BY job_filing_number ORDER BY current_status_date DESC) = 1
)

SELECT * FROM cleaned