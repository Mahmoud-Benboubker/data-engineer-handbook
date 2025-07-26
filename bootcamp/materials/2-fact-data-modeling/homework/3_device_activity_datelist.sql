/*
    A cumulative query to generate `device_activity_datelist` from `events`
*/


insert into user_devices_cumulated 
WITH dedup_events AS (
  SELECT DISTINCT
    user_id,
    device_id,
    event_time::date AS event_date
  FROM events
),
dedup_events_browser AS (
  select
  DISTINCT
    de.user_id,
    de.device_id,
    de.event_date,
    COALESCE(d.browser_type, 'Other') AS browser_type
  FROM dedup_events de
  LEFT JOIN devices d ON d.device_id = de.device_id
  ORDER by de.user_id,
    de.device_id,
    de.event_date
),
browser_dates AS (
  SELECT
    user_id,
    browser_type,
    jsonb_agg(to_jsonb(event_date) ORDER BY event_date) AS dates_array
  FROM dedup_events_browser
  GROUP BY user_id, browser_type
)
SELECT
  u.user_id,
  COALESCE(
    jsonb_object_agg(bd.browser_type, bd.dates_array) FILTER (WHERE bd.browser_type IS NOT NULL),
    '{}'::jsonb
  ) AS device_activity_datelist
FROM users u
LEFT JOIN browser_dates bd ON bd.user_id = u.user_id
GROUP BY u.user_id
ORDER BY u.user_id;
