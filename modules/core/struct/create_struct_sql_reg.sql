---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- sqls
create table opas_ot_sql_descriptions (
sql_id              varchar2(13)                           not null  primary key,
sql_text            number                                           references opas_files ( file_id ),
sql_text_approx     number                                           references opas_files ( file_id ),
created_by          varchar2(128)    default 'PUBLIC',
first_discovered    timestamp,
first_discovered_at varchar2(128)                                    references opas_db_links (db_link_name)
);

alter table opas_ot_sql_descriptions ROW STORE COMPRESS ADVANCED;
create index        idx_opas_ot_sql_descr_file  on opas_ot_sql_descriptions(sql_text);
create index        idx_opas_ot_sql_descr_a_file  on opas_ot_sql_descriptions(sql_text_approx);

--==================================================================
create table opas_ot_sql_tags (
tag_name            varchar2(128)                                    primary key,
tag_prnt            varchar2(128)                                    references opas_ot_sql_tags(tag_name),  
tag_description     varchar2(4000),
tag_autoexpr        varchar2(4000)
);

create table opas_ot_sql_sql2tags(
sql_id              varchar2(13)                                     references opas_ot_sql_descriptions(sql_id) on delete cascade,
tag                 varchar2(128)                                    references opas_ot_sql_tags(tag_name),
tag_type            varchar2(1),  --M MANUAL, A AUTO
primary key (sql_id,tag))
organization index including tag_type overflow;

create table opas_ot_sql_auto_gather_sqls (
ags_id          number                                           generated always as identity primary key,
dblink          varchar2(128)                                    references opas_db_links (db_link_name) on delete cascade,
filter_vsql     varchar2(4000),
filter_awrstat  varchar2(4000),
filter_awrash   varchar2(4000),
sqltext_filter  varchar2(4000),
schedule        number                                           references opas_scheduler (sch_id) on delete set null,
row_limit       number,
time_limit      number,
descr           varchar2(1000)
);

create index idx_opas_ot_sql_asg_dbl   on opas_ot_sql_auto_gather_sqls(dblink);
create index idx_opas_ot_sql_asg_sch   on opas_ot_sql_auto_gather_sqls(schedule);

create global temporary table OPAS_OT_TMP_AGS_LIST (
sql_id              varchar2(13),
plan_hash_value     number,
force_matching_signature varchar2(100)
) on commit preserve rows;

create global temporary table OPAS_OT_TMP_AGS_SQLS (
sql_id              varchar2(13),
plan_hash_value     number,
sql_text            clob,
force_matching_signature varchar2(100),
jaro_winkler_similarity  number
) on commit preserve rows;

create table opas_ot_sql_searches(
session_id          number generated always as identity primary key,
apex_sess           number,
apex_user           varchar2(128),
local_status        varchar2(100),
remote_status       varchar2(100),
created             date,
retention           number, --null default, number - days
search_params       CLOB,
CONSTRAINT search_pars_json_chk CHECK (search_params IS JSON));

create table opas_ot_sql_search_results(
session_id          number                                           references opas_ot_sql_searches(session_id) on delete cascade,
search_source       varchar2(1), -- L local, E - external
txt_score           number,
sql_id              varchar2(13),
sql_text_local      number,
sql_text_external   clob,
created_by          varchar2(128),
first_discovered    timestamp,
first_discovered_at varchar2(128));

create index idx_sql_sr_sess on opas_ot_sql_search_results(session_id);
--==================================================================

create sequence opas_ot_sq_dp;

create table opas_ot_sql_data (
sql_data_point_id   number                                           primary key,
prnt_data_point_id  number                                           references opas_ot_sql_data ( sql_data_point_id ) on delete cascade,
sql_id              varchar2(13)                           not null  references opas_ot_sql_descriptions ( sql_id ) on delete cascade,
start_gathering_dt  timestamp,
end_gathering_dt    timestamp,
dblink              varchar2(128)                          not null  references opas_db_links (db_link_name),
gathering_status    varchar2(32)     default 'NOT_STARTED' not null,
tq_id               number,
tq_id2              number,
awr_snap_start      number,
awr_snap_end        number,
incarnation#        number
);

alter table opas_ot_sql_data ROW STORE COMPRESS ADVANCED;

create index idx_opas_sql_data_sqlid on opas_ot_sql_data(sql_id) compress;
create index idx_opas_sql_data_dbl   on opas_ot_sql_data(dblink) compress;
create index idx_opas_sql_data_prnt  on opas_ot_sql_data(prnt_data_point_id) compress;

create global temporary table opas_ot_tmp_rec_sql_ids (
sql_id varchar2(13)
) on commit delete rows;

create table opas_ot_sql_data_sect (
sql_data_point_id   number                                 not null  references opas_ot_sql_data(sql_data_point_id) on delete cascade,
section_name        varchar2(30)                           not null,
start_gathering_dt  timestamp,
end_gathering_dt    timestamp,
gathering_status    varchar2(32)     default 'NOT_STARTED' not null,
error_message       varchar2(4000),
amount_gathered     number
);

alter table opas_ot_sql_data_sect ROW STORE COMPRESS ADVANCED;
create index idx_opas_sql_data_sect_sid on opas_ot_sql_data_sect(sql_data_point_id) compress;

create table opas_ot_sql_data_point_ref (
 obj_id                                             number                                 not null  references opas_objects(obj_id) on delete cascade,
 sql_data_point_id                                  number                                 not null  references opas_ot_sql_data(sql_data_point_id),
 primary key (obj_id, sql_data_point_id)
) organization index;

--create index idx_opas_sql_dp_ref_dp  on opas_ot_sql_data_point_ref(sql_data_point_id);
--create unique index idx_opas_sql_dp_rep_mon on opas_ot_sql_data_point_ref(obj_id);

----
create table opas_ot_sql_nonshared (
sql_data_point_id   number,
sql_id              varchar2(13), 
inst_id             number, 
nonshared_reason    varchar2(100), 
cnt                 number);

alter table opas_ot_sql_nonshared ROW STORE COMPRESS ADVANCED;
alter table opas_ot_sql_nonshared add constraint fk_sql_ns_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_nonshared add constraint fk_sql_ns_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_ns_dp    on opas_ot_sql_nonshared(sql_data_point_id);
create index idx_opas_sql_ns_sqlid on opas_ot_sql_nonshared(sql_id) compress;

----
CREATE TABLE OPAS_OT_SQL_VSQL 
   (SQL_DATA_POINT_ID NUMBER, 
	SQL_ID VARCHAR2(13 BYTE), 
	CHILD_NUMBER NUMBER, 
	PLAN_HASH_VALUE NUMBER, 
	OPTIMIZER_ENV_HASH_VALUE NUMBER, 
	INST_ID NUMBER, 
	FORCE_MATCHING_SIGNATURE NUMBER, 
	OLD_HASH_VALUE NUMBER, 
	PROGRAM_ID NUMBER, 
	PROGRAM_LINE# NUMBER, 
	PARSING_SCHEMA_NAME VARCHAR2(128 BYTE), 
	MODULE VARCHAR2(64 BYTE), 
	ACTION VARCHAR2(64 BYTE), 
	FIRST_LOAD_TIME VARCHAR2(76 BYTE), 
	LAST_LOAD_TIME VARCHAR2(76 BYTE), 
	LAST_ACTIVE_TIME DATE, 
	IS_OBSOLETE VARCHAR2(1 BYTE), 
	IS_BIND_SENSITIVE VARCHAR2(1 BYTE), 
	IS_BIND_AWARE VARCHAR2(1 BYTE), 
	IS_SHAREABLE VARCHAR2(1 BYTE), 
	SQL_PROFILE VARCHAR2(64 BYTE), 
	SQL_PATCH VARCHAR2(128 BYTE), 
	SQL_PLAN_BASELINE VARCHAR2(128 BYTE), 
	PX_SERVERS_EXECUTIONS NUMBER, 
	PHYSICAL_READ_REQUESTS NUMBER, 
	PHYSICAL_READ_BYTES NUMBER, 
	PHYSICAL_WRITE_REQUESTS NUMBER, 
	PHYSICAL_WRITE_BYTES NUMBER, 
	PARSE_CALLS NUMBER, 
	EXECUTIONS NUMBER, 
	FETCHES NUMBER, 
	ROWS_PROCESSED NUMBER, 
	END_OF_FETCH_COUNT NUMBER, 
	CPU_TIME NUMBER, 
	ELAPSED_TIME NUMBER, 
	DISK_READS NUMBER, 
	BUFFER_GETS NUMBER, 
	DIRECT_WRITES NUMBER, 
	APPLICATION_WAIT_TIME NUMBER, 
	CONCURRENCY_WAIT_TIME NUMBER, 
	CLUSTER_WAIT_TIME NUMBER, 
	USER_IO_WAIT_TIME NUMBER, 
	PLSQL_EXEC_TIME NUMBER, 
	JAVA_EXEC_TIME NUMBER, 
	IO_CELL_OFFLOAD_ELIGIBLE_BYTES NUMBER, 
	IO_INTERCONNECT_BYTES NUMBER, 
	OPTIMIZED_PHY_READ_REQUESTS NUMBER, 
	IO_CELL_UNCOMPRESSED_BYTES NUMBER, 
	IO_CELL_OFFLOAD_RETURNED_BYTES NUMBER);

