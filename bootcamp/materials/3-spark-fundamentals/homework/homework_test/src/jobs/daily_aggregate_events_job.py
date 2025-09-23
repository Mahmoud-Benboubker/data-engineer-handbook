from pyspark.sql import SparkSession

def run_daily_aggregate_events(spark: SparkSession, events_df):
    """
    Compute daily site hits per user and return monthly aggregates.
    Returns
        DataFrame (user_id, month_start, metric_name, num_hits, day_of_month)
    """
    
    # Temp view for SQL script
    events_df.createOrReplaceTempView("events")
    
    query = """
    WITH daily_aggregate AS (
        SELECT 
            user_id,
            DATE(event_time) AS date,
            COUNT(1) AS num_site_hits
        FROM events
        WHERE user_id IS NOT NULL
        GROUP BY user_id, DATE(event_time)
    )
    SELECT
        user_id,
        DATE_TRUNC('month', date) AS month_start,
        'site_hits' AS metric_name,
        num_site_hits AS num_hits,
        EXTRACT(DAY FROM date) AS day_of_month
    FROM daily_aggregate
    """
    
    result_df = spark.sql(query)
    return result_df
