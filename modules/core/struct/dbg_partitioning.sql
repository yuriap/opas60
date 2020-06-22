spool dbg_partitioning.log
set echo on

delete from opas_ot_dbg_objects where (dbg_id,prnt_table) in (
select unique dbg_id, prnt_table
  from (select dbg_id, prnt_table, max(sz) max_sz
          from (select o.dbg_id, s.dbgdp_id, o.prnt_table, sum(size_bytes) sz
                  from opas_ot_dbg_objects o, opas_ot_dbg_seg_sizes s
                 where o.dbgobj_id = s.dbgobj_id
                 group by o.dbg_id, s.dbgdp_id, o.prnt_table)
         group by dbg_id, prnt_table
        having max(sz) <= 1024 * 1024/2/2));
commit;

alter table OPAS_OT_DBG_DATAPOINT modify dbgdp_id number  generated always as identity (nocache);

drop table opas_ot_dbg_seg_sizes_p;
drop table opas_ot_dbg_objects_p;
drop sequence opas_ot_sq_dbg_obj;

create table opas_ot_dbg_objects_p (
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

begin
  for i in (select unique dbg_id from opas_ot_dbg_objects order by 1)
  loop
    execute immediate 'alter table opas_ot_dbg_objects_p add partition part_'||i.dbg_id||' values('||i.dbg_id||')'; 
  end loop;
end;
/

insert /*+ append */ into opas_ot_dbg_objects_p
  (dbgobj_id, version_dp_id, dbg_id, owner, object_id, data_object_id, object_name, subobject_name, object_type, segment_type, tablespace_name, created, object_class, prnt_table, prnt_table_type, prnt_table_owner, prnt_table_col)
select
  dbgobj_id, version_dp_id, dbg_id, owner, object_id, data_object_id, object_name, subobject_name, object_type, segment_type, tablespace_name, created, object_class, prnt_table, prnt_table_type, prnt_table_owner, prnt_table_col
from opas_ot_dbg_objects;

commit;

begin
  for i in (select max(dbgobj_id)+100 v from opas_ot_dbg_objects_p) loop
    execute immediate 'create sequence opas_ot_sq_dbg_obj start with '||i.v;
  end loop;
end;
/
--------------------------------------------

CREATE TABLE opas_ot_dbg_seg_sizes_p (
dbg_id           number not null references opas_ot_dbg_monitor (dbg_id) on delete cascade,
dbgdp_id         number not null references opas_ot_dbg_datapoint(dbgdp_id) on delete cascade,
dbgobj_id        number not null references opas_ot_dbg_objects_p(dbgobj_id) on delete cascade,
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

begin
  for i in (select unique dbg_id from opas_ot_dbg_objects order by 1)
  loop
    execute immediate 'alter table opas_ot_dbg_seg_sizes_p add partition part_'||i.dbg_id||' values('||i.dbg_id||')'; 
    for j in (select * from user_tab_subpartitions where table_name='OPAS_OT_DBG_SEG_SIZES_P' and partition_name='PART_'||i.dbg_id)
    loop
      execute immediate 'alter table opas_ot_dbg_seg_sizes_p rename subpartition '||j.subpartition_name||' to ssp_'||i.dbg_id||'_max';
      for k in (select min(dbgdp_id) spl from opas_ot_dbg_datapoint where dbg_id = i.dbg_id group by trunc(snapped,'mm') order by 1)
      loop
        execute immediate 'alter table opas_ot_dbg_seg_sizes_p split subpartition ssp_'||i.dbg_id||'_max at ('||k.spl||') into (subpartition ssp_'||k.spl||', subpartition ssp_'||i.dbg_id||'_max)';
      end loop;      
    end loop;
  end loop;
end;
/

insert /*+ append */ into opas_ot_dbg_seg_sizes_p
select d.dbg_id, d.dbgdp_id, s.dbgobj_id, s.size_bytes
from opas_ot_dbg_seg_sizes s, opas_ot_dbg_datapoint d
where s.dbgdp_id = d.dbgdp_id;

commit;

alter table opas_ot_dbg_seg_sizes rename to opas_ot_dbg_seg_sizes_old;
alter table opas_ot_dbg_objects rename to opas_ot_dbg_objects_old;

alter table opas_ot_dbg_seg_sizes_p rename to opas_ot_dbg_seg_sizes;
alter table opas_ot_dbg_objects_p rename to opas_ot_dbg_objects;

create index idx_opas_ot_dbg_dbgm2                on opas_ot_dbg_datapoint(dbg_id, dbgdp_id);

CREATE OR REPLACE VIEW V$OPAS_DBG_SELECTED_OBJECTS_V3P AS
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


CREATE OR REPLACE VIEW V$OPAS_DBG_SELECTED_OBJECTS_V3PG1 AS
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

CREATE OR REPLACE VIEW V$OPAS_DBG_SELECTED_OBJECTS_V3PG2 AS
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


CREATE OR REPLACE VIEW V$OPAS_DBG_SELECTED_OBJECTS_V3PG AS
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
   
create or replace view v$opas_dbg_selected_objects_delta as
select filtered_total, 
       COREMOD_REPORT_UTILS.to_hr_num(filtered_total) filtered_total_h,
       filtered_delta,
       COREMOD_REPORT_UTILS.to_hr_num(filtered_delta) filtered_delta_h
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

create or replace view v$opas_dbg_total_delta as
select tot_occupied,
       COREMOD_REPORT_UTILS.to_hr_num(tot_occupied) tot_occupied_h,
       tot_occupied_sch,
       COREMOD_REPORT_UTILS.to_hr_num(tot_occupied_sch) tot_occupied_sch_h,
       tot_occupied_delta,
       COREMOD_REPORT_UTILS.to_hr_num(tot_occupied_delta) tot_occupied_delta_h,
       tot_occupied_sch_delta,
       COREMOD_REPORT_UTILS.to_hr_num(tot_occupied_sch_delta) tot_occupied_sch_delta_h       
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

create or replace view v$opas_dbg_sel_objects_det_delta as
with
  pars as (select * from opas_ot_dbg_report_pars pars where apex_sess = V('SESSION')),
  dat1 as (select /*+ materialize */ d1.* from v$opas_dbg_selected_objects_v3pg1 d1),
  dat2 as (select /*+ materialize */ d2.* from v$opas_dbg_selected_objects_v3pg2 d2)
select
  parent_table, sub_object,
  seg_delta,    COREMOD_REPORT_UTILS.to_hr_num(seg_delta) seg_delta_h, 
  sum(seg_delta) over () tot_seg_delta, COREMOD_REPORT_UTILS.to_hr_num(sum(seg_delta) over ()) tot_seg_delta_h,
  seg_total,    COREMOD_REPORT_UTILS.to_hr_num(seg_total) seg_total_h,
  parent_delta, COREMOD_REPORT_UTILS.to_hr_num(parent_delta) parent_delta_h,
  parent_total, COREMOD_REPORT_UTILS.to_hr_num(parent_total) parent_total_h,
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
) where seg_delta > 0)
;


create or replace view v$opas_dbg_sel_objects_det_delta_n as
with
  pars as (select * from opas_ot_dbg_report_pars pars where apex_sess = V('SESSION')),
  dat1 as (select /*+ materialize */ d1.* from v$opas_dbg_selected_objects_v3pg1 d1),
  dat2 as (select /*+ materialize */ d2.* from v$opas_dbg_selected_objects_v3pg2 d2)
select
  parent_table, sub_object,
  seg_delta,    COREMOD_REPORT_UTILS.to_hr_num(seg_delta) seg_delta_h,
  sum(seg_delta) over () tot_seg_delta, COREMOD_REPORT_UTILS.to_hr_num(sum(seg_delta) over ()) tot_seg_delta_h,
  seg_total,    COREMOD_REPORT_UTILS.to_hr_num(seg_total) seg_total_h,
  parent_delta, COREMOD_REPORT_UTILS.to_hr_num(parent_delta) parent_delta_h,
  parent_total, COREMOD_REPORT_UTILS.to_hr_num(parent_total) parent_total_h,
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
) where seg_delta < 0 )
;

begin
  -- Call the procedure
  coreobj_db_growth.init_dbg;
end;
/

spool off