alter table opas_ot_sql_vsql ROW STORE COMPRESS ADVANCED;
alter table opas_ot_sql_vsql add constraint fk_sql_vsql_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_vsql add constraint fk_sql_vsql_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_vsql_dp    on opas_ot_sql_vsql(sql_data_point_id);
create index idx_opas_sql_vsql_sqlid on opas_ot_sql_vsql(sql_id) compress;

CREATE TABLE OPAS_OT_SQL_VSQL_OBJS 
   (SQL_DATA_POINT_ID NUMBER, 
	CHILD_NUMBER NUMBER, 
	OBJECT_ID NUMBER, 
	OWNER VARCHAR2(128 BYTE), 
	OBJECT_TYPE VARCHAR2(23 BYTE), 
	OBJECT_NAME VARCHAR2(128 BYTE));

alter table opas_ot_sql_vsql_objs ROW STORE COMPRESS ADVANCED;
alter table opas_ot_sql_vsql_objs add constraint fk_sql_vsql_objs_dp foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
create index idx_opas_sql_vsql_objs_dp on opas_ot_sql_vsql_objs(sql_data_point_id) compress;

----------------------------------------------------------------------------------------------------------------
create sequence opas_ot_sq_plan_id;

CREATE TABLE OPAS_OT_SQL_PLANS 
   (PLAN_ID NUMBER, 
	CREATED TIMESTAMP (6) WITH TIME ZONE, 
	SQL_ID VARCHAR2(13 BYTE), 
	PLAN_SOURCE VARCHAR2(20 BYTE));

alter table opas_ot_sql_plans ROW STORE COMPRESS ADVANCED;
alter table opas_ot_sql_plans add constraint pk_sql_plan_id primary key(plan_id);
alter table opas_ot_sql_plans add constraint fk_sql_plans_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;
create index idx_opas_sql_plans_sqlid on opas_ot_sql_plans(sql_id);

CREATE TABLE OPAS_OT_SQL_PLAN_DET 
   (PLAN_ID NUMBER, 
	INST_ID NUMBER, 
	ADDRESS RAW(8), 
	HASH_VALUE NUMBER, 
	SQL_ID VARCHAR2(13 BYTE), 
	PLAN_HASH_VALUE NUMBER, 
	FULL_PLAN_HASH_VALUE NUMBER, 
	CHILD_ADDRESS RAW(8), 
	CHILD_NUMBER NUMBER, 
	TIMESTAMP DATE, 
	OPERATION VARCHAR2(120 BYTE), 
	OPTIONS VARCHAR2(120 BYTE), 
	OBJECT_NODE VARCHAR2(160 BYTE), 
	OBJECT# NUMBER, 
	OBJECT_OWNER VARCHAR2(128 BYTE), 
	OBJECT_NAME VARCHAR2(128 BYTE), 
	OBJECT_ALIAS VARCHAR2(261 BYTE), 
	OBJECT_TYPE VARCHAR2(80 BYTE), 
	OPTIMIZER VARCHAR2(80 BYTE), 
	ID NUMBER, 
	PARENT_ID NUMBER, 
	DEPTH NUMBER, 
	POSITION NUMBER, 
	SEARCH_COLUMNS NUMBER, 
	COST NUMBER, 
	CARDINALITY NUMBER, 
	BYTES NUMBER, 
	OTHER_TAG VARCHAR2(140 BYTE), 
	PARTITION_START VARCHAR2(256 BYTE), 
	PARTITION_STOP VARCHAR2(256 BYTE), 
	PARTITION_ID NUMBER, 
	OTHER VARCHAR2(4000 BYTE), 
	DISTRIBUTION VARCHAR2(80 BYTE), 
	CPU_COST NUMBER, 
	IO_COST NUMBER, 
	TEMP_SPACE NUMBER, 
	ACCESS_PREDICATES VARCHAR2(4000 BYTE), 
	FILTER_PREDICATES VARCHAR2(4000 BYTE), 
	PROJECTION VARCHAR2(4000 BYTE), 
	TIME NUMBER, 
	QBLOCK_NAME VARCHAR2(128 BYTE), 
	REMARKS VARCHAR2(4000 BYTE), 
	OTHER_XML CLOB, 
	EXECUTIONS NUMBER, 
	LAST_STARTS NUMBER, 
	STARTS NUMBER, 
	LAST_OUTPUT_ROWS NUMBER, 
	OUTPUT_ROWS NUMBER, 
	LAST_CR_BUFFER_GETS NUMBER, 
	CR_BUFFER_GETS NUMBER, 
	LAST_CU_BUFFER_GETS NUMBER, 
	CU_BUFFER_GETS NUMBER, 
	LAST_DISK_READS NUMBER, 
	DISK_READS NUMBER, 
	LAST_DISK_WRITES NUMBER, 
	DISK_WRITES NUMBER, 
	LAST_ELAPSED_TIME NUMBER, 
	ELAPSED_TIME NUMBER, 
	POLICY VARCHAR2(40 BYTE), 
	ESTIMATED_OPTIMAL_SIZE NUMBER, 
	ESTIMATED_ONEPASS_SIZE NUMBER, 
	LAST_MEMORY_USED NUMBER, 
	LAST_EXECUTION VARCHAR2(40 BYTE), 
	LAST_DEGREE NUMBER, 
	TOTAL_EXECUTIONS NUMBER, 
	OPTIMAL_EXECUTIONS NUMBER, 
	ONEPASS_EXECUTIONS NUMBER, 
	MULTIPASSES_EXECUTIONS NUMBER, 
	ACTIVE_TIME NUMBER, 
	MAX_TEMPSEG_SIZE NUMBER, 
	LAST_TEMPSEG_SIZE NUMBER, 
	CON_ID NUMBER, 
	CON_DBID NUMBER);

alter table opas_ot_sql_plan_det ROW STORE COMPRESS ADVANCED;
alter table opas_ot_sql_plan_det add constraint fk_sql_pland_id foreign key (plan_id) references opas_ot_sql_plans(plan_id) on delete cascade;
alter table opas_ot_sql_plan_det add constraint fk_sql_pland_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;
create index idx_opas_sql_pland_id on opas_ot_sql_plan_det(plan_id) compress;
create index idx_opas_sql_pland_sqlid on opas_ot_sql_plan_det(sql_id) compress;

create table opas_ot_sql_ep_plan_det
(
SQL_ID                  VARCHAR2(13),
PLAN_ID                 NUMBER,
sql_plan_hash_value      number,
sql_full_plan_hash_value number,
STATEMENT_ID            VARCHAR2(30),
TIMESTAMP               DATE,
REMARKS                 VARCHAR2(4000),
OPERATION               VARCHAR2(30),
OPTIONS                 VARCHAR2(255),
OBJECT_NODE             VARCHAR2(128),
OBJECT_OWNER            VARCHAR2(128),
OBJECT_NAME             VARCHAR2(128),
OBJECT_ALIAS            VARCHAR2(261),
OBJECT_INSTANCE         NUMBER(38),
OBJECT_TYPE             VARCHAR2(30),
OPTIMIZER               VARCHAR2(255),
SEARCH_COLUMNS          NUMBER,
ID                      NUMBER(38),
PARENT_ID               NUMBER(38),
DEPTH                   NUMBER(38),
POSITION                NUMBER(38),
COST                    NUMBER(38),
CARDINALITY             NUMBER(38),
BYTES                   NUMBER(38),
OTHER_TAG               VARCHAR2(255),
PARTITION_START         VARCHAR2(255),
PARTITION_STOP          VARCHAR2(255),
PARTITION_ID            NUMBER(38),
OTHER_XML               CLOB,
DISTRIBUTION            VARCHAR2(30),
CPU_COST                NUMBER(38),
IO_COST                 NUMBER(38),
TEMP_SPACE              NUMBER(38),
ACCESS_PREDICATES       VARCHAR2(4000),
FILTER_PREDICATES       VARCHAR2(4000),
PROJECTION              VARCHAR2(4000),
TIME                    NUMBER(38),
QBLOCK_NAME             VARCHAR2(128)
);

alter table opas_ot_sql_ep_plan_det ROW STORE COMPRESS ADVANCED;
alter table opas_ot_sql_ep_plan_det add constraint fk_sql_eppland_id foreign key (plan_id) references opas_ot_sql_plans(plan_id) on delete cascade;
alter table opas_ot_sql_ep_plan_det add constraint fk_sql_eppland_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;
create index idx_opas_sql_eppland_id on opas_ot_sql_ep_plan_det(plan_id) compress;
create index idx_opas_sql_eppland_sqlid on opas_ot_sql_ep_plan_det(sql_id) compress;


create table opas_ot_sql_plan_ref (
 sql_data_point_id                                number                                 not null  references opas_ot_sql_data(sql_data_point_id) on delete cascade,
 plan_id                                          number                                 not null  references opas_ot_sql_plans(plan_id) on delete cascade
);

alter table opas_ot_sql_plan_ref ROW STORE COMPRESS ADVANCED;
create index idx_opas_sql_plan_ref_dp  on opas_ot_sql_plan_ref(sql_data_point_id) compress;
create index idx_opas_sql_plan_rep_mon on opas_ot_sql_plan_ref(plan_id) compress;

