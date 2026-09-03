-- ================================================================
-- GOLD ETL VALIDATION & RECONCILIATION QUERIES
-- Project: AWS Flight Delay Analytics Pipeline
-- Purpose: GitHub documentation for validating the Gold layer
--
-- IMPORTANT:
--   1. These queries are DOCUMENTATION ONLY. They are not being run
--      automatically by this file.
--   2. Replace <SILVER_DATABASE>.<SILVER_TABLE> with the actual
--      Glue Catalog database/table name for Silver before execution.
--   3. Gold database/tables are fixed:
--        flight_gold_db.airline_summary
--        flight_gold_db.airport_summary
--        flight_gold_db.route_monthly_summary
--   4. Gold is partitioned by Year + Month.
--   5. Prefer testing one Year/Month partition first to minimize Athena
--      data scanned and therefore minimize cost.
--
-- EXPECTED RESULT CONVENTION:
--   - "Expected: 0" means the validation should return zero violations.
--   - "Expected: MATCH" means the compared values should be identical.
--   - Exact row counts are intentionally not hard-coded because they
--     should be obtained from the actual deployed dataset.
-- ================================================================
-- ================================================================
-- 0. GOLD TABLE DISCOVERY / BASIC INSPECTION
-- ================================================================
-- Show the three Gold tables registered in the Glue Data Catalog.
-- Expected: airline_summary, airport_summary, route_monthly_summary.
SHOW TABLES IN flight_gold_db;
-- Inspect the schema of each Gold table.
-- Expected:
--   - Business columns match the finalized Gold design.
--   - Year and Month appear as partition columns.
DESCRIBE flight_gold_db.airline_summary;
DESCRIBE flight_gold_db.airport_summary;
DESCRIBE flight_gold_db.route_monthly_summary;
-- ================================================================
-- 1. BASIC GOLD DATA PREVIEW
-- ================================================================
-- Basic sample from airline_summary.
-- Expected: rows are returned and contain valid airline/month
-- aggregates.
SELECT *
FROM flight_gold_db.airline_summary
LIMIT 10;
-- Basic sample from airport_summary.
-- Expected: AIRPORT_ROLE contains the expected role values
-- (ORIGIN / DESTINATION) and rows contain aggregate metrics.
SELECT *
FROM flight_gold_db.airport_summary
LIMIT 10;
-- Basic sample from route_monthly_summary.
-- Expected: rows contain ORIGIN, DEST, Year, Month and route metrics.
SELECT *
FROM flight_gold_db.route_monthly_summary
LIMIT 10;
-- ================================================================
-- 2. GOLD ROW COUNTS
-- ================================================================
-- These are documentation/inspection queries.
-- Exact values depend on the actual Gold output.
SELECT COUNT(*) AS airline_summary_rows
FROM flight_gold_db.airline_summary;
SELECT COUNT(*) AS airport_summary_rows
FROM flight_gold_db.airport_summary;
SELECT COUNT(*) AS route_monthly_summary_rows
FROM flight_gold_db.route_monthly_summary;
-- ================================================================
-- 3. GOLD GRAIN VALIDATION
-- ================================================================
-- ------------------------------------------------
-- 3A. airline_summary grain
-- Grain:
--   AIRLINE + Year + Month
--
-- Expected:
--   total_rows = distinct_grains
--   OR equivalently, duplicate_grains = 0.
-- ------------------------------------------------
SELECT COUNT(*) AS total_rows,
    COUNT(
        DISTINCT CONCAT(
            CAST(AIRLINE AS VARCHAR),
            '|',
            CAST(Year AS VARCHAR),
            '|',
            CAST(Month AS VARCHAR)
        )
    ) AS distinct_grains,
    COUNT(*) - COUNT(
        DISTINCT CONCAT(
            CAST(AIRLINE AS VARCHAR),
            '|',
            CAST(Year AS VARCHAR),
            '|',
            CAST(Month AS VARCHAR)
        )
    ) AS duplicate_grains
FROM flight_gold_db.airline_summary;
-- Direct duplicate search.
-- Expected: 0 rows.
SELECT AIRLINE,
    Year,
    Month,
    COUNT(*) AS row_count
FROM flight_gold_db.airline_summary
GROUP BY AIRLINE,
    Year,
    Month
HAVING COUNT(*) > 1
ORDER BY row_count DESC;
-- ------------------------------------------------
-- 3B. airport_summary grain
-- Grain:
--   AIRPORT + AIRPORT_ROLE + Year + Month
--
-- Expected:
--   duplicate_grains = 0.
-- ------------------------------------------------
SELECT COUNT(*) AS total_rows,
    COUNT(
        DISTINCT CONCAT(
            CAST(AIRPORT AS VARCHAR),
            '|',
            CAST(AIRPORT_ROLE AS VARCHAR),
            '|',
            CAST(Year AS VARCHAR),
            '|',
            CAST(Month AS VARCHAR)
        )
    ) AS distinct_grains,
    COUNT(*) - COUNT(
        DISTINCT CONCAT(
            CAST(AIRPORT AS VARCHAR),
            '|',
            CAST(AIRPORT_ROLE AS VARCHAR),
            '|',
            CAST(Year AS VARCHAR),
            '|',
            CAST(Month AS VARCHAR)
        )
    ) AS duplicate_grains
