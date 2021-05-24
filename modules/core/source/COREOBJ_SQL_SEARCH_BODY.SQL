

CREATE OR REPLACE
PACKAGE BODY COREOBJ_SQL_SEARCH AS

  gCurrentSession opas_ot_sql_searches.session_id%type;
  gSearchMode varchar2(1);

  g_qry_priority number := 1;
  g_qry_timeout  number := 300; --sec
  g_SELECT_LIST COREMOD_EXTPROC.t_columns;

  function get_shorten_sql_text(p_sql_id varchar2, p_length number default 0, p_show_tail number default 1) return varchar2 deterministic
  is
    PRAGMA UDF;
    l_res varchar2(4000);
  begin
    for i in (
      select t.file_contentc
      from OPAS_OT_SQL_DESCRIPTIONS s,
           opas_files t
      where s.sql_id=p_sql_id
        and nvl(s.sql_text,s.sql_text_approx) = t.file_id(+))
    loop
      l_res := get_shorten_sql_text_for_html_expose(i.file_contentc, p_length, 'N', p_show_tail);
    end loop;
    return l_res;
  end;

  function get_shorten_sql_text_for_html_expose(p_sql_text clob, p_length number default 0, p_replace_spec varchar2 default 'Y', p_show_tail number default 1) return clob deterministic
  is
    PRAGMA UDF;
    l_res clob;
  begin
    --dbms_lock.sleep(5);
    if p_sql_text is null then
      return 'N/A';
    end if;
    l_res :=case when p_length = 0 then p_sql_text
                 when dbms_lob.getlength(p_sql_text) <= p_length then p_sql_text
                 else
                   case when p_show_tail = 1 then substr(p_sql_text,1,round(p_length*2/3)-5)||' ... '||substr(p_sql_text,-1*round(p_length*2/3))
                        else substr(p_sql_text,1,p_length-3)||'...'
                   end
                 end;
    if p_replace_spec = 'Y' then
      return replace(replace(replace(l_res,'  ','&nbsp;'),chr(13)||chr(10),'<br>'),chr(10),'<br>');
    else
      return l_res;
    end if;
  end;

  procedure create_search_session(p_session_id out opas_ot_sql_searches.session_id%type,
                                  p_where varchar2) --I - internal registry, E - through dblink, B - both
  is
  begin
    insert into opas_ot_sql_searches
      (apex_sess, created, search_params, apex_user,
       local_status, remote_status)
    values
      (V('SESSION'), sysdate, empty_clob(), V('APP_USER'),
       case when p_where in (stInternal, stBoth) then ssInQueue else null end,
       case when p_where in (stExternal, stBoth) then ssInQueue else null end
       ) returning session_id into p_session_id;
    gCurrentSession := p_session_id;
    gParams.delete;
    gSearchMode:=p_where;
  end;

  function is_session_current(p_session_id opas_ot_sql_searches.session_id%type) return boolean
  is
  begin
    return nvl(gCurrentSession,0)=nvl(p_session_id,-1);
  end;

  procedure add_param(p_session_id opas_ot_sql_searches.session_id%type,
                      p_pname      varchar2,
                      p_value      varchar2)
  is
  begin
    if gCurrentSession = p_session_id then
      gParams(p_pname):=p_value;
    else
      raise_application_error(-20000,'Session ID mismatch current:specified '||gCurrentSession||':'||p_session_id);
    end if;
  end;

  procedure store_params(p_session_id opas_ot_sql_searches.session_id%type)
  is
    l_indx varchar2(100);
    pragma autonomous_transaction;
  begin
    APEX_JSON.initialize_clob_output;
    APEX_JSON.open_object;
    APEX_JSON.open_array('params');

    l_indx := gParams.first;
    loop
      if gParams(l_indx) is not null then
        APEX_JSON.open_object;
        APEX_JSON.write('param_name', l_indx);
        APEX_JSON.write('param_value', gParams(l_indx));
        APEX_JSON.close_object;
      end if;
      l_indx := gParams.next(l_indx);
      exit when l_indx is null;
    end loop;

    APEX_JSON.close_array;
    APEX_JSON.close_object;

    update opas_ot_sql_searches
       set search_params = APEX_JSON.get_clob_output
     where session_id = p_session_id;

    APEX_JSON.free_output;
    commit;
  end;


  procedure extract_params(p_session_id opas_ot_sql_searches.session_id%type)
  is
    l_json_text VARCHAR2(32767);
    l_count     PLS_INTEGER;
  begin
    select search_params into l_json_text from OPAS_OT_SQL_SEARCHES where session_id = p_session_id;
    gParams.delete;

    APEX_JSON.parse(l_json_text);
    l_count := APEX_JSON.get_count(p_path => 'params');

    FOR i IN 1 .. l_count LOOP
      gParams(APEX_JSON.get_varchar2(p_path => 'params[%d].param_name', p0 => i)) := APEX_JSON.get_varchar2(p_path => 'params[%d].param_value', p0 => i);
    END LOOP;
  end;

  procedure get_param(p_session_id opas_ot_sql_searches.session_id%type,
                      p_pname      varchar2,
                      p_value  out varchar2)
  is
  begin
    if COREOBJ_SQL_SEARCH.gParams.exists(p_pname) then
      p_value := COREOBJ_SQL_SEARCH.gParams(p_pname);
    else
      p_value := null;
    end if;
  end;

  procedure set_search_progress(p_session_id       opas_ot_sql_searches.session_id%type,
                                p_local_message    opas_ot_sql_searches.local_status%type default null,
                                p_remote_message   opas_ot_sql_searches.remote_status%type default null)
  is
    pragma autonomous_transaction;
  begin
    update opas_ot_sql_searches
       set local_status = nvl(p_local_message,local_status),
           remote_status = nvl(p_remote_message,remote_status)
     where session_id = p_session_id;
    commit;
  end;

  procedure start_search(p_session_id opas_ot_sql_searches.session_id%type,
                         p_notifyme   boolean default false)
  is
    l_tq_id      OPAS_TASK_QUEUE.tq_id%type;
    l_nt_id      opas_notification.ID%type;
  begin
    store_params(p_session_id);
    commit;
    if gSearchMode in (stInternal,stBoth) then
      l_tq_id:=COREMOD_TASKS.prep_execute_task (  P_TASKNAME => 'OPAS_SQL_LOCAL_SEARCH') ;
      if p_notifyme then
        COREMOD_ALERTS.add_notification (
          nt_id => l_nt_id,
          NT_TEXT => 'Local search session #'||p_session_id|| ' finished with '||COREMOD_ALERTS.ntPlaceHolder,
          --NT_LINK => 'f?p='||v('APP_ID')||':1411:<APP_SESSION>::::'||COREMOD_ALERTS.url_with_cleanup('P1411_MODE,P1411_SESSION', 'COMMON,'||p_session_id, l_nt_id),
          NT_TYPE_ID => COREMOD_ALERTS.nttTaskfinished,
          --NT_COLOR => NT_COLOR, --default
          NT_USERNAME => v('APP_USER'),
          --NT_NO_BROWSER_NOTIF_FLAG => NT_NO_BROWSER_NOTIF_FLAG, default
          NT_ACTIVATE => 0) ;

        COREMOD_ALERTS.set_url (  NT_ID => l_nt_id,
          --P_OBJ_ID => P_OBJ_ID,
          P_PAGE_ID => 1411,
          --P_PREV_PAGE => P_PREV_PAGE,
          P_ITEMS => 'P1411_MODE,P1411_SESSION',
          P_VALUES => 'COMMON,'||p_session_id) ;

        COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => COREMOD_TASKS.parNotifyMe, p_num_par => l_nt_id);
      end if;
      COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => 'B1', p_num_par => p_session_id);
      COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id ) ;
      commit;
    end if;
    if gSearchMode in (stExternal,stBoth) then
      l_tq_id:=COREMOD_TASKS.prep_execute_task (  P_TASKNAME => 'OPAS_SQL_EXTERNAL_SEARCH') ;
      if p_notifyme then
        COREMOD_ALERTS.add_notification (
          nt_id => l_nt_id,
          NT_TEXT => 'External search session #'||p_session_id|| ' finished with '||COREMOD_ALERTS.ntPlaceHolder,
          --NT_LINK => 'f?p='||v('APP_ID')||':1411:<APP_SESSION>::::'||COREMOD_ALERTS.url_with_cleanup('P1411_MODE,P1411_SESSION', 'COMMON,'||p_session_id, l_nt_id),
          NT_TYPE_ID => COREMOD_ALERTS.nttTaskfinished,
          --NT_COLOR => NT_COLOR, --default
          NT_USERNAME => v('APP_USER'),
          --NT_NO_BROWSER_NOTIF_FLAG => NT_NO_BROWSER_NOTIF_FLAG, default
          NT_ACTIVATE => 0) ;

        COREMOD_ALERTS.set_url (  NT_ID => l_nt_id,
          --P_OBJ_ID => P_OBJ_ID,
          P_PAGE_ID => 1411,
          --P_PREV_PAGE => P_PREV_PAGE,
          P_ITEMS => 'P1411_MODE,P1411_SESSION',
          P_VALUES => 'COMMON,'||p_session_id) ;

        COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => COREMOD_TASKS.parNotifyMe, p_num_par => l_nt_id);
      end if;
      COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => 'B1', p_num_par => p_session_id);
      COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id ) ;
      commit;
    end if;

    begin
      coremod_tasks.exec_coordinator;
    exception
      when others then null;
    end;
  end;

  procedure start_local_search(p_session_id opas_ot_sql_searches.session_id%type)
  is
    l_rows_found number;
    l_rows       number;
    l_sql varchar2(32765) := q'[      insert into opas_ot_sql_search_results
        (session_id,   search_source, sql_id, sql_text_local, sql_text_external,    created_by, first_discovered, first_discovered_at, txt_score)
      select
         :p_session_id, :p_source,    sql_id, nvl(sql_text, sql_text_approx), null, created_by, first_discovered, first_discovered_at, <SCORE>
      from opas_ot_sql_descriptions d <OPAS_FILES> where 1=1 ]' || chr(10);
    l_time timestamp := systimestamp;
    l_duration varchar2(100);
  begin
    coremod_log.log('COREOBJ_SQL_SEARCH.start_local_search: started for: '||p_session_id,'DEBUG');
    extract_params(p_session_id);
    --------------------------------
    set_search_progress(p_session_id => p_session_id, p_local_message => ssInProgress);
