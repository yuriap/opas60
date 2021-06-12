

CREATE OR REPLACE
PACKAGE BODY COREMOD_EXTPROC_SRV AS

  --gExtSQLCoordinator varchar2(128) := 'OPASEXTSQL';
  gsrvQueryPerServerSession number; -- init section below
  gsrvLoggingLevel          varchar2(10); -- init section below

  gParent_Task_Id number;

  -- *****************************************************************************************************
  -- logging
  -- *****************************************************************************************************

  procedure log_info(p_message varchar2) is begin coremod_log.log(p_message, 'INFO', 'OPAS_EXTEXECSRV'); end;
  procedure log_debug(p_message varchar2) is
  begin
    if gsrvLoggingLevel = 'DEBUG' then
      coremod_log.log(p_message, 'INFO', 'OPAS_EXTEXECSRV');
    end if;
  end;


-- *****************************************************************************************************
-- cleanups
-- *****************************************************************************************************
  procedure cleanup_task(p_task_id number)
  is
  begin
      for i in (select TARGET_TABLE from OPAS_EXTPROC_QUEUE_SRV where TASK_ID=p_task_id)
      loop
        if i.TARGET_TABLE is not null then
          begin
            execute immediate 'delete from '||i.TARGET_TABLE||'_EXT where task_id=:task' using p_task_id;
          exception
            when others then log_info('Unable to cleanup COREMOD_EXTPROC_SRV.cleanup_task('||p_task_id||'): '||i.TARGET_TABLE||': '||sqlerrm);
          end;
        end if;
      end loop;
  end;

  procedure Cleanup_queue
  is
    l_ids TABLEOFNUMBERS;
    l_retention_h number := to_number(COREMOD_API.getconf('EXTEXECLOGRETENT'));
  begin
    delete from OPAS_EXTPROC_WORK_SRV where FINISHED < sysdate - l_retention_h/24;
    select task_id bulk collect into l_ids from OPAS_EXTPROC_QUEUE_SRV
     where (nvl(FINISHED,TAKEN) < sysdate - l_retention_h/24) or
           (status='PRE' and created < sysdate - l_retention_h/24);
    for i in 1..l_ids.count loop
      cleanup_task(l_ids(i));
      delete from OPAS_EXTPROC_QUEUE_SRV where task_id=l_ids(i);
      commit;
    end loop;
  end;

