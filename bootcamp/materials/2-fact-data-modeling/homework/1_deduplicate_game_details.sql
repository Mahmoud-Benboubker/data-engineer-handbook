/* - A query to deduplicate `game_details` from Day 1 so there's no duplicates
 */
with rows as (
    select
        *,
        row_number() over (partition by game_id, team_id, player_id) as row_number
    from
        game_details
)
select
    *
from
    rows
where
    row_number = 1;