CREATE GLOBAL TEMPORARY TABLE OPAS_OT_TMP_GV$SQL_PLAN_STAT_ALL 
   (REPORT_ID NUMBER, 
	INST_ID NUMBER, 
	ADDRESS RAW(8), 
	HASH_VALUE NUMBER, 
	SQL_ID VARCHAR2(13 BYTE), 
	PLAN_HASH_VALUE NUMBER, 
	FULL_PLAN_HASH_VALUE NUMBER, 
	CHILD_ADDRESS RAW(8), 
	CHILD_NUMBER NUMBER, 
	TIMESTAMP DATE, 
	OPERATION VARCHAR2(120 BYTE), 
	OPTIONS VARCHAR2(120 BYTE), 
	OBJECT_NODE VARCHAR2(160 BYTE), 
	OBJECT# NUMBER, 
	OBJECT_OWNER VARCHAR2(128 BYTE), 
	OBJECT_NAME VARCHAR2(128 BYTE), 
	OBJECT_ALIAS VARCHAR2(261 BYTE), 
	OBJECT_TYPE VARCHAR2(80 BYTE), 
	OPTIMIZER VARCHAR2(80 BYTE), 
	ID NUMBER, 
	PARENT_ID NUMBER, 
	DEPTH NUMBER, 
	POSITION NUMBER, 
	SEARCH_COLUMNS NUMBER, 
	COST NUMBER, 
	CARDINALITY NUMBER, 
	BYTES NUMBER, 
	OTHER_TAG VARCHAR2(140 BYTE), 
	PARTITION_START VARCHAR2(256 BYTE), 
	PARTITION_STOP VARCHAR2(256 BYTE), 
	PARTITION_ID NUMBER, 
	OTHER VARCHAR2(4000 BYTE), 
	DISTRIBUTION VARCHAR2(80 BYTE), 
	CPU_COST NUMBER, 
	IO_COST NUMBER, 
	TEMP_SPACE NUMBER, 
	ACCESS_PREDICATES VARCHAR2(4000 BYTE), 
	FILTER_PREDICATES VARCHAR2(4000 BYTE), 
	PROJECTION VARCHAR2(4000 BYTE), 
	TIME NUMBER, 
	QBLOCK_NAME VARCHAR2(128 BYTE), 
	REMARKS VARCHAR2(4000 BYTE), 
	OTHER_XML CLOB, 
	EXECUTIONS NUMBER, 
	LAST_STARTS NUMBER, 
	STARTS NUMBER, 
	LAST_OUTPUT_ROWS NUMBER, 
	OUTPUT_ROWS NUMBER, 
	LAST_CR_BUFFER_GETS NUMBER, 
	CR_BUFFER_GETS NUMBER, 
	LAST_CU_BUFFER_GETS NUMBER, 
	CU_BUFFER_GETS NUMBER, 
	LAST_DISK_READS NUMBER, 
	DISK_READS NUMBER, 
	LAST_DISK_WRITES NUMBER, 
	DISK_WRITES NUMBER, 
	LAST_ELAPSED_TIME NUMBER, 
	ELAPSED_TIME NUMBER, 
	POLICY VARCHAR2(40 BYTE), 
	ESTIMATED_OPTIMAL_SIZE NUMBER, 
	ESTIMATED_ONEPASS_SIZE NUMBER, 
	LAST_MEMORY_USED NUMBER, 
	LAST_EXECUTION VARCHAR2(40 BYTE), 
	LAST_DEGREE NUMBER, 
	TOTAL_EXECUTIONS NUMBER, 
	OPTIMAL_EXECUTIONS NUMBER, 
	ONEPASS_EXECUTIONS NUMBER, 
	MULTIPASSES_EXECUTIONS NUMBER, 
	ACTIVE_TIME NUMBER, 
	MAX_TEMPSEG_SIZE NUMBER, 
	LAST_TEMPSEG_SIZE NUMBER, 
	CON_ID NUMBER, 
	CON_DBID NUMBER
   ) ON COMMIT DELETE ROWS;


CREATE GLOBAL TEMPORARY TABLE OPAS_OT_TMP_GV$SQL_PLAN_KEY 
   (PLAN_ID NUMBER, 
	REPORT_ID NUMBER, 
	INST_ID NUMBER, 
	CHILD_NUMBER NUMBER, 
	PLAN_HASH_VALUE NUMBER, 
	FULL_PLAN_HASH_VALUE NUMBER
   ) ON COMMIT DELETE ROWS ;

----
create sequence opas_ot_sq_sqlmon_id;

create table opas_ot_sql_sqlmon (
 sqlmon_id                                          number                                           primary key,
 sql_id                                             varchar2(13)                           not null  references opas_ot_sql_descriptions(sql_id) on delete cascade,
 sql_mon_report                                     number                                           references opas_files ( file_id ),
 sql_mon_hst_report                                 number                                           references opas_files ( file_id ),
 plan_id                                            number                                           references opas_ot_sql_plans ( plan_id ),
 dblink                                             varchar2(128)                          not null  references opas_db_links(db_link_name), 
 source                                             varchar2(100), -- v$/hst
 report_id                                          number,
 status                                             varchar2(19),
 first_refresh_time                                 date,
 last_refresh_time                                  date,
 refresh_count                                      number,
 sql_exec_start                                     date,
 sql_exec_id                                        number,
 sid                                                number,
 session_serial#                                    number,
 con_id                                             number,
 con_name                                           varchar2(128),
 ecid                                               varchar2(64),
 ---
 snap_id                                            number,
 dbid                                               number,
 instance_number                                    number,
 con_dbid                                           number);
 
alter table opas_ot_sql_sqlmon ROW STORE COMPRESS ADVANCED;
create index idx_opas_sql_mon_rep_text  on opas_ot_sql_sqlmon(sql_mon_report);
create index idx_opas_sql_mon_rep_xml  on opas_ot_sql_sqlmon(sql_mon_hst_report);
create index idx_opas_sql_mon_rep_sqlid on opas_ot_sql_sqlmon(sql_id) compress;

create table opas_ot_sql_sqlmon_ref (
 sql_data_point_id                                  number                                 not null  references opas_ot_sql_data(sql_data_point_id) on delete cascade,
 sqlmon_id                                          number                                 not null  references opas_ot_sql_sqlmon(sqlmon_id) on delete cascade
);

alter table opas_ot_sql_sqlmon_ref ROW STORE COMPRESS ADVANCED;
create index idx_opas_sql_mon_ref_dp  on opas_ot_sql_sqlmon_ref(sql_data_point_id) compress;
create index idx_opas_sql_mon_rep_mon on opas_ot_sql_sqlmon_ref(sqlmon_id) compress;

create table opas_ot_sql_sqlmon_data (
 sqlmon_id                                          number                                 not null  references opas_ot_sql_sqlmon(sqlmon_id) on delete cascade,
 user#                                              number,
 username                                           varchar2(128),
 module                                             varchar2(64),
 action                                             varchar2(64),
 service_name                                       varchar2(64),
 client_identifier                                  varchar2(64),
 client_info                                        varchar2(64),
 program                                            varchar2(48),
 plsql_entry_object_id                              number,
 plsql_entry_subprogram_id                          number,
 plsql_object_id                                    number,
 plsql_subprogram_id                                number,
 dbop_exec_id                                       number,
 dbop_name                                          varchar2(30),
 process_name                                       varchar2(5),
 sql_text                                           varchar2(2000),
 is_full_sqltext                                    varchar2(1),
 sql_plan_hash_value                                number,
 sql_full_plan_hash_value                           number,
 exact_matching_signature                           number,
 force_matching_signature                           number,
 px_is_cross_instance                               varchar2(1),
 px_maxdop                                          number,
 px_maxdop_instances                                number,
 px_servers_requested                               number,
 px_servers_allocated                               number,
 px_server#                                         number,
 px_server_group                                    number,
 px_server_set                                      number,
 px_qcinst_id                                       number,
 px_qcsid                                           number,
 error_number                                       varchar2(40),
 error_facility                                     varchar2(4),
 error_message                                      varchar2(256),
 elapsed_time                                       number,
 queuing_time                                       number,
 cpu_time                                           number,
 fetches                                            number,
 buffer_gets                                        number,
 disk_reads                                         number,
 direct_writes                                      number,
 io_interconnect_bytes                              number,
 physical_read_requests                             number,
 physical_read_bytes                                number,
 physical_write_requests                            number,
 physical_write_bytes                               number,
 application_wait_time                              number,
 concurrency_wait_time                              number,
 cluster_wait_time                                  number,
 user_io_wait_time                                  number,
 plsql_exec_time                                    number,
 java_exec_time                                     number,
 rm_last_action                                     varchar2(48),
 rm_last_action_reason                              varchar2(128),
 rm_last_action_time                                date,
 rm_consumer_group                                  varchar2(128),
 is_adaptive_plan                                   varchar2(1),
 is_final_plan                                      varchar2(1),
 in_dbop_name                                       varchar2(30),
 in_dbop_exec_id                                    number,
 io_cell_uncompressed_bytes                         number,
 io_cell_offload_eligible_bytes                     number,
 io_cell_offload_returned_bytes                     number);

alter table opas_ot_sql_sqlmon_data ROW STORE COMPRESS ADVANCED;
create index idx_opas_sql_mon_rep_d_mon on opas_ot_sql_sqlmon_data(sqlmon_id) compress;

