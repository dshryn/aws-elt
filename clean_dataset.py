import os
import pandas as pd
import numpy as np

INPUT_FILE = "dataset/flight_data.csv"

OUTPUT_DIR = "output"

CLEANED_FILE = os.path.join(
    OUTPUT_DIR,
    "flight_data_cleaned.csv"
)

PROFILE_FILE = os.path.join(
    OUTPUT_DIR,
    "data_quality_report.csv"
)

os.makedirs(OUTPUT_DIR, exist_ok=True)

print("========================================")
print("FLIGHT DATA LOCAL PROFILING")
print("========================================")

print("\nReading dataset...")

df = pd.read_csv(
    INPUT_FILE,
    low_memory=False,
    na_values=[
        "",
        " ",
        "NA",
        "N/A",
        "NULL",
        "null"
    ]
)

original_rows = len(df)
original_columns = len(df.columns)

print(f"Rows    : {original_rows:,}")
print(f"Columns : {original_columns:,}")


print("\nCleaning column names...")

df.columns = (
    df.columns
    .str.strip()
    .str.replace(r"\s+", "_", regex=True)
)


print("Cleaning string columns...")

missing_string_tokens = {
    "",
    " ",
    "na",
    "n/a",
    "null",
    
}

for column in list(
    df.select_dtypes(include=["object"]).columns
):

    def clean_string_value(value):

        if value is None or pd.isna(value):
            return np.nan

        if isinstance(value, str):
            value = value.strip()

            if value == "":
                return np.nan

            normalized = value.lower()

            if normalized in missing_string_tokens:
                return np.nan

            return value

        if isinstance(value, (list, tuple, set)):
            return [clean_string_value(item) for item in value]

        if isinstance(value, np.ndarray):
            return np.array(
                [clean_string_value(item) for item in value],
                dtype=object
            )

        if isinstance(value, (dict,)):
            return {
                key: clean_string_value(val)
                for key, val in value.items()
            }

        return value

    df[column] = df[column].map(clean_string_value)

    df[column] = df[column].replace(
        r"^\s*$",
        np.nan,
        regex=True
    )


print("Converting FL_DATE...")

if "FL_DATE" in df.columns:

    df["FL_DATE"] = pd.to_datetime(
        df["FL_DATE"],
        errors="coerce",
        dayfirst=True
    )


integer_columns = [
    "AIRLINE_DOT",
    "DOT_CODE",
    "FL_NUMBER",
    "CRS_DEP_TIME",
    "DEP_TIME",
    "DEP_DELAY",
    "TAXI_OUT",
    "WHEELS_OFF",
    "WHEELS_ON",
    "TAXI_IN",
    "CRS_ARR_TIME",
    "ARR_TIME",
    "ARR_DELAY",
    "CANCELLED",
    "DIVERTED"
]


float_columns = [
    "CRS_ELAPSED_TIME",
    "ELAPSED_TIME",
    "AIR_TIME",
    "DISTANCE",
    "DELAY_DUE_CARRIER",
    "DELAY_DUE_WEATHER",
    "DELAY_DUE_NAS",
    "DELAY_DUE_SECURITY",
    "DELAY_DUE_LATE_AIRCRAFT"
]


print("Converting numeric columns...")

for column in integer_columns:

    if column in df.columns:

        df[column] = pd.to_numeric(
            df[column],
            errors="coerce"
        ).astype("Int64")


for column in float_columns:

    if column in df.columns:

        df[column] = pd.to_numeric(
            df[column],
            errors="coerce"
        )


print("\n========================================")
print("DATA VALIDATION")
print("========================================")


print("\nChecking FL_DATE...")

if "FL_DATE" in df.columns:

    invalid_dates = df["FL_DATE"].isna().sum()

    print(
        f"Invalid/missing FL_DATE: "
        f"{invalid_dates:,}"
    )

else:

    raise ValueError(
        "FL_DATE column not found."
    )


print("\nChecking CANCELLED...")

if "CANCELLED" in df.columns:

    invalid_cancelled = (
        ~df["CANCELLED"].isin([0, 1])
        & df["CANCELLED"].notna()
    ).sum()

    print(
        f"Invalid CANCELLED values: "
        f"{invalid_cancelled:,}"
    )

    if invalid_cancelled > 0:

        raise ValueError(
            "Invalid values found in CANCELLED."
        )


print("\nChecking DIVERTED...")

if "DIVERTED" in df.columns:

    invalid_diverted = (
        ~df["DIVERTED"].isin([0, 1])
        & df["DIVERTED"].notna()
    ).sum()

    print(
        f"Invalid DIVERTED values: "
        f"{invalid_diverted:,}"
    )

    if invalid_diverted > 0:

        raise ValueError(
            "Invalid values found in DIVERTED."
        )


print("\nChecking cancellation logic...")

