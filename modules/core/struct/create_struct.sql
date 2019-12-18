---------------------------------------------------------------------------------------------
-- Module registry
---------------------------------------------------------------------------------------------
create table opas_modules (
MODNAME             varchar2(128)                                   primary key,
MODDESCR            varchar2(4000),
MODVER              varchar2(32)                           not null,
INSTALLED           date                                   not null
);

---------------------------------------------------------------------------------------------
-- Module Metadata
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
-- Known query storage
---------------------------------------------------------------------------------------------
--create table opas_query_storage (
--sql_id              varchar2(128)                                    primary key,
--sql_text            clob,
--created             timestamp        default systimestamp,
--owner               varchar2(128)    default 'PUBLIC')
--lob (sql_text) store as (compress high)
--;

-- Text index TBD

---------------------------------------------------------------------------------------------
-- Database link dictionary
---------------------------------------------------------------------------------------------
create table opas_db_links (
db_link_name        varchar2(128)                                    primary key,
owner               varchar2(128)    default 'PUBLIC',
username            varchar2(128),
password            varchar2(128),
connstr             varchar2(1000),
STATUS              varchar2(32)     default 'NEW'         not null,
is_public           varchar2(1)      default 'Y'           not null);

CREATE OR REPLACE FORCE VIEW V$OPAS_DB_LINKS AS 
with gn as (select value from v$parameter where name like '%domain%')
select DB_LINK_NAME,
       case
         when DB_LINK_NAME = '$LOCAL$' then DB_LINK_NAME
         else l.db_link
       end ORA_DB_LINK,
       case
         when DB_LINK_NAME = '$LOCAL$' then 'LOCAL'
         else 
           case when l.username is not null then DB_LINK_NAME||' ('||l.username||'@'||l.host||')' else DB_LINK_NAME||' (SUSPENDED)' end
         end DISPLAY_NAME,
       OWNER,
       STATUS,
       IS_PUBLIC
  from OPAS_DB_LINKS o, user_db_links l, gn
 where owner =
       decode(owner,
              'PUBLIC',
              owner,
              decode(is_public, 'Y', owner, nvl(V('APP_USER'), '~^')))
   and l.db_link(+) = case when gn.value is null then upper(o.DB_LINK_NAME) else upper(o.DB_LINK_NAME ||'.'|| gn.value) end;

create table opas_db_link_cache (
dblink              varchar2(128)                          not null  references opas_db_links(db_link_name) on delete cascade,
key                 varchar2(128)                          not null,
value               varchar2(4000),
last_updated        timestamp         default systimestamp);

create unique index idx_opas_dblink_cache on opas_db_link_cache(dblink,key);



---------------------------------------------------------------------------------------------
-- File storage
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
-- Authorization
---------------------------------------------------------------------------------------------
-- Authorization group_id - is an access level
-- 0 - admin; 1 - rw; 2 - RO; 3 - noaccess;
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
-- Navigator
---------------------------------------------------------------------------------------------
create table opas_object_types (
  ot_id             number                                           primary key,
  ot_name           varchar2(100)                          not null,
  ot_descr          varchar2(4000),
--  ot_sortordr       number           default 0             not null,
  ot_icon           varchar2(100)    default 'def_icon'    not null,
  ot_api_pkg        varchar2(128)
);

create table opas_object_pages (
  ot_app_page       number                                 not null,
  ot_id             number                                 not null  references opas_object_types(ot_id) on delete cascade,
  ot_page_type      varchar2(32)                           not null, --OPEN, NEW, DELETE ...
  ot_page_descr     varchar2(4000)
);

create index idx_opas_object_pages_ot on opas_object_pages(ot_id);
create unique index idx_opas_object_pages_pt on opas_object_pages(ot_page_type,ot_app_page);

--create table opas_object_page_pars (
--  ot_par_name       varchar2(100)                                    primary key,
--  ot_app_page       number                                 not null  references opas_object_pages(ot_app_page) on delete cascade,
--  ot_par_def_val    varchar2(512),
--  ot_par_mandat     varchar2(1)      default 'N'           not null,
--  ot_par_sortordr   number                                 not null
--);

--create index idx_opas_object_page_pars_pg on opas_object_page_pars(ot_app_page);

