-- Cleansed campaign briefing staging model
{{ config(materialized='view') }}

SELECT DISTINCT ON (campaign_id)
    TRIM(campaign_id) AS campaign_id,
    TRIM(campaign_name) AS campaign_name,
    campaign_objectives,
    startdate,
    enddate,
    UPPER(TRIM(currency)) AS currency,
    COALESCE(buy_rate_cpe::FLOAT, 0.0) AS buy_rate_cpe,
    COALESCE(volume_agreed::FLOAT, 0.0) AS volume_agreed,
    COALESCE(gross_cost_budget::FLOAT, 0.0) AS gross_cost_budget
FROM {{ source('staging_raw', 'raw_briefing') }}
WHERE campaign_id IS NOT NULL
ORDER BY campaign_id