FROM flight_gold_db.airport_summary;
SELECT AIRPORT,
    AIRPORT_ROLE,
    Year,
    Month,
    COUNT(*) AS row_count
FROM flight_gold_db.airport_summary
GROUP BY AIRPORT,
    AIRPORT_ROLE,
    Year,
    Month
HAVING COUNT(*) > 1
ORDER BY row_count DESC;
-- ------------------------------------------------
-- 3C. route_monthly_summary grain
-- Grain:
--   ORIGIN + DEST + Year + Month
--
-- Expected:
--   duplicate_grains = 0.
-- ------------------------------------------------
SELECT COUNT(*) AS total_rows,
    COUNT(
        DISTINCT CONCAT(
            CAST(ORIGIN AS VARCHAR),
            '|',
            CAST(DEST AS VARCHAR),
            '|',
            CAST(Year AS VARCHAR),
            '|',
            CAST(Month AS VARCHAR)
        )
    ) AS distinct_grains,
    COUNT(*) - COUNT(
        DISTINCT CONCAT(
            CAST(ORIGIN AS VARCHAR),
            '|',
            CAST(DEST AS VARCHAR),
            '|',
            CAST(Year AS VARCHAR),
            '|',
            CAST(Month AS VARCHAR)
        )
    ) AS duplicate_grains
FROM flight_gold_db.route_monthly_summary;
SELECT ORIGIN,
    DEST,
    Year,
    Month,
    COUNT(*) AS row_count
FROM flight_gold_db.route_monthly_summary
GROUP BY ORIGIN,
    DEST,
    Year,
    Month
HAVING COUNT(*) > 1
ORDER BY row_count DESC;
-- ================================================================
-- 4. PARTITION VALIDATION
-- ================================================================
-- List all Year/Month combinations present in Gold.
-- Expected:
--   Only partitions that actually exist should appear.
--   Do NOT assume 5 x 12 = 60 partitions per table.
--   The crawler reported 168 partition changes across the three
--   tables, so actual discovered partitions should be verified.
SELECT Year,
    Month,
    COUNT(*) AS rows_in_partition
FROM flight_gold_db.airline_summary
GROUP BY Year,
    Month
ORDER BY Year,
    Month;
SELECT Year,
    Month,
    COUNT(*) AS rows_in_partition
FROM flight_gold_db.airport_summary
GROUP BY Year,
    Month
ORDER BY Year,
    Month;
SELECT Year,
    Month,
    COUNT(*) AS rows_in_partition
FROM flight_gold_db.route_monthly_summary
GROUP BY Year,
    Month
ORDER BY Year,
    Month;
-- Validate Year range.
-- Expected: values should fall within the project's source years:
-- 2019, 2020, 2021, 2022, 2023.
SELECT DISTINCT Year
FROM flight_gold_db.airline_summary
ORDER BY Year;
-- Validate Month values.
-- Expected: 1 through 12 for months that are present.
SELECT DISTINCT Month
FROM flight_gold_db.airline_summary
ORDER BY Month;
-- ================================================================
-- 5. GOLD VALUE / DATA-QUALITY VALIDATION
-- ================================================================
-- Check for unexpected NULLs in key grouping columns.
-- Expected: 0 rows.
SELECT COUNT(*) AS invalid_key_rows
FROM flight_gold_db.airline_summary
WHERE AIRLINE IS NULL
    OR Year IS NULL
    OR Month IS NULL;
SELECT COUNT(*) AS invalid_key_rows
FROM flight_gold_db.airport_summary
WHERE AIRPORT IS NULL
    OR AIRPORT_ROLE IS NULL
    OR Year IS NULL
    OR Month IS NULL;
SELECT COUNT(*) AS invalid_key_rows
FROM flight_gold_db.route_monthly_summary
WHERE ORIGIN IS NULL
    OR DEST IS NULL
    OR Year IS NULL
    OR Month IS NULL;
-- Check airport roles.
-- Expected: only ORIGIN and DESTINATION.
SELECT DISTINCT AIRPORT_ROLE
FROM flight_gold_db.airport_summary
ORDER BY AIRPORT_ROLE;
-- Check that counts are not negative.
-- Expected: 0 rows.
SELECT *
FROM flight_gold_db.airline_summary
WHERE TOTAL_FLIGHTS < 0
    OR DELAYED_DEPARTURES < 0
    OR DELAYED_ARRIVALS < 0
    OR CANCELLED_FLIGHTS < 0
    OR DIVERTED_FLIGHTS < 0;
SELECT *
FROM flight_gold_db.airport_summary
WHERE TOTAL_FLIGHTS < 0
    OR DELAYED_FLIGHTS < 0
    OR CANCELLED_FLIGHTS < 0
    OR DIVERTED_FLIGHTS < 0;
