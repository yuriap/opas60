

CREATE OR REPLACE
PACKAGE COREOBJ_ASHA_CUBE_CALCS AS

  -- Main Parameters
  pDBLINK         constant varchar2(100) := 'ASHAB_DBLINK';
  pSTARTDT        constant varchar2(100) := 'ASHAB_STARTDT';
  pENDDT          constant varchar2(100) := 'ASHAB_ENDDT';
  pGETSTATS       constant varchar2(100) := 'ASHAB_GETSTATS'; --v$sesstat
  pMetricList     constant varchar2(100) := 'ASHAB_METRICLST';

  pDTFMT          constant varchar2(100) := 'ASHAB_DTFMT';

  --cube/range status
  csNEW           constant varchar2(100) := 'NEW';
  csInQueue       constant varchar2(100) := 'INQUEUE';
  csReady         constant varchar2(100) := 'READY';
  csInProgress    constant varchar2(100) := 'INPROGRESS';
  csEmpty         constant varchar2(100) := 'EMPTY';

  --granule type V GV$ASH, A DBA_HIST_ASH, S - Samples of GV$SESS
  gtGV$ASH        constant varchar2(100) := 'V';
  gtGV$ASHAWR     constant varchar2(100) := 'VA';
  gtDBA_HIST_ASH  constant varchar2(100) := 'A';
  gtSamplGV$SESS  constant varchar2(100) := 'S';
  /*
  p        constant varchar2(100) := 'ASHAB_';
  p        constant varchar2(100) := 'ASHAB_';
  p        constant varchar2(100) := 'ASHAB_';
  p        constant varchar2(100) := 'ASHAB_';
  p        constant varchar2(100) := 'ASHAB_';
  p        constant varchar2(100) := 'ASHAB_';
  p        constant varchar2(100) := 'ASHAB_';
  p        constant varchar2(100) := 'ASHAB_';
  p        constant varchar2(100) := 'ASHAB_';
  p        constant varchar2(100) := 'ASHAB_';
  */
  procedure load_params (p_obj_id  opas_objects.obj_id%type);
  procedure store_params(p_obj_id  opas_objects.obj_id%type);

  function gp(p_name varchar2) return varchar2;
  procedure setp(p_name varchar2, p_value varchar2);

  procedure init_cube_ranges(p_obj_id  opas_objects.obj_id%type);

  procedure get_ash_data(p_obj_id  opas_objects.obj_id%type);
  procedure sample_stat_for_granule(p_asharange_id opas_ot_ashacube_ranges.asharange_id%type);
  procedure sample_data_for_granule(p_asharange_id opas_ot_ashacube_ranges.asharange_id%type);

  function show_remote_date_context(p_dblink opas_db_links.db_link_name%type) return varchar2;

  procedure set_cube_preserve(p_obj_id  opas_objects.obj_id%type, p_preserve boolean default true);
  procedure set_range_preserve(p_asharange_id opas_ot_ashacube_ranges.asharange_id%type, p_preserve boolean default true);

  procedure cancel_all_jobs(p_obj_id  opas_objects.obj_id%type);

END COREOBJ_ASHA_CUBE_CALCS;
/


