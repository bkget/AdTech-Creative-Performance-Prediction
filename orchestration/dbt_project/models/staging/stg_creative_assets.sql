-- Cleansed creative image assets staging model
{{ config(materialized='view') }}

SELECT
    filename,
    request_id,
    creative_slug,
    file_path
FROM {{ source('staging_raw', 'raw_creative_assets') }}
WHERE filename IS NOT NULL
