

CREATE OR REPLACE
PACKAGE BODY COREMOD_EXTPROC AS

  --gExtSQLCoordinator varchar2(128) := 'OPASEXTSQL';
  gsrvQueryPerServerSession number; -- init section below
  gsrvLoggingLevel          varchar2(10); -- init section below

  gRowsProcessed number;

  procedure log_info(p_message varchar2) is begin coremod_log.log(p_message, 'INFO', 'OPAS_EXTEXEC'); end;
  procedure log_debug(p_message varchar2) is
  begin
    if gsrvLoggingLevel = 'DEBUG' then
      coremod_log.log(p_message, 'INFO', 'OPAS_EXTEXEC');
    end if;
  end;

  procedure load_external_data(p_target_table  varchar2,
                               p_select_list   t_columns,
                               p_sql_body      varchar2,
                               p_dblink        varchar2,
                               p_priority      number default 3,
                               p_timeout       number default 600,
                               p_generate_only boolean default false,
                               p_plsql_body    varchar2 default null,
                               p_key_pref      varchar2 default null,
                               p_src_table     varchar2 default null,
                               p_timestamp_col varchar2 default null)
  is
    l_extunltmpl varchar2(32765) := q'[SELECT <COLLIST>
 FROM <SQLBODY>]';

    l_dbltmpl varchar2(32765) := q'[
insert into <TARGETTBL> (<TARGETCOLLIST>)
SELECT <COLLIST>
FROM   <SQLBODY>]';

    l_sql varchar2(32765);
    l_unlsql varchar2(32765);
    l_loadsql varchar2(32765);
    l_loadlocalsql varchar2(32765);
    l_trgcols varchar2(32765);
    l_trgcols_expr varchar2(32765);
    l_trgcols_java_vals varchar2(32765);
    l_col_num number := 0;
    l_task_id number;
    l_column_list varchar2(32765) := null;
    l_ts_col varchar2(128);
    l_ts_fnc varchar2(512);
    l_dblink boolean := COREMOD_API.external_mode_dblink(p_dblink);
    l_javasrv boolean := COREMOD_API.external_mode_javasrv(p_dblink);
  begin
--dbms_output.put_line(replace(p_key_pref||'_<SRC_TABLE>','<SRC_TABLE>',p_src_table));
    if p_key_pref = 'TABCOLLIST' then
      l_column_list := COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_dblink,
                                                        P_KEY => replace(p_key_pref||'_<SRC_TABLE>','<SRC_TABLE>',p_src_table));
    elsif p_key_pref = 'LOCTABCOLS' then
      l_column_list := COREMOD_API.get_ora_dblink_cache(P_DB_LINK_NAME => p_dblink,
                                                        P_KEY => replace(p_key_pref||'_<SRC_TABLE>','<SRC_TABLE>',p_src_table),
                                                        p_local_tab => p_target_table);
    end if;
    if p_timestamp_col is not null and p_timestamp_col in ('TS', 'LTS', 'TSTZ','TSUTC') then
      l_ts_col := p_timestamp_col;
      l_ts_fnc := case p_timestamp_col
                  when 'TS' then 'cast(systimestamp as timestamp)'
                  when 'LTS' then 'localtimestamp'
                  when 'TSTZ' then 'systimestamp'
                  when 'TSUTC' then 'sys_extract_utc(systimestamp)' else null end;
    end if;

--dbms_output.put_line(','||upper(l_column_list)||',');
--dbms_output.put_line(l_column_list);
    for i in (select * from user_tab_cols where table_name=upper(p_target_table) and virtual_column='NO' and hidden_column='NO' order by column_id) loop
      if p_key_pref is not null then
