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

-- 4. Accident rate and average casualty count per vehicle type, normalized by vehicle count in accidents

WITH CTE_vehicle_stats AS (
  SELECT
    vehicle_type,
    COUNT(*) AS total_accidents,
    SUM(vehicle_count) AS total_vehicles,
    SUM(casualty_count) AS total_casualties,
    COUNT(
      CASE
        WHEN accident_severity ILIKE '%serious%'
        OR accident_severity ILIKE '%fatal%' THEN 1
      END
    ) AS severe_accidents
  FROM tbl_accidents
  WHERE vehicle_type IS NOT NULL
  GROUP BY vehicle_type
)
SELECT
  vehicle_type,
  total_accidents,
  total_vehicles,
  ROUND(total_accidents * 1.0 / NULLIF(total_vehicles, 0), 4) AS accident_rate_per_vehicle,
  ROUND(total_casualties * 1.0 / NULLIF(total_vehicles, 0), 4) AS casualties_per_vehicle,
  ROUND(severe_accidents * 100.0 / NULLIF(total_accidents, 0), 2) AS severity_rate_pct
FROM CTE_vehicle_stats
ORDER BY accident_rate_per_vehicle DESC;

-- 5. Relationship between junction control types, junction details, and accident severity; include temporal patterns in the analysis

WITH CTE_junction_analysis AS (
  SELECT
    junction_control,
    junction_detail,
    accident_severity,
    HOUR (accident_timestamp) AS hour_of_day,
    day_of_week,
    COUNT(*) AS accident_count,
    SUM(casualty_count) AS total_casualties
  FROM tbl_accidents
  WHERE junction_control IS NOT NULL AND junction_detail IS NOT NULL
  GROUP BY junction_control, junction_detail, accident_severity, hour_of_day, day_of_week
)
SELECT
  junction_control,
  junction_detail,
  day_of_week,
  hour_of_day,
  SUM(
    CASE
      WHEN accident_severity ILIKE '%slight%' THEN accident_count ELSE 0
    END
  ) AS slight_accidents,
  SUM(
    CASE
      WHEN accident_severity ILIKE '%serious%' THEN accident_count ELSE 0
    END
  ) AS serious_accidents,
  SUM(
    CASE
      WHEN accident_severity ILIKE '%fatal%' THEN accident_count ELSE 0
    END
  ) AS fatal_accidents,
  SUM(total_casualties) AS total_casualties,
  ROUND(
    SUM(
      CASE
        WHEN accident_severity ILIKE '%serious%' OR accident_severity ILIKE '%fatal%' THEN accident_count ELSE 0
      END
    ) * 100.0 / NULLIF(SUM(accident_count), 0), 2
  ) AS severity_rate
FROM  CTE_junction_analysis
GROUP BY junction_control, junction_detail, day_of_week, hour_of_day
ORDER BY severity_rate DESC, total_casualties DESC ;

-- 6. Combinations of conditions (weather, light, road type, junction presence) that are most strongly associated with high-severity accidents

WITH CTE_condition_combos AS (
  SELECT
    weather_conditions,
    light_conditions,
    road_type,
    CASE
      WHEN junction_control IS NULL THEN 'No Junction' ELSE 'Has Junction' END
    AS junction_presence,
    COUNT(*) AS total_accidents,
    COUNT(
      CASE
        WHEN accident_severity ILIKE '%serious%' OR accident_severity ILIKE '%fatal%' THEN 1 END
    ) AS severe_accidents,
    SUM(casualty_count) AS total_casualties
  FROM tbl_accidents
  WHERE weather_conditions IS NOT NULL
    AND light_conditions IS NOT NULL
    AND road_type IS NOT NULL
  GROUP BY weather_conditions, light_conditions, road_type, junction_presence
)
SELECT
  weather_conditions,
  light_conditions,
  road_type,
  junction_presence,
  total_accidents,
  severe_accidents,
  total_casualties,
  ROUND(severe_accidents * 100.0 / NULLIF(total_accidents, 0), 2) AS severity_rate,
  ROUND(total_casualties * 1.0 / NULLIF(total_accidents, 0), 2) AS avg_casualties_per_accident
