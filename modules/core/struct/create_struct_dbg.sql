create table opas_ot_dbg_monitor (
dbg_id          number                                           primary key,
dblink          varchar2(128)                                    references opas_db_links (db_link_name),
scheme_list     varchar2(4000),
schedule        number                                           references opas_scheduler (sch_id) on delete set null,
size_limit      number default 524288
);

alter table opas_ot_dbg_monitor add constraint fk_dbg_mon_obj foreign key (dbg_id) references opas_objects(obj_id);
create index idx_opas_ot_dbg_monitor_dbl   on opas_ot_dbg_monitor(dblink);
create index idx_opas_ot_dbg_monitor_sch   on opas_ot_dbg_monitor(schedule);

create table opas_ot_dbg_monitor_al_cfg (
alert_id        number                                           generated always as identity primary key,
dbg_id          number                                  not null references opas_ot_dbg_monitor (dbg_id) on delete cascade,
alert_name      varchar2(128)                           not null,
alert_type      varchar2(128)                           not null,
alert_expr      varchar2(1024),
alert_limit     number                                  not null,
alert_measur    varchar2(100),
actual_start    timestamp);

create unique index idx_opas_ot_dbg_mon_acgg_u1   on opas_ot_dbg_monitor_al_cfg(decode(alert_type,'REGEXP', null, alert_type), decode(alert_type,'REGEXP', null, dbg_id));
create index idx_opas_ot_dbg_mon_acgg_m           on opas_ot_dbg_monitor_al_cfg(dbg_id);

create table opas_ot_dbg_monitor_al_cfg_hst (
alert_id        number,
dbg_id          number                                           references opas_ot_dbg_monitor (dbg_id) on delete cascade,
alert_name      varchar2(128),
alert_type      varchar2(128),
alert_expr      varchar2(1024),
alert_limit     number,
alert_measur    varchar2(100),
actual_start    timestamp,
actual_end      timestamp);

--create index idx_opas_ot_dbg_mon_acgg_hst           on opas_ot_dbg_monitor_al_cfg_hst(alert_id);
create index idx_opas_ot_dbg_mon_acgg_hm           on opas_ot_dbg_monitor_al_cfg_hst(dbg_id);

---------------------------------
create table opas_ot_dbg_charts(
apex_sess       number,
created         date,
alert_id        number,
chart_id        number,
dtstamp         timestamp,
chart_val       number);

---------------------------------
create table opas_ot_dbg_datapoint (
dbgdp_id        number                                           generated always as identity (nocache) primary key,
dbg_id          number                                           references opas_ot_dbg_monitor (dbg_id) on delete cascade,
snapped         timestamp
) 
ROW STORE COMPRESS ADVANCED;

create index idx_opas_ot_dbg_dbgm                 on opas_ot_dbg_datapoint(dbg_id, snapped); --???
create index idx_opas_ot_dbg_dbgm2                on opas_ot_dbg_datapoint(dbg_id, dbgdp_id);

create table opas_ot_dbg_ts_sizes (
dbgdp_id         number                                           references opas_ot_dbg_datapoint (dbgdp_id) on delete cascade, 
ts_name          varchar2(128), 
tot_occupied     number, 
bin_occupied     number, 
seg_occupied     number generated always as (tot_occupied - bin_occupied),
tot_free         number, 
curr_available   number,
ext_available    number,
tot_occupied_sch number, 
bin_occupied_sch number
) ROW STORE COMPRESS ADVANCED;
   
create index idx_opas_ot_dbg_tsdp                on opas_ot_dbg_ts_sizes(dbgdp_id);

/*
create table opas_ot_dbg_objects (
dbgobj_id        number                                           generated always as identity primary key,
version_dp_id    number                                           references opas_ot_dbg_datapoint (dbgdp_id) on delete cascade,
dbg_id           number                                           references opas_ot_dbg_monitor (dbg_id) on delete cascade,
owner            varchar2(128),
object_id        number,
data_object_id   number,
object_name      varchar2(128),
subobject_name   varchar2(128),
object_type      varchar2(128),
segment_type     varchar2(128),
tablespace_name  varchar2(128),
created          date,
object_class     varchar2(512),
prnt_table       varchar2(512),
prnt_table_type  varchar2(512),
prnt_table_owner varchar2(512),
prnt_table_col   varchar2(512)) 
ROW STORE COMPRESS ADVANCED;

create index idx_opas_ot_dbg_objdp                on opas_ot_dbg_objects(version_dp_id);

create table opas_ot_dbg_seg_sizes (
dbgdp_id         number not null references opas_ot_dbg_datapoint(dbgdp_id) on delete cascade,
dbgobj_id        number not null references opas_ot_dbg_objects(dbgobj_id) on delete cascade,
size_bytes       number
) 
ROW STORE COMPRESS ADVANCED;

create index idx_opas_ot_dbg_segsdp               on opas_ot_dbg_seg_sizes(dbgdp_id);
create index idx_opas_ot_dbg_segsobj              on opas_ot_dbg_seg_sizes(dbgobj_id);
--create index idx_opas_ot_dbg_segsf                on opas_ot_dbg_seg_sizes(dbgdp_id, dbgobj_id, size_bytes) compress;
*/
						
