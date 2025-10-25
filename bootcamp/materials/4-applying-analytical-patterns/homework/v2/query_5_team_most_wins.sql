-- Query 5: Team with the most total wins
-- Computes winner per game (home or visitor) and aggregates.

WITH wins AS (
    SELECT CASE WHEN home_team_wins = 1 THEN home_team_id ELSE visitor_team_id END AS team_id
    FROM games
)
SELECT t.team_abbreviation, COUNT(*) AS total_wins
FROM wins w
JOIN (SELECT DISTINCT team_id, team_abbreviation FROM game_details) t ON w.team_id = t.team_id
GROUP BY t.team_abbreviation
ORDER BY total_wins DESC, t.team_abbreviation
LIMIT 1;
