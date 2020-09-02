

CREATE OR REPLACE
package body COREOBJ_SQL_CATCHER is

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_modname          opas_files.modname%type default COREMOD_API.gMODNAME,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_catcher_name     opas_objects.obj_name%type default null,
                   p_descr            opas_objects.obj_descr%type default null)
  is
  begin
    COREOBJ_API.add (  P_OBJ_ID => P_OBJ_ID,
      P_OBJ_PRNT  => P_OBJ_PRNT,
      P_OBJ_OT    => COREOBJ_API.otSQL_Catcher,
      P_OBJ_NAME  => nvl(p_catcher_name, 'SQL Catcher ' ||to_char(sysdate,'YYYYMMDD')),
      P_OBJ_DESCR => p_descr,
      p_obj_owner => p_owner) ;

    INSERT INTO opas_ot_sqlcatch (
      obj_id,  search_condition,  sql_num_limit, sql_time_limit, check_interval, status,  tq_id, srcdb, sql_exec_def)
    VALUES (
      P_OBJ_ID, def_search_condition, def_sql_num_limit, def_sql_time_limit, def_check_interval, stNew, null, null, def_execs);
  end;

  procedure set_catcher (p_obj_id            opas_objects.obj_id%type,
                         p_catcher_name      opas_objects.obj_name%type,
                         p_catcher_descr     opas_objects.obj_descr%type,
                         p_search_condition  opas_ot_sqlcatch.search_condition%type,
                         p_SQL_NUM_LIMIT     opas_ot_sqlcatch.SQL_NUM_LIMIT%type,
                         p_SQL_TIME_LIMIT    opas_ot_sqlcatch.SQL_TIME_LIMIT%type,
                         p_CHECK_INTERVAL    opas_ot_sqlcatch.CHECK_INTERVAL%type,
                         p_SRCDB             opas_ot_sqlcatch.SRCDB%type,
                         p_sql_exec_def      opas_ot_sqlcatch.sql_exec_def%type)
  is
  begin
    COREOBJ_API.edit_descr  (p_obj_id  => p_obj_id,
                             p_obj_name => p_catcher_name,
                             p_obj_descr => p_catcher_descr);
    UPDATE opas_ot_sqlcatch
    SET
     search_condition = p_search_condition,
     sql_num_limit = p_SQL_NUM_LIMIT,
     sql_time_limit = p_SQL_TIME_LIMIT,
     check_interval = p_CHECK_INTERVAL,
     srcdb = p_SRCDB,
     sql_exec_def = p_sql_exec_def
    WHERE
        obj_id = p_obj_id and status in (stNew, stInactive);

    UPDATE opas_ot_sqlcatch
    SET
     search_condition = p_search_condition,
     sql_num_limit = p_SQL_NUM_LIMIT,
     sql_time_limit = p_SQL_TIME_LIMIT,
     check_interval = p_CHECK_INTERVAL,
     sql_exec_def = p_sql_exec_def
    WHERE
        obj_id = p_obj_id;
  end;

  procedure remove  (p_obj_id         opas_objects.obj_id%type,
                     p_cascade        varchar2 default 'N')
  is
    l_ctchr opas_ot_sqlcatch%rowtype;
  begin
    COREOBJ_API.check_remove_ability(p_obj_id);

    select * into l_ctchr from opas_ot_sqlcatch where obj_id = p_obj_id;
    COREMOD_TASKS.cancel_task (  P_TQ_ID => l_ctchr.TQ_ID) ;
    delete from opas_ot_sqlcatch where obj_id = p_obj_id;

    for i in (select * from opas_objects o, opas_object_types ot where o.obj_ot=ot.ot_id and obj_prnt = p_obj_id) loop
      if p_cascade = 'N' then
        raise_application_error(-20000,'Folder is not empty');
      end if;
      execute immediate 'begin '||i.ot_api_pkg||q'[.remove(p_obj_id => :p_obj_id, p_cascade => :p_cascade); end; ]' using i.obj_id, p_cascade;
    end loop;
    COREOBJ_API.remove(p_obj_id);
  end;

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
    l_status opas_ot_sqlcatch.status%type;
  begin
    select status into l_status from opas_ot_sqlcatch where obj_id = p_obj_id;
    return l_status;
  end;

  procedure activate_catcher (p_obj_id            opas_objects.obj_id%type,
                              p_start_time        date default null)
  is
    l_ctchr opas_ot_sqlcatch%rowtype;
    L_TASKNAME   OPAS_TASK.TASKNAME%type := 'OPAS_SQL_CATCHER';
    l_tq_id      OPAS_TASK_QUEUE.tq_id%type;
  begin
    select * into l_ctchr from opas_ot_sqlcatch where obj_id = p_obj_id;

    if l_ctchr.search_condition is not null and
       l_ctchr.sql_num_limit is not null and
       l_ctchr.sql_time_limit is not null and
       l_ctchr.check_interval is not null and
       l_ctchr.srcdb is not null and
       l_ctchr.status in (stNew, stInactive)
    then
      l_tq_id:=COREMOD_TASKS.prep_execute_task (  P_TASKNAME => L_TASKNAME) ;
      COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => 'B1', p_num_par => p_obj_id);
      COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id, p_start_time => activate_catcher.p_start_time ) ;

      UPDATE opas_ot_sqlcatch SET status =  stActive, TQ_ID = l_tq_id WHERE obj_id = p_obj_id;
    else
      raise_application_error(-20000, 'Unable to activate SQL Catcher, check parameters and status');
    end if;
  end;

  procedure collectonly_catcher (p_obj_id            opas_objects.obj_id%type)
  is
    l_ctchr opas_ot_sqlcatch%rowtype;
  begin
    select * into l_ctchr from opas_ot_sqlcatch where obj_id = p_obj_id;
    if l_ctchr.status in (stNew, stInactive) then
      activate_catcher(p_obj_id);
    else
      UPDATE opas_ot_sqlcatch SET status = stActiveCO WHERE obj_id = p_obj_id and status in (stActive, stPaused);
    end if;
  end;

  procedure pause_catcher (p_obj_id            opas_objects.obj_id%type)
  is
  begin
    UPDATE opas_ot_sqlcatch SET status = stPaused WHERE obj_id = p_obj_id and status in (stActive, stActiveCO);
  end;

  procedure resume_catcher (p_obj_id            opas_objects.obj_id%type)
  is
  begin
    UPDATE opas_ot_sqlcatch SET status = stActive WHERE obj_id = p_obj_id and status in (stPaused, stActiveCO);
  end;

  procedure stop_catcher (p_obj_id            opas_objects.obj_id%type)
  is
    l_ctchr opas_ot_sqlcatch%rowtype;
  begin
    select * into l_ctchr from opas_ot_sqlcatch where obj_id = p_obj_id and status not in (stNew, stInactive);
    COREMOD_TASKS.cancel_task (  P_TQ_ID => l_ctchr.TQ_ID) ;
    UPDATE opas_ot_sqlcatch SET status = stInactive WHERE obj_id = p_obj_id;
  end;

  procedure task_catcher     (p_obj_id            opas_objects.obj_id%type)
  is
    l_sql_load varchar2(32765) := q'[
      insert into opas_ot_tmp_sqlcatch_sqls (sql_id, sql_text, ACTUAL_EXECS)
      select sql_id, substr(sql_text,1,4000), sum(EXECUTIONS)
        from gv$sql<DBLINK>
       where sql_id in (<FILTER>)
         and rownum <= :p_row_limit
         group by sql_id, substr(sql_text,1,4000)]';
    l_sql               varchar2(32765);
    l_ctchr             opas_ot_sqlcatch%rowtype;
    l_start_tim         number := dbms_utility.get_time;

    l_obj_id            opas_objects.obj_id%type;
    l_owner             opas_objects.obj_owner%type;

    l_lops_ind          pls_integer;
    l_msg               varchar2(1000);

    l_cnt1              number := 0;
    l_cnt2              number := 0;
    l_cnt3              number := 0;
    l_log_time          number := dbms_utility.get_time;
    l_name              opas_objects.obj_name%type;
    l_nt_id             opas_notification.ID%type;

    procedure load_sqls is
    begin
      delete from opas_ot_tmp_sqlcatch_sqls;
      l_sql := replace(replace(l_sql_load,'<FILTER>',l_ctchr.SEARCH_CONDITION),'<DBLINK>',COREMOD_API.get_dblink_for_query(l_ctchr.srcdb));
      execute immediate l_sql using l_ctchr.sql_num_limit;

      commit;
      if l_ctchr.check_interval > 60 and COREMOD_API.get_dblink_for_query(l_ctchr.srcdb) is not null then
        execute immediate 'ALTER SESSION CLOSE DATABASE LINK '||l_ctchr.srcdb;
      end if;
    end;

  begin
    select obj_owner, obj_name into l_owner, l_name from opas_objects where obj_id = p_obj_id;
    select * into l_ctchr from opas_ot_sqlcatch where obj_id = p_obj_id;
    coremod_api.init_longops(p_op_name => 'SQL Catching',
                             p_target_desc => 'for duration',
                             p_units => 'sec',
                             p_totalwork => l_ctchr.sql_time_limit,
                             p_lops_ind => l_lops_ind);
    --coremod_tasks.log(l_ctchr.sql_time_limit);
    loop

      select * into l_ctchr from opas_ot_sqlcatch where obj_id = p_obj_id;
      --coremod_tasks.log('task_catcher: time active: '||((dbms_utility.get_time - l_start_tim)/100));

      if l_ctchr.status in (stInactive, stNew) then exit;
      elsif l_ctchr.status in (stActive, stActiveCO, stPaused) and 100 * l_ctchr.sql_time_limit < dbms_utility.get_time - l_start_tim then exit;
      elsif l_ctchr.status = stPaused then dbms_lock.sleep(10); continue;
      elsif l_ctchr.status in (stActive, stActiveCO) then
        -- short distributed transaction with connection closing
        load_sqls;
        --
        merge into OPAS_OT_SQLCATCH_SQLS t
        using opas_ot_tmp_sqlcatch_sqls s
        on (t.OBJ_ID = p_obj_id and t.SQL_ID = s.SQL_ID)
        when matched then update set
          t.actual_execs = s.ACTUAL_EXECS
          where t.status in (ssqltNew)
        when not matched then
        INSERT (obj_id, sql_id, status, execs_num_to_init, sql_text, actual_execs, PICKED)
        VALUES (p_obj_id, s.sql_id, ssqltNew, l_ctchr.sql_exec_def,  s.sql_text, s.ACTUAL_EXECS, systimestamp);
        l_cnt1 := l_cnt1 + sql%rowcount;

        update OPAS_OT_SQLCATCH_SQLS set
          status = case when EXECS_NUM_TO_INIT <= ACTUAL_EXECS then ssqltReady else status end
        where OBJ_ID = p_obj_id and status in (ssqltNew) and EXECS_NUM_TO_INIT <= ACTUAL_EXECS;
        l_cnt2 := l_cnt2 + sql%rowcount;

        update OPAS_OT_SQLCATCH_SQLS set
          status = ssqltReady
        where OBJ_ID = p_obj_id and status in (ssqltNew) and sql_id not in (select sql_id from opas_ot_tmp_sqlcatch_sqls);
        l_cnt3 := l_cnt3 + sql%rowcount;

        commit;

        if dbms_utility.get_time - l_log_time > 12000 -- 2 minute
        then
          l_msg := 'Added: '||l_cnt1; l_cnt1 := 0;
          l_msg := l_msg||'; Ready by exec num: '||l_cnt2; l_cnt2 := 0;
          l_msg := l_msg||'; Ready by out of V$SQL: '||l_cnt3; l_cnt3 := 0;
          coremod_tasks.log(l_msg);
          l_log_time := dbms_utility.get_time;
        end if;

        if l_ctchr.status in (stActive) then
          for i in (select obj_id,sql_id from opas_ot_sqlcatch_sqls where status=ssqltReady and obj_id = p_obj_id)
          loop
            coreobj_sql.add(p_obj_id => l_obj_id,
                            p_obj_prnt => p_obj_id,
                            --p_modname => 'OPASCORE',
                            p_owner => l_owner,
                            p_descr => 'SQL Catcher',
                            p_sql_id => i.sql_id,
                            p_db_link => l_ctchr.srcdb,
                            p_prnt_dp => null);

            update opas_ot_sqlcatch_sqls set status=ssqltCollected where obj_id=i.obj_id and sql_id=i.sql_id;
            commit;
            dbms_lock.sleep(3);
          end loop;
        end if;
      end if;

      coremod_api.end_longops_section(p_sofar => round((dbms_utility.get_time - l_start_tim)/100),
                                      p_lops_ind => l_lops_ind);
      --coremod_tasks.log(round((dbms_utility.get_time - l_start_tim)/100));

      dbms_lock.sleep(l_ctchr.check_interval);
    end loop;
    UPDATE opas_ot_sqlcatch SET status =  stInactive WHERE obj_id = p_obj_id;

    COREMOD_ALERTS.add_notification (
          nt_id => l_nt_id,
          NT_TEXT => 'SQL Catcher "'|| l_name|| '" finished by schedule',
          NT_TYPE_ID => COREMOD_ALERTS.nttTaskfinished,
          NT_COLOR => COREMOD_ALERTS.ntcGreen,
          NT_USERNAME => l_owner,
          --NT_NO_BROWSER_NOTIF_FLAG => 0,
          NT_ACTIVATE => 1) ;

    COREMOD_ALERTS.set_url (
          NT_ID => l_nt_id,
          P_OBJ_ID => p_obj_id,
          p_page_id => 7000,
          P_PREV_PAGE => 10) ;

    commit;

  exception
    when others then
      rollback;

      COREMOD_ALERTS.add_notification (
          nt_id => l_nt_id,
          NT_TEXT => 'SQL Catcher "'|| l_name|| '" failed with: '||sqlerrm,
          NT_TYPE_ID => COREMOD_ALERTS.nttException,
          NT_COLOR => COREMOD_ALERTS.ntcRed,
          NT_USERNAME => l_owner,
          NT_NO_BROWSER_NOTIF_FLAG => 0,
          NT_ACTIVATE => 1) ;

         COREMOD_ALERTS.set_url (
          NT_ID => l_nt_id,
          P_OBJ_ID => p_obj_id,
          p_page_id => 7000,
          P_PREV_PAGE => 10) ;

      UPDATE opas_ot_sqlcatch SET status =  stInactive WHERE obj_id = p_obj_id;
      commit;
      if l_sql is not null then coremod_tasks.log('Error task_catcher ('||p_obj_id||'): '||l_sql); end if;
      coremod_tasks.log('Error task_catcher ('||p_obj_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
  end;

end COREOBJ_SQL_CATCHER;
/


