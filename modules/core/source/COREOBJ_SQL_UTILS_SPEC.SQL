CREATE OR REPLACE
PACKAGE COREOBJ_SQL_UTILS AS

  sstNotStarted    constant varchar2(30) := 'Not started';
  sstInProgress    constant varchar2(30) := 'In progress';
  sstReady         constant varchar2(30) := 'Ready';
  sstFailed        constant varchar2(30) := 'Failed';
  sstEmpty         constant varchar2(30) := 'Empty';

  srcV$            constant varchar2(30) := 'V$';
  srcHST           constant varchar2(30) := 'HST';
  srcAWR           constant varchar2(30) := 'AWR';

  --default data gathering parameters
  defSQLMONHSTDays constant  number := 8;    pnSQLMONHSTDays     constant varchar2(30) := 'SQL_SQLMONHSTDAYS';
  defSQLMONHSTRows constant  number := 10;   pnSQLMONHSTRows     constant varchar2(30) := 'SQL_SQLMONHSTROWS';
  defAWRDataDays   constant  number := 8;    pnAWRDataDays       constant varchar2(30) := 'SQL_AWRDATADAYS';
  pnAWRStartDT     constant varchar2(30) := 'SQL_AWRSTARTDT';
  pnAWREndDT       constant varchar2(30) := 'SQL_AWRENDDT';

  type t_awr_params_rec is record (
    DBLINK               OPAS_DB_LINK_V$DB.DBLINK%type,
    DBID                 OPAS_DB_LINK_V$DB.DBID%type,
    CON_ID               OPAS_DB_LINK_V$DB.CON_ID%type,
    INSTANCE_LIST_C      varchar2(32765),
    SNAP_START           OPAS_DB_LINK_AWRSNAPS.SNAP_ID%type,
    SNAP_END             OPAS_DB_LINK_AWRSNAPS.SNAP_ID%type,
    BEGIN_INTERVAL_TIME  OPAS_DB_LINK_AWRSNAPS.BEGIN_INTERVAL_TIME%type,
    END_INTERVAL_TIME    OPAS_DB_LINK_AWRSNAPS.END_INTERVAL_TIME%type
  );

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

  procedure update_dblink_db_info_awrsn(p_db_link_name varchar2,
                                        p_days         number,
                                        p_start_dt     timestamp with time zone,
                                        p_end_dt       timestamp with time zone,
                                        p_params   out t_awr_params_rec);
END COREOBJ_SQL_UTILS;
/
