# src/tests/test_daily_users_cumulated_job.py
import pytest
from pyspark.sql import SparkSession, Row
from pyspark.sql.types import StructType, StructField, StringType, DateType, ArrayType
from datetime import datetime
from src.jobs.daily_users_cumulated_job import run_daily_users_cumulated

@pytest.fixture(scope="session")
def spark():
    spark = SparkSession.builder \
        .appName("TestDailyUsersCumulated") \
        .master("local[1]") \
        .getOrCreate()
    yield spark
    spark.stop()

def test_daily_users_cumulated(spark):
    """Test FULL OUTER JOIN logic and array of dates"""
    
    # --- yesterday (users_cumulated) fake data ---
    schema = StructType([
        StructField("user_id", StringType(), True),
        StructField("dates_active", ArrayType(DateType()), True),
        StructField("yesterday_date", DateType(), True)
    ])
    
    users_cumulated_data = [
        Row(
            user_id="1",
            dates_active=[],
            yesterday_date=datetime.strptime("2023-01-30", "%Y-%m-%d").date()
        ),
        Row(
            user_id="3",
            dates_active=[],
            yesterday_date=datetime.strptime("2023-01-30", "%Y-%m-%d").date()
        ),
    ]
    
    users_cumulated_df = spark.createDataFrame(users_cumulated_data, schema=schema)
    users_cumulated_df.createOrReplaceTempView("users_cumulated")
    
    # --- today (events) fake data ---
    events_data = [
        Row(user_id="1", event_time="2023-01-31 10:00:00"),
        Row(user_id="2", event_time="2023-01-31 12:00:00"),
    ]
    events_df = spark.createDataFrame(events_data)
    events_df.createOrReplaceTempView("events")
    
    # run the job
    result_df = run_daily_users_cumulated(spark, users_cumulated_df, events_df)
    
    results = {row.user_id: row.dates_active for row in result_df.collect()}

    for row in result_df.collect():
        print(row.user_id, row.dates_active, row.yesterday_date)

    
    # Assertions
    assert "1" in results
    assert "2" in results
    assert "3" in results
    
    # Check that yesterday and today dates exist correctly
    assert any(str(d) == "2023-01-31" for d in results["1"])
    assert any(str(d) == "2023-01-31" for d in results["2"])
    assert any(str(d) == "2023-01-30" for d in results["3"])
