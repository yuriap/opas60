---------------------------------------------------------------------------------------------
-- Simple DB metric monitor
create table opas_ot_db_monitor (
metric_id       number                                           primary key,
dblink          varchar2(128)                                    references opas_db_links (db_link_name),
schedule        number                                           references opas_scheduler (sch_id) on delete set null,
call_type       varchar2(512)                           not null check (call_type in ('SQL','FUNC')),
calc_code       varchar2(512),
convert_code    varchar2(1000),
measure         varchar2(32)
);

alter table opas_ot_db_monitor add constraint fk_ot_db_mon_obj foreign key (metric_id) references opas_objects(obj_id) on delete cascade;
create index idx_opas_ot_db_monitor_dbl   on opas_ot_db_monitor(dblink);
create index idx_opas_ot_db_monitor_sch   on opas_ot_db_monitor(schedule);

create table opas_ot_db_monitor_vals_t (
measur_id       number                                           generated always as identity primary key,
metric_id       number                                           references opas_ot_db_monitor (metric_id) on delete cascade,
tim_tz          timestamp(6) WITH TIME ZONE,
val             number) row store compress advanced;

create index idx_opas_ot_db_monitor_vm   on opas_ot_db_monitor_vals_t(metric_id);

create or replace view opas_ot_db_monitor_vals as
SELECT
    metric_id,
    to_timestamp(to_char(tim_tz at local,'yyyymmddhh24miss.ff6'),'yyyymmddhh24miss.ff6') tim,
    val,
    measur_id
FROM
    opas_ot_db_monitor_vals_t;

create table opas_ot_db_monitor_alerts_cfg (
metric_id       number                                           references opas_ot_db_monitor (metric_id) on delete cascade,
alert_type      varchar2(128),
alert_limit     number,
limit_actual    varchar2(1) default 'Y',
actual_start    timestamp,
actual_end      timestamp);

create unique index idx_opas_ot_db_mon_acgg_u1   on opas_ot_db_monitor_alerts_cfg(decode(limit_actual,'Y', metric_id, null), decode(limit_actual,'Y', alert_type, null));
create index idx_opas_ot_db_mon_acgg_m    on opas_ot_db_monitor_alerts_cfg(metric_id);

create table opas_ot_db_chart_lists(
apex_sess       number,
created         date,
metric_id       number,
chart_id        number,
chart_name      varchar2(1000));

create table opas_ot_db_dashboard(
apex_user       varchar2(128) primary key,
last_modified   date,
start_dt        timestamp WITH TIME ZONE,
end_dt          timestamp WITH TIME ZONE,
data_interv     INTERVAL DAY(3) TO SECOND,
refresh_int     number);

create table opas_ot_db_dashboard_graphs(
apex_user       varchar2(128) references opas_ot_db_dashboard (apex_user),
graph_num       number,
metric_id       number,
chart_id        number,
chart_name      varchar2(1000));

--********************************************************************************

create table opas_ot_db_mon_hist (
dbmh_id         number                                           generated always as identity primary key,
dbmh_name       varchar2(256),
dbmh_buckets    varchar2(4000),
dbmh_stat       varchar2(4000),
dblink          varchar2(128)                                    references opas_db_links (db_link_name),
schedule        varchar2(512),
start_date      date,
last_exec_ts    timestamp,
status          varchar2(10),
calc_type       varchar2(10) default 'REGULAR' --REGULAR, DELTA
);

create table opas_ot_db_mon_hist_sess (
sess_id         number                                           generated always as identity primary key,
dbmh_id         number                                 not null  references opas_ot_db_mon_hist(dbmh_id) on delete cascade,
tim_tz          timestamp(6) WITH TIME ZONE,
status          varchar2(1) default 'R' -- S - snapshot, R - ready
);

create table opas_ot_db_mon_hist_data (
sess_id         number                                 not null  references opas_ot_db_mon_hist_sess(sess_id) on delete cascade,
inst_id         number,
range#          number,
quantity        number)
row store compress advanced;


CREATE OR REPLACE VIEW OPAS_OT_DB_MON_HIST_VALS AS
SELECT
    s.dbmh_id,s.sess_id,
	s.tim_tz,
    to_timestamp(to_char(s.tim_tz at local,'yyyymmddhh24miss.ff6'),'yyyymmddhh24miss.ff6') tim_ts,
    to_date(to_char(s.tim_tz at local,'yyyymmddhh24miss'),'yyyymmddhh24miss') tim_dt,
    d.inst_id,d.range#,d.quantity
FROM
    opas_ot_db_mon_hist_sess s,
    opas_ot_db_mon_hist_data d
where s.sess_id = d.sess_id and s.status = 'R';