--dbms_output.put_line(','||i.column_name||',');
      if instr(','||upper(l_column_list)||',', ','||i.column_name||',')=0 then continue; end if;
      end if;
      if (i.data_type in ('VARCHAR2', 'CHAR', 'RAW', 'NUMBER', 'DATE') or
         i.data_type = 'TIMESTAMP' or i.data_type like 'TIMESTAMP(%)' or
         i.data_type like 'TIMESTAMP(%) WITH TIME ZONE'     )
         and l_javasrv
      then
        l_trgcols := l_trgcols || i.column_name || ', ';
      elsif l_dblink then
        l_trgcols := l_trgcols || i.column_name || ', ';
      end if;
      if p_select_list is not null and p_select_list.exists(i.column_name) then
        l_trgcols_expr := l_trgcols_expr ||', ' || p_select_list(i.column_name) || ' as ' || i.column_name  ;
      elsif p_select_list is null or p_select_list is not null and p_select_list.count=0 and l_javasrv then
        l_trgcols_expr:= l_trgcols_expr ||
         case when i.data_type in ('VARCHAR2', 'CHAR', 'RAW') then ', ' || i.column_name
              when i.data_type = 'NUMBER' then ', ' || i.column_name
              when i.data_type = 'DATE' then ', ' || 'to_char('||i.column_name||')'
              when i.data_type = 'TIMESTAMP' or i.data_type like 'TIMESTAMP(%)' then ', ' || 'to_char('||i.column_name||')'
              when i.data_type like 'TIMESTAMP(%) WITH TIME ZONE' then ', ' || 'to_char('||i.column_name||')'
              else '/*<'||i.column_name || '> Unsupported type '||i.data_type||'*/' end;-- || ', ';
      elsif l_dblink then
        l_trgcols_expr:= l_trgcols_expr || ', ' || i.column_name;
      end if;
      l_trgcols_java_vals:= l_trgcols_java_vals ||
         case when i.data_type in ('VARCHAR2', 'CHAR', 'RAW') then  ', ' || '?'
              when i.data_type = 'NUMBER' then  ', ' || 'to_number(?)'
              when i.data_type = 'DATE' then  ', ' || 'to_date(?)'
              when i.data_type = 'TIMESTAMP' or i.data_type like 'TIMESTAMP(%)' then  ', ' || 'to_timestamp(?)'
              when i.data_type like 'TIMESTAMP(%) WITH TIME ZONE' then  ', ' || 'TO_TIMESTAMP_TZ(?)'
              else '/*<'||i.column_name || '>Unsupported type '||i.data_type||'*/' end;-- || ', ';
      --l_col_num := l_col_num + 1;
    end loop;
    l_trgcols := rtrim(l_trgcols,', ');
    l_trgcols_expr := ltrim(l_trgcols_expr,', ');
    l_trgcols_java_vals := ltrim(l_trgcols_java_vals,', ');
    l_col_num := regexp_count(l_trgcols_expr, ',')+1;

    if l_dblink then
      l_sql := l_dbltmpl;
      l_sql := replace(replace(replace(replace(l_sql,'<SQLBODY>',p_sql_body),'<DBLINK>',COREMOD_API.get_dblink_for_query(p_dblink)),'<TARGETTBL>',p_target_table),'<TARGETCOLLIST>',l_trgcols);
      l_sql := replace(l_sql,'<COLLIST>',l_trgcols_expr);
      log_debug('load_external_data DBLINK l_sql: '||l_sql);
      if p_generate_only then
        log_info('load_external_data DBLINK l_sql: '||l_sql);
      else
        execute immediate l_sql;
        gRowsProcessed := sql%rowcount;
      end if;
    elsif l_javasrv then
      l_task_id := seq_opas_extproc_queue_srv.nextval;
      l_unlsql := l_extunltmpl;

      l_unlsql := replace(replace(l_unlsql,'<SQLBODY>',p_sql_body),'<DBLINK>');
      l_unlsql := replace(l_unlsql,'<COLLIST>',l_trgcols_expr);

      l_loadsql := q'[INSERT INTO <TARGET_TABLE>_EXT (task_id, <TARGETCOLLIST>) VALUES (to_number(?), <INSCOLLIST>)]';
      l_loadsql := replace(replace(replace(l_loadsql,'<TARGET_TABLE>',p_target_table),'<TARGETCOLLIST>',l_trgcols),'<INSCOLLIST>',l_trgcols_java_vals);

      l_loadlocalsql := q'[INSERT INTO <TARGET_TABLE> (<TARGETCOLLIST>) select <TARGETCOLLIST> from <TARGET_TABLE>_EXT where task_id=:l_task]';
      l_loadlocalsql := replace(replace(l_loadlocalsql,'<TARGET_TABLE>',p_target_table),'<TARGETCOLLIST>',l_trgcols);

      if p_generate_only then
        log_info('load_external_data JAVA l_unlsql: '||l_unlsql);
        log_info('load_external_data JAVA l_loadsql: '||l_loadsql);
        log_info('load_external_data JAVA l_loadlocalsql: '||l_loadlocalsql);
        log_info('load_external_data JAVA p_plsql_body: '||p_plsql_body);
--              dbms_output.put_line(l_unlsql);
--                    dbms_output.put_line(l_loadsql);
--                          dbms_output.put_line(l_loadlocalsql);
--                                dbms_output.put_line(p_plsql_body);
      else
        log_debug('load_external_data JAVA l_unlsql: '||l_unlsql);
        log_debug('load_external_data JAVA l_loadsql: '||l_loadsql);
        log_debug('load_external_data JAVA l_loadlocalsql: '||l_loadlocalsql);
        log_debug('load_external_data JAVA p_plsql_body: '||p_plsql_body);
        --SQLSELINS
        INSERT INTO opas_extproc_queue_srv (
          TASK_ID, PRIORITY, db_link_name, QRY_TYPE, select_sql, load_sql, col_number, TARGET_TABLE, PL_SQL) VALUES (
          l_task_id, p_priority, p_dblink, case when p_plsql_body is null then 'SQLSELINS' else 'PLSQLSELINS' end, l_unlsql,  l_loadsql, l_col_num, p_target_table, p_plsql_body);
        commit;

        wait_result (  P_TASK_ID => l_task_id,
                       P_TIMEOUT => load_external_data.p_timeout) ;

        execute immediate l_loadlocalsql using l_task_id;
        set_task_taken (  P_TASK_ID => l_task_id) ;  -- gRowsProcessed filled here

        --select ROWS_PROCESSED into gRowsProcessed from OPAS_EXTPROC_QUEUE_SRV where TASK_ID=l_task_id;
      end if;
    else
      raise_application_error(-20000,'Unsupported external execution mode for DB Link(load_external_data): '||p_dblink);
    end if;

  end;

  procedure cleanup_task(p_task_id number)
  is
  begin
      for i in (select TARGET_TABLE from OPAS_EXTPROC_QUEUE_SRV where TASK_ID=p_task_id)
      loop
        if i.TARGET_TABLE is not null then
          begin
            execute immediate 'delete from '||i.TARGET_TABLE||'_EXT where task_id=:task' using p_task_id;
          exception
            when others then log_info('Unable to cleanup COREMOD_EXTPROC.cleanup_task('||p_task_id||'): '||i.TARGET_TABLE||': '||sqlerrm);
          end;
        end if;
      end loop;
  end;

  procedure Cleanup_queue
  is
    l_ids TABLEOFNUMBERS;
    l_retention_h number := to_number(COREMOD_API.getconf('EXTEXECLOGRETENT'));
  begin
    select exec_id bulk collect into l_ids from opas_extproc_queue where finished < sysdate - 1/24;