-- *****************************************************************************************************
-- coordinator job procedures
-- *****************************************************************************************************
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
                              program_action           => 'begin COREMOD_EXTPROC_SRV.coordinator_proc; end;',
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

  procedure stop_coordinator is
  begin
    for i in (select * from opas_extproc_work_srv where job_name is not null and finished is null) loop
      stop_worker(p_job_name => i.job_name);
    end loop;

    begin dbms_scheduler.stop_job(job_name  => 'OPASEXTSQL'); exception when others then coremod_tasks.log('COREMOD_EXTPROC_SRV.stop_coordinator stop_job: '||sqlerrm); end;
    begin dbms_scheduler.disable('OPASEXTSQL'); exception when others then coremod_tasks.log('COREMOD_EXTPROC_SRV.stop_coordinator disable: '||sqlerrm); end;
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

    select count(1) into l_connect_error_count
      from OPAS_EXTPROC_WORK_SRV
     where DB_LINK_NAME = p_dblink and errmsgs like 'Connection problem%' and STARTED > sysdate - 5/(24*60*60);

    if l_connect_error_count > 0 then
      raise_application_error(-20000,'DB Link '||p_dblink||' has connectivity problem');
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
        if COREMOD_API.getconf('SERVERTYPE') = 'STANDALONE' then
          select ' Standalone server heart beat: '||cast(systimestamp - LAST_EVENT as INTERVAL DAY(2) TO SECOND(3)) recent_run into l_status from OPAS_EXTPROC_WORK_SRV_HEARTBEAT where rownum=1;
        end if;
        l_status := 'Server enabled: '||i.enabled||'; Run: '||i.recent_run||' ago. Next run: '||i.next_run_date||l_status;
      end if;
    end loop;
    return l_status;
  end;

  procedure coordinator_proc_standalone_v2 is
    l_max_workers number;
    l_threads2create  number:=0;
    l_queued_jobs     number;
    l_zombie_jobs     number;
    l_running_jobs    number;
    l_dblinks_running t_jobs;
    l_dblinks2start   t_jobs;
    l_dblinks2ban     t_jobs;
    --l_dblink          varchar2(128);

    l_work_id number;
    l_job_name varchar2(128);

    l_iter number := 0;
    l_maxiter  number := to_number(COREMOD_API.getconf('COORDAQCITERS'));
    l_sleep    number := to_number(COREMOD_API.getconf('COORDAQCSLEEP'));
  begin
    log_debug('coordinator_proc_standalone_v2 started');
    loop
      if l_iter = 0 or mod(l_iter,20)=0 then
        gsrvLoggingLevel := COREMOD_API.getconf('EXTLOGGINGMODE');
        l_max_workers := to_number(COREMOD_API.getconf('MAXEXTWORKERS'));
        gsrvQueryPerServerSession := to_number(COREMOD_API.getconf('QRYPERWORKERSESS'));
      end if;

      for i in (SELECT que_actual.DB_LINK_NAME, que_length, nvl(sess_alive,0)sess_alive, nvl(task_active,0) task_active, max_TIMEOUT_SECS, nvl(total_cnt,0) total_cnt
                  FROM (select DB_LINK_NAME, count(1) que_length
                          from OPAS_EXTPROC_QUEUE_SRV que0
                         where status = 'NEW'
                         group by que0.DB_LINK_NAME) que_actual,
                       (select wrkr.DB_LINK_NAME,
                               count(1) total_cnt,
                               sum(decode(ss.sid,null,0,1)) sess_alive,
                               sum(decode(wrkr.TASK_ID,null,0,1)) task_active,
                               max(que.TIMEOUT_SECS) max_TIMEOUT_SECS
                          from opas_extproc_work_srv  wrkr,
                               gv$session             ss,
                               OPAS_EXTPROC_QUEUE_SRV que
                         where wrkr.SESS_SID = ss.sid(+)
                           and wrkr.SESS_INST_ID = ss.inst_id(+)
                           and wrkr.TASK_ID = que.TASK_ID(+)
                           and wrkr.finished is null
                           group by wrkr.DB_LINK_NAME) wrkr
                 where que_actual.DB_LINK_NAME = wrkr.DB_LINK_NAME(+))
      loop
        log_debug('coordinator_proc_standalone_v2: DB_LINK_NAME='||i.DB_LINK_NAME||'; total_cnt='||i.total_cnt||'; que_length='||i.que_length||'; sess_alive='||i.sess_alive||'; task_active='||i.task_active||'; max_TIMEOUT_SECS='||i.max_TIMEOUT_SECS);

        if not l_dblinks2ban.exists(i.DB_LINK_NAME) then
          begin
            check_connection_problem(i.DB_LINK_NAME);
          exception
            when others then
              if not l_dblinks2ban.exists(i.DB_LINK_NAME) then
                l_dblinks2ban(i.DB_LINK_NAME) := 20;
              end if;
              log_info('coordinator_proc_standalone_v2 connection problem: '||i.DB_LINK_NAME||': '||sqlerrm);
          end;
        else
          if l_dblinks2ban(i.DB_LINK_NAME)>0 then
            l_dblinks2ban(i.DB_LINK_NAME):=l_dblinks2ban(i.DB_LINK_NAME)-1;
          else
            l_dblinks2ban.delete(i.DB_LINK_NAME);
          end if;
        end if;

        if gsrvLoggingLevel = 'DEBUG' then
          if i.que_length > 0 and i.sess_alive<l_max_workers and i.sess_alive < i.task_active then
            log_debug('coordinator_proc_standalone_v2 condition 1: i.que_length > 0 and i.sess_alive<l_max_workers and i.sess_alive < i.task_active: '||
            i.que_length||' > 0 and '||i.sess_alive||'<'||l_max_workers||' and '||i.sess_alive||' < '||i.task_active);
          end if;

          if i.que_length > 0 and i.sess_alive<l_max_workers+2 and i.task_active = i.sess_alive and i.task_active > 0
          then
            log_debug('coordinator_proc_standalone condition 2: i.que_length > 0 and i.sess_alive<l_max_workers+2 and i.task_active = i.sess_alive and i.task_active > 0: '||
            i.que_length||' > 0 and '||i.sess_alive||'<'||(l_max_workers+2)||' and '||i.sess_alive||' = '||i.task_active||' and '||i.task_active||' > 0');
          end if;

          if i.total_cnt <= l_max_workers+2
          then
            log_debug('coordinator_proc_standalone_v2 condition 3: i.total_cnt <= l_max_workers+2: '||
            i.total_cnt||'<'||(l_max_workers+2));
          end if;

          if i.que_length > 0 and i.total_cnt<l_max_workers+2 and i.total_cnt < i.que_length + 1
          then
            log_debug('coordinator_proc_standalone condition 4: i.que_length > 0 and i.total_cnt<l_max_workers+2 and i.total_cnt < i.que_length + 1: '||
            i.que_length||' > 0 and '||i.total_cnt||'<'||(l_max_workers+2)||' and '||i.total_cnt||' < '||(i.que_length + 1));
          end if;
        end if;

        --pause to start another worker for the same dblink
        if (i.que_length > 0 and i.sess_alive<l_max_workers and i.sess_alive < i.task_active or
            i.que_length > 0 and i.sess_alive<l_max_workers+2 and i.task_active = i.sess_alive and i.task_active > 0 or
            i.que_length > 0 and i.total_cnt<l_max_workers+2 and i.total_cnt < i.que_length + 1)
            and
            i.total_cnt <= l_max_workers+2
        then
          if not l_dblinks2ban.exists(i.DB_LINK_NAME) then
            INSERT INTO opas_extproc_work_srv ( work_id, db_link_name, job_name)
              VALUES (seq_opas_extproc_work_srv.nextval, i.DB_LINK_NAME, gshJobName||'_'||DBMS_RANDOM.STRING('X',6)) returning work_id, job_name into l_work_id, l_job_name;
            log_debug('coordinator_proc_standalone_v2 to start: l_job_name l_dblink: '||l_job_name||', '||i.DB_LINK_NAME);
          else
            log_info('coordinator_proc_standalone_v2 to banned: l_dblink: '||i.DB_LINK_NAME);
          end if;
        else
          log_debug('coordinator_proc_standalone_v2 limit reached: l_dblink: '||i.DB_LINK_NAME);
        end if;
      end loop;
      commit;

      l_iter := l_iter + 1;
      exit when l_iter > l_maxiter;
      dbms_session.sleep(l_sleep);
      log_debug('coordinator_proc_standalone_v2 slept: '||l_sleep);
    end loop;
    log_debug('coordinator_proc_standalone_v2 finished');
  end coordinator_proc_standalone_v2;

  procedure get_next_server(p_work_id out number) is
    l_acquired boolean := false;
    l_iterations number := 0;
    l_max_iteration number := to_number(COREMOD_API.getconf('COORDAQCITERS')); --2 minutes
    l_sleep number := to_number(COREMOD_API.getconf('COORDGNSSLEEP'));
  begin
    log_debug('get_next_server started');

    p_work_id := 0;
    loop
      for j in (select * from opas_extproc_work_srv where STARTED is null and FINISHED is null for update skip locked order by WORK_ID) loop
        p_work_id := j.WORK_ID;
        l_acquired := true;
        update opas_extproc_work_srv set STARTED = systimestamp where WORK_ID=j.WORK_ID;
        commit;
        exit;
      end loop;
      l_iterations := l_iterations + 1;

      if l_iterations = 0 or mod(l_iterations,100)=0 then
        update opas_extproc_work_srv_heartbeat set last_event = systimestamp;
        commit;
      end if;

      exit when l_acquired or l_iterations>l_max_iteration;
      dbms_session.sleep(l_sleep);
    end loop;

    commit;

    log_debug('get_next_server finished');
  end;

  procedure coordinator_proc is
  begin
    if COREMOD_API.getconf('SERVERTYPE') = 'LOCALJVM' then
      --coordinator_proc_local();
      raise_application_error(-20000,'Deprecated server type: LOCALJVM');
    elsif COREMOD_API.getconf('SERVERTYPE') = 'STANDALONE' then
      coordinator_proc_standalone_v2();
    else
      raise_application_error(-20000,'Unsupported server type: <'||COREMOD_API.getconf('SERVERTYPE')||'>');
    end if;
  end;