SELECT *
FROM flight_gold_db.route_monthly_summary
WHERE TOTAL_FLIGHTS < 0
    OR DELAYED_DEPARTURES < 0
    OR DELAYED_ARRIVALS < 0
    OR CANCELLED_FLIGHTS < 0
    OR DIVERTED_FLIGHTS < 0;
-- Check rate bounds.
-- Expected: 0 <= rate <= 1, with no violations.
SELECT *
FROM flight_gold_db.airline_summary
WHERE DEPARTURE_DELAY_RATE < 0
    OR DEPARTURE_DELAY_RATE > 1
    OR ARRIVAL_DELAY_RATE < 0
    OR ARRIVAL_DELAY_RATE > 1
    OR CANCELLATION_RATE < 0
    OR CANCELLATION_RATE > 1;
SELECT *
FROM flight_gold_db.airport_summary
WHERE DELAY_RATE < 0
    OR DELAY_RATE > 1;
SELECT *
FROM flight_gold_db.route_monthly_summary
WHERE DEPARTURE_DELAY_RATE < 0
    OR DEPARTURE_DELAY_RATE > 1
    OR ARRIVAL_DELAY_RATE < 0
    OR ARRIVAL_DELAY_RATE > 1;
-- Check count relationships.
-- Expected: no delayed/cancelled/diverted count exceeds total flights.
SELECT *
FROM flight_gold_db.airline_summary
WHERE DELAYED_DEPARTURES > TOTAL_FLIGHTS
    OR DELAYED_ARRIVALS > TOTAL_FLIGHTS
    OR CANCELLED_FLIGHTS > TOTAL_FLIGHTS
    OR DIVERTED_FLIGHTS > TOTAL_FLIGHTS;
SELECT *
FROM flight_gold_db.airport_summary
WHERE DELAYED_FLIGHTS > TOTAL_FLIGHTS
    OR CANCELLED_FLIGHTS > TOTAL_FLIGHTS
    OR DIVERTED_FLIGHTS > TOTAL_FLIGHTS;
SELECT *
FROM flight_gold_db.route_monthly_summary
WHERE DELAYED_DEPARTURES > TOTAL_FLIGHTS
    OR DELAYED_ARRIVALS > TOTAL_FLIGHTS
    OR CANCELLED_FLIGHTS > TOTAL_FLIGHTS
    OR DIVERTED_FLIGHTS > TOTAL_FLIGHTS;
-- ================================================================
-- 6. SILVER -> GOLD TOTAL FLIGHT RECONCILIATION
-- ================================================================
--
-- IMPORTANT:
-- These queries require the actual Silver Catalog table name.
--
-- Replace:
--   <SILVER_DATABASE>.<SILVER_TABLE>
--
-- with the real Silver table.
--
-- COST CONTROL:
-- Start with ONE partition, for example Year=2023, Month=1.
-- Once that matches, test a few additional partitions.
-- ================================================================
-- ------------------------------------------------
-- 6A. Silver flight count for one partition
-- ------------------------------------------------
SELECT Year,
    Month,
    COUNT(*) AS silver_flights
FROM < SILVER_DATABASE >.< SILVER_TABLE >
WHERE Year = 2023
    AND Month = 1
GROUP BY Year,
    Month;
-- ------------------------------------------------
-- 6B. Gold airline total for the same partition
--
-- Expected:
--   gold_flights = silver_flights
-- ------------------------------------------------
SELECT Year,
    Month,
    SUM(TOTAL_FLIGHTS) AS gold_flights
FROM flight_gold_db.airline_summary
WHERE Year = 2023
    AND Month = 1
GROUP BY Year,
    Month;
-- ------------------------------------------------
-- 6C. Gold route total for the same partition
--
-- Expected:
--   route_gold_flights = silver_flights
-- ------------------------------------------------
SELECT Year,
    Month,
    SUM(TOTAL_FLIGHTS) AS route_gold_flights
FROM flight_gold_db.route_monthly_summary
WHERE Year = 2023
    AND Month = 1
GROUP BY Year,
    Month;
-- ================================================================
-- 7. SILVER -> GOLD RECONCILIATION IN ONE QUERY
-- ================================================================
--
-- This gives a direct PASS/FAIL result for a selected partition.
-- Expected:
--   status = PASS
--   silver_flights = airline_gold_flights = route_gold_flights
--
-- Replace the Silver table name before execution.
-- ================================================================
WITH silver AS (
    SELECT COUNT(*) AS silver_flights
    FROM < SILVER_DATABASE >.< SILVER_TABLE >
    WHERE Year = 2023
        AND Month = 1
),
airline_gold AS (
    SELECT SUM(TOTAL_FLIGHTS) AS airline_gold_flights
    FROM flight_gold_db.airline_summary
    WHERE Year = 2023
        AND Month = 1
),
route_gold AS (
    SELECT SUM(TOTAL_FLIGHTS) AS route_gold_flights
    FROM flight_gold_db.route_monthly_summary
    WHERE Year = 2023
        AND Month = 1
)
SELECT silver.silver_flights,
    airline_gold.airline_gold_flights,
    route_gold.route_gold_flights,
    CASE
        WHEN silver.silver_flights = airline_gold.airline_gold_flights
        AND silver.silver_flights = route_gold.route_gold_flights THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM silver
    CROSS JOIN airline_gold
    CROSS JOIN route_gold;
