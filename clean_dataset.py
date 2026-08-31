import pandas as pd
import numpy as np
import os

INPUT_FILE = "dataset/flight_data_2018_2024.csv"
OUTPUT_FILE = "output/flight_data_2018_2024_cleaned.csv"
PROFILE_FILE = "output/data_quality_report.csv"

os.makedirs("output", exist_ok=True)

print("Reading dataset...")

df = pd.read_csv(
    INPUT_FILE,
    low_memory=False,
    na_values=["", " ", "NA", "N/A", "NULL", "null"]
)

original_rows = len(df)

print(f"Rows: {original_rows:,}")
print(f"Columns: {len(df.columns)}")

df.columns = df.columns.str.strip()

for col in df.select_dtypes(include=["object"]).columns:
    df[col] = df[col].apply(
        lambda x: x.strip() if isinstance(x, str) else x
    )

    df[col] = df[col].replace(
        r"^\s*$",
        np.nan,
        regex=True
    )

if "FlightDate" in df.columns:
    df["FlightDate"] = pd.to_datetime(
        df["FlightDate"],
        errors="coerce"
    )

if "Year" in df.columns:
    df["Year"] = pd.to_numeric(
        df["Year"],
        errors="coerce"
    ).astype("Int64")

if "Quarter" in df.columns:
    df["Quarter"] = pd.to_numeric(
        df["Quarter"],
        errors="coerce"
    ).astype("Int64")

if "Month" in df.columns:
    df["Month"] = pd.to_numeric(
        df["Month"],
        errors="coerce"
    ).astype("Int64")

if "DayofMonth" in df.columns:
    df["DayofMonth"] = pd.to_numeric(
        df["DayofMonth"],
        errors="coerce"
    ).astype("Int64")

if "DayOfWeek" in df.columns:
    df["DayOfWeek"] = pd.to_numeric(
        df["DayOfWeek"],
        errors="coerce"
    ).astype("Int64")

integer_columns = [
    "DOT_ID_Marketing_Airline",
    "Flight_Number_Marketing_Airline",
    "DOT_ID_Originally_Scheduled_Code_Share_Airline",
    "Flight_Num_Originally_Scheduled_Code_Share_Airline",
    "DOT_ID_Operating_Airline",
    "Flight_Number_Operating_Airline",
    "OriginAirportID",
    "OriginAirportSeqID",
    "OriginCityMarketID",
    "OriginStateFips",
    "OriginWac",
    "DestAirportID",
    "DestAirportSeqID",
    "DestCityMarketID",
    "DestStateFips",
    "DestWac",
    "CRSDepTime",
    "DepTime",
    "DepDelayMinutes",
    "DepDel15",
    "DepartureDelayGroups",
    "TaxiOut",
    "WheelsOff",
    "WheelsOn",
    "TaxiIn",
    "CRSArrTime",
    "ArrTime",
    "ArrDelayMinutes",
    "ArrDel15",
    "ArrivalDelayGroups",
    "Cancelled",
    "Diverted",
    "Flights",
    "DistanceGroup",
    "DivAirportLandings",
    "DivReachedDest",
    "Div1AirportID",
    "Div1AirportSeqID",
    "Div1WheelsOn",
    "Div1TotalGTime",
    "Div1LongestGTime",
    "Div1WheelsOff",
    "Div2AirportID",
    "Div2AirportSeqID",
    "Div2WheelsOn",
    "Div2TotalGTime",
    "Div2LongestGTime",
    "Div2WheelsOff",
    "Div3AirportID",
    "Div3AirportSeqID",
    "Div3WheelsOn",
    "Div3TotalGTime",
    "Div3LongestGTime",
    "Div3WheelsOff",
    "Div4AirportID",
    "Div4AirportSeqID",
    "Div4WheelsOn",
    "Div4TotalGTime",
    "Div4LongestGTime",
    "Div4WheelsOff",
    "Div5AirportID",
    "Div5AirportSeqID",
    "Div5WheelsOn",
    "Div5TotalGTime",
    "Div5LongestGTime",
    "Div5WheelsOff"
]

for col in integer_columns:
    if col in df.columns:
        df[col] = pd.to_numeric(
            df[col],
            errors="coerce"
        ).astype("Int64")

