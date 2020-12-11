

CREATE OR REPLACE
PACKAGE BODY COREOBJ_ASHA_CUBE_CALCS AS

  gJSParams             COREOBJ_API.t_params;
  gTABParams            COREOBJ_API.t_params;

  type tab_tq_id      is table of  OPAS_TASK_QUEUE.tq_id%type;
  g_tq_id_tab           tab_tq_id := tab_tq_id();
  g_tq_name_tab         TABLEOFSTRINGS := TABLEOFSTRINGS();

  gGranulaSize          number := 15; -- minutes, must devide 60 in a round number

  gASH_Available        varchar2(1) := 'N';

  gTargetTZ             varchar2(10);
  gTargetIncarnation    number;
  gTargetDBID           number;
  gTargetCurrTS_TZ      timestamp with time zone;
  gTargetCurrTS         timestamp;
  gTargetCurrTS_UTC     timestamp;
  gTargetSNAP_START     number;
  gTargetSNAP_END       number;

  gLogLevel             varchar2(100):='INFO';
  gLogLevelInfo         varchar2(100):='INFO';

    cursor crsr_granules (pc_obj_id  opas_objects.obj_id%type,
                          pc_dblink  OPAS_DB_LINKS.DB_LINK_NAME%type,
                          --pc_min_ash date,
                          pc_curr_dt date,
                          pc_create_ranges number default 0)
    is
    with input_pars as (
            select START_TIME_UTC,
                   END_TIME_UTC,
                   --pc_min_ash min_ash,
                   pc_curr_dt curr_dt
              from opas_ot_ashacube where ashacube_id = pc_obj_id and START_TIME_UTC is not null and END_TIME_UTC is not null and START_TIME_UTC < END_TIME_UTC),
          adj_input_pars as
           (select --min_ash,
                   curr_dt,
                   trunc(START_TIME_UTC, 'hh') +
                   floor(24 * 60 * (trunc(START_TIME_UTC,'MI') - trunc(START_TIME_UTC, 'hh')) / gGranulaSize) * gGranulaSize / 24 / 60 real_start_date,
                   trunc(END_TIME_UTC, 'hh') +
                   ceil(24 * 60 * (trunc(END_TIME_UTC,'MI') - trunc(END_TIME_UTC, 'hh')) / gGranulaSize) * gGranulaSize / 24 / 60 real_end_date--,
                   --START_TIME_UTC, END_TIME_UTC
              from input_pars),
          dt_boundaries0 as
           (select level rn,
                   --min_ash,
                   curr_dt,
                   real_start_date + (level-1) /(24*round(60/gGranulaSize)) start_granula_dt,
                   real_start_date + (level) /(24*round(60/gGranulaSize)) end_granula_dt
              from dual, adj_input_pars
            connect by level <= ((real_end_date - real_start_date) * 24 * round(60/gGranulaSize))),
          dt_boundaries as
            (
             select x1.*,
                    (select listagg(inst_id, ',')within group (order by inst_id) from opas_ot_tmp_gv$ash_info where oldest_sample_time_utc between start_granula_dt and end_granula_dt) eof_ash_nodes,
                    (select min(oldest_sample_time_utc) from opas_ot_tmp_gv$ash_info where oldest_sample_time_utc between start_granula_dt and end_granula_dt) min_ash,
                    (select min(oldest_sample_time_utc) from opas_ot_tmp_gv$ash_info) min_min_ash,
                    (select max(oldest_sample_time_utc) from opas_ot_tmp_gv$ash_info) max_min_ash
               from dt_boundaries0 x1 )
             select case
                    --when b.min_ash between b.start_granula_dt and b.end_granula_dt then -1e6
                    when eof_ash_nodes is not null then -1e6
                    when b.max_min_ash < b.start_granula_dt and b.curr_dt > b.end_granula_dt then -1e6 + b.rn
                    when b.curr_dt < b.start_granula_dt then 1e9 + b.rn
                    else b.rn end ordr,
                    'V' granula_type, b.eof_ash_nodes, b.min_ash, b.min_min_ash, b.max_min_ash, b.rn,
                    b.start_granula_dt, b.end_granula_dt,
                    rng.*, rf.ashacube_id
               from opas_ot_ashacube_ref rf,
                    OPAS_OT_ASHACUBE_RANGES    rng,
                    dt_boundaries              b
              where b.start_granula_dt = rng.START_TIME_UTC(+)
                and b.end_granula_dt = rng.END_TIME_UTC(+)
                and rng.ASHARANGE_ID = rf.ASHARANGE_ID(+)
                and rng.DBLINK(+) = pc_dblink
                and (b.min_min_ash <= b.start_granula_dt or b.start_granula_dt < b.min_min_ash and b.min_min_ash <= b.end_granula_dt)
              union all
             select 1e6 + b.rn ordr,
                    'A' granula_type, b.eof_ash_nodes, b.min_ash, b.min_min_ash, b.max_min_ash, b.rn,
                    b.start_granula_dt, nvl(b.min_ash, b.end_granula_dt),
                    rng.*, rf.ashacube_id
               from opas_ot_ashacube_ref rf,
                    OPAS_OT_ASHACUBE_RANGES    rng,
                    dt_boundaries              b
              where b.start_granula_dt = rng.START_TIME_UTC(+)
                and b.end_granula_dt = rng.END_TIME_UTC(+)
                and rng.ASHARANGE_ID = rf.ASHARANGE_ID(+)
                and rng.DBLINK(+) = pc_dblink
                and (b.end_granula_dt <= b.min_min_ash or pc_create_ranges = 0 /*and b.start_granula_dt <= b.max_min_ash*/ and b.start_granula_dt <= b.max_min_ash)
              order by ordr, start_granula_dt desc;

    type t_granules is table of crsr_granules%rowtype;

  procedure llog(p_message varchar2, p_level varchar2 default gLogLevel)
  is
  begin
    coremod_log.log(p_message, p_level, 'ASHA_CUBE_CALCS');
  end;

  procedure set_lock(p_dblink opas_db_links.db_link_name%type)
  is
  begin
    COREMOD_API.lock_resource (
      P_RESOURCE_NAME => 'OPASASHACUBESETRANGE'||p_dblink,
      P_MODE => DBMS_LOCK.X_MODE,
      P_TIMEOUT => 180,
      P_RELEASE_ON_COMMIT => false) ;
  end;

  procedure load_params(p_obj_id  opas_objects.obj_id%type)
  is
  begin
    gJSParams.delete;
    gJSParams := coreobj_api.get_all_jparam(p_obj_id => p_obj_id);

    if not gJSParams.exists(pDTFMT) then
      gJSParams(pDTFMT) := 'YYYY-MM-DD HH24:MI';
    end if;

    select
      dblink, to_char(START_TIME_UTC, gJSParams(pDTFMT)), to_char(END_TIME_UTC, gJSParams(pDTFMT))
    into
      gTABParams(pDBLINK), gTABParams(pSTARTDT), gTABParams(pENDDT)
    from opas_ot_ashacube where ashacube_id = p_obj_id;
  end;

  procedure store_params(p_obj_id  opas_objects.obj_id%type)
  is
    l_name varchar2(1000);
  begin
    COREOBJ_API.extract_jparams(p_obj_id);

    l_name := gJSParams.first;
    loop
      exit when l_name is null;
      COREOBJ_API.add_jparam (  P_OBJ_ID => store_params.P_OBJ_ID,
        P_PNAME => l_name,
        P_VALUE => gJSParams(l_name));
      l_name := gJSParams.next(l_name);
    end loop;

    COREOBJ_API.store_jparams(p_obj_id);

    update opas_ot_ashacube
    set dblink = gTABParams(pDBLINK),
        START_TIME_UTC = to_timestamp(gTABParams(pSTARTDT), gJSParams(pDTFMT)),
        END_TIME_UTC = to_timestamp(gTABParams(pENDDT), gJSParams(pDTFMT))
    where ashacube_id = p_obj_id;

  end;

  procedure store_tasks(p_obj_id  opas_objects.obj_id%type)
  is
    pragma autonomous_transaction;
  begin
    APEX_JSON.initialize_clob_output;
    APEX_JSON.open_object;

    APEX_JSON.open_array('tasks');
    for i in 1..g_tq_id_tab.count loop
      --APEX_JSON.write(g_tq_id_tab(i));
      APEX_JSON.open_object;
      APEX_JSON.write('tq_id',   g_tq_id_tab(i));
      APEX_JSON.write('tq_name', g_tq_name_tab(i));
      APEX_JSON.close_object;
    end loop;
    --APEX_JSON.write(COREMOD_TASKS.get_curr_tq_id());
    APEX_JSON.open_object;
    APEX_JSON.write('tq_id', COREMOD_TASKS.get_curr_tq_id());
    APEX_JSON.write('tq_name', 'Main Task');
    APEX_JSON.close_object;
    APEX_JSON.close_array;
    APEX_JSON.close_object;

    COREOBJ_API.set_jparam(p_obj_id => p_obj_id,
                           p_pname =>  'ASHACUBE_TQLIST',
                           p_json =>   APEX_JSON.get_clob_output);

    APEX_JSON.free_output;
    commit;
  end;

  procedure cancel_all_jobs(p_obj_id  opas_objects.obj_id%type)
  is
  begin
    for i in (
      SELECT tasks.value
        FROM OPAS_OBJECT_PARS,
             json_table(jsparams, '$.tasks[*]' COLUMNS (value PATH '$')) tasks
       where obj_id=p_obj_id and par_name='ASHACUBE_TQLIST')
    loop
      coremod_tasks.stop_task (  P_TQ_ID => i.value) ;
    end loop;

    COREOBJ_API.remove_param(p_obj_id, 'ASHACUBE_TQLIST');
  end;

  function gp(p_name varchar2) return varchar2
  is
    PRAGMA UDF;
  begin
    if upper(p_name) in (pDBLINK, pSTARTDT, pENDDT) then
      if gTABParams.exists(upper(p_name))
      then
        return gTABParams(upper(p_name));
      else
        return null;
      end if;
    else
      if gJSParams.exists(upper(p_name))
      then
        return gJSParams(upper(p_name));
      else
        return null;
      end if;
    end if;
  end;

  procedure setp(p_name varchar2, p_value varchar2)
  is
  begin
    if upper(p_name) in (pDBLINK, pSTARTDT, pENDDT) then
      gTABParams(upper(p_name)) := p_value;
    else
      gJSParams(upper(p_name)) := p_value;
    end if;
  end;

  procedure log_ash_info
  is
  begin
    if gLogLevel = COREMOD_API.getconf('LOGGING_LEVEL',COREMOD_API.gMODNAME) then
      llog('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: opas_ot_tmp_gv$ash_info');
      for i in (select * from opas_ot_tmp_gv$ash_info) loop
        llog('Node '||i.inst_id||': '||to_char(i.oldest_sample_time,'YYYY-MM-DD HH24:MI:SS')||': '||to_char(i.oldest_sample_time_utc,'YYYY-MM-DD HH24:MI:SS'));
      end loop;
    end if;
  end;

  procedure init_ash_info(p_dblink opas_db_links.db_link_name%type)
  is
    l_sql  varchar2(1000);
  begin
    delete from opas_ot_tmp_gv$ash_info; --+ INTERVAL '30' SECOND
    l_sql :=  q'[INSERT INTO opas_ot_tmp_gv$ash_info (inst_id, oldest_sample_time) select inst_id, oldest_sample_time  from GV$ASH_INFO]' || COREMOD_API.get_dblink_for_query(p_dblink) || ' where oldest_sample_time is not null';
    execute immediate l_sql;
    gASH_Available := case when sql%rowcount>0 then 'Y' else 'N' end;
    if gASH_Available = 'Y' then
      update opas_ot_tmp_gv$ash_info
         set oldest_sample_time_utc = sys_extract_utc(to_timestamp_tz(to_char(oldest_sample_time,'YYYYMMDDHH24MISS')|| ' ' || gTargetTZ ,'YYYYMMDDHH24MISS TZH:TZM'));
    end if;
    log_ash_info;
  end;

  procedure get_remote_data(p_dblink opas_db_links.db_link_name%type)
  is
    l_sql  varchar2(1000);
  begin
    l_sql := --RAC!!!
      q'[select extract(TIMEZONE_HOUR from systimestamp)||':'||extract(TIMEZONE_MINUTE from systimestamp),]' ||
      q'[(select incarnation# from v$database_incarnation]' || COREMOD_API.get_dblink_for_query(p_dblink) || q'[ where status='CURRENT']'
      || q'[), systimestamp, cast(systimestamp as timestamp), sys_extract_utc(systimestamp) from dual]'||COREMOD_API.get_dblink_for_query(p_dblink);

    execute immediate l_sql into gTargetTZ, /*gTargetMinASHTS,*/ gTargetIncarnation, gTargetCurrTS_TZ, gTargetCurrTS, gTargetCurrTS_UTC;

    init_ash_info(p_dblink);
  end;

  procedure get_remote_curr_ts(p_dblink opas_db_links.db_link_name%type)
  is
    l_sql  varchar2(1000);
  begin
    l_sql := q'[select cast(systimestamp as timestamp), sys_extract_utc(systimestamp) from dual]'||COREMOD_API.get_dblink_for_query(p_dblink);
    execute immediate l_sql into gTargetCurrTS, gTargetCurrTS_UTC;
  end;

  function get_remote_ts_utc(p_dblink opas_db_links.db_link_name%type) return timestamp
  is
  begin
    get_remote_curr_ts(p_dblink);
    return gTargetCurrTS_UTC;
  end;

  procedure get_remote_awr_snaps(p_dblink opas_db_links.db_link_name%type,
                                 p_start_dt timestamp,
                                 p_end_dt timestamp)
  is
    l_sql_get_snaps varchar2(4000)
      := q'[select min(snap_id) min_snap, max(snap_id) max_snap from dba_hist_snapshot<DBLINK> where dbid = ]' ||
      gTargetDBID || q'[ and begin_interval_time + INTERVAL '125' MINUTE >= :p1 and end_interval_time - INTERVAL '125' MINUTE <= :p2 ]';
  begin
    llog('COREOBJ_ASHA_CUBE_CALCS.get_remote_awr_snaps: p_start_dt "'|| to_char(p_start_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.get_remote_awr_snaps: p_end_dt "'|| to_char(p_end_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');
    execute immediate replace(l_sql_get_snaps,'<DBLINK>',COREMOD_API.get_dblink_for_query(p_dblink)) into gTargetSNAP_START, gTargetSNAP_END using p_start_dt, p_end_dt;
    llog('COREOBJ_ASHA_CUBE_CALCS.get_remote_awr_snaps: gTargetSNAP_START, gTargetSNAP_END "'||gTargetSNAP_START ||'", "'||gTargetSNAP_END||'"');
  end;

  function show_remote_date_context(p_dblink opas_db_links.db_link_name%type) return varchar2
  is
    l_min_ashs varchar2(4000);
  begin
    get_remote_data(p_dblink);
    commit;
    --llog('COREOBJ_ASHA_CUBE_CALCS.show_remote_date_context: gTargetCurrTS_TZ "'|| to_char(gTargetCurrTS_TZ,'YYYY-MM-DD HH24:MI:SS.FF3 TZH:TZM') ||'"');
    --llog('COREOBJ_ASHA_CUBE_CALCS.show_remote_date_context: gTargetMinASHTS "'|| to_char(gTargetMinASHTS,'YYYY-MM-DD HH24:MI:SS') ||'"');
    execute immediate 'ALTER SESSION CLOSE DATABASE LINK '||p_dblink;

    select listagg('Node '||inst_id||': '||to_char(oldest_sample_time_utc,'YYYY-MM-DD HH24:MI:SS'), '; ')within group (order by inst_id)
    into l_min_ashs
    from opas_ot_tmp_gv$ash_info;

    return 'Target database time: current in target time zone: <b>'||to_char(gTargetCurrTS_TZ,'YYYY-MM-DD HH24:MI:SS TZH:TZM') || '</b>; current time UTC: <b>' || to_char(gTargetCurrTS_UTC,'YYYY-MM-DD HH24:MI:SS') || '</b>'||
      case when l_min_ashs is not null then '; Oldest V$ASH data UTC: <b>' || l_min_ashs || /* || gTargetTZ ||*/ '</b>'
           else '; No V$ASH available' end;
  exception
    when others then return 'Error for "'||p_dblink|| '": '||sqlerrm||'; '||DBMS_UTILITY.FORMAT_ERROR_STACK;
  end;

  procedure init_execution_context(p_obj_id  opas_objects.obj_id%type)
  is
  begin

    gTargetTZ         := null;
    gTargetIncarnation:= null;
    gTargetDBID       := null;
    gTargetCurrTS_TZ  := null;
    gTargetCurrTS     := null;  gTargetCurrTS_UTC := null;

    gTargetSNAP_START := null;
    gTargetSNAP_END   := null;

    load_params(p_obj_id);
    get_remote_data(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));

    select dbid into gTargetDBID from OPAS_DB_LINKS where DB_LINK_NAME = COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK);

    llog('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetTZ "'||gTargetTZ||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetCurrTS_TZ "'||to_char(gTargetCurrTS_TZ,'YYYY-MM-DD HH24:MI:SS.FF3 TZH:TZM')||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetCurrTS "'||to_char(gTargetCurrTS,'YYYY-MM-DD HH24:MI:SS.FF3')||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetCurrTS_UTC "'||to_char(gTargetCurrTS_UTC,'YYYY-MM-DD HH24:MI:SS.FF3')||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetIncarnation "'||gTargetIncarnation||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetDBID "'||gTargetDBID||'"');
  end;

  procedure set_range_status(p_asharange_id opas_ot_ashacube_ranges.asharange_id%type,
                             p_status_old varchar2,
                             p_status_new varchar2,
                             p_tq_id opas_ot_ashacube_ranges.tq_id%type)
  is
    pragma autonomous_transaction;
  begin
    if p_tq_id is null then
      raise_application_error(-20000,'set_range_status: TQ_ID must be specified');
    end if;

    if p_status_old = csNEW and p_status_new = csInQueue then
      update opas_ot_ashacube_ranges
         set status = p_status_new,
             MODIFIED = systimestamp,
             tq_id = nvl(p_tq_id, tq_id)
       where asharange_id = p_asharange_id and status = p_status_old;
    else
      update opas_ot_ashacube_ranges
         set status = p_status_new,
             MODIFIED = systimestamp
       where asharange_id = p_asharange_id and status = p_status_old and tq_id = p_tq_id;
    end if;
    llog('COREOBJ_ASHA_CUBE_CALCS.set_range_status: p_asharange_id -> p_status_new "'|| p_asharange_id ||' -> '|| p_status_new ||'" rows: '|| sql%rowcount ||'; TQ=>'||p_tq_id);
    --update OPAS_OT_ASHACUBE_METRICS_LIST set METRIC_STATUS = p_status_new where asharange_id = p_asharange_id;
    commit;
  end;

  procedure set_cube_preserve(p_obj_id  opas_objects.obj_id%type, p_preserve boolean default true)
  is
    l_preserve varchar2(1) := case when p_preserve then 'Y' else 'N' end;
  begin
    update opas_ot_ashacube_ranges set PRESERVE_POLICY = l_preserve
     where ASHARANGE_ID in (select ASHARANGE_ID from OPAS_OT_ASHACUBE_REF where ASHACUBE_ID = p_obj_id)
       and STATUS in (csReady);
  end;

  procedure set_range_preserve(p_asharange_id opas_ot_ashacube_ranges.asharange_id%type, p_preserve boolean default true)
  is
    l_preserve varchar2(1) := case when p_preserve then 'Y' else 'N' end;
  begin
    update opas_ot_ashacube_ranges set PRESERVE_POLICY = l_preserve
     where ASHARANGE_ID = p_asharange_id
       and STATUS in (csReady);
  end;

  function from_utc_to_target_tz(p_ts_utc timestamp, p_tzhtzm varchar2 default gTargetTZ) return timestamp
  is
    l_trg_tz timestamp;
  begin
    execute immediate q'[select cast(to_timestamp_tz(']' || to_char(p_ts_utc,'YYYYMMDDHH24MISS')||' 00:00' || q'[','YYYYMMDDHH24MISS TZH:TZM') at time zone ']' ||p_tzhtzm|| q'[' as timestamp) from dual]'
                into l_trg_tz;
    return l_trg_tz;
  end;

  procedure load_metrics(p_asharange_id opas_ot_ashacube_ranges.asharange_id%type,
                         p_start_dt timestamp,
                         p_end_dt timestamp,
                         p_rows  in out number)
  is
    l_sql_ml     varchar2(32765);
    l_sql_gm     varchar2(32765);
    l_metric_flt varchar2(32765);
    l_sql        varchar2(32765);
    l_rows       number := 0;
    procedure set_metric_status(p_asharange_id  opas_ot_ashacube_ranges.asharange_id%type,
                                p_group_id      OPAS_OT_ASHACUBE_METRICS_LIST.group_id%type,
                                p_metric_id     OPAS_OT_ASHACUBE_METRICS_LIST.metric_id%type,
                                p_status_old    varchar2,
                                p_status_new    varchar2)
    is
      pragma autonomous_transaction;
    begin
      if p_group_id is null and p_metric_id is null then
        update OPAS_OT_ASHACUBE_METRICS_LIST set METRIC_STATUS = p_status_new where asharange_id = p_asharange_id and METRIC_STATUS = p_status_old;
      else
        update OPAS_OT_ASHACUBE_METRICS_LIST set METRIC_STATUS = p_status_new where asharange_id = p_asharange_id and group_id = p_group_id and metric_id = p_metric_id and METRIC_STATUS = p_status_old;
      end if;
      commit;
    end;
  begin
    llog('COREOBJ_ASHA_CUBE_CALCS.load_metrics('|| p_asharange_id ||'): p_start_dt "'|| to_char(p_start_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.load_metrics('|| p_asharange_id ||'): p_end_dt "'|| to_char(p_end_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');

    set_metric_status(p_asharange_id, null, null, csNEW, csInProgress);

--    l_sql_ml := q'[select '('||listagg('(group_id='||group_id||' and metric_id='||metric_id||')', ' or ')within group(order by metric_id, group_id)||')' flt from OPAS_DB_METRICS where rowid in ('<ROWIDS>')]';
--    l_sql_ml := replace(l_sql_ml,'<ROWIDS>',replace(COREOBJ_ASHA_CUBE_CALCS.gp(pMetricList),':',q'[',']'));
    --llog('COREOBJ_ASHA_CUBE_CALCS.load_metrics('|| p_asharange_id ||'): metric list sql: '||chr(10)||l_sql_ml);
--    execute immediate l_sql_ml into l_metric_flt;
    begin
      select listagg('(group_id='||group_id||' and metric_id='||metric_id||')', ' or ')within group(order by metric_id, group_id)
        into l_metric_flt
        from OPAS_OT_ASHACUBE_METRICS_LIST where ASHARANGE_ID = p_asharange_id and METRIC_STATUS = csInProgress;
    exception
      when no_data_found then l_metric_flt := null;
    end;

    --llog('COREOBJ_ASHA_CUBE_CALCS.load_metrics('|| p_asharange_id ||'): l_metric_flt: "'||l_metric_flt||'"');

    if l_metric_flt is not null then
      l_sql_gm := q'[insert into opas_ot_ashacube_metrics (asharange_id, dblink, inst_id, begin_time_utc, end_time_utc, group_id, metric_id, value)
      select
        :p_asharange_id, :pDBLINK, inst_id, SYS_EXTRACT_UTC(from_tz(cast(begin_time as timestamp),:gTargetTZ)), SYS_EXTRACT_UTC(from_tz(cast(end_time as timestamp),:gTargetTZ)), group_id, metric_id, value
      from (
        select inst_id, begin_time, end_time, group_id, metric_id, value from gv$sysmetric_history<DBLINK> where (<GROUPMETRIC>) and <DTFLT>
        union
        select instance_number, begin_time, end_time, group_id, metric_id, value from dba_hist_sysmetric_history<DBLINK> where (<GROUPMETRIC>) and <DTFLT>
        and dbid=:p_dbid and snap_id between :pstart and :pend and instance_number > 0)]';

      l_sql_gm := replace(replace(l_sql_gm,'<GROUPMETRIC>',l_metric_flt),'<DBLINK>',COREMOD_API.get_dblink_for_query(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK)));


      l_sql := replace(l_sql_gm,'<DTFLT>',q'[end_time >= to_date(']' || to_char(p_start_dt,'YYYYMMDDHH24MISS') || q'[','YYYYMMDDHH24MISS') and end_time < to_date(']' || to_char(p_end_dt,'YYYYMMDDHH24MISS') || q'[','YYYYMMDDHH24MISS')]');

      --llog('COREOBJ_ASHA_CUBE_CALCS.load_metrics('|| p_asharange_id ||'): metric sql: '||chr(10)||l_sql);
      execute immediate l_sql using p_asharange_id, COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK), gTargetTZ, gTargetTZ, gTargetDBID, gTargetSNAP_START, gTargetSNAP_END;
      p_rows := p_rows + sql%rowcount;

      for i in (select ASHARANGE_ID, l.GROUP_ID, l.METRIC_ID,
                       (select count(1) from OPAS_OT_ASHACUBE_METRICS m
                         where l.ASHARANGE_ID = m.ASHARANGE_ID
                           and l.METRIC_ID = m.METRIC_ID
                           and l.GROUP_ID = m.GROUP_ID
                           and rownum=1) cnt
                  from OPAS_OT_ASHACUBE_METRICS_LIST l where ASHARANGE_ID = p_asharange_id and METRIC_STATUS = csInProgress)
      loop
        set_metric_status(p_asharange_id, i.GROUP_ID, i.METRIC_ID, csInProgress, case when i.cnt > 0 then csReady else csEmpty end);
      end loop;
    end if;

    llog('COREOBJ_ASHA_CUBE_CALCS.load_metrics('|| p_asharange_id ||'): metrics added: '||p_rows);
  end;

  procedure get_granule(p_granula crsr_granules%rowtype,
                        p_current_range   boolean)
  is
    p_asharange_id    opas_ot_ashacube_ranges.asharange_id%type;

    l_range opas_ot_ashacube_ranges%rowtype;
    l_old_status     OPAS_OT_ASHACUBE_RANGES.STATUS%type;

    l_unable_to_lock exception;
    l_rows number := 0;
    l_current_range boolean := p_current_range;

    --targte TZ
    l_start_dt       timestamp;
    l_start_range_dt timestamp;
    l_end_dt         timestamp;
    l_end_range_dt   timestamp;

    l_awr_filter     varchar2(4000);
  begin
    p_asharange_id := p_granula.asharange_id;
    llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): Begin.', gLogLevelInfo);
    llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): p_granula "'|| p_granula.granula_type ||'"', gLogLevelInfo);
    llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): p_current_range "'|| COREMOD_UTILS.bool2str(p_current_range) ||'"', gLogLevelInfo);

    if p_current_range and p_granula.granula_type <> gtGV$ASH then
      raise_application_error(-20000, 'COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): p_type must be "'||gtGV$ASH||'" for current range');
    end if;

    select * into l_range from opas_ot_ashacube_ranges where asharange_id = p_asharange_id;

    l_start_dt := from_utc_to_target_tz(p_granula.START_TIME_UTC);
    l_start_range_dt := l_start_dt;
    l_end_dt   :=from_utc_to_target_tz(p_granula.END_TIME_UTC);
    l_end_range_dt := l_end_dt;

    llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): l_start_range_dt "'|| to_char(l_start_range_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): l_end_range_dt "'|| to_char(l_end_range_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');

    if l_range.status in (csReady,csEmpty) and l_range.SAMPLE_TP = gtGV$ASH and p_granula.granula_type = gtDBA_HIST_ASH then
      l_old_status := l_range.status;
      set_range_status(p_asharange_id, l_range.status, csNEW, COREMOD_TASKS.get_curr_tq_id);
      llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): Set status to NEW for adding AWR');
    end if;

    set_range_status(p_asharange_id, csNEW, csInQueue, COREMOD_TASKS.get_curr_tq_id);
    set_range_status(p_asharange_id, csInQueue, csInProgress, COREMOD_TASKS.get_curr_tq_id);

    begin
      select * into l_range from opas_ot_ashacube_ranges where asharange_id = p_asharange_id and status = csInProgress for update skip locked;
    exception
      when no_data_found then
        raise l_unable_to_lock;
    end;


    get_remote_awr_snaps(p_dblink => COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK),
                         p_start_dt => l_start_dt,
                         p_end_dt => l_end_dt);

    if p_current_range then
      get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));
      l_end_dt := gTargetCurrTS;
    end if;

    loop
      llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): start cycle l_start_dt "'|| to_char(l_start_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');
      llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): start cycle l_end_dt "'|| to_char(l_end_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');
        delete from OPAS_OT_TMP_GV$ASH;

        case p_granula.granula_type
          when gtGV$ASH then
            begin
              llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): V$ASH start');
                COREMOD_API.load_tmp_data (
                  P_DB_LINK_NAME => COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK),
                  P_SRC_TABLE_NAME_R => 'GV_$ACTIVE_SESSION_HISTORY',
                  P_SRC_TABLE_NAME => 'GV$ACTIVE_SESSION_HISTORY',
                  P_TRG_TABLE_NAME => 'OPAS_OT_TMP_GV$ASH',
                  P_SUFF => 'GV$ASH',
                  p_key_pref => 'LOCTABCOLS',
                  --P_DBID => null,
                  P_FILTER => q'[sample_time between to_timestamp(']' || to_char(l_start_dt,'YYYYMMDDHH24MISS') || q'[','YYYYMMDDHH24MISS') and to_timestamp(']' || to_char(l_end_dt,'YYYYMMDDHH24MISS') || q'[','YYYYMMDDHH24MISS')]'
                  );
   -- llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): 1 l_start_dt "'|| to_char(l_start_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');
   -- llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): 1 l_end_dt "'|| to_char(l_end_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');
              update OPAS_OT_ASHACUBE_RANGES set
                     SAMPLE_TP = case when SAMPLE_TP = gtDBA_HIST_ASH then gtGV$ASHAWR else gtGV$ASH end,
                     MODIFIED = systimestamp
               where ASHARANGE_ID = p_asharange_id;
              llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): V$ASH finish: '||COREMOD_API.get_last_rowcount|| ' loaded. ', gLogLevelInfo);

              if p_granula.min_ash is not null then
                llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): V$ASH p_granula.min_ash correction: '||to_char(p_granula.min_ash,'YYYY/MM/DD HH24:MI:SS'), gLogLevelInfo);
                log_ash_info;
                update opas_ot_tmp_gv$ash_info o set oldest_sample_time = (select min(sample_time) from OPAS_OT_TMP_GV$ASH i where o.inst_id=i.inst_id)
                  where oldest_sample_time between l_start_dt and l_end_dt;
                llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): updated opas_ot_tmp_gv$ash_info : '||sql%rowcount, gLogLevelInfo);
                log_ash_info;
              end if;
            end;
          when gtDBA_HIST_ASH then
            begin
              if gTargetSNAP_START is not null and gTargetSNAP_END is not null then
                llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): AWR start');

                select ' and ('||listagg('instance_number='||inst_id||' and sample_time<=to_date('||to_char(oldest_sample_time,'YYYYMMDDHH24MISS')||q'[,'YYYYMMDDHH24MISS')]', ' or ')
                       within group (order by inst_id)||')'
                       into l_awr_filter
                  from opas_ot_tmp_gv$ash_info;

                llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): AWR start: l_awr_filter: '||l_awr_filter);

                COREMOD_API.load_tmp_data (
                  P_DB_LINK_NAME => COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK),
                  P_SRC_TABLE_NAME_R => 'DBA_HIST_ACTIVE_SESS_HISTORY',
                  P_SRC_TABLE_NAME => 'DBA_HIST_ACTIVE_SESS_HISTORY',
                  P_TRG_TABLE_NAME => 'OPAS_OT_TMP_GV$ASH',
                  P_SUFF => 'HIST_ASH',
                  p_key_pref => 'LOCTABCOLS',
                  P_DBID => gTargetDBID,
                  P_FILTER => q'[sample_time between to_timestamp(']' || to_char(l_start_dt,'YYYYMMDDHH24MISS') || q'[','YYYYMMDDHH24MISS') and to_timestamp(']' || to_char(l_end_dt,'YYYYMMDDHH24MISS') || q'[','YYYYMMDDHH24MISS')]'
                              || ' and instance_number>0 and snap_id between ' || gTargetSNAP_START || ' and ' || gTargetSNAP_END
                              || l_awr_filter
                  );

                update OPAS_OT_ASHACUBE_RANGES set MIN_SNAP_ID = gTargetSNAP_START, MAX_SNAP_ID = gTargetSNAP_END,
                       SAMPLE_TP = case when SAMPLE_TP = gtGV$ASH then gtGV$ASHAWR else gtDBA_HIST_ASH end,
                       MODIFIED = systimestamp
                 where ASHARANGE_ID = p_asharange_id;

                llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): AWR finish: '||COREMOD_API.get_last_rowcount|| ' loaded. ', gLogLevelInfo);
              else
                llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): AWR No data found');
              end if;
            end;
          else
            null;
        end case;

        if COREOBJ_ASHA_CUBE_CALCS.gp(pMetricList) is not null then
          load_metrics(p_asharange_id, l_start_dt, l_end_dt, l_rows);
        end if;

        update OPAS_OT_TMP_GV$ASH set event='CPU', wait_class='CPU' where event is null;
       -- if l_is_data4insert then
            INSERT INTO opas_ot_ashacube_ash (
              asharange_id, dblink, SAMPLE_TP, snap_id, instance_number, sample_time,
              sample_time_utc,
              session_id, session_serial#, session_type,
              user_id, username, osuser, sql_id, sql_child_number, sql_opname, force_matching_signature, top_level_sql_id, sql_plan_hash_value,
              sql_full_plan_hash_value, sql_plan_line_id, sql_plan_operation, sql_plan_options, sql_exec_id, sql_exec_start, plsql_entry_object_id,
              plsql_entry_subprogram_id, plsql_object_id, plsql_subprogram_id, qc_instance_id, qc_session_id, qc_session_serial#, px_flags, event,
              state, wait_class, blocking_session_status, blocking_session, blocking_session_serial#, blocking_inst_id, final_blocking_session_status,
              final_blocking_instance, final_blocking_session, current_obj#, current_file#, current_block#, current_row#, consumer_group_id, xid,
              program, module, action, client_id, machine, port, ecid, terminal, tm_delta_time, tm_delta_cpu_time, tm_delta_db_time, delta_time,
              delta_read_io_requests, delta_write_io_requests, delta_read_io_bytes, delta_write_io_bytes, delta_interconnect_io_bytes, delta_read_mem_bytes,
              pga_allocated, temp_space_allocated)
            select
              p_asharange_id, COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK), p_granula.granula_type, snap_id, nvl(instance_number,inst_id), sample_time,
              nvl(sample_time_utc,SYS_EXTRACT_UTC(from_tz(sample_time,gTargetTZ))),
              session_id, session_serial#, session_type,
              user_id, username, osuser, sql_id, sql_child_number, sql_opname, force_matching_signature, top_level_sql_id, sql_plan_hash_value,
              sql_full_plan_hash_value, sql_plan_line_id, sql_plan_operation, sql_plan_options, sql_exec_id, sql_exec_start, plsql_entry_object_id,
              plsql_entry_subprogram_id, plsql_object_id, plsql_subprogram_id, qc_instance_id, qc_session_id, qc_session_serial#, px_flags, event,
              state, wait_class, blocking_session_status, blocking_session, blocking_session_serial#, blocking_inst_id, final_blocking_session_status,
              final_blocking_instance, final_blocking_session, current_obj#, current_file#, current_block#, current_row#, consumer_group_id, xid,
              program, module, action, client_id, machine, port, ecid, terminal, tm_delta_time, tm_delta_cpu_time, tm_delta_db_time, delta_time,
              delta_read_io_requests, delta_write_io_requests, delta_read_io_bytes, delta_write_io_bytes, delta_interconnect_io_bytes, delta_read_mem_bytes,
              pga_allocated, temp_space_allocated
            from OPAS_OT_TMP_GV$ASH
            where sample_time >= l_start_dt and sample_time < l_end_dt;
            l_rows := l_rows + sql%rowcount;

   -- llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): 2 l_start_dt "'|| to_char(l_start_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');
   -- llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): 2 l_end_dt "'|| to_char(l_end_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');

        if p_current_range then
            get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));
            exit when gTargetCurrTS > l_end_range_dt + INTERVAL '30' SECOND ;
        end if;

        if p_current_range then

          merge into OPAS_OT_ASHACUBE_ASH_WCS t
          using (
          with cls as (select 'CPU' wait_class from dual union all
                       select 'User I/O' from dual union all
                       select 'Administrative' from dual union all
                       select 'Application' from dual union all
                       select 'Commit' from dual union all
                       select 'Concurrency' from dual union all
                       select 'Configuration' from dual union all
                       select 'Idle' from dual union all
                       select 'Network' from dual union all
                       select 'Other' from dual union all
                       select 'Scheduler' from dual union all
                       select 'System I/O' from dual union all
                       select 'Cluster' from dual union all
                       select 'Remainder' from dual)
          select p_asharange_id ASHARANGE_ID, cls.wait_class, 1 NUM_OF_SAMPLES
            from cls where exists (select 1 from OPAS_OT_TMP_GV$ASH ash where ash.wait_class=cls.wait_class)) s
          on (t.ASHARANGE_ID = s.ASHARANGE_ID and t.WAIT_CLASS = s.WAIT_CLASS)
          when matched then update set t.NUM_OF_SAMPLES = s.NUM_OF_SAMPLES
          when not matched then insert (asharange_id, WAIT_CLASS, NUM_OF_SAMPLES) values (s.asharange_id, s.WAIT_CLASS, s.NUM_OF_SAMPLES);

          commit;
          dbms_lock.sleep(60);
          get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));
          l_start_dt := l_end_dt;
          l_end_dt := least(gTargetCurrTS, l_end_range_dt);
          llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): for current range l_start_dt "'|| to_char(l_start_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');
          llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): for current range l_end_dt "'|| to_char(l_end_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');

        end if;

        exit when not l_current_range;
    end loop;

    merge into OPAS_OT_ASHACUBE_ASH_WCS t
    using (
    with cls as (select 'CPU' wait_class from dual union all
                 select 'User I/O' from dual union all
                 select 'Administrative' from dual union all
                 select 'Application' from dual union all
                 select 'Commit' from dual union all
                 select 'Concurrency' from dual union all
                 select 'Configuration' from dual union all
                 select 'Idle' from dual union all
                 select 'Network' from dual union all
                 select 'Other' from dual union all
                 select 'Scheduler' from dual union all
                 select 'System I/O' from dual union all
                 select 'Cluster' from dual union all
                 select 'Remainder' from dual)
    select p_asharange_id ASHARANGE_ID, cls.wait_class, 1 NUM_OF_SAMPLES
      from cls where exists (select 1 from OPAS_OT_ASHACUBE_ASH ash
                                     where ash.wait_class=cls.wait_class
                                       and asharange_id = p_asharange_id
                                       and DBLINK=COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK)
                                       and SAMPLE_TIME_UTC between l_start_range_dt and l_end_range_dt)) s
    on (t.ASHARANGE_ID = s.ASHARANGE_ID and t.WAIT_CLASS = s.WAIT_CLASS)
    when not matched then insert (asharange_id, WAIT_CLASS, NUM_OF_SAMPLES) values (s.asharange_id, s.WAIT_CLASS, s.NUM_OF_SAMPLES);

    commit;
    if l_old_status is null then
        set_range_status(p_asharange_id, csInProgress, case when l_rows>0 then csReady else csEmpty end, COREMOD_TASKS.get_curr_tq_id);
    else
        set_range_status(p_asharange_id, csInProgress, case when l_rows>0 then csReady else l_old_status end, COREMOD_TASKS.get_curr_tq_id);
    end if;

    llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||') rows total: "' ||l_rows|| '"', gLogLevelInfo);
  exception
    when l_unable_to_lock then llog('COREOBJ_ASHA_CUBE_CALCS.get_granule('|| p_asharange_id ||'): unable to lock the range', gLogLevelInfo);
  end;

  procedure sample_data_for_granule(p_asharange_id opas_ot_ashacube_ranges.asharange_id%type)
  is
    l_range opas_ot_ashacube_ranges%rowtype;
    L_ASHACUBE_ID OPAS_OT_ASHACUBE.ASHACUBE_ID%type;
    l_iter number := 0;
    l_rows number := 0;
    l_tmp  number;
    l_sampling_interval number := 100; --santisecs
    l_start_time        number;
    l_sleep_time        number;
    l_sql1               varchar2(32765);
    l_sql2               varchar2(32765);

    --target TZ
    l_start_dt           timestamp;
    l_end_dt             timestamp;
  begin
    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_ASHA_CUBE_CALCS.SAMPLE_DATA_FOR_GRANULE.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_ASHA_CUBE_CALCS.SAMPLE_DATA_FOR_GRANULE.SQL_TRACE');

    llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||'): start', gLogLevelInfo);

    set_range_status(p_asharange_id, csNEW, csInQueue, COREMOD_TASKS.get_curr_tq_id);
    set_range_status(p_asharange_id, csInQueue, csInProgress, COREMOD_TASKS.get_curr_tq_id);

    select * into l_range from opas_ot_ashacube_ranges
     where asharange_id = p_asharange_id
       and tq_id = COREMOD_TASKS.get_curr_tq_id
       for update skip locked;

    select ASHACUBE_ID into L_ASHACUBE_ID from OPAS_OT_ASHACUBE_REF where ASHARANGE_ID = p_asharange_id;

    init_execution_context(L_ASHACUBE_ID);

    llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||'): gTargetCurrTS "'||to_char(gTargetCurrTS,'YYYY-MM-DD HH24:MI:SS.FF3')||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||'): gTargetCurrTS_UTC "'||to_char(gTargetCurrTS_UTC,'YYYY-MM-DD HH24:MI:SS.FF3')||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||'): SYS_EXTRACT_UTC(systimestamp) "'||to_char(SYS_EXTRACT_UTC(systimestamp),'YYYY-MM-DD HH24:MI:SS.FF3')||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||') l_range.START_TIME_UTC "'||to_char(l_range.START_TIME_UTC,'YYYY-MM-DD HH24:MI:SS')||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||') l_range.END_TIME_UTC "'||to_char(l_range.END_TIME_UTC,'YYYY-MM-DD HH24:MI:SS.FF3')||'"');

    l_start_dt := from_utc_to_target_tz(l_range.START_TIME_UTC);
    l_end_dt   := from_utc_to_target_tz(l_range.END_TIME_UTC);

    llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||'): l_start_dt "'|| to_char(l_start_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||'): l_end_dt "'|| to_char(l_end_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"');

    if gTargetCurrTS_UTC >= l_range.START_TIME_UTC - INTERVAL '70' SECOND and gTargetCurrTS_UTC < l_range.END_TIME_UTC + INTERVAL '10' SECOND then

      l_sql1 := COREMOD_API.get_tmp_load_query(
        P_DB_LINK_NAME => l_range.DBLINK,
        P_SRC_TABLE_NAME_R => 'GV_$SESSION',
        P_SRC_TABLE_NAME => 'GV$SESSION',
        P_TRG_TABLE_NAME => 'OPAS_OT_TMP_GV$SESSION',
        P_SUFF => 'GV$SESS',
        P_DBID => null,
        P_KEY_PREF => 'TABCOLLIST',
        P_FILTER => q'[status='ACTIVE' and type='USER']',
        p_timestamp_col => 'TSTZ');

      llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||'): Sampling SQL "'||l_sql1||'"');

      l_sql2 :=
      q'[INSERT INTO opas_ot_ashacube_ash (
        asharange_id, dblink,               snap_id, instance_number, sample_time, sample_time_utc,
        session_id, session_serial#, session_type,
        user_id, username, osuser, sql_id, sql_child_number, sql_opname, force_matching_signature, top_level_sql_id, sql_plan_hash_value,
        sql_full_plan_hash_value, sql_plan_line_id, sql_plan_operation, sql_plan_options, sql_exec_id, sql_exec_start, plsql_entry_object_id,
        plsql_entry_subprogram_id, plsql_object_id, plsql_subprogram_id, qc_instance_id, qc_session_id, qc_session_serial#, px_flags, event,
        state, wait_class, blocking_session_status, blocking_session, blocking_session_serial#, blocking_inst_id, final_blocking_session_status,
        final_blocking_instance, final_blocking_session, current_obj#, current_file#, current_block#, current_row#, consumer_group_id, xid,
        program, module, action, client_id, machine, port, ecid, terminal, tm_delta_time, tm_delta_cpu_time, tm_delta_db_time, delta_time,
        delta_read_io_requests, delta_write_io_requests, delta_read_io_bytes, delta_write_io_bytes, delta_interconnect_io_bytes, delta_read_mem_bytes,
        pga_allocated, temp_space_allocated)
      select
        :p_asharange_id, :DBLINK, null snap_id, inst_id,       TSTZ at time zone ']' || gTargetTZ || q'[', sys_extract_utc(TSTZ),
        SID, SERIAL#, TYPE,
        USER#, USERNAME, OSUSER, sql_id, sql_child_number, null sql_opname, null force_matching_signature, null top_level_sql_id, null sql_plan_hash_value,
        null sql_full_plan_hash_value, null sql_plan_line_id, null sql_plan_operation, null sql_plan_options, sql_exec_id, sql_exec_start, plsql_entry_object_id,
        plsql_entry_subprogram_id, plsql_object_id, plsql_subprogram_id, null qc_instance_id, null qc_session_id, null qc_session_serial#, null px_flags, event,
        state, wait_class, blocking_session_status, blocking_session, null blocking_session_serial#, blocking_instance, final_blocking_session_status,
        final_blocking_instance, final_blocking_session, null current_obj#, null current_file#, null current_block#, null current_row#, null consumer_group_id, null xid,
        program, module, action, CLIENT_IDENTIFIER client_id, machine, port, ecid, terminal, null tm_delta_time, null tm_delta_cpu_time, null tm_delta_db_time, null delta_time,
        null delta_read_io_requests, null delta_write_io_requests, null delta_read_io_bytes, null delta_write_io_bytes, null delta_interconnect_io_bytes, null delta_read_mem_bytes,
        null pga_allocated, null temp_space_allocated
      from OPAS_OT_TMP_GV$SESSION where sys_extract_utc(TSTZ) >= :START_RANGE_UTC and sys_extract_utc(TSTZ) < :END_RANGE_UTC
       and not( upper(machine) like '%'||upper(SYS_CONTEXT ('USERENV', 'SERVER_HOST'))||'%' or
                upper(program) like '%'||upper(SYS_CONTEXT ('USERENV', 'SERVER_HOST'))||'%' or
                upper(module)  like '%'||upper(SYS_CONTEXT ('USERENV', 'SERVER_HOST'))||'%') ]'; --dbhostl75.localdomain

      llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||'): Loading SQL "'||l_sql2||'"');

      delete from OPAS_OT_TMP_GV$SESSION;

      l_start_time := DBMS_UTILITY.GET_TIME;
      loop
        --sampling
        execute immediate l_sql1;
        --llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||') sampled "'||sql%rowcount||'"');

        l_sleep_time := (l_sampling_interval - (DBMS_UTILITY.GET_TIME-l_start_time))/100;
        if l_sleep_time > 0.09 then
          dbms_lock.sleep(l_sleep_time);
          --llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||') slept: '||l_sleep_time);
        end if;
        l_iter := l_iter + 1; --for logging

        if mod(l_iter,60) = 0 then
          --llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||') l_start_range_dt_utc "'||to_char(l_start_range_dt_utc,'YYYY-MM-DD HH24:MI:SS.FF3')||'"');
          --llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||') l_end_range_dt_utc "'||to_char(l_end_range_dt_utc,'YYYY-MM-DD HH24:MI:SS.FF3')||'"');
          execute immediate l_sql2 using p_asharange_id, l_range.DBLINK, l_range.START_TIME_UTC, l_range.END_TIME_UTC;
          l_rows := l_rows + sql%rowcount;
          delete from OPAS_OT_TMP_GV$SESSION;
          llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||') deleted from OPAS_OT_TMP_GV$SESSION: '|| sql%rowcount);

          l_end_dt   := from_utc_to_target_tz(SYS_EXTRACT_UTC(systimestamp));
          llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||') l_start_dt "'||to_char(l_start_dt,'YYYY-MM-DD HH24:MI:SS.FF3')||'"');
          llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||') l_end_dt "'||to_char(l_end_dt,'YYYY-MM-DD HH24:MI:SS.FF3')||'"');

          if COREOBJ_ASHA_CUBE_CALCS.gp(pMetricList) is not null then
            load_metrics(p_asharange_id, l_start_dt, l_end_dt, l_rows);
          end if;
          l_start_dt := l_end_dt;
          commit;
          llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||') l_iter "'||l_iter||'"');
        end if;

        exit when SYS_EXTRACT_UTC(systimestamp) >= l_range.END_TIME_UTC + INTERVAL '10' SECOND or gGranulaSize < 1 + l_iter*(l_sampling_interval/100)/60;
        l_start_time := DBMS_UTILITY.GET_TIME;
      end loop;
    end if;


    execute immediate l_sql2 using p_asharange_id, l_range.DBLINK, l_range.START_TIME_UTC, l_range.END_TIME_UTC;

    l_rows := l_rows + sql%rowcount;

    insert into OPAS_OT_ASHACUBE_ASH_WCS
    select asharange_id, nvl(wait_class,'CPU') wait_class, count(1)
      from OPAS_OT_ASHACUBE_ASH
     where asharange_id = p_asharange_id
     group by asharange_id, nvl(wait_class,'CPU') order by 1,2;

    commit;
    set_range_status(p_asharange_id, csInProgress, case when l_rows>0 then csReady else csEmpty end, COREMOD_TASKS.get_curr_tq_id);
    llog('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule('|| p_asharange_id ||') finish: l_rows; l_iter: "'||l_rows|| '"; "' || l_iter || '"', gLogLevelInfo);

    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_ASHA_CUBE_CALCS.SAMPLE_DATA_FOR_GRANULE.GATHER_SQL_STAT');
    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_ASHA_CUBE_CALCS.SAMPLE_DATA_FOR_GRANULE.SQL_TRACE');
  exception
    when others then
      coremod_tasks.log('Error COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule ('||p_asharange_id||'): '||sqlerrm);
      coremod_tasks.log('Error COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule error stack: '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      raise_application_error(-20000, 'Error COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule ('||p_asharange_id||'): '||sqlerrm);
  end;
--===============================================================================================================================
  procedure sample_stat_for_granule(p_asharange_id opas_ot_ashacube_ranges.asharange_id%type)
  is
    l_range opas_ot_ashacube_ranges%rowtype;
    L_ASHACUBE_ID OPAS_OT_ASHACUBE.ASHACUBE_ID%type;
    l_iter number := 0;
    l_rows number := 0;

    l_sampling_interval number := 1000; --santisecs
    l_start_time        number;
    l_sleep_time        number;
    l_sql1              varchar2(32765);
    l_sql2              varchar2(32765);
    l_sql3              varchar2(32765);
  begin
    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_ASHA_CUBE_CALCS.SAMPLE_STAT_FOR_GRANULE.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_ASHA_CUBE_CALCS.SAMPLE_STAT_FOR_GRANULE.SQL_TRACE');

    llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||'): start', gLogLevelInfo);

    select * into l_range from opas_ot_ashacube_ranges
     where asharange_id = p_asharange_id ;

    select ASHACUBE_ID into L_ASHACUBE_ID from OPAS_OT_ASHACUBE_REF where ASHARANGE_ID = p_asharange_id;

    init_execution_context(L_ASHACUBE_ID);

    llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||') gTargetCurrTS_UTC "'||to_char(gTargetCurrTS_UTC,'YYYY-MM-DD HH24:MI:SS.FF3')||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||') SYS_EXTRACT_UTC(systimestamp) "'||to_char(SYS_EXTRACT_UTC(systimestamp),'YYYY-MM-DD HH24:MI:SS.FF3')||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||') l_range.START_TIME_UTC "'||to_char(l_range.START_TIME_UTC,'YYYY-MM-DD HH24:MI:SS')||'"');
    llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||') l_range.END_TIME_UTC "'||to_char(l_range.END_TIME_UTC,'YYYY-MM-DD HH24:MI:SS.FF3')||'"');

    if gTargetCurrTS_UTC >= l_range.START_TIME_UTC - INTERVAL '70' SECOND and gTargetCurrTS_UTC < l_range.END_TIME_UTC + INTERVAL '10' SECOND then

      l_sql3 := q'[merge into opas_db_statistics t
      using (select statistic#, display_name, '<DBLINKNM>' dblink from v$statname<DBLINK> where <STATSLIST>) s
      on (s.statistic#=t.statistic# and s.dblink=t.dblink)
      when not matched then insert (statistic#, display_name, dblink) values (s.statistic#, s.display_name, s.dblink)]';


      if gp(pGETSTATS) = 'Y' and gp(pGETSEESTATS) = 'Y' then
        l_sql1 := q'[insert into opas_ot_tmp_gv$stats (TS_UTC, INST_ID, SID, STATISTIC#, VALUE)
        select  :ts_utc, inst_id, sid, statistic#, value from (
        select  inst_id, sid, statistic#, value from gv$sesstat<DBLINK> where value>0 and <STATSLIST> union all select  inst_id, null sid, statistic#, value from gv$sysstat<DBLINK> where value>0 and <STATSLIST>)]';
      elsif gp(pGETSTATS) = 'Y' and gp(pGETSEESTATS) = 'N' then
        l_sql1 := q'[insert into opas_ot_tmp_gv$stats (TS_UTC, INST_ID, SID, STATISTIC#, VALUE)
        select  :ts_utc, inst_id, sid, statistic#, value from (
        select  inst_id, null sid, statistic#, value from gv$sysstat<DBLINK> where value>0 and <STATSLIST>)]';
      end if;

      l_sql1 := replace(l_sql1,'<DBLINK>',COREMOD_API.get_dblink_for_query(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK)));
      l_sql3 := replace(l_sql3,'<DBLINK>',COREMOD_API.get_dblink_for_query(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK)));
      l_sql3 := replace(l_sql3,'<DBLINKNM>',COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));

      l_sql1 :=replace(replace(l_sql1,'<STATSLIST>','statistic# in (<LIST>)'),'<LIST>',replace(gp(pSTATSLIST),':',','));
      llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||') Sampling SQL "'||l_sql1||'"');

      l_sql3 :=replace(replace(l_sql3,'<STATSLIST>','statistic# in (<LIST>)'),'<LIST>',replace(gp(pSTATSLIST),':',','));
      llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||') Stats dic SQL "'||l_sql3||'"');

      l_sql2 :=
      q'[INSERT INTO OPAS_OT_ASHACUBE_STATS (
        asharange_id, dblink, TS_UTC, INST_ID, SID, STATISTIC#, VALUE)
      select
        :p_asharange_id, :DBLINK, TS_UTC, INST_ID, SID, STATISTIC#, VALUE
      from
      (select
         TS_UTC, INST_ID, SID, STATISTIC#, VALUE - lag(VALUE)over(partition by INST_ID, SID, STATISTIC# order by TS_UTC) VALUE
         from opas_ot_tmp_gv$stats where ts_utc >= :START_TIME_UTC and ts_utc < :END_TIME_UTC)
      where nvl(VALUE,0)>0]';

      llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||') Loading SQL "'||l_sql2||'"');

      execute immediate l_sql3;
      commit;

      delete from OPAS_OT_TMP_GV$ASH;

      l_start_time := DBMS_UTILITY.GET_TIME;
      loop
        --sampling
        execute immediate l_sql1 using SYS_EXTRACT_UTC(systimestamp);
        l_rows := l_rows + sql%rowcount;

        l_sleep_time := (l_sampling_interval - (DBMS_UTILITY.GET_TIME-l_start_time))/100;
        if l_sleep_time > 0.09 then
          dbms_lock.sleep(l_sleep_time);
          --llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||') slept: '||l_sleep_time);
        end if;
        l_iter := l_iter + 1; --for logging

        if mod(l_iter,60) = 0 then
          llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||') l_iter, l_rows: "'||l_iter||'", "'||l_rows||'"');
        end if;

        exit when SYS_EXTRACT_UTC(systimestamp) >= l_range.END_TIME_UTC + INTERVAL '10' SECOND or gGranulaSize < 1 + l_iter*(l_sampling_interval/100)/60;
        l_start_time := DBMS_UTILITY.GET_TIME;
      end loop;
    end if;

    l_rows := 0;
    execute immediate l_sql2 using p_asharange_id, l_range.DBLINK, l_range.START_TIME_UTC, l_range.END_TIME_UTC;
    l_rows := l_rows + sql%rowcount;

    commit;
    llog('COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule('|| p_asharange_id ||'): l_rows; l_iter: "' ||l_rows|| '"; "' || l_iter || '"', gLogLevelInfo);

    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_ASHA_CUBE_CALCS.SAMPLE_STAT_FOR_GRANULE.GATHER_SQL_STAT');
    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_ASHA_CUBE_CALCS.SAMPLE_STAT_FOR_GRANULE.SQL_TRACE');
  exception
    when others then
      coremod_tasks.log('Error COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule ('||p_asharange_id||'): '||sqlerrm);
      coremod_tasks.log('Error COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule error stack: '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      raise_application_error(-20000, 'Error COREOBJ_ASHA_CUBE_CALCS.sample_stat_for_granule ('||p_asharange_id||'): '||sqlerrm);
  end;

  procedure init_cube_ranges(p_obj_id  opas_objects.obj_id%type)
  is
    l_granules          t_granules;
    l_mstatuses         varchar2(4000);
  begin

      init_execution_context(p_obj_id);
      --================================================================================================
      set_lock(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));

      delete from opas_ot_ashacube_ranges r
       where DBLINK<>COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK)
         and ASHARANGE_ID in (select ASHARANGE_ID from OPAS_OT_ASHACUBE_REF where ASHACUBE_ID = p_obj_id)
         and not exists (select 1 from OPAS_OT_ASHACUBE_REF i where i.ASHARANGE_ID = r.ASHARANGE_ID and ASHACUBE_ID != p_obj_id)
         and STATUS in (csNew, csEmpty);

      delete from OPAS_OT_ASHACUBE_REF where ASHACUBE_ID = p_obj_id;

      open crsr_granules (p_obj_id, COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK), /*trunc(gTargetMinASHTS_UTC,'MI'),*/ gTargetCurrTS_UTC, 1 /*pc_create_ranges*/);
      fetch crsr_granules bulk collect into l_granules;
      close crsr_granules;

      --llog('COREOBJ_ASHA_CUBE_CALCS.init_cube_ranges('||p_obj_id||'): granuls to prepare: "'|| l_granules.count ||'"');

      for i in 1..l_granules.count loop
        llog('COREOBJ_ASHA_CUBE_CALCS.init_cube_ranges('||p_obj_id||'): preparing l_granules(i).start_granula_dt: "'||to_char(l_granules(i).start_granula_dt,'YYYY/MM/DD HH24:MI')||'"');
        llog('COREOBJ_ASHA_CUBE_CALCS.init_cube_ranges('||p_obj_id||'): preparing l_granules(i).end_granula_dt: "'||to_char(l_granules(i).end_granula_dt,'YYYY/MM/DD HH24:MI')||'"');
        if    gASH_Available = 'Y' -- enterprise edition
           or gASH_Available = 'N' and l_granules(i).end_granula_dt >= gTargetCurrTS_UTC --standard edition, only for future time ranges
           or gASH_Available = 'N' and gp(pMetricList) is not null
        then
          if l_granules(i).asharange_id is null then
              INSERT INTO opas_ot_ashacube_ranges (
                dblink, sample_tp, start_time_utc, end_time_utc, incarnation#, status, created, DBID)
              VALUES (
                COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK),
                case when gASH_Available = 'N' then gtSamplGV$SESS else null end,
                l_granules(i).start_granula_dt, l_granules(i).end_granula_dt, gTargetIncarnation, csNew, systimestamp, gTargetDBID
              ) returning asharange_id into l_granules(i).asharange_id;
              --llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: new granula: "'|| l_granules(i).asharange_id ||'"');
          end if;

          delete from OPAS_OT_ASHACUBE_METRICS_LIST
           where ASHARANGE_ID = l_granules(i).asharange_id
             and not exists (select 1 from OPAS_OT_ASHACUBE_REF where ASHARANGE_ID = l_granules(i).asharange_id and ASHACUBE_ID != p_obj_id)
             and (GROUP_ID,METRIC_ID) not in (select to_number(substr(column_value,1,instr(column_value,'~')-1)) group_id,
                                                     to_number(substr(column_value,instr(column_value,'~')+1)) metric_id
                                                from table(apex_string.split(gp(pMetricList),':')));
          delete from OPAS_OT_ASHACUBE_METRICS
           where ASHARANGE_ID = l_granules(i).asharange_id
             and not exists (select 1 from OPAS_OT_ASHACUBE_REF where ASHARANGE_ID = l_granules(i).asharange_id and ASHACUBE_ID != p_obj_id)
             and (GROUP_ID,METRIC_ID) not in (select to_number(substr(column_value,1,instr(column_value,'~')-1)) group_id,
                                                     to_number(substr(column_value,instr(column_value,'~')+1)) metric_id
                                                from table(apex_string.split(gp(pMetricList),':')));
          if gp(pMetricList) is not null then
            /*llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data granula: pMetricList: "'|| gp(pMetricList) ||'"');
            for jj in (select -- l_granules(i).asharange_id asharange_id,
                          substr(column_value,1,instr(column_value,'~')-1) group_id,
                          substr(column_value,instr(column_value,'~')+1) metric_id from table(apex_string.split(gp(pMetricList),':')))
            loop
              llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data granula: pMetricList: "'||  jj.group_id ||':'|| jj.metric_id || '"');
            end loop;*/

            merge into OPAS_OT_ASHACUBE_METRICS_LIST t
            using (select l_granules(i).asharange_id asharange_id,
                          to_number(substr(column_value,1,instr(column_value,'~')-1)) group_id,
                          to_number(substr(column_value,instr(column_value,'~')+1)) metric_id from table(apex_string.split(gp(pMetricList),':'))) s
               on (t.asharange_id = s.asharange_id and t.group_id = s.group_id and t.METRIC_ID = s.METRIC_ID)
             when not matched then insert(asharange_id,  group_id,  metric_id, METRIC_STATUS) VALUES (s.asharange_id,  s.group_id,  s.metric_id, csNEW);
          end if;

        end if;
        if l_granules(i).ashacube_id is null and l_granules(i).asharange_id is not null then
          INSERT INTO OPAS_OT_ASHACUBE_REF ( ASHACUBE_ID, ASHARANGE_ID) VALUES (p_obj_id, l_granules(i).asharange_id);
          --llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data granula: linked: "'|| l_granules(i).asharange_id ||'"');
        end if;
      end loop;
      COREMOD_API.release_resource;
  exception
    when others then
      COREMOD_API.release_resource;
      coremod_tasks.log('Error COREOBJ_ASHA_CUBE_CALCS.init_cube_ranges ('||p_obj_id||'): '||sqlerrm);
      coremod_tasks.log('Error COREOBJ_ASHA_CUBE_CALCS.init_cube_ranges error stack: '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      raise_application_error(-20000, 'Error COREOBJ_ASHA_CUBE_CALCS.init_cube_ranges ('||p_obj_id||'): '||sqlerrm);
  end;

  procedure get_ash_data(p_obj_id  opas_objects.obj_id%type)
  is
    l_asharange_id opas_ot_ashacube_ranges.asharange_id%type;
    --l_granula_rows_added number;
    l_start_time_trg_tz timestamp;
    l_end_time_trg_tz   timestamp;

    l_grnl_idx          number;

    l_middle_time_trg_tz   timestamp;
    l_middle_asharange_id  opas_ot_ashacube_ranges.asharange_id%type;

    l_granules          t_granules;
    l_granules1         t_granules;
    --l_awr_boundary      crsr_granules%rowtype;

    l_cycles            number := 0;

    l_lops_ind          pls_integer;
    l_lops_iter         pls_integer;
    l_ModuleName        varchar2(100) := 'ASHA Cube gathering: ';

    l_in_progress       number;
    l_ready             number;
    --type tab_tq_id      is table of  OPAS_TASK_QUEUE.tq_id%type;
    l_tq_id_tab         tab_tq_id := tab_tq_id();
    l_tq_id_tab2        tab_tq_id := tab_tq_id();
  begin
    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_ASHA_CUBE_CALCS.GET_ASHA_DATA.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_ASHA_CUBE_CALCS.GET_ASHA_DATA.SQL_TRACE');

    store_tasks(p_obj_id); --store itself

    g_tq_id_tab.delete;
    g_tq_name_tab.delete;

    loop

        init_execution_context(p_obj_id);

        llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): l_cycles: "'|| l_cycles ||'"');
        llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): target edition: "'|| case when gASH_Available = 'Y' then 'Enterprise' else 'Standard' end ||'"');
        --================================================================================================

        open crsr_granules (p_obj_id, COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK),/*trunc(gTargetMinASHTS_UTC,'MI'),*/ gTargetCurrTS_UTC);
        fetch crsr_granules bulk collect into l_granules;
        close crsr_granules;

        update OPAS_OT_ASHACUBE set STATUS = csInProgress, MODIFIED = systimestamp where ASHACUBE_ID = p_obj_id;-- and STATUS = csNEW;
        commit;
        --================================================================================================

        if gASH_Available = 'Y' then -- enterprise edition
          l_ModuleName := 'ASHA Cube gathering: ';
        else -- standard edition, sampling
          l_ModuleName := 'ASHA Cube sampling: ';
        end if;


        llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): granuls in queue: "'|| l_granules.count ||'"', gLogLevelInfo);

        coremod_api.init_longops(p_op_name => l_ModuleName,
                                 p_target_desc => 'ranges',
                                 p_units => 'range',
                                 p_totalwork => l_granules.count,
                                 p_lops_ind => l_lops_ind);

        l_lops_iter := 0;


        for i in 1..l_granules.count loop

          if l_granules(i).STATUS = csNEW then

            coremod_api.start_longops_section(p_module_name => l_ModuleName,
                                              p_action_name => 'Range: '||to_char(l_granules(i).start_granula_dt,'YYYY/MM/DD HH24:MI')|| ' - ' ||to_char(l_granules(i).end_granula_dt,'YYYY/MM/DD HH24:MI'));

            llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): l_granules(i).start_granula_dt: "'||to_char(l_granules(i).start_granula_dt,'YYYY/MM/DD HH24:MI')||'"');
            llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): l_granules(i).end_granula_dt: "'||to_char(l_granules(i).end_granula_dt,'YYYY/MM/DD HH24:MI')||'"');

            get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));

