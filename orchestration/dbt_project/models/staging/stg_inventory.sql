-- Cleansed inventory events staging model
{{ config(materialized='view') }}

SELECT
    campaign_id,
    game_key,
    TRIM(type) AS event_type,
    COALESCE(NULLIF(TRIM(device_type), ''), 'Unknown') AS device_type,
    COALESCE(NULLIF(TRIM(platform_os), ''), 'Unknown') AS platform_os,
    COALESCE(NULLIF(UPPER(TRIM(geo_country)), ''), 'Unknown') AS geo_country
FROM {{ source('staging_raw', 'raw_inventory') }}
WHERE campaign_id IS NOT NULL
  AND game_key IS NOT NULL
  AND game_key LIKE '%/%'
