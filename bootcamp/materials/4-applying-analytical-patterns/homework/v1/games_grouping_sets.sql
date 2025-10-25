/*
 This query uses `GROUPING SETS` to efficiently aggregate `game_details` data
 along multiple dimensions:
 - player and team
 → Who scored the most points playing for one team?
 - player and season
 → Who scored the most points in one season?
 - team
 → Which team has won the most games?
 
 ⚠️ Important note:
 `GROUPING SETS` operates at the granularity of the source table (`game_details`),
 which is player–team–game.  
 It cannot correctly calculate the number of games won by a team because each game
 would be counted once per player on that team.  
 To address this, the team win calculation is done separately from the `games` table
 (one row per game) and combined using a `UNION ALL`.
 */
WITH player_stats AS (
    SELECT
        player_name,
        team_abbreviation,
        g.season,
        SUM(COALESCE(pts, 0)) AS total_pts
    FROM
        game_details gd
        JOIN games g ON gd.game_id = g.game_id
    GROUP BY
        GROUPING SETS (
            (player_name, team_abbreviation),
            -- total points by player and team
            (player_name, season) -- total points by player and season
        )
),
team_wins AS (
    SELECT
        CASE
            WHEN home_team_wins = 1 THEN home_team_id
            ELSE visitor_team_id
        END AS team_id,
        COUNT(*) AS total_wins
    FROM
        games
    GROUP BY
        team_id
)
SELECT
    player_name,
    team_abbreviation,
    season,
    total_pts,
    NULL AS total_wins
FROM
    player_stats
UNION
ALL
SELECT
    NULL AS player_name,
    NULL AS team_abbreviation,
    NULL AS season,
    NULL AS total_pts,
    total_wins
FROM
    team_wins