-- ================================================================
-- 8. AIRLINE METRIC RECONCILIATION
-- ================================================================
--
-- Validate the Gold airline metrics directly against Silver for one
-- Year/Month partition.
--
-- Expected:
--   For every airline:
--     TOTAL_FLIGHTS matches
--     DELAYED_DEPARTURES matches
--     DELAYED_ARRIVALS matches
--     CANCELLED_FLIGHTS matches
--     DIVERTED_FLIGHTS matches
--
-- This is a stronger test than simply comparing total row counts.
-- ================================================================
WITH silver_agg AS (
    SELECT AIRLINE,
        Year,
        Month,
        COUNT(*) AS silver_total_flights,
        SUM(
            CASE
                WHEN DEP_DELAY > 0 THEN 1
                ELSE 0
            END
        ) AS silver_delayed_departures,
        SUM(
            CASE
                WHEN ARR_DELAY > 0 THEN 1
                ELSE 0
            END
        ) AS silver_delayed_arrivals,
        SUM(
            CASE
                WHEN CANCELLED = 1 THEN 1
                ELSE 0
            END
        ) AS silver_cancelled_flights,
        SUM(
            CASE
                WHEN DIVERTED = 1 THEN 1
                ELSE 0
            END
        ) AS silver_diverted_flights
    FROM < SILVER_DATABASE >.< SILVER_TABLE >
    WHERE Year = 2023
        AND Month = 1
    GROUP BY AIRLINE,
        Year,
        Month
),
gold_agg AS (
    SELECT AIRLINE,
        Year,
        Month,
        TOTAL_FLIGHTS,
        DELAYED_DEPARTURES,
        DELAYED_ARRIVALS,
        CANCELLED_FLIGHTS,
        DIVERTED_FLIGHTS
    FROM flight_gold_db.airline_summary
    WHERE Year = 2023
        AND Month = 1
)
SELECT COALESCE(s.AIRLINE, g.AIRLINE) AS AIRLINE,
    COALESCE(s.Year, g.Year) AS Year,
    COALESCE(s.Month, g.Month) AS Month,
    s.silver_total_flights,
    g.TOTAL_FLIGHTS AS gold_total_flights,
    s.silver_delayed_departures,
    g.DELAYED_DEPARTURES AS gold_delayed_departures,
    s.silver_delayed_arrivals,
    g.DELAYED_ARRIVALS AS gold_delayed_arrivals,
    s.silver_cancelled_flights,
    g.CANCELLED_FLIGHTS AS gold_cancelled_flights,
    s.silver_diverted_flights,
    g.DIVERTED_FLIGHTS AS gold_diverted_flights
FROM silver_agg s
    FULL OUTER JOIN gold_agg g ON s.AIRLINE = g.AIRLINE
    AND s.Year = g.Year
    AND s.Month = g.Month
WHERE s.silver_total_flights IS NULL
    OR g.TOTAL_FLIGHTS IS NULL
    OR s.silver_total_flights <> g.TOTAL_FLIGHTS
    OR s.silver_delayed_departures <> g.DELAYED_DEPARTURES
    OR s.silver_delayed_arrivals <> g.DELAYED_ARRIVALS
    OR s.silver_cancelled_flights <> g.CANCELLED_FLIGHTS
    OR s.silver_diverted_flights <> g.DIVERTED_FLIGHTS
ORDER BY AIRLINE;
-- Expected:
--   0 rows.
--
-- Any returned row indicates a discrepancy requiring investigation.
-- ================================================================
-- 9. AIRLINE RATE RECONCILIATION
-- ================================================================
--
-- Do NOT validate rates by averaging flight-level rates.
-- Rates should be derived from aggregate counts.
--
-- Expected:
--   Gold rates match:
--     delayed departures / total flights
--     delayed arrivals / total flights
--     cancelled flights / total flights
-- ================================================================
SELECT AIRLINE,
    Year,
    Month,
    DELAYED_DEPARTURES * 1.0 / NULLIF(TOTAL_FLIGHTS, 0) AS expected_departure_delay_rate,
    DEPARTURE_DELAY_RATE AS gold_departure_delay_rate,
    DELAYED_ARRIVALS * 1.0 / NULLIF(TOTAL_FLIGHTS, 0) AS expected_arrival_delay_rate,
    ARRIVAL_DELAY_RATE AS gold_arrival_delay_rate,
    CANCELLED_FLIGHTS * 1.0 / NULLIF(TOTAL_FLIGHTS, 0) AS expected_cancellation_rate,
    CANCELLATION_RATE AS gold_cancellation_rate
