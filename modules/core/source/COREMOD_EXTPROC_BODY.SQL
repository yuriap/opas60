

CREATE OR REPLACE
PACKAGE BODY COREMOD_EXTPROC AS

  --gExtSQLCoordinator varchar2(128) := 'OPASEXTSQL';
  gsrvQueryPerServerSession number; -- init section below
  gsrvLoggingLevel          varchar2(10); -- init section below
  gshProgram constant varchar2(100) := 'OPASEXTSQL_PRG';
  gshJobName constant varchar2(100) := 'OPASEXTSQL';

  procedure llog(p_message varchar2, p_level varchar2 default gsrvLoggingLevel)
  is
  begin
    coremod_log.log(p_message, gsrvLoggingLevel, 'OPAS_EXTEXEC');
  end;

  procedure load_external_data(p_target_table varchar2,
                               p_select_list  t_columns,
                               p_sql_body     varchar2,
                               p_dblink       varchar2,
                               p_priority     number default 3,
                               p_task_id      out number)
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
    l_trgcols varchar2(32765);
    l_trgcols_expr varchar2(32765);
    --l_trgcols_dt varchar2(32765);
    --l_trgcols_ldr varchar2(32765);
    l_trgcols_java_vals varchar2(32765);
    --l_fullpath varchar2(32765);
    --l_connstr  varchar2(512);
    --l_exec_id number;
    --l_datafile varchar2(100):= 'data_'||l_exec_id||'.csv';
    --l_time number;
    l_col_num number := 0;
  begin
    for i in (select * from user_tab_columns where table_name=upper(p_target_table) order by column_id) loop
      --l_trgcols_dt:= l_trgcols_dt || i.column_name  || ' ' || case when i.data_type='VARCHAR2' then i.data_type||'('||i.data_length||')' else i.data_type end || ', ';
      --l_trgcols_ldr:= l_trgcols_ldr || i.column_name || ' ' || case when i.data_type='VARCHAR2' and i.data_length>255 then ' char('||i.data_length||')' else null end || ', ';
      l_trgcols := l_trgcols || i.column_name || ', ';
      if p_select_list.exists(i.column_name) then
        l_trgcols_expr := l_trgcols_expr || p_select_list(i.column_name) || ' as ' || i.column_name ||', ' ;
      end if;
      l_trgcols_java_vals:= l_trgcols_java_vals || ' ' ||
         case when i.data_type in ('VARCHAR2', 'CHAR', 'RAW') then '?'
              when i.data_type = 'NUMBER' then 'to_number(?)'
              when i.data_type = 'DATE' then 'to_date(?)'
              when i.data_type = 'TIMESTAMP' then 'to_timestamp(?)'
              else 'Unsupported type '||i.data_type end || ', ';
      l_col_num := l_col_num + 1;
    end loop;
    l_trgcols := rtrim(l_trgcols,', ');
    l_trgcols_expr := rtrim(l_trgcols_expr,', ');
    --l_trgcols_dt := rtrim(l_trgcols_dt,', ');
    --l_trgcols_ldr := rtrim(l_trgcols_ldr,', ');
    l_trgcols_java_vals := rtrim(l_trgcols_java_vals,', ');

    if COREMOD_API.external_mode_dblink(p_dblink) then
      l_sql := l_dbltmpl;
      l_sql := replace(replace(replace(replace(l_sql,'<SQLBODY>',p_sql_body),'<DBLINK>',COREMOD_API.get_dblink_for_query(p_dblink)),'<TARGETTBL>',p_target_table),'<TARGETCOLLIST>',l_trgcols);
      l_sql := replace(l_sql,'<COLLIST>',l_trgcols_expr);
      execute immediate l_sql;
    elsif COREMOD_API.external_mode_javasrv(p_dblink) then
      p_task_id := seq_opas_extproc_queue_srv.nextval;
      l_unlsql := l_extunltmpl;

      l_unlsql := replace(replace(replace(replace(l_unlsql,'<SQLBODY>',p_sql_body),'<DBLINK>'),'<TARGETTBL>',p_target_table),'<TARGETCOLLIST>',l_trgcols);
      l_unlsql := replace(l_unlsql,'<COLLIST>',l_trgcols_expr);

      l_loadsql := q'[INSERT INTO <TARGET_TABLE> ( <TARGETCOLLIST>) VALUES (<INSCOLLIST>)]';
      l_loadsql := replace(replace(replace(l_loadsql,'<TARGET_TABLE>',p_target_table),'<TARGETCOLLIST>',l_trgcols),'<INSCOLLIST>',l_trgcols_java_vals);
    --SQLSELINS
      INSERT INTO opas_extproc_queue_srv (
        TASK_ID, PRIORITY, db_link_name, QRY_TYPE, select_sql, load_sql, col_number, TARGET_TABLE) VALUES (
        p_task_id, p_priority, p_dblink, 'SQLSELINS', l_unlsql,  l_loadsql, l_col_num - 1, p_target_table);
      commit;
    else
      raise_application_error(-20000,'Unsupported external execution mode for DB Link: '||p_dblink);
    end if;

  end;

  procedure cleanup_task(p_task_id number)
  is
  begin
      for i in (select TARGET_TABLE from OPAS_EXTPROC_QUEUE_SRV where TASK_ID=p_task_id)
      loop
        if i.TARGET_TABLE is not null then
          begin
            execute immediate 'delete from '||i.TARGET_TABLE||' where task_id=:task' using p_task_id;
          exception
            when others then llog('Unable to cleanup COREMOD_EXTPROC.cleanup_task('||p_task_id||'): '||i.TARGET_TABLE||': '||sqlerrm);
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
    llog('start_coordinator executed','INFO');
  end;

  procedure stop_worker(p_job_name varchar2) is
  begin
    begin dbms_scheduler.stop_job(job_name  => p_job_name); exception when others then coremod_tasks.log('COREMOD_EXTPROC.stop_worker stop_job: '||p_job_name||': '||sqlerrm); end;
    update OPAS_EXTPROC_WORK_SRV set FINISHED = systimestamp, errmsgs = 'Stopped by stop_worker' where JOB_NAME=p_job_name;
    commit;
    llog('stop_worker executed: '||p_job_name, 'INFO');
  end;

  procedure stop_coordinator is
  begin
    for i in (select * from opas_extproc_work_srv where job_name is not null and finished is null) loop
      stop_worker(p_job_name => i.job_name);
    end loop;

    begin dbms_scheduler.stop_job(job_name  => 'OPASEXTSQL'); exception when others then coremod_tasks.log('COREMOD_EXTPROC.stop_coordinator stop_job: '||sqlerrm); end;
    begin dbms_scheduler.disable('OPASEXTSQL'); exception when others then coremod_tasks.log('COREMOD_EXTPROC.stop_coordinator disable: '||sqlerrm); end;
    --begin dbms_scheduler.drop_program(program_name => 'OPASEXTSQL_PRG'); exception when others then coremod_tasks.log('COREMOD_EXTPROC.stop_coordinator drop_program: '||sqlerrm); end;
    llog('stop_coordinator executed', 'INFO');
  end;

  procedure check_connection_problem(p_dblink       varchar2)
  is
    l_connect_error_count number;
    l_retention_m number := to_number(COREMOD_API.getconf('ALARMLOGININTERVAL'));
  begin
    select count(1) into l_connect_error_count from OPAS_EXTPROC_WORK_SRV where DB_LINK_NAME = p_dblink and errmsgs like 'Connection problem%' and STARTED < sysdate - l_retention_m/(24*60);
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
    l_created_threads number:=0;
    l_running_jobs    number;
    l_dblinks_running t_columns;
    l_dblinks2start   t_columns;
    l_dblink          varchar2(128);

    l_work_id number;
    l_job_name varchar2(128);
  begin
    gsrvLoggingLevel := COREMOD_API.getconf('EXTLOGGINGMODE');

    l_max_workers := to_number(COREMOD_API.getconf('MAXEXTWORKERS'));

    select count(1) into l_running_jobs from user_scheduler_running_jobs where job_name in (select JOB_NAME from OPAS_EXTPROC_WORK_SRV where FINISHED is null and STARTED is not null);

    --llog('coordinator_proc started: '||l_running_jobs);

    if l_max_workers > l_running_jobs then
      l_created_threads := l_max_workers - l_running_jobs;

      for i in (select unique DB_LINK_NAME from OPAS_EXTPROC_WORK_SRV where JOB_NAME in (select JOB_NAME from user_scheduler_running_jobs)) loop
        l_dblinks_running(i.DB_LINK_NAME):='R';
      end loop;

      for i in (select DB_LINK_NAME, count(1) cnt from OPAS_EXTPROC_QUEUE_SRV where STATUS='NEW' group by DB_LINK_NAME)loop
      begin
        check_connection_problem(i.DB_LINK_NAME);
        l_dblinks2start(i.DB_LINK_NAME):=i.cnt;
      exception
        when others then llog('coordinator_proc connection problem: '||i.DB_LINK_NAME||': '||sqlerrm);
      end;
      end loop;

      l_dblink := l_dblinks2start.first;
      loop
        exit when l_dblink is null or l_created_threads <= 0;
        if not l_dblinks_running.exists(l_dblink) and l_created_threads>0 then
          llog('coordinator_proc job l_dblink, l_created_threads: '||l_dblink||', '||l_created_threads);
          --round(2*to_number(l_dblinks2start(l_dblink))/gsrvQueryPerServerSession)
          INSERT INTO opas_extproc_work_srv ( work_id, db_link_name, job_name)
            VALUES (seq_opas_extproc_queue_srv.nextval, l_dblink, 'OPASEXTSQL_'||DBMS_RANDOM.STRING('X',6)) returning work_id, job_name into l_work_id, l_job_name;
          commit;
          dbms_scheduler.create_job(job_name => l_job_name,
                                    job_type => 'PLSQL_BLOCK',
                                    job_action => q'{begin COREMOD_EXTPROC.worker_proc(}' || l_work_id || q'{); end;}',
                                    start_date => systimestamp,
                                    enabled => true,
                                    auto_drop=> true);
          l_created_threads := l_created_threads - 1;
          llog('coordinator_proc job invoked: '||l_job_name);
        end if;
        l_dblink := l_dblinks2start.next(l_dblink);
      end loop;
    --for i in (select DB_LINK_NAME, cnt, count(unique DB_LINK_NAME) over() dblnks from (select DB_LINK_NAME, count(1) cnt from OPAS_EXTPROC_QUEUE_SRV where STATUS='NEW' group by DB_LINK_NAME)) loop
    --  null;
    --end loop;
    end if;
    --llog('coordinator_proc finished');
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
    llog('worker_proc started: '||p_work_id, 'DEBUG');
    start_server_prc(p_work_id => p_work_id);
    llog('worker_proc finished: '||p_work_id, 'DEBUG');
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

  procedure init_server_parameters(p_work_id number, p_username out varchar2, p_password out varchar2, p_connstr out varchar2, p_query_num out number, p_logging_mode out varchar2) is
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

    p_query_num := gsrvQueryPerServerSession;
    p_logging_mode :=gsrvLoggingLevel;
    llog('init_server_parameters finished: '||p_work_id);
  end;

  procedure get_next_task(p_work_id number, p_task_id out number, p_qry_type out varchar2, p_qry1 out varchar2, p_qry2 out varchar2, p_num_cols out number, p_timeouted out number) is
    l_acquired boolean := false;
    l_iterations number := 0;
    l_max_iteration number := to_number(COREMOD_API.getconf('WORKERAQCITERS')); --2 minutes
    l_sleep number := to_number(COREMOD_API.getconf('WORKERAQCSLEEP'));
  begin
    for i in (select * from opas_extproc_work_srv where work_id=p_work_id) loop
      loop
        for j in (select * from OPAS_EXTPROC_QUEUE_SRV where STATUS = 'NEW' and DB_LINK_NAME = i.DB_LINK_NAME for update skip locked order by PRIORITY) loop
          p_task_id := j.task_id;
          p_qry_type := j.QRY_TYPE;
          p_qry1 := j.SELECT_SQL;
          p_qry2 := j.LOAD_SQL;
          p_num_cols := j.COL_NUMBER;
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
      p_timeouted := 1; llog('get_next_task timed out: p_work_id, '||p_work_id, 'INFO');
    else
      llog('get_next_task finished', 'INFO');
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
  procedure set_task_finshed(p_task_id number, p_status varchar2, p_errormsg varchar2/*, p_result clob default null*/) is
    pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_QUEUE_SRV set FINISHED = systimestamp, STATUS=p_status, ERRORMSG = p_errormsg/*, EXEC_RES = p_result*/ where TASK_ID=p_task_id;
    commit;
  end;

  procedure set_task_taken(p_task_id number) is
    pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_QUEUE_SRV set TAKEN = systimestamp, STATUS='TAKEN' where TASK_ID=p_task_id;
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


