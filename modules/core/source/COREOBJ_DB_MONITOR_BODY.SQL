CREATE OR REPLACE
PACKAGE BODY COREOBJ_DB_MONITOR AS

  procedure calc_alerts(p_metric_id   OPAS_OT_DB_MONITOR_VALS.METRIC_ID%type,
                        p_metric_tim  OPAS_OT_DB_MONITOR_VALS.TIM%type, --varchar2, -- TZ is getting lost somehow
                        p_metruc_val  OPAS_OT_DB_MONITOR_VALS.VAL%type,
                        p_measur_id   OPAS_OT_DB_MONITOR_VALS.measur_id%type)
  is
    L_ALERT_ID number;
    l_obj      opas_objects%rowtype;
  begin
    for i in (select c.*,o.obj_name, o.obj_id, m.measure, m.dblink
                from opas_ot_db_monitor_alerts_cfg c, OPAS_OT_DB_MONITOR m,
                     opas_objects o
               where c.metric_id = p_metric_id
                 and c.metric_id=o.obj_id
                 and m.metric_id = c.metric_id
                 and c.limit_actual = 'Y')
    loop
--coremod_tasks.log(i.alert_type||':'||p_metruc_val||':'||i.alert_limit);
      if i.alert_type = 'SINGLELIMIT' then
        if p_metruc_val > i.alert_limit then
          l_obj  := COREOBJ_API.get_obj(i.obj_id);
          COREMOD_ALERTS.add_alert (
            P_ALERT_ID   => L_ALERT_ID,
            P_ALERT_TYPE => 'DB Monitor: '||i.obj_name,
            p_alert_source => i.dblink,
            p_created    => p_metric_tim,
            P_OWNER      => l_obj.obj_owner,
            P_MESSAGE    => 'Limit exceeded. Actual: '||p_metruc_val||' '||i.measure||'; Limit: '||i.ALERT_LIMIT||' '||i.measure||'.',
            P_LINK_PAGE  => 6002,
            P_LINK_PARAM => p_measur_id) ;
        end if;
      end if;
    end loop;
  end;

  procedure save_simple_datapoint(p_metric_id   OPAS_OT_DB_MONITOR_VALS.METRIC_ID%type,
                                  p_metric_tim  OPAS_OT_DB_MONITOR_VALS.TIM%type,
                                  p_metruc_val  OPAS_OT_DB_MONITOR_VALS.VAL%type)
  is
    l_measur_id opas_ot_db_monitor_vals.measur_id%type;
  begin
    INSERT INTO opas_ot_db_monitor_vals ( metric_id, tim, val )
         VALUES ( p_metric_id, p_metric_tim, p_metruc_val) returning measur_id into l_measur_id;
    commit;
    calc_alerts(p_metric_id, p_metric_tim, p_metruc_val, l_measur_id);
    commit;
  end;

--EXAPLE
--select rdb_status.get_replication_lag().status from dual;
--declare l_inp INTERVAL DAY TO SECOND :=to_dsinterval(:inp); begin :outp := extract(day from l_inp)*24*60*60 + extract(hour from l_inp)*60*60 + extract(minute from l_inp)*60 + extract(second from l_inp); end;

  procedure execute_simple_metric_i(p_metric_id OPAS_OT_DB_MONITOR.METRIC_ID%type,
                                    p_ts  out OPAS_OT_DB_MONITOR_VALS.TIM%type, --varchar2, -- TZ is getting lost somehow
                                    p_val out OPAS_OT_DB_MONITOR_VALS.VAL%type) AS

--    l_sql varchar2(16000) := rtrim('select rdb_status.get_replication_lag().status from dual;',';');
--    l_exp varchar2(16000) := 'declare l_inp INTERVAL DAY TO SECOND :=to_dsinterval(:inp); begin :outp := extract(day from l_inp)*24*60*60 + extract(hour from l_inp)*60*60 + extract(minute from l_inp)*60 + extract(second from l_inp); end;';

--    l_sql varchar2(16000) := rtrim('rdb_status.get_replication_lag().status;',';');
--    l_exp varchar2(16000) := 'declare l_inp INTERVAL DAY TO SECOND :=to_dsinterval(:inp); begin :outp := extract(day from l_inp)*24*60*60 + extract(hour from l_inp)*60*60 + extract(minute from l_inp)*60 + extract(second from l_inp); end;';