FROM flight_gold_db.airline_summary
WHERE ABS(
        DEPARTURE_DELAY_RATE - DELAYED_DEPARTURES * 1.0 / NULLIF(TOTAL_FLIGHTS, 0)
    ) > 0.0000001
    OR ABS(
        ARRIVAL_DELAY_RATE - DELAYED_ARRIVALS * 1.0 / NULLIF(TOTAL_FLIGHTS, 0)
    ) > 0.0000001
    OR ABS(
        CANCELLATION_RATE - CANCELLED_FLIGHTS * 1.0 / NULLIF(TOTAL_FLIGHTS, 0)
    ) > 0.0000001;
-- Expected: 0 rows.
-- ================================================================
-- 10. AIRPORT ORIGIN/DESTINATION RECONCILIATION
-- ================================================================
--
-- This validates the special airport design:
--
--   AIRPORT_ROLE = ORIGIN
--       AIRPORT = ORIGIN
--       delay metric = DEP_DELAY
--
--   AIRPORT_ROLE = DESTINATION
--       AIRPORT = DEST
--       delay metric = ARR_DELAY
--
-- Test one partition first.
-- Expected: 0 discrepancy rows.
-- ================================================================
WITH origin_silver AS (
    SELECT ORIGIN AS AIRPORT,
        'ORIGIN' AS AIRPORT_ROLE,
        Year,
        Month,
        COUNT(*) AS total_flights,
        SUM(
            CASE
                WHEN DEP_DELAY > 0 THEN 1
                ELSE 0
            END
        ) AS delayed_flights,
        SUM(
            CASE
                WHEN CANCELLED = 1 THEN 1
                ELSE 0
            END
        ) AS cancelled_flights,
        SUM(
            CASE
                WHEN DIVERTED = 1 THEN 1
                ELSE 0
            END
        ) AS diverted_flights,
        AVG(DEP_DELAY) AS avg_delay,
        SUM(DEP_DELAY) AS total_delay_minutes
    FROM < SILVER_DATABASE >.< SILVER_TABLE >
    WHERE Year = 2023
        AND Month = 1
    GROUP BY ORIGIN,
        Year,
        Month
),
destination_silver AS (
    SELECT DEST AS AIRPORT,
        'DESTINATION' AS AIRPORT_ROLE,
        Year,
        Month,
        COUNT(*) AS total_flights,
        SUM(
            CASE
                WHEN ARR_DELAY > 0 THEN 1
                ELSE 0
            END
        ) AS delayed_flights,
        SUM(
            CASE
                WHEN CANCELLED = 1 THEN 1
                ELSE 0
            END
        ) AS cancelled_flights,
        SUM(
            CASE
                WHEN DIVERTED = 1 THEN 1
                ELSE 0
            END
        ) AS diverted_flights,
        AVG(ARR_DELAY) AS avg_delay,
        SUM(ARR_DELAY) AS total_delay_minutes
    FROM < SILVER_DATABASE >.< SILVER_TABLE >
    WHERE Year = 2023
        AND Month = 1
    GROUP BY DEST,
        Year,
        Month
),
silver_agg AS (
    SELECT *
    FROM origin_silver
    UNION ALL
    SELECT *
    FROM destination_silver
),
gold_agg AS (
    SELECT AIRPORT,
        AIRPORT_ROLE,
        Year,
        Month,
        TOTAL_FLIGHTS,
        DELAYED_FLIGHTS,
        CANCELLED_FLIGHTS,
        DIVERTED_FLIGHTS,
        AVG_DELAY,
        TOTAL_DELAY_MINUTES
    FROM flight_gold_db.airport_summary
    WHERE Year = 2023
        AND Month = 1
)
SELECT COALESCE(s.AIRPORT, g.AIRPORT) AS AIRPORT,
    COALESCE(s.AIRPORT_ROLE, g.AIRPORT_ROLE) AS AIRPORT_ROLE,
    COALESCE(s.Year, g.Year) AS Year,
    COALESCE(s.Month, g.Month) AS Month,
    s.total_flights AS silver_total_flights,
    g.TOTAL_FLIGHTS AS gold_total_flights,
    s.delayed_flights AS silver_delayed_flights,
    g.DELAYED_FLIGHTS AS gold_delayed_flights,
    s.cancelled_flights AS silver_cancelled_flights,
    g.CANCELLED_FLIGHTS AS gold_cancelled_flights,
    s.diverted_flights AS silver_diverted_flights,
    g.DIVERTED_FLIGHTS AS gold_diverted_flights,
    s.avg_delay AS silver_avg_delay,
    g.AVG_DELAY AS gold_avg_delay,
    s.total_delay_minutes AS silver_total_delay_minutes,
    g.TOTAL_DELAY_MINUTES AS gold_total_delay_minutes
FROM silver_agg s
    FULL OUTER JOIN gold_agg g ON s.AIRPORT = g.AIRPORT
    AND s.AIRPORT_ROLE = g.AIRPORT_ROLE
    AND s.Year = g.Year
    AND s.Month = g.Month
