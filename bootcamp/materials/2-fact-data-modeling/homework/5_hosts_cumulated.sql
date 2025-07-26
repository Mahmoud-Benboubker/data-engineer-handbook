/*
- A DDL for `hosts_cumulated` table 
- a `host_activity_datelist` which logs to see which dates each host is experiencing any activity
*/

create  table hosts_cumulated (
host text,
host_activity_datelist date[]
);

insert into hosts_cumulated (
select host, array_agg( distinct event_time::date order by event_time::date ) as host_activity_datelist from events
group by host)
;
