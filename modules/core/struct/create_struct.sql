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
-- known query storage
---------------------------------------------------------------------------------------------
--create table opas_query_storage (
--sql_id              varchar2(128)                                    primary key,
--sql_text            clob,
--created             timestamp        default systimestamp,
--owner               varchar2(128)    default 'public')
--lob (sql_text) store as (compress high)
--;

-- text index tbd

---------------------------------------------------------------------------------------------
-- database link dictionary
---------------------------------------------------------------------------------------------
create table opas_db_links (
db_link_name        varchar2(128)                                    primary key,
owner               varchar2(128)    default 'public',
username            varchar2(128),
password            varchar2(128),
connstr             varchar2(1000),
status              varchar2(32)     default 'new'         not null,
is_public           varchar2(1)      default 'y'           not null,
dbid                number
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
       owner,
       status,
       is_public,
       dbid
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
create table opas_db_link_v$db
as
select cast('' as varchar2(128)) dblink,
       'Y' is_actual,
       systimestamp actual_since,
       x.*
  from v$database x
 where 1=2;

create index idx_opas_dbl_db_dblink on opas_db_link_v$db(dblink,is_actual);
alter table opas_db_link_v$db add constraint fk_v$db_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

create global temporary table opas_dbl_tmp_v$database on commit delete rows
as select * from v$database where 1=2;
----
create table opas_db_link_v$pdbs
as
select cast('' as varchar2(128)) dblink,
       'Y' is_actual,
       systimestamp actual_since,
       x.*
  from v$pdbs x
 where 1=2;

create index idx_opas_dbl_pdbs_dblink on opas_db_link_v$pdbs(dblink,is_actual);
alter table opas_db_link_v$pdbs add constraint fk_v$pdbs_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

create global temporary table opas_dbl_tmp_v$pdbs on commit delete rows
as select * from v$pdbs where 1=2;
----
create table opas_db_link_v$inst
as 
select cast('' as varchar2(128)) dblink,
       x.*
  from gv$instance x
 where 1=2;

create index idx_opas_dbl_vinst_dblink on opas_db_link_v$inst(dblink);
alter table opas_db_link_v$inst add constraint fk_v$inst_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

create global temporary table opas_dbl_tmp_v$inst on commit delete rows
as select * from gv$instance where 1=2;
----
create table opas_db_link_dbh_inst
as
select cast('' as varchar2(128)) dblink,
       x.*
  from dba_hist_database_instance x
 where 1=2;

create index idx_opas_dbl_inst_dblink on opas_db_link_dbh_inst(dblink);
alter table opas_db_link_dbh_inst add constraint fk_dbh_inst_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

create global temporary table opas_dbl_tmp_awrinst on commit delete rows
as select * from DBA_HIST_DATABASE_INSTANCE where 1=2;
----
create table opas_db_link_reghst
as
select cast('' as varchar2(128)) dblink,
       x.*
  from dba_registry_history x
 where 1=2;

create index idx_opas_db_link_reg_dblink on opas_db_link_reghst(dblink);
alter table opas_db_link_reghst add constraint fk_dbl_reghst_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

create global temporary table opas_dbl_tmp_reghst on commit delete rows
as select * from DBA_REGISTRY_HISTORY where 1=2;
----
create table opas_db_link_sqlptchhst
as
select cast('' as varchar2(128)) dblink,
       x.*
  from DBA_REGISTRY_SQLPATCH x
 where 1=2;

alter table opas_db_link_sqlptchhst modify
  (PATCH_TYPE null,
  STATUS null,
  ACTION_TIME null,
  LOGFILE null);

create index idx_opas_db_link_ptch_dblink on opas_db_link_sqlptchhst(dblink);
alter table opas_db_link_sqlptchhst add constraint fk_dbl_ptch_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

create global temporary table opas_dbl_tmp_sqlptchhst on commit delete rows
as select * from DBA_REGISTRY_SQLPATCH where 1=2;

alter table opas_dbl_tmp_sqlptchhst modify
  (PATCH_TYPE null,
  STATUS null,
  ACTION_TIME null,
  LOGFILE null);

----
create table opas_db_link_awrsnaps
as
select cast('' as varchar2(128)) dblink,
       x.*
  from dba_hist_snapshot x
 where 1=2;

create index idx_opas_db_link_awrsn_dblink on opas_db_link_awrsnaps(dblink);
alter table opas_db_link_awrsnaps add constraint fk_dbl_awrsn_dblink foreign key (dblink) references opas_db_links(db_link_name) on delete cascade;

create global temporary table opas_dbl_tmp_awrsnaps on commit preserve rows
as select * from dba_hist_snapshot where 1=2;

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
owner               varchar2(128)    default 'public'      not null,
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
  ot_icon           varchar2(100)    default 'def_icon'    not null,
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
  is_public         varchar2(1)      default 'y'           not null,
  is_readonly       varchar2(1)      default 'n'           not null
);

