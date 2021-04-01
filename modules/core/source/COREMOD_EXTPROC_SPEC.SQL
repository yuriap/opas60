

CREATE OR REPLACE
PACKAGE COREMOD_EXTPROC AS

--  gemDBLINK  constant varchar2(10):='DBLINK';
--  gemSQLPLUS constant varchar2(10):='SQLPLUS';
--  gemJAVASRV constant varchar2(10):='JAVASRV';

  type t_columns is table of varchar2(1000) index by varchar2(128);

--  function external_mode return varchar2;
--  function external_mode_dblink return boolean;
--  function external_mode_sqlplus return boolean;
--  function external_mode_javasrv return boolean;

  --procedure exec_sql(p_dblink varchar2, p_sql varchar2, p_exec_id out number);
  --procedure cleanup_exec(p_exec_id number);

  procedure load_external_data(p_target_table varchar2,
                               p_select_list  t_columns,
                               p_sql_body     varchar2,
                               p_dblink       varchar2,
                               p_priority     number default 3,
                               p_task_id      out number);

  procedure Cleanup_queue;

  procedure coordinator_proc;
  procedure start_coordinator;
  procedure stop_coordinator;

  procedure worker_proc(p_work_id number);
  procedure worker_finished(p_work_id number, p_stmt_done number, p_errors varchar2);
  procedure stop_worker(p_work_id number);
  procedure report_connection_problem(p_work_id number, p_errormsg varchar2);

  procedure init_server_parameters(p_work_id number, p_username out varchar2, p_password out varchar2, p_connstr out varchar2, p_query_num out number, p_logging_mode out varchar2);
  procedure get_next_task(p_work_id number, p_task_id out number, p_qry_type out varchar2, p_qry1 out varchar2, p_qry2 out varchar2, p_num_cols out number, p_timeouted out number);
  --procedure set_task_selected_data(p_task_id number);
  procedure set_task_finshed(p_task_id number, p_status varchar2, p_errormsg varchar2/*, p_result clob default null*/);
  procedure set_task_taken(p_task_id number);
  procedure wait_result(p_task_id number, p_timeout number default 600);

  function get_server_status(p_format varchar2) return varchar2;

END COREMOD_EXTPROC;
/


