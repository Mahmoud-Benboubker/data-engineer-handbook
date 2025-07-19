/*
5. **Incremental query for `actors_history_scd`:** Write an "incremental" query that combines 
the previous year's SCD data with new incoming data from the `actors` table.
*/

CREATE TYPE scd_type AS (
                    is_active boolean,
                    quality_class quality_class,
                    start_date INTEGER,
                    end_date INTEGER
                        )
;


INSERT INTO actors_scd_table
WITH last_year_actors_scd_table AS (
    SELECT * FROM actors_scd_table
    WHERE current_year = 1970
      AND end_date = 1970
),

historical_scd AS (
    SELECT
        actor,
        actorid,
        is_active,
        quality_class,
        start_date,
        end_date
    FROM actors_scd_table
    WHERE current_year = 1970
      AND end_date < 1970
),

this_year_data AS (
    SELECT * FROM actors
    WHERE current_year = 1971
),

unchanged_records AS (
    SELECT
        ts.actor,
        ts.actorid,
        ts.is_active,
        ts.quality_class,
        ls.start_date,
        ts.current_year AS end_date
    FROM this_year_data ts
    JOIN last_year_actors_scd_table ls
      ON ls.actorid = ts.actorid
    WHERE ts.quality_class = ls.quality_class
      AND ts.is_active = ls.is_active
),

changed_records AS (
    SELECT
        ts.actor,
        ts.actorid,
        UNNEST(ARRAY[
            ROW(
                ls.is_active,
                ls.quality_class,
                ls.start_date,
                ls.end_date
            )::scd_type,
            ROW(
                ts.is_active,
                ts.quality_class,
                ts.current_year,
                ts.current_year
            )::scd_type
        ]) AS record
    FROM this_year_data ts
    LEFT JOIN last_year_actors_scd_table ls
      ON ls.actor = ts.actor
    WHERE (ts.quality_class <> ls.quality_class
       OR ts.is_active <> ls.is_active)
),

unnested_changed_records AS (
    SELECT
        cr.actor,
        cr.actorid,
        (cr.record).is_active,
        (cr.record).quality_class,
        (cr.record).start_date,
        (cr.record).end_date
    FROM changed_records cr
),

new_records AS (
    SELECT
        ts.actor,
        ts.actorid,
        ts.is_active,
        ts.quality_class,
        ts.current_year AS start_date,
        ts.current_year AS end_date
    FROM this_year_data ts
    LEFT JOIN last_year_actors_scd_table ls
      ON ts.actor = ls.actor
    WHERE ls.actor IS NULL
)

SELECT
    actor,
    actorid,
    quality_class,
    is_active,
    start_date,
    end_date,
    1971 AS current_year
FROM (
    SELECT * FROM historical_scd
    UNION ALL
    SELECT * FROM unchanged_records
    UNION ALL
    SELECT * FROM unnested_changed_records
    UNION ALL
    SELECT * FROM new_records
) a;

