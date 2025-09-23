import pytest
from pyspark.sql import SparkSession
from pyspark.sql import Row
from src.jobs.daily_aggregate_events_job import run_daily_aggregate_events

@pytest.fixture(scope="session")
def spark():
    spark = SparkSession.builder \
        .appName("TestDailyAggregate") \
        .getOrCreate()
    yield spark
    spark.stop()

def test_daily_aggregate(spark):
    # fake dataset
    events_data = [
        Row(user_id=1, event_time="2023-01-03 10:00:00"),
        Row(user_id=1, event_time="2023-01-03 12:00:00"),
        Row(user_id=2, event_time="2023-01-03 15:00:00"),
    ]
    events_df = spark.createDataFrame(events_data)
    
    result_df = run_daily_aggregate_events(spark, events_df)
    
    # Collect results as dict for easy assertion
    results = {row.user_id: row.num_hits for row in result_df.collect()}

    assert results[1] == 2 
    assert results[2] == 1
