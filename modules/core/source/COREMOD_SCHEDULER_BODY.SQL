

CREATE OR REPLACE
PACKAGE BODY COREMOD_SCHEDULER AS

  function check_action(p_sch_id OPAS_SCHEDULER.SCH_ID%type, p_action varchar2) return boolean
  is
    l_scheduler V$OPAS_SCHEDULER%rowtype;
    l_res boolean := false;
  begin
    select * into l_scheduler from OPAS_SCHEDULER where sch_id=p_sch_id;
    return getstatus(p_action, l_scheduler.status) is not null;
  exception
    when no_data_found then return false;
  end;

  function getstatus(p_action varchar2, p_status varchar2) return varchar2
  is
  begin
    return case
             when p_action = scaSave then
                case when p_status in (scsActive, scsActiveChanged) then null when p_status in (scsValidated, scsSuspended, scsNew) then scsNew else null end
             when p_action = scaValidate then
                case when p_status in (scsActive, scsActiveChanged, scsValidated) then null when p_status in (scsSuspended, scsNew) then scsValidated else null end
             when p_action = scaActivate then
                case when p_status in (scsValidated) then scsActive when p_status in (scsActive, scsActiveChanged, scsSuspended, scsNew) then null else null end
             when p_action = scaSuspend then
                case when p_status in (scsActive, scsActiveChanged) then scsSuspended when p_status in (scsValidated, scsSuspended, scsNew) then null else null end
             when p_action = scaCleanup then
                case when p_status in (scsActive, scsActiveChanged) then null when p_status in (scsValidated, scsSuspended, scsNew) then scsNew else null end
             when p_action = scaDrop then
                case when p_status in (scsActive, scsActiveChanged) then null when p_status in (scsValidated, scsSuspended, scsNew) then scsNew else null end
             else
               null
           end;
  end;

  procedure inis_scheduler (p_sch_id      out OPAS_SCHEDULER.SCH_ID%type,
                            p_schedule    OPAS_SCHEDULER.schedule%type,
                            p_start_date  OPAS_SCHEDULER.start_date%type,
                            p_PLSQL_CALL  OPAS_SCHEDULER.PLSQL_CALL%type,
                            p_owner       OPAS_SCHEDULER.owner%type default v('APP_USER')) AS
  BEGIN
--    if p_sch_id is null then
       insert into OPAS_SCHEDULER
              (  start_date,   schedule, last_changed, last_validated, PLSQL_CALL,   owner)
       values (p_start_date, p_schedule, systimestamp, null,           p_PLSQL_CALL, p_owner) returning sch_id into p_sch_id;
/*
    else
      update V$OPAS_SCHEDULER t set
         t.start_date=p_start_date,
         t.schedule=p_schedule,
         t.last_changed = systimestamp,
         t.last_validated = null,
         t.PLSQL_CALL = p_PLSQL_CALL,
         t.status = getstatus(scaSave, t.status)
       where sch_id=p_sch_id;

      if sql%rowcount=1 then
        delete from opas_scheduler_validation where sch_id=p_sch_id;
      end if;
*/
--    end if;
  END inis_scheduler;

  procedure set_parameters (p_sch_id      OPAS_SCHEDULER.SCH_ID%type,
                            p_schedule    OPAS_SCHEDULER.schedule%type,
                            p_start_date  OPAS_SCHEDULER.start_date%type) AS
  BEGIN
    if check_action(P_SCH_ID => p_sch_id, P_ACTION => scaSave) then
      update OPAS_SCHEDULER t set
         t.start_date=p_start_date,
         t.schedule=p_schedule,
         t.last_changed = systimestamp,
         t.last_validated = null,
         t.status = getstatus(scaSave, t.status)
       where sch_id=p_sch_id;

      if sql%rowcount=1 then
        delete from opas_scheduler_validation where sch_id=p_sch_id;
      end if;
    else
      raise_application_error(-20000,'Unable to save Scheduler configuration('|| p_sch_id ||'). Wrong status');
    end if;
  END set_parameters;

  procedure suspend_config (p_sch_id OPAS_SCHEDULER.SCH_ID%type) AS
    l_params  OPAS_SCHEDULER%rowtype;
  begin
    if check_action(P_SCH_ID => p_sch_id, P_ACTION => scaSuspend) then
      select * into l_params from OPAS_SCHEDULER where sch_id=p_sch_id;
      for i in (select job_name from user_scheduler_running_jobs where job_name=l_params.job_name) loop
        begin
          DBMS_SCHEDULER.stop_job(l_params.job_name);
        exception
          when others then
            COREMOD_LOG.log('Suspension: Stopping job '||l_params.job_name||' error: '||sqlerrm);
        end;
      end loop;
      DBMS_SCHEDULER.disable(l_params.job_name);
      update OPAS_SCHEDULER t set t.status = getstatus(scaSuspend, t.status) where sch_id=p_sch_id;
--    else
--      raise_application_error(-20000,'Unable to suspend Scheduler configuration('|| p_sch_id ||'). Wrong status');
    end if;
  END suspend_config;

  procedure run_job        (p_sch_id OPAS_SCHEDULER.SCH_ID%type)
  is
    l_params  OPAS_SCHEDULER%rowtype;
  begin
    for l_params in (select * from OPAS_SCHEDULER where sch_id=p_sch_id and status in (scsActive, scsActiveChanged))
    loop
      if l_params.job_name is not null and l_params.last_validated is not null then
        execute immediate 'begin '||l_params.PLSQL_CALL||' end;';
      end if;
    end loop;