create sequence opas_ot_sq_dbg_obj;
																																	  
-- start partitioned --
-- starting state
create table opas_ot_dbg_objects (
dbgobj_id        number                                           primary key,
version_dp_id    number                                           references opas_ot_dbg_datapoint (dbgdp_id) on delete cascade,
dbg_id           number                                           references opas_ot_dbg_monitor (dbg_id) on delete cascade,
owner            varchar2(128),
object_id        number,
data_object_id   number,
object_name      varchar2(128),
subobject_name   varchar2(128),
object_type      varchar2(128),
segment_type     varchar2(128),
tablespace_name  varchar2(128),
created          date,
object_class     varchar2(512),
prnt_table       varchar2(512),
prnt_table_type  varchar2(512),
prnt_table_owner varchar2(512),
prnt_table_col   varchar2(512))
PARTITION BY LIST (dbg_id)
(
   PARTITION part_start values (1)
)
ROW STORE COMPRESS ADVANCED;
--indexes ???

create index IDX_DBGSZ_OBJ on OPAS_OT_DBG_SEG_SIZES(DBGOBJ_ID) local;

----------------------
CREATE TABLE opas_ot_dbg_seg_sizes (
dbg_id           number not null references opas_ot_dbg_monitor (dbg_id) on delete cascade,
dbgdp_id         number not null references opas_ot_dbg_datapoint(dbgdp_id) on delete cascade,
dbgobj_id        number not null references opas_ot_dbg_objects(dbgobj_id) on delete cascade,
size_bytes       number
)
PARTITION BY LIST (dbg_id)
SUBPARTITION BY range (dbgdp_id)
(
   PARTITION part_start values (1)
      (
         SUBPARTITION sp_start_max values LESS THAN (maxvalue)
      )
) ROW STORE COMPRESS ADVANCED;
--indexes ???
-- end partitioned --

create global temporary table opas_ot_tmp_dbg_objects (
owner            varchar2(128),
object_id        number,
data_object_id   number,
object_name      varchar2(128),
subobject_name   varchar2(128),
object_type      varchar2(128),
segment_type     varchar2(128),
tablespace_name  varchar2(128),
created          date,
size_bytes       number,
dbgobj_id        number
) on commit preserve rows;

create global temporary table opas_ot_tmp_dbg_clusters (
owner            varchar2(128), 
cluster_name     varchar2(128),
cluster_type     varchar2(128)
) on commit preserve rows;  

create global temporary table opas_ot_tmp_dbg_tables (
owner            varchar2(128), 
table_name       varchar2(128), 
cluster_name     varchar2(128),
iot_name         varchar2(128),
iot_type         varchar2(128)
) on commit preserve rows;  

create global temporary table opas_ot_tmp_dbg_indexes (
owner            varchar2(128), 
index_name       varchar2(128), 
index_type       varchar2(27), 
table_owner      varchar2(128), 
table_name       varchar2(128), 
table_type       varchar2(11)
) on commit preserve rows;

create global temporary table opas_ot_tmp_dbg_lobs (
owner            varchar2(128), 
table_name       varchar2(128), 
column_name      varchar2(4000), 
segment_name     varchar2(128), 
tablespace_name  varchar2(30), 
index_name       varchar2(128)
) on commit preserve rows;

create global temporary table opas_ot_tmp_dbg_lob_ps (
table_owner      varchar2(128), 
table_name       varchar2(128), 
column_name      varchar2(4000), 
lob_name         varchar2(128), 
part_name        varchar2(128),
sub_part_name    varchar2(128),
lob_part_name    varchar2(128),
lob_indpart_name varchar2(128),
lob_subpart_name    varchar2(128),
lob_indsubpart_name varchar2(128),
tablespace_name  varchar2(128)
) on commit preserve rows;

create global temporary table opas_ot_tmp_dbg_nt (
owner               varchar2(128), 
table_name          varchar2(128),
parent_table_name   varchar2(128), 
parent_table_column varchar2(128)
) on commit preserve rows;

create global temporary table opas_ot_tmp_dbg_xml (
owner               varchar2(128), 
table_name          varchar2(128),
xmlschema_name      varchar2(1024), 
schema_owner        varchar2(128),
element_name        varchar2(128),
storage_type        varchar2(128)
) on commit preserve rows;

