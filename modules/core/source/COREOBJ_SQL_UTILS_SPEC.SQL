CREATE OR REPLACE
PACKAGE COREOBJ_SQL_UTILS AS

  sstNotStarted    constant varchar2(30) := 'Not started';
  sstInProgress    constant varchar2(30) := 'In progress';
  sstReady         constant varchar2(30) := 'Ready';
  sstFailed        constant varchar2(30) := 'Failed';
  sstEmpty         constant varchar2(30) := 'Empty';

  srcV$            constant varchar2(30) := 'V$';
  srcHST           constant varchar2(30) := 'HST';

  procedure discover_sql (p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type);
  procedure discover_sql2(p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type);

  procedure is_section_ready(p_sql_data_point_id      opas_ot_sql_data.sql_data_point_id%type,
                             p_section_name           varchar2,
                             p_status             out opas_ot_sql_data_sect.gathering_status%type,
                             p_errm               out opas_ot_sql_data_sect.error_message%type);

  function  is_section_empty(p_sql_data_point_id      opas_ot_sql_data.sql_data_point_id%type,
                             p_section_name           varchar2) return boolean;

  procedure init_section_statuses(p_sql_data_point_id opas_ot_sql_data.sql_data_point_id%type);
  procedure refresh_section(p_sql_data_point_id       opas_ot_sql_data.sql_data_point_id%type,
                            p_section_name            varchar2);

END COREOBJ_SQL_UTILS;
/
