CREATE OR REPLACE
PACKAGE COREOBJ_SQL AS

  -- SQL Data Object statuses
  sdoNotStarted    constant varchar2(30) := 'NOT_STARTED';
  sdoInQueue       constant varchar2(30) := 'INQUEUE';
  sdoInProgress    constant varchar2(30) := 'INPROGRESS';
  sdoWaitFor2      constant varchar2(30) := 'WAITSECONDARY';
  sdoREADY         constant varchar2(30) := 'READY';
  sdoFAILED        constant varchar2(30) := 'FAILED';
  --sdo     constant varchar2(30) := '';


  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_modname          opas_files.modname%type default COREMOD_API.gMODNAME,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_descr            opas_objects.obj_descr%type,
                   p_sql_id           opas_ot_sql_descriptions.sql_id%type,
                   p_db_link          opas_db_links.db_link_name%type);

  procedure queue_discover_sql(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type);

  procedure remove  (p_obj_id         opas_objects.obj_id%type,
                     p_cascade        varchar2 default 'N');

  procedure remove_dp(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type);

  procedure drop_sql(p_sql_id         opas_ot_sql_descriptions.sql_id%type);

  --
--  procedure group_sql_in_folder(
--                    p_folder_id        opas_objects.obj_id%type);

END COREOBJ_SQL;
/
