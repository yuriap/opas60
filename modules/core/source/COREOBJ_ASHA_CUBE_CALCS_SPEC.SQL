

CREATE OR REPLACE
PACKAGE COREOBJ_ASHA_CUBE_CALCS AS

  -- Main Parameters
  pDBLINK         constant varchar2(100) := 'ASHAB_DBLINK';
  pSTARTDT        constant varchar2(100) := 'ASHAB_STARTDT';
  pENDDT          constant varchar2(100) := 'ASHAB_ENDDT';
  pGETSTATS       constant varchar2(100) := 'ASHAB_GETSTATS'; --v$sesstat
  pMetricList     constant varchar2(100) := 'ASHAB_METRICLST';

  pDTFMT          constant varchar2(100) := 'ASHAB_DTFMT';

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

  function gp(p_name varchar2) return varchar2;
  procedure get_ash_data(p_obj_id  opas_objects.obj_id%type);

END COREOBJ_ASHA_CUBE_CALCS;
/