/*
    for i in 1..l_ids.count loop
      begin
        host_command (p_command => '/home/oracle/extproc/execsqlpluscln.sh '||l_ids(i));
        delete from opas_extproc_queue where exec_id = l_ids(i);
      exception
        when others then llog('Unable to cleanup COREMOD_EXTPROC('||l_ids(i)||'): '||sqlerrm);
      end;
    end loop;
*/
    delete from OPAS_EXTPROC_WORK_SRV where FINISHED < sysdate - l_retention_h/24;
    select task_id bulk collect into l_ids from OPAS_EXTPROC_QUEUE_SRV where nvl(FINISHED,TAKEN) < sysdate - l_retention_h/24;
    for i in 1..l_ids.count loop
      cleanup_task(l_ids(i));
      delete from OPAS_EXTPROC_QUEUE_SRV where task_id=l_ids(i);
      commit;
    end loop;
  end;

  procedure start_coordinator is
    l_server_interval varchar2(100) := COREMOD_API.getconf('SRVINTERVAL');
    l_cnt number;
    l_job_status varchar2(100);
  begin
    select count(1) into l_cnt from user_scheduler_programs where program_name=gshProgram;
    if l_cnt = 0 then
      dbms_scheduler.create_program(
                              program_name             => gshProgram,
                              program_type             => 'PLSQL_BLOCK',
                              program_action           => 'begin COREMOD_EXTPROC.coordinator_proc; end;',
                              enabled                  => true,
                              comments                 => 'OPAS External executor job coordinator program');
    end if;
    begin
      select enabled into l_job_status from user_scheduler_jobs where job_name=gshJobName;
      if l_job_status = 'FALSE' then
        dbms_scheduler.enable(gshJobName);
      end if;
    exception
      when no_data_found then
        dbms_scheduler.create_job(job_name                 => gshJobName,
                              program_name             => gshProgram,
                              start_date               => systimestamp,
                              repeat_interval          => l_server_interval, --'FREQ=SECONDLY; INTERVAL=5',
                              job_style                => 'LIGHTWEIGHT',
                              enabled                  => true);
      when others then raise;
    end;
    log_info('start_coordinator executed');
  end;

  procedure stop_worker(p_job_name varchar2) is
  begin
    begin dbms_scheduler.stop_job(job_name  => p_job_name); exception when others then coremod_tasks.log('COREMOD_EXTPROC.stop_worker stop_job: '||p_job_name||': '||sqlerrm); end;
    update OPAS_EXTPROC_WORK_SRV set FINISHED = systimestamp, errmsgs = 'Stopped by stop_worker' where JOB_NAME=p_job_name;
    commit;
    log_info('stop_worker executed: '||p_job_name);
  end;

  procedure stop_coordinator is
  begin
    for i in (select * from opas_extproc_work_srv where job_name is not null and finished is null) loop
      stop_worker(p_job_name => i.job_name);
    end loop;

    begin dbms_scheduler.stop_job(job_name  => 'OPASEXTSQL'); exception when others then coremod_tasks.log('COREMOD_EXTPROC.stop_coordinator stop_job: '||sqlerrm); end;
    begin dbms_scheduler.disable('OPASEXTSQL'); exception when others then coremod_tasks.log('COREMOD_EXTPROC.stop_coordinator disable: '||sqlerrm); end;
    --begin dbms_scheduler.drop_program(program_name => 'OPASEXTSQL_PRG'); exception when others then coremod_tasks.log('COREMOD_EXTPROC.stop_coordinator drop_program: '||sqlerrm); end;
    log_info('stop_coordinator executed');
  end;

  procedure check_connection_problem(p_dblink       varchar2)
  is
    l_connect_error_count number;
    l_retention_m number := to_number(COREMOD_API.getconf('ALARMLOGININTERVAL'));
    l_last_error_dt date;
  begin
    select count(1), max(started) into l_connect_error_count, l_last_error_dt
      from OPAS_EXTPROC_WORK_SRV
     where DB_LINK_NAME = p_dblink and errmsgs like 'Connection problem%ORA-01017%' and STARTED > sysdate - l_retention_m/(24*60);
    if not COREMOD_API.dblink_available(p_dblink, l_last_error_dt) then
      raise_application_error(-20000,'DB Link '||p_dblink||' is not enabled');
    end if;
    if l_connect_error_count > 3 then
      COREMOD_API.drop_dblink(p_db_link_name => upper(p_dblink), p_suspend => true);
      raise_application_error(-20000,'DB Link '||p_dblink||' suspended due to multiple connection errors');
    end if;
  end;

  function get_server_status(p_format varchar2) return varchar2
  is
    l_status varchar2(4000) := 'Server not created';
  begin
    for i in (select enabled, cast(systimestamp - last_start_date as INTERVAL DAY(2) TO SECOND(3)) recent_run, to_char(next_run_date,'YYYY/MM/DD HH24:MI:SS') next_run_date from user_scheduler_jobs where job_name=gshJobName) loop
      if p_format = 'SHORT' then
        l_status := 'Server enabled: '||i.enabled;
      elsif p_format = 'LONG1' then
        l_status := 'Server enabled: '||i.enabled||'; Run: '||i.recent_run||' ago. Next run: '||i.next_run_date;
      end if;
    end loop;
    return l_status;
  end;

  procedure coordinator_proc is
    l_max_workers number;
    l_threads2created number:=0;
    l_running_jobs    number;
    l_dblinks_running t_jobs;
    l_dblinks2start   t_jobs;
    l_dblinks2ban     t_jobs;
    l_dblink          varchar2(128);

    l_work_id number;
    l_job_name varchar2(128);

    l_iter number := 0;
    l_maxiter  number := to_number(COREMOD_API.getconf('COORDAQCITERS'));
    l_sleep    number := to_number(COREMOD_API.getconf('COORDAQCSLEEP'));
  begin
    log_info('coordinator_proc started');
    loop
      if l_iter = 0 or mod(l_iter,20)=0 then
        gsrvLoggingLevel := COREMOD_API.getconf('EXTLOGGINGMODE');
        l_max_workers := to_number(COREMOD_API.getconf('MAXEXTWORKERS'));
        gsrvQueryPerServerSession := to_number(COREMOD_API.getconf('QRYPERWORKERSESS'));
      end if;

        for i in (select DB_LINK_NAME, count(1) cnt from OPAS_EXTPROC_QUEUE_SRV where STATUS='NEW' group by DB_LINK_NAME) loop

          l_dblinks2start.delete;
          l_dblinks_running.delete;

          select count(1) into l_running_jobs from user_scheduler_running_jobs where job_name in (select JOB_NAME from OPAS_EXTPROC_WORK_SRV where FINISHED is null and STARTED is not null);
          if l_max_workers > l_running_jobs then
            l_threads2created := l_max_workers - l_running_jobs;

            for i in (select unique DB_LINK_NAME from OPAS_EXTPROC_WORK_SRV where JOB_NAME in (select JOB_NAME from user_scheduler_running_jobs)) loop
              l_dblinks_running(i.DB_LINK_NAME):=0;
            end loop;
          end if;

          if not l_dblinks2ban.exists(i.DB_LINK_NAME) then
            begin
              check_connection_problem(i.DB_LINK_NAME);
              l_dblinks2start(i.DB_LINK_NAME):=i.cnt;
            exception
              when others then
                if not l_dblinks2ban.exists(i.DB_LINK_NAME) then
                  l_dblinks2ban(i.DB_LINK_NAME) := 20;
                end if;
                log_info('coordinator_proc connection problem: '||i.DB_LINK_NAME||': '||sqlerrm);
            end;
          else
            if l_dblinks2ban(i.DB_LINK_NAME)>0 then
              l_dblinks2ban(i.DB_LINK_NAME):=l_dblinks2ban(i.DB_LINK_NAME)-1;
            else
              l_dblinks2ban.delete(i.DB_LINK_NAME);
            end if;
          end if;
        end loop;

        l_dblink := l_dblinks2start.first;
        loop
          exit when l_dblink is null or l_threads2created <= 0;
          if (
               (not l_dblinks_running.exists(l_dblink)) or
               (l_dblinks_running.exists(l_dblink) and l_dblinks2start(l_dblink) > gsrvQueryPerServerSession/2)
             )
              and l_threads2created>0 then
            l_dblinks_running(l_dblink):=0;
            log_info('coordinator_proc job l_dblink, l_threads2created: '||l_dblink||', '||l_threads2created);
            --round(2*to_number(l_dblinks2start(l_dblink))/gsrvQueryPerServerSession)
            INSERT INTO opas_extproc_work_srv ( work_id, db_link_name, job_name)
              VALUES (seq_opas_extproc_queue_srv.nextval, l_dblink, gshJobName||'_'||DBMS_RANDOM.STRING('X',6)) returning work_id, job_name into l_work_id, l_job_name;
            commit;
            dbms_scheduler.create_job(job_name => l_job_name,
                                      job_type => 'PLSQL_BLOCK',
                                      job_action => q'{begin COREMOD_EXTPROC.worker_proc(}' || l_work_id || q'{); end;}',
                                      start_date => systimestamp,
                                      enabled => true,
                                      auto_drop=> true);
            l_threads2created := l_threads2created - 1;
            log_info('coordinator_proc job invoked: '||l_job_name);
          end if;
          l_dblink := l_dblinks2start.next(l_dblink);
        end loop;
      --for i in (select DB_LINK_NAME, cnt, count(unique DB_LINK_NAME) over() dblnks from (select DB_LINK_NAME, count(1) cnt from OPAS_EXTPROC_QUEUE_SRV where STATUS='NEW' group by DB_LINK_NAME)) loop
      --  null;
      --end loop;
      --end if;
      l_iter := l_iter + 1;
      exit when l_iter > l_maxiter;
      dbms_session.sleep(l_sleep);
    end loop;
    log_info('coordinator_proc finished');
  end;

  procedure report_connection_problem(p_work_id number, p_errormsg varchar2)
  is
    pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_WORK_SRV set FINISHED = systimestamp, errmsgs = 'Connection problem: '||p_errormsg where work_id=p_work_id;
    commit;
  end;

  procedure worker_proc(p_work_id number) is
  begin
    dbms_output.enable(1000000);
    DBMS_JAVA.SET_OUTPUT(1000000);
    log_debug('worker_proc started: '||p_work_id);
    start_server_prc(p_work_id => p_work_id);
    log_debug('worker_proc finished: '||p_work_id);
  end;

  procedure worker_finished(p_work_id number, p_stmt_done number, p_errors varchar2) is
    pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_WORK_SRV set FINISHED = systimestamp, QRY_EXECUTED = p_stmt_done, errmsgs = p_errors where work_id=p_work_id;
    commit;
  end;

  procedure stop_worker(p_work_id number) is
  begin
    for i in (select * from opas_extproc_work_srv where work_id=p_work_id) loop
      stop_worker(p_job_name => i.job_name);
    end loop;
  end;

  procedure init_server_parameters(p_work_id number, p_username out varchar2, p_password out varchar2, p_connstr out varchar2, p_query_num out number, p_logging_mode out varchar2, p_batch_size out number) is
    l_status varchar2(100);
    pragma autonomous_transaction;
  begin
    for i in (select * from opas_extproc_work_srv where job_name is not null and finished is null and STARTED is null and work_id=p_work_id for update nowait) loop
      update OPAS_EXTPROC_WORK_SRV set STARTED = systimestamp where work_id=p_work_id;
    end loop;
    commit;

    for i in (select * from opas_extproc_work_srv where work_id=p_work_id) loop
      select USERNAME, PASSWORD, CONNSTR, STATUS into p_username, p_password, p_connstr, l_status from OPAS_DB_LINKS where DB_LINK_NAME = i.DB_LINK_NAME;
      if l_status <> COREMOD_API.dblEXTENABLED then
        raise_application_error(-20000,'External connection from JAVASRV through "'||i.DB_LINK_NAME||'" is blocked for status='||l_status);
      end if;
    end loop;

    gsrvLoggingLevel := COREMOD_API.getconf('EXTLOGGINGMODE');
    gsrvQueryPerServerSession := to_number(COREMOD_API.getconf('QRYPERWORKERSESS'));
    p_batch_size := to_number(COREMOD_API.getconf('JDBCBATCHSIZE'));

    p_query_num := gsrvQueryPerServerSession;
    p_logging_mode :=gsrvLoggingLevel;
    log_info('init_server_parameters finished: '||p_work_id);
  end;

  procedure get_next_task(p_work_id number, p_task_id out number, p_qry_type out varchar2, p_qry1 out varchar2, p_qry2 out varchar2, p_qry3 out varchar2, p_num_cols out number, p_timeouted out number) is
    l_acquired boolean := false;
    l_iterations number := 0;
    l_max_iteration number := to_number(COREMOD_API.getconf('WORKERAQCITERS')); --2 minutes
    l_sleep number := to_number(COREMOD_API.getconf('WORKERAQCSLEEP'));
  begin
    for i in (select * from opas_extproc_work_srv where work_id=p_work_id) loop
      loop
        for j in (select * from OPAS_EXTPROC_QUEUE_SRV where STATUS = 'NEW' and DB_LINK_NAME = i.DB_LINK_NAME for update skip locked order by PRIORITY, CREATED) loop
          p_task_id := j.task_id;
          p_qry_type := j.QRY_TYPE;
          p_qry1 := j.SELECT_SQL;
          p_qry2 := j.LOAD_SQL;
          p_num_cols := j.COL_NUMBER;
          p_qry3 := j.PL_SQL;
          l_acquired := true;
          update OPAS_EXTPROC_QUEUE_SRV set STARTED = systimestamp, status='STARTED' where TASK_ID=j.TASK_ID;
          exit;
        end loop;
        l_iterations := l_iterations + 1;
        exit when l_acquired or l_iterations>l_max_iteration;
        dbms_session.sleep(l_sleep);
      end loop;
    end loop;
    commit;

    p_timeouted := 0;
    if l_iterations>l_max_iteration then
      p_timeouted := 1; log_info('get_next_task timed out: p_work_id, '||p_work_id);
    else
      log_info('get_next_task finished');
    end if;
  end;
