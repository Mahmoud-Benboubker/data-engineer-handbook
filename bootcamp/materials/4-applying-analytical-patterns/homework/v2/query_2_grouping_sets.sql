-- Query 2: Aggregations using GROUPING SETS (PostgreSQL)
-- Requirement: Aggregate game_details along multiple dimensions efficiently.

SELECT 
    gd.player_name,
    gd.team_abbreviation,
    g.season,
    SUM(COALESCE(gd.pts, 0)) AS total_pts,
    GROUPING(gd.player_name) AS g_player,
    GROUPING(gd.team_abbreviation) AS g_team,
    GROUPING(g.season) AS g_season
FROM game_details gd
JOIN games g ON gd.game_id = g.game_id
GROUP BY GROUPING SETS (
    (gd.player_name, gd.team_abbreviation),   -- total points per player-team
    (gd.player_name, g.season),               -- total points per player-season
    (gd.team_abbreviation)                    -- total points per team
)
ORDER BY g_player, g_team, g_season;
