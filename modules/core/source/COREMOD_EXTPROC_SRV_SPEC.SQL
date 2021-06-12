

CREATE OR REPLACE
PACKAGE COREMOD_EXTPROC_SRV AS

  gshProgram constant varchar2(100) := 'OPASEXTSQL_PRG';
  gshJobName constant varchar2(100) := 'OPASEXTSQL';

  type t_jobs is table of number index by varchar2(128);

-- *****************************************************************************************************
-- cleanups
-- *****************************************************************************************************
  procedure Cleanup_queue;

-- *****************************************************************************************************
-- coordinator job procedures
-- *****************************************************************************************************
  procedure start_coordinator;
  procedure stop_coordinator;
  function get_server_status(p_format varchar2) return varchar2;
  procedure get_next_server(p_work_id out number);
  procedure coordinator_proc;

-- *****************************************************************************************************
-- worker's procedures
-- *****************************************************************************************************
  procedure worker_proc(p_work_id number);
  procedure stop_worker(p_work_id number);
  procedure stop_worker(p_job_name varchar2);
  procedure server_before_start;
  procedure init_server_parameters(p_work_id number, p_username out varchar2, p_password out varchar2, p_connstr out varchar2, p_query_num out number, p_logging_mode out varchar2, p_batch_size out number);
  procedure worker_finished(p_work_id number, p_stmt_done number, p_errors varchar2);
  procedure report_connection_problem(p_work_id number, p_errormsg varchar2);

-- *****************************************************************************************************
-- task operations
-- *****************************************************************************************************
  procedure get_next_task(p_work_id number, p_task_id out number, p_qry_type out varchar2, p_qry1 out varchar2, p_qry2 out varchar2, p_qry3 out varchar2, p_num_cols out number, p_timeouted out number);
  procedure set_task_finshed(p_work_id number, p_task_id number, p_status varchar2, p_errormsg varchar2, p_rows_processed number/*, p_result clob default null*/);

-- *****************************************************************************************************
-- client API calls parameters
-- *****************************************************************************************************

  procedure set_param(p_task_id number, p_ordr_num number, p_clob clob);
  procedure set_param(p_task_id number, p_ordr_num number, p_number number);
  procedure set_param(p_task_id number, p_ordr_num number, p_date date);
  procedure set_param(p_task_id number, p_ordr_num number, p_timestamp timestamp);
  procedure set_param(p_task_id number, p_ordr_num number, p_timestamp_tz timestamp with time zone);
  procedure set_param(p_task_id number, p_ordr_num number, p_varchar2 varchar2);

END COREMOD_EXTPROC_SRV;
/