/*
  procedure set_task_selected_data(p_task_id number) is
    pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_QUEUE_SRV set SELECTED = systimestamp, STATUS='SELECTED' where TASK_ID=p_task_id;
    commit;
  end;
*/
  procedure set_task_finshed(p_task_id number, p_status varchar2, p_errormsg varchar2, p_rows_processed number/*, p_result clob default null*/) is
    pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_QUEUE_SRV set FINISHED = systimestamp, STATUS=p_status, ERRORMSG = p_errormsg, ROWS_PROCESSED = p_rows_processed/*, EXEC_RES = p_result*/ where TASK_ID=p_task_id;
    commit;
  end;

  function get_rows_processed return number
  is
  begin
    return gRowsProcessed;
  end;

  procedure set_task_taken(p_task_id number) is
    pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_QUEUE_SRV set TAKEN = systimestamp, STATUS='TAKEN' where TASK_ID=p_task_id returning ROWS_PROCESSED into gRowsProcessed;
    commit;
  end;

  procedure set_task_timedout(p_task_id number, p_msg varchar2) is
    pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_QUEUE_SRV set TAKEN = systimestamp, STATUS='TIMEDOUT', ERRORMSG = p_msg where TASK_ID=p_task_id;
    commit;
  end;

  procedure wait_result(p_task_id number, p_timeout number default 600)
  is
    l_start_tim date := sysdate;
    l_res boolean := false;
    l_timedout boolean := false;

    l_timout_after_task_created number := to_number(COREMOD_API.getconf('TIMOUTCREATED'));
    l_timout_after_task_started number := to_number(COREMOD_API.getconf('TIMOUTSTARTED'));
  begin
    loop
      for i in (select created, started, FINISHED, status, ERRORMSG from OPAS_EXTPROC_QUEUE_SRV where TASK_ID=p_task_id and FINISHED is not null)
      loop
        l_res := i.FINISHED is not null; --p_status := i.status;
        l_timedout := (sysdate - (i.created+0))*24*3600 > l_timout_after_task_created;
        l_timedout := (sysdate - (i.started+0))*24*3600 > l_timout_after_task_started;
        if i.status='FAILED' then raise_application_error(-20000, 'Task <'||p_task_id||'> failed with: '||i.ERRORMSG);end if;
      end loop;

      if not l_timedout then l_timedout := (sysdate-l_start_tim)*24*3600>p_timeout; end if;

      if l_timedout then set_task_timedout(p_task_id, 'Timeout after '||p_timeout|| ' secs'); raise_application_error(-20000, 'Task '||p_task_id||' timed out after '||p_timeout|| ' secs.'); end if;
      exit when l_res or l_timedout;
      dbms_session.sleep(0.1);
    end loop;
  end;

  procedure clean_param(p_task_id number, p_ordr_num number) is
  begin
    delete from OPAS_EXTPROC_RESULTS where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
  end;
  procedure add_param(p_task_id number, p_io_type varchar2, p_ordr_num number, p_clob clob) is
    pragma autonomous_transaction;
  begin
    if p_io_type = 'IN' then
      raise_application_error(-20000,'IN CLOB parameter is not supported so far');
    end if;
    clean_param(p_task_id, p_ordr_num);
    insert into OPAS_EXTPROC_RESULTS(TASK_ID, R_ORDR_NUM, R_IO_TYPE, R_DATA_TYPE, R_CLOB) values (p_task_id, p_ordr_num, p_io_type, 'CLOB', p_clob);
    commit;
  end;
  procedure add_param(p_task_id number, p_io_type varchar2, p_ordr_num number, p_number number) is
    pragma autonomous_transaction;
  begin
    clean_param(p_task_id, p_ordr_num);
    insert into OPAS_EXTPROC_RESULTS(TASK_ID, R_ORDR_NUM, R_IO_TYPE, R_DATA_TYPE, R_NUMBER) values (p_task_id, p_ordr_num, p_io_type, 'NUMBER', p_number);
    commit;
  end;
  procedure add_param(p_task_id number, p_io_type varchar2, p_ordr_num number, p_date date) is
    pragma autonomous_transaction;
  begin
    clean_param(p_task_id, p_ordr_num);
    insert into OPAS_EXTPROC_RESULTS(TASK_ID, R_ORDR_NUM, R_IO_TYPE, R_DATA_TYPE, R_DATE) values (p_task_id, p_ordr_num, p_io_type, 'DATE', p_date);
    commit;
  end;
  procedure add_param(p_task_id number, p_io_type varchar2, p_ordr_num number, p_timestamp timestamp) is
    pragma autonomous_transaction;
  begin
    clean_param(p_task_id, p_ordr_num);
    insert into OPAS_EXTPROC_RESULTS(TASK_ID, R_ORDR_NUM, R_IO_TYPE, R_DATA_TYPE, R_TIMESTAMP) values (p_task_id, p_ordr_num, p_io_type, 'TIMESTAMP', p_timestamp);
    commit;
  end;
  procedure add_param(p_task_id number, p_io_type varchar2, p_ordr_num number, p_timestamp_tz timestamp with time zone) is
    pragma autonomous_transaction;
  begin
    clean_param(p_task_id, p_ordr_num);
    insert into OPAS_EXTPROC_RESULTS(TASK_ID, R_ORDR_NUM, R_IO_TYPE, R_DATA_TYPE, R_TIMESTAMP_TZ) values (p_task_id, p_ordr_num, p_io_type, 'TIMESTAMP_TZ', p_timestamp_tz);
    commit;
  end;
  procedure add_param(p_task_id number, p_io_type varchar2, p_ordr_num number, p_varchar2 varchar2) is
    pragma autonomous_transaction;
  begin
    clean_param(p_task_id, p_ordr_num);
    insert into OPAS_EXTPROC_RESULTS(TASK_ID, R_ORDR_NUM, R_IO_TYPE, R_DATA_TYPE, R_VARCHAR) values (p_task_id, p_ordr_num, p_io_type, 'VARCHAR2', p_varchar2);
    commit;
  end;

  procedure set_param(p_task_id number, p_ordr_num number, p_clob clob) is
  begin
    --raise_application_error(-20000,'p_clob:'||length(p_clob));
    update OPAS_EXTPROC_RESULTS set R_CLOB = p_clob where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
  end;
  procedure set_param(p_task_id number, p_ordr_num number, p_number number) is
  begin
    update OPAS_EXTPROC_RESULTS set R_NUMBER = p_number where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
  end;
  procedure set_param(p_task_id number, p_ordr_num number, p_date date) is
  begin
    update OPAS_EXTPROC_RESULTS set R_DATE = p_date where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
  end;
  procedure set_param(p_task_id number, p_ordr_num number, p_timestamp timestamp) is
  begin
    update OPAS_EXTPROC_RESULTS set R_TIMESTAMP = p_timestamp where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
  end;
  procedure set_param(p_task_id number, p_ordr_num number, p_timestamp_tz timestamp with time zone) is
  begin
    update OPAS_EXTPROC_RESULTS set R_TIMESTAMP_TZ = p_timestamp_tz where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
  end;
  procedure set_param(p_task_id number, p_ordr_num number, p_varchar2 varchar2) is
  begin
    update OPAS_EXTPROC_RESULTS set R_VARCHAR = p_varchar2 where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
  end;

  function  create_plsql_task (p_plsql_body    varchar2,
                               p_dblink        varchar2,
                               p_priority      number default 3,
                               p_generate_only boolean default false) return number --returns p_task_id
  is
    l_task_id number;
    l_PL_SQL  varchar2(32765);
    pragma autonomous_transaction;
  begin
      l_PL_SQL := replace(p_plsql_body,'<DBLINK>');

      if p_generate_only then
        log_info('create_plsql_task JAVA l_PL_SQL: '||l_PL_SQL);

      else
        --PLSQL
        l_task_id := seq_opas_extproc_queue_srv.nextval;
        INSERT INTO opas_extproc_queue_srv (
          TASK_ID, PRIORITY, db_link_name, QRY_TYPE, PL_SQL, STATUS) VALUES (
          l_task_id, p_priority, p_dblink, 'PLSQL', l_PL_SQL, 'PRE');
        commit;
      end if;
      return l_task_id;
  end;

  procedure execute_plsql_task (p_task_id       number,
                                p_timeout       number default 600)
  is
    pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_QUEUE_SRV set STATUS = 'NEW' where TASK_ID = p_task_id;
    commit;
    wait_result (  P_TASK_ID => p_task_id,
                   P_TIMEOUT => execute_plsql_task.p_timeout) ;
  end;
  procedure get_param(p_task_id number, p_ordr_num number, p_clob out clob)
  is
  begin
    select R_CLOB into p_clob from OPAS_EXTPROC_RESULTS where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num and R_IO_TYPE = 'OUT';
  end;
  procedure get_param(p_task_id number, p_ordr_num number, p_number out number)
  is
  begin
    select R_NUMBER into p_number from OPAS_EXTPROC_RESULTS where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num and R_IO_TYPE = 'OUT';
  end;
  procedure get_param(p_task_id number, p_ordr_num number, p_date out date)
  is
  begin
    select R_DATE into p_date from OPAS_EXTPROC_RESULTS where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num and R_IO_TYPE = 'OUT';
  end;
  procedure get_param(p_task_id number, p_ordr_num number, p_timestamp out timestamp)
  is
  begin
    select R_TIMESTAMP into p_timestamp from OPAS_EXTPROC_RESULTS where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num and R_IO_TYPE = 'OUT';
  end;
  procedure get_param(p_task_id number, p_ordr_num number, p_timestamp_tz out timestamp with time zone)
  is
  begin
    select R_TIMESTAMP_TZ into p_timestamp_tz from OPAS_EXTPROC_RESULTS where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num and R_IO_TYPE = 'OUT';
  end;
  procedure get_param(p_task_id number, p_ordr_num number, p_varchar2 out varchar2)
  is
  begin
    select R_VARCHAR into p_varchar2 from OPAS_EXTPROC_RESULTS where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num and R_IO_TYPE = 'OUT';
  end;

