CREATE OR REPLACE
PACKAGE BODY COREOBJ_SQL_UTILS AS

  gAWRParams   t_awr_params_rec;

  procedure is_section_ready(p_sql_data_point_id      opas_ot_sql_data.sql_data_point_id%type,
                             p_section_name           varchar2,
                             p_status             out opas_ot_sql_data_sect.gathering_status%type,
                             p_errm               out opas_ot_sql_data_sect.error_message%type)
  is
  begin
    select gathering_status, error_message into p_status, p_errm
      from opas_ot_sql_data_sect x
     where sql_data_point_id = p_sql_data_point_id and section_name = p_section_name;
  exception
    when no_data_found then p_status := null; p_errm := null;
  end;

  function  is_section_empty(p_sql_data_point_id      opas_ot_sql_data.sql_data_point_id%type,
                             p_section_name           varchar2) return boolean
  is
    l_status  opas_ot_sql_data_sect.gathering_status%type;
    l_errm    opas_ot_sql_data_sect.error_message%type;
  begin
    is_section_ready(p_sql_data_point_id,p_section_name, l_status, l_errm);
    return l_status=sstEmpty;
  end;

  procedure start_processing(p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type,
                             p_data                  out opas_ot_sql_data%rowtype,
                             p_obj_id                out opas_ot_sql_data_point_ref.obj_id%type)
  is
    pragma autonomous_transaction;
  begin
    begin
      select * into p_data from opas_ot_sql_data where sql_data_point_id = p_sql_data_point_id and gathering_status = COREOBJ_SQL.sdoInQueue for update wait 60;
      select obj_id into p_obj_id from opas_ot_sql_data_point_ref where sql_data_point_id = p_sql_data_point_id;
    exception
      when others then
        raise_application_error(-20000,'Unable to lock SQL Data Object '||p_sql_data_point_id||': '||sqlerrm);
    end;

    update opas_ot_sql_data set gathering_status = COREOBJ_SQL.sdoInProgress, start_gathering_dt = systimestamp where sql_data_point_id = p_sql_data_point_id;

    COREOBJ_API.set_param (  P_OBJ_ID => P_OBJ_ID,
      P_PAR_NAME => pnAllParsDispl,
      P_NUM_PAR => null,
      P_VARCHAR_PAR => COREOBJ_SQL_REPORT_UTILS.print_data_point_params(p_sql_data_point_id),
      P_DATE_PAR => null,
      P_DTTZ_PAR => null);

    commit;
  end;

  procedure start_processing2(p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type,
                              p_data                  out opas_ot_sql_data%rowtype,
                              p_obj_id                out opas_ot_sql_data_point_ref.obj_id%type)
  is
  begin
    select * into p_data from opas_ot_sql_data where sql_data_point_id = p_sql_data_point_id;
    select obj_id into p_obj_id from opas_ot_sql_data_point_ref where sql_data_point_id = p_sql_data_point_id;
  end;

  procedure finish_processing(p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type, p_status opas_ot_sql_data.gathering_status%type default COREOBJ_SQL.sdoREADY)
  is
    pragma autonomous_transaction;
  begin
    update opas_ot_sql_data set gathering_status = p_status, end_gathering_dt = systimestamp where sql_data_point_id = p_sql_data_point_id;
    commit;
  end;

  procedure set_status_prep_recursive(p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type)
  is
    pragma autonomous_transaction;
  begin
    update opas_ot_sql_data set gathering_status = COREOBJ_SQL.sdoPrepRecursive where sql_data_point_id = p_sql_data_point_id;
    commit;
  end;

  procedure wait_processing_of_discovery2(p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type)
  is
    pragma autonomous_transaction;
    l_tq_id                     opas_ot_sql_data.TQ_ID2%type;
  begin
    update opas_ot_sql_data set gathering_status = COREOBJ_SQL.sdoWaitFor2 where sql_data_point_id = p_sql_data_point_id returning TQ_ID2 into l_tq_id;
    commit;

    begin
      coremod_tasks.wait_task_finish(l_tq_id, to_number(COREMOD_API.getconf('SECONDARYTASKTIMEOUT',COREMOD_API.gMODNAME)));
    exception
      when coremod_tasks.exTimedOutTask then
        coremod_tasks.cancel_task(l_tq_id);
    end;

  end;

  procedure init_section_statuses(p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type)
  is
    --pragma autonomous_transaction;
  begin
    INSERT INTO opas_ot_sql_data_sect
        (    sql_data_point_id, section_name, start_gathering_dt, end_gathering_dt, gathering_status)
    select p_sql_data_point_id, x.val,        null,               null,             sstNotStarted
      from opas_dictionary x where dic_name='SQLREPSECT';
    --commit;
  end;


  procedure start_section(p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type,
                          p_section_name varchar2)
  is
    pragma autonomous_transaction;
  begin
    update opas_ot_sql_data_sect
       set start_gathering_dt = systimestamp,
           gathering_status = sstInProgress
     where sql_data_point_id = p_sql_data_point_id and section_name = p_section_name;
    commit;
  end;

  procedure finish_section(p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type,
                           p_section_name varchar2,
                           p_exception    varchar2 default null,
                           p_rows_processed number default 1)
  is
    pragma autonomous_transaction;
  begin
    update opas_ot_sql_data_sect
       set end_gathering_dt = systimestamp,
           gathering_status = case when p_exception is null then case when p_rows_processed > 0 then sstReady else sstEmpty end else sstFailed end,
           error_message    = p_exception
     where sql_data_point_id = p_sql_data_point_id and section_name = p_section_name;
    commit;
  end;

  procedure finalize_section_statuses(p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type)
  is
    pragma autonomous_transaction;
  begin
    delete from opas_ot_sql_data_sect
     where sql_data_point_id = p_sql_data_point_id and gathering_status = sstNotStarted;
    commit;
  end;
  -------------------------------------------------
  -------------------------------------------------
  -------------------------------------------------
  procedure load_sql_text(p_data   opas_ot_sql_data%rowtype)
  is
    l_sql clob;
    l_file_id opas_files.file_id%type;
    l_rows number := 1;
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQL_TEXT);

    for i in (select * from opas_ot_sql_descriptions where sql_id=p_data.sql_id and sql_text is null) loop
      if p_data.dblink <> '$LOCAL$' then
        COREMOD_UTILS.get_clob_remotelly(q'[select sql_fulltext into l_out from gv$sql where sql_id=']' || p_data.sql_id || q'[' and rownum=1;]',
                                         COREMOD_API.get_ora_dblink(p_data.dblink),
                                         l_sql);
        if l_sql = '<NO_DATA_FOUND>' then
          COREMOD_UTILS.get_clob_remotelly(q'[select sql_text into l_out from dba_hist_sqltext where sql_id=']' || p_data.sql_id || q'[';]',
                                           COREMOD_API.get_ora_dblink(p_data.dblink),
                                           l_sql);
        end if;
      else
        begin
          select sql_text into l_sql from
            (
              select sql_fulltext sql_text from gv$sql where sql_id=p_data.sql_id
              union all
              select sql_text from dba_hist_sqltext where sql_id=p_data.sql_id
            )
          where rownum = 1;
        exception
          when no_data_found then l_sql := '<NO_DATA_FOUND>';
        end;
      end if;
      if l_sql != '<NO_DATA_FOUND>' then
        l_file_id := COREMOD_FILE_UTILS.create_file(P_MODNAME => COREMOD_API.gMODNAME,
                                                    P_FILE_TYPE => 'SQL Text',
                                                    P_FILE_NAME => i.sql_id,
                                                    P_MIMETYPE  => COREMOD_FILE_UTILS.mtTEXT,
                                                    P_OWNER     => i.created_by);
        COREMOD_FILE_UTILS.store_content(l_file_id,l_sql);
        update opas_ot_sql_descriptions set
          sql_text            = l_file_id,
          first_discovered    = systimestamp,
          FIRST_DISCOVERED_AT = p_data.dblink
        where sql_id = p_data.sql_id;
      else
        l_rows := 0;
      end if;
    end loop;

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQL_TEXT, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      coremod_tasks.log('Error load_sql_text ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQL_TEXT, sqlerrm);
  end;

  procedure load_non_shared(p_data   opas_ot_sql_data%rowtype)
  is
    l_sql varchar2(32765);
    l_rows number;
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSHARING);

    -- https://timurakhmadeev.wordpress.com/2012/03/15/vsql-is_obsolete/
    l_sql :=
        q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_NONSHARED */ INTO opas_ot_sql_nonshared (
              sql_data_point_id, sql_id, inst_id, nonshared_reason, cnt)
           select :p_sql_data_point_id, sql_id, inst_id, nonshared_reason, cnt from
          (select inst_id, sql_id, nonshared_reason, count(*) cnt from (select inst_id,sql_id,
             UNBOUND_CURSOR,SQL_TYPE_MISMATCH,OPTIMIZER_MISMATCH,OUTLINE_MISMATCH,STATS_ROW_MISMATCH,LITERAL_MISMATCH,FORCE_HARD_PARSE,
             EXPLAIN_PLAN_CURSOR,BUFFERED_DML_MISMATCH,PDML_ENV_MISMATCH,INST_DRTLD_MISMATCH,SLAVE_QC_MISMATCH,TYPECHECK_MISMATCH,
             AUTH_CHECK_MISMATCH,BIND_MISMATCH,DESCRIBE_MISMATCH,LANGUAGE_MISMATCH,TRANSLATION_MISMATCH,BIND_EQUIV_FAILURE,INSUFF_PRIVS,
             INSUFF_PRIVS_REM,REMOTE_TRANS_MISMATCH,LOGMINER_SESSION_MISMATCH,INCOMP_LTRL_MISMATCH,OVERLAP_TIME_MISMATCH,EDITION_MISMATCH,
             MV_QUERY_GEN_MISMATCH,USER_BIND_PEEK_MISMATCH,TYPCHK_DEP_MISMATCH,NO_TRIGGER_MISMATCH,FLASHBACK_CURSOR,ANYDATA_TRANSFORMATION,
             PDDL_ENV_MISMATCH,TOP_LEVEL_RPI_CURSOR,DIFFERENT_LONG_LENGTH,LOGICAL_STANDBY_APPLY,DIFF_CALL_DURN,BIND_UACS_DIFF,PLSQL_CMP_SWITCHS_DIFF,
             CURSOR_PARTS_MISMATCH,STB_OBJECT_MISMATCH,CROSSEDITION_TRIGGER_MISMATCH,PQ_SLAVE_MISMATCH,TOP_LEVEL_DDL_MISMATCH,MULTI_PX_MISMATCH,
             BIND_PEEKED_PQ_MISMATCH,MV_REWRITE_MISMATCH,ROLL_INVALID_MISMATCH,OPTIMIZER_MODE_MISMATCH,PX_MISMATCH,MV_STALEOBJ_MISMATCH,FLASHBACK_TABLE_MISMATCH,
             LITREP_COMP_MISMATCH,PLSQL_DEBUG,LOAD_OPTIMIZER_STATS,ACL_MISMATCH,FLASHBACK_ARCHIVE_MISMATCH,LOCK_USER_SCHEMA_FAILED,REMOTE_MAPPING_MISMATCH,
             LOAD_RUNTIME_HEAP_FAILED,HASH_MATCH_FAILED,PURGED_CURSOR,BIND_LENGTH_UPGRADEABLE,USE_FEEDBACK_STATS
          from gv$sql_shared_cursor]' || COREMOD_API.get_dblink_for_query(p_data.dblink) ||
          q'[ where sql_id = :p_sql_id) unpivot
            (nonshared_value for nonshared_reason in (
               UNBOUND_CURSOR as 'UNBOUND_CURSOR', SQL_TYPE_MISMATCH as 'SQL_TYPE_MISMATCH', OPTIMIZER_MISMATCH as 'OPTIMIZER_MISMATCH', OUTLINE_MISMATCH as 'OUTLINE_MISMATCH',
               STATS_ROW_MISMATCH as 'STATS_ROW_MISMATCH', LITERAL_MISMATCH as 'LITERAL_MISMATCH', FORCE_HARD_PARSE as 'FORCE_HARD_PARSE', EXPLAIN_PLAN_CURSOR as 'EXPLAIN_PLAN_CURSOR',
               BUFFERED_DML_MISMATCH as 'BUFFERED_DML_MISMATCH', PDML_ENV_MISMATCH as 'PDML_ENV_MISMATCH', INST_DRTLD_MISMATCH as 'INST_DRTLD_MISMATCH', SLAVE_QC_MISMATCH as 'SLAVE_QC_MISMATCH',
               TYPECHECK_MISMATCH as 'TYPECHECK_MISMATCH', AUTH_CHECK_MISMATCH as 'AUTH_CHECK_MISMATCH', BIND_MISMATCH as 'BIND_MISMATCH', DESCRIBE_MISMATCH as 'DESCRIBE_MISMATCH',
               LANGUAGE_MISMATCH as 'LANGUAGE_MISMATCH', TRANSLATION_MISMATCH as 'TRANSLATION_MISMATCH', BIND_EQUIV_FAILURE as 'BIND_EQUIV_FAILURE', INSUFF_PRIVS as 'INSUFF_PRIVS',
               INSUFF_PRIVS_REM as 'INSUFF_PRIVS_REM', REMOTE_TRANS_MISMATCH as 'REMOTE_TRANS_MISMATCH', LOGMINER_SESSION_MISMATCH as 'LOGMINER_SESSION_MISMATCH', INCOMP_LTRL_MISMATCH as 'INCOMP_LTRL_MISMATCH',
               OVERLAP_TIME_MISMATCH as 'OVERLAP_TIME_MISMATCH', EDITION_MISMATCH as 'EDITION_MISMATCH', MV_QUERY_GEN_MISMATCH as 'MV_QUERY_GEN_MISMATCH', USER_BIND_PEEK_MISMATCH as 'USER_BIND_PEEK_MISMATCH',
               TYPCHK_DEP_MISMATCH as 'TYPCHK_DEP_MISMATCH', NO_TRIGGER_MISMATCH as 'NO_TRIGGER_MISMATCH', FLASHBACK_CURSOR as 'FLASHBACK_CURSOR', ANYDATA_TRANSFORMATION as 'ANYDATA_TRANSFORMATION',
               PDDL_ENV_MISMATCH as 'PDDL_ENV_MISMATCH', TOP_LEVEL_RPI_CURSOR as 'TOP_LEVEL_RPI_CURSOR', DIFFERENT_LONG_LENGTH as 'DIFFERENT_LONG_LENGTH', LOGICAL_STANDBY_APPLY as 'LOGICAL_STANDBY_APPLY',
               DIFF_CALL_DURN as 'DIFF_CALL_DURN', BIND_UACS_DIFF as 'BIND_UACS_DIFF', PLSQL_CMP_SWITCHS_DIFF as 'PLSQL_CMP_SWITCHS_DIFF', CURSOR_PARTS_MISMATCH as 'CURSOR_PARTS_MISMATCH',
               STB_OBJECT_MISMATCH as 'STB_OBJECT_MISMATCH', CROSSEDITION_TRIGGER_MISMATCH as 'CROSSEDITION_TRIGGER_MISMATCH', PQ_SLAVE_MISMATCH as 'PQ_SLAVE_MISMATCH', TOP_LEVEL_DDL_MISMATCH as 'TOP_LEVEL_DDL_MISMATCH',
               MULTI_PX_MISMATCH as 'MULTI_PX_MISMATCH', BIND_PEEKED_PQ_MISMATCH as 'BIND_PEEKED_PQ_MISMATCH', MV_REWRITE_MISMATCH as 'MV_REWRITE_MISMATCH', ROLL_INVALID_MISMATCH as 'ROLL_INVALID_MISMATCH',
               OPTIMIZER_MODE_MISMATCH as 'OPTIMIZER_MODE_MISMATCH', PX_MISMATCH as 'PX_MISMATCH', MV_STALEOBJ_MISMATCH as 'MV_STALEOBJ_MISMATCH', FLASHBACK_TABLE_MISMATCH as 'FLASHBACK_TABLE_MISMATCH',
               LITREP_COMP_MISMATCH as 'LITREP_COMP_MISMATCH', PLSQL_DEBUG as 'PLSQL_DEBUG', LOAD_OPTIMIZER_STATS as 'LOAD_OPTIMIZER_STATS', ACL_MISMATCH as 'ACL_MISMATCH',
               FLASHBACK_ARCHIVE_MISMATCH as 'FLASHBACK_ARCHIVE_MISMATCH', LOCK_USER_SCHEMA_FAILED as 'LOCK_USER_SCHEMA_FAILED', REMOTE_MAPPING_MISMATCH as 'REMOTE_MAPPING_MISMATCH',
               LOAD_RUNTIME_HEAP_FAILED as 'LOAD_RUNTIME_HEAP_FAILED', HASH_MATCH_FAILED as 'HASH_MATCH_FAILED', PURGED_CURSOR as 'PURGED_CURSOR', BIND_LENGTH_UPGRADEABLE as 'BIND_LENGTH_UPGRADEABLE',
               USE_FEEDBACK_STATS as 'USE_FEEDBACK_STATS'))
         where nonshared_value = 'Y'
         group by inst_id,sql_id, nonshared_reason)]';
    execute immediate l_sql using p_data.sql_data_point_id, p_data.sql_id;
    l_rows := sql%rowcount;

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSHARING, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      if l_sql is not null then coremod_tasks.log('Error load_non_shared ('||p_data.sql_data_point_id||'): '||l_sql); end if;
      coremod_tasks.log('Error load_non_shared ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSHARING, sqlerrm);
  end;

  procedure load_vsql(p_data   opas_ot_sql_data%rowtype)
  is
    l_sql  varchar2(32765);
    l_rows number;
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsVSQL);
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsEXADATA);

    l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_VSQL */ INTO opas_ot_sql_vsql (
              sql_data_point_id,
              sql_id, child_number, plan_hash_value, optimizer_env_hash_value, inst_id, force_matching_signature, old_hash_value, program_id, program_line#,
              parsing_schema_name, module, action, first_load_time, last_load_time, last_active_time, is_obsolete, is_bind_sensitive, is_bind_aware, is_shareable,
              sql_profile, sql_patch, sql_plan_baseline, px_servers_executions, physical_read_requests, physical_read_bytes, physical_write_requests, physical_write_bytes,
              parse_calls, executions, fetches, rows_processed, end_of_fetch_count, cpu_time, elapsed_time, disk_reads, buffer_gets, direct_writes, application_wait_time,
              concurrency_wait_time, cluster_wait_time, user_io_wait_time, plsql_exec_time, java_exec_time, io_cell_offload_eligible_bytes, IO_INTERCONNECT_BYTES,
              optimized_phy_read_requests, io_cell_uncompressed_bytes, io_cell_offload_returned_bytes)
           select
              :p_sql_data_point_id,
              sql_id, child_number, plan_hash_value, optimizer_env_hash_value, inst_id, force_matching_signature, old_hash_value, program_id, program_line#,
              parsing_schema_name, module, action, first_load_time, last_load_time, last_active_time, is_obsolete, is_bind_sensitive, is_bind_aware, is_shareable,
              sql_profile, sql_patch, sql_plan_baseline, px_servers_executions, physical_read_requests, physical_read_bytes, physical_write_requests, physical_write_bytes,
              parse_calls, executions, fetches, rows_processed, end_of_fetch_count, cpu_time, elapsed_time, disk_reads, buffer_gets, direct_writes, application_wait_time,
              concurrency_wait_time, cluster_wait_time, user_io_wait_time, plsql_exec_time, java_exec_time, io_cell_offload_eligible_bytes, IO_INTERCONNECT_BYTES,
              optimized_phy_read_requests, io_cell_uncompressed_bytes, io_cell_offload_returned_bytes
           from gv$sql]' || COREMOD_API.get_dblink_for_query(p_data.dblink) || ' where sql_id=:p_sql_id';

    execute immediate l_sql using p_data.sql_data_point_id, p_data.sql_id;
    l_rows := sql%rowcount;
    l_sql:=null;

    for i in (select program_id, CHILD_NUMBER from opas_ot_sql_vsql where sql_data_point_id = p_data.sql_data_point_id) loop
      l_sql := q'[INSERT INTO opas_ot_sql_vsql_objs
                   ( sql_data_point_id,   CHILD_NUMBER, object_id, owner, object_type, object_name)
           select :p_sql_data_point_id,  :CHILD_NUMBER, object_id, owner, object_type, object_name from dba_objects]' ||
             COREMOD_API.get_dblink_for_query(p_data.dblink)
             || ' s where s.object_id=:program_id';
      execute immediate l_sql using p_data.sql_data_point_id, i.CHILD_NUMBER, i.program_id;
      l_sql:=null;
    end loop;

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsVSQL,    p_rows_processed => l_rows);
    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsEXADATA, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      if l_sql is not null then coremod_tasks.log('Error load_vsql ('||p_data.sql_data_point_id||'): '||l_sql); end if;
      coremod_tasks.log('Error load_vsql ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsVSQL, sqlerrm);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsEXADATA, sqlerrm);
  end;

  procedure load_sql_mon(p_data   opas_ot_sql_data%rowtype,
                         p_obj_id opas_ot_sql_data_point_ref.obj_id%type)
  is
    l_sql        varchar2(32765);
    l_rows       number;
    l_report     clob;
    l_file_id    opas_files.file_id%type;
    l_drows      number;
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLMONV$);

    l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_SQLMON */ INTO opas_ot_tmp_gv$sql_monitor (<SRC_DB_COL_LICT>)
              select <SRC_DB_COL_LICT> from gv$sql_monitor]' || COREMOD_API.get_dblink_for_query(p_data.dblink) || q'[ where sql_id = :p_sql_id and rownum < :p_drows]';
    l_sql := replace(l_sql,'<SRC_DB_COL_LICT>',COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_data.dblink, P_KEY => 'TABCOLLIST_GV_$SQL_MONITOR'));

    l_drows := nvl( COREOBJ_API.get_param_n(p_obj_id, pnSQLMONHSTRows, true), defSQLMONHSTRows);

    execute immediate l_sql using p_data.sql_id, l_drows;
    l_sql := null;

    INSERT ALL
      WHEN op = 'I' THEN
      INTO opas_ot_sql_sqlmon (
        sqlmon_id, sql_id, sql_mon_report, plan_id, source, report_id, status, first_refresh_time,
        last_refresh_time, refresh_count, sql_exec_start, sql_exec_id, sid, session_serial#, con_id,
        con_name, ecid, snap_id, dbid, instance_number, con_dbid,
        dblink)
      values (
        opas_ot_sq_sqlmon_id.nextval, sql_id, null, null, 'V$', report_id, status, first_refresh_time,
        last_refresh_time, refresh_count, sql_exec_start, sql_exec_id, sid, session_serial#, con_id,
        con_name, ecid, null, null, inst_id, null,
        p_data.dblink)
      WHEN op = 'I' THEN
      INTO opas_ot_sql_sqlmon_data (
        sqlmon_id, user#, username, module, action, service_name, client_identifier, client_info,
        program, plsql_entry_object_id, plsql_entry_subprogram_id, plsql_object_id, plsql_subprogram_id,
        dbop_exec_id, dbop_name, process_name, sql_text, is_full_sqltext, sql_plan_hash_value, sql_full_plan_hash_value,
        exact_matching_signature, force_matching_signature, px_is_cross_instance, px_maxdop, px_maxdop_instances,
        px_servers_requested, px_servers_allocated, px_server#, px_server_group, px_server_set, px_qcinst_id,
        px_qcsid, error_number, error_facility, error_message, elapsed_time, queuing_time, cpu_time, fetches,
        buffer_gets, disk_reads, direct_writes, io_interconnect_bytes, physical_read_requests, physical_read_bytes,
        PHYSICAL_WRITE_REQUESTS, physical_write_bytes, application_wait_time, concurrency_wait_time, cluster_wait_time,
        user_io_wait_time, plsql_exec_time, java_exec_time, rm_last_action, rm_last_action_reason, rm_last_action_time,
        rm_consumer_group, is_adaptive_plan, is_final_plan, in_dbop_name, in_dbop_exec_id, io_cell_uncompressed_bytes,
        io_cell_offload_eligible_bytes, io_cell_offload_returned_bytes)
      values (
        opas_ot_sq_sqlmon_id.currval, user#, username, module, action, service_name, client_identifier, client_info,
        program, plsql_entry_object_id, plsql_entry_subprogram_id, plsql_object_id, plsql_subprogram_id,
        dbop_exec_id, dbop_name, process_name, sql_text, is_full_sqltext, sql_plan_hash_value, sql_full_plan_hash_value,
        exact_matching_signature, force_matching_signature, px_is_cross_instance, px_maxdop, px_maxdop_instances,
        px_servers_requested, px_servers_allocated, px_server#, px_server_group, px_server_set, px_qcinst_id,
        px_qcsid, error_number, error_facility, error_message, elapsed_time, queuing_time, cpu_time, fetches,
        buffer_gets, disk_reads, direct_writes, io_interconnect_bytes, physical_read_requests, physical_read_bytes,
        PHYSICAL_WRITE_REQUESTS, physical_write_bytes, application_wait_time, concurrency_wait_time, cluster_wait_time,
        user_io_wait_time, plsql_exec_time, java_exec_time, rm_last_action, rm_last_action_reason, rm_last_action_time,
        rm_consumer_group, is_adaptive_plan, is_final_plan, in_dbop_name, in_dbop_exec_id, io_cell_uncompressed_bytes,
        io_cell_offload_eligible_bytes, io_cell_offload_returned_bytes)
      WHEN op = 'I' THEN
      INTO opas_ot_sql_sqlmon_ref ( sql_data_point_id, sqlmon_id)
      values( p_data.sql_data_point_id, opas_ot_sq_sqlmon_id.currval)
      WHEN op = 'L' THEN
      INTO opas_ot_sql_sqlmon_ref ( sql_data_point_id, sqlmon_id)
      values( p_data.sql_data_point_id, sqlmon_id)
    SELECT 'I' op, t.*, null sqlmon_id FROM opas_ot_tmp_gv$sql_monitor t
    where report_id = 0 and status = 'EXECUTING'
    union all
    SELECT 'I' op, t.*, null sqlmon_id FROM opas_ot_tmp_gv$sql_monitor t
    where report_id = 0 and status != 'EXECUTING'
      and not exists (select 1 from opas_ot_sql_sqlmon i
                       where i.report_id = 0
                         and t.status = i.status
                         and t.sql_exec_start = i.sql_exec_start
                         and t.sql_id = i.sql_id
                         and i.dblink = p_data.dblink
                         and t.sid = i.sid
                         and t.session_serial# = i.session_serial#)
    union all
    SELECT 'I' op, t.*, null sqlmon_id FROM opas_ot_tmp_gv$sql_monitor t
    where report_id <> 0
      and report_id not in (select report_id from opas_ot_sql_sqlmon where sql_id = p_data.sql_id and dblink = p_data.dblink)
    union all
    SELECT 'L' op, t.*, p.sqlmon_id FROM opas_ot_tmp_gv$sql_monitor t, opas_ot_sql_sqlmon p
    where t.report_id = p.report_id and t.sql_id = p.sql_id and p.dblink = p_data.dblink and t.report_id <> 0
      and not exists (select 1 from opas_ot_sql_sqlmon_ref i where sql_data_point_id = p_data.sql_data_point_id and i.sqlmon_id=p.sqlmon_id);

    select count(1) into l_rows from opas_ot_sql_sqlmon_ref where sql_data_point_id = p_data.sql_data_point_id;

    for i in (select m.* from opas_ot_sql_sqlmon_ref r, opas_ot_sql_sqlmon m where r.sqlmon_id = m.sqlmon_id and r.sql_data_point_id = p_data.sql_data_point_id and sql_mon_report is null) loop
      begin
        if i.report_id <> 0 then
          COREMOD_UTILS.get_clob_remotelly(p_sql => replace(replace(
            q'[begin l_out := dbms_sqltune.report_sql_monitor(sql_id=>'<SQL_ID>', REPORT_ID => <REP_ID>, report_level=>'ALL'); end;]'
                                                    ,'<SQL_ID>',p_data.sql_id)
                                                    ,'<REP_ID>',i.report_id),
                                         p_dblink => p_data.dblink,
                                         p_output => l_report);

        else
          COREMOD_UTILS.get_clob_remotelly(p_sql => replace(replace(replace(replace(replace(replace(
            q'[begin l_out := dbms_sqltune.report_sql_monitor(sql_id=>'<SQL_ID>', SESSION_ID => <SID>, SESSION_SERIAL=> <SER>, SQL_EXEC_ID => <EID>, INST_ID => <IID>, SQL_EXEC_START => to_date('<SDT>','YYYYMMDDHH24MISS'), report_level=>'ALL'); end;]'
                                                    ,'<SQL_ID>',p_data.sql_id)
                                                    ,'<SID>',i.sid)
                                                    ,'<SER>',i.session_serial#)
                                                    ,'<EID>',i.sql_exec_id)
                                                    ,'<IID>',i.instance_number)
                                                    ,'<SDT>',to_char(i.sql_exec_start,'YYYYMMDDHH24MISS')),
                                         p_dblink => p_data.dblink,
                                         p_output => l_report);
        end if;
        l_file_id := COREMOD_FILE_UTILS.create_file(
          P_MODNAME => COREMOD_API.gMODNAME,
          P_FILE_TYPE => 'SQLMON',
          P_FILE_NAME => p_data.sql_id||'_sqlmon.txt',
          P_MIMETYPE => COREMOD_FILE_UTILS.mtTEXT,
          P_OWNER => 'PUBLIC');
        COREMOD_FILE_UTILS.store_content (
           P_FILE_ID => l_file_id,
           P_CONTENT => l_report) ;

        update opas_ot_sql_sqlmon set sql_mon_report = l_file_id where sqlmon_id = i.sqlmon_id;
      exception
        when others then
          coremod_tasks.log('Error load_sql_mon ('||p_data.sql_data_point_id||') calling dbms_sqltune.report_sql_monitor: '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      end;
    end loop;

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLMONV$, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      if l_sql is not null then coremod_tasks.log('Error load_sql_mon ('||p_data.sql_data_point_id||'): '||l_sql); end if;
      coremod_tasks.log('Error load_sql_mon ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLMONV$, sqlerrm);
  end;

  procedure load_sql_mon_hst(p_data   opas_ot_sql_data%rowtype,
                             p_obj_id opas_ot_sql_data_point_ref.obj_id%type)
  is
    l_sql        varchar2(32765);
    l_rows       number;
    l_report     clob;
    l_file_id    opas_files.file_id%type;
    l_obj_lst    varchar2(32765);
    l_ddays      number;
    l_drows      number;
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLMONHST);

    l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_SQLMON_HST */ INTO opas_ot_tmp_dba_hist_reports (<SRC_DB_COL_LICT>)
              select <SRC_DB_COL_LICT> from dba_hist_reports]' || COREMOD_API.get_dblink_for_query(p_data.dblink) ||
              q'[ r where r.component_name = 'sqlmonitor' and r.key1 = :p_sql_id and period_start_time > (sysdate - :p_days) and rownum <= :p_rows ]'; --TODO filter istory reports
    l_sql := replace(l_sql,'<SRC_DB_COL_LICT>',COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_data.dblink, P_KEY => 'TABCOLLIST_DBA_HIST_REPORTS'));

    l_ddays := nvl( COREOBJ_API.get_param_n(p_obj_id, pnSQLMONHSTDays, true), defSQLMONHSTDays);
    l_drows := nvl( COREOBJ_API.get_param_n(p_obj_id, pnSQLMONHSTRows, true), defSQLMONHSTRows);
    execute immediate l_sql using p_data.sql_id, l_ddays, l_drows;
    l_sql := null;

    select listagg(REPORT_ID,',')within group (order by REPORT_ID) into l_obj_lst from (select REPORT_ID from opas_ot_tmp_dba_hist_reports);
    if l_obj_lst is not null then
      l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_SQLMON_XML */ INTO opas_ot_tmp_dba_hist_rep_xml (REPORT_ID, REPORT)
                select d.REPORT_ID, d.REPORT from dba_hist_reports_details]' || COREMOD_API.get_dblink_for_query(p_data.dblink) ||
                q'[ d where d.REPORT_ID in (<RPT_LST>)]'; --TODO filter istory reports
      l_sql := replace(l_sql,'<RPT_LST>',l_obj_lst);

      execute immediate l_sql;
      l_sql := null;
    end if;

    INSERT ALL
      WHEN op = 'I' THEN
      INTO opas_ot_sql_sqlmon (
        sqlmon_id,                   sql_id, sql_mon_report, plan_id, source, report_id, status, first_refresh_time,
        last_refresh_time, refresh_count, sql_exec_start, sql_exec_id, sid, session_serial#, con_id,
        con_name, ecid, snap_id, dbid, instance_number, con_dbid,
        dblink)
      values (
        opas_ot_sq_sqlmon_id.nextval, key1,  null,           null,    srcHST,  report_id, STATUS, to_date(first_refresh_time,'MM/DD/YYYY HH24:MI:SS'),
        to_date(last_refresh_time,'MM/DD/YYYY HH24:MI:SS'), refresh_count, to_date(sql_exec_start,'MM/DD/YYYY HH24:MI:SS'), sql_exec_id, session_id, session_serial#, con_id,
        null,     null, snap_id, dbid, instance_number, con_dbid,
        p_data.dblink)
      WHEN op = 'I' THEN
      INTO opas_ot_sql_sqlmon_data (
        sqlmon_id,
        user#, username, module, action, service_name, client_identifier, client_info,
        program, plsql_entry_object_id, plsql_entry_subprogram_id, plsql_object_id, plsql_subprogram_id,
        dbop_exec_id, dbop_name, process_name, sql_text, is_full_sqltext, sql_plan_hash_value, sql_full_plan_hash_value,
        exact_matching_signature, force_matching_signature, px_is_cross_instance, px_maxdop, px_maxdop_instances,
        px_servers_requested, px_servers_allocated, px_server#, px_server_group, px_server_set, px_qcinst_id,
        px_qcsid, error_number, error_facility, error_message, elapsed_time, queuing_time, cpu_time, fetches,
        buffer_gets, disk_reads, direct_writes, io_interconnect_bytes, physical_read_requests, physical_read_bytes,
        PHYSICAL_WRITE_REQUESTS, physical_write_bytes, application_wait_time, concurrency_wait_time, cluster_wait_time,
        user_io_wait_time, plsql_exec_time, java_exec_time, rm_last_action, rm_last_action_reason, rm_last_action_time,
        rm_consumer_group, is_adaptive_plan, is_final_plan, in_dbop_name, in_dbop_exec_id, io_cell_uncompressed_bytes,
        io_cell_offload_eligible_bytes, io_cell_offload_returned_bytes)
      values (
        opas_ot_sq_sqlmon_id.currval,
        user#, username, module, action, service_name, null /*client_identifier*/, null /*client_info*/,
        program, null /*plsql_entry_object_id*/, null /*plsql_entry_subprogram_id*/, null /*plsql_object_id*/, null /*plsql_subprogram_id*/,
        null /*dbop_exec_id*/, null /*dbop_name*/, null /*process_name*/, null /*sql_text*/, is_full_sqltext, sql_plan_hash_value, sql_full_plan_hash_value,
        null /*exact_matching_signature*/, null /*force_matching_signature*/, null /*px_is_cross_instance*/, null /*px_maxdop*/, null /*px_maxdop_instances*/,
        null /*px_servers_requested*/, null /*px_servers_allocated*/, null /*px_server#*/, null /*px_server_group*/, null /*px_server_set*/, null /*px_qcinst_id*/,
        null /*px_qcsid*/, null /*error_number*/, null /*error_facility*/, null /*error_message*/, elapsed_time, null /*queuing_time*/, cpu_time, fetches,
        buffer_gets, disk_reads, null /*direct_writes*/, null /*io_interconnect_bytes*/, physical_read_requests, physical_read_bytes,
        null /*PHYSICAL_WRITE_REQUESTS*/, null /*physical_write_bytes*/, null /*application_wait_time*/, null /*concurrency_wait_time*/, null /*cluster_wait_time*/,
        user_io_wait_time, null /*plsql_exec_time*/, null /*java_exec_time*/, null /*rm_last_action*/, null /*rm_last_action_reason*/, null /*rm_last_action_time*/,
        rm_consumer_group, null /*is_adaptive_plan*/, null /*is_final_plan*/, null /*in_dbop_name*/, null /*in_dbop_exec_id*/, null /*io_cell_uncompressed_bytes*/,
        null /*io_cell_offload_eligible_bytes*/, null /*io_cell_offload_returned_bytes*/)
      WHEN op = 'I' THEN
      INTO opas_ot_sql_sqlmon_ref ( sql_data_point_id, sqlmon_id)
      values( p_data.sql_data_point_id, opas_ot_sq_sqlmon_id.currval)
      WHEN op = 'L' THEN
      INTO opas_ot_sql_sqlmon_ref ( sql_data_point_id, sqlmon_id)
      values( p_data.sql_data_point_id, sqlmon_id)
    select x.*, x1.*, x2.*--, XMLCast(xmlquery('$p/report/sql_monitor_report/target/sql_fulltext' passing xmltype(x.report) as "p" RETURNING CONTENT) as varchar2(2000)) sql_text
    from ( SELECT 'I' op, t.*, null sqlmon_id, d.report
             FROM opas_ot_tmp_dba_hist_reports t, opas_ot_tmp_dba_hist_rep_xml d
            where not exists (select 1 from opas_ot_sql_sqlmon i
                               where i.report_id = t.report_id
                                 and i.sql_id    = t.key1
                                 and i.dblink    = p_data.dblink)
             and t.report_id=d.report_id
           union all
           SELECT 'L' op, t.*, p.sqlmon_id, d.report
             FROM opas_ot_tmp_dba_hist_reports t, opas_ot_sql_sqlmon p, opas_ot_tmp_dba_hist_rep_xml d
            where t.report_id = p.report_id and t.key1 = p.sql_id and p.dblink = p_data.dblink and p.sql_id = p_data.sql_id
              and not exists (select 1 from opas_ot_sql_sqlmon_ref i where sql_data_point_id = p_data.sql_data_point_id and i.sqlmon_id=p.sqlmon_id)
              and t.report_id=d.report_id) x,
           xmltable('/report/sql_monitor_report/target'
                  PASSING xmlparse(document x.report) COLUMNS
                  STATUS path 'status'
                 ,refresh_count path 'refresh_count'
                 ,rm_consumer_group path 'rminfo/@rmcg'
                 --,sql_text path 'sql_fulltext'
                 ,is_full_sqltext path 'sql_fulltext/@is_full'
                 ,sql_exec_start path '@sql_exec_start'
                 ,sql_exec_id path '@sql_exec_id'
                 ,sql_plan_hash_value path '@sql_plan_hash'
                 ,sql_full_plan_hash_value path '@sql_full_plan_hash'
                 ,db_unique_name path '@db_unique_name'
                 ,db_platform_name path '@db_platform_name'
                 ,report_host_name path '@report_host_name'
                 ,servers_requested path 'servers_requested'
                 ,servers_allocated path 'servers_allocated'
                 ,user# path 'user_id'
                 ,username path 'user'
                 ,program path 'program'
                 ,module path 'module'
                 ,action path 'action'
                 ,service_name path 'service'
                 ,first_refresh_time path 'first_refresh_time'
                 ,last_refresh_time path 'last_refresh_time'
                 ,duration path 'duration'
                 ) x1,
           xmltable('/report/sql_monitor_report/stats'
                  PASSING xmlparse(document x.report) COLUMNS
                  elapsed_time path 'stat[@name="elapsed_time"]'
                  ,cpu_time path 'stat[@name="cpu_time"]'
                  ,user_io_wait_time path 'stat[@name="user_io_wait_time"]'
                  ,other_wait_time path 'stat[@name="other_wait_time"]'
                  ,fetches path 'stat[@name="user_fetch_count"]'
                  ,buffer_gets path 'stat[@name="buffer_gets"]'
                  ,disk_reads path 'stat[@name="disk_reads"]'
                  ,physical_read_requests path 'stat[@name="read_reqs"]'
                  ,physical_read_bytes path 'stat[@name="read_bytes"]'
                  ) x2;

    select count(1) into l_rows from opas_ot_sql_sqlmon_ref where sql_data_point_id = p_data.sql_data_point_id;

    insert into opas_ot_tmp_gv$sql_plan_stat_all (
           report_id,
           SQL_ID,PLAN_HASH_VALUE,FULL_PLAN_HASH_VALUE,CHILD_NUMBER,inst_id,
           OPERATION, OPTIONS, OBJECT_NODE, OBJECT_NAME, OBJECT_ALIAS,
           ID, DEPTH, POSITION, COST, CARDINALITY, BYTES, PARTITION_START,
           PARTITION_STOP, PARTITION_ID, DISTRIBUTION, CPU_COST, IO_COST,
           TEMP_SPACE, ACCESS_PREDICATES, FILTER_PREDICATES, QBLOCK_NAME)
    select r.report_id,
           r.sql_id, d.SQL_PLAN_HASH_VALUE, d.SQL_FULL_PLAN_HASH_VALUE, 0, r.instance_number,
           OPERATION, OPTIONS, OBJECT_NODE, OBJECT_NAME, OBJECT_ALIAS,
           ID, DEPTH, POSITION, COST, CARDINALITY, BYTES, PARTITION_START,
           PARTITION_STOP, PARTITION_ID, DISTRIBUTION, CPU_COST, IO_COST,
           TEMP_SPACE, ACCESS_PREDICATES, FILTER_PREDICATES, QBLOCK_NAME
    from opas_ot_sql_sqlmon r, opas_ot_sql_sqlmon_data d, opas_ot_tmp_dba_hist_rep_xml x, opas_ot_sql_sqlmon_ref reff,
         xmltable('/report/sql_monitor_report/plan/operation'
                  PASSING xmlparse(document x.report) COLUMNS
                  OPERATION path '@name'
                 ,options path '@options'
                 ,OBJECT_NODE path 'node'
                 ,OBJECT_NAME path 'object'
                 ,object_alias path 'object_alias'
                 ,id path '@id'
                 ,depth path '@depth'
                 ,POSITION path '@pos'
                 ,cost path 'cost'
                 ,CARDINALITY path 'card'
                 ,bytes path 'bytes'
                 ,PARTITION_START PATH 'partition/@start'
                 ,PARTITION_STOP path 'partition/@stop'
                 ,PARTITION_ID path 'partition/@id'
                 ,DISTRIBUTION path 'distrib'
                 ,cpu_cost path 'cpu_cost'
                 ,io_cost path 'io_cost'
                 ,TEMP_SPACE path 'TEMP_SPACE'
                 ,ACCESS_PREDICATES path 'predicates[@type="access"]'
                 ,FILTER_PREDICATES path 'predicates[@type="filter"]'
                 ,QBLOCK_NAME path 'qblock'
                 ) x1
     where r.SQLMON_ID=d.SQLMON_ID
       and r.report_id=x.report_id
       and r.SQLMON_ID = reff.SQLMON_ID
       and r.SOURCE = srcHST
       and reff.sql_data_point_id = p_data.sql_data_point_id;


    INSERT INTO opas_ot_tmp_gv$sql_plan_key
           ( plan_id,                   report_id, inst_id, child_number, plan_hash_value, full_plan_hash_value)
     select opas_ot_sq_plan_id.nextval, report_id, inst_id, child_number, plan_hash_value, full_plan_hash_value
       from (select unique report_id, inst_id, child_number, plan_hash_value, full_plan_hash_value from opas_ot_tmp_gv$sql_plan_stat_all);

    insert all
      into opas_ot_sql_plans    ( plan_id, plan_source, created, sql_id)
      into opas_ot_sql_plan_ref ( sql_data_point_id, plan_id)
      values( p_data.sql_data_point_id, plan_id)
      select plan_id, srcHST plan_type, systimestamp created, p_data.sql_id sql_id from opas_ot_tmp_gv$sql_plan_key;

    update OPAS_OT_SQL_SQLMON m
       set plan_id = (select plan_id from opas_ot_tmp_gv$sql_plan_key k where m.REPORT_ID = k.REPORT_ID)
     where m.SOURCE = srcHST and SQLMON_ID in (select SQLMON_ID from opas_ot_sql_sqlmon_ref where sql_data_point_id = p_data.sql_data_point_id);

    insert all into opas_ot_sql_plan_det (
        plan_id,
        inst_id,address,hash_value,sql_id,plan_hash_value,full_plan_hash_value,child_address,child_number,timestamp,operation,options,object_node,object#,
        object_owner,object_name,object_alias,object_type,optimizer,id,parent_id,depth,position,search_columns,cost,cardinality,bytes,other_tag,partition_start,
        partition_stop,partition_id,other,distribution,cpu_cost,io_cost,temp_space,access_predicates,filter_predicates,projection,time,qblock_name,remarks,
        other_xml, EXECUTIONS,last_starts,starts,last_output_rows,output_rows,last_cr_buffer_gets,cr_buffer_gets,last_cu_buffer_gets,cu_buffer_gets,
        last_disk_reads,disk_reads,last_disk_writes,disk_writes,last_elapsed_time,elapsed_time,policy,estimated_optimal_size,estimated_onepass_size,
        last_memory_used,last_execution,last_degree,total_executions,optimal_executions,onepass_executions,multipasses_executions,active_time,
        max_tempseg_size,last_tempseg_size,con_id,con_dbid)
      values (
        plan_id,
        inst_id,address,hash_value,sql_id,plan_hash_value,full_plan_hash_value,child_address,child_number,timestamp,operation,options,object_node,object#,
        object_owner,object_name,object_alias,object_type,optimizer,id,parent_id,depth,position,search_columns,cost,cardinality,bytes,other_tag,partition_start,
        partition_stop,partition_id,other,distribution,cpu_cost,io_cost,temp_space,access_predicates,filter_predicates,projection,time,qblock_name,remarks,
        other_xml, EXECUTIONS,last_starts,starts,last_output_rows,output_rows,last_cr_buffer_gets,cr_buffer_gets,last_cu_buffer_gets,cu_buffer_gets,
        last_disk_reads,disk_reads,last_disk_writes,disk_writes,last_elapsed_time,elapsed_time,policy,estimated_optimal_size,estimated_onepass_size,
        last_memory_used,last_execution,last_degree,total_executions,optimal_executions,onepass_executions,multipasses_executions,active_time,
        max_tempseg_size,last_tempseg_size,con_id,con_dbid)
    select p.*, k.plan_id
      from opas_ot_tmp_gv$sql_plan_stat_all p,
           opas_ot_tmp_gv$sql_plan_key k
     where p.inst_id = k.inst_id
       and p.child_number = k.child_number
       and p.plan_hash_value = k.plan_hash_value
       and p.full_plan_hash_value = k.full_plan_hash_value
       and p.report_id=k.report_id;


    for i in (select * from opas_ot_sql_descriptions where sql_id=p_data.sql_id and sql_text is null) loop
      begin
        for j in (select * from (
                  select XMLCast(xmlquery('$p/report/sql_monitor_report/target/sql_fulltext' passing xmltype(report) as "p" RETURNING CONTENT) as clob) sql_text,
                         XMLCast(xmlquery('$p/report/sql_monitor_report/target/sql_fulltext/@is_full' passing xmltype(report) as "p" RETURNING CONTENT) as varchar2(10)) is_full_sqltext
                    from opas_ot_tmp_dba_hist_rep_xml x
                  ) where is_full_sqltext = 'Y' and rownum = 1)
        loop
            l_file_id := COREMOD_FILE_UTILS.create_file(P_MODNAME => COREMOD_API.gMODNAME,
                                                        P_FILE_TYPE => 'SQL Text',
                                                        P_FILE_NAME => i.sql_id,
                                                        P_MIMETYPE  => COREMOD_FILE_UTILS.mtTEXT,
                                                        P_OWNER     => i.created_by);
            COREMOD_FILE_UTILS.store_content(l_file_id,j.sql_text);
            update opas_ot_sql_descriptions set
              sql_text_approx = l_file_id,
              FIRST_DISCOVERED = nvl(FIRST_DISCOVERED, systimestamp),
              FIRST_DISCOVERED_AT = nvl(FIRST_DISCOVERED_AT, p_data.dblink)
            where sql_id = p_data.sql_id;
            finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQL_TEXT, p_rows_processed => 1);
        end loop;
      exception
        when others then
        coremod_tasks.log('Error load_sql_mon_hst ('||p_data.sql_data_point_id||'): getting approx. sql text: '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      end;
    end loop;

    for i in (SELECT d.report, p.SQLMON_ID
                FROM opas_ot_tmp_dba_hist_reports t, opas_ot_sql_sqlmon p, opas_ot_tmp_dba_hist_rep_xml d
               where t.report_id = p.report_id and t.key1 = p.sql_id and p.dblink = p_data.dblink
                 and t.report_id = d.report_id
                 and sql_mon_hst_report is null)
    loop
      l_file_id := COREMOD_FILE_UTILS.create_file(
        P_MODNAME => COREMOD_API.gMODNAME,
        P_FILE_TYPE => 'SQLMONHST',
        P_FILE_NAME => p_data.sql_id||'_sqlmonhst.txt',
        P_MIMETYPE => COREMOD_FILE_UTILS.mtTEXT,
        P_OWNER => 'PUBLIC');
      COREMOD_FILE_UTILS.store_content (
         P_FILE_ID => l_file_id,
         P_CONTENT => i.report) ;

      update opas_ot_sql_sqlmon set sql_mon_hst_report = l_file_id where sqlmon_id = i.sqlmon_id;

    end loop;

    for i in (select m.* from opas_ot_sql_sqlmon_ref r, opas_ot_sql_sqlmon m where r.sqlmon_id = m.sqlmon_id and r.sql_data_point_id = p_data.sql_data_point_id and sql_mon_report is null) loop
      begin
        COREMOD_UTILS.get_clob_remotelly(p_sql => replace(
            q'[begin l_out := DBMS_AUTO_REPORT.REPORT_REPOSITORY_DETAIL(RID => <REP_ID>, TYPE => 'text'); end;]'
                                                    ,'<REP_ID>',i.report_id),
                                         p_dblink => p_data.dblink,
                                         p_output => l_report);

        l_file_id := COREMOD_FILE_UTILS.create_file(
          P_MODNAME => COREMOD_API.gMODNAME,
          P_FILE_TYPE => 'SQLMON',
          P_FILE_NAME => p_data.sql_id||'_sqlmon.txt',
          P_MIMETYPE => COREMOD_FILE_UTILS.mtTEXT,
          P_OWNER => 'PUBLIC');
        COREMOD_FILE_UTILS.store_content (
          P_FILE_ID => l_file_id,
          P_CONTENT => l_report) ;

        update opas_ot_sql_sqlmon set sql_mon_report = l_file_id where sqlmon_id = i.sqlmon_id;
      exception
        when others then
        coremod_tasks.log('Error load_sql_mon_hst ('||p_data.sql_data_point_id||'): calling DBMS_AUTO_REPORT.REPORT_REPOSITORY_DETAIL: '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      end;
    end loop;

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLMONHST, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      if l_sql is not null then coremod_tasks.log('Error load_sql_mon_hst ('||p_data.sql_data_point_id||'): '||l_sql); end if;
      coremod_tasks.log('Error load_sql_mon_hst ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLMONHST, sqlerrm);
  end;

  procedure load_work_area(p_data   opas_ot_sql_data%rowtype)
  is
    l_sql  varchar2(32765);
    l_rows number;
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsWORKAREA);

    l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_WA */ into opas_ot_sql_wa (
              sql_data_point_id,
              sql_id, inst_id, child_number, policy, operation_id, operation_type, estimated_optimal_size, estimated_onepass_size, last_memory_used, last_execution,
              last_degree, total_executions, optimal_executions, onepass_executions, multipasses_executions, active_time, max_tempseg_size, last_tempseg_size)
           select
              :p_sql_data_point_id,
              sql_id, inst_id, child_number, policy, operation_id, operation_type, estimated_optimal_size, estimated_onepass_size, last_memory_used, last_execution,
              last_degree, total_executions, optimal_executions, onepass_executions, multipasses_executions, active_time, max_tempseg_size, last_tempseg_size
           from gv$sql_workarea]' || COREMOD_API.get_dblink_for_query(p_data.dblink) || ' where sql_id=:p_sql_id';

    execute immediate l_sql using p_data.sql_data_point_id, p_data.sql_id;
    l_rows := sql%rowcount;

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsWORKAREA, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      coremod_tasks.log('Error load_work_area ('||p_data.sql_data_point_id||'): '||l_sql);
      coremod_tasks.log('Error load_work_area ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsWORKAREA, sqlerrm);
  end;

  procedure load_opt_env(p_data   opas_ot_sql_data%rowtype)
  is
    l_sql  varchar2(32765);
    l_rows number;
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsOPTENV);

    l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_OE */ into opas_ot_sql_opt_env (
              sql_data_point_id, sql_id,
              inst_id,child_number,name,isdefault,value)
           select
              :p_sql_data_point_id, sql_id,
              inst_id,child_number,name,isdefault,value
           from gv$sql_optimizer_env]' || COREMOD_API.get_dblink_for_query(p_data.dblink) || ' where sql_id=:p_sql_id';

    execute immediate l_sql using p_data.sql_data_point_id, p_data.sql_id;
    l_rows := sql%rowcount;

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsOPTENV, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      coremod_tasks.log('Error load_opt_env ('||p_data.sql_data_point_id||'): '||l_sql);
      coremod_tasks.log('Error load_opt_env ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsOPTENV, sqlerrm);
  end;

  procedure load_sql_plans(p_data   opas_ot_sql_data%rowtype)
  is
    l_sql        varchar2(32765);
    l_rows       number;
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLLAST);
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLADV);
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLALL);
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLADAPT);

    l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_PLANS */ INTO opas_ot_tmp_gv$sql_plan_stat_all (<SRC_DB_COL_LICT>)
              select <SRC_DB_COL_LICT> from gv$sql_plan_statistics_all]' || COREMOD_API.get_dblink_for_query(p_data.dblink) || q'[ where sql_id = :p_sql_id]';
    l_sql := replace(l_sql,'<SRC_DB_COL_LICT>',COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_data.dblink, P_KEY => 'TABCOLLIST_GV_$SQL_PLAN_STATISTICS_ALL'));
    execute immediate l_sql using p_data.sql_id;
    l_sql := null;

    INSERT INTO opas_ot_tmp_gv$sql_plan_key
           ( plan_id,                   inst_id, child_number, plan_hash_value, full_plan_hash_value)
     select opas_ot_sq_plan_id.nextval, inst_id, child_number, plan_hash_value, full_plan_hash_value
       from (select unique inst_id, child_number, plan_hash_value, full_plan_hash_value from opas_ot_tmp_gv$sql_plan_stat_all);

    insert all
      into opas_ot_sql_plans    ( plan_id, plan_source, created, sql_id)
      into opas_ot_sql_plan_ref ( sql_data_point_id, plan_id)
      values( p_data.sql_data_point_id, plan_id)
      select plan_id, srcV$ plan_type, systimestamp created, p_data.sql_id sql_id from opas_ot_tmp_gv$sql_plan_key;

    insert all into opas_ot_sql_plan_det (
        plan_id,
        inst_id,address,hash_value,sql_id,plan_hash_value,full_plan_hash_value,child_address,child_number,timestamp,operation,options,object_node,object#,
        object_owner,object_name,object_alias,object_type,optimizer,id,parent_id,depth,position,search_columns,cost,cardinality,bytes,other_tag,partition_start,
        partition_stop,partition_id,other,distribution,cpu_cost,io_cost,temp_space,access_predicates,filter_predicates,projection,time,qblock_name,remarks,
        other_xml, EXECUTIONS,last_starts,starts,last_output_rows,output_rows,last_cr_buffer_gets,cr_buffer_gets,last_cu_buffer_gets,cu_buffer_gets,
        last_disk_reads,disk_reads,last_disk_writes,disk_writes,last_elapsed_time,elapsed_time,policy,estimated_optimal_size,estimated_onepass_size,
        last_memory_used,last_execution,last_degree,total_executions,optimal_executions,onepass_executions,multipasses_executions,active_time,
        max_tempseg_size,last_tempseg_size,con_id,con_dbid)
      values (
        plan_id,
        inst_id,address,hash_value,sql_id,plan_hash_value,full_plan_hash_value,child_address,child_number,timestamp,operation,options,object_node,object#,
        object_owner,object_name,object_alias,object_type,optimizer,id,parent_id,depth,position,search_columns,cost,cardinality,bytes,other_tag,partition_start,
        partition_stop,partition_id,other,distribution,cpu_cost,io_cost,temp_space,access_predicates,filter_predicates,projection,time,qblock_name,remarks,
        other_xml, EXECUTIONS,last_starts,starts,last_output_rows,output_rows,last_cr_buffer_gets,cr_buffer_gets,last_cu_buffer_gets,cu_buffer_gets,
        last_disk_reads,disk_reads,last_disk_writes,disk_writes,last_elapsed_time,elapsed_time,policy,estimated_optimal_size,estimated_onepass_size,
        last_memory_used,last_execution,last_degree,total_executions,optimal_executions,onepass_executions,multipasses_executions,active_time,
        max_tempseg_size,last_tempseg_size,con_id,con_dbid)
    select p.*, k.plan_id
      from opas_ot_tmp_gv$sql_plan_stat_all p,
           opas_ot_tmp_gv$sql_plan_key k
     where p.inst_id = k.inst_id
       and p.child_number = k.child_number
       and p.plan_hash_value = k.plan_hash_value
       and p.full_plan_hash_value = k.full_plan_hash_value;

    select count(1) into l_rows from opas_ot_sql_plan_ref r, opas_ot_sql_plans p where r.plan_id=p.plan_id and p.plan_source = srcV$ and r.sql_data_point_id = p_data.sql_data_point_id;

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLLAST, p_rows_processed => l_rows);
    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLADV, p_rows_processed => l_rows);
    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLALL, p_rows_processed => l_rows);
    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLADAPT, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      if l_sql is not null then coremod_tasks.log('Error load_sql_plans ('||p_data.sql_data_point_id||'): '||l_sql);  end if;
      coremod_tasks.log('Error load_sql_plans ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);

      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLLAST, sqlerrm);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLADV, sqlerrm);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLALL, sqlerrm);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLADAPT, sqlerrm);
  end;

  procedure load_sql_ep_plans(p_data   opas_ot_sql_data%rowtype)
  is
    l_sql        varchar2(32765);
    l_rows       number;
    l_remote_ep  varchar2(32765) := q'[begin delete from plan_table where STATEMENT_ID = 'OPAS60'; execute immediate q'~explain plan set statement_id='OPAS60' for ]' || chr(10) || q'[<SQLTOEXPLAIN>~'; end;]';
    l_sql_ptr    OPAS_OT_SQL_DESCRIPTIONS.SQL_TEXT%type;
    l_sql_text   clob;
    l_sql_out    clob;
    l_plan_hash  number;
    l_full_plan_hash number;
    l_col_list   varchar2(32765);
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLEP);

    select nvl(SQL_TEXT,SQL_TEXT_APPROX) into l_sql_ptr from OPAS_OT_SQL_DESCRIPTIONS where sql_id=p_data.sql_id;
    if l_sql_ptr is null then raise_application_error(-20000, 'SQL Text is unavailable'); end if;

    if p_data.dblink <> COREMOD_API.gLocalDBLink then
      if COREMOD_FILE_UTILS.get_file_size(p_file_id => l_sql_ptr) > 32000 then raise_application_error(-20000, 'SQL Text is too long'); end if;
      COREMOD_FILE_UTILS.get_locator(l_sql_ptr,l_sql_text);

      l_col_list := COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_data.dblink, P_KEY => 'TABCOLLIST_PLAN_TABLE$');

      l_sql := replace(l_remote_ep,'<SQLTOEXPLAIN>',l_sql_text);

      COREMOD_UTILS.execute_plsql_remotelly (  P_SQL => l_sql,
        P_DBLINK => p_data.dblink,
        P_OUTPUT => l_sql_out,
        P_IS_OUTPUT => false) ;

      delete from plan_table where STATEMENT_ID = 'OPAS60';

      l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_EP_PLANS */ INTO plan_table (<SRC_DB_COL_LICT>)
                 select <SRC_DB_COL_LICT> from plan_table]' || COREMOD_API.get_dblink_for_query(p_data.dblink) || q'[ where STATEMENT_ID = 'OPAS60']';
      l_sql := replace(l_sql,'<SRC_DB_COL_LICT>',l_col_list);
      execute immediate l_sql;
      l_sql := null;
    else
      l_sql := replace(l_remote_ep,'<SQLTOEXPLAIN>',l_sql_text);
      execute immediate l_sql;
    end if;

    select x1.plan_hash, x1.plan_hash_full into l_plan_hash, l_full_plan_hash
      from plan_table p,
           xmltable('/other_xml'
                  PASSING xmlparse(document p.other_xml) COLUMNS
                  plan_hash      path 'info[@type="plan_hash"]',
                  plan_hash_full path 'info[@type="plan_hash_full"]'
                 ) x1
     where other_xml is not null and STATEMENT_ID = 'OPAS60';

    INSERT INTO opas_ot_tmp_gv$sql_plan_key
           ( plan_id,                   plan_hash_value, full_plan_hash_value)
     select opas_ot_sq_plan_id.nextval, l_plan_hash, l_full_plan_hash
       from dual;

    insert all
      into opas_ot_sql_plans    ( plan_id, plan_source, created, sql_id)
      into opas_ot_sql_plan_ref ( sql_data_point_id, plan_id)
      values( p_data.sql_data_point_id, plan_id)
      select plan_id, srcEP plan_type, systimestamp created, p_data.sql_id sql_id from opas_ot_tmp_gv$sql_plan_key;

    insert all into opas_ot_sql_ep_plan_det (
        SQL_ID, PLAN_ID, STATEMENT_ID, TIMESTAMP, REMARKS, OPERATION, OPTIONS, OBJECT_NODE, OBJECT_OWNER,
        OBJECT_NAME, OBJECT_ALIAS, OBJECT_INSTANCE, OBJECT_TYPE, OPTIMIZER, SEARCH_COLUMNS, ID, PARENT_ID,
        DEPTH, POSITION, COST, CARDINALITY, BYTES, OTHER_TAG, PARTITION_START, PARTITION_STOP, PARTITION_ID,
        OTHER_XML, DISTRIBUTION, CPU_COST, IO_COST, TEMP_SPACE, ACCESS_PREDICATES, FILTER_PREDICATES, PROJECTION, TIME, QBLOCK_NAME,
        sql_plan_hash_value,sql_full_plan_hash_value)
      values (
        SQL_ID, opas_plan_id, STATEMENT_ID, TIMESTAMP, REMARKS, OPERATION, OPTIONS, OBJECT_NODE, OBJECT_OWNER,
        OBJECT_NAME, OBJECT_ALIAS, OBJECT_INSTANCE, OBJECT_TYPE, OPTIMIZER, SEARCH_COLUMNS, ID, PARENT_ID,
        DEPTH, POSITION, COST, CARDINALITY, BYTES, OTHER_TAG, PARTITION_START, PARTITION_STOP, PARTITION_ID,
        OTHER_XML, DISTRIBUTION, CPU_COST, IO_COST, TEMP_SPACE, ACCESS_PREDICATES, FILTER_PREDICATES, PROJECTION, TIME, QBLOCK_NAME,
        plan_hash_value, full_plan_hash_value)
    select p.*, k.plan_id opas_plan_id, p_data.sql_id sql_id, k.plan_hash_value, k.full_plan_hash_value
      from plan_table p,
           opas_ot_tmp_gv$sql_plan_key k
     where p.STATEMENT_ID = 'OPAS60';

    select count(1) into l_rows from opas_ot_sql_plan_ref r, opas_ot_sql_plans p where r.plan_id=p.plan_id and p.plan_source = srcEP and r.sql_data_point_id = p_data.sql_data_point_id;

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLEP, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      if l_sql is not null then coremod_tasks.log('Error load_sql_ep_plans ('||p_data.sql_data_point_id||'): '||l_sql);  end if;
      coremod_tasks.log('Error load_sql_ep_plans ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);

      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsSQLPLEP, sqlerrm);
  end;

  procedure load_sql_vash(p_data   opas_ot_sql_data%rowtype)
  is
    l_sql        varchar2(32765);
    l_rows       number := 0;
    l_obj_lst    varchar2(32765);
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsVASH);

    l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_VASH */ INTO opas_ot_tmp_gv$ash (sql_id,sample_time,SQL_EXEC_START,sql_plan_hash_value,sql_plan_line_id,sql_plan_operation,sql_plan_options,event,CURRENT_OBJ#,CURRENT_FILE#)
              select sql_id,sample_time,SQL_EXEC_START,sql_plan_hash_value,sql_plan_line_id,sql_plan_operation,sql_plan_options,event,CURRENT_OBJ#,CURRENT_FILE# from gv$active_session_history]' || COREMOD_API.get_dblink_for_query(p_data.dblink) || q'[ where sql_id = :p_sql_id]';
    --l_sql := replace(l_sql,'<SRC_DB_COL_LICT>',COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_data.dblink, P_KEY => 'TABCOLLIST_GV_$ACTIVE_SESSION_HISTORY'));
    execute immediate l_sql using p_data.sql_id;
    l_sql := null;

    select listagg(CURRENT_OBJ#,',')within group (order by CURRENT_OBJ#) into l_obj_lst from (select unique CURRENT_OBJ# from opas_ot_tmp_gv$ash);
    if l_obj_lst is not null then
      l_sql := q'[INSERT INTO opas_ot_tmp_gv$ash_objs ( object_id, object_type, object_name)
                 select    object_id, object_type, object_name from dba_objects]' ||
                COREMOD_API.get_dblink_for_query(p_data.dblink)
                || ' s where s.object_id in ('||l_obj_lst||')';
      execute immediate l_sql;
      l_sql := null;
    end if;

    select listagg(CURRENT_FILE#,',')within group (order by CURRENT_FILE#) into l_obj_lst from (select unique CURRENT_FILE# from opas_ot_tmp_gv$ash);
    if l_obj_lst is not null then
      l_sql := q'[INSERT INTO opas_ot_tmp_gv$ash_objs ( object_id, object_type, object_name)
             select    FILE_ID, 'TABLESPACE', TABLESPACE_NAME from dba_data_files]' ||
               COREMOD_API.get_dblink_for_query(p_data.dblink)
               || ' s where s.FILE_ID in ('||l_obj_lst||')';
      execute immediate l_sql;
      l_sql := null;
    end if;

    INSERT INTO opas_ot_sql_vash1 ( sql_data_point_id, sql_id, sql_exec_start, sql_exec_end, plan_hash_value, id, row_src, event, cnt, tim_pct, tim_id_pct, obj, tbs)
    select p_data.sql_data_point_id,p_data.sql_id,
       SQL_EXEC_START,
       to_date(to_char(max(sample_time) over(partition by SQL_EXEC_START, plan_hash_value),'YYYYMMDDHH24MISS'),'YYYYMMDDHH24MISS') sql_exec_end,
       plan_hash_value, id, row_src, event, cnt,
       round(100 * cnt / sum(cnt) over(partition by SQL_EXEC_START, plan_hash_value), 2) tim_pct,
       round(100 * sum(cnt) over(partition by id, SQL_EXEC_START, plan_hash_value) / sum(cnt) over(partition by SQL_EXEC_START, plan_hash_value), 2) tim_id_pct,
       obj, tbs
       from (select
               trunc(SQL_EXEC_START,'HH') SQL_EXEC_START,
               sql_plan_hash_value plan_hash_value,
               sql_plan_line_id id,
               sql_plan_operation || ' ' || sql_plan_options row_src,
               obj,tbs,
               nvl(event, 'CPU') event,
               count(1) cnt,
               max(sample_time) sample_time
          from (select x.*,
                       case when CURRENT_OBJ#>0 then (select object_type||'.'||object_name from opas_ot_tmp_gv$ash_objs where object_id=CURRENT_OBJ# and object_type!='TABLESPACE') else to_char(CURRENT_OBJ#) end obj,
                       case when CURRENT_FILE#>0 then (select object_name from opas_ot_tmp_gv$ash_objs where object_id=CURRENT_FILE# and object_type='TABLESPACE') else null end tbs
            from opas_ot_tmp_gv$ash x)
         group by trunc(SQL_EXEC_START,'HH'),
                  sql_plan_hash_value,
                  sql_plan_line_id,
                  sql_plan_operation || ' ' || sql_plan_options,
                  nvl(event, 'CPU'),
                  obj,tbs) x;
    l_rows := l_rows + sql%rowcount;

    INSERT INTO opas_ot_sql_vash2 (sql_data_point_id, sql_id, plan_hash_value, id, row_src, event, cnt, tim_pct, tim_id_pct, obj, tbs)
      select p_data.sql_data_point_id,p_data.sql_id,
             plan_hash_value, id, row_src, event, cnt,
             round(100 * cnt / sum(cnt) over(partition by id), 2),
             round(100 * sum(cnt) over(partition by id) / sum(cnt) over()),
             obj, tbs
        from (select sql_plan_hash_value plan_hash_value,
               sql_plan_line_id id,
               sql_plan_operation || ' ' || sql_plan_options row_src,
               obj,tbs,
               nvl(event, 'CPU') event,
               count(1) cnt
          from (select x.*,
                       case when CURRENT_OBJ#>0 then (select object_type||'.'||object_name from opas_ot_tmp_gv$ash_objs where object_id=CURRENT_OBJ# and object_type!='TABLESPACE') else to_char(CURRENT_OBJ#) end obj,
                       case when CURRENT_FILE#>0 then (select object_name from opas_ot_tmp_gv$ash_objs where object_id=CURRENT_FILE# and object_type='TABLESPACE') else null end tbs
            from opas_ot_tmp_gv$ash x)
         group by sql_plan_hash_value,
                  sql_plan_line_id,
                  sql_plan_operation || ' ' || sql_plan_options,
                  nvl(event, 'CPU'),
                  obj,tbs) x;
    l_rows := l_rows + sql%rowcount;

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsVASH, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      if l_sql is not null then coremod_tasks.log('Error load_sql_plans ('||p_data.sql_data_point_id||'): '||l_sql); end if;
      coremod_tasks.log('Error load_sql_plans ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsVASH, sqlerrm);
  end;

  ------------------------------------------------------------
  ------------------------------------------------------------
  ------------------------------------------------------------

  procedure load_awr_sqlstats(p_data       opas_ot_sql_data%rowtype,
                              p_awr_params t_awr_params_rec)
  is
    l_sql  varchar2(32765);
    l_rows number;
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_SQLSTAT);

    l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_AWRSQLST */ into opas_ot_tmp_awrsqlstat (<SRC_DB_COL_LICT>)
           select <SRC_DB_COL_LICT>
           from dba_hist_sqlstat]' || COREMOD_API.get_dblink_for_query(p_data.dblink) ||
           q'[ where sql_id=:p_sql_id and dbid = :p_dbid and snap_id between :p1 and :p2 and INSTANCE_NUMBER in (<INST_LST>) <CON_FILTER>]';

    l_sql := replace(l_sql,'<SRC_DB_COL_LICT>',COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_data.dblink, P_KEY => 'TABCOLLIST_DBA_HIST_SQLSTAT'));
    l_sql := replace(l_sql,'<INST_LST>', p_awr_params.INSTANCE_LIST_C);

    if p_awr_params.CON_ID is not null and instr(COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_data.dblink, P_KEY => 'TABCOLLIST_DBA_HIST_SQLSTAT'),'CON_ID') > 0 then
      l_sql := replace(l_sql,'<CON_FILTER>','and CON_ID = '||p_awr_params.CON_ID);
    else
      l_sql := replace(l_sql,'<CON_FILTER>','');
    end if;

    execute immediate l_sql using p_data.sql_id, p_awr_params.DBID, p_awr_params.SNAP_START, p_awr_params.SNAP_END;
    l_rows := sql%rowcount;

    merge into opas_ot_sql_awr_sqlstat t
      using opas_ot_tmp_awrsqlstat s
      on (t.snap_id = s.snap_id and
          t.DBID = s.DBID and
          t.INSTANCE_NUMBER = s.INSTANCE_NUMBER and
          t.SQL_ID = s.SQL_ID and
          t.DBLINK = p_data.dblink and
          t.PLAN_HASH_VALUE = s.PLAN_HASH_VALUE and
          t.INCARNATION# = p_awr_params.INCARNATION# and
          decode(t.CON_DBID,s.CON_DBID,1,0) = 1
      ) when not matched then insert (
      DBLINK, snap_id, DBID, INSTANCE_NUMBER, SQL_ID, PLAN_HASH_VALUE, OPTIMIZER_COST, OPTIMIZER_MODE, OPTIMIZER_ENV_HASH_VALUE, SHARABLE_MEM, LOADED_VERSIONS, VERSION_COUNT,
      MODULE, ACTION, SQL_PROFILE, FORCE_MATCHING_SIGNATURE, PARSING_SCHEMA_ID, PARSING_SCHEMA_NAME, PARSING_USER_ID, FETCHES_TOTAL, FETCHES_DELTA, END_OF_FETCH_COUNT_TOTAL,
      END_OF_FETCH_COUNT_DELTA, SORTS_TOTAL, SORTS_DELTA, EXECUTIONS_TOTAL, EXECUTIONS_DELTA, PX_SERVERS_EXECS_TOTAL, PX_SERVERS_EXECS_DELTA, LOADS_TOTAL, LOADS_DELTA,
      INVALIDATIONS_TOTAL, INVALIDATIONS_DELTA, PARSE_CALLS_TOTAL, PARSE_CALLS_DELTA, DISK_READS_TOTAL, DISK_READS_DELTA, BUFFER_GETS_TOTAL, BUFFER_GETS_DELTA, ROWS_PROCESSED_TOTAL,
      ROWS_PROCESSED_DELTA, CPU_TIME_TOTAL, CPU_TIME_DELTA, ELAPSED_TIME_TOTAL, ELAPSED_TIME_DELTA, IOWAIT_TOTAL, IOWAIT_DELTA, CLWAIT_TOTAL, CLWAIT_DELTA, APWAIT_TOTAL, APWAIT_DELTA,
      CCWAIT_TOTAL, CCWAIT_DELTA, DIRECT_WRITES_TOTAL, DIRECT_WRITES_DELTA, PLSEXEC_TIME_TOTAL, PLSEXEC_TIME_DELTA, JAVEXEC_TIME_TOTAL, JAVEXEC_TIME_DELTA,
      IO_OFFLOAD_ELIG_BYTES_TOTAL, IO_OFFLOAD_ELIG_BYTES_DELTA, IO_INTERCONNECT_BYTES_TOTAL, IO_INTERCONNECT_BYTES_DELTA, PHYSICAL_READ_REQUESTS_TOTAL, PHYSICAL_READ_REQUESTS_DELTA,
      PHYSICAL_READ_BYTES_TOTAL, PHYSICAL_READ_BYTES_DELTA, PHYSICAL_WRITE_REQUESTS_TOTAL, PHYSICAL_WRITE_REQUESTS_DELTA, PHYSICAL_WRITE_BYTES_TOTAL, PHYSICAL_WRITE_BYTES_DELTA,
      OPTIMIZED_PHYSICAL_READS_TOTAL, OPTIMIZED_PHYSICAL_READS_DELTA, CELL_UNCOMPRESSED_BYTES_TOTAL, CELL_UNCOMPRESSED_BYTES_DELTA, IO_OFFLOAD_RETURN_BYTES_TOTAL,
      IO_OFFLOAD_RETURN_BYTES_DELTA, BIND_DATA, FLAG, OBSOLETE_COUNT, CON_DBID, CON_ID, INCARNATION#)
      values (
      p_data.dblink, s.snap_id, s.DBID, s.INSTANCE_NUMBER, s.SQL_ID, s.PLAN_HASH_VALUE, s.OPTIMIZER_COST, s.OPTIMIZER_MODE, s.OPTIMIZER_ENV_HASH_VALUE, s.SHARABLE_MEM, s.LOADED_VERSIONS, s.VERSION_COUNT,
      s.MODULE, s.ACTION, s.SQL_PROFILE, s.FORCE_MATCHING_SIGNATURE, s.PARSING_SCHEMA_ID, s.PARSING_SCHEMA_NAME, s.PARSING_USER_ID, s.FETCHES_TOTAL, s.FETCHES_DELTA, s.END_OF_FETCH_COUNT_TOTAL,
      s.END_OF_FETCH_COUNT_DELTA, s.SORTS_TOTAL, s.SORTS_DELTA, s.EXECUTIONS_TOTAL, s.EXECUTIONS_DELTA, s.PX_SERVERS_EXECS_TOTAL, s.PX_SERVERS_EXECS_DELTA, s.LOADS_TOTAL, s.LOADS_DELTA,
      s.INVALIDATIONS_TOTAL, s.INVALIDATIONS_DELTA, s.PARSE_CALLS_TOTAL, s.PARSE_CALLS_DELTA, s.DISK_READS_TOTAL, s.DISK_READS_DELTA, s.BUFFER_GETS_TOTAL, s.BUFFER_GETS_DELTA, s.ROWS_PROCESSED_TOTAL,
      s.ROWS_PROCESSED_DELTA, s.CPU_TIME_TOTAL, s.CPU_TIME_DELTA, s.ELAPSED_TIME_TOTAL, s.ELAPSED_TIME_DELTA, s.IOWAIT_TOTAL, s.IOWAIT_DELTA, s.CLWAIT_TOTAL, s.CLWAIT_DELTA, s.APWAIT_TOTAL,
      s.APWAIT_DELTA, s.CCWAIT_TOTAL, s.CCWAIT_DELTA, s.DIRECT_WRITES_TOTAL, s.DIRECT_WRITES_DELTA, s.PLSEXEC_TIME_TOTAL, s.PLSEXEC_TIME_DELTA, s.JAVEXEC_TIME_TOTAL, s.JAVEXEC_TIME_DELTA,
      s.IO_OFFLOAD_ELIG_BYTES_TOTAL, s.IO_OFFLOAD_ELIG_BYTES_DELTA, s.IO_INTERCONNECT_BYTES_TOTAL, s.IO_INTERCONNECT_BYTES_DELTA, s.PHYSICAL_READ_REQUESTS_TOTAL, s.PHYSICAL_READ_REQUESTS_DELTA,
      s.PHYSICAL_READ_BYTES_TOTAL, s.PHYSICAL_READ_BYTES_DELTA, s.PHYSICAL_WRITE_REQUESTS_TOTAL, s.PHYSICAL_WRITE_REQUESTS_DELTA, s.PHYSICAL_WRITE_BYTES_TOTAL, s.PHYSICAL_WRITE_BYTES_DELTA,
      s.OPTIMIZED_PHYSICAL_READS_TOTAL, s.OPTIMIZED_PHYSICAL_READS_DELTA, s.CELL_UNCOMPRESSED_BYTES_TOTAL, s.CELL_UNCOMPRESSED_BYTES_DELTA, s.IO_OFFLOAD_RETURN_BYTES_TOTAL,
      s.IO_OFFLOAD_RETURN_BYTES_DELTA, s.BIND_DATA, s.FLAG, s.OBSOLETE_COUNT, s.CON_DBID, s.CON_ID, p_awr_params.INCARNATION#);

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_SQLSTAT, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      coremod_tasks.log('Error load_awr_sqlstats ('||p_data.sql_data_point_id||'): '||l_sql);
      coremod_tasks.log('Error load_awr_sqlstats ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_SQLSTAT, sqlerrm);
  end;

  procedure load_awr_sqlbinds(p_data       opas_ot_sql_data%rowtype,
                              p_awr_params t_awr_params_rec)
  is
    l_sql  varchar2(32765);
    l_rows number;
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_BINDS);

    l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_AWRSQLBI */ into opas_ot_tmp_awrsqlbind (<SRC_DB_COL_LICT>)
           select <SRC_DB_COL_LICT>
           from dba_hist_sqlbind]' || COREMOD_API.get_dblink_for_query(p_data.dblink) ||
           q'[ where sql_id=:p_sql_id and dbid = :p_dbid and snap_id between :p1 and :p2 and INSTANCE_NUMBER in (<INST_LST>) <CON_FILTER>]';

    l_sql := replace(l_sql,'<SRC_DB_COL_LICT>',COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_data.dblink, P_KEY => 'TABCOLLIST_DBA_HIST_SQLBIND'));
    l_sql := replace(l_sql,'<INST_LST>', p_awr_params.INSTANCE_LIST_C);

    if p_awr_params.CON_ID is not null and instr(COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_data.dblink, P_KEY => 'TABCOLLIST_DBA_HIST_SQLBIND'),'CON_ID') > 0 then
      l_sql := replace(l_sql,'<CON_FILTER>','and CON_ID = '||p_awr_params.CON_ID);
    else
      l_sql := replace(l_sql,'<CON_FILTER>','');
    end if;

    execute immediate l_sql using p_data.sql_id, p_awr_params.DBID, p_awr_params.SNAP_START, p_awr_params.SNAP_END;
    l_rows := sql%rowcount;

    merge into opas_ot_sql_awr_sqlbind t
      using opas_ot_tmp_awrsqlbind s
      on (t.snap_id = s.snap_id and
          t.DBID = s.DBID and
          t.INSTANCE_NUMBER = s.INSTANCE_NUMBER and
          t.SQL_ID = s.SQL_ID and
          t.DBLINK = p_data.dblink and
          t.POSITION = s.POSITION and
          t.INCARNATION# = p_awr_params.INCARNATION# and
          decode(t.CON_DBID,s.CON_DBID,1,0) = 1
      ) when not matched then insert (
        DBLINK, snap_id, DBID, INSTANCE_NUMBER, SQL_ID, NAME, POSITION, DUP_POSITION, DATATYPE, DATATYPE_STRING, CHARACTER_SID, PRECISION,
        SCALE, MAX_LENGTH, WAS_CAPTURED, LAST_CAPTURED, VALUE_STRING, VALUE_ANYDATA, CON_DBID, CON_ID, INCARNATION#)
      values (
        p_data.dblink, s.snap_id, s.DBID, s.INSTANCE_NUMBER, s.SQL_ID, s.NAME, s.POSITION, s.DUP_POSITION, s.DATATYPE, s.DATATYPE_STRING, s.CHARACTER_SID, s.PRECISION,
        s.SCALE, s.MAX_LENGTH, s.WAS_CAPTURED, s.LAST_CAPTURED, s.VALUE_STRING, s.VALUE_ANYDATA, s.CON_DBID, s.CON_ID, p_awr_params.INCARNATION#);

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_BINDS, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      coremod_tasks.log('Error load_awr_sqlbinds ('||p_data.sql_data_point_id||'): '||l_sql);
      coremod_tasks.log('Error load_awr_sqlbinds ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_BINDS, sqlerrm);
  end;

  procedure load_awr_plans(p_data   opas_ot_sql_data%rowtype,
                           p_awr_params t_awr_params_rec)
  is
    l_sql        varchar2(32765);
    l_rows       number;
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_SQLPLAN);

    l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_AWRPLANS */ INTO opas_ot_tmp_dbh_plan (<SRC_DB_COL_LICT>)
              select <SRC_DB_COL_LICT> from dba_hist_sql_plan]' || COREMOD_API.get_dblink_for_query(p_data.dblink) ||
           q'[ where sql_id=:p_sql_id and dbid = :p_dbid <CON_FILTER>]';

    l_sql := replace(l_sql,'<SRC_DB_COL_LICT>',COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_data.dblink, P_KEY => 'TABCOLLIST_DBA_HIST_SQL_PLAN'));

    if p_awr_params.CON_ID is not null and instr(COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_data.dblink, P_KEY => 'TABCOLLIST_DBA_HIST_SQL_PLAN'),'CON_ID') > 0 then
      l_sql := replace(l_sql,'<CON_FILTER>','and CON_ID = '||p_awr_params.CON_ID);
    else
      l_sql := replace(l_sql,'<CON_FILTER>','');
    end if;

    execute immediate l_sql using p_data.sql_id, p_awr_params.DBID;
    l_rows := sql%rowcount;
    l_sql := null;

    INSERT INTO opas_ot_tmp_dbh_plan_key
           ( plan_id,                   plan_hash_value)
     select opas_ot_sq_awrplan_id.nextval, plan_hash_value
       from (select unique plan_hash_value from opas_ot_tmp_dbh_plan);

    insert all
      WHEN op = 'I' THEN
      into opas_ot_sql_awr_plans    ( plan_id, created, sql_id, dbid, plan_hash_value, INCARNATION#) values (plan_id, created, sql_id, dbid, plan_hash_value, INCARNATION#)
      WHEN op in ('I', 'R') THEN
      into opas_ot_sql_awr_plan_ref ( sql_data_point_id, plan_id) values( p_data.sql_data_point_id, plan_id)
      select 'I' op, plan_id, systimestamp created, p_data.sql_id sql_id, p_awr_params.DBID dbid, plan_hash_value, p_awr_params.INCARNATION# INCARNATION#
        from opas_ot_tmp_dbh_plan_key k
       where not exists (select 1 from opas_ot_sql_awr_plans p where p.sql_id=p_data.sql_id and p.dbid=p_awr_params.DBID and p.PLAN_HASH_VALUE=k.PLAN_HASH_VALUE)
      union all
      select 'R' op, p.plan_id, systimestamp created, p_data.sql_id sql_id, p_awr_params.DBID dbid, p.plan_hash_value, p_awr_params.INCARNATION# INCARNATION#
        from opas_ot_sql_awr_plans p, opas_ot_tmp_dbh_plan_key k
       where p.sql_id=p_data.sql_id and p.dbid=p_awr_params.DBID and p.PLAN_HASH_VALUE=k.PLAN_HASH_VALUE;

    delete from opas_ot_tmp_dbh_plan_key where plan_id not in (select plan_id from opas_ot_sql_awr_plans where sql_id=p_data.sql_id and dbid = p_awr_params.DBID);

    insert all into opas_ot_sql_awr_plan_det (
        plan_id,
        dbid, SQL_ID, PLAN_HASH_VALUE, ID, OPERATION, OPTIONS, OBJECT_NODE, OBJECT#, OBJECT_OWNER, OBJECT_NAME, OBJECT_ALIAS, OBJECT_TYPE,
        OPTIMIZER, PARENT_ID, DEPTH, POSITION, SEARCH_COLUMNS, COST, CARDINALITY, BYTES, OTHER_TAG, PARTITION_START, PARTITION_STOP, PARTITION_ID,
        OTHER, DISTRIBUTION, CPU_COST, IO_COST, TEMP_SPACE, ACCESS_PREDICATES, FILTER_PREDICATES, PROJECTION, TIME, QBLOCK_NAME, REMARKS, TIMESTAMP,
        OTHER_XML, CON_DBID, CON_ID)
      values (
        plan_id,
        dbid, SQL_ID, PLAN_HASH_VALUE, ID, OPERATION, OPTIONS, OBJECT_NODE, OBJECT#, OBJECT_OWNER, OBJECT_NAME, OBJECT_ALIAS, OBJECT_TYPE,
        OPTIMIZER, PARENT_ID, DEPTH, POSITION, SEARCH_COLUMNS, COST, CARDINALITY, BYTES, OTHER_TAG, PARTITION_START, PARTITION_STOP, PARTITION_ID,
        OTHER, DISTRIBUTION, CPU_COST, IO_COST, TEMP_SPACE, ACCESS_PREDICATES, FILTER_PREDICATES, PROJECTION, TIME, QBLOCK_NAME, REMARKS, TIMESTAMP,
        OTHER_XML, CON_DBID, CON_ID)
    select p.*, k.plan_id
      from opas_ot_tmp_dbh_plan p,
           opas_ot_tmp_dbh_plan_key k
     where p.plan_hash_value = k.plan_hash_value;

    select count(1) into l_rows from opas_ot_sql_awr_plan_ref where sql_data_point_id = p_data.sql_data_point_id;

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_SQLPLAN, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      if l_sql is not null then coremod_tasks.log('Error load_awr_plans ('||p_data.sql_data_point_id||'): '||l_sql);  end if;
      coremod_tasks.log('Error load_awr_plans ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);

      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_SQLPLAN, sqlerrm);
  end;

  procedure load_awr_sqlash (p_data       opas_ot_sql_data%rowtype,
                             p_awr_params t_awr_params_rec)
  is
    l_sql        varchar2(32765);
    l_rows       number;
    l_obj_lst    varchar2(32765);
  begin
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_PLSQLSRC);
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_ASHINVOKER);
    start_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_ASHPLSTATS);

    l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_AWRASH */ into opas_ot_tmp_dbh_ash (
                  dbid, SNAP_ID, SESSION_ID, SESSION_SERIAL#, INSTANCE_NUMBER, SQL_ID, TOP_LEVEL_SQL_ID, USER_ID, PROGRAM, MACHINE, MODULE, ACTION,
                  CLIENT_ID, ECID, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID, FORCE_MATCHING_SIGNATURE,
                  SQL_CHILD_NUMBER, SQL_PLAN_HASH_VALUE, SQL_FULL_PLAN_HASH_VALUE, SQL_EXEC_ID, SQL_EXEC_START, SQL_PLAN_LINE_ID, SQL_PLAN_OPERATION, EVENT,
                  SQL_PLAN_OPTIONS, SESSION_TYPE, CON_ID, CON_DBID, MIN_SAMPLE_TIME, MAX_SAMPLE_TIME, CNT, PGA_ALLOCATED, TEMP_SPACE_ALLOCATED,
                  CURRENT_OBJ#,CURRENT_FILE#)
           select dbid, snap_id, session_id, session_serial#, instance_number, sql_id, TOP_LEVEL_SQL_ID, user_id, program, machine, module, action,
                  client_id, ecid, plsql_entry_object_id, plsql_entry_subprogram_id, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID, force_matching_signature,
                  sql_child_number, sql_plan_hash_value, sql_full_plan_hash_value, SQL_EXEC_ID, SQL_EXEC_START, sql_plan_line_id, sql_plan_operation, event,
                  sql_plan_options, session_type, con_id, con_dbid, min(sample_time) min_sample_time, max(sample_time) max_sample_time, count(1) cnt,
                  max(pga_allocated) pga_allocated, max(temp_space_allocated) temp_space_allocated,
                  CURRENT_OBJ#,CURRENT_FILE#
             from dba_hist_active_sess_history]' || COREMOD_API.get_dblink_for_query(p_data.dblink) ||
           q'[ where sql_id=:p_sql_id and dbid = :p_dbid and snap_id between :p1 and :p2 and INSTANCE_NUMBER in (<INST_LST>)
           group by
             dbid, snap_id, session_id, session_serial#, instance_number, sql_id, TOP_LEVEL_SQL_ID, user_id, program, machine, module, action,
             client_id, ecid, plsql_entry_object_id, plsql_entry_subprogram_id, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID, force_matching_signature,
             sql_child_number, sql_plan_hash_value, sql_full_plan_hash_value, SQL_EXEC_ID, SQL_EXEC_START, sql_plan_line_id, sql_plan_operation, event,
             sql_plan_options, session_type, con_id, con_dbid,
             CURRENT_OBJ#,CURRENT_FILE#]';

    l_sql := replace(l_sql,'<INST_LST>', p_awr_params.INSTANCE_LIST_C);

    execute immediate l_sql using p_data.sql_id, p_awr_params.DBID, p_awr_params.SNAP_START, p_awr_params.SNAP_END;
    l_rows := sql%rowcount;

    for i in (select plsql_entry_object_id, plsql_entry_subprogram_id from opas_ot_tmp_dbh_ash where plsql_entry_object_id is not null union
              select PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID from opas_ot_tmp_dbh_ash where PLSQL_OBJECT_ID is not null) loop
      l_sql := q'[INSERT INTO opas_ot_tmp_awr_ash_objs
                   ( object_id, subprogram_id, owner, object_type, object_name, PROCEDURE_NAME)
           select    object_id, subprogram_id, owner, object_type, object_name, PROCEDURE_NAME from dba_procedures]' ||
             COREMOD_API.get_dblink_for_query(p_data.dblink)
             || ' s where s.object_id=:p_program_id and decode(s.subprogram_id,:p_subprogram_id,1,0)=1';
      execute immediate l_sql using i.plsql_entry_object_id, i.plsql_entry_subprogram_id;
      l_sql:=null;
    end loop;

    for i in (select unique user_id from opas_ot_tmp_dbh_ash where user_id is not null) loop
      l_sql := q'[INSERT INTO opas_ot_tmp_awr_ash_objs
                   ( object_id, subprogram_id, owner, object_type, object_name, PROCEDURE_NAME)
           select    USER_ID,   null, null, 'USER', USERNAME, null from dba_users]' ||
             COREMOD_API.get_dblink_for_query(p_data.dblink)
             || ' s where s.USER_ID=:p_user_id';
      execute immediate l_sql using i.user_id;
      l_sql:=null;
    end loop;

    select listagg(CURRENT_OBJ#,',')within group (order by CURRENT_OBJ#) into l_obj_lst from (select unique CURRENT_OBJ# from opas_ot_tmp_dbh_ash);
    if l_obj_lst is not null then
      l_sql := q'[INSERT INTO opas_ot_tmp_awr_ash_objs ( object_id, object_type, object_name)
                 select    object_id, object_type, object_name from dba_objects]' ||
                COREMOD_API.get_dblink_for_query(p_data.dblink)
                || ' s where s.object_id in ('||l_obj_lst||')';
      execute immediate l_sql;
      l_sql := null;
    end if;

    select listagg(CURRENT_FILE#,',')within group (order by CURRENT_FILE#) into l_obj_lst from (select unique CURRENT_FILE# from opas_ot_tmp_dbh_ash);
    if l_obj_lst is not null then
      l_sql := q'[INSERT INTO opas_ot_tmp_awr_ash_objs ( object_id, object_type, object_name)
             select    FILE_ID, 'TABLESPACE', TABLESPACE_NAME from dba_data_files]' ||
               COREMOD_API.get_dblink_for_query(p_data.dblink)
               || ' s where s.FILE_ID in ('||l_obj_lst||')';
      execute immediate l_sql;
      l_sql := null;
    end if;

    merge into opas_ot_sql_awr_ash_summ t
      using (
        select x2.*,
               (select object_name from opas_ot_tmp_awr_ash_objs i where object_id=user_id and object_type = 'USER') username,
               (select owner || '; ' || object_type || '; ' || object_name || decode(procedure_name, null, null, '.' || procedure_name)
                 from opas_ot_tmp_awr_ash_objs i where object_id=plsql_entry_object_id and subprogram_id=plsql_entry_subprogram_id  and object_type != 'USER') plsql_top,
               (select owner || '; ' || object_type || '; ' || object_name || decode(procedure_name, null, null, '.' || procedure_name)
                 from opas_ot_tmp_awr_ash_objs i where object_id=plsql_object_id and subprogram_id=plsql_subprogram_id and object_type != 'USER') plsql_end
         from (
           select
                  row_number()over(partition by SNAP_ID order by samples desc) topn,
                  x1.*
             from (
               select
                 dbid, SNAP_ID, SESSION_ID, SESSION_SERIAL#, INSTANCE_NUMBER, SQL_ID, TOP_LEVEL_SQL_ID, USER_ID, PROGRAM, MACHINE, MODULE, ACTION,
                 CLIENT_ID, ECID, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID, FORCE_MATCHING_SIGNATURE,
                 SQL_CHILD_NUMBER, SQL_PLAN_HASH_VALUE, SQL_FULL_PLAN_HASH_VALUE, SQL_EXEC_ID, SQL_EXEC_START, session_type, con_id, con_dbid,
                 min(MIN_SAMPLE_TIME) MIN_SAMPLE_TIME, max(MAX_SAMPLE_TIME) MAX_SAMPLE_TIME, sum(CNT) samples, max(PGA_ALLOCATED) PGA_ALLOCATED, max(TEMP_SPACE_ALLOCATED)TEMP_SPACE_ALLOCATED
               from opas_ot_tmp_dbh_ash
               group by
                 dbid, SNAP_ID, SESSION_ID, SESSION_SERIAL#, INSTANCE_NUMBER, SQL_ID, TOP_LEVEL_SQL_ID, USER_ID, PROGRAM, MACHINE, MODULE, ACTION,
                 CLIENT_ID, ECID, PLSQL_ENTRY_OBJECT_ID, PLSQL_ENTRY_SUBPROGRAM_ID, PLSQL_OBJECT_ID, PLSQL_SUBPROGRAM_ID, FORCE_MATCHING_SIGNATURE,
                 SQL_CHILD_NUMBER, SQL_PLAN_HASH_VALUE, SQL_FULL_PLAN_HASH_VALUE, SQL_EXEC_ID, SQL_EXEC_START,
                 SESSION_TYPE, CON_ID, CON_DBID
                 ) x1) x2 where topn <=3
            ) s
      on (
        t.dblink = p_data.dblink and
        t.dbid = s.dbid and
        t.SNAP_ID = s.SNAP_ID and
        t.INSTANCE_NUMBER = s.INSTANCE_NUMBER and
        t.SQL_ID = s.SQL_ID and
        t.INCARNATION# = p_awr_params.INCARNATION# and
        t.topn = s.topn
      )
      when not matched then insert (
        topn, DBID, DBLINK, SNAP_ID, SESSION_ID, SESSION_SERIAL#, INSTANCE_NUMBER, SQL_ID, TOP_LEVEL_SQL_ID, USER_ID, PROGRAM, MACHINE, MODULE, ACTION,
        CLIENT_ID, ECID, FORCE_MATCHING_SIGNATURE, SQL_CHILD_NUMBER, SQL_PLAN_HASH_VALUE, SQL_FULL_PLAN_HASH_VALUE, SQL_EXEC_ID, SQL_EXEC_START,
        SESSION_TYPE, CON_ID, CON_DBID, USERNAME, PLSQL_TOP, PLSQL_END, MIN_SAMPLE_TIME, MAX_SAMPLE_TIME, SAMPLES, PGA_ALLOCATED, TEMP_SPACE_ALLOCATED,
        INCARNATION#
      ) values (
        s.topn, s.DBID, p_data.dblink, s.SNAP_ID, s.SESSION_ID, s.SESSION_SERIAL#, s.INSTANCE_NUMBER, s.SQL_ID, s.TOP_LEVEL_SQL_ID, s.USER_ID, s.PROGRAM, s.MACHINE, s.MODULE, s.ACTION,
        s.CLIENT_ID, s.ECID, s.FORCE_MATCHING_SIGNATURE, s.SQL_CHILD_NUMBER, s.SQL_PLAN_HASH_VALUE, s.SQL_FULL_PLAN_HASH_VALUE, s.SQL_EXEC_ID, s.SQL_EXEC_START,
        s.SESSION_TYPE, s.CON_ID, s.CON_DBID, s.USERNAME, s.PLSQL_TOP, s.PLSQL_END, s.MIN_SAMPLE_TIME, s.MAX_SAMPLE_TIME, s.SAMPLES, s.PGA_ALLOCATED, s.TEMP_SPACE_ALLOCATED,
        p_awr_params.INCARNATION#
      );

    merge into opas_ot_sql_awr_ash_plst t
      using (select
               x.*,
               case when CURRENT_OBJ#>0 then (select object_type||'.'||object_name from opas_ot_tmp_awr_ash_objs where object_id=CURRENT_OBJ# and object_type!='TABLESPACE') else to_char(CURRENT_OBJ#) end obj,
               case when CURRENT_FILE#>0 then (select object_name from opas_ot_tmp_awr_ash_objs where object_id=CURRENT_FILE# and object_type='TABLESPACE') else null end tbs
             from (
        select sql_id,dbid, snap_id, INSTANCE_NUMBER, sql_plan_hash_value,sql_full_plan_hash_value,
               sql_plan_line_id, sql_plan_operation,sql_plan_options, nvl(event, 'CPU') event,
               CURRENT_OBJ#,CURRENT_FILE#,
               sum(cnt) samples
          from opas_ot_tmp_dbh_ash
         group by sql_id,dbid, snap_id, INSTANCE_NUMBER, sql_plan_hash_value,sql_full_plan_hash_value,
                  sql_plan_line_id, sql_plan_operation, sql_plan_options, nvl(event, 'CPU'),
                  CURRENT_OBJ#,CURRENT_FILE#) x
             ) s
        on (
          t.dblink = p_data.dblink and
          t.dbid = s.dbid and
          t.SNAP_ID = s.SNAP_ID and
          t.sql_plan_hash_value = s.sql_plan_hash_value and
          t.SQL_ID = s.SQL_ID and
          t.sql_full_plan_hash_value = s.sql_full_plan_hash_value and
          t.sql_plan_line_id = s.sql_plan_line_id and
          t.event = s.event and
          t.INCARNATION# = p_awr_params.INCARNATION# and
          t.INSTANCE_NUMBER = s.INSTANCE_NUMBER
        )
      when not matched then insert (
        sql_id, DBID, SNAP_ID, SQL_PLAN_HASH_VALUE, SQL_FULL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID, SQL_PLAN_OPERATION,
        SQL_PLAN_OPTIONS, EVENT, SAMPLES, DBLINK, INSTANCE_NUMBER, OBJ, TBS, INCARNATION#
      ) values (
        s.sql_id, s.DBID, s.SNAP_ID, s.SQL_PLAN_HASH_VALUE, s.SQL_FULL_PLAN_HASH_VALUE, s.SQL_PLAN_LINE_ID, s.SQL_PLAN_OPERATION,
        s.SQL_PLAN_OPTIONS, s.EVENT, s.SAMPLES, p_data.dblink, s.INSTANCE_NUMBER, s.OBJ, s.TBS, p_awr_params.INCARNATION#
      );

    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_PLSQLSRC, p_rows_processed => l_rows);
    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_ASHINVOKER, p_rows_processed => l_rows);
    finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_ASHPLSTATS, p_rows_processed => l_rows);
  exception
    when others then
      rollback;
      coremod_tasks.log('Error load_awr_sqlash ('||p_data.sql_data_point_id||'): '||l_sql);
      coremod_tasks.log('Error load_awr_sqlash ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_PLSQLSRC, sqlerrm);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_ASHINVOKER, sqlerrm);
      finish_section(p_data.sql_data_point_id, COREOBJ_SQL_REPORT_UTILS.repsAWR_ASHPLSTATS, sqlerrm);
  end;

  -------------------------------------------------
  -------------------------------------------------
  -------------------------------------------------
  procedure update_dblink_db_info_awrsn(p_db_link_name     varchar2,
                                        p_days             number,
                                        p_start_dt         timestamp with time zone,
                                        p_end_dt           timestamp with time zone,
                                        p_search_last_days boolean,
                                        p_sql_id           varchar2 default null,
                                        p_params       out t_awr_params_rec)
  is
    l_sql        varchar2(32765);
    l_sql1       varchar2(32765);
    l_ts1        timestamp with time zone;
    l_ts2        timestamp with time zone;
    l_found      number;
  begin
    select DBLINK, dbid, CON_ID into p_params.DBLINK, p_params.DBID, p_params.CON_ID from OPAS_DB_LINK_V$DB where DBLINK = p_db_link_name and IS_ACTUAL = 'Y';

    delete from opas_dbl_tmp_awrsnaps;

    l_sql := q'[select incarnation# from v$database_incarnation]' || COREMOD_API.get_dblink_for_query(p_db_link_name) || q'[ where status='CURRENT']';
    execute immediate l_sql into p_params.INCARNATION#;
    l_sql := null;

    if p_days is not null then
      if p_search_last_days then
        l_sql :=q'[select max(END_INTERVAL_TIME), count(1) found_cnt from dba_hist_snapshot]' || COREMOD_API.get_dblink_for_query(p_db_link_name) ||
                q'[ s, dba_hist_sqlstat]' || COREMOD_API.get_dblink_for_query(p_db_link_name) ||
                q'[ q where s.dbid=q.dbid and s.dbid=:p_dbid and s.snap_id=q.snap_id and s.instance_number=q.instance_number and q.sql_id=:p_sql_id]';
        execute immediate l_sql into l_ts2, l_found using p_params.DBID, p_sql_id;
        l_sql := null;
      else
        l_ts2 := COREMOD_UTILS.get_remote_ts(p_db_link_name);
      end if;
      if l_ts2 is null then
        l_ts2 := systimestamp;
      end if;
      l_ts1 := l_ts2 - NUMTODSINTERVAL(p_days, 'day');
    else
      l_ts1 := p_start_dt;
      l_ts2 := p_end_dt;
    end if;

    l_sql :=q'[INSERT /*+ OPAS60_DBLINK_AWRSN */ INTO opas_dbl_tmp_awrsnaps (<SRC_DB_COL_LICT>)
              select <SRC_DB_COL_LICT> from dba_hist_snapshot]' || COREMOD_API.get_dblink_for_query(p_db_link_name) ||
              q'[ where END_INTERVAL_TIME between :d1 and :d2 and dbid=:p_dbid <CON_FILTER>]';


    l_sql := replace(l_sql,'<SRC_DB_COL_LICT>',COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_db_link_name, P_KEY => 'TABCOLLIST_DBA_HIST_SNAPSHOT'));

    if p_params.CON_ID is not null and instr(COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_db_link_name, P_KEY => 'TABCOLLIST_DBA_HIST_SNAPSHOT'),'CON_ID') > 0 then
      l_sql := replace(l_sql,'<CON_FILTER>','and CON_ID = '||p_params.CON_ID);
    else
      l_sql := replace(l_sql,'<CON_FILTER>','');
    end if;

    execute immediate l_sql using l_ts1, l_ts2, p_params.DBID;
    l_sql := null;

    select min(END_INTERVAL_TIME), max(END_INTERVAL_TIME),
           min(SNAP_ID), max(SNAP_ID)
      into p_params.BEGIN_INTERVAL_TIME,p_params.END_INTERVAL_TIME,
           p_params.SNAP_START,p_params.SNAP_END
    from opas_dbl_tmp_awrsnaps;

    select listagg(INSTANCE_NUMBER,',') within group (order by INSTANCE_NUMBER)
     into p_params.INSTANCE_LIST_C
    from ( select unique INSTANCE_NUMBER from opas_dbl_tmp_awrsnaps);

    merge into OPAS_DB_LINK_AWRSNAPS t
      using opas_dbl_tmp_awrsnaps s
      on (t.DBLINK = p_db_link_name and
          t.snap_id = s.snap_id and
          t.DBID = s.DBID and
          t.INSTANCE_NUMBER = s.INSTANCE_NUMBER and
          t.INCARNATION# = p_params.INCARNATION#)
      when not matched then insert (
       dblink, SNAP_ID, DBID, INSTANCE_NUMBER, STARTUP_TIME, BEGIN_INTERVAL_TIME, END_INTERVAL_TIME, FLUSH_ELAPSED, SNAP_LEVEL, ERROR_COUNT, SNAP_FLAG, SNAP_TIMEZONE, BEGIN_INTERVAL_TIME_TZ, END_INTERVAL_TIME_TZ, CON_ID,
       INCARNATION#
       ) values (
       p_db_link_name, s.SNAP_ID, s.DBID, s.INSTANCE_NUMBER, s.STARTUP_TIME, s.BEGIN_INTERVAL_TIME, s.END_INTERVAL_TIME, s.FLUSH_ELAPSED, s.SNAP_LEVEL, s.ERROR_COUNT, s.SNAP_FLAG, s.SNAP_TIMEZONE, s.BEGIN_INTERVAL_TIME_TZ, s.END_INTERVAL_TIME_TZ, s.CON_ID,
       p_params.INCARNATION#
       );
    --commit;
  exception
    when others then
      rollback;
      coremod_tasks.log('Error update_dblink_db_info_awrsn ('||p_sql_id||'): '||l_sql);
      coremod_tasks.log('Error update_dblink_db_info_awrsn ('||p_sql_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
  end;

  procedure gather_recursive_sql(p_data       opas_ot_sql_data%rowtype,
                                 p_obj_id     opas_ot_sql_data_point_ref.obj_id%type,
                                 p_awr_params t_awr_params_rec)
  is
    l_rec_v$     number;
    l_rec_awr    number;
    l_obj_id     opas_ot_sql_data_point_ref.obj_id%type;
    l_sql        varchar2(32765);
    l_owner      OPAS_OT_SQL_DESCRIPTIONS.CREATED_BY%type;
  begin
    l_rec_v$  := nvl(COREOBJ_API.get_param_n(p_obj_id, COREOBJ_SQL_UTILS.pnV$Recursive,    true), COREOBJ_SQL_UTILS.defV$Recursive);
    l_rec_awr := nvl(COREOBJ_API.get_param_n(p_obj_id, COREOBJ_SQL_UTILS.pnAWRRecursive,   true), COREOBJ_SQL_UTILS.defAWRRecursive);
    if l_rec_v$ >= 0 then
      l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_REC_SQL */ into opas_ot_tmp_rec_sql_ids (sql_id)
                 select sql_id from gv$active_session_history]' || COREMOD_API.get_dblink_for_query(p_data.dblink) || ' where top_level_sql_id=:p_sql_id and sql_id<>top_level_sql_id
                 group by sql_id
                 having count(1) > :p_limit';
      execute immediate l_sql using p_data.sql_id, l_rec_v$;
      l_sql := null;
    end if;
    if l_rec_awr >= 0 then
      l_sql :=q'[INSERT /*+ OPAS60_COREOBJ_SQL_UTILS_LOAD_REC_SQL */ into opas_ot_tmp_rec_sql_ids (sql_id)
                 select sql_id from dba_hist_active_sess_history]' || COREMOD_API.get_dblink_for_query(p_data.dblink)
                 || ' where top_level_sql_id=:p_sql_id and dbid = :p_dbid and snap_id between :p1 and :p2 and INSTANCE_NUMBER in (<INST_LST>) and sql_id<>top_level_sql_id
                 group by sql_id
                 having count(1) > :p_limit';
      l_sql := replace(l_sql,'<INST_LST>', p_awr_params.INSTANCE_LIST_C);

      execute immediate l_sql using p_data.sql_id, p_awr_params.DBID, p_awr_params.SNAP_START, p_awr_params.SNAP_END, l_rec_awr;
      l_sql := null;
    end if;

    select CREATED_BY into l_owner from OPAS_OT_SQL_DESCRIPTIONS where sql_id=p_data.sql_id;

    for i in (select unique sql_id from opas_ot_tmp_rec_sql_ids) loop
      COREOBJ_SQL.add (
        P_OBJ_ID   => l_obj_id, --new ID is created here
        P_OBJ_PRNT => p_obj_id,
        P_OWNER    => l_owner,
        P_DESCR    => 'Recursive SQL for SQL_ID='||p_data.SQL_ID,
        P_SQL_ID   => i.sql_id,
        P_DB_LINK  => p_data.DBLINK,
        p_prnt_dp  => p_data.sql_data_point_id) ;

      COREOBJ_API.set_param(p_obj_id   => l_obj_id,
                            p_par_name => COREOBJ_SQL_UTILS.pnV$Recursive,
                            p_NUM_PAR  => COREOBJ_SQL_UTILS.defV$Recursive);
      COREOBJ_API.set_param(p_obj_id   => l_obj_id,
                            p_par_name => COREOBJ_SQL_UTILS.pnAWRRecursive,
                            p_NUM_PAR  => COREOBJ_SQL_UTILS.defAWRRecursive);
    end loop;
  exception
    when others then
      rollback;
      coremod_tasks.log('Error gather_recursive_sql ('||p_data.sql_data_point_id||'): '||l_sql);
      coremod_tasks.log('Error gather_recursive_sql ('||p_data.sql_data_point_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
  end;

  procedure load_awr_data(p_data   opas_ot_sql_data%rowtype,
                          p_obj_id opas_ot_sql_data_point_ref.obj_id%type)
  is
    l_awrdays          number;
    l_start_dt         timestamp with time zone;
    l_end_dt           timestamp with time zone;
    l_search_last_days boolean := false;
  begin
    l_start_dt := COREOBJ_API.get_param_z(p_obj_id, pnAWRStartDT, false);
    l_end_dt := COREOBJ_API.get_param_z(p_obj_id, pnAWREndDT, false);

    if l_start_dt is not null and l_end_dt is not null then
      l_awrdays := null;
    else
      l_awrdays := nvl( COREOBJ_API.get_param_n(p_obj_id, pnAWRDataDays, true), defAWRDataDays);
      l_search_last_days := nvl( COREOBJ_API.get_param_c(p_obj_id, pnAWRSearchLastDays, true), defAWRSearchLastDays) = 'Y';
    end if;

    update_dblink_db_info_awrsn(p_db_link_name     => p_data.dblink,
                                p_days             => l_awrdays,
                                p_start_dt         => l_start_dt,
                                p_end_dt           => l_end_dt,
                                p_search_last_days => l_search_last_days,
                                p_sql_id           => p_data.sql_id,
                                p_params           => gAWRParams);

    update opas_ot_sql_data set
      AWR_SNAP_START = gAWRParams.SNAP_START,
      AWR_SNAP_END = gAWRParams.SNAP_END,
      INCARNATION#=gAWRParams.INCARNATION#
    where sql_data_point_id = p_data.sql_data_point_id;
    commit;

    load_awr_sqlstats(p_data, gAWRParams);
    commit;
    load_awr_sqlbinds(p_data, gAWRParams);
    commit;
    load_awr_plans(p_data, gAWRParams);
    commit;
    load_awr_sqlash(p_data, gAWRParams);
    commit;

    set_status_prep_recursive(p_data.sql_data_point_id);
    gather_recursive_sql(p_data, p_obj_id, gAWRParams);
    commit;
  end;

  ------------------------------------------------------------
  ------------------------------------------------------------
  ------------------------------------------------------------
  procedure discover_sql(p_sql_data_point_id   opas_ot_sql_data.sql_data_point_id%type)
  AS
    l_data       opas_ot_sql_data%rowtype;
    L_TASKNAME   OPAS_TASK.TASKNAME%type := 'OPAS_SQL_DISCOVER2';
    l_tq_id      OPAS_TASK_QUEUE.tq_id%type;
    l_obj_id     opas_ot_sql_data_point_ref.obj_id%type;
  BEGIN
    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_SQL_UTILS.DISCOVER_SQL.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_SQL_UTILS.DISCOVER_SQL.SQL_TRACE');

    start_processing(p_sql_data_point_id, l_data, l_obj_id);
    --init_section_statuses(p_sql_data_point_id);

    L_TASKNAME := case when l_data.prnt_data_point_id is null then 'OPAS_SQL_DISCOVER2' else 'OPAS_SQL_DISCOVER2_REC' end;

    l_tq_id:=COREMOD_TASKS.prep_execute_task (  P_TASKNAME => L_TASKNAME) ;
    COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => 'B1', p_num_par => p_sql_data_point_id);
    COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id ) ;
    update opas_ot_sql_data set tq_id2 = l_tq_id where sql_data_point_id = p_sql_data_point_id;
    commit;

    load_non_shared(l_data);
    commit;
    load_vsql(l_data);
    commit;
    load_work_area(l_data);
    commit;
    load_opt_env(l_data);
    commit;
    load_sql_vash(l_data);
    commit;
    load_awr_data(l_data, l_obj_id);
    commit;

    wait_processing_of_discovery2(p_sql_data_point_id);

    finalize_section_statuses(p_sql_data_point_id);
    finish_processing(p_sql_data_point_id);

    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_SQL_UTILS.DISCOVER_SQL.SQL_TRACE');
    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_SQL_UTILS.DISCOVER_SQL.GATHER_SQL_STAT');
  exception
    when others then
      finish_processing(p_sql_data_point_id,COREOBJ_SQL.sdoFAILED);
      coremod_tasks.log('Error discover_sql ('||p_sql_data_point_id||'): '||sqlerrm);
      coremod_tasks.log('Error discover_sql error stack: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      raise_application_error(-20000, 'Error discover_sql ('||p_sql_data_point_id||'): '||sqlerrm);
  END discover_sql;

  procedure discover_sql2(p_sql_data_point_id   opas_ot_sql_data.sql_data_point_id%type)
  AS
    l_data opas_ot_sql_data%rowtype;
    l_obj_id     opas_ot_sql_data_point_ref.obj_id%type;
  BEGIN
    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_SQL_UTILS.DISCOVER_SQL2.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_SQL_UTILS.DISCOVER_SQL2.SQL_TRACE');

    start_processing2(p_sql_data_point_id, l_data, l_obj_id);

    load_sql_text(l_data);
    commit;
    load_sql_ep_plans(l_data);
    commit;
    load_sql_plans(l_data);
    commit;
    load_sql_mon(l_data, l_obj_id);
    commit;
    load_sql_mon_hst(l_data, l_obj_id);
    commit;

    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_SQL_UTILS.DISCOVER_SQL2.SQL_TRACE');
    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_SQL_UTILS.DISCOVER_SQL2.GATHER_SQL_STAT');
  exception
    when others then
      coremod_tasks.log('Error discover_sql2 ('||p_sql_data_point_id||'): '||sqlerrm);
      coremod_tasks.log('Error discover_sql2 error stack: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      raise_application_error(-20000, 'Error discover_sql2 ('||p_sql_data_point_id||'): '||sqlerrm);
  END discover_sql2;

  procedure cancel_discover_sql (p_sql_data_point_id         opas_ot_sql_data.sql_data_point_id%type)
  is
  begin
    for i in (select * from opas_ot_sql_data where sql_data_point_id = p_sql_data_point_id) loop
      COREMOD_TASKS.cancel_task (  P_TQ_ID => i.tq_id) ;
      COREMOD_TASKS.stop_task   (  P_TQ_ID => i.tq_id) ;
      COREMOD_TASKS.cancel_task (  P_TQ_ID => i.tq_id2) ;
      COREMOD_TASKS.stop_task   (  P_TQ_ID => i.tq_id2) ;
    end loop;

    finalize_section_statuses(p_sql_data_point_id);
    finish_processing(p_sql_data_point_id);

    update OPAS_OT_SQL_DATA_SECT set
     GATHERING_STATUS = sstEmpty
     where SQL_DATA_POINT_ID = p_sql_data_point_id and GATHERING_STATUS in (sstInProgress);
    commit;

  end;

  procedure refresh_section(p_sql_data_point_id   opas_ot_sql_data.sql_data_point_id%type,
                            p_section_name varchar2)
  AS
    l_data  opas_ot_sql_data%rowtype;
    l_obj_id     opas_ot_sql_data_point_ref.obj_id%type;
  BEGIN
    case when p_section_name = COREOBJ_SQL_REPORT_UTILS.repsSQLMONV$ then
      begin
        for i in (select d.* from opas_ot_sql_data d
                   where sql_data_point_id = p_sql_data_point_id
                     and gathering_status = COREOBJ_SQL.sdoREADY) loop
          select obj_id into l_obj_id from OPAS_OT_SQL_DATA_POINT_REF where sql_data_point_id = p_sql_data_point_id;
          load_sql_mon(i, l_obj_id);
          commit;
        end loop;
      end;
    else
      raise_application_error(-20000,'Not implemented for section: '||p_section_name);
    end case;
  END refresh_section;

  procedure getdatacmd
                  (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_sql_id           opas_ot_sql_descriptions.sql_id%type,
                   p_db_link          opas_db_links.db_link_name%type,
                   p_current_dir      varchar2,
                   p_gather_new       boolean,
                   p_dirname      out varchar2)
  is
    l_folder   opas_objects.obj_id%type;
  begin
    p_dirname := replace(p_current_dir,'\','/');
    p_dirname := substr(p_dirname,instr(p_dirname,'/',-1)+1);

    begin
      select obj_id into l_folder from opas_objects where obj_prnt=p_obj_prnt and OBJ_OT = COREOBJ_API.otFOLDER and OBJ_NAME = p_dirname;
    exception
      when no_data_found then
        if p_gather_new then
          COREOBJ_FOLDER.add (  P_OBJ_ID      => l_folder,
                                P_OBJ_PRNT    => p_obj_prnt,
                                p_folder_name => p_dirname) ;
        else
          raise_application_error(-20000, 'Directory '||p_dirname||' not found. Either go to the directory where data has been gathered or gather the data here.');
        end if;
    end;

    if p_gather_new then
	  COREOBJ_SQL.add (
        P_OBJ_ID   =>   p_obj_id,
        P_OBJ_PRNT => l_folder,
        P_OWNER    => 'PUBLIC',
        P_DESCR    => 'SQL Data gathering from CMD',
        P_SQL_ID   => p_sql_id,
        P_DB_LINK  => p_db_link) ;
    else
      select max(o.obj_id) into p_obj_id
        from opas_objects o,
             OPAS_OT_SQL_DATA_POINT_REF r,
             opas_ot_sql_data d
       where o.obj_prnt=l_folder
         and o.OBJ_OT=COREOBJ_API.otSQL_PERFORMANCE_DATA
         and o.obj_id=r.obj_id
         and r.sql_data_point_id=d.sql_data_point_id
         and d.sql_id=p_sql_id;
      if p_obj_id is null then
        raise_application_error(-20000, 'SQL data object for "'||p_sql_id||'" is not found in directory '||p_dirname);
      end if;
    end if;
  end;
END COREOBJ_SQL_UTILS;
/