--driving table opas_files
--search among sql text
--another search among all files

    if gParams.exists('P1411_ROWS') and gParams('P1411_ROWS') is not null then
      l_rows := case when gParams('P1411_ROWS') > 1000 then 1000 else gParams('P1411_ROWS') end;
    else
      l_rows := 100;
    end if;

    if gParams.exists('P1411_CONTAINS') and gParams('P1411_CONTAINS') is not null then
      if gParams.exists('P1411_TEXT_SEARCH_OPTIONS') then
        if gParams('P1411_TEXT_SEARCH_OPTIONS') = 'ORATEXT' then
           l_sql := replace(l_sql, '<SCORE>', ' SCORE(1) score');
           l_sql := replace(l_sql, '<OPAS_FILES>', ', opas_files f');
           l_sql := l_sql || q'[ and f.file_type='SQL Text' and nvl(d.sql_text, d.sql_text_approx) = f.file_id and CONTAINS(f.file_contentc, q'~]' || replace(gParams('P1411_CONTAINS'),'_','\_') || q'[~', 1) > 0]';
        end if;
        if gParams('P1411_TEXT_SEARCH_OPTIONS') like '%REGEXP' then
           l_sql := replace(l_sql, '<OPAS_FILES>', ', opas_files f');
           l_sql := l_sql || q'[ and f.file_type='SQL Text' and nvl(d.sql_text, d.sql_text_approx) = f.file_id and regexp_like (f.file_contentc, q'~]' || gParams('P1411_CONTAINS') || q'[~', 'in')]';
        end if;
        if gParams('P1411_TEXT_SEARCH_OPTIONS') = 'NOTREGEXP' then
           l_sql := replace(l_sql,'and regexp_like','and not regexp_like');
        end if;
        if gParams('P1411_TEXT_SEARCH_OPTIONS') like '%LIKE' then
           l_sql := replace(l_sql, '<OPAS_FILES>', ', opas_files f');
           l_sql := l_sql || q'[ and f.file_type='SQL Text' and nvl(d.sql_text, d.sql_text_approx) = f.file_id and f.file_contentc like q'~]' || gParams('P1411_CONTAINS') || q'[~']';
        end if;
        if gParams('P1411_TEXT_SEARCH_OPTIONS') = 'NOTLIKE' then
           l_sql := replace(l_sql,'f.file_contentc like','file_contentc not like');
        end if;
        if gParams('P1411_TEXT_SEARCH_OPTIONS') like '%LIKECI' then
           l_sql := replace(l_sql, '<OPAS_FILES>', ', opas_files f');
           l_sql := l_sql || q'[ and f.file_type='SQL Text' and nvl(d.sql_text, d.sql_text_approx) = f.file_id and upper(f.file_contentc) like upper(q'~]' || gParams('P1411_CONTAINS') || q'[~')]';
        end if;
        if gParams('P1411_TEXT_SEARCH_OPTIONS') = 'NOTLIKECI' then
           l_sql := replace(l_sql,'upper(f.file_contentc) like','upper(f.file_contentc) not like');
        end if;
      end if;
    end if;
    l_sql := replace(l_sql, '<SCORE>', '0');
    l_sql := replace(l_sql, '<OPAS_FILES>');

    if gParams.exists('P1411_SQL_ID') and gParams('P1411_SQL_ID') is not null then
      l_sql := l_sql || q'[ and d.sql_id = ']' || gParams('P1411_SQL_ID') || q'[']' || chr(10);
    end if;

    if gParams.exists('P1411_PLAN_HASH') and gParams('P1411_PLAN_HASH') is not null then
      l_sql := l_sql || q'[ and d.sql_id in (select sql_id from opas_ot_sql_vsql where plan_hash_value = <PLAN_HASH> union
        select sql_id from opas_ot_sql_vash1        where plan_hash_value = <PLAN_HASH> union
        select sql_id from opas_ot_sql_vash2        where plan_hash_value = <PLAN_HASH> union
        select sql_id from opas_ot_sql_sqlmon m, opas_ot_sql_sqlmon_data da where m.sqlmon_id = da.sqlmon_id and sql_plan_hash_value = <PLAN_HASH> union
        select sql_id from opas_ot_sql_plan_det     where plan_hash_value = <PLAN_HASH> union
        select sql_id from opas_ot_sql_ep_plan_det  where sql_plan_hash_value = <PLAN_HASH> union
        select sql_id from opas_ot_sql_awr_sqlstat  where plan_hash_value = <PLAN_HASH> union
        select sql_id from opas_ot_sql_awr_plan_det where plan_hash_value = <PLAN_HASH> union
        select sql_id from opas_ot_sql_awr_ash_summ where sql_plan_hash_value = <PLAN_HASH> union
        select sql_id from opas_ot_sql_awr_ash_plst where sql_plan_hash_value = <PLAN_HASH>)]' || chr(10);
      l_sql := replace(l_sql,'<PLAN_HASH>',gParams('P1411_PLAN_HASH'));
    end if;

    if gParams.exists('P1411_MODULE') and gParams('P1411_MODULE') is not null then
      l_sql := l_sql || q'[ and d.sql_id in (select sql_id from OPAS_OT_SQL_AWR_ASH_SUMM where MODULE like '<MODULE>' union
        select sql_id from OPAS_OT_SQL_AWR_SQLSTAT where MODULE like '<MODULE>' union
        select sql_id from opas_ot_sql_sqlmon m, opas_ot_sql_sqlmon_data da where m.sqlmon_id = da.sqlmon_id and MODULE like '<MODULE>' union
        select sql_id from OPAS_OT_SQL_VSQL where MODULE like '<MODULE>')]' || chr(10); --'
      l_sql := replace(l_sql,'<MODULE>',gParams('P1411_MODULE'));
    end if;

    if gParams.exists('P1411_ACTION') and gParams('P1411_ACTION') is not null then
      l_sql := l_sql || q'[ and d.sql_id in (select sql_id from OPAS_OT_SQL_AWR_ASH_SUMM where ACTION like '<ACTION>' union
        select sql_id from OPAS_OT_SQL_AWR_SQLSTAT where ACTION like '<ACTION>' union
        select sql_id from opas_ot_sql_sqlmon m, opas_ot_sql_sqlmon_data da where m.sqlmon_id = da.sqlmon_id and ACTION like '<ACTION>' union
        select sql_id from OPAS_OT_SQL_VSQL where ACTION like '<ACTION>')]' || chr(10); --'
      l_sql := replace(l_sql,'<ACTION>',gParams('P1411_ACTION'));
    end if;

    if gParams.exists('P1411_LOCAL_SQL_EXPRESSION') and gParams('P1411_LOCAL_SQL_EXPRESSION') is not null then
      l_sql := l_sql || q'[ and d.sql_id in (]' || gParams('P1411_LOCAL_SQL_EXPRESSION') || q'[)]' || chr(10);
    end if;

    if gParams.exists('P1411_TAGS') and gParams('P1411_TAGS') is not null then
      if gParams.exists('P1411_HIERARCHY') and gParams('P1411_HIERARCHY') = 'N' then
        l_sql := l_sql || q'[ and d.sql_id in (select sql_id from opas_ot_sql_sql2tags where tag in (]' || coreobj_sql_tags.parse_tag_ist(p_tag_names => gParams('P1411_TAGS'),  p_delim => ',', p_enclosed => 'Y') || '))';
      else
        l_sql := l_sql || q'[ and d.sql_id in (select sql_id from opas_ot_sql_sql2tags where tag in (select tag_name from OPAS_OT_SQL_TAGS start with tag_name in (]' || coreobj_sql_tags.parse_tag_ist(p_tag_names => gParams('P1411_TAGS'),  p_delim => ',', p_enclosed => 'Y') || ') connect by prior tag_name = tag_prnt))';
      end if;
    end if;

    if gParams.exists('P1411_CREATED_BY') and gParams('P1411_CREATED_BY') is not null then
      l_sql := l_sql || q'[ and d.created_by like ']' || gParams('P1411_CREATED_BY') || q'[']' || chr(10);
    end if;

    -- the last one
    l_sql := l_sql || q'[ and rownum <= ]' || l_rows || chr(10);

    coremod_log.log('COREOBJ_SQL_SEARCH.start_local_search: '||l_sql,'INFO');--'DEBUG');

    execute immediate l_sql using p_session_id, stInternal;
    l_rows_found := sql%rowcount;

    select to_char(cast((systimestamp - l_time) AS INTERVAL DAY(2) TO SECOND(3))) into l_duration from dual;
    set_search_progress(p_session_id => p_session_id, p_local_message => 'Found: '||l_rows_found||' rows in '||l_duration);

    --------------------------------
    gCurrentSession := null;
    gParams.delete;

  exception
    when others then
      rollback;
      set_search_progress(p_session_id => p_session_id, p_local_message => 'Error');
      if l_sql is not null then coremod_tasks.log('Error COREOBJ_SQL_SEARCH.start_local_search ('||p_session_id||'): '||l_sql); end if;
      coremod_tasks.log('Error COREOBJ_SQL_SEARCH.start_local_search ('||p_session_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      raise_application_error(-20000, 'Error COREOBJ_SQL_SEARCH.start_local_search ('||p_session_id||'): '||sqlerrm);
  end;

  procedure start_external_search(p_session_id opas_ot_sql_searches.session_id%type)
  is
    l_rows_found number := 0;

    l_v2_sql varchar2(32765) := q'[      insert /*+ qb_name(OPAS60) */ into opas_ot_sql_search_results
        (session_id,    search_source, sql_id, sql_text_external, created_by,          first_discovered, first_discovered_at, txt_score)
      select /*+ qb_name(OPAS60) */
         :p_session_id, :p_source,     sql_id, sql_fulltext,      parsing_schema_name, sysdate,          '<DBLINKNM>/V$SQL',          0
      from gv$sql<DBLINK> d where (inst_id, child_number, sql_id) in
        (select inst_id, child_number, sql_id from (select inst_id, child_number, sql_id, row_number()over(partition by sql_id order by child_number) rn from gv$sql<DBLINK> where sql_id in (<SQL_ID_LIST>)) where rn = 1)]' || chr(10); --'

    l_v_sql varchar2(32765) := q'[select /*+ qb_name(OPAS60)  driving_site(d) */ unique sql_id from gv$sql<DBLINK> d where 1=1 ]' || chr(10); --'

    l_awr_sql varchar2(32765) := q'[select /*+ qb_name(OPAS60) driving_site(d) */ unique sql_id from dba_hist_sqltext<DBLINK> d where d.DBID = <DBID>]' || chr(10); --'

    l_awr2_sql varchar2(32765) := q'[insert /*+ qb_name(OPAS60) */ into opas_ot_sql_search_results
        (session_id,    search_source, sql_id, sql_text_external, created_by,  first_discovered, first_discovered_at, txt_score)
      select /*+ qb_name(OPAS60) */
         :p_session_id, :p_source,     sql_id, sql_text,          null,        sysdate,          '<DBLINKNM>/AWR',          0
      from dba_hist_sqltext<DBLINK> where sql_id in (<SQL_ID_LIST>)]' || chr(10); --'

    l_crsr        sys_refcursor;

    l_sql         varchar2(32765);
    l_sql_id      varchar2(100);
    l_sql_id_list varchar2(32765);
    l_counter     number;
    l_rows        number;
    l_time        timestamp := systimestamp;
    l_duration    varchar2(100);
    l_task        number;
    l_sql_fulltext clob;
    l_parsing_schema varchar2(512);
  begin
    coremod_log.log('COREOBJ_SQL_SEARCH.start_external_search: started for: '||p_session_id,'DEBUG');
    extract_params(p_session_id);
    --------------------------------

    if gParams.exists('P1411_ROWS') and gParams('P1411_ROWS') is not null then
      l_rows := case when gParams('P1411_ROWS') > 1000 then 1000 else gParams('P1411_ROWS') end;
    else
      l_rows := 100;
    end if;

    if gParams.exists('P1411_DATABASE') and gParams('P1411_DATABASE') is not null
    then
      set_search_progress(p_session_id => p_session_id, p_remote_message => ssInProgress);