begin
  gsrvLoggingLevel := COREMOD_API.getconf('EXTLOGGINGMODE');
  gsrvQueryPerServerSession := to_number(COREMOD_API.getconf('QRYPERWORKERSESS'));
/*
  procedure exec_sql(p_dblink varchar2, p_sql varchar2, p_exec_id out number) AS
  BEGIN
    p_exec_id := seq_opas_extproc_queue.nextval;
    INSERT INTO opas_extproc_queue (exec_id, db_link_name, sql2exec) VALUES (p_exec_id, p_dblink, replace(p_sql,'<EXECID>',p_exec_id));
    commit;
    host_command (p_command => '/home/oracle/extproc/execsqlcli.sh '||p_exec_id);
  END exec_sql;

  procedure cleanup_exec(p_exec_id number)
  is
  begin
    delete from opas_extproc_queue where exec_id = p_exec_id;
  end;

    l_extloadtmpl varchar2(32765) := q'[
insert into <TARGETTBL>
SELECT <TARGETCOLLIST>
FROM   EXTERNAL (
         (
           <COLLISTWITHTYPE>
         )
         TYPE oracle_loader
         DEFAULT DIRECTORY <DIRECTORY>
         ACCESS PARAMETERS (
           RECORDS DELIMITED BY NEWLINE
           BADFILE <DIRECTORY>
           LOGFILE <DIRECTORY>:'inline_ext_tab_%a_%p.log'
           DISCARDFILE tempdata
           FIELDS CSV WITH EMBEDDED record terminators TERMINATED BY '|' OPTIONALLY ENCLOSED BY '"' date_format date mask "YYYYMMDDHH24MISS"
           MISSING FIELD VALUES ARE NULL (
           <COLLISTWITHTYPE_LOADER>
           )
        )
        LOCATION ('<DATAFILE>')
        REJECT LIMIT UNLIMITED
      ) inline_ext_tab]';
    l_unlfiletmpl varchar2(32765):=q'[SET MARKUP CSV ON DELIMITER "|" QUOTE ON
SET TRIMSPOOL ON LINESIZE 5000 FEEDBACK OFF PAGESIZE 0 HEADING OFF SQLBL ON
<CONNECTSTR>
alter session set nls_date_format='YYYYMMDDHH24MISS';
alter session set NLS_TIMESTAMP_FORMAT = 'YYYYMMDDHH24MISS.FF9';
alter session set NLS_TIMESTAMP_TZ_FORMAT = 'YYYYMMDDHH24MISS.FF9 TZH:TZM';
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '. ';
set numf fm9999999999999999999999999.9999999999999999

spool <FULLPATH>/<DATAFILE>

<SQLTEXT>;

spool off
]';

    elsif COREMOD_API.external_mode_sqlplus(p_dblink) then

      l_exec_id := seq_opas_extproc_queue.nextval;
      l_time := DBMS_UTILITY.GET_TIME;
      l_loadsql := l_extloadtmpl;
      l_unlsql := l_extunltmpl;

      l_unlsql := replace(replace(replace(replace(l_unlsql,'<SQLBODY>',p_sql_body),'<DBLINK>'),'<TARGETTBL>',p_target_table),'<TARGETCOLLIST>',l_trgcols);
      l_unlsql := replace(l_unlsql,'<COLLIST>',l_trgcols_expr);

      l_loadsql := replace(replace(replace(replace(l_loadsql,'<COLLISTWITHTYPE>',l_trgcols_dt),'<DBLINK>'),'<TARGETTBL>',p_target_table),'<TARGETCOLLIST>',l_trgcols);
      l_loadsql := replace(replace(replace(l_loadsql,'<DIRECTORY>',COREMOD_API.getconf('DATADIRECTORY')),'<COLLISTWITHTYPE_LOADER>',l_trgcols_ldr),'<DATAFILE>',l_datafile);

      select rtrim(rtrim(directory_path,'/'),'\') into l_fullpath from all_directories where directory_name=upper(COREMOD_API.getconf('DATADIRECTORY'));
      select 'conn '||username||'/'||password||'@'||connstr into l_connstr from opas_db_links x where x.db_link_name=p_dblink;

      l_unlsql := replace(replace(replace(replace(l_unlfiletmpl,'<SQLTEXT>',l_unlsql),'<FULLPATH>',l_fullpath),'<DATAFILE>',l_datafile),'<CONNECTSTR>',l_connstr);

      INSERT INTO opas_extproc_queue (exec_id, db_link_name, sql2exec) VALUES (l_exec_id, p_dblink, replace(l_unlsql,'<EXECID>',l_exec_id));
      commit;
      host_command (p_command => '/home/oracle/extproc/execsqlplusunl.sh '||l_exec_id);
      update opas_extproc_queue set STARTED = systimestamp, STATUS = 'STARTED' where exec_id = l_exec_id;
      execute immediate l_loadsql;
      update opas_extproc_queue set TOT_DURATION = DBMS_UTILITY.GET_TIME - l_time, FINISHED = systimestamp, STATUS = 'FINISHED' where exec_id = l_exec_id;

*/
END COREMOD_EXTPROC;
/