/*
CREATE OR REPLACE CONTEXT OPAS_CONTEXT USING COREMOD_CONTEXT;

create or replace view v$opas_dbg_selected_objects as
select *
    from opas_ot_dbg_objects o, opas_ot_dbg_datapoint dp
   where o.version_dp_id = dp.dbgdp_id 
     and dp.dbg_id = SYS_CONTEXT('OPAS_CONTEXT','DBGSO_DBG_ID')
     and (SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE') is null or 
            (
             (SYS_CONTEXT('OPAS_CONTEXT','DBGSO_INVERSE') = 'N' and
               ((regexp_like (prnt_table,       SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_PRNT_TABLE')      = 'Y') or
                (regexp_like (prnt_table_type,  SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_PRNT_TABLE_TYPE') = 'Y') or
                (regexp_like (object_class,     SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_OBJECT_CLASS')    = 'Y') or
                (regexp_like (object_type,      SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_OBJECT_TYPE')     = 'Y') or
                (regexp_like (segment_type,     SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_SEGMENT_TYPE')    = 'Y') or
                (regexp_like (object_name,      SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_OBJECT_NAME')     = 'Y') or
                (regexp_like (subobject_name,   SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_SUBOBJECT_NAME')  = 'Y') or
                (regexp_like (tablespace_name,  SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLESPACE_NAME') = 'Y')
               )
              ) 
              or
             (SYS_CONTEXT('OPAS_CONTEXT','DBGSO_INVERSE') = 'Y' and 
               ((not regexp_like (prnt_table,       SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_PRNT_TABLE')      = 'Y') or
                (not regexp_like (prnt_table_type,  SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_PRNT_TABLE_TYPE') = 'Y') or
                (not regexp_like (object_class,     SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_OBJECT_CLASS')    = 'Y') or
                (not regexp_like (object_type,      SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_OBJECT_TYPE')     = 'Y') or
                (not regexp_like (segment_type,     SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_SEGMENT_TYPE')    = 'Y') or                
                (not regexp_like (object_name,      SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_OBJECT_NAME')     = 'Y') or
                (not regexp_like (subobject_name,   SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_SUBOBJECT_NAME')  = 'Y') or
                (not regexp_like (tablespace_name,  SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLE_NAME_LIKE'), 'i') and SYS_CONTEXT('OPAS_CONTEXT','DBGSO_TABLESPACE_NAME') = 'Y')
               )             
            )
           )
         );
        
*/
create table opas_ot_dbg_report_pars(
apex_sess                number,
created                  date,
DBGSO_DBG_ID             number,
DBGSO_START_SNAP         number,
DBGSO_END_SNAP           number,
DBGSO_TABLE_NAME_LIKE    varchar2(4000),
DBGSO_INVERSE            varchar2(1),
DBGSO_PRNT_TABLE         varchar2(1),
DBGSO_PRNT_TABLE_TYPE    varchar2(1),
DBGSO_OBJECT_CLASS       varchar2(1),
DBGSO_OBJECT_TYPE        varchar2(1),
DBGSO_SEGMENT_TYPE       varchar2(1),
DBGSO_OBJECT_NAME        varchar2(1),
DBGSO_SUBOBJECT_NAME     varchar2(1),
DBGSO_TABLESPACE_NAME    varchar2(1)
);

