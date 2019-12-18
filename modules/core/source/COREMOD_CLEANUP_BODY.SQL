CREATE OR REPLACE
package body coremod_cleanup as

  procedure register_cleanup_tasks(p_taskname   opas_cleanup_tasks.taskname%type,
                                   p_modname    opas_cleanup_tasks.modname%type,
                                   p_frequency_h opas_cleanup_tasks.frequency_h%type,
                                   p_task_body  opas_cleanup_tasks.task_body%type)
  is
  begin
    insert into opas_cleanup_tasks ( taskname, modname, created, task_body, frequency_h, last_exec) values (p_taskname, p_modname, systimestamp, p_task_body, p_frequency_h, systimestamp);
  end;

  procedure create_cleanup_job is
  begin
    dbms_scheduler.create_job(job_name => 'OPAS_CLEANUP_JOB',
                              job_type => 'PLSQL_BLOCK',
                              job_action => 'begin coremod_cleanup.cleanup_job_proc; end;',
                              start_date => trunc(systimestamp,'hh'),
                              repeat_interval => 'FREQ=MINUTELY; INTERVAL=10',
                              enabled => true);
  end;


  procedure cleanup_job_proc is
    l_tasks tableofstrings;
  begin
    select taskname bulk collect into l_tasks from opas_cleanup_tasks where last_exec + frequency_h/24 <= systimestamp order by taskname;
    for j in 1..l_tasks.count loop
      for i in (select taskname,task_body,modname from opas_cleanup_tasks where taskname = l_tasks(j))
      loop
        begin
          coremod_log.log('Executing cleanup task: '||i.modname||'.'||i.taskname);
          update opas_cleanup_tasks set last_exec = systimestamp where taskname = i.taskname;
          commit;
          execute immediate i.task_body;
        exception
          when others then
            rollback;
            coremod_log.log('Cleanup job error ('||i.modname||'.'||i.taskname||'): '||sqlerrm);
            coremod_log.log(DBMS_UTILITY.FORMAT_ERROR_STACK);
            coremod_log.log(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        end;
      end loop;
    end loop;

    begin
      ctx_ddl.sync_index('idx_txt_opas_files', '2M');
    exception
      when others then
        rollback;
        coremod_log.log('Cleanup job text index idx_txt_opas_files synchronizing error: '||sqlerrm);
        coremod_log.log(DBMS_UTILITY.FORMAT_ERROR_STACK);
        coremod_log.log(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
    end;
  end;

end;
/
