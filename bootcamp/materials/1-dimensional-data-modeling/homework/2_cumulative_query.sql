/*
2. **Cumulative table generation query:** Write a query that populates the `actors` table one year at a time.
*/
INSERT INTO actors (actor, actorid, films, quality_class, is_active, current_year)
WITH current_year_agg AS (
    SELECT
        actor,
        actorid,
        ARRAY_AGG(ROW(film, votes, rating, filmid)::film) AS current_films,
        AVG(rating) AS avg_rating
    FROM actor_films
    WHERE year = 1971
    GROUP BY actor, actorid
),
previous_year_tbl AS (
    SELECT * FROM actors
    WHERE current_year = 1970
),
joined_tbl AS (
    SELECT
        COALESCE(p.actor, c.actor) AS actor,
        COALESCE(p.actorid, c.actorid) AS actorid,
        COALESCE(p.films, ARRAY[]::film[]) || COALESCE(c.current_films, ARRAY[]::film[]) AS films,
        c.actor IS NOT NULL AS is_active,
        c.avg_rating
    FROM previous_year_tbl p
    FULL OUTER JOIN current_year_agg c
    ON p.actorid = c.actorid
)
SELECT
    actor,
    actorid,
    films,
    CASE
        WHEN avg_rating > 8 THEN 'star'::quality_class
        WHEN avg_rating > 7 THEN 'good'::quality_class
        WHEN avg_rating > 6 THEN 'average'::quality_class
        ELSE 'bad'::quality_class
    END AS quality_class,
    is_active,
    1971 AS current_year
FROM joined_tbl
;