WHERE s.total_flights IS NULL
    OR g.TOTAL_FLIGHTS IS NULL
    OR s.total_flights <> g.TOTAL_FLIGHTS
    OR s.delayed_flights <> g.DELAYED_FLIGHTS
    OR s.cancelled_flights <> g.CANCELLED_FLIGHTS
    OR s.diverted_flights <> g.DIVERTED_FLIGHTS
    OR ABS(
        COALESCE(s.avg_delay, 0) - COALESCE(g.AVG_DELAY, 0)
    ) > 0.000001
    OR ABS(
        COALESCE(s.total_delay_minutes, 0) - COALESCE(g.TOTAL_DELAY_MINUTES, 0)
    ) > 0.000001
ORDER BY AIRPORT_ROLE,
    AIRPORT;
-- ================================================================
-- 11. ROUTE RECONCILIATION
-- ================================================================
--
-- Validates:
--   ORIGIN + DEST + Year + Month
--
-- Expected: 0 discrepancy rows.
-- ================================================================
WITH silver_agg AS (
    SELECT ORIGIN,
        DEST,
        Year,
        Month,
        COUNT(*) AS total_flights,
        SUM(
            CASE
                WHEN DEP_DELAY > 0 THEN 1
                ELSE 0
            END
        ) AS delayed_departures,
        SUM(
            CASE
                WHEN ARR_DELAY > 0 THEN 1
                ELSE 0
            END
        ) AS delayed_arrivals,
        SUM(
            CASE
                WHEN CANCELLED = 1 THEN 1
                ELSE 0
            END
        ) AS cancelled_flights,
        SUM(
            CASE
                WHEN DIVERTED = 1 THEN 1
                ELSE 0
            END
        ) AS diverted_flights,
        AVG(DEP_DELAY) AS avg_dep_delay,
        AVG(ARR_DELAY) AS avg_arr_delay,
        SUM(DISTANCE) AS total_distance,
        AVG(DISTANCE) AS avg_distance
    FROM < SILVER_DATABASE >.< SILVER_TABLE >
    WHERE Year = 2023
        AND Month = 1
    GROUP BY ORIGIN,
        DEST,
        Year,
        Month
),
gold_agg AS (
    SELECT ORIGIN,
        DEST,
        Year,
        Month,
        TOTAL_FLIGHTS,
        DELAYED_DEPARTURES,
        DELAYED_ARRIVALS,
        CANCELLED_FLIGHTS,
        DIVERTED_FLIGHTS,
        AVG_DEP_DELAY,
        AVG_ARR_DELAY,
        TOTAL_DISTANCE,
        AVG_DISTANCE
    FROM flight_gold_db.route_monthly_summary
    WHERE Year = 2023
        AND Month = 1
)
SELECT COALESCE(s.ORIGIN, g.ORIGIN) AS ORIGIN,
    COALESCE(s.DEST, g.DEST) AS DEST,
    COALESCE(s.Year, g.Year) AS Year,
    COALESCE(s.Month, g.Month) AS Month,
    s.total_flights AS silver_total_flights,
    g.TOTAL_FLIGHTS AS gold_total_flights,
    s.delayed_departures AS silver_delayed_departures,
    g.DELAYED_DEPARTURES AS gold_delayed_departures,
    s.delayed_arrivals AS silver_delayed_arrivals,
    g.DELAYED_ARRIVALS AS gold_delayed_arrivals,
    s.cancelled_flights AS silver_cancelled_flights,
    g.CANCELLED_FLIGHTS AS gold_cancelled_flights,
    s.diverted_flights AS silver_diverted_flights,
    g.DIVERTED_FLIGHTS AS gold_diverted_flights
FROM silver_agg s
    FULL OUTER JOIN gold_agg g ON s.ORIGIN = g.ORIGIN
    AND s.DEST = g.DEST
    AND s.Year = g.Year
    AND s.Month = g.Month
WHERE s.total_flights IS NULL
    OR g.TOTAL_FLIGHTS IS NULL
    OR s.total_flights <> g.TOTAL_FLIGHTS
    OR s.delayed_departures <> g.DELAYED_DEPARTURES
    OR s.delayed_arrivals <> g.DELAYED_ARRIVALS
    OR s.cancelled_flights <> g.CANCELLED_FLIGHTS
    OR s.diverted_flights <> g.DIVERTED_FLIGHTS
ORDER BY ORIGIN,
    DEST;
