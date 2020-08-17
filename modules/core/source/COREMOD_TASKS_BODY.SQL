CREATE OR REPLACE


package body coremod_tasks as

  g_time number;
  g_cpu_tim number;

  gJOBNMPREF   constant varchar2(10):='OPASTASK';

  gTQ_ID       number;

  function get_curr_tq_id return opas_task_queue.tq_id%type is begin return gTQ_ID; end;

  procedure log(p_msg opas_log.msg%type, p_tq_id opas_task_queue.tq_id%type default null)
  is
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    if length(p_msg)<=4000 then
      insert into opas_log (created, msg, tq_id) values (default, p_msg, nvl(p_tq_id,gTQ_ID));
    else
      insert into opas_log (created, msg_long, tq_id) values (default, p_msg, nvl(p_tq_id,gTQ_ID));
    end if;
    commit;
  end;

  procedure cleanup_tasks is
    l_rows_processed number;
  begin
    delete from opas_task_queue
     where (systimestamp - finished > TO_DSINTERVAL(COREMOD_API.getconf('TASKRETENTION',COREMOD_API.gMODNAME)||' 00:00:00'))
        or (status = gtqRUNNING and started<sysdate-0.95 and nvl(job_name,'~^') not in (select job_name from user_scheduler_running_jobs))
        or  status = gtqCanceled;
    l_rows_processed:=sql%rowcount;
    commit;
    coremod_log.log('Cleanup task queue: deleted '||l_rows_processed||' row(s).');
  end;


  procedure create_task(p_taskname   opas_task.taskname%type,
                        p_modname    opas_task.modname%type,
                        p_is_public  opas_task.is_public%type default 'Y',
                        p_task_priority opas_task.task_priority%type,
                        p_task_body  opas_task.task_body%type)
  is
  begin
    INSERT INTO opas_task (taskname, modname, is_public, created, task_body, task_priority)
                   VALUES (upper(p_taskname),p_modname,p_is_public,default,p_task_body, p_task_priority);
  end;


  function prep_execute_task(p_taskname opas_task.taskname%type,
                             p_task_subname opas_task_queue.task_subname%type default null) return opas_task_queue.tq_id%type
  is
    l_tq_id opas_task_queue.tq_id%type;
  begin
    INSERT INTO opas_task_queue (taskname, owner, status, task_subname) VALUES (p_taskname, nvl(V('APP_USER'),'PUBLIC'), gtqNEW, p_task_subname) returning tq_id into l_tq_id;
    return l_tq_id;
  end;

  procedure set_task_param(p_tq_id opas_task_queue.tq_id%type, p_name opas_task_pars.par_name%type, p_num_par number)
  is
  begin
    merge into OPAS_TASK_PARS t using (select p_tq_id id, p_name nm, p_num_par val from dual) s
    on (t.tq_id = s.id and t.par_name=s.nm)
    when matched then update set num_par = s.val
    when not matched then insert (tq_id,par_name,num_par) values (s.id, s.nm, s.val);
  end;

  procedure set_task_param(p_tq_id opas_task_queue.tq_id%type, p_name opas_task_pars.par_name%type, p_varchar_par varchar2)
  is
  begin
    merge into OPAS_TASK_PARS t using (select p_tq_id id, p_name nm, p_varchar_par val from dual) s
    on (t.tq_id = s.id and t.par_name=s.nm)
    when matched then update set varchar_par = s.val
    when not matched then insert (tq_id,par_name,varchar_par) values (s.id, s.nm, s.val);
  end;

  procedure set_task_param(p_tq_id opas_task_queue.tq_id%type, p_name opas_task_pars.par_name%type, p_date_par date)
  is
  begin
    merge into OPAS_TASK_PARS t using (select p_tq_id id, p_name nm, p_date_par val from dual) s
    on (t.tq_id = s.id and t.par_name=s.nm)
    when matched then update set date_par = s.val
    when not matched then insert (tq_id,par_name,date_par) values (s.id, s.nm, s.val);
  end;

  procedure set_task_param_list(p_tq_id opas_task_queue.tq_id%type, p_name opas_task_pars.par_name%type, p_list_par varchar2)
  is
  begin
    merge into OPAS_TASK_PARS t using (select p_tq_id id, p_name nm, p_list_par val from dual) s
    on (t.tq_id = s.id and t.par_name=s.nm)
    when matched then update set list_par = s.val
    when not matched then insert (tq_id,par_name,list_par) values (s.id, s.nm, s.val);
  end;

  procedure queue_task(p_tq_id opas_task_queue.tq_id%type, p_start_time date default null)
  is
    l_task_name opas_task_queue.taskname%type;
    l_job_name  opas_task_queue.job_name%type;
  begin
    if p_start_time is null then
      update opas_task_queue set status=gtqQUEUED, queued=systimestamp where tq_id = p_tq_id and status=gtqNEW returning taskname into l_task_name;
      if sql%rowcount<1 then
        raise_application_error(-20000,'Unable to change task status ID, Status: '||p_tq_id||', '||gtqQUEUED);
      end if;
    else
      select taskname into l_task_name from opas_task_queue where tq_id = p_tq_id;

      l_job_name := gJOBNMPREF||'_'||upper(l_task_name)||'_'||DBMS_RANDOM.STRING('X',6);

      update opas_task_queue set status=gtqSCHEDULED, queued=systimestamp, job_name = l_job_name where tq_id = p_tq_id and status=gtqNEW;
      if sql%rowcount<1 then
        raise_application_error(-20000,'Unable to change task status ID, Status: '||p_tq_id||', '||gtqQUEUED);
      end if;

      dbms_scheduler.create_job(job_name => l_job_name,
                                job_type => 'PLSQL_BLOCK',
                                job_action => 'begin coremod_tasks.execute_task('||p_tq_id||'); end;',
                                start_date => p_start_time,
                                enabled => true,
                                auto_drop=> true);
    end if;
  end;

  procedure set_task_started(p_tq_id opas_task_queue.tq_id%type, p_job_name opas_task_queue.job_name%type)
  is
  begin
    update opas_task_queue set status=gtqSTARTED, job_name = p_job_name where tq_id = p_tq_id and status in (gtqQUEUED);
    if sql%rowcount<1 then
      raise_application_error(-20000,'Unable to change task status ID, Status: '||p_tq_id||', '||gtqSTARTED);
    end if;
  end;

  procedure set_task_running(p_tq_id opas_task_queue.tq_id%type)
  is
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    g_time:=DBMS_UTILITY.GET_TIME;
    g_cpu_tim:=DBMS_UTILITY.GET_CPU_TIME;
    update opas_task_queue set
           started=systimestamp,
           sid=SYS_CONTEXT('USERENV','SID'),
           serial#=(select serial# from gv$session where sid=SYS_CONTEXT('USERENV','SID') and inst_id=SYS_CONTEXT('USERENV','INSTANCE')),
           inst_id=SYS_CONTEXT('USERENV','INSTANCE'),
           status=gtqRUNNING
     where tq_id=p_tq_id and status in (gtqSTARTED, gtqSCHEDULED);
    if sql%rowcount<1 then
      raise_application_error(-20000,'Unable to change task status ID, Status: '||p_tq_id||', '||gtqRUNNING);
    end if;
    commit;
  exception
    when others then
      rollback;
      raise;
  end;
  procedure set_task_finished(p_tq_id opas_task_queue.tq_id%type, p_status opas_task_queue.status%type)
  is
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
      g_time:=DBMS_UTILITY.GET_TIME-g_time;
      g_cpu_tim:=DBMS_UTILITY.GET_CPU_TIME-g_cpu_tim;
      update opas_task_queue set
             finished=systimestamp,
             cpu_time=g_cpu_tim/100,
             elapsed_time=g_time/100,
             status=p_status
       where tq_id=p_tq_id and status in (gtqRUNNING);
    if sql%rowcount<1 then
      raise_application_error(-20000,'Unable to change task status ID, Status: '||p_tq_id||', '||p_status);
    end if;
    commit;
  exception
    when others then
      rollback;
      raise;
  end;

  procedure exec_coordinator
  is
  begin
    dbms_scheduler.run_job('OPAS_TASK_COORD',use_current_session => false);
  end;

  procedure execute_task_proc is  --job coordinator
    --l_running_jobs number;
    l_freeslots    number;
    type t_task_tbl is table of opas_task_queue%rowtype;
    l_tasks   t_task_tbl;
    l_2run    t_task_tbl := t_task_tbl();
    /*
    l_high_limit number := to_number(COREMOD_API.getconf('MAXTHREADS'||tpHIGH,COREMOD_API.gMODNAME));
    l_norm_limit number := to_number(COREMOD_API.getconf('MAXTHREADS'||tpNORM,COREMOD_API.gMODNAME));
    l_low_limit  number := to_number(COREMOD_API.getconf('MAXTHREADS'||tpLOW,COREMOD_API.gMODNAME));
    */
  begin
    COREMOD_API.lock_resource(
      P_RESOURCE_NAME => 'OPASTASKCOORD',
      P_MODE => 6,
      P_TIMEOUT => 60,
      P_RELEASE_ON_COMMIT => false);

    for i in (select priority_levels.lvl task_priority, count(j.job_name) cnt
                from (select decode(level,1,tpHIGH,2,tpNORM,3,tpLOW,4,tpINTERNAL) lvl from dual connect by level <=4) priority_levels,
                     USER_SCHEDULER_RUNNING_JOBS j,
                     opas_task_queue tq,
                     opas_task t
               where priority_levels.lvl = t.task_priority(+)
                 and j.job_name(+) like gJOBNMPREF||'%'
                 and j.job_name(+) = tq.job_name
                 and tq.taskname(+) = t.taskname
               group by priority_levels.lvl)
    loop
      if i.task_priority = tpINTERNAL then
        l_freeslots := 1000;
      else
        if i.cnt < to_number(COREMOD_API.getconf('MAXTHREADS'||i.task_priority,COREMOD_API.gMODNAME)) then
          l_freeslots:= to_number(COREMOD_API.getconf('MAXTHREADS'||i.task_priority,COREMOD_API.gMODNAME)) - i.cnt;
        else
          l_freeslots := 0;
        end if;
      end if;

      select tq.* bulk collect into l_tasks
        from opas_task_queue tq, opas_task t
       where status=gtqQUEUED
         and tq.taskname = t.taskname
         and t.task_priority = i.task_priority
         for update skip locked order by queued;

      for i in 1..least(l_freeslots,l_tasks.count) loop
        l_2run.extend;
        l_2run(l_2run.count):=l_tasks(i);
        l_2run(l_2run.count).job_name:=gJOBNMPREF||'_'||upper(l_2run(l_2run.count).taskname)||'_'||DBMS_RANDOM.STRING('X',6);
        set_task_started(l_tasks(i).tq_id, l_2run(l_2run.count).job_name);
      end loop;
    end loop;

    commit;

    for i in 1..l_2run.count
    loop
      begin
        dbms_scheduler.create_job(job_name => l_2run(i).job_name,
                                  job_type => 'PLSQL_BLOCK',
                                  job_action => 'begin coremod_tasks.execute_task('||l_2run(i).tq_id||'); end;',
                                  start_date => systimestamp,
                                  enabled => true,
                                  auto_drop=> true);
      exception
        when others then
          log('Execute task error: '||sqlerrm,l_2run(i).tq_id);
          log(DBMS_UTILITY.FORMAT_ERROR_STACK,l_2run(i).tq_id);
      end;
    end loop;

    COREMOD_API.release_resource;
  end;

  procedure cancel_task(p_tq_id opas_task_queue.tq_id%type)
  is
    l_job_name  opas_task_queue.job_name%type;
  begin
    update opas_task_queue set status=gtqCanceled where tq_id = p_tq_id and status in (gtqNEW,gtqQUEUED,gtqSCHEDULED) returning job_name into l_job_name;
    /*
    if sql%rowcount<1 then
      raise_application_error(-20000,'Unable to change task status ID, Status: '||p_tq_id||', '||gtqCanceled);
    end if;
    */
    if l_job_name is not null then
      dbms_scheduler.disable(l_job_name);
      dbms_scheduler.drop_job(l_job_name);
    end if;

    log('Executed cancel_task: '||p_tq_id||'; '||nvl(l_job_name,'N/A'));
  exception
    when others then
      log('cancel_task error: '||sqlerrm,p_tq_id);
      log(DBMS_UTILITY.FORMAT_ERROR_STACK);
  end;

  procedure stop_task(p_tq_id opas_task_queue.tq_id%type)
  is
    l_job_name opas_task_queue.job_name%type;
  begin
    --select job_name into l_job_name from opas_task_queue where tq_id=p_tq_id;
    update opas_task_queue set status=gtqCanceled where tq_id = p_tq_id and status in (gtqRUNNING) returning job_name into l_job_name;
    commit;
    if l_job_name is not null then
      dbms_scheduler.stop_job(l_job_name, true);
    end if;
    log('Executed stop_task: '||p_tq_id||'; '||nvl(l_job_name,'N/A'));
  exception
     when others then
       log('Stop job error: '||l_job_name||':'||p_tq_id||chr(10)||sqlerrm);
       log(DBMS_UTILITY.FORMAT_ERROR_STACK);
  end;

  procedure stop_previous_user_task(p_taskname   opas_task.taskname%type)
  is
  begin
    for i in (select * from opas_task_queue where status=gtqRUNNING and owner = V('APP_USER') and taskname=p_taskname and job_name in (select job_name from user_scheduler_running_jobs)) loop
      log('Stopping previous instance of '||p_taskname||' with job name: '||i.job_name);
      stop_task(i.tq_id);
    end loop;
  end;

  procedure create_task_job is
  begin
    dbms_scheduler.create_program(
                              program_name             => 'OPAS_TASK_COORD_PRG',
                              program_type             => 'PLSQL_BLOCK',
                              program_action           => 'begin coremod_tasks.execute_task_proc; end;',
                              enabled                  => true,
                              comments                 => 'OPAS Task job coordinator program');
    dbms_scheduler.create_job(job_name                 => 'OPAS_TASK_COORD',
                              program_name             => 'OPAS_TASK_COORD_PRG',
                              start_date               => trunc(systimestamp,'mi'),
                              repeat_interval          => 'FREQ=SECONDLY; INTERVAL=10',
                              job_style                => 'LIGHTWEIGHT',
                              $IF not OPAS_CLOUD.gOPAS_CLOUD $THEN
                              job_class                => 'JC_'||user,
                              $END
                              enabled                  => true);
  end;

  procedure wait_task_finish(p_tq_id opas_task_queue.tq_id%type, p_timeout number default 3600)
  is
    l_expiration_time date := sysdate + p_timeout/3600/24;
    l_status          opas_task_queue.status%type;
  begin
  /*
    loop
      select status into l_status from opas_task_queue where tq_id=p_tq_id;

      if l_expiration_time < sysdate then
        raise exTimedOutTask;
      end if;

      exit when l_status in (gtqSUCCEEDED,gtqFAILED,gtqCanceled);
      dbms_lock.sleep(15);
    end loop;

  gtqNEW       constant varchar2(10):='NEW';
  gtqQUEUED    constant varchar2(10):='QUEUED';
  gtqSTARTED   constant varchar2(10):='STARTED';
  gtqSCHEDULED constant varchar2(10):='SCHEDULED';
  gtqRUNNING   constant varchar2(10):='RUNNING';
  gtqSUCCEEDED constant varchar2(10):='SUCCEEDED';
  gtqFAILED    constant varchar2(10):='FAILED';
  gtqCanceled  constant varchar2(10):='CANCELED';
  */
    loop
      select STATUS into l_STATUS from opas_task_queue where tq_id = p_tq_id;
      exit when l_STATUS not in (gtqNEW,gtqQUEUED,gtqSTARTED,gtqSCHEDULED);
      dbms_lock.sleep(10);
    end loop;

    COREMOD_API.lock_resource(
      P_RESOURCE_NAME => 'OPASTASK'||p_tq_id,
      P_MODE => 6,
      P_TIMEOUT => p_timeout,
      P_RELEASE_ON_COMMIT => true);
    commit;
  end;

  procedure execute_task(p_tq_id opas_task_queue.tq_id%type)
  is
    l_task opas_task%rowtype;
    l_task_body clob;
  begin

    --to be able to wait for job finish
    COREMOD_API.lock_resource(
      P_RESOURCE_NAME => 'OPASTASK'||p_tq_id,
      P_MODE => 6,
      P_TIMEOUT => 0,
      P_RELEASE_ON_COMMIT => false);

    gTQ_ID:=p_tq_id;
    set_task_running(p_tq_id);
    select * into l_task from opas_task where taskname=(select taskname from opas_task_queue where tq_id = p_tq_id);
    l_task_body:=l_task.task_body;
    for i in (select * from opas_task_pars where tq_id = p_tq_id) loop
      case
        when i.num_par is not null then
          l_task_body:=replace(l_task_body,'<'||i.par_name||'>',i.num_par);
        when i.varchar_par is not null then
          l_task_body:=replace(l_task_body,'<'||i.par_name||'>',q'[']'||i.varchar_par||q'[']');
        when i.list_par is not null then
          l_task_body:=replace(l_task_body,'<'||i.par_name||'>',i.list_par);
        when i.date_par is not null then
          raise_application_error(-20000,'Not implemented parameter type: DATE');
        else
          raise_application_error(-20000,'Null parameter passed');
      end case;
    end loop;
    log('Start task: '||l_task.taskname,p_tq_id);
    execute immediate l_task_body;
    log('End task: '||l_task.taskname,p_tq_id);
    set_task_finished(p_tq_id,gtqSUCCEEDED);
    gTQ_ID:=null;
  exception
    when others then
      set_task_finished(p_tq_id,gtqFAILED);
      log('Execute task error ('||l_task.taskname||'): '||sqlerrm,p_tq_id);
      log('Task body: '||l_task_body,p_tq_id);
      log('Execute task error stack: '||DBMS_UTILITY.FORMAT_ERROR_STACK,p_tq_id);
      gTQ_ID:=null;
      raise_application_error(-20000, 'Execute task error ('||l_task.taskname||'): '||sqlerrm);
  end;


  procedure drop_task(p_taskname opas_task.taskname%type) is
  begin
    delete from opas_task where taskname=upper(p_taskname);
    commit;
  end;

end;
/


