from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col,
    trim,
    when,
    to_date,
    year,
    month
)
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    IntegerType,
    DoubleType
)

from awsglue.context import GlueContext
from awsglue.job import Job


BRONZE_PATH = "s3://elt-781504636344-ap-southeast-2-an/bronze/flight_data.csv"

SILVER_PATH = "s3://elt-781504636344-ap-southeast-2-an/silver/"


spark = (
    SparkSession.builder
    .appName("flight-silver-etl")
    .config("spark.sql.ansi.enabled", "false")
    .config("spark.sql.shuffle.partitions", "8")
    .getOrCreate()
)


glue_context = GlueContext(
    spark.sparkContext
)

job = Job(glue_context)

job.init(
    "flight-silver-etl",
    {}
)


print("========================================")
print("FLIGHT SILVER ETL STARTED")
print("========================================")


# ==================================================
# 1. DEFINE SOURCE SCHEMA
# ==================================================
# FIX: AIRLINE_DOT removed entirely. The full local profile of the
# exact uploaded file confirmed it has 31 columns and does NOT
# include AIRLINE_DOT (it was dropped upstream by the pandas
# cleaning step). Since Spark's CSV reader with an explicit schema
# does POSITIONAL matching (header is skipped, not name-validated),
# keeping a phantom AIRLINE_DOT field shifted every subsequent
# column one position left -- silently corrupting FL_NUMBER, and
# eventually CANCELLED, which is what caused the last failure.

schema = StructType([

    StructField(
        "FL_DATE",
        StringType(),
        True
    ),

    StructField(
        "AIRLINE",
        StringType(),
        True
    ),

    StructField(
        "AIRLINE_CODE",
        StringType(),
        True
    ),

    StructField(
        "DOT_CODE",
        IntegerType(),
        True
    ),

    StructField(
        "FL_NUMBER",
        IntegerType(),
        True
    ),

    StructField(
        "ORIGIN",
        StringType(),
        True
    ),

    StructField(
        "ORIGIN_CITY",
        StringType(),
        True
    ),

    StructField(
        "DEST",
        StringType(),
        True
    ),

    StructField(
        "DEST_CITY",
        StringType(),
        True
    ),

    StructField(
        "CRS_DEP_TIME",
        IntegerType(),
        True
    ),

    StructField(
        "DEP_TIME",
        IntegerType(),
        True
    ),

    StructField(
        "DEP_DELAY",
        IntegerType(),
        True
    ),

    StructField(
        "TAXI_OUT",
        IntegerType(),
        True
    ),

    StructField(
        "WHEELS_OFF",
        IntegerType(),
        True
    ),

    StructField(
        "WHEELS_ON",
        IntegerType(),
        True
    ),

    StructField(
        "TAXI_IN",
        IntegerType(),
        True
    ),

    StructField(
        "CRS_ARR_TIME",
        IntegerType(),
        True
    ),

    StructField(
        "ARR_TIME",
        IntegerType(),
        True
    ),

    StructField(
        "ARR_DELAY",
        IntegerType(),
        True
    ),

    StructField(
        "CANCELLED",
        IntegerType(),
        True
    ),

    StructField(
        "CANCELLATION_CODE",
        StringType(),
        True
    ),

    StructField(
        "DIVERTED",
        IntegerType(),
        True
    ),

    StructField(
        "CRS_ELAPSED_TIME",
        DoubleType(),
        True
    ),

    StructField(
        "ELAPSED_TIME",
        DoubleType(),
        True
    ),

    StructField(
        "AIR_TIME",
        DoubleType(),
        True
    ),

    StructField(
        "DISTANCE",
        DoubleType(),
        True
    ),

    StructField(
        "DELAY_DUE_CARRIER",
        DoubleType(),
        True
    ),

    StructField(
        "DELAY_DUE_WEATHER",
        DoubleType(),
        True
    ),

    StructField(
        "DELAY_DUE_NAS",
        DoubleType(),
        True
    ),

    StructField(
        "DELAY_DUE_SECURITY",
        DoubleType(),
        True
    ),

    StructField(
        "DELAY_DUE_LATE_AIRCRAFT",
        DoubleType(),
        True
    )
])

# ==================================================
# 2. READ BRONZE
# ==================================================

print("\nReading Bronze CSV...")

df = (
    spark.read
    .schema(schema)
    .option("header", "true")
    .option("mode", "PERMISSIVE")
    .option("nullValue", "")
    .option("emptyValue", "")
    .csv(BRONZE_PATH)
)


bronze_count = df.count()