CREATE GLOBAL TEMPORARY TABLE OPAS_OT_TMP_GV$SQL_MONITOR 
   (INST_ID NUMBER, 
	KEY NUMBER, 
	REPORT_ID NUMBER, 
	STATUS VARCHAR2(19 BYTE), 
	USER# NUMBER, 
	USERNAME VARCHAR2(128 BYTE), 
	MODULE VARCHAR2(64 BYTE), 
	ACTION VARCHAR2(64 BYTE), 
	SERVICE_NAME VARCHAR2(64 BYTE), 
	CLIENT_IDENTIFIER VARCHAR2(64 BYTE), 
	CLIENT_INFO VARCHAR2(64 BYTE), 
	PROGRAM VARCHAR2(48 BYTE), 
	PLSQL_ENTRY_OBJECT_ID NUMBER, 
	PLSQL_ENTRY_SUBPROGRAM_ID NUMBER, 
	PLSQL_OBJECT_ID NUMBER, 
	PLSQL_SUBPROGRAM_ID NUMBER, 
	FIRST_REFRESH_TIME DATE, 
	LAST_REFRESH_TIME DATE, 
	REFRESH_COUNT NUMBER, 
	DBOP_EXEC_ID NUMBER, 
	DBOP_NAME VARCHAR2(30 BYTE), 
	SID NUMBER, 
	PROCESS_NAME VARCHAR2(5 BYTE), 
	SQL_ID VARCHAR2(13 BYTE), 
	SQL_TEXT VARCHAR2(2000 BYTE), 
	IS_FULL_SQLTEXT VARCHAR2(1 BYTE), 
	SQL_EXEC_START DATE, 
	SQL_EXEC_ID NUMBER, 
	SQL_PLAN_HASH_VALUE NUMBER, 
	SQL_FULL_PLAN_HASH_VALUE NUMBER, 
	EXACT_MATCHING_SIGNATURE NUMBER, 
	FORCE_MATCHING_SIGNATURE NUMBER, 
	SQL_CHILD_ADDRESS RAW(8), 
	SESSION_SERIAL# NUMBER, 
	PX_IS_CROSS_INSTANCE VARCHAR2(1 BYTE), 
	PX_MAXDOP NUMBER, 
	PX_MAXDOP_INSTANCES NUMBER, 
	PX_SERVERS_REQUESTED NUMBER, 
	PX_SERVERS_ALLOCATED NUMBER, 
	PX_SERVER# NUMBER, 
	PX_SERVER_GROUP NUMBER, 
	PX_SERVER_SET NUMBER, 
	PX_QCINST_ID NUMBER, 
	PX_QCSID NUMBER, 
	ERROR_NUMBER VARCHAR2(40 BYTE), 
	ERROR_FACILITY VARCHAR2(4 BYTE), 
	ERROR_MESSAGE VARCHAR2(256 BYTE), 
	BINDS_XML CLOB, 
	OTHER_XML CLOB, 
	ELAPSED_TIME NUMBER, 
	QUEUING_TIME NUMBER, 
	CPU_TIME NUMBER, 
	FETCHES NUMBER, 
	BUFFER_GETS NUMBER, 
	DISK_READS NUMBER, 
	DIRECT_WRITES NUMBER, 
	IO_INTERCONNECT_BYTES NUMBER, 
	PHYSICAL_READ_REQUESTS NUMBER, 
	PHYSICAL_READ_BYTES NUMBER, 
	PHYSICAL_WRITE_REQUESTS NUMBER, 
	PHYSICAL_WRITE_BYTES NUMBER, 
	APPLICATION_WAIT_TIME NUMBER, 
	CONCURRENCY_WAIT_TIME NUMBER, 
	CLUSTER_WAIT_TIME NUMBER, 
	USER_IO_WAIT_TIME NUMBER, 
	PLSQL_EXEC_TIME NUMBER, 
	JAVA_EXEC_TIME NUMBER, 
	RM_LAST_ACTION VARCHAR2(48 BYTE), 
	RM_LAST_ACTION_REASON VARCHAR2(128 BYTE), 
	RM_LAST_ACTION_TIME DATE, 
	RM_CONSUMER_GROUP VARCHAR2(128 BYTE), 
	CON_ID NUMBER, 
	CON_NAME VARCHAR2(128 BYTE), 
	ECID VARCHAR2(64 BYTE), 
	IS_ADAPTIVE_PLAN VARCHAR2(1 BYTE), 
	IS_FINAL_PLAN VARCHAR2(1 BYTE), 
	IN_DBOP_NAME VARCHAR2(30 BYTE), 
	IN_DBOP_EXEC_ID NUMBER, 
	IO_CELL_UNCOMPRESSED_BYTES NUMBER, 
	IO_CELL_OFFLOAD_ELIGIBLE_BYTES NUMBER, 
	IO_CELL_OFFLOAD_RETURNED_BYTES NUMBER
   ) ON COMMIT DELETE ROWS;


CREATE GLOBAL TEMPORARY TABLE OPAS_OT_TMP_DBA_HIST_REPORTS 
   (	SNAP_ID NUMBER, 
	DBID NUMBER, 
	INSTANCE_NUMBER NUMBER, 
	REPORT_ID NUMBER, 
	COMPONENT_ID NUMBER, 
	SESSION_ID NUMBER, 
	SESSION_SERIAL# NUMBER, 
	PERIOD_START_TIME DATE, 
	PERIOD_END_TIME DATE, 
	GENERATION_TIME DATE, 
	COMPONENT_NAME VARCHAR2(128 BYTE), 
	REPORT_NAME VARCHAR2(128 BYTE), 
	REPORT_PARAMETERS VARCHAR2(1024 BYTE), 
	KEY1 VARCHAR2(128 BYTE), 
	KEY2 VARCHAR2(128 BYTE), 
	KEY3 VARCHAR2(128 BYTE), 
	KEY4 VARCHAR2(256 BYTE), 
	GENERATION_COST_SECONDS NUMBER, 
	REPORT_SUMMARY VARCHAR2(4000 BYTE), 
	CON_DBID NUMBER, 
	CON_ID NUMBER
   ) ON COMMIT DELETE ROWS ;
   
CREATE GLOBAL TEMPORARY TABLE OPAS_OT_TMP_DBA_HIST_REP_XML 
   (REPORT_ID NUMBER, 
	REPORT CLOB
   ) ON COMMIT DELETE ROWS;
   
----
CREATE TABLE OPAS_OT_SQL_WA 
   (SQL_DATA_POINT_ID NUMBER, 
	SQL_ID VARCHAR2(13 BYTE), 
	INST_ID NUMBER, 
	CHILD_NUMBER NUMBER, 
	POLICY VARCHAR2(40 BYTE), 
	OPERATION_ID NUMBER, 
	OPERATION_TYPE VARCHAR2(160 BYTE), 
	ESTIMATED_OPTIMAL_SIZE NUMBER, 
	ESTIMATED_ONEPASS_SIZE NUMBER, 
	LAST_MEMORY_USED NUMBER, 
	LAST_EXECUTION VARCHAR2(40 BYTE), 
	LAST_DEGREE NUMBER, 
	TOTAL_EXECUTIONS NUMBER, 
	OPTIMAL_EXECUTIONS NUMBER, 
	ONEPASS_EXECUTIONS NUMBER, 
	MULTIPASSES_EXECUTIONS NUMBER, 
	ACTIVE_TIME NUMBER, 
	MAX_TEMPSEG_SIZE NUMBER, 
	LAST_TEMPSEG_SIZE NUMBER);
	
alter table opas_ot_sql_wa ROW STORE COMPRESS ADVANCED;
alter table opas_ot_sql_wa add constraint fk_sql_wa_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_wa add constraint fk_sql_wa_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_wa_dp    on opas_ot_sql_wa(sql_data_point_id) compress;
create index idx_opas_sql_wa_sqlid on opas_ot_sql_wa(sql_id) compress;
----

CREATE TABLE OPAS_OT_SQL_OPT_ENV 
   (SQL_DATA_POINT_ID NUMBER, 
	SQL_ID VARCHAR2(13 BYTE), 
	INST_ID NUMBER, 
	CHILD_NUMBER NUMBER, 
	NAME VARCHAR2(40 BYTE), 
	ISDEFAULT VARCHAR2(3 BYTE), 
	VALUE VARCHAR2(25 BYTE));
	
alter table opas_ot_sql_opt_env ROW STORE COMPRESS ADVANCED;
alter table opas_ot_sql_opt_env add constraint fk_sql_oe_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_opt_env add constraint fk_sql_oe_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_oe_dp    on opas_ot_sql_opt_env(sql_data_point_id) compress;
create index idx_opas_sql_oe_sqlid on opas_ot_sql_opt_env(sql_id) compress;
---

CREATE TABLE opas_ot_sql_ash_ident
(	
sql_data_point_id   number,
source_tab          varchar2(10),
SQL_ID              VARCHAR2(13 BYTE), 
MIN_SAMPLE_TIME     TIMESTAMP (3), 
MAX_SAMPLE_TIME     TIMESTAMP (3), 
SQL_EXEC_START      DATE, 
PROGRAM             VARCHAR2(48 BYTE), 
MODULE              VARCHAR2(64 BYTE), 
ACTION              VARCHAR2(64 BYTE), 
CLIENT_ID           VARCHAR2(64 BYTE), 
SAMPLES_CNT         NUMBER
);

