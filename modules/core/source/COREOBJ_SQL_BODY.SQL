CREATE OR REPLACE
PACKAGE BODY COREOBJ_SQL AS

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_modname          opas_files.modname%type default COREMOD_API.gMODNAME,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_descr            opas_objects.obj_descr%type,
                   p_sql_id           opas_ot_sql_descriptions.sql_id%type,
                   p_db_link          opas_db_links.db_link_name%type)
  AS
    l_sql_exists number;
    l_sess_id    opas_ot_sql_data.sess_id%type;
  BEGIN
    COREOBJ_API.add (  P_OBJ_ID => P_OBJ_ID,
      P_OBJ_PRNT  => P_OBJ_PRNT,
      P_OBJ_OT    => COREOBJ_API.otSQL_PERFORMANCE_DATA,
      P_OBJ_NAME  => p_sql_id,
      P_OBJ_DESCR => p_descr) ;

    select count(1) into l_sql_exists from opas_ot_sql_descriptions where sql_id = p_sql_id;

    if l_sql_exists = 0 then
      INSERT INTO opas_ot_sql_descriptions
               (  sql_id,  sql_text,  created,  created_by)
        VALUES (p_sql_id,      null,  default,  p_owner);
    end if;

    INSERT INTO opas_ot_sql_data
             ( data_id,  sql_id,   start_gathering_dt,  end_gathering_dt, dblink,    gathering_status, tq_id)
      VALUES ( P_OBJ_ID, p_sql_id, null,                null,             p_db_link, sdoNotStarted,    null) returning sess_id into l_sess_id;

    queue_discover_sql(l_sess_id);
  END add;

  procedure queue_discover_sql(p_sess_id    opas_ot_sql_data.sess_id%type)
  is
    L_TASKNAME   OPAS_TASK.TASKNAME%type := 'OPAS_SQL_DISCOVER';
    l_tq_id      OPAS_TASK_QUEUE.tq_id%type;

    l_status     opas_ot_sql_data.gathering_status%type;
  begin
    select gathering_status into l_status from opas_ot_sql_data where sess_id = p_sess_id for update;
    if l_status in (sdoNotStarted, sdoFAILED) then
      l_tq_id:=COREMOD_TASKS.prep_execute_task (  P_TASKNAME => L_TASKNAME) ;
      COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => 'B1', p_num_par => p_sess_id);
      COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id ) ;

      update opas_ot_sql_data set tq_id = l_tq_id, gathering_status = sdoInQueue where sess_id = p_sess_id;

      COREOBJ_SQL_UTILS.init_section_statuses(p_sess_id);
    else
      raise_application_error(-20000,'Inapropriate data object '|| p_sess_id || ' status: '||l_status);
    end if;
  end;

  procedure remove  (p_obj_id    opas_objects.obj_id%type,
                     p_cascade   varchar2 default 'N') AS
  BEGIN
    COREOBJ_API.lock_object(p_obj_id);
    COREOBJ_API.check_remove_ability(p_obj_id);
    delete from opas_ot_sql_data where data_id = p_obj_id;
    COREOBJ_API.remove(p_obj_id);
  END remove;

  procedure drop_sql(p_sql_id    opas_ot_sql_descriptions.sql_id%type) AS
    type t_file_id is table of opas_ot_sql_descriptions.sql_text%type;
    l_file_id1 t_file_id;
    l_file_id2 t_file_id;
    l_sql_text opas_ot_sql_descriptions.sql_text%type;
    l_sql_text_approx opas_ot_sql_descriptions.SQL_TEXT_APPROX%type;
  BEGIN
    delete from OPAS_OT_SQL_SQLMON where sql_id=p_sql_id returning SQL_MON_REPORT, SQL_MON_HST_REPORT bulk collect into l_file_id1, l_file_id2;
    for i in 1..l_file_id1.count loop
      COREMOD_FILE_UTILS.delete_file (  P_FILE_ID => l_file_id1(i)) ;
    end loop;

    for i in 1..l_file_id2.count loop
      COREMOD_FILE_UTILS.delete_file (  P_FILE_ID => l_file_id2(i)) ;
    end loop;

    delete from opas_ot_sql_descriptions where sql_id = p_sql_id returning sql_text, SQL_TEXT_APPROX into l_sql_text, l_sql_text_approx;
    COREMOD_FILE_UTILS.delete_file (  P_FILE_ID => l_sql_text) ;
    COREMOD_FILE_UTILS.delete_file (  P_FILE_ID => l_sql_text_approx) ;
  END drop_sql;

/*
  procedure group_sql_in_folder(
                    p_folder_id        opas_objects.obj_id%type)
  is
    l_folder_name v$opas_objects.obj_name%type;
    L_OBJ_ID      v$opas_objects.obj_id%type;
  begin
    select obj_name into l_folder_name from v$opas_objects where obj_id = p_folder_id;
    for i in (select sqls.sql_id from v$opas_objects o, opas_ot_sql_data sqls
               where o.obj_id=sqls.data_id
                 and o.obj_ot = COREOBJ_API.otSQL_PERFORMANCE_DATA
                 and o.obj_prnt = p_folder_id
            group by sqls.sql_id
              having count(1)>1)
    loop
      if l_folder_name <> i.sql_id then
        COREOBJ_FOLDER.add (  P_OBJ_ID => L_OBJ_ID, P_OBJ_PRNT => p_folder_id) ;
      end if;
    end loop;
  end;
*/
END COREOBJ_SQL;
/
