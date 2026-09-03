from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, avg as spark_avg, when, lit

from awsglue.context import GlueContext
from awsglue.job import Job


SILVER_PATH = "s3://elt-781504636344-ap-southeast-2-an/silver/"

GOLD_AIRLINE_PATH = "s3://elt-781504636344-ap-southeast-2-an/gold/airline_summary/"
GOLD_AIRPORT_PATH = "s3://elt-781504636344-ap-southeast-2-an/gold/airport_summary/"
GOLD_ROUTE_PATH = "s3://elt-781504636344-ap-southeast-2-an/gold/route_monthly_summary/"


REQUIRED_SILVER_COLUMNS = [
    "FL_DATE", "AIRLINE", "AIRLINE_CODE", "DOT_CODE", "FL_NUMBER",
    "ORIGIN", "ORIGIN_CITY", "DEST", "DEST_CITY",
    "CRS_DEP_TIME", "DEP_TIME", "DEP_DELAY", "TAXI_OUT", "WHEELS_OFF",
    "WHEELS_ON", "TAXI_IN", "CRS_ARR_TIME", "ARR_TIME", "ARR_DELAY",
    "CANCELLED", "CANCELLATION_CODE", "DIVERTED",
    "CRS_ELAPSED_TIME", "ELAPSED_TIME", "AIR_TIME", "DISTANCE",
    "DELAY_DUE_CARRIER", "DELAY_DUE_WEATHER", "DELAY_DUE_NAS",
    "DELAY_DUE_SECURITY", "DELAY_DUE_LATE_AIRCRAFT",
    "Year", "Month"
]


spark = (
    SparkSession.builder
    .appName("flight-gold-etl")
    .getOrCreate()
)

glue_context = GlueContext(spark.sparkContext)
job = Job(glue_context)
job.init("flight-gold-etl", {})


print("========================================")
print("FLIGHT GOLD ETL STARTED")
print("========================================")


# ==================================================
# 1. READ SILVER
# ==================================================

print("\nReading Silver Parquet...")

silver_df = spark.read.parquet(SILVER_PATH)

print(f"Silver columns: {silver_df.columns}")


# ==================================================
# 2. VALIDATE REQUIRED COLUMNS (metadata-only, no action)
# ==================================================

print("\nValidating required Silver columns...")

missing_columns = [
    c for c in REQUIRED_SILVER_COLUMNS
    if c not in silver_df.columns
]

if missing_columns:
    raise ValueError(
        f"Silver is missing required columns: {missing_columns}"
    )

print("All required columns present.")


# ==================================================
# 3. CACHE SILVER
# ==================================================
# Silver is read once and reused across 4 aggregations
# (airline, airport-origin, airport-destination, route).
# Caching avoids 3 redundant full scans of ~3M rows.

silver_df = silver_df.cache()


# ==================================================
# 4. BUILD airline_summary
# ==================================================
# Grain: AIRLINE x Year x Month

print("\nBuilding airline_summary...")

