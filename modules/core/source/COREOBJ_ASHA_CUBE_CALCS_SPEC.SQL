

CREATE OR REPLACE
PACKAGE COREOBJ_ASHA_CUBE_CALCS AS

  -- Main Parameters
  pDBLINK         constant varchar2(100) := 'ASHAB_DBLINK';
  pSTARTDT        constant varchar2(100) := 'ASHAB_STARTDT';
  pENDDT          constant varchar2(100) := 'ASHAB_ENDDT';
  pGETSTATS       constant varchar2(100) := 'ASHAB_GETSTATS'; --v$sesstat
  pMetricList     constant varchar2(100) := 'ASHAB_METRICLST';

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

  procedure load_v$ash;

END COREOBJ_ASHA_CUBE_CALCS;
/


