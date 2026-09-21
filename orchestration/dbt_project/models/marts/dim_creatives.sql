-- Curated Creative Dimension Enriched with Deep Vision Features
{{ config(materialized='table', alias='creatives') }}

WITH distinct_game_keys AS (
    SELECT DISTINCT game_key
    FROM {{ ref('stg_inventory') }}
    WHERE game_key IS NOT NULL AND game_key LIKE '%/%'
)

SELECT DISTINCT ON (inv.game_key)
    inv.game_key,
    SPLIT_PART(inv.game_key, '/', 1)                                            AS creative_slug,
    SPLIT_PART(inv.game_key, '/', 2)                                            AS creative_request_id,
    SPLIT_PART(inv.game_key, '/', 1) || '-' || SPLIT_PART(inv.game_key, '/', 2) || '.png' AS image_filename,
    COALESCE(v.aspect_ratio, 0.0)                                               AS aspect_ratio,
    COALESCE(v.brightness_mean, 0.0)                                            AS brightness_mean,
    COALESCE(v.saturation_mean, 0.0)                                            AS saturation_mean,
    COALESCE(v.colorfulness, 0.0)                                               AS colorfulness,
    COALESCE(v.visual_entropy, 0.0)                                             AS visual_entropy,
    COALESCE(v.color_diversity_score, 0.0)                                      AS color_diversity_score,
    FALSE                                                                       AS has_video,
    COALESCE(v.is_dark_background, FALSE)                                       AS is_dark_background,
    COALESCE(v.is_light_background, FALSE)                                      AS is_light_background
FROM distinct_game_keys inv
LEFT JOIN {{ ref('stg_vision_features') }} v
    ON v.filename = (
        SPLIT_PART(inv.game_key, '/', 1) || '-' ||
        SPLIT_PART(inv.game_key, '/', 2) || '.png'
    )
ORDER BY inv.game_key