airline_summary = (
    silver_df
    .groupBy("AIRLINE", "Year", "Month")
    .agg(
        spark_sum(lit(1)).alias("TOTAL_FLIGHTS"),
        spark_sum(
            when(col("DEP_DELAY") > 0, 1).otherwise(0)
        ).alias("DELAYED_DEPARTURES"),
        spark_sum(
            when(col("ARR_DELAY") > 0, 1).otherwise(0)
        ).alias("DELAYED_ARRIVALS"),
        spark_sum(
            when(col("CANCELLED") == 1, 1).otherwise(0)
        ).alias("CANCELLED_FLIGHTS"),
        spark_sum(
            when(col("DIVERTED") == 1, 1).otherwise(0)
        ).alias("DIVERTED_FLIGHTS"),
        spark_avg("DEP_DELAY").alias("AVG_DEP_DELAY"),
        spark_avg("ARR_DELAY").alias("AVG_ARR_DELAY"),
        spark_sum("DELAY_DUE_CARRIER").alias("TOTAL_CARRIER_DELAY"),
        spark_sum("DELAY_DUE_WEATHER").alias("TOTAL_WEATHER_DELAY"),
        spark_sum("DELAY_DUE_NAS").alias("TOTAL_NAS_DELAY"),
        spark_sum("DELAY_DUE_SECURITY").alias("TOTAL_SECURITY_DELAY"),
        spark_sum("DELAY_DUE_LATE_AIRCRAFT").alias("TOTAL_LATE_AIRCRAFT_DELAY"),
    )
    .withColumn(
        "DEPARTURE_DELAY_RATE",
        when(col("TOTAL_FLIGHTS") > 0, col("DELAYED_DEPARTURES") / col("TOTAL_FLIGHTS"))
    )
    .withColumn(
        "ARRIVAL_DELAY_RATE",
        when(col("TOTAL_FLIGHTS") > 0, col("DELAYED_ARRIVALS") / col("TOTAL_FLIGHTS"))
    )
    .withColumn(
        "CANCELLATION_RATE",
        when(col("TOTAL_FLIGHTS") > 0, col("CANCELLED_FLIGHTS") / col("TOTAL_FLIGHTS"))
    )
    .select(
        "AIRLINE",
        "TOTAL_FLIGHTS",
        "DELAYED_DEPARTURES",
        "DELAYED_ARRIVALS",
        "CANCELLED_FLIGHTS",
        "DIVERTED_FLIGHTS",
        "AVG_DEP_DELAY",
        "AVG_ARR_DELAY",
        "DEPARTURE_DELAY_RATE",
        "ARRIVAL_DELAY_RATE",
        "CANCELLATION_RATE",
        "TOTAL_CARRIER_DELAY",
        "TOTAL_WEATHER_DELAY",
        "TOTAL_NAS_DELAY",
        "TOTAL_SECURITY_DELAY",
        "TOTAL_LATE_AIRCRAFT_DELAY",
        "Year",
        "Month",
    )
)


# ==================================================
# 5. BUILD airport_summary
# ==================================================
# Grain: AIRPORT x AIRPORT_ROLE x Year x Month
# Built as two independent aggregations (origin, destination)
# unioned together -- no join, no Cartesian risk.

print("Building airport_summary...")

origin_summary = (
    silver_df
    .groupBy("ORIGIN", "Year", "Month")
    .agg(
        spark_sum(lit(1)).alias("TOTAL_FLIGHTS"),
        spark_sum(
            when(col("DEP_DELAY") > 0, 1).otherwise(0)
        ).alias("DELAYED_FLIGHTS"),
        spark_sum(
            when(col("CANCELLED") == 1, 1).otherwise(0)
        ).alias("CANCELLED_FLIGHTS"),
        spark_sum(
            when(col("DIVERTED") == 1, 1).otherwise(0)
        ).alias("DIVERTED_FLIGHTS"),
        spark_avg("DEP_DELAY").alias("AVG_DELAY"),
        spark_sum("DEP_DELAY").alias("TOTAL_DELAY_MINUTES"),
    )
    .withColumn("AIRPORT_ROLE", lit("ORIGIN"))
    .withColumnRenamed("ORIGIN", "AIRPORT")
)

destination_summary = (
    silver_df
    .groupBy("DEST", "Year", "Month")
    .agg(
        spark_sum(lit(1)).alias("TOTAL_FLIGHTS"),
        spark_sum(
            when(col("ARR_DELAY") > 0, 1).otherwise(0)
        ).alias("DELAYED_FLIGHTS"),
        spark_sum(
            when(col("CANCELLED") == 1, 1).otherwise(0)
        ).alias("CANCELLED_FLIGHTS"),
        spark_sum(
            when(col("DIVERTED") == 1, 1).otherwise(0)
        ).alias("DIVERTED_FLIGHTS"),
        spark_avg("ARR_DELAY").alias("AVG_DELAY"),
        spark_sum("ARR_DELAY").alias("TOTAL_DELAY_MINUTES"),
    )
    .withColumn("AIRPORT_ROLE", lit("DESTINATION"))
    .withColumnRenamed("DEST", "AIRPORT")
)

airport_summary = (
    origin_summary
    .unionByName(destination_summary)
    .withColumn(
        "DELAY_RATE",
        when(col("TOTAL_FLIGHTS") > 0, col("DELAYED_FLIGHTS") / col("TOTAL_FLIGHTS"))
    )
    .select(
        "AIRPORT",
        "AIRPORT_ROLE",
        "TOTAL_FLIGHTS",
        "DELAYED_FLIGHTS",
        "CANCELLED_FLIGHTS",
        "DIVERTED_FLIGHTS",
        "AVG_DELAY",
        "TOTAL_DELAY_MINUTES",
        "DELAY_RATE",
        "Year",
        "Month",
    )
)