-- ================================================================
-- 12. DELAY-CAUSE RECONCILIATION FOR AIRLINE SUMMARY
-- ================================================================
--
-- These fields are summed from the Silver delay-cause columns.
-- NULL source values are not globally converted to zero.
--
-- Expected: 0 discrepancy rows.
--
-- Test one partition first.
-- ================================================================
WITH silver_agg AS (
    SELECT AIRLINE,
        Year,
        Month,
        SUM(DELAY_DUE_CARRIER) AS carrier_delay,
        SUM(DELAY_DUE_WEATHER) AS weather_delay,
        SUM(DELAY_DUE_NAS) AS nas_delay,
        SUM(DELAY_DUE_SECURITY) AS security_delay,
        SUM(DELAY_DUE_LATE_AIRCRAFT) AS late_aircraft_delay
    FROM < SILVER_DATABASE >.< SILVER_TABLE >
    WHERE Year = 2023
        AND Month = 1
    GROUP BY AIRLINE,
        Year,
        Month
),
gold_agg AS (
    SELECT AIRLINE,
        Year,
        Month,
        TOTAL_CARRIER_DELAY,
        TOTAL_WEATHER_DELAY,
        TOTAL_NAS_DELAY,
        TOTAL_SECURITY_DELAY,
        TOTAL_LATE_AIRCRAFT_DELAY
    FROM flight_gold_db.airline_summary
    WHERE Year = 2023
        AND Month = 1
)
SELECT COALESCE(s.AIRLINE, g.AIRLINE) AS AIRLINE,
    s.carrier_delay,
    g.TOTAL_CARRIER_DELAY,
    s.weather_delay,
    g.TOTAL_WEATHER_DELAY,
    s.nas_delay,
    g.TOTAL_NAS_DELAY,
    s.security_delay,
    g.TOTAL_SECURITY_DELAY,
    s.late_aircraft_delay,
    g.TOTAL_LATE_AIRCRAFT_DELAY
FROM silver_agg s
    FULL OUTER JOIN gold_agg g ON s.AIRLINE = g.AIRLINE
    AND s.Year = g.Year
    AND s.Month = g.Month
WHERE NOT (
        (
            s.carrier_delay = g.TOTAL_CARRIER_DELAY
            OR (
                s.carrier_delay IS NULL
                AND g.TOTAL_CARRIER_DELAY IS NULL
            )
        )
        AND (
            s.weather_delay = g.TOTAL_WEATHER_DELAY
            OR (
                s.weather_delay IS NULL
                AND g.TOTAL_WEATHER_DELAY IS NULL
            )
        )
        AND (
            s.nas_delay = g.TOTAL_NAS_DELAY
            OR (
                s.nas_delay IS NULL
                AND g.TOTAL_NAS_DELAY IS NULL
            )
        )
        AND (
            s.security_delay = g.TOTAL_SECURITY_DELAY
            OR (
                s.security_delay IS NULL
                AND g.TOTAL_SECURITY_DELAY IS NULL
            )
        )
        AND (
            s.late_aircraft_delay = g.TOTAL_LATE_AIRCRAFT_DELAY
            OR (
                s.late_aircraft_delay IS NULL
                AND g.TOTAL_LATE_AIRCRAFT_DELAY IS NULL
            )
        )
    )
ORDER BY AIRLINE;
-- ================================================================
-- 13. AVERAGE DELAY RECONCILIATION
-- ================================================================
--
-- Floating-point values should be compared with a small tolerance,
-- not necessarily exact string/numeric equality.
--
-- Expected: 0 discrepancy rows.
-- ================================================================
WITH silver_agg AS (
    SELECT AIRLINE,
        Year,
        Month,
        AVG(DEP_DELAY) AS avg_dep_delay,
        AVG(ARR_DELAY) AS avg_arr_delay
    FROM < SILVER_DATABASE >.< SILVER_TABLE >
    WHERE Year = 2023
        AND Month = 1
    GROUP BY AIRLINE,
        Year,
        Month
)
SELECT s.AIRLINE,
    s.Year,
    s.Month,
    s.avg_dep_delay AS silver_avg_dep_delay,
    g.AVG_DEP_DELAY AS gold_avg_dep_delay,
    s.avg_arr_delay AS silver_avg_arr_delay,
    g.AVG_ARR_DELAY AS gold_avg_arr_delay
FROM silver_agg s
    JOIN flight_gold_db.airline_summary g ON s.AIRLINE = g.AIRLINE
    AND s.Year = g.Year
    AND s.Month = g.Month
WHERE ABS(
        COALESCE(s.avg_dep_delay, 0) - COALESCE(g.AVG_DEP_DELAY, 0)
    ) > 0.000001
    OR ABS(
        COALESCE(s.avg_arr_delay, 0) - COALESCE(g.AVG_ARR_DELAY, 0)
    ) > 0.000001
ORDER BY s.AIRLINE;
-- ================================================================
-- 14. CANCELLATION / DIVERSION RECONCILIATION
-- ================================================================
-- Overall Gold totals by month.
-- Expected: useful for sanity checking trends; exact values should
-- reconcile with Silver when checked for the same partition.
SELECT Year,
    Month,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(CANCELLED_FLIGHTS) AS cancelled_flights,
    SUM(DIVERTED_FLIGHTS) AS diverted_flights
FROM flight_gold_db.airline_summary
GROUP BY Year,
    Month
ORDER BY Year,
    Month;
-- ================================================================
-- 15. ROUTE SANITY CHECKS
-- ================================================================
-- Find the busiest routes.
-- Expected: non-empty results.
SELECT ORIGIN,
    DEST,
    SUM(TOTAL_FLIGHTS) AS total_flights
FROM flight_gold_db.route_monthly_summary
GROUP BY ORIGIN,
    DEST