-- *****************************************************************************************************
-- worker's procedures
-- *****************************************************************************************************
  procedure worker_proc(p_work_id number) is
  begin
    dbms_output.enable(1000000);
    DBMS_JAVA.SET_OUTPUT(1000000);
    log_debug('worker_proc started: '||p_work_id);
    start_server_prc(p_work_id => p_work_id);
    log_debug('worker_proc finished: '||p_work_id);
  end;

  procedure stop_worker(p_job_name varchar2) is
  begin
    begin dbms_scheduler.stop_job(job_name  => p_job_name); exception when others then coremod_tasks.log('COREMOD_EXTPROC_SRV.stop_worker stop_job: '||p_job_name||': '||sqlerrm); end;
    update OPAS_EXTPROC_WORK_SRV set FINISHED = systimestamp, errmsgs = 'Stopped by stop_worker', TASK_ID = null where JOB_NAME=p_job_name;
    commit;
    log_info('stop_worker executed: '||p_job_name);
  end;

  procedure stop_worker(p_work_id number) is
  begin
    for i in (select * from opas_extproc_work_srv where work_id=p_work_id) loop
      stop_worker(p_job_name => i.job_name);
    end loop;
  end;

  procedure server_before_start
  is
  begin
    update OPAS_EXTPROC_WORK_SRV set FINISHED = systimestamp, ERRMSGS = 'Cleaned up', TASK_ID = null where FINISHED is null;-- and STARTED is not null;
    log_info('server_before_start finished: cleaned abandoned workes: '||sql%rowcount);
    commit;
  end;

  procedure init_server_parameters(p_work_id number, p_username out varchar2, p_password out varchar2, p_connstr out varchar2, p_query_num out number, p_logging_mode out varchar2, p_batch_size out number) is
    l_status varchar2(100);
    pragma autonomous_transaction;
  begin
    if COREMOD_API.getconf('SERVERTYPE') = 'LOCALJVM' then
      for i in (select * from opas_extproc_work_srv where job_name is not null and finished is null and STARTED is null and work_id=p_work_id for update nowait) loop
        update OPAS_EXTPROC_WORK_SRV set STARTED = systimestamp, SESS_SID = sys_context('USERENV','SID'),SESS_INST_ID = sys_context('USERENV','INSTANCE') where work_id=p_work_id;
      end loop;
    elsif COREMOD_API.getconf('SERVERTYPE') = 'STANDALONE' then
      update OPAS_EXTPROC_WORK_SRV set STARTED = systimestamp, SESS_SID = sys_context('USERENV','SID'),SESS_INST_ID = sys_context('USERENV','INSTANCE') where work_id=p_work_id;
    else
      raise_application_error(-20000,'Unsupported server type: <'||COREMOD_API.getconf('SERVERTYPE')||'>');
    end if;
    log_info('init_server_parameters: '||p_work_id || ' <' || sys_context('USERENV','SID') || '> <'|| sys_context('USERENV','INSTANCE')||'>' );
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

  procedure worker_finished(p_work_id number, p_stmt_done number, p_errors varchar2) is
    pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_WORK_SRV set FINISHED = systimestamp, QRY_EXECUTED = p_stmt_done, errmsgs = p_errors, TASK_ID = null where work_id=p_work_id and finished is null;
    commit;
  end;

  procedure report_connection_problem(p_work_id number, p_errormsg varchar2)
  is
    pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_WORK_SRV set FINISHED = systimestamp, errmsgs = 'Connection problem: '||p_errormsg, TASK_ID = null where work_id=p_work_id;
    commit;
  end;

