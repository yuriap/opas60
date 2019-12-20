CREATE OR REPLACE
PACKAGE COREOBJ_SQL_REPORT_UTILS AS

  -- select rpad('  reps'||upper(x.val),30,' ')||'constant varchar2(30) := '''||rpad(upper(x.val||''';'),15,' ')||' -- '||x.display_val from opas_dictionary x where dic_name='SQLREPSECT' order by dic_ordr;

  repsSQL_TEXT                constant varchar2(30) := 'SQL_TEXT';      -- SQL Text
  repsSHARING                 constant varchar2(30) := 'SHARING';       -- Non shared reason
  repsVSQL                    constant varchar2(30) := 'VSQL';          -- V$SQL statistics
  repsEXADATA                 constant varchar2(30) := 'EXADATA';       -- Exadata statistics
  repsSQLMON                  constant varchar2(30) := 'SQLMONV$';        -- SQL Monitor report
  repsWORKAREA                constant varchar2(30) := 'WORKAREA';      -- SQL Workarea
  repsOPTENV                  constant varchar2(30) := 'OPTENV';        -- CBO environment
  repsSQLPLLAST               constant varchar2(30) := 'SQLPLLAST';     -- Display cursor (last)
  repsSQLPLADV                constant varchar2(30) := 'SQLPLADV';      -- Display cursor (LAST ADVANCED)
  repsSQLPLALL                constant varchar2(30) := 'SQLPLALL';      -- Display cursor (ALL)
  repsSQLPLADAPT              constant varchar2(30) := 'SQLPLADAPT';    -- Display cursor (ADAPTIVE)
  repsSQLPLAWR                constant varchar2(30) := 'SQLPLAWR';      -- Display cursor (AWR)
  repsSQLMONHST               constant varchar2(30) := 'SQLMONHST';     -- SQL Monitor report history
  repsVASH                    constant varchar2(30) := 'VASH';          -- ASH summary

--  procedure print_sql_text_html(p_file_id   opas_files.file_id%type);
--  procedure print_vsql_section_html(p_sess_id   opas_ot_sql_data.sess_id%type);

  function  get_header_refresh_interval(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type) return number;
  procedure print_header(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type);

  procedure print_section_html(p_sql_data_point_id   opas_ot_sql_data.sql_data_point_id%type,
                               p_section_name varchar2);

END COREOBJ_SQL_REPORT_UTILS;
/
