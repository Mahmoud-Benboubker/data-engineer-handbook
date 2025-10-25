/*
 - A query that does state change tracking for `players`
 - A player entering the league should be `New`
 - A player leaving the league should be `Retired`
 - A player staying in the league should be `Continued Playing`
 - A player that comes out of retirement should be `Returned from Retirement`
 - A player that stays out of the league should be `Stayed Retired`
 */
-- Generating the players table
WITH params AS (
    SELECT
        2004 AS prev_year,
        2004 + 1 AS year
),
last_season AS (
    SELECT
        p.*
    FROM
        players p
        CROSS JOIN params
    WHERE
        p.current_season = params.prev_year
),
this_season AS (
    SELECT
        ps.*
    FROM
        player_seasons ps
        CROSS JOIN params
    WHERE
        ps.season = params.year
)
INSERT INTO
    players (
        player_name,
        height,
        college,
        country,
        draft_year,
        draft_round,
        draft_number,
        seasons,
        scoring_class,
        years_since_last_active,
        is_active,
        current_season
    )
SELECT
    COALESCE(ls.player_name, ts.player_name),
    COALESCE(ls.height, ts.height),
    COALESCE(ls.college, ts.college),
    COALESCE(ls.country, ts.country),
    COALESCE(ls.draft_year, ts.draft_year),
    COALESCE(ls.draft_round, ts.draft_round),
    COALESCE(ls.draft_number, ts.draft_number),
    COALESCE(ls.seasons, ARRAY [] :: season_stats []) || CASE
        WHEN ts.season IS NOT NULL THEN ARRAY [ROW(ts.season, ts.pts, ts.ast, ts.reb, ts.weight)::season_stats]
        ELSE ARRAY [] :: season_stats []
    END,
    CASE
        WHEN ts.season IS NOT NULL THEN (
            CASE
                WHEN ts.pts > 20 THEN 'star'
                WHEN ts.pts > 15 THEN 'good'
                WHEN ts.pts > 10 THEN 'average'
                ELSE 'bad'
            END
        ) :: scoring_class
        ELSE ls.scoring_class
    END,
    CASE
        WHEN ts.season IS NOT NULL THEN 0
        WHEN ls.player_name IS NOT NULL THEN CASE
            WHEN ls.is_active THEN 1
            ELSE COALESCE(ls.years_since_last_active, 0) + 1
        END
        ELSE NULL
    END,
    (ts.season IS NOT NULL),
    (
        SELECT
            year
        FROM
            params
    )
FROM
    last_season ls FULL
    OUTER JOIN this_season ts ON ls.player_name = ts.player_name;

-- Creating the growth accounting states for players each season
SELECT
    curr.player_name,
    curr.current_season AS season_ref,
    CASE
        WHEN prev.player_name IS NULL THEN 'New'
        WHEN prev.is_active = TRUE
        AND curr.is_active = FALSE THEN 'Retired'
        WHEN prev.is_active = FALSE
        AND curr.is_active = FALSE THEN 'Stayed Retired'
        WHEN prev.is_active = FALSE
        AND curr.is_active = TRUE THEN 'Returned from Retirement'
        WHEN prev.is_active = TRUE
        AND curr.is_active = TRUE THEN 'Continued Playing'
        ELSE NULL
    END AS status_state
FROM
    players AS curr
    LEFT JOIN players AS prev ON curr.player_name = prev.player_name
    AND curr.current_season = prev.current_season + 1
order by
    player_name,
    season_ref;