

CREATE OR REPLACE
PACKAGE COREMOD_SCHEDULER AS

  scaSave              constant varchar2(32) := 'SAVE';
  scaValidate          constant varchar2(32) := 'VALIDATE';
  scaActivate          constant varchar2(32) := 'ACTIVATE';
  scaSuspend           constant varchar2(32) := 'SUSPEND';
  scaCleanup           constant varchar2(32) := 'CLEANUP';
  scaDrop              constant varchar2(32) := 'DROP';

  scsNew               constant varchar2(32) := 'NEW';
  scsValidated         constant varchar2(32) := 'VALIDATED';
  scsActive            constant varchar2(32) := 'ACTIVE';
  scsActiveChanged     constant varchar2(32) := 'ACTIVECHANGED';
  scsSuspended         constant varchar2(32) := 'SUSPENDED';

  procedure inis_scheduler (p_sch_id      out OPAS_SCHEDULER.SCH_ID%type,
                            p_schedule    OPAS_SCHEDULER.schedule%type,
                            p_start_date  OPAS_SCHEDULER.start_date%type,
                            p_PLSQL_CALL  OPAS_SCHEDULER.PLSQL_CALL%type,
                            p_owner       OPAS_SCHEDULER.owner%type default v('APP_USER'));

  procedure set_parameters (p_sch_id      OPAS_SCHEDULER.SCH_ID%type,
                            p_schedule    OPAS_SCHEDULER.schedule%type,
                            p_start_date  OPAS_SCHEDULER.start_date%type);

  procedure suspend_config (p_sch_id OPAS_SCHEDULER.SCH_ID%type);
  procedure activate_config(p_sch_id OPAS_SCHEDULER.SCH_ID%type);
  procedure validate_config(p_sch_id OPAS_SCHEDULER.SCH_ID%type);
  procedure cleanup_config (p_sch_id OPAS_SCHEDULER.SCH_ID%type);
  procedure drop_config    (p_sch_id OPAS_SCHEDULER.SCH_ID%type);

  function check_action(p_sch_id OPAS_SCHEDULER.SCH_ID%type, p_action varchar2) return boolean;
  function getstatus(p_action varchar2, p_status varchar2) return varchar2;
  --top level call
  procedure run_job        (p_sch_id OPAS_SCHEDULER.SCH_ID%type);

END COREMOD_SCHEDULER;
/


