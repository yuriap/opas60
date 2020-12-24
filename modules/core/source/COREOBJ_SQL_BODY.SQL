

CREATE OR REPLACE
PACKAGE BODY COREOBJ_SQL AS

  procedure queue_discover_sql(p_sql_data_point    opas_ot_sql_data%rowtype,
                               p_notifyme         boolean default false,
                               p_priority         varchar2 default null,
                               p_start_time       date default null)
  is
    L_TASKNAME   OPAS_TASK.TASKNAME%type := case when p_sql_data_point.prnt_data_point_id is null then 'OPAS_SQL_DISCOVER' else 'OPAS_SQL_DISCOVER_REC' end;
    l_tq_id      OPAS_TASK_QUEUE.tq_id%type;

    l_status     opas_ot_sql_data.gathering_status%type;
    l_sql_id     opas_ot_sql_data.sql_id%type;
    l_owner      OPAS_OBJECTS.OBJ_OWNER%type;
    l_obj_id     OPAS_OBJECTS.obj_id%type;
    l_nt_id      opas_notification.ID%type;
  begin
    select gathering_status, sql_id into l_status, l_sql_id from opas_ot_sql_data where sql_data_point_id = p_sql_data_point.sql_data_point_id for update;

    if l_status in (sdoNotStarted, sdoFAILED) then

      l_tq_id:=COREMOD_TASKS.prep_execute_task (  P_TASKNAME => L_TASKNAME) ;
      COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => 'B1', p_num_par => p_sql_data_point.sql_data_point_id);

      if p_notifyme then
        select OBJ_OWNER, obj_id into l_owner, l_obj_id from OPAS_OBJECTS where obj_id = (select obj_id from OPAS_OT_SQL_DATA_POINT_REF where SQL_DATA_POINT_ID = p_sql_data_point.SQL_DATA_POINT_ID);

        COREMOD_ALERTS.add_notification (
          nt_id => l_nt_id,
          NT_TEXT => 'SQL Report for "'||l_sql_id|| '" finished with '||COREMOD_ALERTS.ntPlaceHolder,
          --NT_LINK => COREMOD_ALERTS.create_url(), 'f?p='||v('APP_ID')||':1401:<APP_SESSION>::::APP_OBJ_ID,APP_PREV_PAGE:'||l_obj_id||',10',
          NT_TYPE_ID => COREMOD_ALERTS.nttTaskfinished,
          --NT_COLOR => NT_COLOR, --default
          NT_USERNAME => l_owner,
          --NT_NO_BROWSER_NOTIF_FLAG => NT_NO_BROWSER_NOTIF_FLAG, default
          NT_ACTIVATE => 0) ;

        COREMOD_ALERTS.set_url (
          NT_ID => l_nt_id,
          P_OBJ_ID => l_obj_id,
          p_page_id => 1401,
          P_PREV_PAGE => 10) ;

        COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => COREMOD_TASKS.parNotifyMe, p_num_par => l_nt_id);
      end if;

      COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id, p_priority => queue_discover_sql.p_priority, p_start_time => queue_discover_sql.p_start_time) ;

      update opas_ot_sql_data set tq_id = l_tq_id, gathering_status = sdoInQueue where sql_data_point_id = p_sql_data_point.sql_data_point_id;

      COREOBJ_SQL_UTILS.init_section_statuses(p_sql_data_point.sql_data_point_id);

    else
      raise_application_error(-20000,'Inapropriate data object '|| p_sql_data_point.sql_data_point_id || ' status: '||l_status);
    end if;
  end;

  procedure add_sql_description(p_sql_id                     opas_ot_sql_descriptions.sql_id%type,
                                p_created_by                 opas_ot_sql_descriptions.created_by%type,
                                p_first_discovered           opas_ot_sql_descriptions.first_discovered%type,
                                p_first_discovered_at        opas_ot_sql_descriptions.first_discovered_at%type,
                                p_sql_text                   opas_ot_sql_descriptions.sql_text%type)
  is
    l_sql_exists number;
  begin
    coremod_api.lock_resource(p_resource_name => 'SQLID'||p_sql_id,
                              p_mode => 6,
                              p_timeout => 60,
                              p_release_on_commit => true);

    select count(1) into l_sql_exists from opas_ot_sql_descriptions where sql_id = p_sql_id;

    if l_sql_exists = 0 then
      INSERT INTO opas_ot_sql_descriptions
               (  sql_id,  sql_text,   sql_text_approx, created_by,   first_discovered,   first_discovered_at )
        VALUES (p_sql_id,  p_sql_text, null,            p_created_by, p_first_discovered, p_first_discovered_at);
    end if;

    coremod_api.release_resource;
  end;

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_modname          opas_files.modname%type default COREMOD_API.gMODNAME,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_descr            opas_objects.obj_descr%type,
                   p_sql_id           opas_ot_sql_descriptions.sql_id%type,
                   p_db_link          opas_db_links.db_link_name%type,
                   p_prnt_dp          opas_ot_sql_data.prnt_data_point_id%type default null,
                   p_notifyme         boolean default false,
                   p_priority         varchar2 default null,
                   p_start_time       date default null)
  AS
    l_sql_exists number;
    l_sql_data_point    opas_ot_sql_data%rowtype;
  BEGIN
    COREOBJ_API.add (  P_OBJ_ID => P_OBJ_ID,
      P_OBJ_PRNT  => P_OBJ_PRNT,
      P_OBJ_OT    => COREOBJ_API.otSQL_PERFORMANCE_DATA,
      P_OBJ_NAME  => p_sql_id,
      P_OBJ_DESCR => p_descr,
      p_obj_owner => p_owner) ;

    coreobj_sql.add_sql_description(p_sql_id => p_sql_id,
                                    p_created_by => p_owner,
                                    p_first_discovered => null,
                                    p_first_discovered_at => null,
                                    p_sql_text => null);

    INSERT INTO opas_ot_sql_data
             ( sql_data_point_id,     sql_id,   start_gathering_dt,  end_gathering_dt,    dblink,    gathering_status, tq_id, tq_id2, prnt_data_point_id)
      VALUES ( opas_ot_sq_dp.nextval, p_sql_id, null,                null,             p_db_link,    sdoNotStarted,    null,  null, p_prnt_dp)
    returning sql_data_point_id,prnt_data_point_id into l_sql_data_point.sql_data_point_id, l_sql_data_point.prnt_data_point_id;

    INSERT INTO opas_ot_sql_data_point_ref
             ( obj_id,  sql_data_point_id)
      VALUES ( P_OBJ_ID, l_sql_data_point.sql_data_point_id);

    queue_discover_sql(l_sql_data_point, p_notifyme, p_priority, p_start_time);
  END add;

  procedure remove  (p_obj_id    opas_objects.obj_id%type,
                     p_cascade   varchar2 default 'N') AS
    l_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type;
  BEGIN
    COREOBJ_API.lock_object(p_obj_id);
    COREOBJ_API.check_remove_ability(p_obj_id);
    delete from opas_ot_sql_data_point_ref where obj_id = p_obj_id returning sql_data_point_id into l_sql_data_point_id;
    if p_cascade = 'Y' then
      remove_dp(l_sql_data_point_id);
    end if;
    COREOBJ_API.remove(p_obj_id);
  END remove;

  procedure remove_dp(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type)
  is
    l_files1 tableofnumbers;
    l_files2 tableofnumbers;
    l_plans  tableofnumbers;
    l_sql_id opas_ot_sql_data.sql_id%type;
    l_ids    tableofnumbers;
    l_log_level       varchar2(100) := 'DEBUG';
  begin
    -- remove recursive sql datapoints first
    COREMOD_LOG.log ('remove_dp: Start removing '||p_sql_data_point_id, l_log_level);

    select sql_id into l_sql_id from opas_ot_sql_data where sql_data_point_id = p_sql_data_point_id;

    for i in (select sql_data_point_id, sql_id from opas_ot_sql_data where prnt_data_point_id = p_sql_data_point_id) loop
      COREMOD_LOG.log ('remove_dp: Start removing recursive '||i.sql_data_point_id, l_log_level);
      remove_dp(i.sql_data_point_id);
      COREMOD_LOG.log ('remove_dp: Finish removing recursive '||i.sql_data_point_id, l_log_level);
    end loop;

    --remove objects referencing this datapoint
    delete from opas_ot_sql_data_point_ref where sql_data_point_id = p_sql_data_point_id returning obj_id bulk collect into l_ids;
    for i in 1..l_ids.count loop
      remove(l_ids(i), 'N');
    end loop;

    --remove SQL Monitor if noone references it
    delete from opas_ot_sql_sqlmon
     where sqlmon_id in (select sqlmon_id from opas_ot_sql_sqlmon_ref o
                          where sql_data_point_id = p_sql_data_point_id
                            and not exists (select 1 from opas_ot_sql_sqlmon_ref i where o.sqlmon_id = i.sqlmon_id and sql_data_point_id != p_sql_data_point_id))
      returning sql_mon_report, sql_mon_hst_report, plan_id bulk collect into l_files1, l_files2, l_plans;
    delete from opas_ot_sql_sqlmon_ref o where sql_data_point_id = p_sql_data_point_id;
    delete from opas_ot_sql_plans where plan_id in (select column_value from table(l_plans) where column_value is not null);

    --remove plans if noone references it
    delete from opas_ot_sql_plans
     where plan_id in (select plan_id from opas_ot_sql_plan_ref o
                        where sql_data_point_id = p_sql_data_point_id
                          and not exists
                            (select 1 from opas_ot_sql_plan_ref i where o.plan_id = i.plan_id and sql_data_point_id != p_sql_data_point_id)
                       minus
                       select plan_id from opas_ot_sql_sqlmon where sql_id=l_sql_id
                       );
