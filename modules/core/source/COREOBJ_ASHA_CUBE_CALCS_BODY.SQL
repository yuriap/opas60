

CREATE OR REPLACE
PACKAGE BODY COREOBJ_ASHA_CUBE_CALCS AS

  gJSParams             COREOBJ_API.t_params;
  gTABParams            COREOBJ_API.t_params;

  gTargetTZ             varchar2(10);
  gTargetMinASHTS       timestamp; -- with time zone;
  gTargetIncarnation    number;
  gTargetDBID           number;
  gTargetCurrTS_TZ      timestamp with time zone;
  gTargetCurrTS         timestamp;
  gTargetSNAP_START     number;
  gTargetSNAP_END       number;

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
      || q'[), systimestamp, LOCALTIMESTAMP from V$ASH_INFO]'||COREMOD_API.get_dblink_for_query(p_dblink);
      --q'[select TZ_OFFSET(dbtimezone), to_timestamp_tz(to_char(oldest_sample_time,'YYYYMMDDHH24MISS.FF3')||' '||TZ_OFFSET(dbtimezone),'YYYYMMDDHH24MISS.FF3 TZH:TZM') from V$ASH_INFO]'||COREMOD_API.get_dblink_for_query(p_dblink);
    execute immediate l_sql into gTargetTZ, gTargetMinASHTS, gTargetIncarnation, gTargetCurrTS_TZ, gTargetCurrTS;
  end;

  procedure get_remote_curr_ts(p_dblink opas_db_links.db_link_name%type)
  is
    l_sql  varchar2(1000);
  begin
    l_sql := q'[select LOCALTIMESTAMP from dual]'||COREMOD_API.get_dblink_for_query(p_dblink);
    execute immediate l_sql into gTargetCurrTS;
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
    gTargetMinASHTS   := null;
    gTargetIncarnation:= null;
    gTargetDBID       := null;
    gTargetCurrTS_TZ  := null;
    gTargetCurrTS     := null;

    gTargetSNAP_START := null;
    gTargetSNAP_END   := null;

    load_params(p_obj_id);
    get_remote_data(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));

    select dbid into gTargetDBID from OPAS_DB_LINKS where DB_LINK_NAME = COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK);
  end;

  procedure get_granule(p_type varchar2,
                        p_asharange_id opas_ot_ashacube_ranges.asharange_id%type,
                        p_start_dt timestamp,
                        p_end_dt timestamp,
                        p_rows in out number)
  is
  begin
    for i in (select * from opas_ot_ashacube_ranges where asharange_id = p_asharange_id for update skip locked) loop
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
    end loop;
    commit;