-- *****************************************************************************************************
-- task operations
-- *****************************************************************************************************
  procedure get_next_task(p_work_id number, p_task_id out number, p_qry_type out varchar2, p_qry1 out varchar2, p_qry2 out varchar2, p_qry3 out varchar2, p_num_cols out number, p_timeouted out number) is
    l_acquired       boolean := false;
    l_iterations     number := 0;
    l_max_iteration  number := to_number(COREMOD_API.getconf('WORKERAQCITERS')); --2 minutes
    l_sleep          number := to_number(COREMOD_API.getconf('WORKERAQCSLEEP'));
    --l_Parent_Task_Id number;
    --gParent_Task_Id global - preserves state between calls to peek up the child tasks
    l_status         OPAS_EXTPROC_QUEUE_SRV.STATUS%type;
  begin
    for i in (select * from opas_extproc_work_srv where work_id=p_work_id) loop
      loop
        for j in (select * from OPAS_EXTPROC_QUEUE_SRV where STATUS = 'NEW' and DB_LINK_NAME = i.DB_LINK_NAME and
                 (gParent_Task_Id is null and PARENT_TASK_ID is null or
                  gParent_Task_Id is null and TASK_ID = PARENT_TASK_ID or
                  gParent_Task_Id is not null and PARENT_TASK_ID = gParent_Task_Id)
                  for update skip locked order by PRIORITY, CREATED) loop

          if j.PARENT_TASK_ID is not null and gParent_Task_Id is null then
            gParent_Task_Id := j.PARENT_TASK_ID;
            log_info('get_next_task get parent task: p_work_id, gParent_Task_Id: '||p_work_id||', '||gParent_Task_Id);
          elsif j.PARENT_TASK_ID is null and gParent_Task_Id is not null then
            gParent_Task_Id := null;
            log_info('get_next_task reset parent task: p_work_id, '||p_work_id);
          end if;

           if j.PARENT_TASK_ID is not null then
            select status into l_status from OPAS_EXTPROC_QUEUE_SRV where TASK_ID = j.PARENT_TASK_ID and PARENT_TASK_ID = TASK_ID;
            if l_status in ('FAILED', 'TIMEDOUT') then
              gParent_Task_Id := null;
              log_info('get_next_task reset parent task ('||l_status||') : p_work_id, '||p_work_id);
            end if;
          end if;

          p_task_id := j.task_id;
          p_qry_type := j.QRY_TYPE;
          p_qry1 := j.SELECT_SQL;
          p_qry2 := j.LOAD_SQL;
          p_num_cols := j.COL_NUMBER;
          p_qry3 := j.PL_SQL;
          l_acquired := true;
          update OPAS_EXTPROC_QUEUE_SRV set STARTED = systimestamp, status='STARTED' where TASK_ID=j.TASK_ID;
          update OPAS_EXTPROC_WORK_SRV set TASK_ID = j.TASK_ID where work_id=p_work_id;
          exit;
        end loop;
        l_iterations := l_iterations + 1;
        exit when gParent_Task_Id is null and (l_acquired or l_iterations>l_max_iteration) or
                  gParent_Task_Id is not null and (l_acquired or l_iterations>(l_max_iteration*1.5)) ;
        dbms_session.sleep(l_sleep);
      end loop;
    end loop;
    commit;

    p_timeouted := 0;
    if l_iterations>l_max_iteration then
      p_timeouted := 1; log_info('get_next_task timed out: p_work_id, '||p_work_id);
    else
      log_debug('get_next_task finished');
    end if;
  end;

  procedure set_task_finshed(p_work_id number, p_task_id number, p_status varchar2, p_errormsg varchar2, p_rows_processed number/*, p_result clob default null*/) is
    pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_QUEUE_SRV set FINISHED = systimestamp, STATUS=p_status, ERRORMSG = p_errormsg, ROWS_PROCESSED = p_rows_processed/*, EXEC_RES = p_result*/ where TASK_ID=p_task_id;
    update OPAS_EXTPROC_WORK_SRV set TASK_ID = null where work_id=p_work_id;
    commit;
  end;

