import pytest
from pyspark.sql import SparkSession, Row
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, BooleanType, DateType
from datetime import date
from src.jobs.actors_scd_job import run_actors_scd_backfill

@pytest.fixture(scope="session")
def spark():
    spark = SparkSession.builder \
        .appName("TestActorsSCD") \
        .master("local[1]") \
        .getOrCreate()
    yield spark
    spark.stop()

def test_actors_scd_backfill(spark):
    """
    Test the SCD Type-2 backfill for actors with a small synthetic dataset.
    """

    schema = StructType([
        StructField("actorid", IntegerType(), True),
        StructField("actor", StringType(), True),
        StructField("quality_class", StringType(), True),
        StructField("is_active", BooleanType(), True),
        StructField("snapshot_date", DateType(), True),
    ])

    actors_data = [
        Row(actorid=1, actor="John Doe", quality_class="A", is_active=True, snapshot_date=date(2023,1,1)),
        Row(actorid=1, actor="John Doe", quality_class="B", is_active=True, snapshot_date=date(2023,1,10)),
        Row(actorid=1, actor="John Doe", quality_class="B", is_active=False, snapshot_date=date(2023,1,15)),
        Row(actorid=2, actor="Jane Smith", quality_class="A", is_active=True, snapshot_date=date(2023,1,5)),
    ]

    actors_df = spark.createDataFrame(actors_data, schema=schema)

    result_df = run_actors_scd_backfill(spark, actors_df)

    result = [tuple(r) for r in result_df.collect()]

    expected = [
        ("John Doe", 1, "A", True, date(2023,1,1), date(2023,1,9), False),
        ("John Doe", 1, "B", True, date(2023,1,10), date(2023,1,14), False),
        ("John Doe", 1, "B", False, date(2023,1,15), None, True),
        ("Jane Smith", 2, "A", True, date(2023,1,5), None, True),
    ]

    assert result == expected
