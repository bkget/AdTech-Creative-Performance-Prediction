-- Cleansed visual features staging model
{{ config(materialized='view') }}

SELECT
    filename,
    COALESCE(aspect_ratio::FLOAT, 0.0) AS aspect_ratio,
    COALESCE(brightness_mean::FLOAT, 0.0) AS brightness_mean,
    COALESCE(saturation_mean::FLOAT, 0.0) AS saturation_mean,
    COALESCE(colorfulness::FLOAT, 0.0) AS colorfulness,
    COALESCE(visual_entropy::FLOAT, 0.0) AS visual_entropy,
    COALESCE(color_diversity_score::FLOAT, 0.0) AS color_diversity_score,
    COALESCE(is_dark_background::numeric != 0, FALSE) AS is_dark_background,
    COALESCE(is_light_background::numeric != 0, FALSE) AS is_light_background
FROM {{ source('staging_raw', 'raw_vision_features') }}
WHERE filename IS NOT NULL