-- *****************************************************************************************************
-- client API calls parameters
-- *****************************************************************************************************

  procedure set_param(p_task_id number, p_ordr_num number, p_clob clob) is
  pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_RESULTS set R_CLOB = p_clob where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
    commit;
  end;

  procedure set_param(p_task_id number, p_ordr_num number, p_number number) is
  pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_RESULTS set R_NUMBER = p_number where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
    commit;
  end;

  procedure set_param(p_task_id number, p_ordr_num number, p_date date) is
  pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_RESULTS set R_DATE = p_date where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
    commit;
  end;

  procedure set_param(p_task_id number, p_ordr_num number, p_timestamp timestamp) is
  pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_RESULTS set R_TIMESTAMP = p_timestamp where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
    commit;
  end;

  procedure set_param(p_task_id number, p_ordr_num number, p_timestamp_tz timestamp with time zone) is
  pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_RESULTS set R_TIMESTAMP_TZ = p_timestamp_tz where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
    commit;
  end;

  procedure set_param(p_task_id number, p_ordr_num number, p_varchar2 varchar2) is
  pragma autonomous_transaction;
  begin
    update OPAS_EXTPROC_RESULTS set R_VARCHAR = p_varchar2 where TASK_ID = p_task_id and R_ORDR_NUM = p_ordr_num;
    commit;
  end;

begin
  gsrvLoggingLevel := COREMOD_API.getconf('EXTLOGGINGMODE');
  gsrvQueryPerServerSession := to_number(COREMOD_API.getconf('QRYPERWORKERSESS'));
END COREMOD_EXTPROC_SRV;
/