--            if gASH_Available = 'Y' then -- enterprise edition

            l_start_time_trg_tz := from_utc_to_target_tz(l_granules(i).start_granula_dt);
            l_end_time_trg_tz   := from_utc_to_target_tz(l_granules(i).end_granula_dt);

            llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): l_start_time_trg_tz: "'|| l_start_time_trg_tz ||'"');
            llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): l_end_time_trg_tz: "'|| l_end_time_trg_tz ||'"');
--granule status!!!

            if gASH_Available = 'N' /*standard edition, sampling*/ or COREOBJ_ASHA_CUBE_CALCS.gp(pGETSTATS) = 'Y' then
              --=====================================================================

              if gTargetCurrTS_UTC <= l_granules(i).START_TIME_UTC - INTERVAL '60' SECOND then
                llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): waiting to start sampling tasks', gLogLevelInfo);
                loop
                  get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));
                  exit when gTargetCurrTS_UTC >= l_granules(i).START_TIME_UTC - INTERVAL '60' SECOND;
                  dbms_lock.sleep(15);
                end loop;
              end if;

              if gTargetCurrTS_UTC >= l_granules(i).START_TIME_UTC - INTERVAL '60' SECOND and gTargetCurrTS_UTC < l_granules(i).END_TIME_UTC - INTERVAL '60' SECOND then

                if gASH_Available = 'N' then
                  l_tq_id_tab.extend;
                  l_tq_id_tab(l_tq_id_tab.count):=COREMOD_TASKS.prep_execute_task (  P_TASKNAME => 'OPAS_ASHA_GRNLSMPL') ;
                  COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id_tab(l_tq_id_tab.count), p_name => 'B1', p_num_par => l_granules(i).asharange_id);
                  COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id_tab(l_tq_id_tab.count) ) ;
                  commit;
                  llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): sampling V$SESSION granula queued: '||l_granules(i).asharange_id, gLogLevelInfo);
                  g_tq_id_tab.extend;
                  g_tq_id_tab(g_tq_id_tab.count) := l_tq_id_tab(l_tq_id_tab.count);
                  g_tq_name_tab.extend;
                  g_tq_name_tab(g_tq_name_tab.count) := 'V$SESSION Sampling';
                end if;
                if COREOBJ_ASHA_CUBE_CALCS.gp(pGETSTATS) = 'Y' and length(trim(replace(COREOBJ_ASHA_CUBE_CALCS.gp(pSTATSLIST),':')))>0 then
                  l_tq_id_tab.extend;
                  l_tq_id_tab(l_tq_id_tab.count):=COREMOD_TASKS.prep_execute_task (  P_TASKNAME => 'OPAS_ASHA_STATSMPL') ;
                  COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id_tab(l_tq_id_tab.count), p_name => 'B1', p_num_par => l_granules(i).asharange_id);
                  COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id_tab(l_tq_id_tab.count) ) ;
                  commit;
                  llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): sampling V$SESSTAT granula queued: '||l_granules(i).asharange_id, gLogLevelInfo);
                  g_tq_id_tab.extend;
                  g_tq_id_tab(g_tq_id_tab.count) := l_tq_id_tab(l_tq_id_tab.count);
                  g_tq_name_tab.extend;
                  g_tq_name_tab(g_tq_name_tab.count) := 'Statistics Sampling';
                end if;

                store_tasks(p_obj_id);

              end if;
            else
              llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): Noting to sample: '||l_granules(i).asharange_id, gLogLevelInfo);
            end if;

            if gTargetCurrTS <= l_start_time_trg_tz then
              llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): waiting to start granula', gLogLevelInfo);
              loop
                get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));
                llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): currently "'||gTargetCurrTS||'"');
                exit when gTargetCurrTS > l_start_time_trg_tz;
                dbms_lock.sleep(30);
              end loop;
            end if;

            if gTargetCurrTS >= l_end_time_trg_tz then
              llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): full V$ASH granula for past time start...');
              get_granule(/*gtGV$ASH,*/ l_granules(i)/*.asharange_id*/, false);
              llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): full V$ASH granula for past time finish...');
            else
              llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): full V$ASH granula for current time start...');
              get_granule(/*gtGV$ASH,*/ l_granules(i)/*.asharange_id*/, true);
              llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): full V$ASH granula for current time finish...');
            end if;

            l_lops_iter := l_lops_iter + 1;
            coremod_api.end_longops_section(p_sofar => l_lops_iter, p_lops_ind => l_lops_ind);

          end if;
        end loop;

        llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): entering waiting child tasks mode: l_tq_id_tab.count: '||l_tq_id_tab.count, gLogLevelInfo);
        l_tq_id_tab2.delete;
        for i in 1..l_tq_id_tab.count loop
          if not COREMOD_TASKS.is_task_finish(P_TQ_ID => l_tq_id_tab(i)) then l_tq_id_tab2.extend; l_tq_id_tab2(l_tq_id_tab2.count) := l_tq_id_tab(i); end if;
        end loop;
        if l_tq_id_tab2.count > 0 then l_tq_id_tab.delete; l_tq_id_tab := l_tq_id_tab2; end if;
        llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): to wait tasks: "'||l_tq_id_tab2.count||'"', gLogLevelInfo);

        get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));

        open crsr_granules (p_obj_id, COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK), /*trunc(gTargetMinASHTS_UTC,'MI'),*/ gTargetCurrTS_UTC);
        fetch crsr_granules bulk collect into l_granules1;
        close crsr_granules;

        llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'): check cycle exit conditions: l_tq_id_tab2.count, l_granules.count, l_granules1.count, l_cycles: '||
              l_tq_id_tab2.count||'; '||l_granules.count||'; '||l_granules1.count||'; '||l_cycles);
        exit when (l_tq_id_tab2.count = 0 and l_granules.count = l_granules1.count) or l_cycles > 100;
        l_cycles := l_cycles + 1;
        dbms_lock.sleep(15);
    end loop;

    store_params(p_obj_id);

    select
           sum(decode(r.STATUS,csInProgress,1,0)),
           sum(decode(r.STATUS,csReady,1,0))
           into l_in_progress, l_ready
      from OPAS_OT_ASHACUBE_RANGES r, OPAS_OT_ASHACUBE_REF f
     where r.ASHARANGE_ID = f.ASHARANGE_ID and f.ASHACUBE_ID=p_obj_id;

    update OPAS_OT_ASHACUBE set
      STATUS = case when l_in_progress>0 then csInProgress when l_in_progress=0 and l_ready > 0 then csReady else csEmpty end,
      MODIFIED = systimestamp where ASHACUBE_ID = p_obj_id; -- and STATUS = csInProgress;
    commit;

    llog('COREOBJ_ASHA_CUBE_CALCS.get_ash_data('||p_obj_id||'):finishing with: l_in_progress; l_ready: '||l_in_progress||'; '||l_ready, gLogLevelInfo);

    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_ASHA_CUBE_CALCS.GET_ASHA_DATA.SQL_TRACE');
    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_ASHA_CUBE_CALCS.GET_ASHA_DATA.GATHER_SQL_STAT');
  exception
    when others then
      COREMOD_API.release_resource;
      coremod_tasks.log('Error COREOBJ_ASHA_CUBE_CALCS.get_ash_data ('||p_obj_id||'): '||sqlerrm);
      coremod_tasks.log('Error COREOBJ_ASHA_CUBE_CALCS.get_ash_data error stack: '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      raise_application_error(-20000, 'Error COREOBJ_ASHA_CUBE_CALCS.get_ash_data ('||p_obj_id||'): '||sqlerrm);
  end;

END COREOBJ_ASHA_CUBE_CALCS;
/


