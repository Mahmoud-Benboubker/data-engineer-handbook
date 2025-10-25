-- Query 6: Most games a team has won in any 90-game stretch
-- Uses rolling window (ROWS BETWEEN) for consecutive games.

WITH team_game_result AS (
    SELECT g.game_id, g.game_date_est, v.team_id,
           CASE
             WHEN v.team_type = 'home' AND g.home_team_wins = 1 THEN 1
             WHEN v.team_type = 'visitor' AND g.home_team_wins = 0 THEN 1
             ELSE 0
           END AS win_flag
    FROM games g
    CROSS JOIN LATERAL (VALUES (g.home_team_id, 'home'), (g.visitor_team_id, 'visitor')) AS v(team_id, team_type)
),
ordered AS (
    SELECT t.*, ROW_NUMBER() OVER (PARTITION BY team_id ORDER BY game_date_est, game_id) AS rn
    FROM team_game_result t
),
rolling AS (
    SELECT team_id,
           game_date_est,
           SUM(win_flag) OVER (
             PARTITION BY team_id
             ORDER BY rn
             ROWS BETWEEN 89 PRECEDING AND CURRENT ROW
           ) AS wins_last_90,
           LAG(game_date_est, 89) OVER (PARTITION BY team_id ORDER BY rn) AS window_start,
           game_date_est AS window_end
    FROM ordered
)
SELECT team_id, wins_last_90, window_start, window_end
FROM rolling
ORDER BY wins_last_90 DESC, team_id
LIMIT 1;
