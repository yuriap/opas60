---------------------------------------------------------------------------------------------
-- module registry
---------------------------------------------------------------------------------------------
create table opas_modules (
modname             varchar2(128)                                   primary key,
moddescr            varchar2(4000),
modver              varchar2(32)                           not null,
installed           date                                   not null
);

---------------------------------------------------------------------------------------------
-- module metadata
---------------------------------------------------------------------------------------------
create table opas_config (
modname             varchar2(128)                                    references opas_modules(modname) on delete cascade,
cgroup              varchar2(128)                          not null,
ckey                varchar2(100)                          not null,
cvalue              varchar2(4000),
descr               varchar2(200)
);

alter table opas_config add constraint opas_config_pk primary key (modname,ckey);

create table opas_dictionary (
modname             varchar2(128)                          not null  references opas_modules(modname) on delete cascade,
dic_name            varchar2(20)                           not null,
val                 varchar2(128)                          not null,
display_val         varchar2(256)                          not null,
sparse1             varchar2(100),
sparse2             varchar2(100),
sparse3             varchar2(100),
dic_ordr            number);

create index idx_opas_dictionary_mod on opas_dictionary(modname,dic_name);

---------------------------------------------------------------------------------------------
-- OPAS Scheduler
---------------------------------------------------------------------------------------------
create table opas_scheduler (
sch_id          number                                           generated always as identity primary key,
schedule        varchar2(512),
plsql_call      varchar2(512)                           not null,
start_date      date,
last_changed    timestamp,
last_validated  timestamp,
job_name        varchar2(128),
owner           varchar2(128)    default 'PUBLIC'       not null,
status          varchar2(32)     default 'NEW'          not null
);

create or replace force view v$opas_scheduler as 
select *
  from opas_scheduler
 where owner = decode(owner,'PUBLIC', owner, nvl(v('APP_USER'),'~^'));

create table opas_scheduler_validation (
sch_id          number not null references opas_scheduler(sch_id) on delete cascade,
status          varchar2(100),
message         varchar2(4000)
);

create index idx_opas_scheduler_val on opas_scheduler_validation(sch_id);

---------------------------------------------------------------------------------------------
-- Alert system
---------------------------------------------------------------------------------------------

create table opas_alert_queue (
alert_id            number                                           generated always as identity primary key,
alert_type          varchar2(128)    default 'Default'     not null,
alert_source        varchar2(128),
owner               varchar2(128)    default 'PUBLIC'      not null,
message             varchar2(4000)                         not null,
link_page           number,
link_param          varchar2(128),
created             timestamp WITH TIME ZONE               not null,
viewed              timestamp,
status              varchar2(100)    default 'NEW'         not null --New, Viewed
);

create or replace force view v$opas_alert_queue as 
select 
  x.*,
  to_char(CREATED_HH,'YYYY-MM-DD HH24') || ' ' || TZHH ||':'||TZMI CREATED_HHTZ,
  to_char(CREATED_DD,'YYYY-MM-DD') || ' ' || TZHH ||':'||TZMI CREATED_DDTZ,
  to_char(CREATED_LHH,'YYYY-MM-DD HH24') CREATED_LHHTZ,
  to_char(CREATED_LDD,'YYYY-MM-DD') CREATED_LDDTZ  
from (
select 
       ALERT_ID,OWNER,MESSAGE,LINK_PAGE,LINK_PARAM,CREATED,VIEWED,STATUS,ALERT_TYPE,ALERT_SOURCE,
       trunc(created,'hh') CREATED_HH,
       trunc(created,'dd') CREATED_DD,
       trunc(CAST(created AS TIMESTAMP WITH LOCAL TIME ZONE),'hh') CREATED_LHH,
       trunc(CAST(created AS TIMESTAMP WITH LOCAL TIME ZONE),'dd') CREATED_LDD,       
       case when instr(EXTRACT(TIMEZONE_HOUR FROM created),'-')>0 then '-'||lpad(ltrim(EXTRACT(TIMEZONE_HOUR FROM created),'-'),2,'0')else lpad(EXTRACT(TIMEZONE_HOUR FROM created),2,'0') end TZHH, 
       lpad(EXTRACT(TIMEZONE_MINUTE FROM created),2,'0') TZMI
  from opas_alert_queue) x
 where owner = decode(owner,'PUBLIC', owner, nvl(v('APP_USER'),'~^'));
---------------------------------------------------------------------------------------------
-- database link dictionary
---------------------------------------------------------------------------------------------
create table opas_db_links (
db_link_name        varchar2(128)                                    primary key,
owner               varchar2(128)    default 'PUBLIC',
username            varchar2(128),
password            varchar2(128),
connstr             varchar2(1000),
status              varchar2(32)     default 'NEW'         not null,
is_public           varchar2(1)      default 'Y'           not null,
dbid                number,
update_sched        number                                           references opas_scheduler(sch_id) on delete set null
);

create or replace force view v$opas_db_links as 
with gn as (select value from v$parameter where name like '%domain%')
select db_link_name,
       case
         when db_link_name = '$LOCAL$' then db_link_name
         else l.db_link
       end ora_db_link,
       case
         when db_link_name = '$LOCAL$' then 'LOCAL'
         else 
           case when l.username is not null then db_link_name||' ('||l.username||'@'||l.host||')' else db_link_name||' (suspended)' end
         end display_name,
       owner, status, is_public, dbid,update_sched
  from opas_db_links o, user_db_links l, gn
 where owner =
       decode(owner,
              'PUBLIC',
              owner,
              decode(is_public, 'Y', owner, nvl(v('APP_USER'), '~^')))
   and l.db_link(+) = case when gn.value is null then upper(o.db_link_name) else upper(o.db_link_name ||'.'|| gn.value) end;