--driving table opas_files
--search among sql text
--another search among all files
      if gParams.exists('P1411_EXT_SEARCH_OPT') and gParams('P1411_EXT_SEARCH_OPT') in ('VSQL','BOTH') then
        if gParams.exists('P1411_CONTAINS') and gParams('P1411_CONTAINS') is not null then
          if gParams.exists('P1411_TEXT_SEARCH_OPTIONS') then
            if gParams('P1411_TEXT_SEARCH_OPTIONS') like '%REGEXP' or gParams('P1411_TEXT_SEARCH_OPTIONS') = 'ORATEXT' then
               l_v_sql := l_v_sql || q'[ and regexp_like(d.sql_fulltext, q'~]' || gParams('P1411_CONTAINS') || q'[~', 'in')]';
            end if;
            if gParams('P1411_TEXT_SEARCH_OPTIONS') = 'NOTREGEXP' then
               l_v_sql := replace(l_v_sql,'and regexp_like','and not regexp_like');
            end if;
            if gParams('P1411_TEXT_SEARCH_OPTIONS') like '%LIKE' then
               l_v_sql := l_v_sql || q'[ and d.sql_fulltext like q'~]' || gParams('P1411_CONTAINS') || q'[~']';
            end if;
            if gParams('P1411_TEXT_SEARCH_OPTIONS') = 'NOTLIKE' then
               l_v_sql := replace(l_v_sql,'and d.sql_fulltext like','and d.sql_fulltext not like');
            end if;
            if gParams('P1411_TEXT_SEARCH_OPTIONS') like '%LIKECI' then
               l_v_sql := l_v_sql || q'[ and upper(d.sql_fulltext) like upper(q'~]' || gParams('P1411_CONTAINS') || q'[~')]';
            end if;
            if gParams('P1411_TEXT_SEARCH_OPTIONS') = 'NOTLIKECI' then
               l_v_sql := replace(l_v_sql,'and upper(d.sql_fulltext) like','and upper(d.sql_fulltext) not like');
            end if;
          end if;
        end if;

        if gParams.exists('P1411_SQL_ID') and gParams('P1411_SQL_ID') is not null then
          l_v_sql := l_v_sql || q'[ and d.sql_id = q'~]' || gParams('P1411_SQL_ID') || q'[~']' || chr(10);
        end if;

        if gParams.exists('P1411_PLAN_HASH') and gParams('P1411_PLAN_HASH') is not null then
          l_v_sql := l_v_sql || q'[ and d.plan_hash_value = <PLAN_HASH>]' || chr(10);
          l_v_sql := replace(l_v_sql,'<PLAN_HASH>',gParams('P1411_PLAN_HASH'));
        end if;

        if gParams.exists('P1411_MODULE') and gParams('P1411_MODULE') is not null then
          l_v_sql := l_v_sql || q'[ and d.MODULE like q'~<MODULE>~']' || chr(10); --'
          l_v_sql := replace(l_v_sql,'<MODULE>',gParams('P1411_MODULE'));
        end if;

        if gParams.exists('P1411_ACTION') and gParams('P1411_ACTION') is not null then
          l_v_sql := l_v_sql || q'[ and d.ACTION like q'~<ACTION>~']' || chr(10); --'
          l_v_sql := replace(l_v_sql,'<ACTION>',gParams('P1411_ACTION'));
        end if;

        if gParams.exists('P1411_EXTERNAL_SQL_EXPRESSION') and gParams('P1411_EXTERNAL_SQL_EXPRESSION') is not null then
          l_v_sql := l_v_sql || q'[ and d.sql_id in (]' || gParams('P1411_EXTERNAL_SQL_EXPRESSION') || q'[)]' || chr(10);
        end if;

        -- the last one
        l_v_sql := l_v_sql || q'[ and rownum <= ]' || l_rows || chr(10);

        if COREMOD_API.external_mode_dblink(gParams('P1411_DATABASE')) then
          l_v_sql := replace(l_v_sql,'<DBLINK>',COREMOD_API.get_dblink_for_query(gParams('P1411_DATABASE')));
          l_v_sql := replace(l_v_sql,'<DBLINKNM>',gParams('P1411_DATABASE'));

          coremod_log.log('COREOBJ_SQL_SEARCH.start_external_search v$sql: '||l_v_sql,'DEBUG');

          l_counter := 0;
          l_sql_id_list := null;
          l_sql := l_v_sql;

          open l_crsr for l_sql;
          loop
            fetch l_crsr into l_sql_id;
            exit when l_crsr%notfound;
            l_counter := l_counter + 1;
            l_sql_id_list := l_sql_id_list || q'[']' || l_sql_id || q'[',]';
          end loop;
          close l_crsr;

          if l_counter > 0 then
            l_v2_sql := replace(l_v2_sql,'<DBLINK>',COREMOD_API.get_dblink_for_query(gParams('P1411_DATABASE')));
            l_v2_sql := replace(l_v2_sql,'<DBLINKNM>',gParams('P1411_DATABASE'));

            l_v2_sql := replace(l_v2_sql,'<SQL_ID_LIST>',rtrim(l_sql_id_list,','));
            coremod_log.log('COREOBJ_SQL_SEARCH.start_external_search v$sql2: '||l_v2_sql,'DEBUG');

            l_sql := l_v2_sql;
            execute immediate l_sql using p_session_id, stExternal;

            l_rows_found := sql%rowcount;
          else
            l_rows_found := 0;
          end if;
        elsif COREMOD_API.external_mode_javasrv(gParams('P1411_DATABASE')) then
          delete from OPAS_OT_TMP_REC_SQL_IDS;
          COREMOD_EXTPROC.load_external_data (  P_TARGET_TABLE => 'OPAS_OT_TMP_REC_SQL_IDS',
            P_SELECT_LIST => g_SELECT_LIST, --empty
            P_SQL_BODY =>    '('||l_v_sql||')',
            P_DBLINK =>      gParams('P1411_DATABASE'),
            P_PRIORITY =>    g_qry_priority,
            P_TIMEOUT =>     g_qry_timeout) ;

          for i in ( select SQL_ID from OPAS_OT_TMP_REC_SQL_IDS ) loop
            l_task := COREMOD_EXTPROC.create_plsql_task(P_PLSQL_BODY =>
      q'[declare a clob := null; l_sch varchar2(512);
         begin
           begin select sql_fulltext, parsing_schema_name into a, l_sch from gv$sql where SQL_ID=:P_SQL_ID and rownum=1; exception when others then null; end;
           :l_out := a; :l_psch := l_sch;
         end;]',
                                                        P_DBLINK => gParams('P1411_DATABASE'),
                                                        P_PRIORITY => g_qry_priority);

            COREMOD_EXTPROC.add_param (  P_TASK_ID => l_task, P_IO_TYPE => 'IN', P_ORDR_NUM => 1, p_varchar2 => i.SQL_ID ) ;
            COREMOD_EXTPROC.add_param (  P_TASK_ID => l_task, P_IO_TYPE => 'OUT', P_ORDR_NUM => 2, p_clob => null ) ;
            COREMOD_EXTPROC.add_param (  P_TASK_ID => l_task, P_IO_TYPE => 'OUT', P_ORDR_NUM => 3, p_varchar2 => null ) ;
            COREMOD_EXTPROC.execute_plsql_task (  P_TASK_ID => l_task, P_TIMEOUT => g_qry_timeout) ;
            COREMOD_EXTPROC.get_param (  P_TASK_ID => l_task, P_ORDR_NUM => 2, p_clob => l_sql_fulltext) ;
            COREMOD_EXTPROC.get_param (  P_TASK_ID => l_task, P_ORDR_NUM => 3, p_varchar2 => l_parsing_schema) ;

            insert /*+ qb_name(OPAS60) */ into opas_ot_sql_search_results
             (session_id,    search_source, sql_id, sql_text_external, created_by,          first_discovered, first_discovered_at, txt_score)
            select /*+ qb_name(OPAS60) */
             p_session_id, stExternal,   i.SQL_ID, l_sql_fulltext,      l_parsing_schema, sysdate,          gParams('P1411_DATABASE')||'/V$SQL',          0 from dual;
            l_rows_found := l_rows_found + 1;
          end loop;

        end if;
      end if;