print(
    f"Bronze rows: {bronze_count:,}"
)

print(
    f"Bronze columns: {len(df.columns):,}"
)


# ==================================================
# 3. CLEAN COLUMN NAMES
# ==================================================

print("\nCleaning column names...")

clean_names = []

for column_name in df.columns:

    clean_name = (
        column_name
        .strip()
        .replace(" ", "_")
    )

    clean_names.append(clean_name)


df = df.toDF(*clean_names)


# ==================================================
# 4. CLEAN STRING COLUMNS
# ==================================================

print("\nCleaning string columns...")

string_columns = [
    "AIRLINE",
    "AIRLINE_CODE",
    "ORIGIN",
    "ORIGIN_CITY",
    "DEST",
    "DEST_CITY",
    "CANCELLATION_CODE"
]


for column_name in string_columns:

    df = df.withColumn(
        column_name,
        when(
            trim(col(column_name)) == "",
            None
        ).otherwise(
            trim(col(column_name))
        )
    )


# ==================================================
# 5. (removed) AIRLINE_DOT does not exist in this file — no drop needed
# ==================================================


# ==================================================
# 6. PARSE FL_DATE
# ==================================================
# Format confirmed via full 3M-row local scan: yyyy-MM-dd, 100%
# consistent, no ambiguous or mixed-format rows.

print("\nParsing FL_DATE...")

df = df.withColumn(
    "FL_DATE",
    to_date(
        trim(col("FL_DATE")),
        "yyyy-MM-dd"
    )
)


# ==================================================
# 7. VALIDATE FL_DATE
# ==================================================

print("\nValidating FL_DATE...")

null_date_count = df.filter(
    col("FL_DATE").isNull()
).count()


print(
    f"NULL/invalid FL_DATE: "
    f"{null_date_count:,}"
)


if null_date_count > 0:

    print("\nSample RAW FL_DATE values that failed to parse:")

    df_raw_sample = (
        spark.read
        .schema(schema)
        .option("header", "true")
        .option("mode", "PERMISSIVE")
        .option("nullValue", "")
        .option("emptyValue", "")
        .csv(BRONZE_PATH)
    )

    bad_raw_values = (
        df_raw_sample
        .withColumn(
            "_parsed",
            to_date(trim(col("FL_DATE")), "yyyy-MM-dd")
        )
        .filter(col("_parsed").isNull())
        .select("FL_DATE")
        .distinct()
        .limit(20)
        .collect()
    )

    for r in bad_raw_values:
        print(f"  '{r['FL_DATE']}'")

    raise ValueError(
        "NULL or invalid FL_DATE values detected."
    )


# ==================================================
# 8. VALIDATE CANCELLED
# ==================================================

print("\nValidating CANCELLED...")

cancelled_null_count = df.filter(
    col("CANCELLED").isNull()
).count()


invalid_cancelled = df.filter(
    col("CANCELLED").isNotNull()
    & ~col("CANCELLED").isin(0, 1)
).count()


print(
    f"NULL CANCELLED values: "
    f"{cancelled_null_count:,}"
)


print(
    f"Invalid CANCELLED values: "
    f"{invalid_cancelled:,}"
)


if cancelled_null_count > 0:

    raise ValueError(
        "NULL CANCELLED values detected."
    )


if invalid_cancelled > 0:

    raise ValueError(
        "Invalid CANCELLED values detected."
    )


# ==================================================
# 9. VALIDATE DIVERTED
# ==================================================

print("\nValidating DIVERTED...")

diverted_null_count = df.filter(
    col("DIVERTED").isNull()
).count()


invalid_diverted = df.filter(
    col("DIVERTED").isNotNull()
    & ~col("DIVERTED").isin(0, 1)
).count()


print(
    f"NULL DIVERTED values: "
    f"{diverted_null_count:,}"
)


print(
    f"Invalid DIVERTED values: "
    f"{invalid_diverted:,}"
)


if diverted_null_count > 0:

    raise ValueError(
        "NULL DIVERTED values detected."
    )


if invalid_diverted > 0:

    raise ValueError(
        "Invalid DIVERTED values detected."
    )


# ==================================================
# 10. CANCELLATION CODE VALIDATION
# ==================================================

print("\nChecking cancellation logic...")

cancelled_without_code = df.filter(
    (col("CANCELLED") == 1)
    & col("CANCELLATION_CODE").isNull()
).count()


non_cancelled_with_code = df.filter(
    (col("CANCELLED") == 0)
    & col("CANCELLATION_CODE").isNotNull()
).count()


