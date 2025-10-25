-- Query 7: Longest streak of games where LeBron scored over 10 points
-- Implements the 'islands and gaps' pattern with SUM(CASE) OVER window.

WITH enriched AS (
    SELECT g.game_date_est, gd.player_name, gd.pts, gd.game_id
    FROM game_details gd
    JOIN games g ON gd.game_id = g.game_id
    WHERE gd.player_name = 'LeBron James'
),
flagged AS (
    SELECT *, CASE WHEN pts > 10 THEN 1 ELSE 0 END AS over_threshold FROM enriched
),
streaks AS (
    SELECT player_name, game_date_est, over_threshold,
           SUM(CASE WHEN over_threshold = 0 THEN 1 ELSE 0 END)
           OVER (PARTITION BY player_name ORDER BY game_date_est, game_id) AS streak_group
    FROM flagged
)
SELECT player_name, streak_group, COUNT(*) AS streak_length,
       MIN(game_date_est) AS streak_start, MAX(game_date_est) AS streak_end
FROM streaks
WHERE over_threshold = 1
GROUP BY player_name, streak_group
ORDER BY streak_length DESC, streak_end DESC
LIMIT 1;
