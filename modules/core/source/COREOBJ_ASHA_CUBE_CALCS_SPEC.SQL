

CREATE OR REPLACE
PACKAGE COREOBJ_ASHA_CUBE_CALCS AS

  -- Main Parameters
  pDBLINK         constant varchar2(100) := 'ASHAB_DBLINK';
  pSTARTDT        constant varchar2(100) := 'ASHAB_STARTDT';
  pENDDT          constant varchar2(100) := 'ASHAB_ENDDT';
  pGETSTATS       constant varchar2(100) := 'ASHAB_GETSTATS'; --v$sesstat
  pMetricList     constant varchar2(100) := 'ASHAB_METRICLST';

  pDTFMT          constant varchar2(100) := 'ASHAB_DTFMT';

  --cube status
  csNEW           constant varchar2(100) := 'NEW';
  csReady         constant varchar2(100) := 'READY';
  csInProgress    constant varchar2(100) := 'INPROGRESS';

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

  function gp(p_name varchar2) return varchar2;


  procedure get_ash_data(p_obj_id  opas_objects.obj_id%type);

  function show_remote_date_context(p_dblink opas_db_links.db_link_name%type) return varchar2;

END COREOBJ_ASHA_CUBE_CALCS;
/


