import pandas as pd

df = pd.read_csv(
    "../dataset/flight_data.csv",
    usecols=["FL_DATE"],
    dtype=str
)

print(df["FL_DATE"].head(20).to_list())

print("\nMost common raw date values:")
print(df["FL_DATE"].value_counts(dropna=False).head(20))