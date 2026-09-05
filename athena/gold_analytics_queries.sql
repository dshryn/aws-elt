-- ============================================================
-- FLIGHT DELAY ANALYTICS
-- GOLD LAYER — ATHENA ANALYTICAL QUERIES
-- ============================================================
--
-- Database:
--   flight_gold_db
--
-- Gold tables:
--   1. airline_summary
--   2. airport_summary
--   3. route_monthly_summary
--
-- Athena result location:
--   s3://elt-781504636344-ap-southeast-2-an/athena-results/
--
-- PURPOSE
-- -------
-- These queries are the FINAL analytical queries for the project.
-- They are intended to:
--
--   1. Generate meaningful business KPIs
--   2. Support the Power BI dashboard
--   3. Demonstrate Athena SQL analytics
--   4. Demonstrate partition-aware querying
--   5. Provide useful insights from the Gold layer
--
-- IMPORTANT
-- ---------
-- Gold contains aggregated analytical data.
-- Therefore these queries should use Gold rather than Silver
-- wherever possible.
--
-- RATE CALCULATION RULE
-- ---------------------
-- Do NOT calculate overall rates using AVG(rate).
--
-- Correct:
--     SUM(delayed_flights) / SUM(total_flights)
--
-- This produces the exact weighted rate.
--
-- AVERAGE DELAY RULE
-- ------------------
-- Do NOT calculate an overall average by averaging group-level
-- averages unless that is explicitly the desired metric.
--
-- ============================================================
-- ============================================================
-- SECTION 1 — EXECUTIVE KPIs
-- ============================================================
--
-- KPI PURPOSE:
-- Provides the primary high-level metrics for the project.
--
-- KPIs:
--   Total Flights
--   Delayed Departures
--   Delayed Arrivals
--   Cancelled Flights
--   Diverted Flights
--   Departure Delay Rate
--   Arrival Delay Rate
--   Cancellation Rate
--   Diversion Rate
--
-- SOURCE:
--   airline_summary
--
-- COST:
--   Gold-only scan.
--
-- ============================================================
SELECT SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_DEPARTURES) AS delayed_departures,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    SUM(CANCELLED_FLIGHTS) AS cancelled_flights,
    SUM(DIVERTED_FLIGHTS) AS diverted_flights,
    ROUND(
        100.0 * SUM(DELAYED_DEPARTURES) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS departure_delay_rate_pct,
    ROUND(
        100.0 * SUM(DELAYED_ARRIVALS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct,
    ROUND(
        100.0 * SUM(CANCELLED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS cancellation_rate_pct,
    ROUND(
        100.0 * SUM(DIVERTED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS diversion_rate_pct
FROM flight_gold_db.airline_summary;
-- ============================================================
-- SECTION 2 — MONTHLY FLIGHT VOLUME AND DELAY TREND
-- ============================================================
--
-- KPI PURPOSE:
-- Shows how flight activity and delays change over time.
--
-- Useful Power BI visual:
--   Line chart / combination chart
--
-- KPIs:
--   Total Flights
--   Delayed Departures
--   Delayed Arrivals
--   Departure Delay Rate
--   Arrival Delay Rate
--   Cancelled Flights
--   Diverted Flights
--
-- IMPORTANT:
-- Rates are calculated from total counts, NOT averaged.
--
-- ============================================================
SELECT Year,
    Month,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_DEPARTURES) AS delayed_departures,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    SUM(CANCELLED_FLIGHTS) AS cancelled_flights,
    SUM(DIVERTED_FLIGHTS) AS diverted_flights,
    ROUND(
        100.0 * SUM(DELAYED_DEPARTURES) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS departure_delay_rate_pct,
    ROUND(
        100.0 * SUM(DELAYED_ARRIVALS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct
FROM flight_gold_db.airline_summary
GROUP BY Year,
    Month
ORDER BY Year,
    Month;
-- ============================================================
-- SECTION 3 — YEARLY FLIGHT PERFORMANCE
-- ============================================================
--
-- KPI PURPOSE:
-- Compares overall flight performance between years.
--
-- Useful Power BI visual:
--   Column chart / yearly KPI comparison
--
-- KPIs:
--   Total Flights
--   Delayed Flights
--   Cancellation Rate
--   Diversion Rate
--   Delay Rates
--
-- ============================================================
SELECT Year,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_DEPARTURES) AS delayed_departures,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    SUM(CANCELLED_FLIGHTS) AS cancelled_flights,
    SUM(DIVERTED_FLIGHTS) AS diverted_flights,
    ROUND(
        100.0 * SUM(DELAYED_DEPARTURES) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS departure_delay_rate_pct,
    ROUND(
        100.0 * SUM(DELAYED_ARRIVALS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct,
    ROUND(
        100.0 * SUM(CANCELLED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS cancellation_rate_pct,
    ROUND(
        100.0 * SUM(DIVERTED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS diversion_rate_pct
FROM flight_gold_db.airline_summary
GROUP BY Year
ORDER BY Year;
-- ============================================================
-- SECTION 4 — AIRLINE PERFORMANCE
-- ============================================================
--
-- KPI PURPOSE:
-- Compares airlines using operational performance metrics.
--
-- Useful Power BI visual:
--   Horizontal bar chart / airline comparison table
--
-- KPIs:
--   Total Flights
--   Delayed Departures
--   Delayed Arrivals
--   Departure Delay Rate
--   Arrival Delay Rate
--   Cancellation Rate
--   Average Departure Delay
--   Average Arrival Delay
--
-- ============================================================
SELECT AIRLINE,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_DEPARTURES) AS delayed_departures,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    SUM(CANCELLED_FLIGHTS) AS cancelled_flights,
    SUM(DIVERTED_FLIGHTS) AS diverted_flights,
    ROUND(
        SUM(AVG_DEP_DELAY * TOTAL_FLIGHTS) / NULLIF(
            SUM(
                CASE
                    WHEN AVG_DEP_DELAY IS NOT NULL THEN TOTAL_FLIGHTS
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS avg_departure_delay,
    ROUND(
        SUM(AVG_ARR_DELAY * TOTAL_FLIGHTS) / NULLIF(
            SUM(
                CASE
                    WHEN AVG_ARR_DELAY IS NOT NULL THEN TOTAL_FLIGHTS
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS avg_arrival_delay,
    ROUND(
        100.0 * SUM(DELAYED_DEPARTURES) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS departure_delay_rate_pct,
    ROUND(
        100.0 * SUM(DELAYED_ARRIVALS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct,
    ROUND(
        100.0 * SUM(CANCELLED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS cancellation_rate_pct
FROM flight_gold_db.airline_summary
GROUP BY AIRLINE
ORDER BY total_flights DESC;
-- ============================================================
-- SECTION 5 — TOP AIRLINES BY ARRIVAL DELAY RATE
-- ============================================================
--
-- KPI PURPOSE:
-- Identifies airlines with the highest proportion of delayed
-- arrivals.
--
-- IMPORTANT:
-- A minimum flight threshold is used so that an airline with
-- very low traffic does not dominate the ranking.
--
-- KPI:
--   Arrival Delay Rate
--
-- ============================================================
SELECT AIRLINE,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    ROUND(
        100.0 * SUM(DELAYED_ARRIVALS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct
FROM flight_gold_db.airline_summary
GROUP BY AIRLINE
HAVING SUM(TOTAL_FLIGHTS) >= 1000
ORDER BY arrival_delay_rate_pct DESC
LIMIT 10;
-- ============================================================
-- SECTION 6 — TOP AIRLINES BY DEPARTURE DELAY RATE
-- ============================================================
--
-- KPI PURPOSE:
-- Identifies airlines with the highest proportion of delayed
-- departures.
--
-- ============================================================
SELECT AIRLINE,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_DEPARTURES) AS delayed_departures,
    ROUND(
        100.0 * SUM(DELAYED_DEPARTURES) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS departure_delay_rate_pct
FROM flight_gold_db.airline_summary
GROUP BY AIRLINE
HAVING SUM(TOTAL_FLIGHTS) >= 1000
ORDER BY departure_delay_rate_pct DESC
LIMIT 10;
-- ============================================================
-- SECTION 7 — AIRLINE DELAY CAUSES
-- ============================================================
--
-- KPI PURPOSE:
-- Determines what types of operational problems contribute
-- most to delays for each airline.
--
-- Delay categories:
--   Carrier
--   Weather
--   NAS
--   Security
--   Late Aircraft
--
-- Useful Power BI visual:
--   Stacked bar chart
--
-- ============================================================
SELECT AIRLINE,
    SUM(TOTAL_CARRIER_DELAY) AS carrier_delay_minutes,
    SUM(TOTAL_WEATHER_DELAY) AS weather_delay_minutes,
    SUM(TOTAL_NAS_DELAY) AS nas_delay_minutes,
    SUM(TOTAL_SECURITY_DELAY) AS security_delay_minutes,
    SUM(TOTAL_LATE_AIRCRAFT_DELAY) AS late_aircraft_delay_minutes,
    (
        COALESCE(SUM(TOTAL_CARRIER_DELAY), 0) + COALESCE(SUM(TOTAL_WEATHER_DELAY), 0) + COALESCE(SUM(TOTAL_NAS_DELAY), 0) + COALESCE(SUM(TOTAL_SECURITY_DELAY), 0) + COALESCE(SUM(TOTAL_LATE_AIRCRAFT_DELAY), 0)
    ) AS total_recorded_delay_cause_minutes
FROM flight_gold_db.airline_summary
GROUP BY AIRLINE
ORDER BY total_recorded_delay_cause_minutes DESC;
-- ============================================================
-- SECTION 8 — OVERALL DELAY CAUSE CONTRIBUTION
-- ============================================================
--
-- KPI PURPOSE:
-- Provides the overall distribution of recorded delay causes.
--
-- Useful Power BI visual:
--   Donut / pie chart
--
-- NOTE:
-- The five delay-cause columns are independent recorded delay
-- components. They should not automatically be interpreted as
-- mutually exclusive flight counts.
--
-- ============================================================
SELECT SUM(TOTAL_CARRIER_DELAY) AS carrier_delay_minutes,
    SUM(TOTAL_WEATHER_DELAY) AS weather_delay_minutes,
    SUM(TOTAL_NAS_DELAY) AS nas_delay_minutes,
    SUM(TOTAL_SECURITY_DELAY) AS security_delay_minutes,
    SUM(TOTAL_LATE_AIRCRAFT_DELAY) AS late_aircraft_delay_minutes
FROM flight_gold_db.airline_summary;
-- ============================================================
-- SECTION 9 — AIRPORT PERFORMANCE
-- ============================================================
--
-- KPI PURPOSE:
-- Compares airport performance while preserving the distinction
-- between departure/origin and arrival/destination operations.
--
-- Useful Power BI visual:
--   Airport performance table / bar chart
--
-- KPIs:
--   Total Flights
--   Delayed Flights
--   Delay Rate
--   Average Delay
--   Total Delay Minutes
--
-- ============================================================
SELECT AIRPORT,
    AIRPORT_ROLE,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_FLIGHTS) AS delayed_flights,
    SUM(CANCELLED_FLIGHTS) AS cancelled_flights,
    SUM(DIVERTED_FLIGHTS) AS diverted_flights,
    SUM(TOTAL_DELAY_MINUTES) AS total_delay_minutes,
    ROUND(
        SUM(TOTAL_DELAY_MINUTES) / NULLIF(
            SUM(
                CASE
                    WHEN AVG_DELAY IS NOT NULL THEN TOTAL_FLIGHTS
                    ELSE 0
                END
            ),
            0
        ),
        2
    ) AS avg_delay_minutes,
    ROUND(
        100.0 * SUM(DELAYED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS delay_rate_pct
FROM flight_gold_db.airport_summary
GROUP BY AIRPORT,
    AIRPORT_ROLE
ORDER BY delay_rate_pct DESC;
-- ============================================================
-- SECTION 10 — TOP 10 ORIGIN AIRPORTS BY DELAY RATE
-- ============================================================
--
-- KPI PURPOSE:
-- Identifies airports where departures experience the highest
-- delay frequency.
--
-- ============================================================
SELECT AIRPORT,
    SUM(TOTAL_FLIGHTS) AS total_departures,
    SUM(DELAYED_FLIGHTS) AS delayed_departures,
    ROUND(
        100.0 * SUM(DELAYED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS departure_delay_rate_pct,
    SUM(TOTAL_DELAY_MINUTES) AS total_departure_delay_minutes
FROM flight_gold_db.airport_summary
WHERE AIRPORT_ROLE = 'ORIGIN'
GROUP BY AIRPORT
HAVING SUM(TOTAL_FLIGHTS) >= 1000
ORDER BY departure_delay_rate_pct DESC
LIMIT 10;
-- ============================================================
-- SECTION 11 — TOP 10 DESTINATION AIRPORTS BY DELAY RATE
-- ============================================================
--
-- KPI PURPOSE:
-- Identifies airports where arriving flights experience the
-- highest delay frequency.
--
-- ============================================================
SELECT AIRPORT,
    SUM(TOTAL_FLIGHTS) AS total_arrivals,
    SUM(DELAYED_FLIGHTS) AS delayed_arrivals,
    ROUND(
        100.0 * SUM(DELAYED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct,
    SUM(TOTAL_DELAY_MINUTES) AS total_arrival_delay_minutes
FROM flight_gold_db.airport_summary
WHERE AIRPORT_ROLE = 'DESTINATION'
GROUP BY AIRPORT
HAVING SUM(TOTAL_FLIGHTS) >= 1000
ORDER BY arrival_delay_rate_pct DESC
LIMIT 10;
-- ============================================================
-- SECTION 12 — TOP ROUTES BY FLIGHT VOLUME
-- ============================================================
--
-- KPI PURPOSE:
-- Identifies the busiest flight routes.
--
-- Useful Power BI visual:
--   Top routes bar chart
--
-- KPI:
--   Total Flights
--
-- ============================================================
SELECT ORIGIN,
    DEST,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(TOTAL_DISTANCE) AS total_distance,
    ROUND(
        SUM(AVG_DISTANCE * TOTAL_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS avg_distance
FROM flight_gold_db.route_monthly_summary
GROUP BY ORIGIN,
    DEST
ORDER BY total_flights DESC
LIMIT 20;
-- ============================================================
-- SECTION 13 — TOP ROUTES BY DEPARTURE DELAY RATE
-- ============================================================
--
-- KPI PURPOSE:
-- Finds routes where departures are most frequently delayed.
--
-- Minimum volume threshold prevents tiny routes from dominating
-- the ranking.
--
-- ============================================================
SELECT ORIGIN,
    DEST,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_DEPARTURES) AS delayed_departures,
    ROUND(
        100.0 * SUM(DELAYED_DEPARTURES) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS departure_delay_rate_pct
FROM flight_gold_db.route_monthly_summary
GROUP BY ORIGIN,
    DEST
HAVING SUM(TOTAL_FLIGHTS) >= 1000
ORDER BY departure_delay_rate_pct DESC
LIMIT 20;
-- ============================================================
-- SECTION 14 — TOP ROUTES BY ARRIVAL DELAY RATE
-- ============================================================
--
-- KPI PURPOSE:
-- Finds routes where arrivals are most frequently delayed.
--
-- ============================================================
SELECT ORIGIN,
    DEST,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    ROUND(
        100.0 * SUM(DELAYED_ARRIVALS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct
FROM flight_gold_db.route_monthly_summary
GROUP BY ORIGIN,
    DEST
HAVING SUM(TOTAL_FLIGHTS) >= 1000
ORDER BY arrival_delay_rate_pct DESC
LIMIT 20;
-- ============================================================
-- SECTION 15 — ROUTES WITH HIGHEST TOTAL DELAY MINUTES
-- ============================================================
--
-- KPI PURPOSE:
-- Identifies routes responsible for the largest aggregate
-- amount of delay.
--
-- This is different from delay rate.
--
-- A high-volume route can have a large total delay burden even
-- when its percentage delay rate is not the highest.
--
-- ============================================================
SELECT ORIGIN,
    DEST,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_DEPARTURES) AS delayed_departures,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    ROUND(
        SUM(AVG_DEP_DELAY * TOTAL_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS avg_departure_delay,
    ROUND(
        SUM(AVG_ARR_DELAY * TOTAL_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS avg_arrival_delay
FROM flight_gold_db.route_monthly_summary
GROUP BY ORIGIN,
    DEST
HAVING SUM(TOTAL_FLIGHTS) >= 1000
ORDER BY avg_arrival_delay DESC
LIMIT 20;
-- ============================================================
-- SECTION 16 — MONTHLY AIRLINE PERFORMANCE
-- ============================================================
--
-- KPI PURPOSE:
-- Allows comparison of airline performance over time.
--
-- Useful Power BI visual:
--   Multi-line chart
--
-- ============================================================
SELECT AIRLINE,
    Year,
    Month,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_DEPARTURES) AS delayed_departures,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    ROUND(
        100.0 * SUM(DELAYED_DEPARTURES) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS departure_delay_rate_pct,
    ROUND(
        100.0 * SUM(DELAYED_ARRIVALS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct
FROM flight_gold_db.airline_summary
GROUP BY AIRLINE,
    Year,
    Month
ORDER BY Year,
    Month,
    AIRLINE;
-- ============================================================
-- SECTION 17 — MONTHLY DELAY CAUSE TREND
-- ============================================================
--
-- KPI PURPOSE:
-- Shows how different causes of delay change over time.
--
-- Useful Power BI visual:
--   Stacked area / stacked column chart
--
-- ============================================================
SELECT Year,
    Month,
    SUM(TOTAL_CARRIER_DELAY) AS carrier_delay_minutes,
    SUM(TOTAL_WEATHER_DELAY) AS weather_delay_minutes,
    SUM(TOTAL_NAS_DELAY) AS nas_delay_minutes,
    SUM(TOTAL_SECURITY_DELAY) AS security_delay_minutes,
    SUM(TOTAL_LATE_AIRCRAFT_DELAY) AS late_aircraft_delay_minutes
FROM flight_gold_db.airline_summary
GROUP BY Year,
    Month
ORDER BY Year,
    Month;
-- ============================================================
-- SECTION 18 — CANCELLATION PERFORMANCE BY AIRLINE
-- ============================================================
--
-- KPI PURPOSE:
-- Identifies airlines with the highest cancellation rates.
--
-- ============================================================
SELECT AIRLINE,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(CANCELLED_FLIGHTS) AS cancelled_flights,
    ROUND(
        100.0 * SUM(CANCELLED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS cancellation_rate_pct
FROM flight_gold_db.airline_summary
GROUP BY AIRLINE
HAVING SUM(TOTAL_FLIGHTS) >= 1000
ORDER BY cancellation_rate_pct DESC
LIMIT 10;
-- ============================================================
-- SECTION 19 — DIVERSION PERFORMANCE BY AIRLINE
-- ============================================================
--
-- KPI PURPOSE:
-- Identifies airlines with the highest diversion rates.
--
-- ============================================================
SELECT AIRLINE,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DIVERTED_FLIGHTS) AS diverted_flights,
    ROUND(
        100.0 * SUM(DIVERTED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS diversion_rate_pct
FROM flight_gold_db.airline_summary
GROUP BY AIRLINE
HAVING SUM(TOTAL_FLIGHTS) >= 1000
ORDER BY diversion_rate_pct DESC
LIMIT 10;
-- ============================================================
-- SECTION 20 — AIRPORT TRAFFIC VOLUME
-- ============================================================
--
-- KPI PURPOSE:
-- Identifies airports with the largest operational volume.
--
-- Useful Power BI visual:
--   Top airports by traffic
--
-- ============================================================
SELECT AIRPORT,
    AIRPORT_ROLE,
    SUM(TOTAL_FLIGHTS) AS total_flights
FROM flight_gold_db.airport_summary
GROUP BY AIRPORT,
    AIRPORT_ROLE
ORDER BY total_flights DESC
LIMIT 20;
-- ============================================================
-- SECTION 21 — AIRPORT TOTAL DELAY BURDEN
-- ============================================================
--
-- KPI PURPOSE:
-- Identifies airports responsible for the largest aggregate
-- delay burden.
--
-- This should not be confused with delay rate.
--
-- ============================================================
SELECT AIRPORT,
    AIRPORT_ROLE,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_FLIGHTS) AS delayed_flights,
    SUM(TOTAL_DELAY_MINUTES) AS total_delay_minutes,
    ROUND(
        100.0 * SUM(DELAYED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS delay_rate_pct
FROM flight_gold_db.airport_summary
GROUP BY AIRPORT,
    AIRPORT_ROLE
HAVING SUM(TOTAL_FLIGHTS) >= 1000
ORDER BY total_delay_minutes DESC
LIMIT 20;
-- ============================================================
-- SECTION 22 — YEARLY AIRLINE RANKING
-- ============================================================
--
-- KPI PURPOSE:
-- Shows the relative performance of airlines by year.
--
-- Useful for Power BI:
--   Year slicer + airline ranking
--
-- ============================================================
SELECT Year,
    AIRLINE,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_DEPARTURES) AS delayed_departures,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    ROUND(
        100.0 * SUM(DELAYED_DEPARTURES) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS departure_delay_rate_pct,
    ROUND(
        100.0 * SUM(DELAYED_ARRIVALS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct
FROM flight_gold_db.airline_summary
GROUP BY Year,
    AIRLINE
ORDER BY Year,
    arrival_delay_rate_pct DESC;
-- ============================================================
-- SECTION 23 — MONTHLY ROUTE PERFORMANCE
-- ============================================================
--
-- KPI PURPOSE:
-- Provides route-level time-series data for detailed analysis.
--
-- Useful Power BI:
--   Route slicer + monthly trend
--
-- ============================================================
SELECT ORIGIN,
    DEST,
    Year,
    Month,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_DEPARTURES) AS delayed_departures,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    ROUND(
        100.0 * SUM(DELAYED_DEPARTURES) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS departure_delay_rate_pct,
    ROUND(
        100.0 * SUM(DELAYED_ARRIVALS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct,
    ROUND(
        SUM(AVG_DISTANCE * TOTAL_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS avg_distance
FROM flight_gold_db.route_monthly_summary
GROUP BY ORIGIN,
    DEST,
    Year,
    Month
ORDER BY Year,
    Month;
-- ============================================================
-- SECTION 24 — HIGH-VOLUME ROUTES WITH ABOVE-AVERAGE DELAYS
-- ============================================================
--
-- KPI PURPOSE:
-- Identifies operationally significant routes that combine:
--
--   1. High flight volume
--   2. High arrival delay rate
--
-- This is more useful operationally than simply finding routes
-- with the highest delay percentage.
--
-- ============================================================
SELECT ORIGIN,
    DEST,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    ROUND(
        100.0 * SUM(DELAYED_ARRIVALS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct
FROM flight_gold_db.route_monthly_summary
GROUP BY ORIGIN,
    DEST
HAVING SUM(TOTAL_FLIGHTS) >= 5000
ORDER BY arrival_delay_rate_pct DESC
LIMIT 20;
-- ============================================================
-- SECTION 25 — PARTITION-AWARE MONTHLY QUERY EXAMPLE
-- ============================================================
--
-- PURPOSE:
-- Demonstrates explicit partition pruning using Year + Month.
--
-- This is useful for the project's AWS cost-optimization
-- documentation.
--
-- IMPORTANT:
-- This query intentionally filters the partition columns.
--
-- COST:
-- Lower scanned data than an equivalent unfiltered query over
-- the entire Gold table.
--
-- Change the Year/Month values when analyzing another period.
--
-- ============================================================
SELECT AIRLINE,
    TOTAL_FLIGHTS,
    DELAYED_DEPARTURES,
    DELAYED_ARRIVALS,
    DEPARTURE_DELAY_RATE,
    ARRIVAL_DELAY_RATE
FROM flight_gold_db.airline_summary
WHERE Year = 2023
    AND Month = 1
ORDER BY TOTAL_FLIGHTS DESC;
-- ============================================================
-- SECTION 26 — SPECIFIC MONTH AIRPORT ANALYSIS
-- ============================================================
--
-- PURPOSE:
-- Partition-aware airport analysis.
--
-- Useful for:
--   Investigating a specific month
--   Demonstrating partition pruning
--   Keeping Athena scan volume low
--
-- ============================================================
SELECT AIRPORT,
    AIRPORT_ROLE,
    TOTAL_FLIGHTS,
    DELAYED_FLIGHTS,
    AVG_DELAY,
    TOTAL_DELAY_MINUTES,
    DELAY_RATE
FROM flight_gold_db.airport_summary
WHERE Year = 2023
    AND Month = 1
ORDER BY DELAY_RATE DESC
LIMIT 20;
-- ============================================================
-- SECTION 27 — SPECIFIC MONTH ROUTE ANALYSIS
-- ============================================================
--
-- PURPOSE:
-- Partition-aware route analysis.
--
-- ============================================================
SELECT ORIGIN,
    DEST,
    TOTAL_FLIGHTS,
    DELAYED_DEPARTURES,
    DELAYED_ARRIVALS,
    AVG_DEP_DELAY,
    AVG_ARR_DELAY,
    DEPARTURE_DELAY_RATE,
    ARRIVAL_DELAY_RATE,
    TOTAL_DISTANCE
FROM flight_gold_db.route_monthly_summary
WHERE Year = 2023
    AND Month = 1
ORDER BY ARRIVAL_DELAY_RATE DESC
LIMIT 20;
-- ============================================================
-- SECTION 28 — MOST RELIABLE AIRLINES
-- ============================================================
--
-- KPI PURPOSE:
-- Identifies airlines with the lowest arrival delay rates.
--
-- Minimum traffic threshold avoids misleading results from
-- extremely small datasets.
--
-- ============================================================
SELECT AIRLINE,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    SUM(DELAYED_ARRIVALS) AS delayed_arrivals,
    ROUND(
        100.0 * SUM(DELAYED_ARRIVALS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct
FROM flight_gold_db.airline_summary
GROUP BY AIRLINE
HAVING SUM(TOTAL_FLIGHTS) >= 10000
ORDER BY arrival_delay_rate_pct ASC
LIMIT 10;
-- ============================================================
-- SECTION 29 — FLIGHT VOLUME VS DELAY PERFORMANCE BY AIRLINE
-- ============================================================
--
-- KPI PURPOSE:
-- Creates a dataset suitable for a scatter plot:
--
-- X-axis:
--   Total Flights
--
-- Y-axis:
--   Arrival Delay Rate
--
-- This can reveal whether high-volume airlines also experience
-- higher/lower delay rates.
--
-- ============================================================
SELECT AIRLINE,
    SUM(TOTAL_FLIGHTS) AS total_flights,
    ROUND(
        100.0 * SUM(DELAYED_ARRIVALS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS arrival_delay_rate_pct,
    ROUND(
        100.0 * SUM(CANCELLED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS cancellation_rate_pct,
    ROUND(
        100.0 * SUM(DIVERTED_FLIGHTS) / NULLIF(SUM(TOTAL_FLIGHTS), 0),
        2
    ) AS diversion_rate_pct
FROM flight_gold_db.airline_summary
GROUP BY AIRLINE
ORDER BY total_flights DESC;
-- ============================================================
-- SECTION 30 — YEARLY DELAY CAUSE ANALYSIS
-- ============================================================
--
-- KPI PURPOSE:
-- Shows whether the composition of delay causes changes between
-- years.
--
-- Useful Power BI visual:
--   Stacked column chart by year
--
-- ============================================================
SELECT Year,
    SUM(TOTAL_CARRIER_DELAY) AS carrier_delay_minutes,
    SUM(TOTAL_WEATHER_DELAY) AS weather_delay_minutes,
    SUM(TOTAL_NAS_DELAY) AS nas_delay_minutes,
    SUM(TOTAL_SECURITY_DELAY) AS security_delay_minutes,
    SUM(TOTAL_LATE_AIRCRAFT_DELAY) AS late_aircraft_delay_minutes
FROM flight_gold_db.airline_summary
GROUP BY Year
ORDER BY Year;
-- ============================================================
-- END OF GOLD ANALYTICAL QUERY FILE
-- ============================================================
--
-- RECOMMENDED POWER BI CORE DATASETS
-- ----------------------------------
--
-- 1. Monthly flight/delay trend
-- 2. Airline performance
-- 3. Airport performance
-- 4. Route performance
-- 5. Delay causes
--
-- CORE EXECUTIVE KPIs
-- -------------------
--
--   Total Flights
--   Delayed Departures
--   Delayed Arrivals
--   Arrival Delay Rate
--   Departure Delay Rate
--   Cancellation Rate
--   Diversion Rate
--
-- COST OPTIMIZATION PRINCIPLES
-- -----------------------------
--
-- 1. Prefer Gold over Silver for dashboard analytics.
-- 2. Use Year + Month filters whenever possible.
-- 3. Avoid SELECT *.
-- 4. Select only required columns.
-- 5. Avoid unnecessary repeated full-table scans.
-- 6. Use LIMIT for exploratory ranking queries.
-- 7. Do not create another S3 location for Athena results.
--
-- ============================================================