/*
COREMOD_LOG.log ('remove_dp: opas_ot_sql_plans start: '||p_sql_data_point_id||' '||l_sql_id, l_log_level);
    for i in (select plan_id from opas_ot_sql_plan_ref o
                        where sql_data_point_id = p_sql_data_point_id
                          and not exists
                            (select 1 from opas_ot_sql_plan_ref i where o.plan_id = i.plan_id and sql_data_point_id != p_sql_data_point_id)
                       minus
                       select plan_id from opas_ot_sql_sqlmon where sql_id=l_sql_id)
    loop
      COREMOD_LOG.log ('remove_dp: opas_ot_sql_plan_ref start: '||i.plan_id, l_log_level);
for j in (select x.sqlmon_id from opas_ot_sql_sqlmon x where x.plan_id=i.plan_id)
loop
  COREMOD_LOG.log ('remove_dp: opas_ot_sql_sqlmon: '||j.sqlmon_id, l_log_level);
end loop;
      delete from opas_ot_sql_plans where plan_id = i.plan_id;
      COREMOD_LOG.log ('remove_dp: opas_ot_sql_plan_ref finish: '||i.plan_id, l_log_level);
    end loop;
*/
    delete from opas_ot_sql_plan_ref o where sql_data_point_id = p_sql_data_point_id;

    --remove AWR plans if noone references it
    delete from opas_ot_sql_awr_plans
     where plan_id in (select plan_id from opas_ot_sql_awr_plan_ref o
                        where sql_data_point_id = p_sql_data_point_id
                          and not exists
                            (select 1 from opas_ot_sql_awr_plan_ref i where o.plan_id = i.plan_id and sql_data_point_id != p_sql_data_point_id)
                       );
    delete from opas_ot_sql_awr_plan_ref o where sql_data_point_id = p_sql_data_point_id;

    for i in 1..l_files1.count loop
      COREMOD_FILE_UTILS.delete_file (  P_FILE_ID => l_files1(i)) ;
    end loop;

    for i in 1..l_files2.count loop
      COREMOD_FILE_UTILS.delete_file (  P_FILE_ID => l_files2(i)) ;
    end loop;

    --delete data point
    delete from opas_ot_sql_data where sql_data_point_id = p_sql_data_point_id;

    COREMOD_LOG.log ('remove_dp: Finish removing '||p_sql_data_point_id, l_log_level);
  end;

  procedure drop_sql(p_sql_id    opas_ot_sql_descriptions.sql_id%type) AS
    l_sql_text        opas_ot_sql_descriptions.sql_text%type;
    l_sql_text_approx opas_ot_sql_descriptions.SQL_TEXT_APPROX%type;
    l_log_level       varchar2(100) := 'DEBUG';
  BEGIN
    COREMOD_LOG.log ('drop_sql: Start removing '||p_sql_id, l_log_level);

    for i in (select sql_data_point_id from opas_ot_sql_data where sql_id = p_sql_id) loop
      COREMOD_LOG.log ('drop_sql: Start removing '||i.sql_data_point_id, l_log_level);
      remove_dp(i.sql_data_point_id);
      COREMOD_LOG.log ('drop_sql: Finish removing '||i.sql_data_point_id, l_log_level);
    end loop;

    delete from opas_ot_sql_descriptions where sql_id = p_sql_id returning sql_text, SQL_TEXT_APPROX into l_sql_text, l_sql_text_approx;
    COREMOD_FILE_UTILS.delete_file (  P_FILE_ID => l_sql_text) ;
    COREMOD_FILE_UTILS.delete_file (  P_FILE_ID => l_sql_text_approx) ;

    COREMOD_LOG.log ('drop_sql: Finish removing '||p_sql_id, l_log_level);
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

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
    l_status varchar2(100);
  begin
    select GATHERING_STATUS ||
           case when GATHERING_STATUS in (sdoREADY,sdoFAILED,sdoNotStarted) then null
           else ' ' || to_char((select round(100*sum(decode(GATHERING_STATUS,COREOBJ_SQL_UTILS.sstReady,1,COREOBJ_SQL_UTILS.sstFailed,1,COREOBJ_SQL_UTILS.sstEmpty,1,0))/count(1)) from OPAS_OT_SQL_DATA_SECT s where s.SQL_DATA_POINT_ID=d.SQL_DATA_POINT_ID))
                || '%'
           end into l_status
      from OPAS_OT_SQL_DATA_POINT_REF r, OPAS_OT_SQL_DATA d
     where r.obj_id=p_obj_id and r.SQL_DATA_POINT_ID=d.SQL_DATA_POINT_ID;

    return l_status;
  exception
    when others then return 'Broken: '||SQLCODE;
  end;

END COREOBJ_SQL;
/


