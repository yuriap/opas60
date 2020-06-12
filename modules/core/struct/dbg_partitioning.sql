alter table OPAS_OT_DBG_DATAPOINT modify dbgdp_id number  generated always as identity (nocache);

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

insert /*+ append */ into opas_ot_dbg_seg_sizes_p
select d.dbg_id, d.dbgdp_id, s.dbgobj_id, s.size_bytes
from opas_ot_dbg_seg_sizes s, opas_ot_dbg_datapoint d
where s.dbgdp_id = d.dbgdp_id;

commit;

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
         from opas_ot_dbg_seg_sizes_p s1, opas_ot_dbg_report_pars p1
        where s1.dbg_id = p1.DBGSO_DBG_ID
          and p1.apex_sess = V('SESSION')
          and s1.dbgdp_id >= nvl(p1.dbgso_start_snap,0)
          and s1.dbgdp_id <= p1.dbgso_end_snap) s,
       (select /*+ no_merge leading(p1 o1) use_nl(o1) */ o1.*
          from opas_ot_dbg_objects_p o1, opas_ot_dbg_report_pars p1
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