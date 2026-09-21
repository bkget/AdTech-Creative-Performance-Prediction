-- Curated Creative Performance Fact Table
{{ config(materialized='table', alias='creative_metrics') }}

SELECT
    ROW_NUMBER() OVER ()                                         AS id,
    campaign_id,
    game_key,
    device_type,
    platform_os,
    geo_country,
    COUNT(*) FILTER (WHERE event_type = 'impression')            AS n_impressions,
    COUNT(*) FILTER (WHERE event_type = 'first_dropped')         AS n_engagements,
    COUNT(*) FILTER (WHERE event_type = 'click-through-event')   AS n_clicks,
    COUNT(*) FILTER (WHERE event_type = 'first_dropped')::FLOAT
        / NULLIF(COUNT(*) FILTER (WHERE event_type = 'impression'), 0)
                                                                 AS engagement_rate,
    COUNT(*) FILTER (WHERE event_type = 'click-through-event')::FLOAT
        / NULLIF(COUNT(*) FILTER (WHERE event_type = 'impression'), 0)
                                                                 AS click_through_rate
FROM {{ ref('stg_inventory') }}
WHERE game_key IN (SELECT game_key FROM {{ ref('dim_creatives') }})
GROUP BY
    campaign_id, game_key, device_type, platform_os, geo_country
