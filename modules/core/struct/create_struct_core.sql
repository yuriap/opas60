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
 where owner = decode(owner,'PUBLIC', owner,'INTERNAL', owner, nvl(v('APP_USER'),'~^'));

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
update_sched        varchar2(512),
created             timestamp default systimestamp,
data_updated        timestamp,
current_version     VARCHAR2(100)
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
       o.owner, o.status, o.is_public, o.dbid, o.update_sched, o.created, o.data_updated, o.current_version
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
DROP TABLE OPAS_DB_LINK_V$DB;
CREATE TABLE OPAS_DB_LINK_V$DB as
select * from v$database where 1=2;

alter table OPAS_DB_LINK_V$DB add DBLINK VARCHAR2(128 BYTE);
alter table OPAS_DB_LINK_V$DB add IS_ACTUAL CHAR(1 BYTE); 
alter table OPAS_DB_LINK_V$DB add ACTUAL_SINCE TIMESTAMP (6) WITH TIME ZONE; 

create index idx_opas_dbl_db_dblink on opas_db_link_v$db(dblink,is_actual);
alter table opas_db_link_v$db add constraint fk_v$db_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

DROP TABLE OPAS_DBL_TMP_V$DATABASE;
CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_V$DATABASE 
ON COMMIT DELETE ROWS as
select * from v$database where 1=2;
----
                                                
DROP TABLE OPAS_DB_LINK_V$PDBS;
CREATE TABLE OPAS_DB_LINK_V$PDBS as
select * from v$pdbs where 1=2; 

alter table OPAS_DB_LINK_V$PDBS add DBLINK VARCHAR2(128 BYTE);
alter table OPAS_DB_LINK_V$PDBS add IS_ACTUAL CHAR(1 BYTE);
alter table OPAS_DB_LINK_V$PDBS add ACTUAL_SINCE TIMESTAMP (6) WITH TIME ZONE;

create index idx_opas_dbl_pdbs_dblink on opas_db_link_v$pdbs(dblink,is_actual);
alter table opas_db_link_v$pdbs add constraint fk_v$pdbs_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

DROP TABLE OPAS_DBL_TMP_V$PDBS;
CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_V$PDBS 
ON COMMIT DELETE ROWS as
select * from v$pdbs where 1=2;
----
                                                
DROP TABLE OPAS_DB_LINK_V$INST;
CREATE TABLE OPAS_DB_LINK_V$INST as
select * from gv$instance where 1=2;

alter table OPAS_DB_LINK_V$INST add DBLINK VARCHAR2(128 BYTE);
   
create index idx_opas_dbl_vinst_dblink on opas_db_link_v$inst(dblink);
alter table opas_db_link_v$inst add constraint fk_v$inst_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

DROP TABLE OPAS_DBL_TMP_V$INST;
CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_V$INST 
ON COMMIT DELETE ROWS as
select * from gv$instance where 1=2;
----
                                                
DROP TABLE OPAS_DB_LINK_DBH_INST;
CREATE TABLE OPAS_DB_LINK_DBH_INST as
select * from dba_hist_database_instance where 1=2;

alter table OPAS_DB_LINK_DBH_INST add DBLINK VARCHAR2(128 BYTE);

create index idx_opas_dbl_inst_dblink on opas_db_link_dbh_inst(dblink);
alter table opas_db_link_dbh_inst add constraint fk_dbh_inst_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

DROP TABLE OPAS_DBL_TMP_AWRINST;
CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_AWRINST 
ON COMMIT DELETE ROWS as
select * from dba_hist_database_instance where 1=2;
----
                                                
DROP TABLE OPAS_DB_LINK_REGHST;
CREATE TABLE OPAS_DB_LINK_REGHST as
select * from dba_registry_history where 1=2;

alter table OPAS_DB_LINK_REGHST add DBLINK VARCHAR2(128 BYTE);

create index idx_opas_db_link_reg_dblink on opas_db_link_reghst(dblink);
alter table opas_db_link_reghst add constraint fk_dbl_reghst_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

DROP TABLE OPAS_DBL_TMP_REGHST;
CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_REGHST 
ON COMMIT DELETE ROWS as
select * from dba_registry_history where 1=2;
----
                                                
DROP TABLE OPAS_DB_LINK_SQLPTCHHST;
CREATE TABLE OPAS_DB_LINK_SQLPTCHHST as
select * from DBA_REGISTRY_SQLPATCH where 1=2;

alter table OPAS_DB_LINK_SQLPTCHHST add DBLINK VARCHAR2(128 BYTE);
   
create index idx_opas_db_link_ptch_dblink on opas_db_link_sqlptchhst(dblink);
alter table opas_db_link_sqlptchhst add constraint fk_dbl_ptch_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;
                                                