print(
    "Cancelled without cancellation code: "
    f"{cancelled_without_code:,}"
)


print(
    "Non-cancelled with cancellation code: "
    f"{non_cancelled_with_code:,}"
)


# ==================================================
# 11. REMOVE EXACT DUPLICATES
# ==================================================

print("\nRemoving exact duplicate rows...")

before_deduplication = df.count()

df = df.dropDuplicates()

after_deduplication = df.count()

duplicates_removed = (
    before_deduplication
    - after_deduplication
)


print(
    f"Rows before deduplication: "
    f"{before_deduplication:,}"
)


print(
    f"Duplicate rows removed: "
    f"{duplicates_removed:,}"
)


print(
    f"Rows after deduplication: "
    f"{after_deduplication:,}"
)


# ==================================================
# 12. DERIVE YEAR
# ==================================================

print("\nDeriving Year...")

df = df.withColumn(
    "Year",
    year(
        col("FL_DATE")
    ).cast(IntegerType())
)


# ==================================================
# 13. DERIVE MONTH
# ==================================================

print("Deriving Month...")

df = df.withColumn(
    "Month",
    month(
        col("FL_DATE")
    ).cast(IntegerType())
)


# ==================================================
# 14. VALIDATE YEAR
# ==================================================

print("\nValidating Year...")

invalid_years = df.filter(
    col("Year").isNull()
    | (col("Year") < 2019)
    | (col("Year") > 2023)
).count()


print(
    f"Invalid Year records: "
    f"{invalid_years:,}"
)


if invalid_years > 0:

    raise ValueError(
        "Unexpected Year values detected."
    )


# ==================================================
# 15. VALIDATE MONTH
# ==================================================

print("\nValidating Month...")

invalid_months = df.filter(
    col("Month").isNull()
    | (col("Month") < 1)
    | (col("Month") > 12)
).count()


print(
    f"Invalid Month records: "
    f"{invalid_months:,}"
)


if invalid_months > 0:

    raise ValueError(
        "Unexpected Month values detected."
    )


# ==================================================
# 16. YEAR DISTRIBUTION
# ==================================================

print("\n========================================")
print("YEAR DISTRIBUTION")
print("========================================")


year_distribution = (
    df.groupBy("Year")
    .count()
    .orderBy("Year")
    .collect()
)


for row in year_distribution:

    print(
        f"Year={row['Year']} "
        f"Rows={row['count']:,}"
    )


# ==================================================
# 17. YEAR + MONTH DISTRIBUTION
# ==================================================

print("\n========================================")
print("YEAR + MONTH DISTRIBUTION")
print("========================================")


year_month_distribution = (
    df.groupBy(
        "Year",
        "Month"
    )
    .count()
    .orderBy(
        "Year",
        "Month"
    )
    .collect()
)


for row in year_month_distribution:

    print(
        f"Year={row['Year']} "
        f"Month={row['Month']} "
        f"Rows={row['count']:,}"
    )


# ==================================================
# 18. FINAL ROW COUNT
# ==================================================

silver_count = df.count()


print("\n========================================")
print("FINAL SILVER COUNT")
print("========================================")


print(
    f"Bronze rows : {bronze_count:,}"
)


print(
    f"Silver rows : {silver_count:,}"
)


print(
    f"Rows removed: "
    f"{bronze_count - silver_count:,}"
)


# ==================================================
# 19. REPARTITION BY YEAR + MONTH
# ==================================================

print("\nRepartitioning by Year + Month...")

df = df.repartition(
    "Year",
    "Month"
)


# ==================================================
# 20. WRITE SILVER
# ==================================================

print("\nWriting Silver Parquet...")

(
    df.write
    .mode("overwrite")
    .option(
        "compression",
        "snappy"
    )
    .partitionBy(
        "Year",
        "Month"
    )
    .parquet(
        SILVER_PATH
    )
)


# ==================================================
# 21. COMPLETION
# ==================================================

print("\n========================================")
print("FLIGHT SILVER ETL COMPLETED")
print("========================================")

print(
    f"Bronze rows       : "
    f"{bronze_count:,}"
)

print(
    f"Silver rows       : "
    f"{silver_count:,}"
)

print(
    f"Duplicates removed: "
    f"{duplicates_removed:,}"
)

print(
    f"Final columns     : "
    f"{len(df.columns):,}"
)

print(
    "Format            : Parquet"
)

print(
    "Compression        : Snappy"
)

print(
    "Partitions         : Year + Month"
)

print(
    f"Output             : "
    f"{SILVER_PATH}"
)

print("========================================")


job.commit()