create table opas_db_link_cache (
dblink              varchar2(128)                          not null  references opas_db_links(db_link_name) on delete cascade,
key                 varchar2(128)                          not null,
value               varchar2(4000),
last_updated        timestamp         default systimestamp);

create unique index idx_opas_dblink_cache on opas_db_link_cache(dblink,key);
-------------------------------
CREATE TABLE OPAS_DB_LINK_V$DB 
   (DBLINK VARCHAR2(128 BYTE), 
	IS_ACTUAL CHAR(1 BYTE), 
	ACTUAL_SINCE TIMESTAMP (6) WITH TIME ZONE, 
	DBID NUMBER, 
	NAME VARCHAR2(9 BYTE), 
	CREATED DATE, 
	RESETLOGS_CHANGE# NUMBER, 
	RESETLOGS_TIME DATE, 
	PRIOR_RESETLOGS_CHANGE# NUMBER, 
	PRIOR_RESETLOGS_TIME DATE, 
	LOG_MODE VARCHAR2(12 BYTE), 
	CHECKPOINT_CHANGE# NUMBER, 
	ARCHIVE_CHANGE# NUMBER, 
	CONTROLFILE_TYPE VARCHAR2(7 BYTE), 
	CONTROLFILE_CREATED DATE, 
	CONTROLFILE_SEQUENCE# NUMBER, 
	CONTROLFILE_CHANGE# NUMBER, 
	CONTROLFILE_TIME DATE, 
	OPEN_RESETLOGS VARCHAR2(11 BYTE), 
	VERSION_TIME DATE, 
	OPEN_MODE VARCHAR2(20 BYTE), 
	PROTECTION_MODE VARCHAR2(20 BYTE), 
	PROTECTION_LEVEL VARCHAR2(20 BYTE), 
	REMOTE_ARCHIVE VARCHAR2(8 BYTE), 
	ACTIVATION# NUMBER, 
	SWITCHOVER# NUMBER, 
	DATABASE_ROLE VARCHAR2(16 BYTE), 
	ARCHIVELOG_CHANGE# NUMBER, 
	ARCHIVELOG_COMPRESSION VARCHAR2(8 BYTE), 
	SWITCHOVER_STATUS VARCHAR2(20 BYTE), 
	DATAGUARD_BROKER VARCHAR2(8 BYTE), 
	GUARD_STATUS VARCHAR2(7 BYTE), 
	SUPPLEMENTAL_LOG_DATA_MIN VARCHAR2(8 BYTE), 
	SUPPLEMENTAL_LOG_DATA_PK VARCHAR2(3 BYTE), 
	SUPPLEMENTAL_LOG_DATA_UI VARCHAR2(3 BYTE), 
	FORCE_LOGGING VARCHAR2(39 BYTE), 
	PLATFORM_ID NUMBER, 
	PLATFORM_NAME VARCHAR2(101 BYTE), 
	RECOVERY_TARGET_INCARNATION# NUMBER, 
	LAST_OPEN_INCARNATION# NUMBER, 
	CURRENT_SCN NUMBER, 
	FLASHBACK_ON VARCHAR2(18 BYTE), 
	SUPPLEMENTAL_LOG_DATA_FK VARCHAR2(3 BYTE), 
	SUPPLEMENTAL_LOG_DATA_ALL VARCHAR2(3 BYTE), 
	DB_UNIQUE_NAME VARCHAR2(30 BYTE), 
	STANDBY_BECAME_PRIMARY_SCN NUMBER, 
	FS_FAILOVER_STATUS VARCHAR2(22 BYTE), 
	FS_FAILOVER_CURRENT_TARGET VARCHAR2(30 BYTE), 
	FS_FAILOVER_THRESHOLD NUMBER, 
	FS_FAILOVER_OBSERVER_PRESENT VARCHAR2(7 BYTE), 
	FS_FAILOVER_OBSERVER_HOST VARCHAR2(512 BYTE), 
	CONTROLFILE_CONVERTED VARCHAR2(3 BYTE), 
	PRIMARY_DB_UNIQUE_NAME VARCHAR2(30 BYTE), 
	SUPPLEMENTAL_LOG_DATA_PL VARCHAR2(3 BYTE), 
	MIN_REQUIRED_CAPTURE_CHANGE# NUMBER, 
	CDB VARCHAR2(3 BYTE), 
	CON_ID NUMBER, 
	PENDING_ROLE_CHANGE_TASKS VARCHAR2(512 BYTE), 
	CON_DBID NUMBER, 
	FORCE_FULL_DB_CACHING VARCHAR2(3 BYTE));

