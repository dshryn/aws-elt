
"""
Local, zero-cost diagnostic for the FL_DATE column.

This script always runs against:
    flight_data.csv

Usage:
    python inspect_fl_date.py
"""

import csv
import re
from collections import Counter

# Fixed input file
path = "../output/flight_data.csv"

# Regex signatures for common date shapes
patterns = {
    "yyyy-MM-dd (2019-01-09)": re.compile(r"^\d{4}-\d{2}-\d{2}$"),
    "dd-MM-yyyy (09-01-2019)": re.compile(r"^\d{2}-\d{2}-\d{4}$"),
    "d-M-yyyy no padding (9-1-2019)": re.compile(r"^\d{1,2}-\d{1,2}-\d{4}$"),
    "yyyy/MM/dd": re.compile(r"^\d{4}/\d{2}/\d{2}$"),
    "MM/dd/yyyy": re.compile(r"^\d{2}/\d{2}/\d{4}$"),
    "blank/empty": re.compile(r"^\s*$"),
}

pattern_counts = Counter()
unmatched_samples = []
total_rows = 0

# ---------------------------------------------------------
# First pass: inspect FL_DATE patterns
# ---------------------------------------------------------

try:
    with open(
        path,
        "r",
        newline="",
        encoding="utf-8",
        errors="replace"
    ) as f:

        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames

        if fieldnames is None:
            print("CSV file is missing a header row or is empty.")
            raise SystemExit(1)

        if "FL_DATE" not in fieldnames:
            print("FL_DATE column not found.")
            print("Columns seen:")
            print(fieldnames)
            raise SystemExit(1)

        for row in reader:
            total_rows += 1

            val = (row.get("FL_DATE") or "").strip()

            matched = False

            for label, pattern in patterns.items():
                if pattern.match(val):
                    pattern_counts[label] += 1
                    matched = True
                    break

            if not matched:
                pattern_counts["OTHER/UNKNOWN"] += 1

                if len(unmatched_samples) < 20:
                    unmatched_samples.append(val)

except FileNotFoundError:
    print(f"ERROR: Could not find '{path}'.")
    raise SystemExit(1)


# ---------------------------------------------------------
# Print pattern breakdown
# ---------------------------------------------------------

print("=" * 50)
print(f"Rows scanned: {total_rows:,}")
print("=" * 50)

print("\nFL_DATE pattern breakdown:")

for label, count in pattern_counts.most_common():

    pct = (count / total_rows * 100) if total_rows else 0

    print(f"  {label:35s} {count:>10,}  ({pct:5.2f}%)")


# ---------------------------------------------------------
# Print unknown values
# ---------------------------------------------------------

if unmatched_samples:

    print("\nSample of UNKNOWN/unmatched raw values:")

    for value in unmatched_samples:
        print(f"  '{value}'")


# ---------------------------------------------------------
# Check dd-MM-yyyy vs MM-dd-yyyy
# ---------------------------------------------------------

print("\n" + "=" * 50)
print("Also checking day/month value ranges")
print("(to disambiguate dd-MM-yyyy vs MM-dd-yyyy when")
print(" both values are 2-digit)")
print("=" * 50)

first_part_over_12 = 0
second_part_over_12 = 0
both_le_12 = 0

with open(
    path,
    "r",
    newline="",
    encoding="utf-8",
    errors="replace"
) as f:

    reader = csv.DictReader(f)

    for row in reader:

        val = (row.get("FL_DATE") or "").strip()

        # Only inspect values in the form:
        # 09-01-2019
        # 19-01-2019
        m = re.match(
            r"^(\d{1,2})-(\d{1,2})-(\d{4})$",
            val
        )

        if not m:
            continue

        first = int(m.group(1))
        second = int(m.group(2))

        if first > 12:
            # Example: 19-01-2019
            # First number MUST be the day
            first_part_over_12 += 1

        elif second > 12:
            # Example: 01-19-2019
            # Second number MUST be the day
            second_part_over_12 += 1

        else:
            # Example: 09-01-2019
            # Could be either dd-MM or MM-dd
            both_le_12 += 1


print(
    f"Rows where FIRST number > 12 "
    f"(=> dd-MM-yyyy): {first_part_over_12:,}"
)

print(
    f"Rows where SECOND number > 12 "
    f"(=> MM-dd-yyyy): {second_part_over_12:,}"
)

print(
    f"Rows where both <= 12 "
    f"(ambiguous, either format works): {both_le_12:,}"
)

print("\n" + "=" * 50)
print("Diagnostic complete.")
print("=" * 50)