/*
  exception
    when others then
      set alert
*/
  end;

  procedure activate_config(p_sch_id OPAS_SCHEDULER.SCH_ID%type) AS
    l_params  OPAS_SCHEDULER%rowtype;
    l_cnt     number := 0;
  begin
    if check_action(P_SCH_ID => p_sch_id, P_ACTION => scaActivate) then
      select * into l_params from OPAS_SCHEDULER where sch_id=p_sch_id;
      if l_params.last_validated > l_params.last_changed then
        delete from opas_scheduler_validation where sch_id=p_sch_id;

        if l_params.job_name is not null then
          select count(1) into l_cnt from user_scheduler_jobs where job_name=l_params.job_name;
          if l_cnt=1 then
            DBMS_SCHEDULER.SET_ATTRIBUTE(name => l_params.job_name,
                                         attribute => 'start_date',
                                         value => l_params.start_date);
            DBMS_SCHEDULER.SET_ATTRIBUTE(name => l_params.job_name,
                                         attribute => 'repeat_interval',
                                         value => l_params.schedule);
            DBMS_SCHEDULER.enable(l_params.job_name);
          end if;
        end if;

        if l_params.job_name is null or l_cnt=0 then
          l_params.job_name := 'OPAS_SCH_'||l_params.SCH_ID||'_'||DBMS_RANDOM.STRING('X',4);
          dbms_scheduler.create_job(job_name => l_params.job_name,
                                    job_type => 'PLSQL_BLOCK',
                                    job_action => 'begin COREMOD_SCHEDULER.run_job('||l_params.sch_id||'); end;',
                                    start_date => l_params.start_date,
                                    repeat_interval => l_params.schedule,
                                    enabled => true,
                                    auto_drop=> false);
        end if;

        update OPAS_SCHEDULER t set job_name = l_params.job_name, t.status = getstatus(scaActivate, t.status) where sch_id=p_sch_id;
      end if;
    else
      raise_application_error(-20000,'Unable to activate Scheduler configuration('|| p_sch_id ||'). Wrong status');
    end if;
  END activate_config;

  procedure validate_config(p_sch_id OPAS_SCHEDULER.SCH_ID%type) AS
    l_params    OPAS_SCHEDULER%rowtype;
    l_msg       opas_scheduler_validation.message%type;
    l_next_date TIMESTAMP WITH TIME ZONE;
    l_users     DBMS_UTILITY.uncl_array;
    l_tbln      BINARY_INTEGER;
    l_res       varchar2(100);
    l_chk       boolean := false;
  begin
    if check_action(P_SCH_ID => p_sch_id, P_ACTION => scaValidate) then
      select * into l_params from OPAS_SCHEDULER where sch_id=p_sch_id;

      update OPAS_SCHEDULER set last_validated = null where sch_id=p_sch_id;
      delete from opas_scheduler_validation where sch_id=p_sch_id;

      begin
        l_msg := 'Schedule validation';
        DBMS_SCHEDULER.EVALUATE_CALENDAR_STRING(
          calendar_string    => l_params.schedule,
          start_date         => l_params.start_date,
          return_date_after  => null,
          next_run_date      => l_next_date);
        if l_next_date is not null then
          insert into opas_scheduler_validation (sch_id,status,message) values (p_sch_id,'OK',l_msg||': '||to_char(l_next_date,'YYYY-MON-DD HH24:MI:SS.ff3 TZH:TZM'));
        else
          insert into opas_scheduler_validation (sch_id,status,message) values (p_sch_id,'ERROR',l_msg||': unable to calculate next date');
        end if;
      exception
        when others then
          l_chk := true;
          l_msg := substr(l_msg||': '||sqlerrm,1,4000);
          insert into opas_scheduler_validation (sch_id,status,message) values (p_sch_id,'ERROR',l_msg);
      end;

      update OPAS_SCHEDULER t set last_validated = systimestamp, t.status = getstatus(scaValidate, t.status) where sch_id=p_sch_id;
    else
      raise_application_error(-20000,'Unable to validate Scheduler configuration('|| p_sch_id ||'). Wrong status');
    end if;
  END validate_config;

  procedure cleanup_config (p_sch_id OPAS_SCHEDULER.SCH_ID%type) AS
  BEGIN
    if check_action(P_SCH_ID => p_sch_id, P_ACTION => scaCleanup) then
      for l_params in (select * from OPAS_SCHEDULER where sch_id=p_sch_id and status in (scsNew,scsValidated,scsSuspended)) loop
        if l_params.job_name is not null then
          for i in (select job_name from user_scheduler_running_jobs where job_name=l_params.job_name) loop
            begin
              DBMS_SCHEDULER.stop_job(l_params.job_name);
            exception
              when others then
                COREMOD_LOG.log('Suspension: Stopping job '||l_params.job_name||' error: '||sqlerrm);
            end;
          end loop;
          DBMS_SCHEDULER.disable(l_params.job_name);
          DBMS_SCHEDULER.drop_job(l_params.job_name);
        end if;
        update OPAS_SCHEDULER t set t.status = getstatus(scaCleanup, t.status) where sch_id=l_params.sch_id;
      end loop;
    else
      raise_application_error(-20000,'Unable to cleanup Scheduler configuration('|| p_sch_id ||'). Wrong status');
    end if;
  END cleanup_config;

  procedure drop_config    (p_sch_id OPAS_SCHEDULER.SCH_ID%type)
  is
  begin
    if check_action(P_SCH_ID => p_sch_id, P_ACTION => scaDrop) then
      delete from OPAS_SCHEDULER where sch_id=p_sch_id;
    else
      raise_application_error(-20000,'Unable to drop Scheduler configuration('|| p_sch_id ||'). Wrong status');
    end if;
  end;
END COREMOD_SCHEDULER;
/


