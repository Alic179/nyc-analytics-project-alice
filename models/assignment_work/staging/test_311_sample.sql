-- Quick test to verify source connection works
SELECT
    unique_key,
    created_date,
    complaint_type,
    borough
FROM {{ source('raw', 'source_311service_requests_subset') }}
LIMIT 10