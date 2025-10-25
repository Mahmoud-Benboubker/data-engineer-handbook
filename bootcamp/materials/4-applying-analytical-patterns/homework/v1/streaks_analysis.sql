-- How many games in a row did LeBron James score over 10 points a game?
WITH base AS (
    SELECT
        player_name,
        game_date_est,
        pts,
        CASE
            WHEN pts > 10 THEN 1
            ELSE 0
        END AS over_treshold
    FROM
        game_details gd
        JOIN games g ON gd.game_id = g.game_id
    WHERE
        player_name = 'LeBron James'
),
streaks AS (
    SELECT
        player_name,
        game_date_est,
        over_treshold,
        SUM(
            CASE
                WHEN over_treshold = 0 THEN 1
                ELSE 0
            END
        ) OVER (
            PARTITION BY player_name
            ORDER BY
                game_date_est
        ) AS streak_group
    FROM
        base
)
SELECT
    player_name,
    streak_group,
    COUNT(*) AS streak_length,
    MIN(game_date_est) AS streak_start,
    MAX(game_date_est) AS streak_end
FROM
    streaks
WHERE
    over_treshold = 1
GROUP BY
    player_name,
    streak_group
ORDER BY
    streak_length DESC;

/*
 This query calculates winning streaks for each NBA team.
 
 Steps:
 1. Extract unique team identifiers and abbreviations from `game_details`.
 2. Expand each game into two rows (home and visitor teams) using a `CROSS JOIN LATERAL`
 to assign each team its own row and a win/loss flag.
 3. Identify continuous win streaks for each team using a window function:
 - Every time a team loses (`win_flag = 0`), the streak group increments.
 - Each unique `streak_group` represents one uninterrupted winning streak.
 4. Aggregate results to get the length, start date, and end date of each streak.
 
 Finally, the query outputs the longest winning streaks per team.
 */
WITH ref_team AS (
    -- Retrieve team abbreviations and IDs
    SELECT
        DISTINCT team_abbreviation,
        team_id
    FROM
        game_details
),
team_game_result AS (
    -- Expand each game into two team rows (home and visitor)
    SELECT
        g.game_id,
        t.team_id,
        t.team_type,
        g.game_date_est,
        CASE
            WHEN t.team_type = 'home'
            AND g.home_team_wins = 1 THEN 1
            WHEN t.team_type = 'visitor'
            AND g.home_team_wins = 0 THEN 1
            ELSE 0
        END AS win_flag
    FROM
        games g
        CROSS JOIN LATERAL (
            VALUES
                (g.home_team_id, 'home'),
                (g.visitor_team_id, 'visitor')
        ) AS t(team_id, team_type)
),
streaks AS (
    -- Assign a unique group ID to each uninterrupted win streak
    SELECT
        team_id,
        game_date_est,
        win_flag,
        SUM(
            CASE
                WHEN win_flag = 0 THEN 1
                ELSE 0
            END
        ) OVER (
            PARTITION BY team_id
            ORDER BY
                game_date_est
        ) AS streak_group
    FROM
        team_game_result
)
SELECT
    r.team_abbreviation,
    s.streak_group,
    COUNT(*) AS streak_length,
    MIN(s.game_date_est) AS streak_start,
    MAX(s.game_date_est) AS streak_end
FROM
    streaks s
    LEFT JOIN ref_team r ON r.team_id = s.team_id
WHERE
    s.win_flag = 1
GROUP BY
    r.team_abbreviation,
    s.streak_group
ORDER BY
    streak_length DESC;