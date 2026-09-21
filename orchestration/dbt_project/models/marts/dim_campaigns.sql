-- Curated Campaign Dimension
{{ config(materialized='table', alias='campaigns') }}

SELECT
    campaign_id,
    campaign_name,
    campaign_objectives,
    startdate,
    enddate,
    currency,
    buy_rate_cpe,
    volume_agreed,
    gross_cost_budget
FROM {{ ref('stg_briefing') }}
