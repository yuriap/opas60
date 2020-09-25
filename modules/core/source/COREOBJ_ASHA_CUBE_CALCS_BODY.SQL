

CREATE OR REPLACE
PACKAGE BODY COREOBJ_ASHA_CUBE_CALCS AS

  gJSParams             COREOBJ_API.t_params;
  gTABParams            COREOBJ_API.t_params;

  gGranulaSize          number := 15; -- minutes, must devide 60 in a round number

  gTargetTZ             varchar2(10);
  gTargetMinASHTS       timestamp; -- with time zone;
  gTargetMinASHTS_UTC   timestamp;
  gTargetIncarnation    number;
  gTargetDBID           number;
  gTargetCurrTS_TZ      timestamp with time zone;
  gTargetCurrTS         timestamp;
  gTargetCurrTS_UTC     timestamp;
  gTargetSNAP_START     number;
  gTargetSNAP_END       number;

  gLogLevel             varchar2(100):='INFO';

    cursor crsr_granules (pc_obj_id  opas_objects.obj_id%type,
                          pc_dblink  OPAS_DB_LINKS.DB_LINK_NAME%type,
                          pc_min_ash date,
                          pc_curr_dt date)
    is
    with input_pars as (
            select START_TIME_UTC,
                   END_TIME_UTC,
                   pc_min_ash min_ash,
                   pc_curr_dt curr_dt
              from opas_ot_ashacube where ashacube_id = pc_obj_id),
          adj_input_pars as
           (select min_ash,curr_dt,
                   trunc(START_TIME_UTC, 'hh') +
                   floor(24 * 60 * (trunc(START_TIME_UTC,'MI') - trunc(START_TIME_UTC, 'hh')) / gGranulaSize) * gGranulaSize / 24 / 60 real_start_date,
                   trunc(END_TIME_UTC, 'hh') +
                   ceil(24 * 60 * (trunc(END_TIME_UTC,'MI') - trunc(END_TIME_UTC, 'hh')) / gGranulaSize) * gGranulaSize / 24 / 60 real_end_date--,
                   --START_TIME_UTC, END_TIME_UTC
              from input_pars),
          dt_boundaries as
           (select level rn,min_ash,curr_dt,
                   real_start_date + (level-1) /(24*round(60/gGranulaSize)) start_granula_dt,
                   real_start_date + (level) /(24*round(60/gGranulaSize)) end_granula_dt
              from dual, adj_input_pars
            connect by level <= ((real_end_date - real_start_date) * 24 * round(60/gGranulaSize)))
             select case
                   when b.min_ash between b.start_granula_dt and b.end_granula_dt then -1e6
                   when b.min_ash < b.start_granula_dt and b.curr_dt > b.end_granula_dt then -1e6 + b.rn
                   when b.curr_dt < b.start_granula_dt then 1e6 + b.rn
                   else b.rn end ordr,
                    b.min_ash, b.rn, b.start_granula_dt, b.end_granula_dt, rng.*, rf.ashacube_id
               from opas_ot_ashacube_ref rf,
                    OPAS_OT_ASHACUBE_RANGES    rng,
                    dt_boundaries              b
              where b.start_granula_dt = rng.START_TIME_UTC(+)
                and b.end_granula_dt = rng.END_TIME_UTC(+)
                and rng.ASHARANGE_ID = rf.ASHARANGE_ID(+)
                and rng.DBLINK(+) = pc_dblink
              order by ordr, start_granula_dt desc;

    type t_granules is table of crsr_granules%rowtype;

  procedure set_lock(p_dblink opas_db_links.db_link_name%type)
  is
  begin
    COREMOD_API.lock_resource (
      P_RESOURCE_NAME => 'OPASASHACUBEGATHER'||p_dblink,
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

  procedure get_remote_data(p_dblink opas_db_links.db_link_name%type)
  is
    l_sql  varchar2(1000);
  begin
    l_sql :=
      q'[select extract(TIMEZONE_HOUR from systimestamp)||':'||extract(TIMEZONE_MINUTE from systimestamp), oldest_sample_time, (]' ||
         q'[select incarnation# from v$database_incarnation]' || COREMOD_API.get_dblink_for_query(p_dblink) || q'[ where status='CURRENT']'
      || q'[), systimestamp, cast(systimestamp as timestamp), sys_extract_utc(systimestamp) from V$ASH_INFO]'||COREMOD_API.get_dblink_for_query(p_dblink);
      --q'[select TZ_OFFSET(dbtimezone), to_timestamp_tz(to_char(oldest_sample_time,'YYYYMMDDHH24MISS.FF3')||' '||TZ_OFFSET(dbtimezone),'YYYYMMDDHH24MISS.FF3 TZH:TZM') from V$ASH_INFO]'||COREMOD_API.get_dblink_for_query(p_dblink);
    execute immediate l_sql into gTargetTZ, gTargetMinASHTS, gTargetIncarnation, gTargetCurrTS_TZ, gTargetCurrTS, gTargetCurrTS_UTC;

    gTargetMinASHTS_UTC := sys_extract_utc(to_timestamp_tz(to_char(gTargetMinASHTS,'YYYYMMDDHH24MISS')|| ' ' || gTargetTZ ,'YYYYMMDDHH24MISS TZH:TZM'));
  end;

  procedure get_remote_curr_ts(p_dblink opas_db_links.db_link_name%type)
  is
    l_sql  varchar2(1000);
  begin
    l_sql := q'[select cast(systimestamp as timestamp), sys_extract_utc(systimestamp) from dual]'||COREMOD_API.get_dblink_for_query(p_dblink);
    execute immediate l_sql into gTargetCurrTS, gTargetCurrTS_UTC;
  end;

  procedure get_remote_awr_snaps(p_dblink opas_db_links.db_link_name%type,
                                 p_start_dt timestamp,
                                 p_end_dt timestamp)
  is
    l_sql_get_snaps varchar2(4000)
      := q'[select min(snap_id) min_snap, max(snap_id) max_snap from dba_hist_snapshot<DBLINK> where dbid = ]' ||
      gTargetDBID || q'[ and begin_interval_time >= :p1 and end_interval_time <= :p2]';
  begin
    execute immediate replace(l_sql_get_snaps,'<DBLINK>',COREMOD_API.get_dblink_for_query(p_dblink)) into gTargetSNAP_START, gTargetSNAP_END using p_start_dt, p_end_dt;
  end;

  function show_remote_date_context(p_dblink opas_db_links.db_link_name%type) return varchar2
  is
  begin
    get_remote_data(p_dblink);
    commit;
    execute immediate 'ALTER SESSION CLOSE DATABASE LINK '||p_dblink;
    return 'Current time: '||to_char(gTargetCurrTS_TZ,'YYYY-MM-DD HH24:MI:SS.FF3 TZH:TZM') || '; Oldes V$ASH data: ' || to_char(gTargetMinASHTS,'YYYY-MM-DD HH24:MI:SS') || ' ' || gTargetTZ;
  exception
    when others then return 'Error for "'||p_dblink|| '": '||sqlerrm;
  end;

  procedure init_execution_context(p_obj_id  opas_objects.obj_id%type)
  is
  begin

    gTargetTZ         := null;
    gTargetMinASHTS   := null;  gTargetMinASHTS_UTC := null;
    gTargetIncarnation:= null;
    gTargetDBID       := null;
    gTargetCurrTS_TZ  := null;
    gTargetCurrTS     := null;  gTargetCurrTS_UTC := null;

    gTargetSNAP_START := null;
    gTargetSNAP_END   := null;

    load_params(p_obj_id);
    get_remote_data(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));

    select dbid into gTargetDBID from OPAS_DB_LINKS where DB_LINK_NAME = COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK);

    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetTZ "'||gTargetTZ||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetMinASHTS "'||to_char(gTargetMinASHTS,'YYYY-MM-DD HH24:MI:SS.FF3')||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetMinASHTS_UTC "'||to_char(gTargetMinASHTS_UTC,'YYYY-MM-DD HH24:MI:SS.FF3')||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetCurrTS_TZ "'||to_char(gTargetCurrTS_TZ,'YYYY-MM-DD HH24:MI:SS.FF3 TZH:TZM')||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetCurrTS "'||to_char(gTargetCurrTS,'YYYY-MM-DD HH24:MI:SS.FF3')||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetCurrTS_UTC "'||to_char(gTargetCurrTS_UTC,'YYYY-MM-DD HH24:MI:SS.FF3')||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetIncarnation "'||gTargetIncarnation||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetDBID "'||gTargetDBID||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetSNAP_START "'||gTargetSNAP_START||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.init_execution_context: gTargetSNAP_END "'||gTargetSNAP_END||'"', gLogLevel);

  end;

  procedure set_range_status(p_asharange_id opas_ot_ashacube_ranges.asharange_id%type,
                             p_status_old varchar2,
                             p_status_new varchar2)
  is
    pragma autonomous_transaction;
  begin
    update opas_ot_ashacube_ranges set  status = p_status_new, MODIFIED = systimestamp where asharange_id = p_asharange_id and status = p_status_old;
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.set_range_status: p_asharange_id -> p_status_new "'|| p_asharange_id ||' -> '|| p_status_new ||'" rows: '|| sql%rowcount, gLogLevel);
    commit;
  end;

  procedure get_granule(p_type varchar2,
                        p_asharange_id opas_ot_ashacube_ranges.asharange_id%type,
                        p_start_dt timestamp,
                        p_end_dt timestamp,
                        p_rows in out number)
  is
    l_iter number := 0;
  begin
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_granule(p_asharange_id): "'|| p_asharange_id ||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_granule: p_type "'|| p_type ||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_granule: p_start_dt "'|| to_char(p_start_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_granule: p_end_dt "'|| to_char(p_end_dt,'YYYY/MM/DD HH24:MI:SS.FF9') ||'"', gLogLevel);

    set_range_status(p_asharange_id, csNEW, csInProgress);

    for i in (select * from opas_ot_ashacube_ranges where asharange_id = p_asharange_id and status = csInProgress for update skip locked) loop
        l_iter := l_iter + 1; --for logging
        delete from OPAS_OT_TMP_GV$ASH;

        case p_type
          when gtGV$ASH then
            begin
                COREMOD_API.load_tmp_data (
                  P_DB_LINK_NAME => COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK),
                  P_SRC_TABLE_NAME_R => 'GV_$ACTIVE_SESSION_HISTORY',
                  P_SRC_TABLE_NAME => 'GV$ACTIVE_SESSION_HISTORY',
                  P_TRG_TABLE_NAME => 'OPAS_OT_TMP_GV$ASH',
                  P_SUFF => 'GV$ASH',
                  p_key_pref => 'LOCTABCOLS',
                  --P_DBID => null,
                  P_FILTER => q'[sample_time between to_timestamp(']' || to_char(p_start_dt,'YYYYMMDDHH24MISS') || q'[','YYYYMMDDHH24MISS') and to_timestamp(']' || to_char(p_end_dt,'YYYYMMDDHH24MISS') || q'[','YYYYMMDDHH24MISS')]'
                  );
              update OPAS_OT_ASHACUBE_RANGES set
                     SAMPLE_TP = case when SAMPLE_TP = gtDBA_HIST_ASH then gtGV$ASHAWR else gtGV$ASH end,
                     MODIFIED = systimestamp
               where ASHARANGE_ID = p_asharange_id;
            end;
          when gtDBA_HIST_ASH then
            begin
                COREMOD_API.load_tmp_data (
                  P_DB_LINK_NAME => COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK),
                  P_SRC_TABLE_NAME_R => 'DBA_HIST_ACTIVE_SESS_HISTORY',
                  P_SRC_TABLE_NAME => 'DBA_HIST_ACTIVE_SESS_HISTORY',
                  P_TRG_TABLE_NAME => 'OPAS_OT_TMP_GV$ASH',
                  P_SUFF => 'HIST_ASH',
                  p_key_pref => 'LOCTABCOLS',
                  P_DBID => gTargetDBID,
                  P_FILTER => q'[sample_time between to_timestamp(']' || to_char(p_start_dt,'YYYYMMDDHH24MISS') || q'[','YYYYMMDDHH24MISS') and to_timestamp(']' || to_char(p_end_dt,'YYYYMMDDHH24MISS') || q'[','YYYYMMDDHH24MISS')]'
                              || ' and instance_number>0 and snap_id between ' || gTargetSNAP_START || ' and ' || gTargetSNAP_END
                  );
              update OPAS_OT_ASHACUBE_RANGES set MIN_SNAP_ID = gTargetSNAP_START, MAX_SNAP_ID = gTargetSNAP_END,
                     SAMPLE_TP = case when SAMPLE_TP = gtGV$ASH then gtGV$ASHAWR else gtDBA_HIST_ASH end,
                     MODIFIED = systimestamp
               where ASHARANGE_ID = p_asharange_id;
            end;
          else
            null;
        end case;

        INSERT INTO opas_ot_ashacube_ash (
          asharange_id, dblink, snap_id, instance_number, sample_time, sample_time_utc, session_id, session_serial#, session_type,
          user_id, username, osuser, sql_id, sql_child_number, sql_opname, force_matching_signature, top_level_sql_id, sql_plan_hash_value,
          sql_full_plan_hash_value, sql_plan_line_id, sql_plan_operation, sql_plan_options, sql_exec_id, sql_exec_start, plsql_entry_object_id,
          plsql_entry_subprogram_id, plsql_object_id, plsql_subprogram_id, qc_instance_id, qc_session_id, qc_session_serial#, px_flags, event,
          state, wait_class, blocking_session_status, blocking_session, blocking_session_serial#, blocking_inst_id, final_blocking_session_status,
          final_blocking_instance, final_blocking_session, current_obj#, current_file#, current_block#, current_row#, consumer_group_id, xid,
          program, module, action, client_id, machine, port, ecid, terminal, tm_delta_time, tm_delta_cpu_time, tm_delta_db_time, delta_time,
          delta_read_io_requests, delta_write_io_requests, delta_read_io_bytes, delta_write_io_bytes, delta_interconnect_io_bytes, delta_read_mem_bytes,
          pga_allocated, temp_space_allocated)
        select
          p_asharange_id, COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK), null snap_id, instance_number, sample_time, nvl(sample_time_utc,SYS_EXTRACT_UTC(from_tz(sample_time,gTargetTZ))), session_id, session_serial#, session_type,
          user_id, username, osuser, sql_id, sql_child_number, sql_opname, force_matching_signature, top_level_sql_id, sql_plan_hash_value,
          sql_full_plan_hash_value, sql_plan_line_id, sql_plan_operation, sql_plan_options, sql_exec_id, sql_exec_start, plsql_entry_object_id,
          plsql_entry_subprogram_id, plsql_object_id, plsql_subprogram_id, qc_instance_id, qc_session_id, qc_session_serial#, px_flags, event,
          state, wait_class, blocking_session_status, blocking_session, blocking_session_serial#, blocking_inst_id, final_blocking_session_status,
          final_blocking_instance, final_blocking_session, current_obj#, current_file#, current_block#, current_row#, consumer_group_id, xid,
          program, module, action, client_id, machine, port, ecid, terminal, tm_delta_time, tm_delta_cpu_time, tm_delta_db_time, delta_time,
          delta_read_io_requests, delta_write_io_requests, delta_read_io_bytes, delta_write_io_bytes, delta_interconnect_io_bytes, delta_read_mem_bytes,
          pga_allocated, temp_space_allocated
        from OPAS_OT_TMP_GV$ASH;
        p_rows := sql%rowcount;

        commit;
        set_range_status(p_asharange_id, csInProgress, case when p_rows>0 then csReady else csEmpty end);
    end loop;

    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_granule(p_asharange_id): p_rows; l_iter: "'||p_asharange_id || ': ' ||p_rows|| '; ' || l_iter || '"', gLogLevel);
  end;

  procedure sample_data_for_granule(p_asharange_id opas_ot_ashacube_ranges.asharange_id%type)
  is
    l_range opas_ot_ashacube_ranges%rowtype;
    L_ASHACUBE_ID OPAS_OT_ASHACUBE.ASHACUBE_ID%type;
    l_iter number := 0;
    l_rows number;
    l_sampling_interval number := 100; --santisecs
    l_start_time        number;
    l_sleep_time        number;
    l_sql               varchar2(32765);
  begin
    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_ASHA_CUBE_CALCS.SAMPLE_DATA_FOR_GRANULE.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_ASHA_CUBE_CALCS.SAMPLE_DATA_FOR_GRANULE.SQL_TRACE');

    set_range_status(p_asharange_id, csNEW, csInProgress);
    select * into l_range from opas_ot_ashacube_ranges where asharange_id = p_asharange_id for update skip locked;
    select ASHACUBE_ID into L_ASHACUBE_ID from OPAS_OT_ASHACUBE_REF where ASHARANGE_ID = p_asharange_id;

    init_execution_context(L_ASHACUBE_ID);

    --get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule: gTargetCurrTS_UTC "'||to_char(gTargetCurrTS_UTC,'YYYY-MM-DD HH24:MI:SS.FF3')||'"', gLogLevel);

    if gTargetCurrTS_UTC >= l_range.START_TIME_UTC - INTERVAL '10' SECOND and gTargetCurrTS_UTC < l_range.END_TIME_UTC + INTERVAL '10' SECOND then

      l_sql := COREMOD_API.get_tmp_load_query(
        P_DB_LINK_NAME => l_range.DBLINK,
        P_SRC_TABLE_NAME_R => 'GV_$SESSION',
        P_SRC_TABLE_NAME => 'GV$SESSION',
        P_TRG_TABLE_NAME => 'OPAS_OT_TMP_GV$SESSION',
        P_SUFF => 'GV$SESS',
        P_DBID => null,
        P_KEY_PREF => 'TABCOLLIST',
        P_FILTER => q'[status='ACTIVE' and type='USER']',
        p_timestamp_col => 'TS');

      coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule: Sampling SQL "'||l_sql||'"', gLogLevel);

      delete from OPAS_OT_TMP_GV$ASH;

      l_start_time := DBMS_UTILITY.GET_TIME;
      loop
        --sampling
        execute immediate l_sql;

        l_sleep_time := l_sampling_interval - (DBMS_UTILITY.GET_TIME-l_start_time);
        if l_sleep_time > 0.01 then
          dbms_lock.sleep(l_sleep_time);
        end if;
        l_iter := l_iter + 1; --for logging
        if mod(l_iter,10) = 0 then
          get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));
        end if;
        exit when gTargetCurrTS_UTC >= l_range.END_TIME_UTC + INTERVAL '10' SECOND or gGranulaSize < 1 + l_iter*(l_sampling_interval/100)/60;
        l_start_time := DBMS_UTILITY.GET_TIME;
      end loop;
    end if;

    l_sql :=
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
        :p_asharange_id, :DBLINK, null snap_id, inst_id,       lts at time zone ']' || gTargetTZ || q'[', SYS_EXTRACT_UTC(lts),
        SID, SERIAL#, TYPE,
        USER#, USERNAME, OSUSER, sql_id, sql_child_number, null sql_opname, null force_matching_signature, null top_level_sql_id, null sql_plan_hash_value,
        null sql_full_plan_hash_value, null sql_plan_line_id, null sql_plan_operation, null sql_plan_options, sql_exec_id, sql_exec_start, plsql_entry_object_id,
        plsql_entry_subprogram_id, plsql_object_id, plsql_subprogram_id, null qc_instance_id, null qc_session_id, null qc_session_serial#, null px_flags, event,
        state, wait_class, blocking_session_status, blocking_session, null blocking_session_serial#, blocking_instance, final_blocking_session_status,
        final_blocking_instance, final_blocking_session, null current_obj#, null current_file#, null current_block#, null current_row#, null consumer_group_id, null xid,
        program, module, action, CLIENT_IDENTIFIER client_id, machine, port, ecid, terminal, null tm_delta_time, null tm_delta_cpu_time, null tm_delta_db_time, null delta_time,
        null delta_read_io_requests, null delta_write_io_requests, null delta_read_io_bytes, null delta_write_io_bytes, null delta_interconnect_io_bytes, null delta_read_mem_bytes,
        null pga_allocated, null temp_space_allocated
    from OPAS_OT_TMP_GV$SESSION where SYS_EXTRACT_UTC(lts) >= :START_TIME_UTC and SYS_EXTRACT_UTC(lts) < :END_TIME_UTC]';

    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule: Loading SQL "'||l_sql||'"', gLogLevel);
    execute immediate l_sql using p_asharange_id, l_range.DBLINK, l_range.START_TIME_UTC, l_range.END_TIME_UTC;

    l_rows := sql%rowcount;

    commit;
    set_range_status(p_asharange_id, csInProgress, case when l_rows>0 then csReady else csEmpty end);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_granule(p_asharange_id): p_rows; l_iter: "'|| p_asharange_id || ': ' ||l_rows|| '; ' || l_iter || '"', gLogLevel);

    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_ASHA_CUBE_CALCS.SAMPLE_DATA_FOR_GRANULE.GATHER_SQL_STAT');
    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_ASHA_CUBE_CALCS.SAMPLE_DATA_FOR_GRANULE.SQL_TRACE');
  exception
    when others then
      coremod_tasks.log('Error COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule ('||p_asharange_id||'): '||sqlerrm);
      coremod_tasks.log('Error COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule error stack: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      raise_application_error(-20000, 'Error COREOBJ_ASHA_CUBE_CALCS.sample_data_for_granule ('||p_asharange_id||'): '||sqlerrm);
  end;

  procedure get_ash_data(p_obj_id  opas_objects.obj_id%type)
  is
    l_asharange_id opas_ot_ashacube_ranges.asharange_id%type;
    l_granula_rows_added number;
    l_start_time_trg_tz timestamp;
    l_end_time_trg_tz   timestamp;
    l_grnl_idx          number;

    l_granules t_granules;
    l_awr_boundary crsr_granules%rowtype;

    l_lops_ind          pls_integer;
    l_lops_iter         pls_integer;
    l_ModuleName        varchar2(100) := 'ASHA Cube gathering: ';

    l_in_progress       number;
    l_ready             number;
    l_tq_id             OPAS_TASK_QUEUE.tq_id%type;
  begin
    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_ASHA_CUBE_CALCS.GET_ASHA_DATA.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_ASHA_CUBE_CALCS.GET_ASHA_DATA.SQL_TRACE');

    init_execution_context(p_obj_id);

    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: p_obj_id: "'|| p_obj_id ||'"', gLogLevel);
    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: target edition: "'|| case when gTargetMinASHTS is not null then 'Enterprise' else 'Standard' end ||'"', gLogLevel);
    --================================================================================================
    set_lock(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));

    open crsr_granules (p_obj_id, COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK), trunc(gTargetMinASHTS,'MI'), gTargetCurrTS);
    fetch crsr_granules bulk collect into l_granules;
    close crsr_granules;

    for i in 1..l_granules.count loop
      if gTargetMinASHTS is not null or -- enterprise edition
         gTargetMinASHTS is null and l_granules(i).end_granula_dt >= gTargetCurrTS_UTC --standard edition, only for future time ranges
      then
        if l_granules(i).asharange_id is null then
            INSERT INTO opas_ot_ashacube_ranges (
              dblink, sample_tp, start_time_utc, end_time_utc, incarnation#, status, created, DBID)
            VALUES (
              COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK),
              case when gTargetMinASHTS is null then gtSamplGV$SESS else null end,
              l_granules(i).start_granula_dt, l_granules(i).end_granula_dt, gTargetIncarnation, csNew, systimestamp, gTargetDBID
            ) returning asharange_id into l_granules(i).asharange_id;
            coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: new granula: "'|| l_granules(i).asharange_id ||'"', gLogLevel);
        end if;
      end if;
      if l_granules(i).ashacube_id is null and l_granules(i).asharange_id is not null then
        INSERT INTO OPAS_OT_ASHACUBE_REF ( ASHACUBE_ID, ASHARANGE_ID) VALUES (p_obj_id, l_granules(i).asharange_id);
        coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data granula: linked: "'|| l_granules(i).asharange_id ||'"', gLogLevel);
      end if;
    end loop;

    commit;
    COREMOD_API.release_resource;

    update OPAS_OT_ASHACUBE set STATUS = csInProgress, MODIFIED = systimestamp where ASHACUBE_ID = p_obj_id and STATUS = csNEW;
    commit;
    --================================================================================================

    open crsr_granules (p_obj_id, COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK), trunc(gTargetMinASHTS,'MI'), gTargetCurrTS);
    fetch crsr_granules bulk collect into l_granules;
    close crsr_granules;

    coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: granuls in queue: "'|| l_granules.count ||'"', gLogLevel);

    coremod_api.init_longops(p_op_name => l_ModuleName,
                             p_target_desc => 'ranges',
                             p_units => 'range',
                             p_totalwork => l_granules.count,
                             p_lops_ind => l_lops_ind);

    l_lops_iter := 0;

    if gTargetMinASHTS is not null then -- enterprise edition
      for i in 1..l_granules.count loop

        coremod_api.start_longops_section(p_module_name => l_ModuleName,
                                          p_action_name => 'Range: '||to_char(l_granules(i).start_granula_dt,'YYYY/MM/DD HH24:MI')|| ' - ' ||to_char(l_granules(i).end_granula_dt,'YYYY/MM/DD HH24:MI'));

        execute immediate q'[select cast(to_timestamp_tz(']' || to_char(l_granules(i).start_granula_dt,'YYYYMMDDHH24MISS')||' 00:00' || q'[','YYYYMMDDHH24MISS TZH:TZM') at time zone ']' ||gTargetTZ|| q'[' as timestamp) from dual]'
          into l_start_time_trg_tz;
        execute immediate q'[select cast(to_timestamp_tz(']' || to_char(l_granules(i).end_granula_dt,'YYYYMMDDHH24MISS')||' 00:00' || q'[','YYYYMMDDHH24MISS TZH:TZM') at time zone ']' ||gTargetTZ|| q'[' as timestamp) from dual]'
          into l_end_time_trg_tz;

        coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: l_start_time_trg_tz: "'|| l_start_time_trg_tz ||'"', gLogLevel);
        coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: l_end_time_trg_tz: "'|| l_end_time_trg_tz ||'"', gLogLevel);
        coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: l_granules(i).start_granula_dt: "'||to_char(l_granules(i).start_granula_dt,'YYYY/MM/DD HH24:MI')||'"', gLogLevel);
        coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: l_granules(i).end_granula_dt: "'||to_char(l_granules(i).end_granula_dt,'YYYY/MM/DD HH24:MI')||'"', gLogLevel);

        get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));


        if gTargetCurrTS >= l_end_time_trg_tz then
          if gTargetMinASHTS <= l_start_time_trg_tz then
            coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: full V$ASH granula', gLogLevel);
            get_granule(gtGV$ASH, l_granules(i).asharange_id, l_start_time_trg_tz, l_end_time_trg_tz, l_granula_rows_added);
          elsif gTargetMinASHTS >= l_start_time_trg_tz and gTargetMinASHTS <= l_end_time_trg_tz then
            coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: partial V$ASH granula', gLogLevel);
            get_granule(gtGV$ASH, l_granules(i).asharange_id, gTargetMinASHTS, l_end_time_trg_tz, l_granula_rows_added);
          end if;

          if gTargetMinASHTS >= l_start_time_trg_tz and gTargetMinASHTS <= l_end_time_trg_tz then
            l_awr_boundary:=l_granules(i);
            l_awr_boundary.start_time_utc := l_start_time_trg_tz;
          elsif gTargetMinASHTS >= l_start_time_trg_tz then
            if l_awr_boundary.asharange_id is not null then
              coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: partial V$ASH granula adding AWR ASH', gLogLevel);
              get_granule(gtDBA_HIST_ASH, l_awr_boundary.asharange_id, l_awr_boundary.start_time_utc, gTargetMinASHTS, l_granula_rows_added);
              l_awr_boundary.asharange_id := null;
            end if;
            coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: full AWR granula', gLogLevel);
            get_granule(gtDBA_HIST_ASH, l_granules(i).asharange_id, l_start_time_trg_tz, l_end_time_trg_tz, l_granula_rows_added);
          end if;
        else
          coremod_api.start_longops_section(p_module_name => l_ModuleName,
                                            p_action_name => 'Range: '||to_char(l_granules(i).start_granula_dt,'YYYY/MM/DD HH24:MI')|| ' - ' ||to_char(l_granules(i).end_granula_dt,'YYYY/MM/DD HH24:MI'));
          loop
            dbms_lock.sleep(30);
            get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));
            coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: waiting gTargetCurrTS < l_end_time_trg_tz: '||to_char(gTargetCurrTS,'YYYY/MM/DD HH24:MI:SS') ||' < '||to_char(l_end_time_trg_tz,'YYYY/MM/DD HH24:MI:SS'), gLogLevel);
            exit when gTargetCurrTS < l_end_time_trg_tz;
          end loop;

          coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: full V$ASH granula after wait', gLogLevel);
          get_granule(gtGV$ASH, l_granules(i).asharange_id, l_start_time_trg_tz, l_end_time_trg_tz, l_granula_rows_added);

        end if;

        l_lops_iter := l_lops_iter + 1;
        coremod_api.end_longops_section(p_sofar => l_lops_iter, p_lops_ind => l_lops_ind);
      end loop;
    else --standard edition, sampling
      l_ModuleName := 'ASHA Cube sampling: ';
      for i in 1..l_granules.count loop
        coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: sampling V$SESS granula: '||l_granules(i).asharange_id, gLogLevel);
        coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: l_granules(i).start_granula_dt: "'||to_char(l_granules(i).start_granula_dt,'YYYY/MM/DD HH24:MI')||'"', gLogLevel);
        coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: l_granules(i).end_granula_dt: "'||to_char(l_granules(i).end_granula_dt,'YYYY/MM/DD HH24:MI')||'"', gLogLevel);
        --get_sample_granule(l_granules);NUMTODSINTERVAL

        coremod_api.start_longops_section(p_module_name => l_ModuleName,
                                          p_action_name => 'Range: '||to_char(l_granules(i).start_granula_dt,'YYYY/MM/DD HH24:MI')|| ' - ' ||to_char(l_granules(i).end_granula_dt,'YYYY/MM/DD HH24:MI'));

        get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));

        if gTargetCurrTS_UTC <= l_granules(i).START_TIME_UTC - INTERVAL '60' SECOND then
          loop
            get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));
            exit when gTargetCurrTS_UTC >= l_granules(i).START_TIME_UTC - INTERVAL '60' SECOND;
            dbms_lock.sleep(15);
          end loop;
        end if;

        if gTargetCurrTS_UTC >= l_granules(i).START_TIME_UTC - INTERVAL '60' SECOND and gTargetCurrTS_UTC < l_granules(i).END_TIME_UTC - INTERVAL '60' SECOND then

          l_tq_id:=COREMOD_TASKS.prep_execute_task (  P_TASKNAME => 'OPAS_ASHA_GRNLSMPL') ;
          COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => 'B1', p_num_par => l_granules(i).asharange_id);
          COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id ) ;
          commit;
          coremod_log.log('COREOBJ_ASHA_CUBE_CALCS.get_ash_data: sampling V$SESS granula queued: '||l_granules(i).asharange_id, gLogLevel);

        end if;

        l_lops_iter := l_lops_iter + 1;
        coremod_api.end_longops_section(p_sofar => l_lops_iter, p_lops_ind => l_lops_ind);
      end loop;
    end if;

    store_params(p_obj_id);

    select
           sum(decode(r.STATUS,csInProgress,1,0)),
           sum(decode(r.STATUS,csReady,1,0))
           into l_in_progress, l_ready
      from OPAS_OT_ASHACUBE_RANGES r, OPAS_OT_ASHACUBE_REF f
     where r.ASHARANGE_ID = f.ASHARANGE_ID and f.ASHACUBE_ID=p_obj_id;

    update OPAS_OT_ASHACUBE set
      STATUS = case when l_in_progress>0 then csInProgress when l_in_progress=0 and l_ready > 0 then csReady else csEmpty end,
      MODIFIED = systimestamp where ASHACUBE_ID = p_obj_id and STATUS = csInProgress;
    commit;

    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_ASHA_CUBE_CALCS.GET_ASHA_DATA.SQL_TRACE');
    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_ASHA_CUBE_CALCS.GET_ASHA_DATA.GATHER_SQL_STAT');
  exception
    when others then
      COREMOD_API.release_resource;
      coremod_tasks.log('Error COREOBJ_ASHA_CUBE_CALCS.get_ash_data ('||p_obj_id||'): '||sqlerrm);
      coremod_tasks.log('Error COREOBJ_ASHA_CUBE_CALCS.get_ash_data error stack: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      raise_application_error(-20000, 'Error COREOBJ_ASHA_CUBE_CALCS.get_ash_data ('||p_obj_id||'): '||sqlerrm);
  end;

END COREOBJ_ASHA_CUBE_CALCS;
/


