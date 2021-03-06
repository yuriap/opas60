create bigfile tablespace &tblspc_name. datafile size 100m autoextend on next 100m maxsize 1000m;

create user &localscheme. identified by &localscheme.
default tablespace &tblspc_name.
temporary tablespace temp;
alter user &localscheme. quota unlimited on &tblspc_name.;

grant create table to &localscheme.;
grant create view to &localscheme.;
grant create synonym to &localscheme.;
grant create job to &localscheme.;
grant create database link to &localscheme.;
grant create materialized view to &localscheme.;
grant CREATE ANY CONTEXT to &localscheme.;

grant connect, resource to &localscheme.;
grant select_catalog_role to &localscheme.;
grant manage scheduler to &localscheme.;

grant alter session to &localscheme.;
grant select any table to &localscheme.;

grant execute on dbms_auto_report to &localscheme.;
grant execute on dbms_lock to &localscheme.;
grant execute on dbms_log to &localscheme.;
grant execute on dbms_sqltune to &localscheme.;
grant execute on dbms_workload_repository to &localscheme.;
grant execute on dbms_xplan to &localscheme.;
grant execute on sys.dbms_sqltune_util0 to &localscheme.;

--APEX 18.1 uploading files
grant update on apex_180100.WWV_FLOW_TEMP_FILES to &localscheme.;
--APEX 19.1 uploading files
grant update on apex_190100.WWV_FLOW_TEMP_FILES to &localscheme.;
--APEX 20.1 uploading files
grant update on APEX_200100.WWV_FLOW_TEMP_FILES to &localscheme.;
--
grant select on gv_$active_session_history to &localscheme.;
grant select on v_$database to &localscheme.;
grant select on v_$database_incarnation to &localscheme.;
grant select on gv_$instance to &localscheme.;
grant select on v_$parameter to &localscheme.;
grant select on v_$pdbs to &localscheme.;
grant select on gv_$session to &localscheme.;
grant select on v_$session to &localscheme.;
grant select on gv_$sql to &localscheme.;
grant select on gv_$sql_shared_cursor to &localscheme.;
grant select on gv_$sql_monitor to &localscheme.;
grant select on gv_$sql_workarea to &localscheme.;
grant select on gv_$sql_optimizer_env to &localscheme.;
grant select on gv_$sql_plan_statistics_all to &localscheme.;
grant select on gv_$sysmetric_history to &localscheme.;  
grant select on v_$metricname to &localscheme.;
grant select on v_$event_name to &localscheme.;
grant select on v$event_name to &localscheme.; 
grant select on gv_$sesstat to &localscheme.;
grant select on GV_$ASH_INFO to &localscheme.;
grant select on v_$metricname to &localscheme.;
--
grant select on dba_hist_database_instance to &localscheme.;
grant select on dba_hist_reports to &localscheme.;
grant select on dba_hist_reports_details to &localscheme.;
grant select on dba_hist_sqltext to &localscheme.;
grant select on dba_hist_snapshot to &localscheme.;
grant select on dba_hist_sysmetric_history to &localscheme.;

--
grant select on dba_data_files to &localscheme.;
grant select on dba_objects to &localscheme.;
grant select on dba_registry_history to &localscheme.;
grant select on dba_registry_sqlpatch to &localscheme.;
grant select on dba_tab_cols to &localscheme.;

grant select on dba_hist_sqlstat to &localscheme.;
grant select on dba_hist_sqlbind to &localscheme.;
grant select on dba_hist_sql_plan to &localscheme.;
grant select on dba_hist_active_sess_history to &localscheme.;
grant select on dba_procedures to &localscheme.;
grant select on dba_users to &localscheme.;

grant select on dba_free_space to &localscheme.;
grant select on dba_segments to &localscheme.;
grant select on dba_tables to &localscheme.;
grant select on dba_indexes to &localscheme.;
grant select on dba_lobs to &localscheme.;
grant select on dba_lob_partitions to &localscheme.;
grant select on dba_lob_subpartitions to &localscheme.;
grant select on dba_nested_tables to &localscheme.;
grant select on dba_clusters to &localscheme.;
grant select on dba_xml_tables to &localscheme.;
grant select on dba_recyclebin to &localscheme.;
grant select on dba_scheduler_running_jobs to &localscheme.;

grant select on user_segments to &localscheme.;
grant select on user_objects to &localscheme.;
grant select on user_tables to &localscheme.;
grant select on user_indexes to &localscheme.;
grant select on user_lobs to &localscheme.;
grant select on user_lob_partitions to &localscheme.;
grant select on user_lob_subpartitions to &localscheme.;
grant select on user_nested_tables to &localscheme.;
grant select on user_clusters to &localscheme.;
grant select on user_xml_tables to &localscheme.;

grant CREATE MINING MODEL to &localscheme.;

create or replace procedure get_ext_exec_perm4java(p_user varchar2, p_server varchar2)
is
  keynum   NUMBER;
BEGIN
     sys.DBMS_JAVA.grant_permission(
           grantee             => p_user,
           permission_type     => 'SYS:java.net.SocketPermission',
           permission_name     => p_server,
           permission_action   => 'connect,resolve',
           key                 => keynum);
END;
/

grant execute on get_ext_exec_perm4java to &localscheme.;

define job_class_name=JC_&namepref.

begin
DBMS_SCHEDULER.CREATE_JOB_CLASS (
   job_class_name            => '&job_class_name.',
   logging_level             => DBMS_SCHEDULER.LOGGING_FAILED_RUNS,
   log_history               => 1,
   comments                  => 'Low logging level for coordinator jobs');
end;
/

grant execute on &job_class_name. to &localscheme.;

set serveroutput on

create or replace directory &OPASEXPIMP_DIR. as '&OPASEXPIMP_DIRPATH.';
grant read, write on directory &OPASEXPIMP_DIR. to &localscheme.;

grant execute on ctx_ddl to &localscheme.;