--    l_sql varchar2(16000) := rtrim(q'[select  value from v$sysstat where name like 'session pga memory';]',';');
--    l_exp varchar2(16000) := 'declare l_inp varchar2(1000) := :inp; begin :outp := to_number(l_inp); end;';

    l_mon   OPAS_OT_DB_MONITOR%rowtype;
    l_sql   varchar2(16000);

    l_out   clob;
    l_ts    varchar2(100);
    l_metr  varchar2(100);

    l_timfmt varchar2(32) := COREMOD_ALERTS.gTSWTZFMT; --'YYYYMMDDHH24MISS.ff6 TZH:TZM';
  BEGIN
    select * into l_mon from OPAS_OT_DB_MONITOR where METRIC_ID = p_metric_id;

    if l_mon.CALL_TYPE = 'SQL' then
      l_sql := replace(rtrim(l_mon.CALC_CODE,';'),'select<m> ',q'[SELECT TO_CHAR(SYSTIMESTAMP,']' || l_timfmt || q'[')||'|'||]');
      l_sql := replace(l_sql,' from<m>',q'[ into l_out FROM]')||';';
    elsif l_mon.CALL_TYPE = 'FUNC' then
      l_sql := replace(q'[l_out:=to_char(systimestamp,']' || l_timfmt || q'[')||'|'||<FUNC>;]','<FUNC>',l_mon.CALC_CODE);
    end if;

    if l_mon.DBLINK <> '$LOCAL$' then
      COREMOD_UTILS.execute_plsql_remotelly(p_sql => l_sql,
                                            p_dblink => l_mon.DBLINK,
                                            p_output => l_out,
                                            p_is_output => true);
    else
      l_sql := 'declare l_out clob; begin '||l_sql||' :out:=l_out; end;';
      execute immediate l_sql using out l_out;
    end if;

    l_ts   := substr(l_out,1,instr(l_out,'|')-1);
    p_ts   := to_timestamp_tz(l_ts, l_timfmt);
    l_metr := substr(l_out,instr(l_out,'|')+1);

    l_sql := l_mon.CONVERT_CODE;
    execute immediate l_sql using l_metr, out p_val;
  exception
    when others then
      rollback;
      coremod_tasks.log('Error COREOBJ_DB_MONITOR.execute_simple_metric ('||p_metric_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      coremod_tasks.log(l_sql);
      raise_application_error(-20000, 'COREOBJ_DB_MONITOR.execute_simple_metric('||p_metric_id||') failed. See logs for more details.');
  END execute_simple_metric_i;

  procedure execute_simple_metric(p_metric_id OPAS_OT_DB_MONITOR.METRIC_ID%type)
  AS
    l_ts  OPAS_OT_DB_MONITOR_VALS.TIM%type;
    l_val number;
    ex_no_connection exception;
    pragma exception_init(ex_no_connection,-12154); --ORA-12154
  BEGIN
    execute_simple_metric_i(p_metric_id, l_ts, l_val);
    save_simple_datapoint(p_metric_id,l_ts,l_val);
    commit;
  exception
    when ex_no_connection then
      coremod_tasks.log('COREOBJ_DB_MONITOR.execute_simple_metric('||p_metric_id||'); '||sqlerrm);
  END execute_simple_metric;

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type)
  is
  begin
    COREOBJ_API.add (  P_OBJ_ID => p_obj_id,
      P_OBJ_PRNT  => p_obj_prnt,
      P_OBJ_OT    => COREOBJ_API.otSIMPLE_DB_MONITOR,
      P_OBJ_NAME  => 'Simple DB Monitor '||to_char(sysdate,'YYYYMMDD'),
      P_OBJ_DESCR => null);

    INSERT INTO opas_ot_db_monitor
            ( metric_id, dblink, schedule, call_type, calc_code, convert_code, measure)
     VALUES ( p_obj_id,  null,   null,     'SQL',     'select<m> 1 from<m> dual', 'declare l_inp varchar2(1000) := :inp; begin :outp := to_number(l_inp); end;', 'parrots');
  end;

  procedure edit  (p_obj_id           opas_objects.obj_id%type,
                   p_dblink           OPAS_OT_DB_MONITOR.dblink%type,
                   p_call_type        OPAS_OT_DB_MONITOR.call_type%type,
                   p_calc_code        OPAS_OT_DB_MONITOR.calc_code%type,
                   p_convert_code     OPAS_OT_DB_MONITOR.convert_code%type,
                   p_measure          OPAS_OT_DB_MONITOR.measure%type)
  is
  begin
    update opas_ot_db_monitor
       set dblink = p_dblink,
           call_type = p_call_type,
           calc_code = p_calc_code,
           convert_code = p_convert_code,
           measure = p_measure
     where metric_id = p_obj_id;
  end;

  procedure get_schedule  (p_obj_id   opas_objects.obj_id%type,
                           p_schedule out OPAS_OT_DB_MONITOR.schedule%type)
  is
    l_obj  opas_objects%rowtype := COREOBJ_API.get_obj(p_obj_id);
  begin
    COREMOD_SCHEDULER.inis_scheduler (
      P_SCH_ID     => p_schedule,
      P_SCHEDULE   => 'freq=daily; interval=1',
      P_START_DATE => trunc(sysdate,'hh')+1/24,
      P_PLSQL_CALL => 'begin COREOBJ_DB_MONITOR.execute_simple_metric('||p_obj_id||'); end;',
      P_OWNER      => l_obj.obj_owner);

    update opas_ot_db_monitor
       set schedule = p_schedule
     where metric_id = p_obj_id;
  end;

  function test_metric(p_metric_id OPAS_OT_DB_MONITOR.METRIC_ID%type) return number
  is
    l_ts  timestamp;
    l_val number;
  BEGIN
    execute_simple_metric_i(p_metric_id, l_ts, l_val);
    return l_val;
  end;

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
    l_dbm OPAS_OT_DB_MONITOR%rowtype;
    l_status varchar2(32);
  begin
    select * into l_dbm from OPAS_OT_DB_MONITOR where metric_id = p_obj_id;

    if l_dbm.schedule is null then
      l_status := 'No schedule';
    else
      select status into l_status from OPAS_SCHEDULER where sch_id=l_dbm.schedule;
    end if;

    return l_status;
  end;

  procedure drop_metric(p_metric_id OPAS_OT_DB_MONITOR.METRIC_ID%type)
  is
    l_mon   OPAS_OT_DB_MONITOR%rowtype;
  BEGIN
    select * into l_mon from OPAS_OT_DB_MONITOR where METRIC_ID = p_metric_id;
    if l_mon.SCHEDULE is not null then
      COREMOD_SCHEDULER.suspend_config (  P_SCH_ID => l_mon.SCHEDULE);
      COREMOD_SCHEDULER.cleanup_config (  P_SCH_ID => l_mon.SCHEDULE);
      COREMOD_SCHEDULER.drop_config    (  P_SCH_ID => l_mon.SCHEDULE);
    end if;
    delete from OPAS_OT_DB_MONITOR where METRIC_ID = p_metric_id;
  end;

  procedure remove  (p_obj_id    opas_objects.obj_id%type,
                     p_cascade   varchar2 default 'N')
  is
  begin
    drop_metric(p_obj_id);
    COREOBJ_API.remove(p_obj_id);
  end;

  procedure add_alert_limit(p_metric_id   opas_ot_db_monitor_alerts_cfg.metric_id%type,
                            p_alert_type  opas_ot_db_monitor_alerts_cfg.alert_type%type,
                            p_alert_limit  opas_ot_db_monitor_alerts_cfg.alert_limit%type)
  is
    l_ts timestamp := systimestamp;
  begin
    for i in (select x.rowid from opas_ot_db_monitor_alerts_cfg x where metric_id = p_metric_id and alert_type = p_alert_type and limit_actual = 'Y' and decode(alert_limit,p_alert_limit,1,0)=0)
    loop
      update opas_ot_db_monitor_alerts_cfg set limit_actual='N', actual_end = l_ts where rowid=i.rowid;
    end loop;

    merge into opas_ot_db_monitor_alerts_cfg t
    using (select p_metric_id metric_id, p_alert_type alert_type, p_alert_limit alert_limit from dual) s
    on (t.metric_id = s.metric_id and t.alert_type = s.alert_type and t.limit_actual = 'Y')
    when not matched then insert ( t.metric_id, t.alert_type, t.alert_limit, t.limit_actual, t.actual_start)
      VALUES (s.metric_id, s.alert_type, s.alert_limit, 'Y', l_ts);
  end;

  procedure drop_alert_limit(p_metric_id   opas_ot_db_monitor_alerts_cfg.metric_id%type/*,
                             p_alert_type  opas_ot_db_monitor_alerts_cfg.alert_type%type*/)
  is
  begin
    --delete from OPAS_OT_DB_MONITOR_ALERTS_CFG where metric_id = p_metric_id;
    update opas_ot_db_monitor_alerts_cfg set limit_actual='N', actual_end = systimestamp where metric_id = p_metric_id;
  end;

END COREOBJ_DB_MONITOR;
/