if (
    "CANCELLED" in df.columns
    and "CANCELLATION_CODE" in df.columns
):

    cancelled_without_code = (
        (df["CANCELLED"] == 1)
        & df["CANCELLATION_CODE"].isna()
    ).sum()

    non_cancelled_with_code = (
        (df["CANCELLED"] == 0)
        & df["CANCELLATION_CODE"].notna()
    ).sum()

    print(
        "Cancelled flights without cancellation code: "
        f"{cancelled_without_code:,}"
    )

    print(
        "Non-cancelled flights with cancellation code: "
        f"{non_cancelled_with_code:,}"
    )


print("\nChecking diversion distribution...")

if "DIVERTED" in df.columns:

    print(
        df["DIVERTED"]
        .value_counts(dropna=False)
        .sort_index()
    )


print("\nChecking delay values...")

if "DEP_DELAY" in df.columns:

    negative_dep_delay = (
        df["DEP_DELAY"] < 0
    ).sum()

    print(
        f"Negative DEP_DELAY values: "
        f"{negative_dep_delay:,}"
    )


if "ARR_DELAY" in df.columns:

    negative_arr_delay = (
        df["ARR_DELAY"] < 0
    ).sum()

    print(
        f"Negative ARR_DELAY values: "
        f"{negative_arr_delay:,}"
    )


print("\nChecking exact duplicates...")

exact_duplicates = df.duplicated().sum()

print(
    f"Exact duplicate rows: "
    f"{exact_duplicates:,}"
)

print(
    "Duplicate rows will NOT be removed automatically."
)


print("\nChecking completely empty columns...")

empty_columns: list[str] = []

for column in list(df.columns):

    non_null_count = df[column].notna().sum()

    if non_null_count == 0:

        empty_columns.append(column)


if empty_columns:

    print("Completely empty columns:")

    for column in empty_columns:

        print(f"  - {column}")

else:

    print("No completely empty columns found.")


print("\n========================================")
print("DATE DISTRIBUTION")
print("========================================")


valid_dates = df["FL_DATE"].notna()

date_years = (
    df.loc[valid_dates, "FL_DATE"]
    .dt.year
)

date_months = (
    df.loc[valid_dates, "FL_DATE"]
    .dt.month
)


print("\nYears present:")

print(
    date_years
    .value_counts()
    .sort_index()
)


print("\nMonths present:")

print(
    date_months
    .value_counts()
    .sort_index()
)


print("\nYear + Month distribution:")

year_month_distribution = (
    df.loc[valid_dates]
    .assign(
        YEAR=df.loc[valid_dates, "FL_DATE"].dt.year,
        MONTH=df.loc[valid_dates, "FL_DATE"].dt.month
    )
    .groupby(["YEAR", "MONTH"])
    .size()
    .reset_index(name="FLIGHT_COUNT")
    .sort_values(["YEAR", "MONTH"])
)

print(
    year_month_distribution.to_string(
        index=False
    )
)


print("\n========================================")
print("AIRLINE DISTRIBUTION")
print("========================================")


if "AIRLINE" in df.columns:

    print(
        df["AIRLINE"]
        .value_counts()
        .head(20)
    )


print("\n========================================")
print("DATA QUALITY REPORT")
print("========================================")


profile_data = []

for column in list(df.columns):

    profile_data.append({
        "column": column,
        "dtype": str(df[column].dtype),
        "null_count": int(
            df[column].isna().sum()
        ),
        "null_percentage": round(
            df[column].isna().mean() * 100,
            2
        ),
        "unique_values": int(
            df[column].nunique(
                dropna=True
            )
        )
    })


profile = pd.DataFrame(profile_data)


profile.to_csv(
    PROFILE_FILE,
    index=False
)


print("\nRemoving completely empty columns...")

if empty_columns:

    df = df.drop(
        columns=empty_columns
    )

    print(
        f"Removed {len(empty_columns)} "
        f"completely empty column(s)."
    )

else:

    print("No columns removed.")


cleaned_rows = len(df)


print("\nChecking row count...")

print(
    f"Before cleaning : {original_rows:,}"
)

print(
    f"After cleaning  : {cleaned_rows:,}"
)


if cleaned_rows != original_rows:

    raise ValueError(
        "Row count changed unexpectedly."
    )


print("\nSaving cleaned dataset...")

df.to_csv(
    CLEANED_FILE,
    index=False
)


print("\n========================================")
print("LOCAL PROFILING COMPLETED")
print("========================================")

print(
    f"Original rows        : "
    f"{original_rows:,}"
)

print(
    f"Final rows           : "
    f"{cleaned_rows:,}"
)

print(
    f"Original columns     : "
    f"{original_columns:,}"
)

print(
    f"Final columns        : "
    f"{len(df.columns):,}"
)

print(
    f"Exact duplicates     : "
    f"{exact_duplicates:,}"
)

print(
    f"Empty columns removed: "
    f"{len(empty_columns):,}"
)

print("\nFiles created:")

print(
    CLEANED_FILE
)

print(
    PROFILE_FILE
)

print("\n========================================")
print("DONE")
print("========================================")