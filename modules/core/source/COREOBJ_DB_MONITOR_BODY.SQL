

CREATE OR REPLACE
PACKAGE BODY COREOBJ_DB_MONITOR AS

  procedure calc_alerts(p_metric_id   opas_ot_db_monitor_vals_t.METRIC_ID%type,
                        p_metric_tim  opas_ot_db_monitor_vals_t.tim_tz%type, --varchar2, -- TZ is getting lost somehow
                        p_metruc_val  opas_ot_db_monitor_vals_t.VAL%type,
                        p_measur_id   opas_ot_db_monitor_vals_t.measur_id%type)
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

  procedure save_simple_datapoint(p_metric_id   opas_ot_db_monitor_vals_t.METRIC_ID%type,
                                  p_metric_tim  opas_ot_db_monitor_vals_t.tim_tz%type,
                                  p_metruc_val  opas_ot_db_monitor_vals_t.VAL%type)
  is
    l_measur_id opas_ot_db_monitor_vals_t.measur_id%type;
  begin
    INSERT INTO opas_ot_db_monitor_vals_t ( metric_id, tim_tz, val)
         VALUES ( p_metric_id, p_metric_tim, p_metruc_val) returning measur_id into l_measur_id;
    commit;
    calc_alerts(p_metric_id, p_metric_tim, p_metruc_val, l_measur_id);
    commit;
  end;

--EXAPLE
--select rdb_status.get_replication_lag().status from dual;
--declare l_inp INTERVAL DAY TO SECOND :=to_dsinterval(:inp); begin :outp := extract(day from l_inp)*24*60*60 + extract(hour from l_inp)*60*60 + extract(minute from l_inp)*60 + extract(second from l_inp); end;

  procedure execute_simple_metric_i(p_metric_id OPAS_OT_DB_MONITOR.METRIC_ID%type,
                                    p_ts  out opas_ot_db_monitor_vals_t.tim_tz%type, --varchar2, -- TZ is getting lost somehow
                                    p_val out opas_ot_db_monitor_vals_t.VAL%type) AS

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
    l_ts  opas_ot_db_monitor_vals_t.tim_tz%type;
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
      select status||'; at '||to_char(start_date,'HH24:MI') || ' ('||l_dbm.DBLINK||')' into l_status from OPAS_SCHEDULER where sch_id=l_dbm.schedule;
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

  procedure cleanup_chart_data
  is
  begin
    delete from opas_ot_db_chart_lists where created < sysdate-0.5/24;
    commit;
  end;

  procedure prepare_charts_data(p_chart_list      varchar2,
                                p_dt_fmt          varchar2,
                                p_start_dt in out varchar2,
                                p_end_dt   in out varchar2)
  is
    l_tbl DBMS_UTILITY.LNAME_ARRAY;
    l_n   number;
    l_end_dt  timestamp WITH TIME ZONE;
  begin
    delete from opas_ot_db_chart_lists where apex_sess = V('SESSION');
    commit;
    if p_end_dt is null then l_end_dt := systimestamp; p_end_dt := to_char(l_end_dt,p_dt_fmt); end if;
    if p_start_dt is null then p_start_dt := to_char(l_end_dt - TO_DSINTERVAL('1 00:00:00'),p_dt_fmt); end if;

    --coremod_log.log('p_chart_list: '||p_chart_list);

    if p_chart_list is not null then
      DBMS_UTILITY.COMMA_TO_TABLE (
        list   => replace(p_chart_list,':',','),
        tablen => l_n,
        tab    => l_tbl);

      for i in 1..l_n loop
        --coremod_log.log(i||':'||l_tbl(i));
        insert into opas_ot_db_chart_lists
          (apex_sess, created, metric_id, chart_id, chart_name)
        select V('SESSION'), sysdate, metric_id, i, obj_name || ' (' || t.dblink || '), '|| t.measure
          from opas_ot_db_monitor t, v$opas_objects o
         where t.metric_id=o.obj_id and metric_id = to_number(replace(l_tbl(i),'M'));
      end loop;
    end if;
  end;

  procedure init_dashboard_data(p_dt_fmt           varchar2,
                                p_start_dt  in out varchar2,
                                p_end_dt    in out varchar2,
                                p_page_refresh out number)
  is
    l_start_dt  opas_ot_db_dashboard.start_dt%type;
    l_end_dt    opas_ot_db_dashboard.end_dt%type;
    l_dp        opas_ot_db_dashboard%rowtype;
  begin
    --coremod_log.log(p_dt_fmt);
    --coremod_log.log(p_start_dt);
    --coremod_log.log(p_end_dt);
    select * into l_dp from opas_ot_db_dashboard where apex_user = v('APP_USER');
    p_page_refresh:=l_dp.refresh_int;
    if l_dp.data_interv is not null then
      l_end_dt := systimestamp; p_end_dt := to_char(l_end_dt,p_dt_fmt);
      l_start_dt := l_end_dt - l_dp.data_interv; p_start_dt := to_char(l_start_dt, p_dt_fmt);
    else
      if p_end_dt is null then
        l_end_dt := systimestamp; p_end_dt := to_char(l_end_dt,p_dt_fmt);
      else
        l_end_dt := to_timestamp_tz(p_end_dt, p_dt_fmt);
      end if;
      if p_start_dt is null then
        l_start_dt := l_end_dt - TO_DSINTERVAL('1 00:00:00'); p_start_dt := to_char(l_start_dt,p_dt_fmt);
      else
        l_start_dt := to_timestamp_tz(p_start_dt, p_dt_fmt);
      end if;
    end if;

    update opas_ot_db_dashboard
       set start_dt = l_start_dt,
           end_dt = l_end_dt
     where apex_user = v('APP_USER');
  exception
    when no_data_found then
      p_start_dt := null;
      p_end_dt   := null;
      p_page_refresh   := null;
  end;

  procedure save_dachboard_conf(p_graph_num       opas_ot_db_dashboard_graphs.graph_num%type,
                                p_chart_list      varchar2,
                                p_data_interv     opas_ot_db_dashboard.data_interv%type,
                                p_refresh_int     opas_ot_db_dashboard.refresh_int%type)
  is
    l_tbl DBMS_UTILITY.LNAME_ARRAY;
    l_n   number;
  begin
    merge into opas_ot_db_dashboard t
    using (select v('APP_USER') apex_user from dual) s
    on (t.apex_user = s.apex_user)
    when matched then update set
      t.refresh_int = p_refresh_int,
      t.data_interv = p_data_interv,
      t.last_modified = sysdate
    when not matched then insert
      (apex_user, last_modified, refresh_int, data_interv)
    values
      (v('APP_USER'), sysdate, p_refresh_int, p_data_interv);

    delete from opas_ot_db_dashboard_graphs where  apex_user = v('APP_USER') and graph_num = p_graph_num;

    if p_chart_list is not null then
      DBMS_UTILITY.COMMA_TO_TABLE (
        list   => replace(p_chart_list,':',','),
        tablen => l_n,
        tab    => l_tbl);

      for i in 1..l_n loop
        --coremod_log.log(i||':'||l_tbl(i));
        insert into opas_ot_db_dashboard_graphs
          (apex_user, graph_num, metric_id, chart_id, chart_name)
        select v('APP_USER'), p_graph_num, metric_id, i, obj_name || ' (' || t.dblink || '), '|| t.measure
          from opas_ot_db_monitor t, v$opas_objects o
         where t.metric_id=o.obj_id and metric_id = to_number(replace(l_tbl(i),'M'));
      end loop;
    end if;
  end;
END COREOBJ_DB_MONITOR;
/


