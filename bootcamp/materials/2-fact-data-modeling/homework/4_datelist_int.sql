-- A `datelist_int` generation query. Convert the `device_activity_datelist` column into a `datelist_int` column 

WITH date_generator AS (
  SELECT generate_series(
    DATE '2023-01-01',
    DATE '2023-01-31',
    INTERVAL '1 day'
  )::date AS date
),
user_browser_dates AS (
  SELECT
    userid,
    browser_type,
    jsonb_array_elements_text(device_activity_datelist -> browser_type) AS active_date
  FROM user_devices_cumulated,
       jsonb_object_keys(device_activity_datelist) AS browser_type
),
date_flags AS (
  SELECT
    ub.userid,
    dg.date,
    ub.browser_type,
    CASE WHEN ud.active_date::date IS NOT NULL THEN '1' ELSE '0' END AS active_flag
  FROM date_generator dg
  CROSS JOIN (
    SELECT DISTINCT userid, browser_type FROM user_browser_dates
  ) ub
  LEFT JOIN user_browser_dates ud ON
    ud.userid = ub.userid AND ud.browser_type = ub.browser_type AND ud.active_date::date = dg.date
),
flags_agg AS (
  SELECT
    userid,
    browser_type,
    STRING_AGG(active_flag, '' ORDER BY date) AS datelist_int
  FROM date_flags
  GROUP BY userid, browser_type
),
final_json AS (
  SELECT
    userid,
    jsonb_object_agg(browser_type, datelist_int) AS datelist_int_map
  FROM flags_agg
  GROUP BY userid
)
SELECT * FROM final_json
ORDER BY userid;
