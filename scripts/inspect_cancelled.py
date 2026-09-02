"""
Local, zero-cost diagnostic for the CANCELLED column.

Usage:
    python inspect_cancelled.py sample.csv
    python inspect_cancelled.py flight_data.csv   # full file if available
"""

import sys
import csv
from collections import Counter

if len(sys.argv) < 2:
    print("Usage: python inspect_cancelled.py <path_to_csv>")
    sys.exit(1)

path = sys.argv[1]

value_counts = Counter()
total_rows = 0
blank_or_missing = 0
sample_rows_with_issue = []

with open(path, "r", newline="", encoding="utf-8", errors="replace") as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames

    if fieldnames is None or "CANCELLED" not in fieldnames:
        print(f"CANCELLED column not found. Columns seen: {fieldnames}")
        sys.exit(1)

    for row in reader:
        total_rows += 1
        raw = row.get("CANCELLED")

        if raw is None:
            key = "<field missing entirely>"
        else:
            stripped = raw.strip()
            if stripped == "":
                key = "<empty string>"
            else:
                key = repr(stripped)  # keep quotes to catch whitespace/weird chars

        value_counts[key] += 1

        if key in ("<field missing entirely>", "<empty string>"):
            blank_or_missing += 1
            if len(sample_rows_with_issue) < 10:
                sample_rows_with_issue.append(row)

print("========================================")
print(f"Rows scanned: {total_rows:,}")
print("========================================")
print("\nCANCELLED distinct raw value counts:")
for key, count in value_counts.most_common(30):
    pct = (count / total_rows * 100) if total_rows else 0
    print(f"  {key:30s} {count:>10,}  ({pct:6.3f}%)")

print(f"\nBlank/missing CANCELLED total: {blank_or_missing:,}")

if sample_rows_with_issue:
    print("\nFull rows where CANCELLED is blank/missing (first 10):")
    for r in sample_rows_with_issue:
        print(r)