CREATE OR REPLACE
PACKAGE COREOBJ_SQL_UTILS AS

  sstNotStarted    constant varchar2(30) := 'Not started';
  sstInProgress    constant varchar2(30) := 'In progress';
  sstReady         constant varchar2(30) := 'Ready';
  sstFailed        constant varchar2(30) := 'Failed';
  sstEmpty         constant varchar2(30) := 'Empty';
  sstNoSection     constant varchar2(30) := 'No section';

  srcV$            constant varchar2(30) := 'V$';
  srcHST           constant varchar2(30) := 'HST';
  srcAWR           constant varchar2(30) := 'AWR';
  srcEP            constant varchar2(30) := 'EP';

  --default data gathering parameters
  defSQLMONHSTDays     constant  number := 8;         pnSQLMONHSTDays     constant varchar2(30) := 'SQL_SQLMONHSTDAYS';
  defSQLMONHSTRows     constant  number := 10;        pnSQLMONHSTRows     constant varchar2(30) := 'SQL_SQLMONHSTROWS';
  defAWRDataDays       constant  number := 8;         pnAWRDataDays       constant varchar2(30) := 'SQL_AWRDATADAYS';
  defAWRSearchLastDays constant varchar2(1) := 'N';   pnAWRSearchLastDays constant varchar2(30) := 'SQL_AWRSEARCHLASTDAYS';
  pnAWRStartDT         constant varchar2(30) := 'SQL_AWRSTARTDT';
  pnAWREndDT           constant varchar2(30) := 'SQL_AWRENDDT';
  pnAllParsDispl       constant varchar2(30) := 'SQL_ALLPARSDISPL';

  defV$Recursive       constant number := -1; /* -1 not gather */  pnV$Recursive       constant varchar2(30) := 'SQL_V$RECURSIVE';
  defAWRRecursive      constant number := -1; /* -1 not gather */  pnAWRRecursive      constant varchar2(30) := 'SQL_AWRRECURSIVE';

  type t_awr_params_rec is record (
    DBLINK               OPAS_DB_LINK_V$DB.DBLINK%type,
    DBID                 OPAS_DB_LINK_V$DB.DBID%type,
    CON_ID               OPAS_DB_LINK_V$DB.CON_ID%type,
    INSTANCE_LIST_C      varchar2(32765),
    SNAP_START           OPAS_DB_LINK_AWRSNAPS.SNAP_ID%type,
    SNAP_END             OPAS_DB_LINK_AWRSNAPS.SNAP_ID%type,
    BEGIN_INTERVAL_TIME  OPAS_DB_LINK_AWRSNAPS.BEGIN_INTERVAL_TIME%type,
    END_INTERVAL_TIME    OPAS_DB_LINK_AWRSNAPS.END_INTERVAL_TIME%type,
    INCARNATION#         OPAS_DB_LINK_AWRSNAPS.INCARNATION#%type,
    DATES_SPECIFIED      boolean
  );

  procedure discover_sql (p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type);
  procedure discover_sql2(p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type);

  procedure is_section_ready(p_sql_data_point_id      opas_ot_sql_data.sql_data_point_id%type,
                             p_section_name           varchar2,
                             p_status             out opas_ot_sql_data_sect.gathering_status%type,
                             p_errm               out opas_ot_sql_data_sect.error_message%type);

  function  is_section_empty(p_sql_data_point_id      opas_ot_sql_data.sql_data_point_id%type,
                             p_section_name           varchar2) return boolean;
  function  is_section_no_data(p_sql_id              opas_ot_sql_data.sql_id%type,
                                p_section_name           varchar2) return boolean;

  procedure init_section_statuses(p_sql_data_point_id opas_ot_sql_data.sql_data_point_id%type);
  procedure refresh_section(p_sql_data_point_id       opas_ot_sql_data.sql_data_point_id%type,
                            p_section_name            varchar2);

  procedure getdatacmd
                  (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_sql_id           opas_ot_sql_descriptions.sql_id%type,
                   p_db_link          opas_db_links.db_link_name%type,
                   p_current_dir      varchar2,
                   p_gather_new       boolean,
                   p_dirname      out varchar2);

  procedure cancel_discover_sql (p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type);

  procedure get_approxtext(p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type,
                           p_raise_exception            boolean default true);

END COREOBJ_SQL_UTILS;
/