ORDER BY total_flights DESC
LIMIT 20;
-- Find routes with the highest average arrival delay.
--
-- IMPORTANT:
-- Do not simply AVG(AVG_ARR_DELAY) across months if an overall
-- weighted average is required. This query is only a dashboard/
-- exploratory ranking of the stored monthly aggregates.
--
-- For an exact overall metric, calculate from underlying counts or
-- Silver data.
SELECT ORIGIN,
    DEST,
    AVG(AVG_ARR_DELAY) AS average_of_monthly_arrival_delays
FROM flight_gold_db.route_monthly_summary
GROUP BY ORIGIN,
    DEST
ORDER BY average_of_monthly_arrival_delays DESC
LIMIT 20;
-- ================================================================
-- 16. PARTITION PRUNING / COST-AWARE QUERY EXAMPLE
-- ================================================================
--
-- Always prefer a Year + Month filter when the analysis permits it.
--
-- This is an example of a partition-pruned query.
-- It should scan substantially less Gold data than an unfiltered
-- query over the full dataset.
-- ================================================================
SELECT AIRLINE,
    TOTAL_FLIGHTS,
    AVG_ARR_DELAY,
    CANCELLATION_RATE
FROM flight_gold_db.airline_summary
WHERE Year = 2023
    AND Month = 1
ORDER BY TOTAL_FLIGHTS DESC;
-- ================================================================
-- 17. YEARLY AIRLINE SUMMARY
-- ================================================================
--
-- WARNING:
-- AVG(AVG_ARR_DELAY) is NOT a mathematically exact overall average
-- across all flights because monthly groups may have different
-- numbers of flights.
--
-- Use this only as a simple exploratory query.
-- For exact weighted metrics, calculate from Silver or retain suitable
-- numerators/denominators in the Gold model.
-- ================================================================
SELECT AIRLINE,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_DEPARTURES) AS delayed_departures,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    SUM(CANCELLED_FLIGHTS) AS cancelled_flights,
    SUM(DIVERTED_FLIGHTS) AS diverted_flights
FROM flight_gold_db.airline_summary
WHERE Year = 2023
GROUP BY AIRLINE
ORDER BY total_flights DESC;
-- ================================================================
-- 18. OPTIONAL FULL YEAR/MONTH SILVER-GOLD RECONCILIATION
-- ================================================================
--
-- COST WARNING:
-- This query reads the Silver dataset and should therefore NOT be
-- the first validation query.
--
-- First validate one partition (for example 2023/1), then several
-- representative partitions. Run this full reconciliation only when
-- required for final project validation.
--
-- Expected:
--   0 rows.
-- ================================================================
WITH silver_counts AS (
    SELECT Year,
        Month,
        COUNT(*) AS silver_flights
    FROM < SILVER_DATABASE >.< SILVER_TABLE >
    GROUP BY Year,
        Month
),
gold_counts AS (
    SELECT Year,
        Month,
        SUM(TOTAL_FLIGHTS) AS gold_flights
    FROM flight_gold_db.airline_summary
    GROUP BY Year,
        Month
)
SELECT COALESCE(s.Year, g.Year) AS Year,
    COALESCE(s.Month, g.Month) AS Month,
    s.silver_flights,
    g.gold_flights
FROM silver_counts s
    FULL OUTER JOIN gold_counts g ON s.Year = g.Year
    AND s.Month = g.Month
WHERE s.silver_flights IS NULL
    OR g.gold_flights IS NULL
    OR s.silver_flights <> g.gold_flights
ORDER BY Year,
    Month;
-- ================================================================
-- 19. FINAL GOLD VALIDATION CHECKLIST
-- ================================================================
--
-- Before declaring Gold complete, all of the following should be true:
--
-- [ ] Exactly 3 Gold Catalog tables exist.
-- [ ] All 3 tables point to the correct gold/ S3 prefixes.
-- [ ] All 3 tables use Year + Month partitions.
-- [ ] Gold files are Parquet.
-- [ ] Gold files use Snappy compression.
-- [ ] airline_summary grain has no duplicates.
-- [ ] airport_summary grain has no duplicates.
-- [ ] route_monthly_summary grain has no duplicates.
-- [ ] AIRPORT_ROLE contains only ORIGIN / DESTINATION.
-- [ ] No negative count values exist.
-- [ ] Rates are between 0 and 1.
-- [ ] Delayed/cancelled/diverted counts do not exceed total flights.
-- [ ] Silver and airline Gold totals reconcile.
-- [ ] Silver and route Gold totals reconcile.
-- [ ] Airline delay/cancellation/diversion counts reconcile.
-- [ ] Airport ORIGIN/DESTINATION logic reconciles.
-- [ ] Route metrics reconcile.
-- [ ] Delay-cause totals reconcile.
-- [ ] Average-delay values reconcile within an appropriate tolerance.
-- [ ] Representative Year/Month partitions have been tested.
-- [ ] Athena queries use partition filters whenever practical.
--
-- FINAL STATUS:
--
-- Gold should be considered VALIDATED only after the reconciliation
-- queries return no unexpected discrepancies.
-- ================================================================