create index idx_opas_dbl_db_dblink on opas_db_link_v$db(dblink,is_actual);
alter table opas_db_link_v$db add constraint fk_v$db_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_V$DATABASE 
   (DBID NUMBER, 
	NAME VARCHAR2(9 BYTE), 
	CREATED DATE, 
	RESETLOGS_CHANGE# NUMBER, 
	RESETLOGS_TIME DATE, 
	PRIOR_RESETLOGS_CHANGE# NUMBER, 
	PRIOR_RESETLOGS_TIME DATE, 
	LOG_MODE VARCHAR2(12 BYTE), 
	CHECKPOINT_CHANGE# NUMBER, 
	ARCHIVE_CHANGE# NUMBER, 
	CONTROLFILE_TYPE VARCHAR2(7 BYTE), 
	CONTROLFILE_CREATED DATE, 
	CONTROLFILE_SEQUENCE# NUMBER, 
	CONTROLFILE_CHANGE# NUMBER, 
	CONTROLFILE_TIME DATE, 
	OPEN_RESETLOGS VARCHAR2(11 BYTE), 
	VERSION_TIME DATE, 
	OPEN_MODE VARCHAR2(20 BYTE), 
	PROTECTION_MODE VARCHAR2(20 BYTE), 
	PROTECTION_LEVEL VARCHAR2(20 BYTE), 
	REMOTE_ARCHIVE VARCHAR2(8 BYTE), 
	ACTIVATION# NUMBER, 
	SWITCHOVER# NUMBER, 
	DATABASE_ROLE VARCHAR2(16 BYTE), 
	ARCHIVELOG_CHANGE# NUMBER, 
	ARCHIVELOG_COMPRESSION VARCHAR2(8 BYTE), 
	SWITCHOVER_STATUS VARCHAR2(20 BYTE), 
	DATAGUARD_BROKER VARCHAR2(8 BYTE), 
	GUARD_STATUS VARCHAR2(7 BYTE), 
	SUPPLEMENTAL_LOG_DATA_MIN VARCHAR2(8 BYTE), 
	SUPPLEMENTAL_LOG_DATA_PK VARCHAR2(3 BYTE), 
	SUPPLEMENTAL_LOG_DATA_UI VARCHAR2(3 BYTE), 
	FORCE_LOGGING VARCHAR2(39 BYTE), 
	PLATFORM_ID NUMBER, 
	PLATFORM_NAME VARCHAR2(101 BYTE), 
	RECOVERY_TARGET_INCARNATION# NUMBER, 
	LAST_OPEN_INCARNATION# NUMBER, 
	CURRENT_SCN NUMBER, 
	FLASHBACK_ON VARCHAR2(18 BYTE), 
	SUPPLEMENTAL_LOG_DATA_FK VARCHAR2(3 BYTE), 
	SUPPLEMENTAL_LOG_DATA_ALL VARCHAR2(3 BYTE), 
	DB_UNIQUE_NAME VARCHAR2(30 BYTE), 
	STANDBY_BECAME_PRIMARY_SCN NUMBER, 
	FS_FAILOVER_STATUS VARCHAR2(22 BYTE), 
	FS_FAILOVER_CURRENT_TARGET VARCHAR2(30 BYTE), 
	FS_FAILOVER_THRESHOLD NUMBER, 
	FS_FAILOVER_OBSERVER_PRESENT VARCHAR2(7 BYTE), 
	FS_FAILOVER_OBSERVER_HOST VARCHAR2(512 BYTE), 
	CONTROLFILE_CONVERTED VARCHAR2(3 BYTE), 
	PRIMARY_DB_UNIQUE_NAME VARCHAR2(30 BYTE), 
	SUPPLEMENTAL_LOG_DATA_PL VARCHAR2(3 BYTE), 
	MIN_REQUIRED_CAPTURE_CHANGE# NUMBER, 
	CDB VARCHAR2(3 BYTE), 
	CON_ID NUMBER, 
	PENDING_ROLE_CHANGE_TASKS VARCHAR2(512 BYTE), 
	CON_DBID NUMBER, 
	FORCE_FULL_DB_CACHING VARCHAR2(3 BYTE)
   ) ON COMMIT DELETE ROWS ;

----
CREATE TABLE OPAS_DB_LINK_V$PDBS 
   (DBLINK VARCHAR2(128 BYTE), 
	IS_ACTUAL CHAR(1 BYTE), 
	ACTUAL_SINCE TIMESTAMP (6) WITH TIME ZONE, 
	CON_ID NUMBER, 
	DBID NUMBER, 
	CON_UID NUMBER, 
	GUID RAW(16), 
	NAME VARCHAR2(128 BYTE), 
	OPEN_MODE VARCHAR2(10 BYTE), 
	RESTRICTED VARCHAR2(3 BYTE), 
	OPEN_TIME TIMESTAMP (3) WITH TIME ZONE, 
	CREATE_SCN NUMBER, 
	TOTAL_SIZE NUMBER, 
	BLOCK_SIZE NUMBER, 
	RECOVERY_STATUS VARCHAR2(8 BYTE), 
	SNAPSHOT_PARENT_CON_ID NUMBER, 
	APPLICATION_ROOT VARCHAR2(3 BYTE), 
	APPLICATION_PDB VARCHAR2(3 BYTE), 
	APPLICATION_SEED VARCHAR2(3 BYTE), 
	APPLICATION_ROOT_CON_ID NUMBER, 
	APPLICATION_ROOT_CLONE VARCHAR2(3 BYTE), 
	PROXY_PDB VARCHAR2(3 BYTE), 
	LOCAL_UNDO NUMBER, 
	UNDO_SCN NUMBER, 
	UNDO_TIMESTAMP DATE, 
	CREATION_TIME DATE, 
	DIAGNOSTICS_SIZE NUMBER, 
	PDB_COUNT NUMBER, 
	AUDIT_FILES_SIZE NUMBER, 
	MAX_SIZE NUMBER, 
	MAX_DIAGNOSTICS_SIZE NUMBER, 
	MAX_AUDIT_SIZE NUMBER, 
	LAST_CHANGED_BY VARCHAR2(11 BYTE), 
	TEMPLATE VARCHAR2(3 BYTE), 
	TENANT_ID VARCHAR2(256 BYTE), 
	UPGRADE_LEVEL NUMBER, 
	GUID_BASE64 VARCHAR2(30 BYTE)
   );