alter table opas_ot_sql_ash_ident ROW STORE COMPRESS ADVANCED;
alter table opas_ot_sql_ash_ident add constraint fk_sql_vashid_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_ash_ident add constraint fk_sql_vashid_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_vashid_dp    on opas_ot_sql_ash_ident(sql_data_point_id) compress;
create index idx_opas_sql_vashid_sqlid on opas_ot_sql_ash_ident(sql_id) compress;

create table opas_ot_sql_vash1 (
sql_data_point_id   number,
sql_id              varchar2(13), 
sql_exec_start      date, 
sql_exec_end        date, 
plan_hash_value     number, 
id                  number, 
row_src             varchar2(64), 
event               varchar2(64), 
cnt                 number, 
tim_pct             number, 
tim_id_pct          number, 
obj                 varchar2(256), 
tbs                 varchar2(30)
);
   
alter table opas_ot_sql_vash1 ROW STORE COMPRESS ADVANCED;
alter table opas_ot_sql_vash1 add constraint fk_sql_vash1_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_vash1 add constraint fk_sql_vash1_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_vash1_dp    on opas_ot_sql_vash1(sql_data_point_id) compress;
create index idx_opas_sql_vash1_sqlid on opas_ot_sql_vash1(sql_id) compress;

create table opas_ot_sql_vash2 (
sql_data_point_id   number,
sql_id              varchar2(13), 
plan_hash_value     number, 
id                  number, 
row_src             varchar2(64), 
event               varchar2(64), 
cnt                 number, 
tim_pct             number, 
tim_id_pct          number, 
obj                 varchar2(256), 
tbs                 varchar2(30)
);

alter table opas_ot_sql_vash2 ROW STORE COMPRESS ADVANCED;
alter table opas_ot_sql_vash2 add constraint fk_sql_vash2_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_vash2 add constraint fk_sql_vash2_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_vash2_dp    on opas_ot_sql_vash2(sql_data_point_id) compress;
create index idx_opas_sql_vash2_sqlid on opas_ot_sql_vash2(sql_id) compress;

CREATE GLOBAL TEMPORARY TABLE OPAS_OT_TMP_GV$ASH 
   (INST_ID NUMBER, 
	SAMPLE_ID NUMBER, 
	SAMPLE_TIME TIMESTAMP (3), 
	SAMPLE_TIME_UTC TIMESTAMP (3), 
	USECS_PER_ROW NUMBER, 
	IS_AWR_SAMPLE VARCHAR2(1 BYTE), 
	SESSION_ID NUMBER, 
	SESSION_SERIAL# NUMBER, 
	SESSION_TYPE VARCHAR2(10 BYTE), 
	FLAGS NUMBER, 
	USER_ID NUMBER, 
	SQL_ID VARCHAR2(13 BYTE), 
	IS_SQLID_CURRENT VARCHAR2(1 BYTE), 
	SQL_CHILD_NUMBER NUMBER, 
	SQL_OPCODE NUMBER, 
	FORCE_MATCHING_SIGNATURE NUMBER, 
	TOP_LEVEL_SQL_ID VARCHAR2(13 BYTE), 
	TOP_LEVEL_SQL_OPCODE NUMBER, 
	SQL_OPNAME VARCHAR2(64 BYTE), 
	SQL_ADAPTIVE_PLAN_RESOLVED NUMBER, 
	SQL_FULL_PLAN_HASH_VALUE NUMBER, 
	SQL_PLAN_HASH_VALUE NUMBER, 
	SQL_PLAN_LINE_ID NUMBER, 
	SQL_PLAN_OPERATION VARCHAR2(30 BYTE), 
	SQL_PLAN_OPTIONS VARCHAR2(30 BYTE), 
	SQL_EXEC_ID NUMBER, 
	SQL_EXEC_START DATE, 
	PLSQL_ENTRY_OBJECT_ID NUMBER, 
	PLSQL_ENTRY_SUBPROGRAM_ID NUMBER, 
	PLSQL_OBJECT_ID NUMBER, 
	PLSQL_SUBPROGRAM_ID NUMBER, 
	QC_INSTANCE_ID NUMBER, 
	QC_SESSION_ID NUMBER, 
	QC_SESSION_SERIAL# NUMBER, 
	PX_FLAGS NUMBER, 
	EVENT VARCHAR2(64 BYTE), 
	EVENT_ID NUMBER, 
	EVENT# NUMBER, 
	SEQ# NUMBER, 
	P1TEXT VARCHAR2(64 BYTE), 
	P1 NUMBER, 
	P2TEXT VARCHAR2(64 BYTE), 
	P2 NUMBER, 
	P3TEXT VARCHAR2(64 BYTE), 
	P3 NUMBER, 
	WAIT_CLASS VARCHAR2(64 BYTE), 
	WAIT_CLASS_ID NUMBER, 
	WAIT_TIME NUMBER, 
	SESSION_STATE VARCHAR2(7 BYTE), 
	TIME_WAITED NUMBER, 
	BLOCKING_SESSION_STATUS VARCHAR2(11 BYTE), 
	BLOCKING_SESSION NUMBER, 
	BLOCKING_SESSION_SERIAL# NUMBER, 
	BLOCKING_INST_ID NUMBER, 
	BLOCKING_HANGCHAIN_INFO VARCHAR2(1 BYTE), 
	CURRENT_OBJ# NUMBER, 
	CURRENT_FILE# NUMBER, 
	CURRENT_BLOCK# NUMBER, 
	CURRENT_ROW# NUMBER, 
	TOP_LEVEL_CALL# NUMBER, 
	TOP_LEVEL_CALL_NAME VARCHAR2(64 BYTE), 
	CONSUMER_GROUP_ID NUMBER, 
	XID RAW(8), 
	REMOTE_INSTANCE# NUMBER, 
	TIME_MODEL NUMBER, 
	IN_CONNECTION_MGMT VARCHAR2(1 BYTE), 
	IN_PARSE VARCHAR2(1 BYTE), 
	IN_HARD_PARSE VARCHAR2(1 BYTE), 
	IN_SQL_EXECUTION VARCHAR2(1 BYTE), 
	IN_PLSQL_EXECUTION VARCHAR2(1 BYTE), 
	IN_PLSQL_RPC VARCHAR2(1 BYTE), 
	IN_PLSQL_COMPILATION VARCHAR2(1 BYTE), 
	IN_JAVA_EXECUTION VARCHAR2(1 BYTE), 
	IN_BIND VARCHAR2(1 BYTE), 
	IN_CURSOR_CLOSE VARCHAR2(1 BYTE), 
	IN_SEQUENCE_LOAD VARCHAR2(1 BYTE), 
	IN_INMEMORY_QUERY VARCHAR2(1 BYTE), 
	IN_INMEMORY_POPULATE VARCHAR2(1 BYTE), 
	IN_INMEMORY_PREPOPULATE VARCHAR2(1 BYTE), 
	IN_INMEMORY_REPOPULATE VARCHAR2(1 BYTE), 
	IN_INMEMORY_TREPOPULATE VARCHAR2(1 BYTE), 
	IN_TABLESPACE_ENCRYPTION VARCHAR2(1 BYTE), 
	CAPTURE_OVERHEAD VARCHAR2(1 BYTE), 
	REPLAY_OVERHEAD VARCHAR2(1 BYTE), 
	IS_CAPTURED VARCHAR2(1 BYTE), 
	IS_REPLAYED VARCHAR2(1 BYTE), 
	IS_REPLAY_SYNC_TOKEN_HOLDER VARCHAR2(1 BYTE), 
	SERVICE_HASH NUMBER, 
	PROGRAM VARCHAR2(48 BYTE), 
	MODULE VARCHAR2(64 BYTE), 
	ACTION VARCHAR2(64 BYTE), 
	CLIENT_ID VARCHAR2(64 BYTE), 
	MACHINE VARCHAR2(64 BYTE), 
	PORT NUMBER, 
	ECID VARCHAR2(64 BYTE), 
	DBREPLAY_FILE_ID NUMBER, 
	DBREPLAY_CALL_COUNTER NUMBER, 
	TM_DELTA_TIME NUMBER, 
	TM_DELTA_CPU_TIME NUMBER, 
	TM_DELTA_DB_TIME NUMBER, 
	DELTA_TIME NUMBER, 
	DELTA_READ_IO_REQUESTS NUMBER, 
	DELTA_WRITE_IO_REQUESTS NUMBER, 
	DELTA_READ_IO_BYTES NUMBER, 
	DELTA_WRITE_IO_BYTES NUMBER, 
	DELTA_INTERCONNECT_IO_BYTES NUMBER, 
	DELTA_READ_MEM_BYTES NUMBER, 
	PGA_ALLOCATED NUMBER, 
	TEMP_SPACE_ALLOCATED NUMBER, 
	CON_DBID NUMBER, 
	CON_ID NUMBER, 
	DBOP_NAME VARCHAR2(30 BYTE), 
	DBOP_EXEC_ID NUMBER
   ) ON COMMIT DELETE ROWS ;


create global temporary table opas_ot_tmp_gv$ash_objs (
object_id number,
object_name varchar2(256),
object_type varchar2(256))
on commit delete rows;
 
