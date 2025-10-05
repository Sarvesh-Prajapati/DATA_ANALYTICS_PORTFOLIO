--1. Distribution of accidents by speed limit and accident severity

WITH CTE_speed_buckets AS (
  SELECT
    CASE
        WHEN speed_limit <= 10 THEN '0 to 10'
        WHEN speed_limit <= 20 THEN '11 to 20'
        WHEN speed_limit <= 30 THEN '21 to 30'
        WHEN speed_limit <= 40 THEN '31 to 40'
        WHEN speed_limit <= 50 THEN '41 to 50'
        WHEN speed_limit <= 60 THEN '51 to 60'
        WHEN speed_limit <= 70 THEN '61 to 70'
        END AS speed_ranges
    , ACCIDENT_SEVERITY
  FROM TBL_ACCIDENTS   
)
SELECT
  speed_ranges
  , COUNT(CASE WHEN ACCIDENT_SEVERITY ILIKE '%Slight' THEN 1 END) AS slight_count
  , COUNT(CASE WHEN ACCIDENT_SEVERITY ILIKE '%Serious' THEN 1 END) AS serious_count
  , COUNT(CASE WHEN ACCIDENT_SEVERITY ILIKE '%Fatal' THEN 1 END) AS fatal_count
FROM CTE_SPEED_BUCKETS
WHERE speed_ranges IS NOT NULL
GROUP BY speed_ranges
ORDER BY speed_ranges ;


-- 2. Risk matrix showing accident severity by both weather conditions and road surface

SELECT
  weather_conditions
  , road_surface_conditions
  , COUNT(CASE WHEN accident_severity ILIKE '%slight%' THEN 1 END) AS slight_accidents
  , COUNT(CASE WHEN accident_severity ILIKE '%serious%' THEN 1 END) AS serious_accidents
  , COUNT(CASE WHEN accident_severity ILIKE '%fatal%' THEN 1 END) AS fatal_accidents
  , COUNT(*) AS total_accidents
  , ROUND(COUNT(CASE WHEN accident_severity ILIKE '%serious%' OR accident_severity ILIKE '%fatal%' THEN 1
                 END) * 100.0 / NULLIF(COUNT(*), 0), 2) AS pct_severity_rate
 FROM tbl_accidents
 WHERE weather_conditions IS NOT NULL AND road_surface_conditions IS NOT NULL
 GROUP BY weather_conditions, road_surface_conditions
 ORDER BY total_accidents DESC, pct_severity_rate DESC;


-- 3. Districts having statistically significant higher accident rates compared to the national average

WITH CTE_national_stats AS (
  SELECT
    COUNT(*) AS total_accidents,
    AVG(casualty_count) AS avg_casualties_per_accident,
    STDDEV(casualty_count) AS std_dev_casualties
  FROM tbl_accidents
),
CTE_district_stats AS (
  SELECT
    local_authority_district,
    COUNT(*) AS district_accidents,
    AVG(casualty_count) AS district_avg_casualties,
    COUNT(CASE WHEN accident_severity ILIKE '%fatal%' OR accident_severity ILIKE '%serious%' THEN 1 END) AS severe_accidents
  FROM tbl_accidents
  GROUP BY local_authority_district
)
SELECT
  d.local_authority_district,
  d.district_accidents,
  d.district_avg_casualties,
  d.severe_accidents,
  (
    (
      d.district_avg_casualties - n.avg_casualties_per_accident
    ) / (
      n.std_dev_casualties / SQRT(d.district_accidents)
    )
  ) AS z_score,
  ROUND(
    (
      d.district_avg_casualties / n.avg_casualties_per_accident - 1
    ) * 100, 2
    ) AS pct_above_avg
FROM CTE_district_stats AS d CROSS JOIN CTE_national_stats AS n
WHERE
  (
    (
      d.district_avg_casualties - n.avg_casualties_per_accident
    ) / (
      n.std_dev_casualties / SQRT(d.district_accidents)
    )
  ) > 1.96
ORDER BY z_score DESC;




SELECT * FROM tbl_accidents;