# ==================================================
# 6. BUILD route_monthly_summary
# ==================================================
# Grain: ORIGIN x DEST x Year x Month

print("Building route_monthly_summary...")

route_monthly_summary = (
    silver_df
    .groupBy("ORIGIN", "DEST", "Year", "Month")
    .agg(
        spark_sum(lit(1)).alias("TOTAL_FLIGHTS"),
        spark_sum(
            when(col("DEP_DELAY") > 0, 1).otherwise(0)
        ).alias("DELAYED_DEPARTURES"),
        spark_sum(
            when(col("ARR_DELAY") > 0, 1).otherwise(0)
        ).alias("DELAYED_ARRIVALS"),
        spark_sum(
            when(col("CANCELLED") == 1, 1).otherwise(0)
        ).alias("CANCELLED_FLIGHTS"),
        spark_sum(
            when(col("DIVERTED") == 1, 1).otherwise(0)
        ).alias("DIVERTED_FLIGHTS"),
        spark_avg("DEP_DELAY").alias("AVG_DEP_DELAY"),
        spark_avg("ARR_DELAY").alias("AVG_ARR_DELAY"),
        spark_sum("DISTANCE").alias("TOTAL_DISTANCE"),
        spark_avg("DISTANCE").alias("AVG_DISTANCE"),
    )
    .withColumn(
        "DEPARTURE_DELAY_RATE",
        when(col("TOTAL_FLIGHTS") > 0, col("DELAYED_DEPARTURES") / col("TOTAL_FLIGHTS"))
    )
    .withColumn(
        "ARRIVAL_DELAY_RATE",
        when(col("TOTAL_FLIGHTS") > 0, col("DELAYED_ARRIVALS") / col("TOTAL_FLIGHTS"))
    )
    .select(
        "ORIGIN",
        "DEST",
        "TOTAL_FLIGHTS",
        "DELAYED_DEPARTURES",
        "DELAYED_ARRIVALS",
        "CANCELLED_FLIGHTS",
        "DIVERTED_FLIGHTS",
        "AVG_DEP_DELAY",
        "AVG_ARR_DELAY",
        "DEPARTURE_DELAY_RATE",
        "ARRIVAL_DELAY_RATE",
        "TOTAL_DISTANCE",
        "AVG_DISTANCE",
        "Year",
        "Month",
    )
)


# ==================================================
# 7. WRITE GOLD DATASETS
# ==================================================
# Each aggregated result is small (thousands of rows, not millions),
# so repartitioning by Year/Month here is cheap and keeps the number
# of output files per partition reasonable -- unlike repartitioning
# the full Silver dataset, which would be expensive.

print("\nWriting airline_summary...")

(
    airline_summary
    .repartition("Year", "Month")
    .write
    .mode("overwrite")
    .option("compression", "snappy")
    .partitionBy("Year", "Month")
    .parquet(GOLD_AIRLINE_PATH)
)

print("Writing airport_summary...")

(
    airport_summary
    .repartition("Year", "Month")
    .write
    .mode("overwrite")
    .option("compression", "snappy")
    .partitionBy("Year", "Month")
    .parquet(GOLD_AIRPORT_PATH)
)

print("Writing route_monthly_summary...")

(
    route_monthly_summary
    .repartition("Year", "Month")
    .write
    .mode("overwrite")
    .option("compression", "snappy")
    .partitionBy("Year", "Month")
    .parquet(GOLD_ROUTE_PATH)
)


# ==================================================
# 8. COMPLETION
# ==================================================

silver_df.unpersist()

print("\n========================================")
print("FLIGHT GOLD ETL COMPLETED")
print("========================================")
print(f"airline_summary        : {GOLD_AIRLINE_PATH}")
print(f"airport_summary        : {GOLD_AIRPORT_PATH}")
print(f"route_monthly_summary  : {GOLD_ROUTE_PATH}")
print("Format                 : Parquet")
print("Compression             : Snappy")
print("Partitions               : Year + Month")
print("========================================")


job.commit()