create index idx_opas_dbl_pdbs_dblink on opas_db_link_v$pdbs(dblink,is_actual);
alter table opas_db_link_v$pdbs add constraint fk_v$pdbs_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_V$PDBS 
   (CON_ID NUMBER, 
	DBID NUMBER, 
	CON_UID NUMBER, 
	GUID RAW(16), 
	NAME VARCHAR2(128 BYTE), 
	OPEN_MODE VARCHAR2(10 BYTE), 
	RESTRICTED VARCHAR2(3 BYTE), 
	OPEN_TIME TIMESTAMP (3) WITH TIME ZONE, 
	CREATE_SCN NUMBER, 
	TOTAL_SIZE NUMBER, 
	BLOCK_SIZE NUMBER, 
	RECOVERY_STATUS VARCHAR2(8 BYTE), 
	SNAPSHOT_PARENT_CON_ID NUMBER, 
	APPLICATION_ROOT VARCHAR2(3 BYTE), 
	APPLICATION_PDB VARCHAR2(3 BYTE), 
	APPLICATION_SEED VARCHAR2(3 BYTE), 
	APPLICATION_ROOT_CON_ID NUMBER, 
	APPLICATION_ROOT_CLONE VARCHAR2(3 BYTE), 
	PROXY_PDB VARCHAR2(3 BYTE), 
	LOCAL_UNDO NUMBER, 
	UNDO_SCN NUMBER, 
	UNDO_TIMESTAMP DATE, 
	CREATION_TIME DATE, 
	DIAGNOSTICS_SIZE NUMBER, 
	PDB_COUNT NUMBER, 
	AUDIT_FILES_SIZE NUMBER, 
	MAX_SIZE NUMBER, 
	MAX_DIAGNOSTICS_SIZE NUMBER, 
	MAX_AUDIT_SIZE NUMBER, 
	LAST_CHANGED_BY VARCHAR2(11 BYTE), 
	TEMPLATE VARCHAR2(3 BYTE), 
	TENANT_ID VARCHAR2(256 BYTE), 
	UPGRADE_LEVEL NUMBER, 
	GUID_BASE64 VARCHAR2(30 BYTE)
   ) ON COMMIT DELETE ROWS ;
----

CREATE TABLE OPAS_DB_LINK_V$INST 
   (DBLINK VARCHAR2(128 BYTE), 
	INST_ID NUMBER, 
	INSTANCE_NUMBER NUMBER, 
	INSTANCE_NAME VARCHAR2(16 BYTE), 
	HOST_NAME VARCHAR2(64 BYTE), 
	VERSION VARCHAR2(17 BYTE), 
	VERSION_LEGACY VARCHAR2(17 BYTE), 
	VERSION_FULL VARCHAR2(17 BYTE), 
	STARTUP_TIME DATE, 
	STATUS VARCHAR2(12 BYTE), 
	PARALLEL VARCHAR2(3 BYTE), 
	THREAD# NUMBER, 
	ARCHIVER VARCHAR2(7 BYTE), 
	LOG_SWITCH_WAIT VARCHAR2(15 BYTE), 
	LOGINS VARCHAR2(10 BYTE), 
	SHUTDOWN_PENDING VARCHAR2(3 BYTE), 
	DATABASE_STATUS VARCHAR2(17 BYTE), 
	INSTANCE_ROLE VARCHAR2(18 BYTE), 
	ACTIVE_STATE VARCHAR2(9 BYTE), 
	BLOCKED VARCHAR2(3 BYTE), 
	CON_ID NUMBER, 
	INSTANCE_MODE VARCHAR2(11 BYTE), 
	EDITION VARCHAR2(7 BYTE), 
	FAMILY VARCHAR2(80 BYTE), 
	DATABASE_TYPE VARCHAR2(15 BYTE)
   );
   
create index idx_opas_dbl_vinst_dblink on opas_db_link_v$inst(dblink);
alter table opas_db_link_v$inst add constraint fk_v$inst_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_V$INST 
   (INST_ID NUMBER, 
	INSTANCE_NUMBER NUMBER, 
	INSTANCE_NAME VARCHAR2(16 BYTE), 
	HOST_NAME VARCHAR2(64 BYTE), 
	VERSION VARCHAR2(17 BYTE), 
	VERSION_LEGACY VARCHAR2(17 BYTE), 
	VERSION_FULL VARCHAR2(17 BYTE), 
	STARTUP_TIME DATE, 
	STATUS VARCHAR2(12 BYTE), 
	PARALLEL VARCHAR2(3 BYTE), 
	THREAD# NUMBER, 
	ARCHIVER VARCHAR2(7 BYTE), 
	LOG_SWITCH_WAIT VARCHAR2(15 BYTE), 
	LOGINS VARCHAR2(10 BYTE), 
	SHUTDOWN_PENDING VARCHAR2(3 BYTE), 
	DATABASE_STATUS VARCHAR2(17 BYTE), 
	INSTANCE_ROLE VARCHAR2(18 BYTE), 
	ACTIVE_STATE VARCHAR2(9 BYTE), 
	BLOCKED VARCHAR2(3 BYTE), 
	CON_ID NUMBER, 
	INSTANCE_MODE VARCHAR2(11 BYTE), 
	EDITION VARCHAR2(7 BYTE), 
	FAMILY VARCHAR2(80 BYTE), 
	DATABASE_TYPE VARCHAR2(15 BYTE)
   ) ON COMMIT DELETE ROWS ;
----
CREATE TABLE OPAS_DB_LINK_DBH_INST 
   (DBLINK VARCHAR2(128 BYTE), 
	DBID NUMBER, 
	INSTANCE_NUMBER NUMBER, 
	STARTUP_TIME TIMESTAMP (3), 
	PARALLEL VARCHAR2(3 BYTE), 
	VERSION VARCHAR2(17 BYTE), 
	DB_NAME VARCHAR2(9 BYTE), 
	INSTANCE_NAME VARCHAR2(16 BYTE), 
	HOST_NAME VARCHAR2(64 BYTE), 
	LAST_ASH_SAMPLE_ID NUMBER, 
	PLATFORM_NAME VARCHAR2(101 BYTE), 
	CDB VARCHAR2(3 BYTE), 
	EDITION VARCHAR2(7 BYTE), 
	DB_UNIQUE_NAME VARCHAR2(30 BYTE), 
	DATABASE_ROLE VARCHAR2(16 BYTE), 
	CDB_ROOT_DBID NUMBER, 
	CON_ID NUMBER, 
	STARTUP_TIME_TZ TIMESTAMP (3) WITH TIME ZONE);