float_columns = [
    "DepDelay",
    "ArrDelay",
    "CRSElapsedTime",
    "ActualElapsedTime",
    "AirTime",
    "Distance",
    "CarrierDelay",
    "WeatherDelay",
    "NASDelay",
    "SecurityDelay",
    "LateAircraftDelay",
    "FirstDepTime",
    "TotalAddGTime",
    "LongestAddGTime",
    "DivActualElapsedTime",
    "DivArrDelay",
    "DivDistance"
]

for col in float_columns:
    if col in df.columns:
        df[col] = pd.to_numeric(
            df[col],
            errors="coerce"
        )

if "Cancelled" in df.columns:
    df["Cancelled"] = pd.to_numeric(
        df["Cancelled"],
        errors="coerce"
    ).astype("Int64")

if "Diverted" in df.columns:
    df["Diverted"] = pd.to_numeric(
        df["Diverted"],
        errors="coerce"
    ).astype("Int64")

if "DepDel15" in df.columns:
    df["DepDel15"] = pd.to_numeric(
        df["DepDel15"],
        errors="coerce"
    ).astype("Int64")

if "ArrDel15" in df.columns:
    df["ArrDel15"] = pd.to_numeric(
        df["ArrDel15"],
        errors="coerce"
    ).astype("Int64")

if "Duplicate" in df.columns:
    df["Duplicate"] = (
        df["Duplicate"]
        .astype("string")
        .str.strip()
    )

print("\nRunning validation...")

if "FlightDate" in df.columns and "Year" in df.columns:

    valid_dates = df["FlightDate"].notna()

    date_year = df.loc[valid_dates, "FlightDate"].dt.year

    inconsistent_year = (
        df.loc[valid_dates, "Year"] != date_year
    ).sum()

    print(
        f"FlightDate/Year inconsistencies: "
        f"{inconsistent_year:,}"
    )

if "FlightDate" in df.columns and "Month" in df.columns:

    valid_dates = df["FlightDate"].notna()

    date_month = df.loc[valid_dates, "FlightDate"].dt.month

    inconsistent_month = (
        df.loc[valid_dates, "Month"] != date_month
    ).sum()

    print(
        f"FlightDate/Month inconsistencies: "
        f"{inconsistent_month:,}"
    )

if "Cancelled" in df.columns:

    invalid_cancelled = (
        ~df["Cancelled"].isin([0, 1])
        & df["Cancelled"].notna()
    ).sum()

    print(
        f"Invalid Cancelled values: "
        f"{invalid_cancelled:,}"
    )

if "Diverted" in df.columns:

    invalid_diverted = (
        ~df["Diverted"].isin([0, 1])
        & df["Diverted"].notna()
    ).sum()

    print(
        f"Invalid Diverted values: "
        f"{invalid_diverted:,}"
    )

print("\nChecking duplicates...")

exact_duplicates = df.duplicated().sum()

print(
    f"Exact duplicate rows: "
    f"{exact_duplicates:,}"
)

print("\nCreating data-quality report...")

profile = pd.DataFrame({
    "column": df.columns,
    "dtype": [
        str(df[col].dtype)
        for col in df.columns
    ],
    "null_count": [
        df[col].isna().sum()
        for col in df.columns
    ],
    "null_percentage": [
        round(df[col].isna().mean() * 100, 2)
        for col in df.columns
    ],
    "unique_values": [
        df[col].nunique(dropna=True)
        for col in df.columns
    ]
})

profile.to_csv(
    PROFILE_FILE,
    index=False
)

print("\nSaving cleaned dataset...")

df.to_csv(
    OUTPUT_FILE,
    index=False
)

print("\n====================================")
print("LOCAL CLEANING COMPLETED")
print("====================================")

print(f"Original rows : {original_rows:,}")
print(f"Output rows   : {len(df):,}")
print(f"Columns       : {len(df.columns)}")
print(f"Duplicates    : {exact_duplicates:,}")

if "Year" in df.columns:
    print("\nYear distribution:")
    print(
        df["Year"]
        .value_counts()
        .sort_index()
    )

print("\nFiles created:")
print(OUTPUT_FILE)
print(PROFILE_FILE)