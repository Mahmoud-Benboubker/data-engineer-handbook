from pyspark.sql import SparkSession

def run_actors_scd_backfill(spark: SparkSession, actors_df):
    """
    Perform SCD Type-2 backfill for actors using Spark SQL.
    Input:
        actors_df: DataFrame with columns
            actorid (int), actor (string), quality_class (string), is_active (bool), snapshot_date (date)
    Output:
        DataFrame with columns:
            actorid, actor, quality_class, is_active, start_date, end_date, is_current
    """

    # Create temp view for SQL
    actors_df.createOrReplaceTempView("actors")

    query = """
    WITH streak_started AS (
        SELECT
            actor,
            actorid,
            quality_class,
            is_active,
            snapshot_date,
            LAG(quality_class) OVER (PARTITION BY actorid ORDER BY snapshot_date) AS prev_quality_class,
            LAG(is_active) OVER (PARTITION BY actorid ORDER BY snapshot_date) AS prev_is_active
        FROM actors
    ),
    did_change_flag AS (
        SELECT *,
            CASE 
                WHEN prev_quality_class IS NULL OR prev_quality_class != quality_class THEN 1
                WHEN prev_is_active IS NULL OR prev_is_active != is_active THEN 1
                ELSE 0
            END AS did_change
        FROM streak_started
    ),
    streak_identifier AS (
        SELECT *,
            SUM(did_change) OVER (PARTITION BY actorid ORDER BY snapshot_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS streak_id
        FROM did_change_flag
    ),
    aggregated AS (
        SELECT
            actor,
            actorid,
            quality_class,
            is_active,
            streak_id,
            MIN(snapshot_date) AS start_date,
            MAX(snapshot_date) AS end_date
        FROM streak_identifier
        GROUP BY actor, actorid, quality_class, is_active, streak_id
    )
    SELECT
        actor,
        actorid,
        quality_class,
        is_active,
        start_date,
        DATE_SUB(LEAD(start_date) OVER (PARTITION BY actorid ORDER BY start_date), 1) AS end_date,
        CASE WHEN LEAD(start_date) OVER (PARTITION BY actorid ORDER BY start_date) IS NULL THEN true ELSE false END AS is_current
    FROM aggregated
    ORDER BY actorid, start_date
    """

    result_df = spark.sql(query)
    return result_df
