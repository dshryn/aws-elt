"""
Full local profiler — run this ONCE against the exact file you uploaded
to S3 (the cleaned CSV). Paste the ENTIRE output back. It gives everything
needed to write a Glue schema/script that matches this file exactly,
with zero guessing.

Usage:
    python profile_for_glue.py path/to/exact_uploaded_file.csv
"""

import sys
import csv
from collections import Counter, OrderedDict

if len(sys.argv) < 2:
    print("Usage: python profile_for_glue.py <path_to_csv>")
    sys.exit(1)

path = sys.argv[1]
SAMPLE_DISTINCT_LIMIT = 8   # how many distinct raw values to show per column
MAX_ROWS_FULL_SCAN = None   # None = scan everything

print("========================================")
print("STEP 1: HEADER")
print("========================================")

with open(path, "r", newline="", encoding="utf-8", errors="replace") as f:
    reader = csv.reader(f)
    header = next(reader)

print(f"Column count: {len(header)}")
print("Columns in exact order:")
for i, col_name in enumerate(header):
    print(f"  [{i}] '{col_name}'")

print("\n========================================")
print("STEP 2: FIRST 5 RAW ROWS (as Spark would see them)")
print("========================================")

with open(path, "r", newline="", encoding="utf-8", errors="replace") as f:
    reader = csv.DictReader(f)
    for i, row in enumerate(reader):
        if i >= 5:
            break
        print(f"\n--- Row {i} ---")
        for k, v in row.items():
            print(f"  {k} = {v!r}")

print("\n========================================")
print("STEP 3: FULL SCAN — per-column stats")
print("(null count, distinct sample, min/max length, numeric-ness)")
print("========================================")

col_null_count = Counter()
col_blank_count = Counter()
col_distinct_samples = {c: OrderedDict() for c in header}
col_min_len = {c: None for c in header}
col_max_len = {c: None for c in header}
col_all_numeric = {c: True for c in header}
col_all_int_like = {c: True for c in header}

total_rows = 0

with open(path, "r", newline="", encoding="utf-8", errors="replace") as f:
    reader = csv.DictReader(f)
    for row in reader:
        total_rows += 1
        for c in header:
            raw = row.get(c)

            if raw is None:
                col_null_count[c] += 1
                continue

            if raw == "":
                col_blank_count[c] += 1
                continue

            length = len(raw)
            if col_min_len[c] is None or length < col_min_len[c]:
                col_min_len[c] = length
            if col_max_len[c] is None or length > col_max_len[c]:
                col_max_len[c] = length

            if len(col_distinct_samples[c]) < SAMPLE_DISTINCT_LIMIT:
                col_distinct_samples[c][raw] = True

            # numeric checks
            try:
                float(raw)
            except ValueError:
                col_all_numeric[c] = False

            if not (raw.lstrip("-").isdigit()):
                col_all_int_like[c] = False

        if MAX_ROWS_FULL_SCAN and total_rows >= MAX_ROWS_FULL_SCAN:
            break

print(f"\nTotal rows scanned: {total_rows:,}\n")

for c in header:
    nulls = col_null_count[c]
    blanks = col_blank_count[c]
    print(f"Column: {c}")
    print(f"  nulls (missing field): {nulls:,}")
    print(f"  blanks (empty string): {blanks:,}")
    print(f"  min/max length (non-empty): {col_min_len[c]} / {col_max_len[c]}")
    print(f"  all values numeric (float-castable): {col_all_numeric[c]}")
    print(f"  all values int-like (no decimal): {col_all_int_like[c]}")
    print(f"  sample distinct raw values: {list(col_distinct_samples[c].keys())}")
    print()

print("========================================")
print("STEP 4: FL_DATE-specific check (if present)")
print("========================================")

if "FL_DATE" in header:
    date_patterns = Counter()
    with open(path, "r", newline="", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        for row in reader:
            v = (row.get("FL_DATE") or "").strip()
            date_patterns[v[:4] if len(v) >= 4 else v] += 0  # placeholder, real check below

    # simpler: just show length distribution and first-char distribution
    length_counter = Counter()
    with open(path, "r", newline="", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        for row in reader:
            v = (row.get("FL_DATE") or "").strip()
            length_counter[len(v)] += 1
    print("FL_DATE string length distribution:")
    for length, count in sorted(length_counter.items()):
        print(f"  length={length}: {count:,} rows")
else:
    print("FL_DATE column not found in this file.")

print("\n========================================")
print("STEP 5: CANCELLED-specific check (if present)")
print("========================================")

if "CANCELLED" in header:
    cc = Counter()
    with open(path, "r", newline="", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        for row in reader:
            raw = row.get("CANCELLED")
            key = "<missing>" if raw is None else (f"'{raw.strip()}'" if raw.strip() != "" else "<blank>")
            cc[key] += 1
    print("CANCELLED distinct raw values:")
    for k, v in cc.most_common(20):
        print(f"  {k}: {v:,}")
else:
    print("CANCELLED column not found in this file.")

print("\n========================================")
print("PROFILE COMPLETE — paste this entire output back")
print("========================================")