create index idx_opas_dbl_inst_dblink on opas_db_link_dbh_inst(dblink);
alter table opas_db_link_dbh_inst add constraint fk_dbh_inst_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_AWRINST 
   (DBID NUMBER, 
	INSTANCE_NUMBER NUMBER, 
	STARTUP_TIME TIMESTAMP (3), 
	PARALLEL VARCHAR2(3 BYTE), 
	VERSION VARCHAR2(17 BYTE), 
	DB_NAME VARCHAR2(9 BYTE), 
	INSTANCE_NAME VARCHAR2(16 BYTE), 
	HOST_NAME VARCHAR2(64 BYTE), 
	LAST_ASH_SAMPLE_ID NUMBER, 
	PLATFORM_NAME VARCHAR2(101 BYTE), 
	CDB VARCHAR2(3 BYTE), 
	EDITION VARCHAR2(7 BYTE), 
	DB_UNIQUE_NAME VARCHAR2(30 BYTE), 
	DATABASE_ROLE VARCHAR2(16 BYTE), 
	CDB_ROOT_DBID NUMBER, 
	CON_ID NUMBER, 
	STARTUP_TIME_TZ TIMESTAMP (3) WITH TIME ZONE
   ) ON COMMIT DELETE ROWS ;
----
CREATE TABLE OPAS_DB_LINK_REGHST 
   (DBLINK VARCHAR2(128 BYTE), 
	ACTION_TIME TIMESTAMP (6), 
	ACTION VARCHAR2(30 BYTE), 
	NAMESPACE VARCHAR2(30 BYTE), 
	VERSION VARCHAR2(30 BYTE), 
	ID NUMBER, 
	COMMENTS VARCHAR2(255 BYTE), 
	BUNDLE_SERIES VARCHAR2(30 BYTE));

create index idx_opas_db_link_reg_dblink on opas_db_link_reghst(dblink);
alter table opas_db_link_reghst add constraint fk_dbl_reghst_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_REGHST 
   (	ACTION_TIME TIMESTAMP (6), 
	ACTION VARCHAR2(30 BYTE), 
	NAMESPACE VARCHAR2(30 BYTE), 
	VERSION VARCHAR2(30 BYTE), 
	ID NUMBER, 
	COMMENTS VARCHAR2(255 BYTE), 
	BUNDLE_SERIES VARCHAR2(30 BYTE)
   ) ON COMMIT DELETE ROWS ;
----

CREATE TABLE OPAS_DB_LINK_SQLPTCHHST 
   (DBLINK VARCHAR2(128 BYTE), 
	INSTALL_ID NUMBER, 
	PATCH_ID NUMBER, 
	PATCH_UID NUMBER, 
	PATCH_TYPE VARCHAR2(10 BYTE), 
	ACTION VARCHAR2(15 BYTE), 
	STATUS VARCHAR2(25 BYTE), 
	ACTION_TIME TIMESTAMP (6), 
	DESCRIPTION VARCHAR2(100 BYTE), 
	LOGFILE VARCHAR2(500 BYTE), 
	RU_LOGFILE VARCHAR2(500 BYTE), 
	FLAGS VARCHAR2(10 BYTE), 
	PATCH_DESCRIPTOR SYS.XMLTYPE , 
	PATCH_DIRECTORY BLOB, 
	SOURCE_VERSION VARCHAR2(15 BYTE), 
	SOURCE_BUILD_DESCRIPTION VARCHAR2(80 BYTE), 
	SOURCE_BUILD_TIMESTAMP TIMESTAMP (6), 
	TARGET_VERSION VARCHAR2(15 BYTE), 
	TARGET_BUILD_DESCRIPTION VARCHAR2(80 BYTE), 
	TARGET_BUILD_TIMESTAMP TIMESTAMP (6)
   );
   
create index idx_opas_db_link_ptch_dblink on opas_db_link_sqlptchhst(dblink);
alter table opas_db_link_sqlptchhst add constraint fk_dbl_ptch_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;


CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_SQLPTCHHST 
   (INSTALL_ID NUMBER, 
	PATCH_ID NUMBER, 
	PATCH_UID NUMBER, 
	PATCH_TYPE VARCHAR2(10 BYTE), 
	ACTION VARCHAR2(15 BYTE), 
	STATUS VARCHAR2(25 BYTE), 
	ACTION_TIME TIMESTAMP (6), 
	DESCRIPTION VARCHAR2(100 BYTE), 
	LOGFILE VARCHAR2(500 BYTE), 
	RU_LOGFILE VARCHAR2(500 BYTE), 
	FLAGS VARCHAR2(10 BYTE), 
	PATCH_DESCRIPTOR SYS.XMLTYPE , 
	PATCH_DIRECTORY BLOB, 
	SOURCE_VERSION VARCHAR2(15 BYTE), 
	SOURCE_BUILD_DESCRIPTION VARCHAR2(80 BYTE), 
	SOURCE_BUILD_TIMESTAMP TIMESTAMP (6), 
	TARGET_VERSION VARCHAR2(15 BYTE), 
	TARGET_BUILD_DESCRIPTION VARCHAR2(80 BYTE), 
	TARGET_BUILD_TIMESTAMP TIMESTAMP (6)
   ) ON COMMIT DELETE ROWS 