--====================================================================================================

      if gParams.exists('P1411_EXT_SEARCH_OPT') and gParams('P1411_EXT_SEARCH_OPT') in ('AWR','BOTH') and
        l_rows - l_rows_found > 0
      then
        if gParams.exists('P1411_CONTAINS') and gParams('P1411_CONTAINS') is not null then
          if gParams.exists('P1411_TEXT_SEARCH_OPTIONS') then
            if gParams('P1411_TEXT_SEARCH_OPTIONS') like '%REGEXP' or gParams('P1411_TEXT_SEARCH_OPTIONS') = 'ORATEXT' then
               l_awr_sql := l_awr_sql || q'[ and regexp_like(d.sql_text, q'~]' || gParams('P1411_CONTAINS') || q'[~', 'in')]';
            end if;
            if gParams('P1411_TEXT_SEARCH_OPTIONS') = 'NOTREGEXP' then
               l_awr_sql := replace(l_awr_sql,'and regexp_like','and not regexp_like');
            end if;
            if gParams('P1411_TEXT_SEARCH_OPTIONS') like '%LIKE' then
               l_awr_sql := l_awr_sql || q'[ and d.sql_text like q'~]' || gParams('P1411_CONTAINS') || q'[~']';
            end if;
            if gParams('P1411_TEXT_SEARCH_OPTIONS') = 'NOTLIKE' then
               l_awr_sql := replace(l_awr_sql,'and d.sql_text like','and d.sql_text not like');
            end if;
          end if;
        end if;

        if gParams.exists('P1411_SQL_ID') and gParams('P1411_SQL_ID') is not null then
          l_awr_sql := l_awr_sql || q'[ and d.sql_id = q'~]' || gParams('P1411_SQL_ID') || q'[~']' || chr(10);
        end if;

        if (gParams.exists('P1411_PLAN_HASH') and gParams('P1411_PLAN_HASH') is not null) or
           (gParams.exists('P1411_MODULE') and gParams('P1411_MODULE') is not null) or
           (gParams.exists('P1411_ACTION') and gParams('P1411_ACTION') is not null)
        then
          l_sql := q'[ and d.sql_id in (select sql_id from dba_hist_sqlstat<DBLINK> s where 1=1 <PLAN_HASH> <MODULE> <ACTION> and s.INSTANCE_NUMBER > 0 and s.DBID = <DBID>)]' || chr(10);

          if gParams.exists('P1411_PLAN_HASH') and gParams('P1411_PLAN_HASH') is not null then
            l_sql := replace(l_sql,'<PLAN_HASH>',q'[ and s.plan_hash_value = ]' || gParams('P1411_PLAN_HASH'));
          else
            l_sql := replace(l_sql,'<PLAN_HASH>');
          end if;

          if gParams.exists('P1411_MODULE') and gParams('P1411_MODULE') is not null then
            l_sql := replace(l_sql,'<MODULE>',q'[ and s.MODULE like q'~]' || gParams('P1411_MODULE') || q'[~']');
          else
            l_sql := replace(l_sql,'<MODULE>');
          end if;

          if gParams.exists('P1411_ACTION') and gParams('P1411_ACTION') is not null then
            l_sql := replace(l_sql,'<ACTION>',q'[ and s.ACTION like q'~]' || gParams('P1411_ACTION') || q'[~']');
          else
            l_sql := replace(l_sql,'<ACTION>');
          end if;

          l_awr_sql := l_awr_sql || l_sql;
        end if;

        if gParams.exists('P1411_EXTERNAL_SQL_EXPRESSION') and gParams('P1411_EXTERNAL_SQL_EXPRESSION') is not null then
          l_awr_sql := l_awr_sql || q'[ and d.sql_id in (]' || gParams('P1411_EXTERNAL_SQL_EXPRESSION') || q'[)]' || chr(10);
        end if;

        -- the last one
        l_awr_sql := l_awr_sql || q'[ and rownum <= ]' || to_char( l_rows - l_rows_found ) || chr(10);
        l_awr_sql := replace(l_awr_sql,'<DBID>',coremod_api.get_dblink_dbid(gParams('P1411_DATABASE')));

        if COREMOD_API.external_mode_dblink(gParams('P1411_DATABASE')) then
          l_awr_sql := replace(l_awr_sql,'<DBLINK>',COREMOD_API.get_dblink_for_query(gParams('P1411_DATABASE')));
          l_awr_sql := replace(l_awr_sql,'<DBLINKNM>',gParams('P1411_DATABASE'));

          coremod_log.log('COREOBJ_SQL_SEARCH.start_external_search awr: '||l_awr_sql,'DEBUG');

          l_counter := 0;
          l_sql_id_list := null;
          l_sql := l_awr_sql;

          open l_crsr for l_sql;
          --open l_crsr for select SQL_ID from OPAS_OT_TMP_REC_SQL_IDS;
          loop
            fetch l_crsr into l_sql_id;
            exit when l_crsr%notfound;
            l_counter := l_counter + 1;
            l_sql_id_list := l_sql_id_list || q'[']' || l_sql_id || q'[',]';
          end loop;
          close l_crsr;

          if l_counter > 0 then
            l_awr2_sql := replace(l_awr2_sql,'<DBLINK>',COREMOD_API.get_dblink_for_query(gParams('P1411_DATABASE')));
            l_awr2_sql := replace(l_awr2_sql,'<DBLINKNM>',gParams('P1411_DATABASE'));

            l_awr2_sql := replace(l_awr2_sql,'<SQL_ID_LIST>',rtrim(l_sql_id_list,','));
            coremod_log.log('COREOBJ_SQL_SEARCH.start_external_search awr2: '||l_awr2_sql,'DEBUG');

            l_sql := l_awr2_sql;
            execute immediate l_sql using p_session_id, stExternal;

            l_rows_found := sql%rowcount + l_rows_found;
          else
            l_rows_found := l_rows_found;
          end if;
        elsif COREMOD_API.external_mode_javasrv(gParams('P1411_DATABASE')) then
          delete from OPAS_OT_TMP_REC_SQL_IDS;
          COREMOD_EXTPROC.load_external_data (  P_TARGET_TABLE => 'OPAS_OT_TMP_REC_SQL_IDS',
            P_SELECT_LIST => g_SELECT_LIST, --empty
            P_SQL_BODY =>    '('||l_awr_sql||')',
            P_DBLINK =>      gParams('P1411_DATABASE'),
            P_PRIORITY =>    g_qry_priority,
            P_TIMEOUT =>     g_qry_timeout) ;

          for i in ( select SQL_ID from OPAS_OT_TMP_REC_SQL_IDS ) loop
            l_task := COREMOD_EXTPROC.create_plsql_task(P_PLSQL_BODY =>
      q'[declare a clob := null;
         begin
           begin select sql_text into a from dba_hist_sqltext where SQL_ID=:P_SQL_ID and rownum=1; exception when others then null; end;
           :l_out := a;
         end;]',
                                                        P_DBLINK => gParams('P1411_DATABASE'),
                                                        P_PRIORITY => g_qry_priority);

            COREMOD_EXTPROC.add_param (  P_TASK_ID => l_task, P_IO_TYPE => 'IN', P_ORDR_NUM => 1, p_varchar2 => i.SQL_ID ) ;
            COREMOD_EXTPROC.add_param (  P_TASK_ID => l_task, P_IO_TYPE => 'OUT', P_ORDR_NUM => 2, p_clob => null ) ;
            --COREMOD_EXTPROC.add_param (  P_TASK_ID => l_task, P_IO_TYPE => 'OUT', P_ORDR_NUM => 3, p_varchar2 => null ) ;
            COREMOD_EXTPROC.execute_plsql_task (  P_TASK_ID => l_task, P_TIMEOUT => g_qry_timeout) ;
            COREMOD_EXTPROC.get_param (  P_TASK_ID => l_task, P_ORDR_NUM => 2, p_clob => l_sql_fulltext) ;
            --COREMOD_EXTPROC.get_param (  P_TASK_ID => l_task, P_ORDR_NUM => 3, p_varchar2 => l_parsing_schema) ;

            insert /*+ qb_name(OPAS60) */ into opas_ot_sql_search_results
             (session_id,    search_source, sql_id, sql_text_external, created_by,          first_discovered, first_discovered_at, txt_score)
            select /*+ qb_name(OPAS60) */
             p_session_id, stExternal,   i.SQL_ID, l_sql_fulltext,      null, sysdate,          gParams('P1411_DATABASE')||'/V$SQL',          0 from dual;
            l_rows_found := l_rows_found + 1;
          end loop;
        end if;
      end if;

      delete from opas_ot_sql_search_results where session_id = p_session_id and sql_text_external like '%OPAS60%';
      l_rows_found := l_rows_found - sql%rowcount;

      select to_char(cast((systimestamp - l_time) AS INTERVAL DAY(2) TO SECOND(3))) into l_duration from dual;
      set_search_progress(p_session_id => p_session_id,
                          p_remote_message => 'Found: '||l_rows_found||' rows in '|| l_duration);

    end if;
    --------------------------------
    gCurrentSession := null;
    gParams.delete;

    commit;
  exception
    when others then
      rollback;
      if l_crsr%isopen then close l_crsr; end if;
      set_search_progress(p_session_id => p_session_id, p_remote_message => 'Error');
      if l_sql is not null then coremod_tasks.log('Error COREOBJ_SQL_SEARCH.start_external_search ('||p_session_id||'): '||l_sql); end if;
      coremod_tasks.log('Error COREOBJ_SQL_SEARCH.start_external_search ('||p_session_id||'): '||sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      raise_application_error(-20000, 'Error COREOBJ_SQL_SEARCH.start_external_search ('||p_session_id||'): '||sqlerrm);
  end;

  procedure cleanup_sessions
  is
  begin
    delete opas_ot_sql_searches
          where created <
            case when retention is null
              then sysdate - to_number(COREMOD_API.getconf('SQLSEARCHRETENTION'))/24/60
              else sysdate - retention end;
    commit;
  end;

  procedure preserve_session(p_session_id opas_ot_sql_searches.session_id%type,
                             p_days       number)
  is
  begin
    update opas_ot_sql_searches
       set retention = p_days
     where session_id = p_session_id;
  end;
END COREOBJ_SQL_SEARCH;
/