create or replace force view v$opas_dbg_selected_objects as
  select /*+ no_merge leading(p dp o) index(dp idx_opas_ot_dbg_dbgm)*/ 
         dp.snapped start_date,
         lead(dp.snapped, 1, systimestamp + to_dsinterval('01 00:00:00')) over(partition by o.object_name, o.subobject_name order by dp.snapped) end_date,
         o.*, 
         dp.*, 
         p.apex_sess, 
         p.created params_created
    from opas_ot_dbg_objects o, opas_ot_dbg_datapoint dp, opas_ot_dbg_report_pars p
   where p.apex_sess = V('SESSION')
     and o.version_dp_id = dp.dbgdp_id 
     and dp.dbg_id = DBGSO_DBG_ID
     and (DBGSO_TABLE_NAME_LIKE is null or 
            (
             (DBGSO_INVERSE = 'N' and
               ((regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                (regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                (regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                (regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                (regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or
                (regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                (regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                (regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
               )
              ) 
              or
             (DBGSO_INVERSE = 'Y' and 
               ((not regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                (not regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                (not regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                (not regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                (not regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or                
                (not regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                (not regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                (not regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
               )             
            )
           )
         );
/*         
CREATE OR REPLACE VIEW V$OPAS_DBG_SELECTED_OBJECTS_V2 AS
select 
       dp.dbgdp_id, dp.snapped,
       s.size_bytes,
       o.*,
       p.apex_sess,
       p.created params_created
  from opas_ot_dbg_datapoint dp,
       opas_ot_dbg_seg_sizes s,
       opas_ot_dbg_objects   o, 
       opas_ot_dbg_report_pars p
 where p.apex_sess = V('SESSION')
   and s.dbgobj_id = o.dbgobj_id
   and dp.dbgdp_id = s.dbgdp_id
   and dp.dbg_id = p.DBGSO_DBG_ID
   and (DBGSO_TABLE_NAME_LIKE is null or
            (
             (DBGSO_INVERSE = 'N' and
               ((regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                (regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                (regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                (regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                (regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or
                (regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                (regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                (regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
               )
              )
              or
             (DBGSO_INVERSE = 'Y' and
               ((not regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                (not regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                (not regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                (not regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                (not regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or
                (not regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                (not regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                (not regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
               )
            )
           )
         );
*/
/*
CREATE OR REPLACE VIEW V$OPAS_DBG_SELECTED_OBJECTS_V2 AS
select / result_cache / * from (
select x.*, 
       sum(size_bytes)over(partition by dbgdp_id) dp_tot, 
       sum(delta)over(partition by dbgdp_id) dp_tot_delta, 
       sum(case when delta < 0 then delta else 0 end)over(partition by dbgdp_id) dp_tot_shrink,
       sum(case when delta > 0 then delta else 0 end)over(partition by dbgdp_id) dp_tot_growth      
  from (select rn,
               dbgobj_id,
               dbgdp_id,
               size_bytes,
               decode(rn, 1, 0, delta) delta
          from (with datapoints as (select dp.dbgdp_id,
                                           dp.dbg_id,
                                           dp.snapped,
                                           row_number() over(order by dp.dbgdp_id) rn
                                      from opas_ot_dbg_datapoint dp, OPAS_OT_DBG_REPORT_PARS p
                                     where dp.dbg_id = p.DBGSO_DBG_ID
                                       and dp.dbgdp_id between nvl(p.DBGSO_START_SNAP,0) and p.DBGSO_END_SNAP),-- select * from datapoints, 
                        objects as (select o.dbgobj_id
                                      from opas_ot_dbg_objects o,
                                           OPAS_OT_DBG_REPORT_PARS p
                                     where o.dbg_id = p.DBGSO_DBG_ID and
                                           (DBGSO_TABLE_NAME_LIKE is null or 
                                            (
                                             (DBGSO_INVERSE = 'N' and
                                               ((regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                                                (regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                                                (regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                                                (regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                                                (regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or
                                                (regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                                                (regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                                                (regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
                                               )
                                              ) 
                                              or
                                             (DBGSO_INVERSE = 'Y' and 
                                               ((not regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                                                (not regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                                                (not regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                                                (not regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                                                (not regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or                
                                                (not regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                                                (not regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                                                (not regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
                                               )             
                                            )
                                           )
                                         )),--select * from objects,
                          object_dp as (select * from objects, datapoints), -- select * from object_dp
                          data1 as (select o.rn, o.dbgdp_id, o.dbgobj_id, s.size_bytes
                                      from object_dp o, opas_ot_dbg_seg_sizes s
                                     where o.dbgdp_id = s.dbgdp_id(+)
                                       and o.dbgobj_id = s.dbgobj_id(+))
                 select *
                   from data1
                 model dimension by(rn, dbgobj_id) 
                 measures(dbgdp_id, size_bytes, 0 as delta) 
                 ignore nav 
                 rules(delta [ any, any ] = size_bytes [ cv(), cv() ] - size_bytes [ cv() - 1, cv() ]))
        ) x ) y where delta <> 0;
*/

----
CREATE OR REPLACE force VIEW V$OPAS_DBG_SELECTED_OBJECTS_V3 AS
select /*+ leading(p o dp s) use_hash(o) use_hash(s) use_hash(dp) swap_join_inputs(dp) */ 
       dp.dbgdp_id,dp.snapped,
       s.size_bytes,
       o.*
  from opas_ot_dbg_datapoint dp,
       opas_ot_dbg_seg_sizes s,
       opas_ot_dbg_objects   o, 
       opas_ot_dbg_report_pars p
 where p.apex_sess = V('SESSION')
   and s.dbgobj_id = o.dbgobj_id
   and dp.dbgdp_id = s.dbgdp_id
   and dp.dbg_id = p.DBGSO_DBG_ID
   and o.dbg_id = p.DBGSO_DBG_ID
   and (dp.dbgdp_id >= nvl(dbgso_start_snap,0))
   and (dp.dbgdp_id <= dbgso_end_snap)
   and (s.dbgdp_id >= nvl(dbgso_start_snap,0))
   and (s.dbgdp_id <= dbgso_end_snap) 
   and (DBGSO_TABLE_NAME_LIKE is null or
            (
             (DBGSO_INVERSE = 'N' and
               (DBGSO_PRNT_TABLE      = 'Y' and (regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_PRNT_TABLE_TYPE = 'Y' and (regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_OBJECT_CLASS    = 'Y' and (regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_OBJECT_TYPE     = 'Y' and (regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_SEGMENT_TYPE    = 'Y' and (regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_OBJECT_NAME     = 'Y' and (regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_SUBOBJECT_NAME  = 'Y' and (regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_TABLESPACE_NAME = 'Y' and (regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i'))
               )
              )
              or
             (DBGSO_INVERSE = 'Y' and
               (DBGSO_PRNT_TABLE      = 'Y' and (not regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_PRNT_TABLE_TYPE = 'Y' and (not regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_OBJECT_CLASS    = 'Y' and (not regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_OBJECT_TYPE     = 'Y' and (not regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_SEGMENT_TYPE    = 'Y' and (not regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_OBJECT_NAME     = 'Y' and (not regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_SUBOBJECT_NAME  = 'Y' and (not regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i')) or
                DBGSO_TABLESPACE_NAME = 'Y' and (not regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i'))
               )
            )
           )
         ); 

--!
CREATE OR REPLACE force VIEW V$OPAS_DBG_SELECTED_OBJECTS_V3P AS
select /*+ leading(dp o s) use_hash(o) use_hash(s) */
       dp.dbgdp_id,dp.snapped,
       s.size_bytes,
       o.*
  from (select /*+ no_merge leading(p1 dp1) use_nl(dp1) no_push_pred */ dp1.dbgdp_id, dp1.snapped, dp1.dbg_id
          from opas_ot_dbg_datapoint dp1, opas_ot_dbg_report_pars p1
         where p1.apex_sess = V('SESSION')
           and dp1.dbg_id = p1.DBGSO_DBG_ID
           and dp1.dbgdp_id >= nvl(p1.dbgso_start_snap,0)
           and dp1.dbgdp_id <=     p1.dbgso_end_snap) dp,
       (select /*+ no_merge leading(p1 s1) use_nl(s1) */ s1.size_bytes, s1.dbgobj_id, s1.dbgdp_id
         from opas_ot_dbg_seg_sizes s1, opas_ot_dbg_report_pars p1
        where s1.dbg_id = p1.DBGSO_DBG_ID
          and p1.apex_sess = V('SESSION')
          and s1.dbgdp_id >= nvl(p1.dbgso_start_snap,0)
          and s1.dbgdp_id <= p1.dbgso_end_snap) s,
       (select /*+ no_merge leading(p1 o1) use_nl(o1) full(o1) */ o1.*
          from opas_ot_dbg_objects o1, opas_ot_dbg_report_pars p1
         where o1.dbg_id = p1.DBGSO_DBG_ID
           and p1.apex_sess = V('SESSION')
           and (DBGSO_TABLE_NAME_LIKE is null or
            (
             (DBGSO_INVERSE = 'N' and
               ((regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                (regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                (regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                (regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                (regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or
                (regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                (regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                (regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
               )
              )
              or
             (DBGSO_INVERSE = 'Y' and
               ((not regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                (not regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                (not regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                (not regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                (not regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or
                (not regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                (not regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                (not regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
               )
            )
           )
         ) ) o
 where s.dbgobj_id = o.dbgobj_id
   and dp.dbgdp_id = s.dbgdp_id
   and dp.dbg_id = o.dbg_id;

--!
CREATE OR REPLACE force VIEW V$OPAS_DBG_SELECTED_OBJECTS_V3PG1 AS
select /*+ leading(dp o s) use_hash(o) use_hash(s) */
       dp.dbgdp_id,dp.snapped,
       s.size_bytes,
       o."DBGOBJ_ID",o."VERSION_DP_ID",o."DBG_ID",o."OWNER",o."OBJECT_ID",o."DATA_OBJECT_ID",o."OBJECT_NAME",o."SUBOBJECT_NAME",o."OBJECT_TYPE",o."SEGMENT_TYPE",o."TABLESPACE_NAME",o."CREATED",o."OBJECT_CLASS",o."PRNT_TABLE",o."PRNT_TABLE_TYPE",o."PRNT_TABLE_OWNER",o."PRNT_TABLE_COL"
  from (select /*+ no_merge leading(p1 dp1) use_nl(dp1) no_push_pred */ dp1.dbgdp_id, dp1.snapped, dp1.dbg_id
          from opas_ot_dbg_datapoint dp1, opas_ot_dbg_report_pars p1
         where p1.apex_sess = V('SESSION')
           and dp1.dbg_id = p1.DBGSO_DBG_ID
           and dp1.dbgdp_id in ( nvl(p1.dbgso_start_snap,0), p1.dbgso_end_snap )) dp,
       (select /*+ no_merge leading(p1 s1) use_nl(s1) */ s1.size_bytes, s1.dbgobj_id, s1.dbgdp_id
         from opas_ot_dbg_seg_sizes s1, opas_ot_dbg_report_pars p1
        where s1.dbg_id = p1.DBGSO_DBG_ID
          and p1.apex_sess = V('SESSION')
          and s1.dbgdp_id = p1.dbgso_start_snap--, p1.dbgso_end_snap)
          ) s,
       (select /*+ no_merge leading(p1 o1) use_nl(o1) full(o1) */ o1.*
          from opas_ot_dbg_objects o1, opas_ot_dbg_report_pars p1
         where o1.dbg_id = p1.DBGSO_DBG_ID
           and p1.apex_sess = V('SESSION')
           and (DBGSO_TABLE_NAME_LIKE is null or
            (
             (DBGSO_INVERSE = 'N' and
               ((regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                (regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                (regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                (regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                (regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or
                (regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                (regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                (regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
               )
              )
              or
             (DBGSO_INVERSE = 'Y' and
               ((not regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                (not regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                (not regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                (not regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                (not regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or
                (not regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                (not regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                (not regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
               )
            )
           )
         ) ) o
 where s.dbgobj_id = o.dbgobj_id
   and dp.dbgdp_id = s.dbgdp_id
   and dp.dbg_id = o.dbg_id
;
--!
CREATE OR REPLACE force VIEW V$OPAS_DBG_SELECTED_OBJECTS_V3PG2 AS
select /*+ leading(dp o s) use_hash(o) use_hash(s) */
       dp.dbgdp_id,dp.snapped,
       s.size_bytes,
       o."DBGOBJ_ID",o."VERSION_DP_ID",o."DBG_ID",o."OWNER",o."OBJECT_ID",o."DATA_OBJECT_ID",o."OBJECT_NAME",o."SUBOBJECT_NAME",o."OBJECT_TYPE",o."SEGMENT_TYPE",o."TABLESPACE_NAME",o."CREATED",o."OBJECT_CLASS",o."PRNT_TABLE",o."PRNT_TABLE_TYPE",o."PRNT_TABLE_OWNER",o."PRNT_TABLE_COL"
  from (select /*+ no_merge leading(p1 dp1) use_nl(dp1) no_push_pred */ dp1.dbgdp_id, dp1.snapped, dp1.dbg_id
          from opas_ot_dbg_datapoint dp1, opas_ot_dbg_report_pars p1
         where p1.apex_sess = V('SESSION')
           and dp1.dbg_id = p1.DBGSO_DBG_ID
           and dp1.dbgdp_id in ( nvl(p1.dbgso_start_snap,0), p1.dbgso_end_snap )) dp,
       (select /*+ no_merge leading(p1 s1) use_nl(s1) */ s1.size_bytes, s1.dbgobj_id, s1.dbgdp_id
         from opas_ot_dbg_seg_sizes s1, opas_ot_dbg_report_pars p1
        where s1.dbg_id = p1.DBGSO_DBG_ID
          and p1.apex_sess = V('SESSION')
          and s1.dbgdp_id = p1.dbgso_end_snap
          ) s,
       (select /*+ no_merge leading(p1 o1) use_nl(o1) full(o1) */ o1.*
          from opas_ot_dbg_objects o1, opas_ot_dbg_report_pars p1
         where o1.dbg_id = p1.DBGSO_DBG_ID
           and p1.apex_sess = V('SESSION')
           and (DBGSO_TABLE_NAME_LIKE is null or
            (
             (DBGSO_INVERSE = 'N' and
               ((regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                (regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                (regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                (regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                (regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or
                (regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                (regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                (regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
               )
              )
              or
             (DBGSO_INVERSE = 'Y' and
               ((not regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                (not regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                (not regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                (not regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                (not regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or
                (not regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                (not regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                (not regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
               )
            )
           )
         ) ) o
 where s.dbgobj_id = o.dbgobj_id
   and dp.dbgdp_id = s.dbgdp_id
   and dp.dbg_id = o.dbg_id;

----
CREATE OR REPLACE force VIEW V$OPAS_DBG_SELECTED_OBJECTS_V3PG AS
select /*+ leading(dp o s) use_hash(o) use_hash(s) */ 
       dp.dbgdp_id,dp.snapped,
       s.size_bytes,
       o.*
  from (select /*+ no_merge leading(p1 dp1) use_nl(dp1) no_push_pred */ dp1.dbgdp_id, dp1.snapped, dp1.dbg_id
          from opas_ot_dbg_datapoint dp1, opas_ot_dbg_report_pars p1
         where p1.apex_sess = V('SESSION')
           and dp1.dbg_id = p1.DBGSO_DBG_ID
           and dp1.dbgdp_id in ( nvl(p1.dbgso_start_snap,0), p1.dbgso_end_snap )) dp,
       (select /*+ no_merge leading(p1 s1) use_nl(s1) */ s1.size_bytes, s1.dbgobj_id, s1.dbgdp_id
         from opas_ot_dbg_seg_sizes s1, opas_ot_dbg_report_pars p1
        where s1.dbg_id = p1.DBGSO_DBG_ID
          and p1.apex_sess = V('SESSION')
          and s1.dbgdp_id in ( nvl(p1.dbgso_start_snap,0), p1.dbgso_end_snap)) s,
       (select /*+ no_merge leading(p1 o1) use_nl(o1) full(o1) */ o1.*
          from opas_ot_dbg_objects o1, opas_ot_dbg_report_pars p1
         where o1.dbg_id = p1.DBGSO_DBG_ID
           and p1.apex_sess = V('SESSION')
           and (DBGSO_TABLE_NAME_LIKE is null or
            (
             (DBGSO_INVERSE = 'N' and
               ((regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                (regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                (regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                (regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                (regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or
                (regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                (regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                (regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
               )
              )
              or
             (DBGSO_INVERSE = 'Y' and
               ((not regexp_like (prnt_table,       DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE      = 'Y') or
                (not regexp_like (prnt_table_type,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_PRNT_TABLE_TYPE = 'Y') or
                (not regexp_like (object_class,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_CLASS    = 'Y') or
                (not regexp_like (object_type,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_TYPE     = 'Y') or
                (not regexp_like (segment_type,     DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SEGMENT_TYPE    = 'Y') or
                (not regexp_like (object_name,      DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_OBJECT_NAME     = 'Y') or
                (not regexp_like (subobject_name,   DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_SUBOBJECT_NAME  = 'Y') or
                (not regexp_like (tablespace_name,  DBGSO_TABLE_NAME_LIKE, 'i') and DBGSO_TABLESPACE_NAME = 'Y')
               )
            )
           )
         ) ) o  
 where s.dbgobj_id = o.dbgobj_id
   and dp.dbgdp_id = s.dbgdp_id
   and dp.dbg_id = o.dbg_id;
--!  
create or replace force view v$opas_dbg_selected_objects_delta as
select filtered_total,
       COREMOD_REPORT_UTILS.to_hr_sz(filtered_total) filtered_total_h,
       filtered_delta,
       COREMOD_REPORT_UTILS.to_hr_sz(filtered_delta) filtered_delta_h
from (
select
     sum(case when dbgdp_id = dbgso_end_snap then size_bytes else 0 end) filtered_total,
     sum(size_bytes) filtered_delta
  from (select dbgdp_id, dbgso_start_snap, dbgso_end_snap,
                 case when dbgdp_id = dbgso_start_snap then -1 else 1 end * size_bytes size_bytes
          from (select dbgdp_id, snapped, sum(size_bytes) size_bytes, dbgso_start_snap, dbgso_end_snap
                  from v$opas_dbg_selected_objects_v3p dat1,
                       opas_ot_dbg_report_pars          pars
                 where dbgdp_id in (dbgso_start_snap, dbgso_end_snap) and pars.apex_sess = V('SESSION')
                 group by dbgdp_id, snapped, dbgso_start_snap, dbgso_end_snap)))
 where filtered_delta is not null;

--!
create or replace force view v$opas_dbg_total_delta as
select tot_occupied,
       COREMOD_REPORT_UTILS.to_hr_sz(tot_occupied) tot_occupied_h,
       tot_occupied_sch,
       COREMOD_REPORT_UTILS.to_hr_sz(tot_occupied_sch) tot_occupied_sch_h,
       tot_occupied_delta,
       COREMOD_REPORT_UTILS.to_hr_sz(tot_occupied_delta) tot_occupied_delta_h,
       tot_occupied_sch_delta,
       COREMOD_REPORT_UTILS.to_hr_sz(tot_occupied_sch_delta) tot_occupied_sch_delta_h
  from (select tot_occupied,
               tot_occupied_sch,
               case when dbgso_start_snap is not null
                 then tot_occupied - lag(tot_occupied) over(order by dbgdp_id)
                 else tot_occupied
                 end tot_occupied_delta,
               case when dbgso_start_snap is not null
                 then tot_occupied_sch - lag(tot_occupied_sch) over(order by dbgdp_id)
                 else tot_occupied_sch
                 end tot_occupied_sch_delta
          from (select dbgdp_id, sum(tot_occupied) tot_occupied, sum(tot_occupied_sch) tot_occupied_sch, dbgso_start_snap, dbgso_end_snap
                  from opas_ot_dbg_ts_sizes dat2,
                       opas_ot_dbg_report_pars          pars
                 where dbgdp_id in (dbgso_start_snap, dbgso_end_snap) and pars.apex_sess = V('SESSION')
                 group by dbgdp_id, dbgso_start_snap, dbgso_end_snap))
 where tot_occupied_delta is not null;
--!
create or replace force view v$opas_dbg_sel_objects_det_delta as
with
  pars as (select * from opas_ot_dbg_report_pars pars where apex_sess = V('SESSION')),
  dat1 as (select /*+ materialize */ d1.* from v$opas_dbg_selected_objects_v3pg1 d1),
  dat2 as (select /*+ materialize */ d2.* from v$opas_dbg_selected_objects_v3pg2 d2)
select
  parent_table, sub_object,
  seg_delta,    COREMOD_REPORT_UTILS.to_hr_sz(seg_delta) seg_delta_h,
  sum(seg_delta) over () tot_seg_delta, COREMOD_REPORT_UTILS.to_hr_sz(sum(seg_delta) over ()) tot_seg_delta_h,
  seg_total,    COREMOD_REPORT_UTILS.to_hr_sz(seg_total) seg_total_h,
  parent_delta, COREMOD_REPORT_UTILS.to_hr_sz(parent_delta) parent_delta_h,
  parent_total, COREMOD_REPORT_UTILS.to_hr_sz(parent_total) parent_total_h,
  DENSE_RANK() OVER (order by parent_delta desc, parent_table) rn1,
  row_number() OVER (partition by parent_table order by seg_delta desc) rn2
from (
select
  parent_table, sub_object, seg_delta, seg_total,
  sum(seg_delta) over (partition by parent_table) parent_delta,
  sum(seg_total) over (partition by parent_table) parent_total,
  dbgdp_id
from (
select *
  from (select /* use_hash(dat1) use_hash(dat2) */
               nvl(dat1.prnt_table,dat2.prnt_table) || ' (' || nvl(dat1.prnt_table_type,dat2.prnt_table_type) || ')' parent_table,
               nvl(dat1.object_type,dat2.object_type) || ': ' || nvl(dat1.object_name,dat2.object_name) ||
                 case when nvl(dat1.subobject_name,dat2.subobject_name) is not null then '.' || nvl(dat1.subobject_name,dat2.subobject_name) end
                 || ' (' || nvl(dat1.object_class,dat2.object_class) || ')' sub_object,
               nvl(dat1.dbgdp_id, dat2.dbgdp_id) dbgdp_id,
               nvl(dat2.size_bytes,0) seg_total,
               nvl(dat2.size_bytes,0) - nvl(dat1.size_bytes,0) seg_delta
               --dat1.*,
               --dat2.*,
               --pars.*
          from dat1 full outer join dat2
               on (dat1.prnt_table = dat2.prnt_table and
                   dat1.prnt_table_type = dat2.prnt_table_type and
                   dat1.object_type = dat2.object_type and
                   dat1.object_name = dat2.object_name and
                   decode(dat1.subobject_name,dat2.subobject_name,1,0)=1
                  )
           )
) where seg_delta > 0);

--!
create or replace force view v$opas_dbg_sel_objects_det_delta_n as
with
  pars as (select * from opas_ot_dbg_report_pars pars where apex_sess = V('SESSION')),
  dat1 as (select /*+ materialize */ d1.* from v$opas_dbg_selected_objects_v3pg1 d1),
  dat2 as (select /*+ materialize */ d2.* from v$opas_dbg_selected_objects_v3pg2 d2)
select
  parent_table, sub_object,
  seg_delta,    COREMOD_REPORT_UTILS.to_hr_sz(seg_delta) seg_delta_h,
  sum(seg_delta) over () tot_seg_delta, COREMOD_REPORT_UTILS.to_hr_sz(sum(seg_delta) over ()) tot_seg_delta_h,
  seg_total,    COREMOD_REPORT_UTILS.to_hr_sz(seg_total) seg_total_h,
  parent_delta, COREMOD_REPORT_UTILS.to_hr_sz(parent_delta) parent_delta_h,
  parent_total, COREMOD_REPORT_UTILS.to_hr_sz(parent_total) parent_total_h,
  --DENSE_RANK() OVER (order by parent_delta desc, parent_table) rn1,
  row_number() OVER (order by seg_delta ) rn1
from (
select
  parent_table, sub_object, seg_delta, seg_total,
  sum(seg_delta) over (partition by parent_table) parent_delta,
  sum(seg_total) over (partition by parent_table) parent_total,
  dbgdp_id
from (
select *
  from (select /* use_hash(dat1) use_hash(dat2) */
               nvl(dat1.prnt_table,dat2.prnt_table) || ' (' || nvl(dat1.prnt_table_type,dat2.prnt_table_type) || ')' parent_table,
               nvl(dat1.object_type,dat2.object_type) || ': ' || nvl(dat1.object_name,dat2.object_name) ||
                 case when nvl(dat1.subobject_name,dat2.subobject_name) is not null then '.' || nvl(dat1.subobject_name,dat2.subobject_name) end
                 || ' (' || nvl(dat1.object_class,dat2.object_class) || ')' sub_object,
               nvl(dat1.dbgdp_id, dat2.dbgdp_id) dbgdp_id,
               nvl(dat2.size_bytes,0) seg_total,
               nvl(dat2.size_bytes,0) - nvl(dat1.size_bytes,0) seg_delta
               --dat1.*,
               --dat2.*,
               --pars.*
          from dat1 full outer join dat2
               on (dat1.prnt_table = dat2.prnt_table and
                   dat1.prnt_table_type = dat2.prnt_table_type and
                   dat1.object_type = dat2.object_type and
                   dat1.object_name = dat2.object_name and
                   decode(dat1.subobject_name,dat2.subobject_name,1,0)=1
                  )
           )
) where seg_delta < 0 );

