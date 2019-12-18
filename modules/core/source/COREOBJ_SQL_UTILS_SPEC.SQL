CREATE OR REPLACE
PACKAGE COREOBJ_SQL_UTILS AS

  sstNotStarted    constant varchar2(30) := 'Not started';
  sstInProgress    constant varchar2(30) := 'In progress';
  sstReady         constant varchar2(30) := 'Ready';
  sstFailed        constant varchar2(30) := 'Failed';
  sstEmpty         constant varchar2(30) := 'Empty';

  procedure discover_sql(p_sess_id   opas_ot_sql_data.sess_id%type);
  procedure discover_sql2(p_sess_id  opas_ot_sql_data.sess_id%type);

  procedure is_section_ready(p_sess_id                opas_ot_sql_data.sess_id%type,
                             p_section_name           varchar2,
                             p_status             out opas_ot_sql_data_sect.gathering_status%type,
                             p_errm               out opas_ot_sql_data_sect.error_message%type);

  procedure init_section_statuses(p_sess_id      opas_ot_sql_data.sess_id%type);
  procedure refresh_section(p_sess_id   opas_ot_sql_data.sess_id%type,
                            p_section_name varchar2);

END COREOBJ_SQL_UTILS;
/