DROP TABLE OPAS_DBL_TMP_SQLPTCHHST;
CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_SQLPTCHHST 
ON COMMIT DELETE ROWS as
select * from DBA_REGISTRY_SQLPATCH where 1=2;
----
                                                
DROP TABLE OPAS_DB_LINK_AWRSNAPS;
CREATE TABLE OPAS_DB_LINK_AWRSNAPS as
select * from DBA_HIST_SNAPSHOT where 1=2;

alter table OPAS_DB_LINK_AWRSNAPS add DBLINK VARCHAR2(128 BYTE);
alter table OPAS_DB_LINK_AWRSNAPS add INCARNATION# NUMBER;
                                                
create index idx_opas_db_link_awrsn_dblink on opas_db_link_awrsnaps(dblink);
alter table opas_db_link_awrsnaps add constraint fk_dbl_awrsn_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

create index IDX_OPAS_DB_LINK_AWRSN_SEL1 on OPAS_DB_LINK_AWRSNAPS(DBLINK,DBID,INCARNATION#,INSTANCE_NUMBER,SNAP_ID);

DROP TABLE OPAS_DBL_TMP_AWRSNAPS;
CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_AWRSNAPS 
ON COMMIT PRESERVE ROWS as
select * from DBA_HIST_SNAPSHOT where 1=2;



CREATE GLOBAL TEMPORARY TABLE OPAS_DBL_TMP_METRICS
(GROUP_ID   NUMBER, 
GROUP_NAME  VARCHAR2(64 BYTE), 
METRIC_ID   NUMBER, 
METRIC_NAME VARCHAR2(64 BYTE), 
METRIC_UNIT VARCHAR2(64 BYTE),
SRC         VARCHAR2(100 BYTE)
) ON COMMIT DELETE ROWS ;

CREATE TABLE OPAS_DB_METRICS
(
GROUP_ID    NUMBER, 
GROUP_NAME  VARCHAR2(64 BYTE), 
METRIC_ID   NUMBER,
METRIC_NAME VARCHAR2(64 BYTE), 
METRIC_UNIT VARCHAR2(64 BYTE),
SRC         VARCHAR2(100 BYTE),
 primary key(GROUP_ID, METRIC_ID)
);

CREATE TABLE OPAS_DB_METRICS2VER
(
VERSION     VARCHAR2(100),
GROUP_ID    NUMBER, 
METRIC_ID   NUMBER,
constraint  FK_METR2VERS foreign key (GROUP_ID, METRIC_ID) references OPAS_DB_METRICS(GROUP_ID, METRIC_ID));

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

create table opas_app_state (
apex_user      varchar2(100)                        primary key,
jsparams       CLOB,
CONSTRAINT obj_app_st_json_chk CHECK (jsparams IS JSON));

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

alter table opas_object_pars add jsparams       CLOB;
alter table opas_object_pars add CONSTRAINT obj_pars_json_chk CHECK (jsparams IS JSON);

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
from opas_task t left outer join opas_task_queue q on (t.taskname = q.taskname and q.owner=decode(t.is_public,'Y',q.owner,nvl(v('APP_USER'),'~^')))
where 1=decode(t.is_public,'Y',1, coremod_sec.is_role_assigned_n(t.modname,'REAS-WRITE USERS'))
;

create or replace force view v$opas_task_queue_longops as
select tq.*,
       case 
         when message is null then 'N/A' 
         else /*opname || ':' || */ message || '; elapsed: ' || elapsed_seconds || '; remaining: ' || nvl(to_char(time_remaining), 'N/A') end msg,
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

drop type tableof2num;
drop type tableof2str;
create or replace type two_numbers as object (col1 number, col2 number)
/
create or replace type two_strings AS OBJECT(col1 VARCHAR2(4000), col2 VARCHAR2(4000))
/
create or replace type tableof2num as table of two_numbers
/
create or replace type tableof2str AS TABLE OF two_strings
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
-- Browser notificatinos
---------------------------------------------------------------------------------------------

  CREATE TABLE OPAS_NOTIFICATION 
   (ID NUMBER GENERATED ALWAYS AS IDENTITY MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE  NOKEEP  NOSCALE  NOT NULL ENABLE, 
	TYPE_ID NUMBER NOT NULL ENABLE, 
	TEXT VARCHAR2(1000 BYTE), 
	LINK VARCHAR2(1000 BYTE), 
	COLOR VARCHAR2(128 BYTE) DEFAULT 'rgb(86,86,86)' NOT NULL ENABLE, 
	USERNAME VARCHAR2(128 BYTE) DEFAULT 'PUBLIC', 
	NO_BROWSER_NOTIF_FLAG NUMBER(1,0) DEFAULT 0, 
	STATUS VARCHAR2(32 BYTE) DEFAULT 'NEW', 
	created timestamp default systimestamp
   );

