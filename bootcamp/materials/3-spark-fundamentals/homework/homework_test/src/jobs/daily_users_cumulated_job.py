from pyspark.sql import SparkSession

def run_daily_users_cumulated(spark: SparkSession, users_cumulated_df, events_df):
    """
    Compute daily cumulative active dates per user by combining yesterday's
    data with today's events.
    Returns
        DataFrame (user_id, dates_active, yesterday_date)
    """
    
    users_cumulated_df.createOrReplaceTempView("users_cumulated")
    events_df.createOrReplaceTempView("events")
    
    query = """
WITH yesterday AS (
    SELECT
        user_id,
        CASE 
            WHEN dates_active IS NOT NULL THEN CAST(dates_active AS ARRAY<DATE>)
            ELSE ARRAY() 
        END AS dates_active,
        yesterday_date
    FROM users_cumulated
    WHERE yesterday_date = DATE('2023-01-30')
),
today AS (
    SELECT
        CAST(user_id AS STRING) AS user_id,
        DATE(CAST(event_time AS TIMESTAMP)) AS date_active
    FROM events
    WHERE DATE(CAST(event_time AS TIMESTAMP)) = DATE('2023-01-31')
        AND user_id IS NOT NULL
)
SELECT
    COALESCE(t.user_id, y.user_id) AS user_id,
    CASE
    WHEN ISNULL(y.dates_active) AND ISNULL(t.date_active) THEN ARRAY()
    WHEN ISNULL(y.dates_active) THEN ARRAY(CAST(t.date_active AS DATE))
    WHEN ISNULL(t.date_active) THEN ARRAY_UNION(y.dates_active, ARRAY(y.yesterday_date))
    ELSE ARRAY_UNION(y.dates_active, ARRAY(CAST(t.date_active AS DATE)))
END AS dates_active,
    COALESCE(t.date_active, y.yesterday_date) AS yesterday_date
FROM today t
FULL OUTER JOIN yesterday y
ON t.user_id = y.user_id;
"""
    return spark.sql(query)