create table opas_object_oper (
  ot_id             number                                 not null  references opas_object_types(ot_id) on delete cascade,
  ot_oper_type      varchar2(32)                           not null, --CREATE, MOVE, COPY, DELETE, EXPORT, IMPORT ...
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
FROM
    opas_objects o, opas_object_types ot 
where case when o.is_public = 'Y' or o.obj_owner = 'PUBLIC' then 1 else case  when o.obj_owner = V('APP_USER') then 1 else 0 end end = 1
and o.obj_ot=ot.ot_id;

create table opas_object_pars (
  obj_id              number                               not null  references opas_objects(obj_id) on delete cascade,
  PAR_NAME            varchar2(100)                        not null,
  num_par             number,
  varchar_par         varchar2(4000),
  date_par            date
);

create unique index idx_opas_obj_pars on opas_object_pars(obj_id, PAR_NAME);


---------------------------------------------------------------------------------------------
-- Task execution infrasrtucture
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
  task_priority       varchar2(10)   default 'NORM'      not null -- 'HIGH', 'LOW'
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
  PAR_NAME            varchar2(100)                        not null,
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

CREATE OR REPLACE FORCE VIEW V$OPAS_TASK_QUEUE AS 
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
from opas_task t left outer join opas_task_queue q on (t.taskname = q.taskname and q.owner=decode(t.is_public,'Y',q.owner,nvl(V('APP_USER'),'~^')))
where 1=decode(t.is_public,'Y',1, COREMOD_SEC.is_role_assigned_n(t.modname,'Reas-write users'))
;

CREATE OR REPLACE FORCE VIEW V$OPAS_TASK_QUEUE_LONGOPS AS
select tq.*,
       case 
         when message is null then 'N/A' 
         else opname || ':' || message || '; elapsed: ' || elapsed_seconds || '; remaining: ' || nvl(to_char(time_remaining), 'N/A') end msg,
       round(100 * (sofar / decode(totalwork,0,1,totalwork))) pct_done,
       units,opname,module,action
  from V$OPAS_TASK_QUEUE           tq,
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
-- Export/Import
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
    decode(x.sess_type,'EXP','Export','IMP','Import','Unknown: '||x.sess_type) sess_type,
    x.status,
    m.modname,
    m.import_prc,
    m.file_descr,
    m.src_version,
    m.src_core_version,
    dbms_lob.getlength(f.file_contentb) fsize,
    f.file_name,
    case when m.MODNAME is not null then to_char(x.created + to_number(COREMOD_API.getconf('EXPIMPSESS',m.MODNAME)),'YYYY-MON-DD HH24:MI' ) else null end expiration
from opas_expimp_sessions x, opas_expimp_metadata m, opas_files f
where x.owner=decode(x.owner,'PUBLIC',x.owner,nvl(V('APP_USER'),'~^'))
and x.sess_id=m.sess_id and x.expimp_file=f.file_id(+);

---------------------------------------------------------------------------------------------
-- Miscelaneous
---------------------------------------------------------------------------------------------
CREATE OR REPLACE TYPE tableofnumbers as table of number(20)
/
CREATE OR REPLACE TYPE tableofstrings as table of varchar2(4000)
/

--Clob2row representation
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
    table(COREMOD_FILE_UTILS.clob2tab(opas_files.file_id)) p1
;
---------------------------------------------------------------------------------------------
-- Core Objects
---------------------------------------------------------------------------------------------
-- Attachments
create table opas_ot_attachments (
attach_id           number                                           primary key,
modname             varchar2(128)                          not null  references opas_modules(modname) on delete cascade,
attach_content      number                                           references opas_files ( file_id ));

alter table opas_ot_attachments add constraint fk_attach_obj foreign key (attach_id) references opas_objects(obj_id);

create index idx_opas_attach_mod   on opas_ot_attachments(modname);
create index idx_opas_attach_cntn  on opas_ot_attachments(attach_content);

---------------------------------------------------------------------------------------------
-- DB Links assignments
create table opas_ot_dblinks2obj (
trg_obj_id          number                                 not null  references opas_objects(obj_id) on delete cascade,
dblink              varchar2(128)                          not null  references opas_db_links (DB_LINK_NAME) on delete cascade,
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
-- Memo
create table opas_ot_memo (
memo_id           number                                             primary key,
memo_content      number                                             references opas_files ( file_id ));

alter table opas_ot_memo add constraint fk_attach_obj foreign key (memo_id) references opas_objects(obj_id);

create index idx_opas_memo_cntn  on opas_ot_memo(memo_content);

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- SQLs
create table opas_ot_sql_descriptions (
sql_id              varchar2(13)                           not null  primary key,
sql_text            number                                           references opas_files ( file_id ),
sql_text_approx     number                                           references opas_files ( file_id ),
created_by          varchar2(128)    default 'PUBLIC',
first_discovered    timestamp        default systimestamp,
first_discovered_at varchar2(128)                          not null  references opas_db_links (DB_LINK_NAME)
);

create index        idx_opas_ot_sql_descr_file  on opas_ot_sql_descriptions(sql_text);
create index        idx_opas_ot_sql_descr_a_file  on opas_ot_sql_descriptions(sql_text_approx);

create sequence opas_ot_sq_dp;

create table opas_ot_sql_data (
sql_data_point_id   number                                           primary key,
sql_id              varchar2(13)                           not null  references opas_ot_sql_descriptions ( sql_id ) on delete cascade,
start_gathering_dt  timestamp,
end_gathering_dt    timestamp,
dblink              varchar2(128)                          not null  references opas_db_links (DB_LINK_NAME),
gathering_status    varchar2(32)     default 'NOT_STARTED' not null,
tq_id               number,
tq_id2              number
);

create index idx_opas_sql_data_sqlid on opas_ot_sql_data(sql_id);
create index idx_opas_sql_data_dbl   on opas_ot_sql_data(dblink);

create table opas_ot_sql_data_sect (
sql_data_point_id   number                                 not null  references opas_ot_sql_data(sql_data_point_id) on delete cascade,
section_name        varchar2(30)                           not null,
start_gathering_dt  timestamp,
end_gathering_dt    timestamp,
gathering_status    varchar2(32)     default 'NOT_STARTED' not null,
error_message       varchar2(4000)
);

create index idx_opas_sql_data_sect_sid on opas_ot_sql_data_sect(sql_data_point_id);

create table opas_ot_sql_data_point_ref (
 sql_data_point_id                                  number                                 not null  references opas_ot_sql_data(sql_data_point_id) on delete cascade,
 obj_id                                             number                                 not null  references opas_objects(obj_id) on delete cascade
);

create index idx_opas_sql_dp_ref_dp  on opas_ot_sql_data_point_ref(sql_data_point_id);
create index idx_opas_sql_dp_rep_mon on opas_ot_sql_data_point_ref(obj_id);

----
create table opas_ot_sql_nonshared (
sql_data_point_id   number,
sql_id              varchar2(13), 
inst_id             number, 
nonshared_reason    varchar2(100), 
cnt                 number);

alter table opas_ot_sql_nonshared add constraint fk_sql_ns_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_nonshared add constraint fk_sql_ns_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_ns_dp    on opas_ot_sql_nonshared(sql_data_point_id);
create index idx_opas_sql_ns_sqlid on opas_ot_sql_nonshared(sql_id);

----
create table opas_ot_sql_vsql as
select 0 sql_data_point_id, 
SQL_ID, CHILD_NUMBER, PLAN_HASH_VALUE, OPTIMIZER_ENV_HASH_VALUE, INST_ID, FORCE_MATCHING_SIGNATURE,
OLD_HASH_VALUE, PROGRAM_ID, PROGRAM_LINE#, PARSING_SCHEMA_NAME, MODULE, ACTION, FIRST_LOAD_TIME,
LAST_LOAD_TIME, LAST_ACTIVE_TIME, IS_OBSOLETE, IS_BIND_SENSITIVE, IS_BIND_AWARE,
IS_SHAREABLE, SQL_PROFILE, SQL_PATCH, SQL_PLAN_BASELINE, PX_SERVERS_EXECUTIONS, PHYSICAL_READ_REQUESTS,
PHYSICAL_READ_BYTES, PHYSICAL_WRITE_REQUESTS, PHYSICAL_WRITE_BYTES, PARSE_CALLS, EXECUTIONS,
FETCHES, ROWS_PROCESSED, END_OF_FETCH_COUNT, CPU_TIME, ELAPSED_TIME, DISK_READS, BUFFER_GETS,
DIRECT_WRITES, APPLICATION_WAIT_TIME, CONCURRENCY_WAIT_TIME, CLUSTER_WAIT_TIME, USER_IO_WAIT_TIME,
PLSQL_EXEC_TIME, JAVA_EXEC_TIME, IO_CELL_OFFLOAD_ELIGIBLE_BYTES, IO_INTERCONNECT_BYTES, 
OPTIMIZED_PHY_READ_REQUESTS, IO_CELL_UNCOMPRESSED_BYTES, IO_CELL_OFFLOAD_RETURNED_BYTES
from gv$sql s where 1=2;

alter table opas_ot_sql_vsql add constraint fk_sql_vsql_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_vsql add constraint fk_sql_vsql_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_vsql_dp    on opas_ot_sql_vsql(sql_data_point_id);
create index idx_opas_sql_vsql_sqlid on opas_ot_sql_vsql(sql_id);

create table opas_ot_sql_vsql_objs as
select 0 sql_data_point_id, 0 CHILD_NUMBER,
object_id, owner, object_type, object_name
from dba_objects s where 1=2;

alter table opas_ot_sql_vsql_objs add constraint fk_sql_vsql_objs_dp foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
create index idx_opas_sql_vsql_objs_dp on opas_ot_sql_vsql_objs(sql_data_point_id);

----------------------------------------------------------------------------------------------------------------
create sequence opas_ot_sq_plan_id;

create table opas_ot_sql_plans as 
select
 0 plan_id, 
 'qazwsxedcrqazwsxedcr' plan_type,
 systimestamp created,
 x.sql_id
from gv$sql_plan_statistics_all x where 1=2;

alter table opas_ot_sql_plans add constraint pk_sql_plan_id primary key(plan_id);
alter table opas_ot_sql_plans add constraint fk_sql_plans_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;
create index idx_opas_sql_plans_sqlid on opas_ot_sql_plans(sql_id);

create table opas_ot_sql_plan_det as 
select
 0 plan_id, 
 x.*
from gv$sql_plan_statistics_all x where 1=2;

alter table opas_ot_sql_plan_det add constraint fk_sql_pland_id foreign key (plan_id) references opas_ot_sql_plans(plan_id) on delete cascade;
alter table opas_ot_sql_plan_det add constraint fk_sql_pland_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;
create index idx_opas_sql_pland_id on opas_ot_sql_plan_det(plan_id);
create index idx_opas_sql_pland_sqlid on opas_ot_sql_plan_det(sql_id);

create table opas_ot_sql_plan_ref (
 sql_data_point_id                                number                                 not null  references opas_ot_sql_data(sql_data_point_id) on delete cascade,
 plan_id                                          number                                 not null  references opas_ot_sql_plans(plan_id) on delete cascade
);

create index idx_opas_sql_plan_ref_dp  on opas_ot_sql_plan_ref(sql_data_point_id);
create index idx_opas_sql_plan_rep_mon on opas_ot_sql_plan_ref(plan_id);

create global temporary table opas_ot_tmp_gv$sql_plan_stat_all on commit delete rows
as select * from gv$sql_plan_statistics_all where 1=2;

create global temporary table opas_ot_tmp_gv$sql_plan_key on commit delete rows
as select 0 plan_id, inst_id, child_number, plan_hash_value, full_plan_hash_value from gv$sql_plan_statistics_all where 1=2;

----
create sequence opas_ot_sq_sqlmon_id;

create table opas_ot_sql_sqlmon (
 sqlmon_id                                          number                                           primary key,
 SQL_ID                                             VARCHAR2(13)                           not null  references opas_ot_sql_descriptions(sql_id) on delete cascade,
 sql_mon_report                                     number                                           references opas_files ( file_id ),
 sql_mon_hst_report                                 number                                           references opas_files ( file_id ),
 plan_id                                            number                                           references opas_ot_sql_plans ( plan_id ),
 dblink                                             varchar2(128)                          not null  references opas_db_links(db_link_name), 
 source                                             varchar2(100), -- V$/HST
 REPORT_ID                                          NUMBER,
 STATUS                                             VARCHAR2(19),
 FIRST_REFRESH_TIME                                 DATE,
 LAST_REFRESH_TIME                                  DATE,
 REFRESH_COUNT                                      NUMBER,
 SQL_EXEC_START                                     DATE,
 SQL_EXEC_ID                                        NUMBER,
 SID                                                NUMBER,
 SESSION_SERIAL#                                    NUMBER,
 CON_ID                                             NUMBER,
 CON_NAME                                           VARCHAR2(128),
 ECID                                               VARCHAR2(64),
 ---
 SNAP_ID                                            NUMBER,
 DBID                                               NUMBER,
 INSTANCE_NUMBER                                    NUMBER,
 CON_DBID                                           NUMBER);
 
create index idx_opas_sql_mon_rep_text  on opas_ot_sql_sqlmon(sql_mon_report);
create index idx_opas_sql_mon_rep_xml  on opas_ot_sql_sqlmon(sql_mon_hst_report);
create index idx_opas_sql_mon_rep_sqlid on opas_ot_sql_sqlmon(sql_id);

create table opas_ot_sql_sqlmon_ref (
 sql_data_point_id                                  number                                 not null  references opas_ot_sql_data(sql_data_point_id) on delete cascade,
 sqlmon_id                                          number                                 not null  references opas_ot_sql_sqlmon(sqlmon_id) on delete cascade
);

create index idx_opas_sql_mon_ref_dp  on opas_ot_sql_sqlmon_ref(sql_data_point_id);
create index idx_opas_sql_mon_rep_mon on opas_ot_sql_sqlmon_ref(sqlmon_id);

create table opas_ot_sql_sqlmon_data (
 sqlmon_id                                          number                                 not null  references opas_ot_sql_sqlmon(sqlmon_id) on delete cascade,
 USER#                                              NUMBER,
 USERNAME                                           VARCHAR2(128),
 MODULE                                             VARCHAR2(64),
 ACTION                                             VARCHAR2(64),
 SERVICE_NAME                                       VARCHAR2(64),
 CLIENT_IDENTIFIER                                  VARCHAR2(64),
 CLIENT_INFO                                        VARCHAR2(64),
 PROGRAM                                            VARCHAR2(48),
 PLSQL_ENTRY_OBJECT_ID                              NUMBER,
 PLSQL_ENTRY_SUBPROGRAM_ID                          NUMBER,
 PLSQL_OBJECT_ID                                    NUMBER,
 PLSQL_SUBPROGRAM_ID                                NUMBER,
 DBOP_EXEC_ID                                       NUMBER,
 DBOP_NAME                                          VARCHAR2(30),
 PROCESS_NAME                                       VARCHAR2(5),
 SQL_TEXT                                           VARCHAR2(2000),
 IS_FULL_SQLTEXT                                    VARCHAR2(1),
 SQL_PLAN_HASH_VALUE                                NUMBER,
 SQL_FULL_PLAN_HASH_VALUE                           NUMBER,
 EXACT_MATCHING_SIGNATURE                           NUMBER,
 FORCE_MATCHING_SIGNATURE                           NUMBER,
 PX_IS_CROSS_INSTANCE                               VARCHAR2(1),
 PX_MAXDOP                                          NUMBER,
 PX_MAXDOP_INSTANCES                                NUMBER,
 PX_SERVERS_REQUESTED                               NUMBER,
 PX_SERVERS_ALLOCATED                               NUMBER,
 PX_SERVER#                                         NUMBER,
 PX_SERVER_GROUP                                    NUMBER,
 PX_SERVER_SET                                      NUMBER,
 PX_QCINST_ID                                       NUMBER,
 PX_QCSID                                           NUMBER,
 ERROR_NUMBER                                       VARCHAR2(40),
 ERROR_FACILITY                                     VARCHAR2(4),
 ERROR_MESSAGE                                      VARCHAR2(256),
 ELAPSED_TIME                                       NUMBER,
 QUEUING_TIME                                       NUMBER,
 CPU_TIME                                           NUMBER,
 FETCHES                                            NUMBER,
 BUFFER_GETS                                        NUMBER,
 DISK_READS                                         NUMBER,
 DIRECT_WRITES                                      NUMBER,
 IO_INTERCONNECT_BYTES                              NUMBER,
 PHYSICAL_READ_REQUESTS                             NUMBER,
 PHYSICAL_READ_BYTES                                NUMBER,
 PHYSICAL_WRITE_REQUESTS                            NUMBER,
 PHYSICAL_WRITE_BYTES                               NUMBER,
 APPLICATION_WAIT_TIME                              NUMBER,
 CONCURRENCY_WAIT_TIME                              NUMBER,
 CLUSTER_WAIT_TIME                                  NUMBER,
 USER_IO_WAIT_TIME                                  NUMBER,
 PLSQL_EXEC_TIME                                    NUMBER,
 JAVA_EXEC_TIME                                     NUMBER,
 RM_LAST_ACTION                                     VARCHAR2(48),
 RM_LAST_ACTION_REASON                              VARCHAR2(128),
 RM_LAST_ACTION_TIME                                DATE,
 RM_CONSUMER_GROUP                                  VARCHAR2(128),
 IS_ADAPTIVE_PLAN                                   VARCHAR2(1),
 IS_FINAL_PLAN                                      VARCHAR2(1),
 IN_DBOP_NAME                                       VARCHAR2(30),
 IN_DBOP_EXEC_ID                                    NUMBER,
 IO_CELL_UNCOMPRESSED_BYTES                         NUMBER,
 IO_CELL_OFFLOAD_ELIGIBLE_BYTES                     NUMBER,
 IO_CELL_OFFLOAD_RETURNED_BYTES                     NUMBER);

create index idx_opas_sql_mon_rep_d_mon on opas_ot_sql_sqlmon_data(sqlmon_id);

create global temporary table opas_ot_tmp_gv$sql_monitor on commit delete rows
as select * from gv$sql_monitor where 1=2;

create global temporary table opas_ot_tmp_dba_hist_reports on commit delete rows
as
  select 
    r.SNAP_ID                      , 
    r.DBID                         , 
    r.INSTANCE_NUMBER              , 
    r.REPORT_ID                    , 
    r.COMPONENT_ID                 , 
    r.SESSION_ID                   , 
    r.SESSION_SERIAL#              , 
    r.PERIOD_START_TIME            , 
    r.PERIOD_END_TIME              , 
    r.GENERATION_TIME              , 
    r.COMPONENT_NAME               , 
    r.REPORT_NAME                  , 
    r.REPORT_PARAMETERS            , 
    r.KEY1                         , 
    r.KEY2                         , 
    r.KEY3                         , 
    r.KEY4                         , 
    r.GENERATION_COST_SECONDS      , 
    r.REPORT_SUMMARY               , 
    r.CON_DBID                     , 
    r.CON_ID
    from dba_hist_reports r
   WHERE 1=2;
create global temporary table opas_ot_tmp_dba_hist_rep_xml on commit delete rows
as
  select 
    d.REPORT_ID                    , 
    d.REPORT
    from dba_hist_reports_details d
   WHERE 1=2;	 
----

create table opas_ot_sql_wa
as
select 0 sql_data_point_id, 
       sql_id, 
       inst_id,
       child_number,
       policy,
       operation_id,
       operation_type,
       estimated_optimal_size,
       estimated_onepass_size,
       last_memory_used,
       last_execution,
       last_degree,
       total_executions,
       optimal_executions,
       onepass_executions,
       multipasses_executions,
       active_time,
       max_tempseg_size,
       last_tempseg_size
  from gv$sql_workarea
 where 1=2;

alter table opas_ot_sql_wa add constraint fk_sql_wa_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_wa add constraint fk_sql_wa_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_wa_dp    on opas_ot_sql_wa(sql_data_point_id);
create index idx_opas_sql_wa_sqlid on opas_ot_sql_wa(sql_id);
----

create table opas_ot_sql_opt_env
as
select 0 sql_data_point_id, sql_id, 
       inst_id,child_number,name,isdefault,value
  from gv$sql_optimizer_env
 where 1=2;

alter table opas_ot_sql_opt_env add constraint fk_sql_oe_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_opt_env add constraint fk_sql_oe_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_oe_dp    on opas_ot_sql_opt_env(sql_data_point_id);
create index idx_opas_sql_oe_sqlid on opas_ot_sql_opt_env(sql_id);
---

CREATE TABLE OPAS_OT_SQL_VASH1 (
sql_data_point_id   number,
sql_id              varchar2(13), 
SQL_EXEC_START      date, 
SQL_EXEC_END        date, 
PLAN_HASH_VALUE     NUMBER, 
ID                  NUMBER, 
ROW_SRC             VARCHAR2(64), 
EVENT               VARCHAR2(64), 
CNT                 NUMBER, 
TIM_PCT             NUMBER, 
TIM_ID_PCT          NUMBER, 
OBJ                 VARCHAR2(256), 
TBS                 VARCHAR2(30)
);
   
alter table OPAS_OT_SQL_VASH1 add constraint fk_sql_vash1_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table OPAS_OT_SQL_VASH1 add constraint fk_sql_vash1_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_vash1_dp    on OPAS_OT_SQL_VASH1(sql_data_point_id);
create index idx_opas_sql_vash1_sqlid on OPAS_OT_SQL_VASH1(sql_id);

CREATE TABLE OPAS_OT_SQL_VASH2 (
sql_data_point_id   number,
sql_id              varchar2(13), 
PLAN_HASH_VALUE     NUMBER, 
ID                  NUMBER, 
ROW_SRC             VARCHAR2(64), 
EVENT               VARCHAR2(64), 
CNT                 NUMBER, 
TIM_PCT             NUMBER, 
TIM_ID_PCT          NUMBER, 
OBJ                 VARCHAR2(256), 
TBS                 VARCHAR2(30)
);

alter table OPAS_OT_SQL_VASH2 add constraint fk_sql_vash2_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table OPAS_OT_SQL_VASH2 add constraint fk_sql_vash2_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_vash2_dp    on OPAS_OT_SQL_VASH2(sql_data_point_id);
create index idx_opas_sql_vash2_sqlid on OPAS_OT_SQL_VASH2(sql_id);

create global temporary table opas_ot_tmp_gv$ash on commit delete rows
as select * from gv$active_session_history where 1=2;

create global temporary table opas_ot_tmp_gv$ash_objs (
object_id number,
object_name varchar2(256),
object_type varchar2(256))
on commit delete rows;
 
---
create global temporary table opas_ot_tmp_awrsnaps on commit delete rows
as select * from dba_hist_snapshot where 1=2;

create global temporary table opas_ot_tmp_awrsqlstat on commit delete rows
as select * from dba_hist_sqlstat where 1=2;

create global temporary table opas_ot_tmp_awrsqlbind on commit delete rows
as select * from dba_hist_sqlbind where 1=2;

create global temporary table opas_ot_tmp_awrinst on commit delete rows
as select * from dba_hist_database_instance where 1=2;

create global temporary table opas_ot_tmp_awrpln on commit delete rows
as select * from dba_hist_sql_plan where 1=2;

create global temporary table opas_ot_tmp_awrash on commit delete rows
as select * from dba_hist_active_sess_history where 1=2;


create table opas_ot_sql_awrstat
create table opas_ot_sql_awrbinds

create table opas_ot_sql_awrplans
create table opas_ot_sql_recursive
create table opas_ot_sql_awrash#
create table opas_ot_sql_awrash#
create table opas_ot_sql_awrash#
create table opas_ot_sql_awrash#

---------------------------------------------------------------------------------------------
-- SQL Lists
create table opas_ot_sql_lists (
sqllst_id           number                                           primary key,
list_name           varchar2(100)                          not null,
description         varchar2(4000)
);

alter table opas_ot_sql_lists add constraint fk_sql_lists_obj foreign key (sqllst_id) references opas_objects(obj_id) on delete cascade;

create table opas_ot_lists2sqls (
sqllst_id           number                                 not null  references opas_sql_lists(sqllst_id) on delete cascade,
sql_id              varchar2(128)                          not null  references opas_query_storage(sql_id)
);

create unique index idx_opas_lists2sqls_sql_l on opas_ot_lists2sqls(sqllst_id, sql_id);
create index idx_opas_lists2sqls_sql   on opas_ot_lists2sqls(sql_id);

---------------------------------------------------------------------------------------------
-- Reports
create table opas_ot_reports (
report_id           number                                           primary key,
parent_id           number                                           references opas_reports(report_id) on delete set null,
modname             varchar2(128)                          not null  references opas_modules(modname) on delete cascade,
tq_id               number                                           references opas_task_queue(tq_id) on delete set null,
report_content      number                                           references opas_files ( file_id ),
report_params_displ varchar2(1000),
report_type         varchar2(100)                          not null);

alter table opas_ot_reports add constraint fk_reports_obj foreign key (report_id) references opas_objects(obj_id);

create index idx_opas_reports_mod   on opas_ot_reports(modname);
create index idx_opas_reports_fcntn on opas_ot_reports(report_content);

create table opas_ot_reports_pars (
report_id           number                                 not null  references opas_reports(report_id) on delete cascade,
par_name            varchar2(100)                          not null,
num_par             number,
varchar_par         varchar2(4000),
date_par            date
);

create index idx_opas_reports_parstske on opas_reports_pars(report_id);

