

CREATE OR REPLACE
package COREOBJ_SQL_CATCHER is

  --Catcher config status
  stNew            constant varchar2(10) := 'New';
  stInactive       constant varchar2(10) := 'Inactive';
  stActive         constant varchar2(10) := 'Active';
  stActiveCO       constant varchar2(10) := 'ActiveCO';
  stPaused         constant varchar2(10) := 'Paused';

  --SQL status
  ssqltNew            constant varchar2(10) := 'New';
  ssqltReady          constant varchar2(10) := 'Ready';
  ssqltCollected      constant varchar2(10) := 'Collected';

  --Defaults  select sql_id from gv$sql where (FILTER)
  def_search_condition constant varchar2(1000) := q'[sql_text not like '%gv$sql%' and sql_text not like '%OPAS60%' and module='DBMS_SCHEDULER' and action like 'ACT%' and elapsed_time > 1e6*600]';
  def_sql_num_limit    constant number := 20;
  def_sql_time_limit   constant number := 3600;
  def_check_interval   constant number := 30;
  def_execs            constant number := 1;

  parCatchAfter        constant varchar2(30) := 'CatchAfter'; -- FIRSTEXEC, NEXTEXEC
  pvFirstExec          constant varchar2(30) := 'FIRSTEXEC';
  pvNextExec           constant varchar2(30) := 'NEXTEXEC';

  procedure add     (p_obj_id       out opas_objects.obj_id%type,
                     p_obj_prnt         opas_objects.obj_prnt%type,
                     p_modname          opas_files.modname%type default COREMOD_API.gMODNAME,
                     p_owner            opas_files.owner%type default 'PUBLIC',
                     p_catcher_name     opas_objects.obj_name%type default null,
                     p_descr            opas_objects.obj_descr%type default null);

  procedure remove  (p_obj_id         opas_objects.obj_id%type,
                     p_cascade        varchar2 default 'N');

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2;

  procedure set_catcher (p_obj_id            opas_objects.obj_id%type,
                         p_catcher_name      opas_objects.obj_name%type,
                         p_catcher_descr     opas_objects.obj_descr%type,
                         p_search_condition  opas_ot_sqlcatch.search_condition%type,
                         p_SQL_NUM_LIMIT     opas_ot_sqlcatch.SQL_NUM_LIMIT%type,
                         p_SQL_TIME_LIMIT    opas_ot_sqlcatch.SQL_TIME_LIMIT%type,
                         p_CHECK_INTERVAL    opas_ot_sqlcatch.CHECK_INTERVAL%type,
                         p_SRCDB             opas_ot_sqlcatch.SRCDB%type,
                         p_sql_exec_def      opas_ot_sqlcatch.sql_exec_def%type);

  procedure activate_catcher (p_obj_id            opas_objects.obj_id%type,
                              p_start_time        date default null);
  procedure collectonly_catcher (p_obj_id            opas_objects.obj_id%type);
  procedure pause_catcher    (p_obj_id            opas_objects.obj_id%type);
  procedure resume_catcher   (p_obj_id            opas_objects.obj_id%type);
  procedure stop_catcher     (p_obj_id            opas_objects.obj_id%type);

  procedure task_catcher     (p_obj_id            opas_objects.obj_id%type);

  procedure load_params (p_obj_id  opas_objects.obj_id%type);
  procedure store_params(p_obj_id  opas_objects.obj_id%type);

  function gp(p_name varchar2) return varchar2;
  procedure setp(p_name varchar2, p_value varchar2);

end COREOBJ_SQL_CATCHER;
/