;
----
CREATE TABLE OPAS_DB_LINK_AWRSNAPS 
   (DBLINK VARCHAR2(128 BYTE), 
	SNAP_ID NUMBER, 
	DBID NUMBER, 
	INSTANCE_NUMBER NUMBER, 
	STARTUP_TIME TIMESTAMP (3), 
	BEGIN_INTERVAL_TIME TIMESTAMP (3), 
	END_INTERVAL_TIME TIMESTAMP (3), 
	FLUSH_ELAPSED INTERVAL DAY (5) TO SECOND (1), 
	SNAP_LEVEL NUMBER, 
	ERROR_COUNT NUMBER, 
	SNAP_FLAG NUMBER, 
	SNAP_TIMEZONE INTERVAL DAY (0) TO SECOND (0), 
	BEGIN_INTERVAL_TIME_TZ TIMESTAMP (3) WITH TIME ZONE, 
	END_INTERVAL_TIME_TZ TIMESTAMP (3) WITH TIME ZONE, 
	CON_ID NUMBER, 
	INCARNATION# NUMBER);

create index idx_opas_db_link_awrsn_dblink on opas_db_link_awrsnaps(dblink);
alter table opas_db_link_awrsnaps add constraint fk_dbl_awrsn_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_AWRSNAPS 
   (SNAP_ID NUMBER, 
	DBID NUMBER, 
	INSTANCE_NUMBER NUMBER, 
	STARTUP_TIME TIMESTAMP (3), 
	BEGIN_INTERVAL_TIME TIMESTAMP (3), 
	END_INTERVAL_TIME TIMESTAMP (3), 
	FLUSH_ELAPSED INTERVAL DAY (5) TO SECOND (1), 
	SNAP_LEVEL NUMBER, 
	ERROR_COUNT NUMBER, 
	SNAP_FLAG NUMBER, 
	SNAP_TIMEZONE INTERVAL DAY (0) TO SECOND (0), 
	BEGIN_INTERVAL_TIME_TZ TIMESTAMP (3) WITH TIME ZONE, 
	END_INTERVAL_TIME_TZ TIMESTAMP (3) WITH TIME ZONE, 
	CON_ID NUMBER
   ) ON COMMIT PRESERVE ROWS ;
---------------------------------------------------------------------------------------------
-- file storage
---------------------------------------------------------------------------------------------
create table opas_files (
file_id             number                                           generated always as identity primary key,
modname             varchar2(128)                          not null  references opas_modules(modname) on delete cascade,
file_type           varchar2(100)                          not null,
file_name           varchar2(1000)                         not null,
file_mimetype       varchar2(30)                           not null,
file_contentb       blob,
file_contentc       clob,
created             timestamp        default systimestamp,
owner               varchar2(128)    default 'PUBLIC'      not null,
blob_prepared       timestamp
)
lob (file_contentb) store as (compress high)
lob (file_contentc) store as (compress high)
;

create index idx_opas_files_mod on opas_files(modname);

create index idx_txt_opas_files on opas_files(file_contentc) indextype is ctxsys.context
  parameters('filter ctxsys.null_filter section group ctxsys.html_section_group');

---------------------------------------------------------------------------------------------
-- authorization
---------------------------------------------------------------------------------------------
-- authorization group_id - is an access level
-- 0 - admin; 1 - rw; 2 - ro; 3 - noaccess;
create table opas_groups (
  group_id            number                                         primary key check (group_id in (0,1,2,3)),
  group_name          varchar2(100)                        not null,
  group_descr         varchar2(1000));

create table opas_groups2apexusr (
  group_id            number                               not null  references opas_groups(group_id),
  modname             varchar2(128)                        not null  references opas_modules(modname) on delete cascade,
  apex_user           varchar2(100)                        not null);

create index opas_groups2apexusr_usr on opas_groups2apexusr(apex_user);
create unique index opas_groups2apexusr_usr2grp on opas_groups2apexusr(modname,apex_user,group_id);

---------------------------------------------------------------------------------------------
-- navigator
---------------------------------------------------------------------------------------------
create table opas_object_types (
  ot_id             number                                           primary key,
  ot_name           varchar2(100)                          not null,
  ot_descr          varchar2(4000),
--  ot_sortordr       number           default 0             not null,
  ot_icon           varchar2(100)    default 'DEF_ICON'    not null,
  ot_api_pkg        varchar2(128)
);

create table opas_object_pages (
  ot_app_page       number                                 not null,
  ot_id             number                                 not null  references opas_object_types(ot_id) on delete cascade,
  ot_page_type      varchar2(32)                           not null, --open, new, delete ...
  ot_page_descr     varchar2(4000)
);

create index idx_opas_object_pages_ot on opas_object_pages(ot_id);
create unique index idx_opas_object_pages_pt on opas_object_pages(ot_page_type,ot_app_page);

--create table opas_object_page_pars (
--  ot_par_name       varchar2(100)                                    primary key,
--  ot_app_page       number                                 not null  references opas_object_pages(ot_app_page) on delete cascade,
--  ot_par_def_val    varchar2(512),
--  ot_par_mandat     varchar2(1)      default 'n'           not null,
--  ot_par_sortordr   number                                 not null
--);

--create index idx_opas_object_page_pars_pg on opas_object_page_pars(ot_app_page);

create table opas_object_oper (
  ot_id             number                                 not null  references opas_object_types(ot_id) on delete cascade,
  ot_oper_type      varchar2(32)                           not null, --create, move, copy, delete, export, import ...
  ot_oper_package   varchar2(128)                          not null,
  ot_oper_procedure varchar2(128)                          not null
);

create index idx_opas_object_oper_ot on opas_object_oper(ot_id);

create table opas_objects (
  obj_id            number                                           generated always as identity primary key,
  obj_prnt          number                                           references opas_objects(obj_id),
  obj_ot            number                                 not null  references opas_object_types(ot_id),
  obj_created       date,
  obj_expired       date,
  obj_name          varchar2(100),
  obj_descr         varchar2(4000),
  obj_sortordr      number           default 0             not null,
  obj_owner         varchar2(128),
  obj_size          number           default 0,
  is_public         varchar2(1)      default 'Y'           not null,
  is_readonly       varchar2(1)      default 'N'           not null
);

create index idx_opas_objects_ot on opas_objects(obj_ot);
create index idx_opas_objects_prnt on opas_objects(obj_prnt);

create table opas_object_references (
  obj_id_src        number                                 not null  references opas_objects(obj_id) on delete cascade,
  obj_id_trg        number                                 not null  references opas_objects(obj_id) on delete cascade,
  obj_ref_type      varchar2(100)    default 'DEFAULT'     not null  -- DEFAULT, SQLOLDNEW, SQLTOPREC
);

create index idx_opas_object_references_src on opas_object_references(obj_id_src);
create index idx_opas_object_references_trg on opas_object_references(obj_id_trg);

create table opas_last_nav_folder (
  apex_user           varchar2(100)                        primary key,
  folder_id           number
)
organization index; 

create or replace force view v$opas_objects as
select
    obj_id,
    obj_prnt,
    obj_ot,
    obj_created,
    obj_expired,
    obj_name,
    obj_descr,
    obj_sortordr,
    obj_owner,
    is_public,
    is_readonly,
    ot_icon,
    ot_name,
    obj_size
from
    opas_objects o, opas_object_types ot 
where case when o.is_public = 'Y' or o.obj_owner = 'PUBLIC' then 1 else case  when o.obj_owner = v('APP_USER') then 1 else 0 end end = 1
and o.obj_ot=ot.ot_id;

create table opas_object_pars (
  obj_id              number                               not null  references opas_objects(obj_id) on delete cascade,
  par_name            varchar2(100)                        not null,
  num_par             number,
  varchar_par         varchar2(4000),
  date_par            date,
  dttz_par            timestamp with time zone
);

create unique index idx_opas_obj_pars on opas_object_pars(obj_id, par_name);


---------------------------------------------------------------------------------------------
-- task execution infrasrtucture
---------------------------------------------------------------------------------------------
create table opas_cleanup_tasks (
  taskname            varchar2(128)                                  primary key,
  modname             varchar2(128)                        not null  references opas_modules(modname) on delete cascade,
  created             timestamp      default systimestamp,
  frequency_h         number         default 24            not null,
  last_exec           timestamp,
  task_body           clob
);

create index idx_opas_cleanup_tasks_mod on opas_cleanup_tasks(modname);

create table opas_task (
  taskname            varchar2(128)                                  primary key,
  modname             varchar2(128)                        not null  references opas_modules(modname) on delete cascade,
  is_public           varchar2(1)    default 'Y'           not null,
  created             timestamp      default systimestamp,
  task_body           clob,
  task_priority       varchar2(10)   default 'NORM'      not null -- 'high', 'low'
);

create index idx_opas_task_mod on opas_task(modname);

create table opas_task_queue (
  tq_id               number                                         generated always as identity primary key,
  taskname            varchar2(128)                        not null  references opas_task(taskname) on delete cascade,
  task_subname        varchar2(128),
  trg_obj_id          number                                         references opas_objects(obj_id) on delete cascade,
  queued              timestamp,
  started             timestamp,
  finished            timestamp,
  cpu_time            number, --seconds
  elapsed_time        number,
  status              varchar2(32)   default 'NEW',
  owner               varchar2(128)                        not null,
  sid                 number,
  serial#             number,
  inst_id             number,
  job_name            varchar2(128)
);

create index idx_opas_task_exec_tsk on opas_task_queue(taskname);
create index idx_opas_task_exec_obj on opas_task_queue(trg_obj_id);

create table opas_task_pars (
  tq_id               number                               not null  references opas_task_queue(tq_id) on delete cascade,
  par_name            varchar2(100)                        not null,
  num_par             number,
  varchar_par         varchar2(4000),
  date_par            date,
  list_par            varchar2(4000)
);

create index idx_opas_task_parstske on opas_task_pars(tq_id);

create table opas_log (
  created             timestamp      default systimestamp,
  msg                 varchar2(4000),
  tq_id               number                                         references opas_task_queue(tq_id) on delete cascade,
  msg_long            clob
);

create index idx_opas_task_logtske on opas_log(tq_id);
create index idx_opas_task_created on opas_log(created);

create or replace force view v$opas_task_queue as 
select
  t.taskname, 
  t.modname, 
  q.task_subname, 
  t.is_public, 
  q.tq_id, 
  q.queued, 
  q.started, 
  q.finished, 
  q.cpu_time, 
  nvl(q.elapsed_time,round((sysdate-(q.started+0))*3600*24)) elapsed_time, 
  q.status, 
  q.owner, 
  q.sid, 
  q.serial#, 
  q.inst_id,
  q.job_name
from opas_task t left outer join opas_task_queue q on (t.taskname = q.taskname and q.owner=decode(t.is_public,'y',q.owner,nvl(v('APP_USER'),'~^')))
where 1=decode(t.is_public,'Y',1, coremod_sec.is_role_assigned_n(t.modname,'REAS-WRITE USERS'))
;

create or replace force view v$opas_task_queue_longops as
select tq.*,
       case 
         when message is null then 'N/A' 
         else opname || ':' || message || '; elapsed: ' || elapsed_seconds || '; remaining: ' || nvl(to_char(time_remaining), 'N/A') end msg,
       round(100 * (sofar / decode(totalwork,0,1,totalwork))) pct_done,
       units,opname,module,action
  from v$opas_task_queue           tq,
       gv$session_longops           lo,
       gv$session                   s
  where tq.sid = lo.sid(+)
    and tq.serial# = lo.serial#(+)
    and tq.inst_id = lo.inst_id(+)
    and tq.sid = s.sid(+)
    and tq.serial# = s.serial#(+)
    and tq.inst_id = s.inst_id(+)
;

---------------------------------------------------------------------------------------------
-- export/import
---------------------------------------------------------------------------------------------
create table opas_expimp_sessions (
sess_id             number                                           generated always as identity primary key,
tq_id               number                                           references opas_task_queue(tq_id) on delete set null,
expimp_file         number                                           references opas_files ( file_id ),
created             timestamp        default systimestamp,
owner               varchar2(128)    default 'PUBLIC'      not null,
sess_type           varchar2(3)      check (sess_type in ('IMP','EXP')),
status              varchar2(32)     default 'NEW'         not null
)
;
create index idx_opas_expimp_sessions_tq   on opas_expimp_sessions(tq_id);

create table opas_expimp_metadata (
sess_id             number                                 not null  references opas_expimp_sessions(sess_id) on delete cascade,
modname             varchar2(128)                          not null  references opas_modules(modname) on delete cascade,
import_prc          varchar2(128),
file_descr          varchar2(4000),
src_version         varchar2(128)                          not null,
src_core_version    varchar2(128)                          not null
);

create index idx_opas_expimp_metadata_mod   on opas_expimp_metadata(modname);
create index idx_opas_expimp_metadata_sess  on opas_expimp_metadata(sess_id);

create table opas_expimp_params (
sess_id             number                                 not null  references opas_expimp_sessions(sess_id) on delete cascade,
par_name            varchar2(128)                          not null,
par_value           varchar2(4000)
);

create index idx_opas_expimp_params_sess   on opas_expimp_params(sess_id);

create table opas_expimp_compat (
modname             varchar2(128)                          not null references opas_modules(modname) on delete cascade,
src_version         varchar2(100)                          not null,
trg_version         varchar2(100)                          not null
);

create or replace force view v$opas_expimp_sessions as
select 
    x.sess_id,
    x.tq_id,
    x.expimp_file file_id,
    x.created,
    x.owner,
    decode(x.sess_type,'EXP','EXPORT','IMP','IMPORT','UNKNOWN: '||x.sess_type) sess_type,
    x.status,
    m.modname,
    m.import_prc,
    m.file_descr,
    m.src_version,
    m.src_core_version,
    dbms_lob.getlength(f.file_contentb) fsize,
    f.file_name,
    case when m.modname is not null then to_char(x.created + to_number(coremod_api.getconf('expimpsess',m.modname)),'yyyy-mon-dd hh24:mi' ) else null end expiration
from opas_expimp_sessions x, opas_expimp_metadata m, opas_files f
where x.owner=decode(x.owner,'public',x.owner,nvl(v('app_user'),'~^'))
and x.sess_id=m.sess_id and x.expimp_file=f.file_id(+);

---------------------------------------------------------------------------------------------
-- miscelaneous
---------------------------------------------------------------------------------------------
create or replace type tableofnumbers as table of number
/
create or replace type tableofstrings as table of varchar2(4000)
/

--clob2row representation
--https://jonathanlewis.wordpress.com/2008/11/19/lateral-lobs/
create or replace type clob_line as object (
    line_number number,
    payload varchar2(4000)
)
/
 
create or replace type clob_page as table of clob_line
/

create or replace force view v$opas_file_contentbyrow
as
select
    /*+ cardinality(p1 10) */
    opas_files.file_id,
    p1.line_number,
    p1.payload
from
    opas_files,
    table(coremod_file_utils.clob2tab(opas_files.file_id)) p1
;
---------------------------------------------------------------------------------------------
-- core objects
---------------------------------------------------------------------------------------------
-- attachments
create table opas_ot_attachments (
attach_id           number                                           primary key,
modname             varchar2(128)                          not null  references opas_modules(modname) on delete cascade,
attach_content      number                                           references opas_files ( file_id ));

alter table opas_ot_attachments add constraint fk_attach_obj foreign key (attach_id) references opas_objects(obj_id);

create index idx_opas_attach_mod   on opas_ot_attachments(modname);
create index idx_opas_attach_cntn  on opas_ot_attachments(attach_content);

---------------------------------------------------------------------------------------------
-- db links assignments
create table opas_ot_dblinks2obj (
trg_obj_id          number                                 not null  references opas_objects(obj_id) on delete cascade,
dblink              varchar2(128)                          not null  references opas_db_links (db_link_name) on delete cascade,
default_dblink      varchar2(1)      default 'N'           not null,
sortordr            number           default 0             not null);

create unique index idx_opas_dblinks2obj_trg on opas_ot_dblinks2obj(trg_obj_id,dblink);
create index idx_opas_dblinks2obj_dbl  on opas_ot_dblinks2obj(dblink);

create or replace type t_opasobj_dblrec is object(
d varchar2(512),
r varchar2(128));
/

create or replace type t_opasobj_dbltab is table of t_opasobj_dblrec;
/

---------------------------------------------------------------------------------------------
-- memo
create table opas_ot_memo (
memo_id           number                                             primary key,
memo_content      number                                             references opas_files ( file_id ));

alter table opas_ot_memo add constraint fk_memo_obj foreign key (memo_id) references opas_objects(obj_id);

create index idx_opas_memo_cntn  on opas_ot_memo(memo_content);

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
error_message       varchar2(4000)
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

---------------------------------------------------------------------------------------------
-- reports
--create table opas_ot_reports (
--report_id           number                                           primary key,
--parent_id           number                                           references opas_reports(report_id) on delete set null,
--modname             varchar2(128)                          not null  references opas_modules(modname) on delete cascade,
--tq_id               number                                           references opas_task_queue(tq_id) on delete set null,
--report_content      number                                           references opas_files ( file_id ),
--report_params_displ varchar2(1000),
--report_type         varchar2(100)                          not null);

--alter table opas_ot_reports add constraint fk_reports_obj foreign key (report_id) references opas_objects(obj_id);

--create index idx_opas_reports_mod   on opas_ot_reports(modname);
--create index idx_opas_reports_fcntn on opas_ot_reports(report_content);

--create table opas_ot_reports_pars (
--report_id           number                                 not null  references opas_reports(report_id) on delete cascade,
--par_name            varchar2(100)                          not null,
--num_par             number,
--varchar_par         varchar2(4000),
--date_par            date
--);

--create index idx_opas_reports_parstske on opas_reports_pars(report_id);

@@create_struct_dbg