create index idx_opas_objects_ot on opas_objects(obj_ot);
create index idx_opas_objects_prnt on opas_objects(obj_prnt);

create table opas_object_references (
  obj_id_src        number                                 not null  references opas_objects(obj_id) on delete cascade,
  obj_id_trg        number                                 not null  references opas_objects(obj_id) on delete cascade,
  obj_ref_type      varchar2(100)    default 'default'     not null  -- default, sqloldnew, sqltoprec
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
where case when o.is_public = 'y' or o.obj_owner = 'public' then 1 else case  when o.obj_owner = v('app_user') then 1 else 0 end end = 1
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
  is_public           varchar2(1)    default 'y'           not null,
  created             timestamp      default systimestamp,
  task_body           clob,
  task_priority       varchar2(10)   default 'norm'      not null -- 'high', 'low'
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
  status              varchar2(32)   default 'new',
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
from opas_task t left outer join opas_task_queue q on (t.taskname = q.taskname and q.owner=decode(t.is_public,'y',q.owner,nvl(v('app_user'),'~^')))
where 1=decode(t.is_public,'y',1, coremod_sec.is_role_assigned_n(t.modname,'reas-write users'))
;

create or replace force view v$opas_task_queue_longops as
select tq.*,
       case 
         when message is null then 'n/a' 
         else opname || ':' || message || '; elapsed: ' || elapsed_seconds || '; remaining: ' || nvl(to_char(time_remaining), 'n/a') end msg,
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
owner               varchar2(128)    default 'public'      not null,
sess_type           varchar2(3)      check (sess_type in ('imp','exp')),
status              varchar2(32)     default 'new'         not null
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
    decode(x.sess_type,'exp','export','imp','import','unknown: '||x.sess_type) sess_type,
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
default_dblink      varchar2(1)      default 'n'           not null,
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

alter table opas_ot_memo add constraint fk_attach_obj foreign key (memo_id) references opas_objects(obj_id);

create index idx_opas_memo_cntn  on opas_ot_memo(memo_content);

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- sqls
create table opas_ot_sql_descriptions (
sql_id              varchar2(13)                           not null  primary key,
sql_text            number                                           references opas_files ( file_id ),
sql_text_approx     number                                           references opas_files ( file_id ),
created_by          varchar2(128)    default 'public',
first_discovered    timestamp,
first_discovered_at varchar2(128)                                    references opas_db_links (db_link_name)
);

create index        idx_opas_ot_sql_descr_file  on opas_ot_sql_descriptions(sql_text);
create index        idx_opas_ot_sql_descr_a_file  on opas_ot_sql_descriptions(sql_text_approx);

create sequence opas_ot_sq_dp;

create table opas_ot_sql_data (
sql_data_point_id   number                                           primary key,
sql_id              varchar2(13)                           not null  references opas_ot_sql_descriptions ( sql_id ) on delete cascade,
start_gathering_dt  timestamp,
end_gathering_dt    timestamp,
dblink              varchar2(128)                          not null  references opas_db_links (db_link_name),
gathering_status    varchar2(32)     default 'not_started' not null,
tq_id               number,
tq_id2              number,
awr_snap_start      number,
awr_snap_end        number
);

create index idx_opas_sql_data_sqlid on opas_ot_sql_data(sql_id);
create index idx_opas_sql_data_dbl   on opas_ot_sql_data(dblink);

create table opas_ot_sql_data_sect (
sql_data_point_id   number                                 not null  references opas_ot_sql_data(sql_data_point_id) on delete cascade,
section_name        varchar2(30)                           not null,
start_gathering_dt  timestamp,
end_gathering_dt    timestamp,
gathering_status    varchar2(32)     default 'not_started' not null,
error_message       varchar2(4000)
);

create index idx_opas_sql_data_sect_sid on opas_ot_sql_data_sect(sql_data_point_id);

create table opas_ot_sql_data_point_ref (
 sql_data_point_id                                  number                                 not null  references opas_ot_sql_data(sql_data_point_id) on delete cascade,
 obj_id                                             number                                 not null  references opas_objects(obj_id) on delete cascade
);

create index idx_opas_sql_dp_ref_dp  on opas_ot_sql_data_point_ref(sql_data_point_id);
create unique index idx_opas_sql_dp_rep_mon on opas_ot_sql_data_point_ref(obj_id);

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
sql_id, child_number, plan_hash_value, optimizer_env_hash_value, inst_id, force_matching_signature,
old_hash_value, program_id, program_line#, parsing_schema_name, module, action, first_load_time,
last_load_time, last_active_time, is_obsolete, is_bind_sensitive, is_bind_aware,
is_shareable, sql_profile, sql_patch, sql_plan_baseline, px_servers_executions, physical_read_requests,
physical_read_bytes, physical_write_requests, physical_write_bytes, parse_calls, executions,
fetches, rows_processed, end_of_fetch_count, cpu_time, elapsed_time, disk_reads, buffer_gets,
direct_writes, application_wait_time, concurrency_wait_time, cluster_wait_time, user_io_wait_time,
plsql_exec_time, java_exec_time, io_cell_offload_eligible_bytes, io_interconnect_bytes, 
optimized_phy_read_requests, io_cell_uncompressed_bytes, io_cell_offload_returned_bytes
from gv$sql s where 1=2;

alter table opas_ot_sql_vsql add constraint fk_sql_vsql_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_vsql add constraint fk_sql_vsql_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_vsql_dp    on opas_ot_sql_vsql(sql_data_point_id);
create index idx_opas_sql_vsql_sqlid on opas_ot_sql_vsql(sql_id);

create table opas_ot_sql_vsql_objs as
select 0 sql_data_point_id, 0 child_number,
object_id, owner, object_type, object_name
from dba_objects s where 1=2;

alter table opas_ot_sql_vsql_objs add constraint fk_sql_vsql_objs_dp foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
create index idx_opas_sql_vsql_objs_dp on opas_ot_sql_vsql_objs(sql_data_point_id);

----------------------------------------------------------------------------------------------------------------
create sequence opas_ot_sq_plan_id;

create table opas_ot_sql_plans as 
select
 0 plan_id, 
 cast('qazwsxedcrqazwsxedcr' as varchar2(20)) plan_source,
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
as select 0 report_id, x.* from gv$sql_plan_statistics_all x where 1=2;

create global temporary table opas_ot_tmp_gv$sql_plan_key on commit delete rows
as select 0 plan_id, 0 report_id, inst_id, child_number, plan_hash_value, full_plan_hash_value from gv$sql_plan_statistics_all where 1=2;

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

create index idx_opas_sql_mon_rep_d_mon on opas_ot_sql_sqlmon_data(sqlmon_id);

create global temporary table opas_ot_tmp_gv$sql_monitor on commit delete rows
as select * from gv$sql_monitor where 1=2;

create global temporary table opas_ot_tmp_dba_hist_reports on commit delete rows
as
  select 
    r.snap_id                      , 
    r.dbid                         , 
    r.instance_number              , 
    r.report_id                    , 
    r.component_id                 , 
    r.session_id                   , 
    r.session_serial#              , 
    r.period_start_time            , 
    r.period_end_time              , 
    r.generation_time              , 
    r.component_name               , 
    r.report_name                  , 
    r.report_parameters            , 
    r.key1                         , 
    r.key2                         , 
    r.key3                         , 
    r.key4                         , 
    r.generation_cost_seconds      , 
    r.report_summary               , 
    r.con_dbid                     , 
    r.con_id
    from dba_hist_reports r
   where 1=2;
create global temporary table opas_ot_tmp_dba_hist_rep_xml on commit delete rows
as
  select 
    d.report_id                    , 
    d.report
    from dba_hist_reports_details d
   where 1=2;    
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
   
alter table opas_ot_sql_vash1 add constraint fk_sql_vash1_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_vash1 add constraint fk_sql_vash1_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_vash1_dp    on opas_ot_sql_vash1(sql_data_point_id);
create index idx_opas_sql_vash1_sqlid on opas_ot_sql_vash1(sql_id);

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

alter table opas_ot_sql_vash2 add constraint fk_sql_vash2_dp    foreign key (sql_data_point_id) references opas_ot_sql_data(sql_data_point_id) on delete cascade;
alter table opas_ot_sql_vash2 add constraint fk_sql_vash2_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_vash2_dp    on opas_ot_sql_vash2(sql_data_point_id);
create index idx_opas_sql_vash2_sqlid on opas_ot_sql_vash2(sql_id);

create global temporary table opas_ot_tmp_gv$ash on commit delete rows
as select * from gv$active_session_history where 1=2;

create global temporary table opas_ot_tmp_gv$ash_objs (
object_id number,
object_name varchar2(256),
object_type varchar2(256))
on commit delete rows;
 
---
create table opas_ot_sql_awr_sqlstat
as
select x.*
  from dba_hist_sqlstat x
 where 1=2;

alter table opas_ot_sql_awr_sqlstat add dblink  varchar2(128)  not null  references opas_db_links (db_link_name);
create index idx_opas_sql_awr_sqlstat_dbl   on opas_ot_sql_awr_sqlstat(dblink);

alter table opas_ot_sql_awr_sqlstat add constraint fk_sql_awrsqlst_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create unique index idx_opas_sql_awrsqlst_sqlid on opas_ot_sql_awr_sqlstat(sql_id,dblink, dbid,snap_id,instance_number,plan_hash_value,con_dbid);

create global temporary table opas_ot_tmp_awrsqlstat on commit delete rows
as select * from dba_hist_sqlstat where 1=2;
--
create table opas_ot_sql_awr_sqlbind
as
select x.*
  from dba_hist_sqlbind x
 where 1=2;

alter table opas_ot_sql_awr_sqlbind add dblink  varchar2(128)  not null  references opas_db_links (db_link_name);
create index idx_opas_sql_awr_sqlbind_dbl   on opas_ot_sql_awr_sqlbind(dblink);

alter table opas_ot_sql_awr_sqlbind add constraint fk_sql_awrsqlbi_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_awrsqlbi_sqlid on opas_ot_sql_awr_sqlbind(sql_id,dblink, dbid,snap_id);

create global temporary table opas_ot_tmp_awrsqlbind on commit delete rows
as select * from dba_hist_sqlbind where 1=2;
--

create sequence opas_ot_sq_awrplan_id;

create table opas_ot_sql_awr_plans as 
select
 0 plan_id, 
 systimestamp created,
 x.sql_id,
 x.dbid,
 x.plan_hash_value
from dba_hist_sql_plan x where 1=2;

alter table opas_ot_sql_awr_plans add constraint pk_sql_awrplan_id primary key(plan_id);
alter table opas_ot_sql_awr_plans add constraint fk_sql_awrplans_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;
create index idx_opas_sql_awrplans_sqlid on opas_ot_sql_awr_plans(sql_id);

create table opas_ot_sql_awr_plan_det as 
select
 0 plan_id, 
 x.*
from dba_hist_sql_plan x where 1=2;

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

create global temporary table opas_ot_tmp_dbh_plan on commit delete rows
as select x.* from dba_hist_sql_plan x where 1=2;

create global temporary table opas_ot_tmp_dbh_plan_key on commit delete rows
as select 0 plan_id, plan_hash_value from dba_hist_sql_plan where 1=2;

--
create global temporary table opas_ot_tmp_dbh_ash on commit delete rows
as
select count(1) cnt,
       dbid,
       snap_id,
       instance_number,
       min(sample_time) min_sample_time,
       max(sample_time) max_sample_time,
       sql_id,
       TOP_LEVEL_SQL_ID,
       user_id,
       program,
       machine,
       max(module) module,
       max(action) action,
       max(client_id) client_id,
       max(ecid) ecid,
       plsql_entry_object_id,
       plsql_entry_subprogram_id,
       PLSQL_OBJECT_ID,
       PLSQL_SUBPROGRAM_ID,
       wait_class,
       event,
       session_state,
       min(SQL_EXEC_START) min_SQL_EXEC_START,
       max(SQL_EXEC_START) max_SQL_EXEC_START,
       force_matching_signature,
       sql_child_number,
       sql_plan_hash_value,
       sql_full_plan_hash_value,
       sql_plan_line_id,
       sql_plan_operation,
       sql_plan_options,
       session_type,
       max(pga_allocated) pga_allocated,
       max(temp_space_allocated) temp_space_allocated
  from dba_hist_active_sess_history
where 1=2
group by 
dbid, snap_id, instance_number, sql_id, TOP_LEVEL_SQL_ID, user_id, program, machine,
plsql_entry_object_id, plsql_entry_subprogram_id, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID, wait_class,
event, session_state, force_matching_signature, sql_child_number, sql_plan_hash_value, sql_full_plan_hash_value,
sql_plan_line_id, sql_plan_operation, sql_plan_options, session_type
;

create  global temporary table opas_ot_tmp_awr_ash_objs on commit delete rows
as
select
object_id, subprogram_id, owner, object_type, object_name, procedure_name
from dba_procedures s where 1=2;

create table opas_ot_sql_awr_ash_summ as
select dbid, snap_id, instance_number, sum(cnt) samples,
       max(pga_allocated) pga_allocated, max(temp_space_allocated) temp_space_allocated,
       sql_id, top_level_sql_id,
       sql_plan_hash_value, sql_full_plan_hash_value,
       force_matching_signature force_matching_sign,
       min(min_sql_exec_start)  min_sql_exec_start,
       max(max_sql_exec_start)  max_sql_exec_start,       
       min(min_sample_time) min_sample_time,
       max(max_sample_time) max_sample_time,
       max(program) program,  machine, max(ecid) ecid, max(module) module, max(action) action, max(client_id) client_id, 
       (select object_name from opas_ot_tmp_awr_ash_objs where object_id=user_id and object_type = 'user') schema_name,
       (select owner || '; ' || object_type || '; ' || object_name || decode(procedure_name, null, null, '.' || procedure_name) 
          from opas_ot_tmp_awr_ash_objs where object_id=plsql_entry_object_id and subprogram_id=plsql_entry_subprogram_id  and object_type != 'user') top_call,
       (select owner || '; ' || object_type || '; ' || object_name || decode(procedure_name, null, null, '.' || procedure_name) 
          from opas_ot_tmp_awr_ash_objs where object_id=plsql_object_id and subprogram_id=plsql_subprogram_id and object_type != 'user') end_call 
  from opas_ot_tmp_dbh_ash
 where 1=2
 group by dbid, snap_id,instance_number,
          sql_id,
          top_level_sql_id,
          sql_plan_hash_value,sql_full_plan_hash_value,
          force_matching_signature, plsql_entry_object_id, plsql_entry_subprogram_id,
          plsql_object_id, plsql_subprogram_id,
          machine, user_id;

alter table opas_ot_sql_awr_ash_summ add dblink  varchar2(128)  not null  references opas_db_links (db_link_name);
create index idx_opas_sql_awr_ashsum_dbl   on opas_ot_sql_awr_ash_summ(dblink);

alter table opas_ot_sql_awr_ash_summ add constraint fk_sql_awrashsum_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create unique index idx_opas_sql_awrashsum_sqlid on opas_ot_sql_awr_ash_summ(sql_id, dblink, dbid, snap_id, sql_plan_hash_value, instance_number);

create table opas_ot_sql_awr_ash_plst as
select sql_id,dbid, snap_id, sql_plan_hash_value,sql_full_plan_hash_value,
       sql_plan_line_id,
       sql_plan_operation,sql_plan_options,
       nvl(event, 'CPU') event,
       sum(cnt) samples
  from opas_ot_tmp_dbh_ash
 where 1=2
 group by sql_id,dbid, snap_id, sql_plan_hash_value,sql_full_plan_hash_value,
          sql_plan_line_id,
          sql_plan_operation,
          sql_plan_options,
          nvl(event, 'CPU');

alter table opas_ot_sql_awr_ash_plst add dblink  varchar2(128)  not null  references opas_db_links (db_link_name);
alter table opas_ot_sql_awr_ash_plst ROW STORE COMPRESS ADVANCED;

create index idx_opas_sql_awr_ashplst_dbl   on opas_ot_sql_awr_ash_plst(dblink) compress;

alter table opas_ot_sql_awr_ash_plst add constraint fk_sql_awrashplst_sqlid foreign key (sql_id) references opas_ot_sql_descriptions(sql_id) on delete cascade;

create index idx_opas_sql_awrashplst_sqlid on opas_ot_sql_awr_ash_plst(sql_id, dblink, dbid, snap_id, sql_plan_hash_value, sql_plan_line_id) compress;		  
---------------------------------------------------------------------------------------------
-- sql lists
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
-- reports
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

