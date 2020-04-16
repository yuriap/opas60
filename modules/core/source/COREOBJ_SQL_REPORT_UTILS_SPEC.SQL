CREATE OR REPLACE
PACKAGE COREOBJ_SQL_REPORT_UTILS AS

  -- select rpad('  reps'||upper(x.val),30,' ')||'constant varchar2(30) := '''||rpad(upper(x.val||''';'),20,' ')||' -- '||x.display_val from opas_dictionary x where dic_name='SQLREPSECT' order by dic_ordr;

  repsSQL_TEXT                constant varchar2(30) := 'SQL_TEXT';           -- SQL Text
  repsSHARING                 constant varchar2(30) := 'SHARING';            -- Non shared reason
  repsVSQL                    constant varchar2(30) := 'VSQL';               -- V$SQL statistics
  repsEXADATA                 constant varchar2(30) := 'EXADATA';            -- Exadata statistics
  repsSQLMONV$                constant varchar2(30) := 'SQLMONV$';           -- SQL Monitor report
  repsWORKAREA                constant varchar2(30) := 'WORKAREA';           -- SQL Workarea
  repsOPTENV                  constant varchar2(30) := 'OPTENV';             -- CBO environment
  repsSQLPLLAST               constant varchar2(30) := 'SQLPLLAST';          -- Display cursor (last)
  repsSQLPLADV                constant varchar2(30) := 'SQLPLADV';           -- Display cursor (LAST ADVANCED)
  repsSQLPLALL                constant varchar2(30) := 'SQLPLALL';           -- Display cursor (ALL)
  repsSQLPLADAPT              constant varchar2(30) := 'SQLPLADAPT';         -- Display cursor (ADAPTIVE)
  repsSQLPLEP                 constant varchar2(30) := 'SQLPLEP';            -- Explain Plan
  repsSQLMONHST               constant varchar2(30) := 'SQLMONHST';          -- SQL Monitor report history
  repsVASH                    constant varchar2(30) := 'VASH';               -- ASH summary
  repsAWR_SQLSTAT             constant varchar2(30) := 'AWR_SQLSTAT';        -- AWR SQL statistics
  repsAWR_BINDS               constant varchar2(30) := 'AWR_BINDS';          -- AWR SQL Binds
  repsAWR_SQLPLAN             constant varchar2(30) := 'AWR_SQLPLAN';        -- AWR Display cursor
  repsAWR_PLSQLSRC            constant varchar2(30) := 'AWR_PLSQLSRC';       -- AWR ASH PL/SQL source
  repsAWR_ASHINVOKER          constant varchar2(30) := 'AWR_ASHINVOKER';     -- AWR ASH Invocers
  repsAWR_ASHPLSTATS          constant varchar2(30) := 'AWR_ASHPLSTATS';     -- AWR ASH plan staictics

--  procedure print_sql_text_html(p_file_id   opas_files.file_id%type);
--  procedure print_vsql_section_html(p_sess_id   opas_ot_sql_data.sess_id%type);
  defDataTimeFmt              constant varchar2(30) := 'YYYY/MM/DD HH24:MI';
  defDataTimeFullFmt          constant varchar2(30) := 'YYYY/MM/DD HH24:MI:SS';

  function  get_header_refresh_interval(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type) return number;
  procedure print_header(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type);

  procedure print_section_html(p_sql_data_point_id   opas_ot_sql_data.sql_data_point_id%type,
                               p_section_name varchar2,
                               p_sql_id   opas_ot_sql_data.sql_id%type default null);

  --cmd utils
  function gathering_status(p_obj_id  opas_objects.obj_id%type) return TABLEOFSTRINGS pipelined;
  function print_report_html(p_obj_id  opas_objects.obj_id%type) return TABLEOFSTRINGS pipelined;

  function print_data_point_params(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type) return varchar2 result_cache;

END COREOBJ_SQL_REPORT_UTILS;
/
