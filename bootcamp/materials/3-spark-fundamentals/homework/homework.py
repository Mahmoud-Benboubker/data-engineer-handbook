# %%
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, broadcast
from pyspark.sql.types import BooleanType, IntegerType, TimestampType
from pyspark.sql import functions as F

# %%
spark = (
    SparkSession.builder.appName("Iceberg Local Test")
    .config("spark.sql.catalog.local", "org.apache.iceberg.spark.SparkCatalog")
    .config("spark.sql.catalog.local.type", "hadoop")
    .config("spark.sql.catalog.local.warehouse", "file:///tmp/iceberg_warehouse")
    .config("spark.executor.memory", "4g")
    .config("spark.driver.memory", "4g")
    .getOrCreate()
)

spark.conf.set("spark.sql.shuffle.partitions", 16)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")
spark.conf.set("spark.sql.adaptive.enabled", "true")

# %%
# Read CSVs
matches = (
    spark.read.option("header", "true")
    .csv("/home/iceberg/data/matches.csv")
    .withColumn("is_team_game", col("is_team_game").cast(BooleanType()))
    .withColumn("completion_date", col("completion_date").cast(TimestampType()))
)

match_details = (
    spark.read.option("header", "true")
    .csv("/home/iceberg/data/match_details.csv")
    .withColumn("player_total_kills", col("player_total_kills").cast(IntegerType()))
    .withColumn("player_total_deaths", col("player_total_deaths").cast(IntegerType()))
)

medals = spark.read.option("header", "true").csv("/home/iceberg/data/medals.csv")
medals_matches_players = (
    spark.read.option("header", "true")
    .csv("/home/iceberg/data/medals_matches_players.csv")
    .withColumn("count", col("count").cast(IntegerType()))
)
maps = spark.read.option("header", "true").csv("/home/iceberg/data/maps.csv")

# %%
# Write Iceberg tables (bucketed for match_id)
for df, tbl, cols, bucket in [
    (
        matches,
        "local.matches",
        ["match_id", "mapid", "is_team_game", "playlist_id", "completion_date"],
        16,
    ),
    (
        match_details,
        "local.match_details",
        ["match_id", "player_gamertag", "player_total_kills", "player_total_deaths"],
        16,
    ),
    (
        medals_matches_players,
        "local.medals_matches_players",
        ["match_id", "player_gamertag", "medal_id", "count"],
        16,
    ),
]:
    df.select([F.col(c) for c in cols]).write.mode("overwrite").saveAsTable(tbl)

medals.write.mode("overwrite").saveAsTable("local.medals")
maps.write.mode("overwrite").saveAsTable("local.maps")

# %%
# Bucket joins
bucketed_joined_df = (
    spark.table("local.match_details")
    .join(spark.table("local.matches"), "match_id")
    .join(spark.table("local.medals_matches_players"), ["match_id", "player_gamertag"])
)

bucketed_joined_df.explain()

# %%
# 4a: Player with highest average kills per game
player_avg_kills = (
    spark.table("local.match_details")
    .groupBy("player_gamertag")
    .agg(
        F.sum("player_total_kills").alias("total_kills"),
        F.countDistinct("match_id").alias("matches_played"),
        (F.sum("player_total_kills") / F.countDistinct("match_id")).alias(
            "avg_kills_per_match"
        ),
    )
    .orderBy(F.desc("avg_kills_per_match"))
)

player_avg_kills.show(1)

# %%
# 4b: Most played playlist
spark.table("local.matches").groupBy("playlist_id").count().orderBy(
    F.desc("count")
).show(1)

# %%
# 4c: Most played map
spark.table("local.matches").join(
    broadcast(spark.table("local.maps")), "mapid"
).groupBy("name").count().orderBy(F.desc("count")).show(1)

# %%
# 4d: Map with most Killing Spree medals
killingspree_medals = (
    spark.table("local.medals")
    .filter(col("classification") == "KillingSpree")
    .select("medal_id")
)

ks_events = (
    spark.table("local.medals_matches_players")
    .join(broadcast(killingspree_medals), "medal_id")
    .groupBy("match_id")
    .agg(F.sum("count").alias("ks_count"))
)

spark.table("local.matches").join(broadcast(ks_events), "match_id").join(
    broadcast(spark.table("local.maps")), "mapid"
).groupBy("name").agg(F.sum("ks_count").alias("total_killingsprees")).orderBy(
    F.desc("total_killingsprees")
).show(
    1
)

# %%
# 5: Test sortWithinPartitions for data size optimization
# Version A: partitionBy playlist
bucketed_joined_df.repartition("playlist_id").sortWithinPartitions(
    "mapid", "completion_date"
).write.mode("overwrite").partitionBy("playlist_id").parquet("/tmp/opt_vA_playlist")

# Version B: partitionBy mapid
bucketed_joined_df.repartition("mapid").sortWithinPartitions(
    "playlist_id", "completion_date"
).write.mode("overwrite").partitionBy("mapid").parquet("/tmp/opt_vB_map")

# Version C: partitionBy playlist + map
bucketed_joined_df.repartition("playlist_id", "mapid").sortWithinPartitions(
    "completion_date"
).write.mode("overwrite").partitionBy("playlist_id", "mapid").parquet(
    "/tmp/opt_vC_both"
)
