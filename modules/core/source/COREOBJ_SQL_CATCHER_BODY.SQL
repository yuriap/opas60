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
      obj_id,  search_condition,  sql_num_limit, sql_time_limit, check_interval, status,  tq_id, srcdb)
    VALUES (
      P_OBJ_ID, def_search_condition, def_sql_num_limit, def_sql_time_limit, def_check_interval, stNew, null, null);
  end;

  procedure set_catcher (p_obj_id            opas_objects.obj_id%type,
                         p_catcher_name      opas_objects.obj_name%type,
                         p_catcher_descr     opas_objects.obj_descr%type,
                         p_search_condition  opas_ot_sqlcatch.search_condition%type,
                         p_SQL_NUM_LIMIT     opas_ot_sqlcatch.SQL_NUM_LIMIT%type,
                         p_SQL_TIME_LIMIT    opas_ot_sqlcatch.SQL_TIME_LIMIT%type,
                         p_CHECK_INTERVAL    opas_ot_sqlcatch.CHECK_INTERVAL%type,
                         p_SRCDB             opas_ot_sqlcatch.SRCDB%type)
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
     srcdb = p_SRCDB
    WHERE
        obj_id = p_obj_id and status in (stNew, stInactive);
  end;

  procedure remove  (p_obj_id         opas_objects.obj_id%type,
                     p_cascade        varchar2 default 'N')
  is
    l_ctchr opas_ot_sqlcatch%rowtype;
  begin
    select * into l_ctchr from opas_ot_sqlcatch where obj_id = p_obj_id;
    COREMOD_TASKS.cancel_task (  P_TQ_ID => l_ctchr.TQ_ID) ;
    delete from opas_ot_sqlcatch where obj_id = p_obj_id;
    COREOBJ_API.remove(p_obj_id);
  end;

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
    l_status opas_ot_sqlcatch.status%type;
  begin
    select status into l_status from opas_ot_sqlcatch where obj_id = p_obj_id;
    return l_status;
  end;

  procedure activate_catcher (p_obj_id            opas_objects.obj_id%type)
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
      COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id ) ;

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
      select unique sql_id, substr(sql_text,1,4000), EXECUTIONS
        from gv$sql<DBLINK>
       where sql_id in (<FILTER>)
         and rownum <= :p_row_limit]';
    l_sql varchar2(32765);
    l_ctchr opas_ot_sqlcatch%rowtype;
    l_start_tim number := dbms_utility.get_time;

    l_obj_id            opas_objects.obj_id%type;
    l_owner             opas_objects.obj_owner%type;
    procedure load_sqls is
    begin
      delete from opas_ot_tmp_sqlcatch_sqls;
      l_sql := replace(replace(l_sql_load,'<FILTER>',l_ctchr.SEARCH_CONDITION),'<DBLINK>',COREMOD_API.get_dblink_for_query(l_ctchr.srcdb));
      execute immediate l_sql using l_ctchr.sql_num_limit;
    end;

  begin
    select obj_owner into l_owner from opas_objects where obj_id = p_obj_id;

    loop
      select * into l_ctchr from opas_ot_sqlcatch where obj_id = p_obj_id;
      --coremod_tasks.log('task_catcher: time active: '||((dbms_utility.get_time - l_start_tim)/100));

      if l_ctchr.status in (stInactive, stNew) then exit;
      elsif l_ctchr.status in (stActive, stActiveCO, stPaused) and 100 * l_ctchr.sql_time_limit < dbms_utility.get_time - l_start_tim then exit;
      elsif l_ctchr.status = stPaused then dbms_lock.sleep(10); continue;
      elsif l_ctchr.status in (stActive, stActiveCO) then
        load_sqls;
        commit;
        merge into OPAS_OT_SQLCATCH_SQLS t
        using opas_ot_tmp_sqlcatch_sqls s
        on (t.OBJ_ID = p_obj_id and t.SQL_ID = s.SQL_ID)
        when matched then update set
          t.actual_execs = s.ACTUAL_EXECS
          where t.status in (ssqltNew)
        when not matched then
        INSERT (obj_id, sql_id, status, execs_num_to_init, sql_text, actual_execs)
        VALUES (p_obj_id, s.sql_id, ssqltNew, def_execs,  s.sql_text, s.ACTUAL_EXECS);

        update OPAS_OT_SQLCATCH_SQLS set
          status = case when EXECS_NUM_TO_INIT <= ACTUAL_EXECS then ssqltReady else status end
        where OBJ_ID = p_obj_id and status in (ssqltNew);

        update OPAS_OT_SQLCATCH_SQLS set
          status = ssqltReady
        where OBJ_ID = p_obj_id and status in (ssqltNew) and sql_id not in (select sql_id from opas_ot_tmp_sqlcatch_sqls);
        commit;


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
      dbms_lock.sleep(l_ctchr.check_interval);
    end loop;
    UPDATE opas_ot_sqlcatch SET status =  stInactive WHERE obj_id = p_obj_id;
    commit;
  exception
    when others then
      rollback;
      UPDATE opas_ot_sqlcatch SET status =  stInactive WHERE obj_id = p_obj_id;
      commit;
      if l_sql is not null then coremod_tasks.log('Error task_catcher ('||p_obj_id||'): '||l_sql); end if;
      coremod_tasks.log('Error task_catcher ('||p_obj_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
  end;

end COREOBJ_SQL_CATCHER;
/
