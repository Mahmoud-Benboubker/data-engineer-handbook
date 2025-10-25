-- Query 4: Player who scored the most points in a single season
-- Joins games to bring in season and finds the top scorer per season.

WITH totals AS (
    SELECT g.season, player_name, SUM(COALESCE(pts, 0)) AS total_pts
    FROM game_details gd
    JOIN games g USING (game_id)
    GROUP BY g.season, player_name
)
SELECT season, player_name, total_pts
FROM totals
ORDER BY total_pts DESC, season, player_name
LIMIT 1;