--coremod_log.log('COREMOD_API.get_ash_granule: '||p_rows,'INFO');
  end;

  procedure get_ash_data(p_obj_id  opas_objects.obj_id%type)
  is
    l_asharange_id opas_ot_ashacube_ranges.asharange_id%type;
    l_granula_rows_added number;
    l_start_time_trg_tz timestamp;
    l_end_time_trg_tz   timestamp;
    l_grnl_idx          number;

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
                   floor(24 * 60 * (trunc(START_TIME_UTC,'MI') - trunc(START_TIME_UTC, 'hh')) / 15) * 15 / 24 / 60 real_start_date,
                   trunc(END_TIME_UTC, 'hh') +
                   ceil(24 * 60 * (trunc(END_TIME_UTC,'MI') - trunc(END_TIME_UTC, 'hh')) / 15) * 15 / 24 / 60 real_end_date--,
                   --START_TIME_UTC, END_TIME_UTC
              from input_pars),
          dt_boundaries as
           (select level rn,min_ash,curr_dt,
                   real_start_date + (level-1) /(24*4) start_granula_dt,
                   real_start_date + (level) /(24*4) end_granula_dt
              from dual, adj_input_pars
            connect by level <= ((real_end_date - real_start_date) * 24 * 4))
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
    l_granules t_granules;
    l_awr_boundary crsr_granules%rowtype;

    l_lops_ind          pls_integer;
    l_lops_iter         pls_integer;
    l_ModuleName        varchar2(100) := 'ASHA Cube gathering: ';
  begin
    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_ASHA_CUBE_CALCS.GET_ASHA_DATA.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_ASHA_CUBE_CALCS.GET_ASHA_DATA.SQL_TRACE');

    init_execution_context(p_obj_id);

    --================================================================================================
    set_lock(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));

    open crsr_granules (p_obj_id, COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK), trunc(gTargetMinASHTS,'MI'), gTargetCurrTS);
    fetch crsr_granules bulk collect into l_granules;
    close crsr_granules;

    for i in 1..l_granules.count loop
      if l_granules(i).asharange_id is null then
          INSERT INTO opas_ot_ashacube_ranges (
            dblink, sample_tp, start_time_utc, end_time_utc, incarnation#, status, created)
          VALUES (
            COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK), null, l_granules(i).start_granula_dt, l_granules(i).end_granula_dt, gTargetIncarnation, csNew, systimestamp
          );
      end if;
      if l_granules(i).ashacube_id is null then
        INSERT INTO OPAS_OT_ASHACUBE_REF ( ASHACUBE_ID, ASHARANGE_ID) VALUES (p_obj_id, l_granules(i).asharange_id);
      end if;
    end loop;

    commit;
    COREMOD_API.release_resource;
    --================================================================================================

    open crsr_granules (p_obj_id, COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK), trunc(gTargetMinASHTS,'MI'), gTargetCurrTS);
    fetch crsr_granules bulk collect into l_granules;
    close crsr_granules;

    coremod_api.init_longops(p_op_name => l_ModuleName,
                             p_target_desc => 'ranges',
                             p_units => 'range',
                             p_totalwork => l_granules.count,
                             p_lops_ind => l_lops_ind);
    l_lops_iter := 0;
    for i in 1..l_granules.count loop

      coremod_api.start_longops_section(p_module_name => l_ModuleName,
                                        p_action_name => 'Range: '||to_char(l_granules(i).start_granula_dt,'YYYY/MM/DD HH24:MI')|| ' - ' ||to_char(l_granules(i).end_granula_dt,'YYYY/MM/DD HH24:MI'));

      execute immediate q'[select cast(to_timestamp_tz(']' || to_char(l_granules(i).start_granula_dt,'YYYYMMDDHH24MISS')||' 00:00' || q'[','YYYYMMDDHH24MISS TZH:TZM') at time zone ']' ||gTargetTZ|| q'[' as timestamp) from dual]'
          into l_start_time_trg_tz;
      execute immediate q'[select cast(to_timestamp_tz(']' || to_char(l_granules(i).end_granula_dt,'YYYYMMDDHH24MISS')||' 00:00' || q'[','YYYYMMDDHH24MISS TZH:TZM') at time zone ']' ||gTargetTZ|| q'[' as timestamp) from dual]'
          into l_end_time_trg_tz;

--coremod_log.log('i.start_granula_trg_tz: '||i.start_granula_trg_tz,'INFO');
--coremod_log.log('i.end_granula_trg_tz: '||i.end_granula_trg_tz,'INFO');
--coremod_log.log('l_start_time_trg_tz: '||l_start_time_trg_tz,'INFO');
--coremod_log.log('l_end_time_trg_tz: '||l_end_time_trg_tz,'INFO');
--coremod_log.log('i.start_granula_dt: '||i.start_granula_dt,'INFO');
--coremod_log.log('i.end_granula_dt: '||i.end_granula_dt,'INFO');
      get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));

      if gTargetCurrTS >= l_end_time_trg_tz then
        if gTargetMinASHTS <= l_start_time_trg_tz then
          get_granule(gtGV$ASH, l_granules(i).asharange_id, l_start_time_trg_tz, l_end_time_trg_tz, l_granula_rows_added);
        elsif gTargetMinASHTS >= l_start_time_trg_tz and gTargetMinASHTS <= l_end_time_trg_tz then
          get_granule(gtGV$ASH, l_granules(i).asharange_id, gTargetMinASHTS, l_end_time_trg_tz, l_granula_rows_added);
        end if;

        if gTargetMinASHTS >= l_start_time_trg_tz and gTargetMinASHTS <= l_end_time_trg_tz then
          l_awr_boundary:=l_granules(i);
          l_awr_boundary.start_time_utc := l_start_time_trg_tz;
        elsif gTargetMinASHTS >= l_start_time_trg_tz then
          if l_awr_boundary.asharange_id is not null then
            get_granule(gtDBA_HIST_ASH, l_awr_boundary.asharange_id, l_awr_boundary.start_time_utc, gTargetMinASHTS, l_granula_rows_added);
            l_awr_boundary.asharange_id := null;
          end if;
          get_granule(gtDBA_HIST_ASH, l_granules(i).asharange_id, l_start_time_trg_tz, l_end_time_trg_tz, l_granula_rows_added);
        end if;
      else
        coremod_api.start_longops_section(p_module_name => l_ModuleName,
                                          p_action_name => 'Range: '||to_char(l_granules(i).start_granula_dt,'YYYY/MM/DD HH24:MI')|| ' - ' ||to_char(l_granules(i).end_granula_dt,'YYYY/MM/DD HH24:MI'));
        loop
          dbms_lock.sleep(60);
          get_remote_curr_ts(COREOBJ_ASHA_CUBE_CALCS.gp(pDBLINK));
          exit when gTargetCurrTS < l_end_time_trg_tz;
        end loop;
        get_granule(gtGV$ASH, l_granules(i).asharange_id, l_start_time_trg_tz, l_end_time_trg_tz, l_granula_rows_added);

      end if;

      l_lops_iter := l_lops_iter + 1;
      coremod_api.end_longops_section(p_sofar => l_lops_iter, p_lops_ind => l_lops_ind);
    end loop;

    store_params(p_obj_id);
    commit;

    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_ASHA_CUBE_CALCS.GET_ASHA_DATA.SQL_TRACE');
    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_ASHA_CUBE_CALCS.GET_ASHA_DATA.GATHER_SQL_STAT');
  exception
    when others then
      COREMOD_API.release_resource;
      coremod_tasks.log('Error get_ash_data ('||p_obj_id||'): '||sqlerrm);
      coremod_tasks.log('Error get_ash_data error stack: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      raise_application_error(-20000, 'Error get_ash_data ('||p_obj_id||'): '||sqlerrm);
  end;

END COREOBJ_ASHA_CUBE_CALCS;
/