---
CREATE TABLE OPAS_OT_SQL_AWR_SQLSTAT 
   (SNAP_ID NUMBER, 
	DBID NUMBER, 
	INSTANCE_NUMBER NUMBER, 
	SQL_ID VARCHAR2(13 BYTE), 
	PLAN_HASH_VALUE NUMBER, 
	OPTIMIZER_COST NUMBER, 
	OPTIMIZER_MODE VARCHAR2(10 BYTE), 
	OPTIMIZER_ENV_HASH_VALUE NUMBER, 
	SHARABLE_MEM NUMBER, 
	LOADED_VERSIONS NUMBER, 
	VERSION_COUNT NUMBER, 
	MODULE VARCHAR2(64 BYTE), 
	ACTION VARCHAR2(64 BYTE), 
	SQL_PROFILE VARCHAR2(64 BYTE), 
	FORCE_MATCHING_SIGNATURE NUMBER, 
	PARSING_SCHEMA_ID NUMBER, 
	PARSING_SCHEMA_NAME VARCHAR2(128 BYTE), 
	PARSING_USER_ID NUMBER, 
	FETCHES_TOTAL NUMBER, 
	FETCHES_DELTA NUMBER, 
	END_OF_FETCH_COUNT_TOTAL NUMBER, 
	END_OF_FETCH_COUNT_DELTA NUMBER, 
	SORTS_TOTAL NUMBER, 
	SORTS_DELTA NUMBER, 
	EXECUTIONS_TOTAL NUMBER, 
	EXECUTIONS_DELTA NUMBER, 
	PX_SERVERS_EXECS_TOTAL NUMBER, 
	PX_SERVERS_EXECS_DELTA NUMBER, 
	LOADS_TOTAL NUMBER, 
	LOADS_DELTA NUMBER, 
	INVALIDATIONS_TOTAL NUMBER, 
	INVALIDATIONS_DELTA NUMBER, 
	PARSE_CALLS_TOTAL NUMBER, 
	PARSE_CALLS_DELTA NUMBER, 
	DISK_READS_TOTAL NUMBER, 
	DISK_READS_DELTA NUMBER, 
	BUFFER_GETS_TOTAL NUMBER, 
	BUFFER_GETS_DELTA NUMBER, 
	ROWS_PROCESSED_TOTAL NUMBER, 
	ROWS_PROCESSED_DELTA NUMBER, 
	CPU_TIME_TOTAL NUMBER, 
	CPU_TIME_DELTA NUMBER, 
	ELAPSED_TIME_TOTAL NUMBER, 
	ELAPSED_TIME_DELTA NUMBER, 
	IOWAIT_TOTAL NUMBER, 
	IOWAIT_DELTA NUMBER, 
	CLWAIT_TOTAL NUMBER, 
	CLWAIT_DELTA NUMBER, 
	APWAIT_TOTAL NUMBER, 
	APWAIT_DELTA NUMBER, 
	CCWAIT_TOTAL NUMBER, 
	CCWAIT_DELTA NUMBER, 
	DIRECT_WRITES_TOTAL NUMBER, 
	DIRECT_WRITES_DELTA NUMBER, 
	PLSEXEC_TIME_TOTAL NUMBER, 
	PLSEXEC_TIME_DELTA NUMBER, 
	JAVEXEC_TIME_TOTAL NUMBER, 
	JAVEXEC_TIME_DELTA NUMBER, 
	IO_OFFLOAD_ELIG_BYTES_TOTAL NUMBER, 
	IO_OFFLOAD_ELIG_BYTES_DELTA NUMBER, 
	IO_INTERCONNECT_BYTES_TOTAL NUMBER, 
	IO_INTERCONNECT_BYTES_DELTA NUMBER, 
	PHYSICAL_READ_REQUESTS_TOTAL NUMBER, 
	PHYSICAL_READ_REQUESTS_DELTA NUMBER, 
	PHYSICAL_READ_BYTES_TOTAL NUMBER, 
	PHYSICAL_READ_BYTES_DELTA NUMBER, 
	PHYSICAL_WRITE_REQUESTS_TOTAL NUMBER, 
	PHYSICAL_WRITE_REQUESTS_DELTA NUMBER, 
	PHYSICAL_WRITE_BYTES_TOTAL NUMBER, 
	PHYSICAL_WRITE_BYTES_DELTA NUMBER, 
	OPTIMIZED_PHYSICAL_READS_TOTAL NUMBER, 
	OPTIMIZED_PHYSICAL_READS_DELTA NUMBER, 
	CELL_UNCOMPRESSED_BYTES_TOTAL NUMBER, 
	CELL_UNCOMPRESSED_BYTES_DELTA NUMBER, 
	IO_OFFLOAD_RETURN_BYTES_TOTAL NUMBER, 
	IO_OFFLOAD_RETURN_BYTES_DELTA NUMBER, 
	BIND_DATA RAW(2000), 
	FLAG NUMBER, 
	OBSOLETE_COUNT NUMBER, 
	CON_DBID NUMBER, 
	CON_ID NUMBER, 
	DBLINK VARCHAR2(128 BYTE) NOT NULL ENABLE, 
	INCARNATION# NUMBER);


alter table opas_ot_sql_awr_sqlstat ROW STORE COMPRESS ADVANCED;

alter table opas_ot_sql_awr_sqlstat add constraint fk_sql_awrsqlst_dbl foreign key (dblink) references opas_db_links (db_link_name);
create index idx_opas_sql_awr_sqlstat_dbl   on opas_ot_sql_awr_sqlstat(dblink) compress;

alter table opas_ot_sql_awr_sqlstat add constraint fk_sql_awrsqlst_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create unique index idx_opas_sql_awrsqlst_sqlid on opas_ot_sql_awr_sqlstat(sql_id,dblink,dbid,incarnation#,snap_id,instance_number,plan_hash_value,con_dbid) compress;

CREATE GLOBAL TEMPORARY TABLE OPAS_OT_TMP_AWRSQLSTAT 
   (SNAP_ID NUMBER, 
	DBID NUMBER, 
	INSTANCE_NUMBER NUMBER, 
	SQL_ID VARCHAR2(13 BYTE), 
	PLAN_HASH_VALUE NUMBER, 
	OPTIMIZER_COST NUMBER, 
	OPTIMIZER_MODE VARCHAR2(10 BYTE), 
	OPTIMIZER_ENV_HASH_VALUE NUMBER, 
	SHARABLE_MEM NUMBER, 
	LOADED_VERSIONS NUMBER, 
	VERSION_COUNT NUMBER, 
	MODULE VARCHAR2(64 BYTE), 
	ACTION VARCHAR2(64 BYTE), 
	SQL_PROFILE VARCHAR2(64 BYTE), 
	FORCE_MATCHING_SIGNATURE NUMBER, 
	PARSING_SCHEMA_ID NUMBER, 
	PARSING_SCHEMA_NAME VARCHAR2(128 BYTE), 
	PARSING_USER_ID NUMBER, 
	FETCHES_TOTAL NUMBER, 
	FETCHES_DELTA NUMBER, 
	END_OF_FETCH_COUNT_TOTAL NUMBER, 
	END_OF_FETCH_COUNT_DELTA NUMBER, 
	SORTS_TOTAL NUMBER, 
	SORTS_DELTA NUMBER, 
	EXECUTIONS_TOTAL NUMBER, 
	EXECUTIONS_DELTA NUMBER, 
	PX_SERVERS_EXECS_TOTAL NUMBER, 
	PX_SERVERS_EXECS_DELTA NUMBER, 
	LOADS_TOTAL NUMBER, 
	LOADS_DELTA NUMBER, 
	INVALIDATIONS_TOTAL NUMBER, 
	INVALIDATIONS_DELTA NUMBER, 
	PARSE_CALLS_TOTAL NUMBER, 
	PARSE_CALLS_DELTA NUMBER, 
	DISK_READS_TOTAL NUMBER, 
	DISK_READS_DELTA NUMBER, 
	BUFFER_GETS_TOTAL NUMBER, 
	BUFFER_GETS_DELTA NUMBER, 
	ROWS_PROCESSED_TOTAL NUMBER, 
	ROWS_PROCESSED_DELTA NUMBER, 
	CPU_TIME_TOTAL NUMBER, 
	CPU_TIME_DELTA NUMBER, 
	ELAPSED_TIME_TOTAL NUMBER, 
	ELAPSED_TIME_DELTA NUMBER, 
	IOWAIT_TOTAL NUMBER, 
	IOWAIT_DELTA NUMBER, 
	CLWAIT_TOTAL NUMBER, 
	CLWAIT_DELTA NUMBER, 
	APWAIT_TOTAL NUMBER, 
	APWAIT_DELTA NUMBER, 
	CCWAIT_TOTAL NUMBER, 
	CCWAIT_DELTA NUMBER, 
	DIRECT_WRITES_TOTAL NUMBER, 
	DIRECT_WRITES_DELTA NUMBER, 
	PLSEXEC_TIME_TOTAL NUMBER, 
	PLSEXEC_TIME_DELTA NUMBER, 
	JAVEXEC_TIME_TOTAL NUMBER, 
	JAVEXEC_TIME_DELTA NUMBER, 
	IO_OFFLOAD_ELIG_BYTES_TOTAL NUMBER, 
	IO_OFFLOAD_ELIG_BYTES_DELTA NUMBER, 
	IO_INTERCONNECT_BYTES_TOTAL NUMBER, 
	IO_INTERCONNECT_BYTES_DELTA NUMBER, 
	PHYSICAL_READ_REQUESTS_TOTAL NUMBER, 
	PHYSICAL_READ_REQUESTS_DELTA NUMBER, 
	PHYSICAL_READ_BYTES_TOTAL NUMBER, 
	PHYSICAL_READ_BYTES_DELTA NUMBER, 
	PHYSICAL_WRITE_REQUESTS_TOTAL NUMBER, 
	PHYSICAL_WRITE_REQUESTS_DELTA NUMBER, 
	PHYSICAL_WRITE_BYTES_TOTAL NUMBER, 
	PHYSICAL_WRITE_BYTES_DELTA NUMBER, 
	OPTIMIZED_PHYSICAL_READS_TOTAL NUMBER, 
	OPTIMIZED_PHYSICAL_READS_DELTA NUMBER, 
	CELL_UNCOMPRESSED_BYTES_TOTAL NUMBER, 
	CELL_UNCOMPRESSED_BYTES_DELTA NUMBER, 
	IO_OFFLOAD_RETURN_BYTES_TOTAL NUMBER, 
	IO_OFFLOAD_RETURN_BYTES_DELTA NUMBER, 
	BIND_DATA RAW(2000), 
	FLAG NUMBER, 
	OBSOLETE_COUNT NUMBER, 
	CON_DBID NUMBER, 
	CON_ID NUMBER
   ) ON COMMIT DELETE ROWS ;

--
CREATE TABLE OPAS_OT_SQL_AWR_SQLBIND 
   (SNAP_ID NUMBER, 
	DBID NUMBER, 
	INSTANCE_NUMBER NUMBER, 
	SQL_ID VARCHAR2(13 BYTE), 
	NAME VARCHAR2(128 BYTE), 
	POSITION NUMBER, 
	DUP_POSITION NUMBER, 
	DATATYPE NUMBER, 
	DATATYPE_STRING VARCHAR2(15 BYTE), 
	CHARACTER_SID NUMBER, 
	PRECISION NUMBER, 
	SCALE NUMBER, 
	MAX_LENGTH NUMBER, 
	WAS_CAPTURED VARCHAR2(3 BYTE), 
	LAST_CAPTURED DATE, 
	VALUE_STRING VARCHAR2(4000 BYTE), 
	VALUE_ANYDATA SYS.ANYDATA , 
	CON_DBID NUMBER, 
	CON_ID NUMBER, 
	DBLINK VARCHAR2(128 BYTE) NOT NULL ENABLE, 
	INCARNATION# NUMBER
	);

alter table opas_ot_sql_awr_sqlbind ROW STORE COMPRESS ADVANCED;

alter table opas_ot_sql_awr_sqlbind add constraint fk_sql_awrsqlbi_dbl foreign key (dblink) references opas_db_links (db_link_name);
create index idx_opas_sql_awr_sqlbind_dbl   on opas_ot_sql_awr_sqlbind(dblink) compress;

alter table opas_ot_sql_awr_sqlbind add constraint fk_sql_awrsqlbi_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_awrsqlbi_sqlid on opas_ot_sql_awr_sqlbind(sql_id,dblink,dbid,incarnation#,snap_id) compress;

CREATE GLOBAL TEMPORARY TABLE OPAS_OT_TMP_AWRSQLBIND 
   (SNAP_ID NUMBER, 
	DBID NUMBER, 
	INSTANCE_NUMBER NUMBER, 
	SQL_ID VARCHAR2(13 BYTE), 
	NAME VARCHAR2(128 BYTE), 
	POSITION NUMBER, 
	DUP_POSITION NUMBER, 
	DATATYPE NUMBER, 
	DATATYPE_STRING VARCHAR2(15 BYTE), 
	CHARACTER_SID NUMBER, 
	PRECISION NUMBER, 
	SCALE NUMBER, 
	MAX_LENGTH NUMBER, 
	WAS_CAPTURED VARCHAR2(3 BYTE), 
	LAST_CAPTURED DATE, 
	VALUE_STRING VARCHAR2(4000 BYTE), 
	VALUE_ANYDATA SYS.ANYDATA , 
	CON_DBID NUMBER, 
	CON_ID NUMBER
   ) ON COMMIT DELETE ROWS;
--

create sequence opas_ot_sq_awrplan_id;

CREATE TABLE OPAS_OT_SQL_AWR_PLANS 
   (PLAN_ID NUMBER, 
	CREATED TIMESTAMP (6) WITH TIME ZONE, 
	SQL_ID VARCHAR2(13 BYTE), 
	DBID NUMBER, 
	PLAN_HASH_VALUE NUMBER, 
	INCARNATION# NUMBER
	);

alter table opas_ot_sql_awr_plans ROW STORE COMPRESS ADVANCED;
alter table opas_ot_sql_awr_plans add constraint pk_sql_awrplan_id primary key(plan_id);
alter table opas_ot_sql_awr_plans add constraint fk_sql_awrplans_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;
create index idx_opas_sql_awrplans_sqlid on opas_ot_sql_awr_plans(sql_id) compress;

CREATE TABLE OPAS_OT_SQL_AWR_PLAN_DET 
   (PLAN_ID NUMBER, 
	DBID NUMBER, 
	SQL_ID VARCHAR2(13 BYTE), 
	PLAN_HASH_VALUE NUMBER, 
	ID NUMBER, 
	OPERATION VARCHAR2(30 BYTE), 
	OPTIONS VARCHAR2(30 BYTE), 
	OBJECT_NODE VARCHAR2(128 BYTE), 
	OBJECT# NUMBER, 
	OBJECT_OWNER VARCHAR2(128 BYTE), 
	OBJECT_NAME VARCHAR2(128 BYTE), 
	OBJECT_ALIAS VARCHAR2(261 BYTE), 
	OBJECT_TYPE VARCHAR2(20 BYTE), 
	OPTIMIZER VARCHAR2(20 BYTE), 
	PARENT_ID NUMBER, 
	DEPTH NUMBER, 
	POSITION NUMBER, 
	SEARCH_COLUMNS NUMBER, 
	COST NUMBER, 
	CARDINALITY NUMBER, 
	BYTES NUMBER, 
	OTHER_TAG VARCHAR2(35 BYTE), 
	PARTITION_START VARCHAR2(64 BYTE), 
	PARTITION_STOP VARCHAR2(64 BYTE), 
	PARTITION_ID NUMBER, 
	OTHER VARCHAR2(4000 BYTE), 
	DISTRIBUTION VARCHAR2(20 BYTE), 
	CPU_COST NUMBER, 
	IO_COST NUMBER, 
	TEMP_SPACE NUMBER, 
	ACCESS_PREDICATES VARCHAR2(4000 BYTE), 
	FILTER_PREDICATES VARCHAR2(4000 BYTE), 
	PROJECTION VARCHAR2(4000 BYTE), 
	TIME NUMBER, 
	QBLOCK_NAME VARCHAR2(128 BYTE), 
	REMARKS VARCHAR2(4000 BYTE), 
	TIMESTAMP DATE, 
	OTHER_XML CLOB, 
	CON_DBID NUMBER, 
	CON_ID NUMBER
	);
	
alter table opas_ot_sql_awr_plan_det add constraint fk_sql_awrpland_id foreign key (plan_id) references opas_ot_sql_awr_plans(plan_id) on delete cascade;
alter table opas_ot_sql_awr_plan_det add constraint fk_sql_awrpland_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;
create index idx_opas_sql_awrpland_id on opas_ot_sql_awr_plan_det(plan_id);
create index idx_opas_sql_awrpland_sqlid on opas_ot_sql_awr_plan_det(sql_id);

create table opas_ot_sql_awr_plan_ref (
 sql_data_point_id                                number                                 not null  references opas_ot_sql_data(sql_data_point_id) on delete cascade,
 plan_id                                          number                                 not null  references opas_ot_sql_awr_plans(plan_id) on delete cascade
);

create index idx_opas_sql_awrplan_ref_dp  on opas_ot_sql_awr_plan_ref(sql_data_point_id);
create index idx_opas_sql_awrplan_rep_pl on opas_ot_sql_awr_plan_ref(plan_id);

CREATE GLOBAL TEMPORARY TABLE OPAS_OT_TMP_DBH_PLAN 
   (	DBID NUMBER, 
	SQL_ID VARCHAR2(13 BYTE), 
	PLAN_HASH_VALUE NUMBER, 
	ID NUMBER, 
	OPERATION VARCHAR2(30 BYTE), 
	OPTIONS VARCHAR2(30 BYTE), 
	OBJECT_NODE VARCHAR2(128 BYTE), 
	OBJECT# NUMBER, 
	OBJECT_OWNER VARCHAR2(128 BYTE), 
	OBJECT_NAME VARCHAR2(128 BYTE), 
	OBJECT_ALIAS VARCHAR2(261 BYTE), 
	OBJECT_TYPE VARCHAR2(20 BYTE), 
	OPTIMIZER VARCHAR2(20 BYTE), 
	PARENT_ID NUMBER, 
	DEPTH NUMBER, 
	POSITION NUMBER, 
	SEARCH_COLUMNS NUMBER, 
	COST NUMBER, 
	CARDINALITY NUMBER, 
	BYTES NUMBER, 
	OTHER_TAG VARCHAR2(35 BYTE), 
	PARTITION_START VARCHAR2(64 BYTE), 
	PARTITION_STOP VARCHAR2(64 BYTE), 
	PARTITION_ID NUMBER, 
	OTHER VARCHAR2(4000 BYTE), 
	DISTRIBUTION VARCHAR2(20 BYTE), 
	CPU_COST NUMBER, 
	IO_COST NUMBER, 
	TEMP_SPACE NUMBER, 
	ACCESS_PREDICATES VARCHAR2(4000 BYTE), 
	FILTER_PREDICATES VARCHAR2(4000 BYTE), 
	PROJECTION VARCHAR2(4000 BYTE), 
	TIME NUMBER, 
	QBLOCK_NAME VARCHAR2(128 BYTE), 
	REMARKS VARCHAR2(4000 BYTE), 
	TIMESTAMP DATE, 
	OTHER_XML CLOB, 
	CON_DBID NUMBER, 
	CON_ID NUMBER
   ) ON COMMIT DELETE ROWS;

CREATE GLOBAL TEMPORARY TABLE OPAS_OT_TMP_DBH_PLAN_KEY 
   (PLAN_ID NUMBER, 
	PLAN_HASH_VALUE NUMBER
   ) ON COMMIT DELETE ROWS ;

--
create global temporary table opas_ot_tmp_dbh_ash
   (dbid number not null enable, 
    snap_id number not null enable, 
    session_id number not null enable, 
    session_serial# number, 
    instance_number number not null enable, 
    sql_id varchar2(13 byte), 
    top_level_sql_id varchar2(13 byte), 
    user_id number, 
    program varchar2(64 byte), 
    machine varchar2(64 byte), 
    module varchar2(64 byte), 
    action varchar2(64 byte), 
    client_id varchar2(64 byte), 
    ecid varchar2(64 byte), 
    plsql_entry_object_id number, 
    plsql_entry_subprogram_id number, 
    plsql_object_id number, 
    plsql_subprogram_id number, 
    force_matching_signature number, 
    sql_child_number number, 
    sql_plan_hash_value number, 
    sql_full_plan_hash_value number, 
    sql_exec_id number, 
    sql_exec_start date, 
    sql_plan_line_id number, 
    sql_plan_operation varchar2(64 byte), 
    sql_plan_options varchar2(64 byte), 
    event varchar2(64 byte), 
    session_type varchar2(10 byte), 
    con_id number, 
    con_dbid number, 
    min_sample_time timestamp (3), 
    max_sample_time timestamp (3), 
    cnt number, 
    pga_allocated number, 
    temp_space_allocated number,
	CURRENT_OBJ# number,
	CURRENT_FILE# number
   ) on commit delete rows ;
;
---
CREATE GLOBAL TEMPORARY TABLE OPAS_OT_TMP_AWR_ASH_OBJS 
   (OBJECT_ID NUMBER, 
	SUBPROGRAM_ID NUMBER, 
	OWNER VARCHAR2(128 BYTE), 
	OBJECT_TYPE VARCHAR2(13 BYTE), 
	OBJECT_NAME VARCHAR2(128 BYTE), 
	PROCEDURE_NAME VARCHAR2(128 BYTE)
   ) ON COMMIT DELETE ROWS ;

---
create table opas_ot_sql_awr_ash_summ 
   (topn number, 
	dbid number not null enable, 
	dblink  varchar2(128)  not null,
	snap_id number not null enable, 
	session_id number not null enable, 
	session_serial# number, 
	instance_number number not null enable, 
	sql_id varchar2(13 byte), 
	top_level_sql_id varchar2(13 byte), 
	user_id number, 
	program varchar2(64 byte), 
	machine varchar2(64 byte), 
	module varchar2(64 byte), 
	action varchar2(64 byte), 
	client_id varchar2(64 byte), 
	ecid varchar2(64 byte), 
	force_matching_signature number, 
	sql_child_number number, 
	sql_plan_hash_value number, 
	sql_full_plan_hash_value number, 
	sql_exec_id number, 
	sql_exec_start date, 
	session_type varchar2(10 byte), 
	con_id number, 
	con_dbid number, 
	username varchar2(128 byte),
	plsql_top varchar2(128 byte),
	plsql_end varchar2(128 byte),
	min_sample_time timestamp (3), 
	max_sample_time timestamp (3), 
	samples number, 
	pga_allocated number, 
	temp_space_allocated number,
	incarnation# number
   )
row store compress advanced logging;

alter table opas_ot_sql_awr_ash_summ add constraint fk_sql_awrashsum_dbl foreign key (dblink) references opas_db_links (db_link_name);
create index idx_opas_sql_awr_ashsum_dbl   on opas_ot_sql_awr_ash_summ(dblink) compress;

alter table opas_ot_sql_awr_ash_summ add constraint fk_sql_awrashsum_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;
create index idx_opas_sql_awrashsum_sqlid on opas_ot_sql_awr_ash_summ(sql_id, dblink, dbid, incarnation#, snap_id, sql_plan_hash_value, instance_number) compress;
---
create table opas_ot_sql_awr_ash_plst 
   (sql_id varchar2(13 byte), 
	dbid number, 
	snap_id number, 
	instance_number number,
	sql_plan_hash_value number, 
	sql_full_plan_hash_value number, 
	sql_plan_line_id number, 
	sql_plan_operation varchar2(64 byte), 
	sql_plan_options varchar2(64 byte), 
	event varchar2(64 byte), 
	samples number, 
	dblink varchar2(128 byte) not null enable,
    obj                 varchar2(256), 
    tbs                 varchar2(30),
	incarnation#        number
   ) 
row store compress advanced logging;

alter table opas_ot_sql_awr_ash_plst add constraint fk_sql_awrashplst_dbl foreign key (dblink)  references opas_db_links (db_link_name);
create index idx_opas_sql_awr_ashplst_dbl   on opas_ot_sql_awr_ash_plst(dblink) compress;

alter table opas_ot_sql_awr_ash_plst add constraint fk_sql_awrashplst_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;
create index idx_opas_sql_awrashplst_sqlid on opas_ot_sql_awr_ash_plst(sql_id, dblink, dbid, incarnation#, snap_id, sql_plan_hash_value, sql_plan_line_id, instance_number) compress;        

---------------------------------------------------------------------------------------------
-- Simple DB metric monitor
create table opas_ot_db_monitor (
metric_id       number                                           primary key,
dblink          varchar2(128)                                    references opas_db_links (db_link_name) on delete cascade,
schedule        number                                           references opas_scheduler (sch_id) on delete set null,
call_type       varchar2(512)                           not null check (call_type in ('SQL','FUNC')),
calc_code       varchar2(512),
convert_code    varchar2(1000),
measure         varchar2(32)
);

alter table opas_ot_db_monitor add constraint fk_ot_db_mon_obj foreign key (metric_id) references opas_objects(obj_id) on delete cascade;
create index idx_opas_ot_db_monitor_dbl   on opas_ot_db_monitor(dblink);
create index idx_opas_ot_db_monitor_sch   on opas_ot_db_monitor(schedule);

create table opas_ot_db_monitor_vals (
measur_id       number                                           generated always as identity primary key,
metric_id       number                                           references opas_ot_db_monitor (metric_id) on delete cascade,
tim             timestamp(6) WITH TIME ZONE,
val             number) row store compress advanced;

create index idx_opas_ot_db_monitor_vm   on opas_ot_db_monitor_vals(metric_id);

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

--
--
---------------------------------------------------------------------------------------------
-- sql lists
--create table opas_ot_sql_lists (
--sqllst_id           number                                           primary key,
--list_name           varchar2(100)                          not null,
--description         varchar2(4000)
--);

--alter table opas_ot_sql_lists add constraint fk_sql_lists_obj foreign key (sqllst_id) references opas_objects(obj_id) on delete cascade;

--create table opas_ot_lists2sqls (
--sqllst_id           number                                 not null  references opas_sql_lists(sqllst_id) on delete cascade,
--sql_id              varchar2(128)                          not null  references opas_query_storage(sql_id)
--);

--create unique index idx_opas_lists2sqls_sql_l on opas_ot_lists2sqls(sqllst_id, sql_id);
--create index idx_opas_lists2sqls_sql   on opas_ot_lists2sqls(sql_id);


create table opas_ot_sqlcatch (
 obj_id                            number                                 not null  references opas_objects(obj_id) on delete cascade,
 srcdb                             varchar2(128)                                    references opas_db_links (db_link_name),
 search_condition                  varchar2(4000),
 sql_num_limit                     number,
 sql_time_limit                    number,
 check_interval                    number,
 status                            varchar2(10),
 tq_id                             number,
 primary key (obj_id)
);

--create index idx_opas_sql_dp_ref_dp  on opas_ot_sql_data_point_ref(sql_data_point_id);
--create unique index idx_opas_sql_dp_rep_mon on opas_ot_sql_data_point_ref(obj_id);


create table opas_ot_sqlcatch_sqls (
 obj_id                            number                                 not null  references opas_ot_sqlcatch(obj_id) on delete cascade,
 sql_id                            varchar2(13 byte), 
 status                            varchar2(10),
 execs_num_to_init                 number,
 actual_execs                      number,
 sql_text                          varchar2(4000)
 primary key (obj_id, sql_id)
);

--create index idx_opas_sql_dp_ref_dp  on opas_ot_sql_data_point_ref(sql_data_point_id);
--create unique index idx_opas_sql_dp_rep_mon on opas_ot_sql_data_point_ref(obj_id);

create global temporary table opas_ot_tmp_sqlcatch_sqls (
 sql_id                            varchar2(13 byte), 
 actual_execs                      number,
 sql_text                          varchar2(4000)
) on commit preserve rows;