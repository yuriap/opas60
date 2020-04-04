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