FROM CTE_condition_combos
WHERE total_accidents >= 10
  /* Filtering for statistical significance */
ORDER BY severity_rate DESC, total_accidents DESC
LIMIT 20;

-- 7. Trends in accident frequency and severity by hour-of-day, day-of-week, month

WITH CTE_temporal_analysis AS (
  SELECT
    HOUR (accident_timestamp) AS hour_of_day,
    day_of_week,
    MONTH (accident_timestamp) AS month,
    COUNT(*) AS total_accidents,
    COUNT(
      CASE
        WHEN accident_severity ILIKE '%serious%'
        OR accident_severity ILIKE '%fatal%' THEN 1
      END
    ) AS severe_accidents,
    SUM(casualty_count) AS total_casualties
  FROM tbl_accidents
  GROUP BY hour_of_day, day_of_week, month
)
SELECT
  hour_of_day,
  day_of_week,
  month,
  total_accidents,
  severe_accidents,
  total_casualties,
  ROUND(
    severe_accidents * 100.0 / NULLIF(total_accidents, 0),
    2
  ) AS severity_rate,
  ROUND(
    total_casualties * 1.0 / NULLIF(total_accidents, 0),
    2
  ) AS avg_casualties_per_accident
FROM CTE_temporal_analysis
ORDER BY
  month,
  CASE
    WHEN day_of_week ILIKE '%sunday%' THEN 1
    WHEN day_of_week ILIKE '%monday%' THEN 2
    WHEN day_of_week ILIKE '%tuesday%' THEN 3
    WHEN day_of_week ILIKE '%wednesday%' THEN 4
    WHEN day_of_week ILIKE '%thursday%' THEN 5
    WHEN day_of_week ILIKE '%friday%' THEN 6
    WHEN day_of_week ILIKE '%saturday%' THEN 7
  END,
  hour_of_day;

-- 8. Combine accident frequency, severity, casualty counts, and environmental conditions into a single risk metric (say, 'risk score')

WITH CTE_area_metrics AS (
  SELECT
    area,
    COUNT(*) AS accident_count,
    COUNT(
      CASE
        WHEN accident_severity ILIKE '%serious%'
        OR accident_severity ILIKE '%fatal%' THEN 1
      END
    ) AS severe_accidents,
    SUM(casualty_count) AS total_casualties,
    COUNT(
      CASE
        WHEN weather_conditions ILIKE '%rain%'
        OR weather_conditions ILIKE '%snow%'
        OR weather_conditions ILIKE '%fog%' THEN 1
      END
    ) AS adverse_weather_accidents,
    COUNT(
      CASE
        WHEN road_surface_conditions ILIKE '%wet%'
        OR road_surface_conditions ILIKE '%icy%'
        OR road_surface_conditions ILIKE '%snow%' THEN 1
      END
    ) AS poor_surface_accidents,
    AVG(speed_limit) AS avg_speed_limit
  FROM tbl_accidents
  WHERE area IS NOT NULL
  GROUP BY area
),
CTE_normalized_scores AS (
  SELECT
    area,
    accident_count,
    (accident_count * 100.0 / MAX(accident_count) OVER ()) AS frequency_score
    /* Normalize each component on 0-100 scale */,
    (severe_accidents * 100.0 / NULLIF(accident_count, 0)) AS severity_score,
    (total_casualties * 100.0 / MAX(total_casualties) OVER ()) AS casualty_score,
    (adverse_weather_accidents * 100.0 / NULLIF(accident_count, 0)) AS weather_risk_score,
    (poor_surface_accidents * 100.0 / NULLIF(accident_count, 0)) AS surface_risk_score,
    (avg_speed_limit * 100.0 / MAX(avg_speed_limit) OVER ()) AS speed_risk_score
  FROM CTE_area_metrics
)
SELECT
  area,
  accident_count,
  ROUND(
    (
      frequency_score * 0.25 + severity_score * 0.30 + casualty_score * 0.20 + weather_risk_score * 0.10 + surface_risk_score * 0.10 + speed_risk_score * 0.05
    ), 2
  ) AS risk_score
FROM CTE_normalized_scores
ORDER BY risk_score DESC ;

