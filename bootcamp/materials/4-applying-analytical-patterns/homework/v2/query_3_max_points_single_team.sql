-- Query 3: Player who scored the most points for a single team
-- Uses aggregation + ordering with deterministic tie-breakers.

WITH totals AS (
    SELECT player_name, team_abbreviation, SUM(COALESCE(pts, 0)) AS total_pts
    FROM game_details
    GROUP BY player_name, team_abbreviation
)
SELECT player_name, team_abbreviation, total_pts
FROM totals
ORDER BY total_pts DESC, player_name, team_abbreviation
LIMIT 1;
