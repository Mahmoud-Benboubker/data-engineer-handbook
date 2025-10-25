-- Query 1: Player State Change Tracking using players_scd
-- Objective: Detect changes in player activity status across seasons.
-- Logic follows a Slowly Changing Dimension Type 2 pattern with LAG().

WITH player_activity AS (
    SELECT 
        p.player_name,
        s.season,
        CASE WHEN ps.player_name IS NOT NULL THEN 1 ELSE 0 END AS is_active
    FROM players p
    CROSS JOIN (SELECT DISTINCT season FROM player_seasons) s
    LEFT JOIN player_seasons ps 
      ON p.player_name = ps.player_name AND ps.season = s.season
)
SELECT 
    player_name,
    season AS season_ref,
    CASE
        WHEN LAG(is_active) OVER w IS NULL AND is_active = 1 THEN 'New'
        WHEN LAG(is_active) OVER w IS NULL AND is_active = 0 THEN 'Stayed Retired'
        WHEN LAG(is_active) OVER w = 1 AND is_active = 1 THEN 'Continued Playing'
        WHEN LAG(is_active) OVER w = 1 AND is_active = 0 THEN 'Retired'
        WHEN LAG(is_active) OVER w = 0 AND is_active = 1 THEN 'Returned from Retirement'
        WHEN LAG(is_active) OVER w = 0 AND is_active = 0 THEN 'Stayed Retired'
    END AS status_state
FROM player_activity
WINDOW w AS (PARTITION BY player_name ORDER BY CAST(SPLIT_PART(season, '-', 1) AS INTEGER))
ORDER BY player_name, season_ref;
