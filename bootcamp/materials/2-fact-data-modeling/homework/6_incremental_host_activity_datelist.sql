/* 
- The incremental query to generate `host_activity_datelist`
*/
create table hosts_cumulated_incremental (
host text,
host_activity_datelist date[],
"current_date" date
);

WITH params AS (
  SELECT DATE '2023-01-02' AS activity_date
),

last_state AS (
  SELECT host, host_activity_datelist
  FROM hosts_cumulated_incremental
  WHERE "current_date" = (SELECT MAX("current_date") FROM hosts_cumulated_incremental)
),

hosts_with_activity AS (
  SELECT DISTINCT host
  FROM events, params
  WHERE event_time::date = params.activity_date
),

updated_hosts AS (
  SELECT
    ls.host,
    CASE
      WHEN hwa.host IS NOT NULL AND NOT ls.host_activity_datelist @> ARRAY[params.activity_date]
      THEN ls.host_activity_datelist || params.activity_date
      ELSE ls.host_activity_datelist
    END AS host_activity_datelist
  FROM last_state ls
  LEFT JOIN hosts_with_activity hwa ON ls.host = hwa.host,
  params
),

new_hosts AS (
  SELECT
    hwa.host,
    ARRAY[params.activity_date] AS host_activity_datelist
  FROM hosts_with_activity hwa
  LEFT JOIN last_state ls ON ls.host = hwa.host,
  params
  WHERE ls.host IS NULL
)

INSERT INTO hosts_cumulated_incremental (host, host_activity_datelist, "current_date")
SELECT host, host_activity_datelist, (SELECT activity_date FROM params) FROM updated_hosts
UNION ALL
SELECT host, host_activity_datelist, (SELECT activity_date FROM params) FROM new_hosts;