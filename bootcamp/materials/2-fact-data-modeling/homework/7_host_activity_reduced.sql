/*
- A monthly, reduced fact table DDL `host_activity_reduced`
   - month
   - host
   - hit_array - think COUNT(1)
   - unique_visitors array -  think COUNT(DISTINCT user_id)

- An incremental query that loads `host_activity_reduced`
  - day-by-day
  */


CREATE TABLE host_activity_reduced (
  month DATE,
  host TEXT,
  hit_array INT[],
  unique_visitors_array INT[],
  PRIMARY KEY (month, host)
);

WITH params AS (
  SELECT DATE '2023-01-02' AS target_date
),

daily_agg AS (
  SELECT
    date_trunc('month', event_time::date) AS month,
    host,
    COUNT(*) AS hit_count,
    COUNT(DISTINCT user_id) AS unique_visitors
  FROM events, params
  WHERE event_time::date = params.target_date
  GROUP BY 1, 2
),

previous_state AS (
  SELECT * FROM host_activity_reduced
),

upsert AS (
  SELECT
    COALESCE(ps.month, da.month) AS month,
    COALESCE(ps.host, da.host) AS host,
    CASE
      WHEN ps.hit_array IS NULL THEN ARRAY[da.hit_count]
      ELSE ps.hit_array || da.hit_count
    END AS hit_array,
    CASE
      WHEN ps.unique_visitors_array IS NULL THEN ARRAY[da.unique_visitors]
      ELSE ps.unique_visitors_array || da.unique_visitors
    END AS unique_visitors_array
  FROM daily_agg da
  LEFT JOIN previous_state ps ON ps.month = da.month AND ps.host = da.host
)

INSERT INTO host_activity_reduced (month, host, hit_array, unique_visitors_array)
SELECT month, host, hit_array, unique_visitors_array
FROM upsert
ON CONFLICT (month, host) DO UPDATE
  SET hit_array = EXCLUDED.hit_array,
      unique_visitors_array = EXCLUDED.unique_visitors_array;


select * from host_activity_reduced;