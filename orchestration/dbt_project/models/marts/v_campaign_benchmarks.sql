-- Analytical View: Aggregated Campaign Benchmarks
{{ config(materialized='view', alias='v_campaign_benchmarks') }}

SELECT
    c.campaign_id,
    c.campaign_name,
    COUNT(DISTINCT m.game_key) AS num_creatives,
    SUM(m.n_impressions) AS total_impressions,
    SUM(m.n_engagements) AS total_engagements,
    SUM(m.n_clicks) AS total_clicks,
    ROUND(
        (SUM(m.n_engagements)::NUMERIC / NULLIF(SUM(m.n_impressions), 0)) * 100, 2
    ) AS avg_engagement_rate_pct,
    ROUND(
        (SUM(m.n_clicks)::NUMERIC / NULLIF(SUM(m.n_impressions), 0)) * 100, 2
    ) AS avg_click_through_rate_pct
FROM {{ ref('dim_campaigns') }} c
LEFT JOIN {{ ref('fact_creative_performance') }} m
    ON c.campaign_id = m.campaign_id
GROUP BY c.campaign_id, c.campaign_name
