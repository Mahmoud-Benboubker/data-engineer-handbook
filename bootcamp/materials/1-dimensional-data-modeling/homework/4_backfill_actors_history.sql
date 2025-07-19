/*
4. **Backfill query for `actors_history_scd`:** Write a "backfill" query that can populate the entire `actors_history_scd` table in a single query.
*/

insert into actors_scd_table  
with streak_started as 
(
select
	actor,
	actorid,
	quality_class,
	is_active,
	current_year,
	lag( quality_class, 1
) over (partition by actorid
order by
	current_year ) <> quality_class
	or lag (quality_class,
	1) over (partition by actorid
order by
	current_year) is null
	or lag( is_active, 1
) over (partition by actorid
order by
	current_year ) <> is_active
	or lag (is_active,
	1) over (partition by actorid
order by
	current_year) is null
as did_change
from
	actors
),
streak_identifier as (
select
	actor,
	actorid,
	current_year,
	quality_class,
	is_active,
	SUM(CASE WHEN did_change THEN 1 ELSE 0 END)
                OVER (PARTITION BY actorid ORDER BY current_year)  as streak_identified
from
	streak_started
group by actor, actorid, current_year, quality_class, is_active, did_change
),
aggregated as (
select
	actor,
	actorid,
	quality_class,
	is_active,
	streak_identified,
    min(current_year) as start_date,
	max(current_year) as end_date
from
	streak_identifier
group by
	actor,
	actorid,
	quality_class,
	is_active,
	streak_identified
)
select
	actor,
	actorid,
	quality_class,
	is_active,
	start_date,
	end_date
from
	aggregated
;