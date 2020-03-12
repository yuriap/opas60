create table opas_ot_dbg_monitor (
dbg_id          number                                           primary key,
dblink          varchar2(128)                                    references opas_db_links (db_link_name) on delete cascade,
scheme_list     varchar2(4000),
schedule        number                                           references opas_scheduler (sch_id) on delete set null
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
actual_start    timestamp);

create unique index idx_opas_ot_dbg_mon_acgg_u1   on opas_ot_dbg_monitor_al_cfg(decode(alert_type,'REGEXP', null, dbg_id));
create index idx_opas_ot_dbg_mon_acgg_m           on opas_ot_dbg_monitor_al_cfg(dbg_id);

create table opas_ot_dbg_monitor_al_cfg_hst (
alert_id        number,
dbg_id          number                                           references opas_ot_dbg_monitor (dbg_id) on delete cascade,
alert_name      varchar2(128),
alert_type      varchar2(128),
alert_expr      varchar2(1024),
alert_limit     number,
actual_start    timestamp,
actual_end      timestamp);

--create index idx_opas_ot_dbg_mon_acgg_hst           on opas_ot_dbg_monitor_al_cfg_hst(alert_id);
create index idx_opas_ot_dbg_mon_acgg_hm           on opas_ot_dbg_monitor_al_cfg_hst(dbg_id);

---------------------------------
create table opas_ot_dbg_datapoint (
dbgdp_id        number                                           generated always as identity primary key,
dbg_id          number                                           references opas_ot_dbg_monitor (dbg_id) on delete cascade,
snapped         timestamp
) 
ROW STORE COMPRESS ADVANCED;

create index idx_opas_ot_dbg_dbgm                 on opas_ot_dbg_datapoint(dbg_id);

create table opas_ot_dbg_ts_sizes (
dbgdp_id         number                                           references opas_ot_dbg_datapoint (dbgdp_id) on delete cascade, 
ts_name          varchar2(128), 
free_bytes       number, 
free_in_files    number, 
free_to_extend   number, 
used_bytes       number
) ROW STORE COMPRESS ADVANCED;
   
create index idx_opas_ot_dbg_tsdp                on opas_ot_dbg_ts_sizes(dbgdp_id);

create table opas_ot_dbg_objects (
dbgobj_id        number                                           generated always as identity primary key,
version_dp_id    number                                           references opas_ot_dbg_datapoint (dbgdp_id) on delete cascade,
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