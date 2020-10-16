

CREATE OR REPLACE
package body coreobj_sql_tags is

  gTagListTable tableofstrings;

  procedure add(p_tag_name opas_ot_sql_tags.tag_name%type,
                p_tag_prnt opas_ot_sql_tags.tag_prnt%type,
                p_tag_description opas_ot_sql_tags.tag_description%type,
                p_tag_autoexpr opas_ot_sql_tags.tag_autoexpr%type,
                p_tag_dependent opas_ot_sql_tags.tag_dependent%type)
  is
  begin
    merge into opas_ot_sql_tags t
    using (select p_tag_name tag_name, p_tag_prnt tag_prnt, p_tag_description tag_description, p_tag_autoexpr tag_autoexpr, p_tag_dependent tag_dependent from dual) s
    on (t.tag_name=s.tag_name)
    when matched then update set
      t.tag_description = s.tag_description,
      t.tag_autoexpr = s.tag_autoexpr,
      t.tag_dependent = s.tag_dependent,
      t.tag_modified = systimestamp
    when not matched then insert (t.tag_name, t.tag_prnt, t.tag_description, t.tag_autoexpr, t.tag_dependent)
    values
    (s.tag_name, s.tag_prnt, s.tag_description, s.tag_autoexpr, s.tag_dependent);

  end;

  procedure remove(p_tag_name opas_ot_sql_tags.tag_name%type,
                   p_tag_type opas_ot_sql_sql2tags.tag_type%type default '%')
  is
  begin
    remove_tag_from_sqls(p_tag_name, p_tag_type);
    delete from opas_ot_sql_tags where tag_name = p_tag_name;
  end;

  procedure remove_tag_from_sqls(p_tag_name opas_ot_sql_tags.tag_name%type,
                                 p_tag_type opas_ot_sql_sql2tags.tag_type%type default 'A')
  is
  begin
    delete from opas_ot_sql_sql2tags where tag = p_tag_name and tag_type like p_tag_type;
  end;

  procedure tag_sql(p_tag_names varchar2,
                    p_sql_id    opas_ot_sql_descriptions.sql_id%type)
  is
    l_tag opas_ot_sql_tags.tag_name%type;
    l_names varchar2(32765) := p_tag_names ||':';
    l_cnt   number := 0;
  begin
    --coremod_log.log('coreobj_sql_tags.tag_sql: '||p_tag_names||' -- ' || p_sql_id);

    delete from opas_ot_sql_sql2tags where sql_id = p_sql_id;
    loop
      l_cnt := l_cnt + 1;
      if instr(l_names,':')>0 then
        l_tag := substr(l_names,1,instr(l_names,':')-1);
      else
        l_tag := l_names;
      end if;
      --coremod_log.log('coreobj_sql_tags.tag_sql: '||l_cnt||' -- '||l_tag);
      if l_tag is not null then
        insert into opas_ot_sql_sql2tags
          (sql_id, tag, tag_type)
        values
          (p_sql_id, l_tag, 'M');
      end if;
      l_names := substr(l_names,instr(l_names,':')+1);
      --coremod_log.log('coreobj_sql_tags.tag_sql: '||l_names);
      exit when l_names is null; -- or l_cnt > 10;
    end loop;
  end;

  function  tags(p_sql_id opas_ot_sql_descriptions.sql_id%type,
                 p_for_apex_ctrl varchar2 default 'N') return varchar2
  is
    l_tags varchar2(32765);
  begin
    for i in (select tag from opas_ot_sql_sql2tags where sql_id = p_sql_id) loop
      if p_for_apex_ctrl = 'Y' then
        l_tags := l_tags || i.tag ||':';
      else
        l_tags := l_tags || i.tag ||'; ';
      end if;
    end loop;
    l_tags := rtrim(rtrim(l_tags,':'),'; ');
    return substr(l_tags, 1, 4000);
  end;

  function parse_tag_ist(p_tag_names varchar2,
                         p_delim     varchar2 default ',',
                         p_enclosed  varchar2 default 'Y') return varchar2
  is
    l_tag opas_ot_sql_tags.tag_name%type;
    l_names varchar2(32765) := p_tag_names ||':';
    l_cnt   number := 0;
    l_parsed varchar2(32765);
  begin
    gTagListTable.delete;
    loop
      l_cnt := l_cnt + 1;
      if instr(l_names,':')>0 then
        l_tag := substr(l_names,1,instr(l_names,':')-1);
      else
        l_tag := l_names;
      end if;

      gTagListTable.extend;
      gTagListTable(gTagListTable.count):=l_tag;

      l_parsed := l_parsed ||
                  case when p_enclosed = 'Y' then q'[']' end ||
                  l_tag ||
                  case when p_enclosed = 'Y' then q'[']' end ||
                  p_delim;

      l_names := substr(l_names,instr(l_names,':')+1);

      exit when l_names is null; -- or l_cnt > 10;
    end loop;
    return rtrim(l_parsed,p_delim);
  end;

  function parse_tag_list(p_tag_names varchar2) return tableofstrings
  is
    l_parsed varchar2(32765);
  begin
    l_parsed := parse_tag_ist(p_tag_names);
    return gTagListTable;
  end;

  procedure auto_tag_sql(p_sql_id    opas_ot_sql_descriptions.sql_id%type)
  is
    l_sql_id opas_ot_sql_descriptions.sql_id%type;
    l_crsr   sys_refcursor;
  begin
    --coremod_log.log('coreobj_sql_tags.tag_sql: '||p_tag_names||' -- ' || p_sql_id);

    for i in (select * from opas_ot_sql_tags where tag_autoexpr is not null and tag_name not like '%!Copy!' and tag_name not like '%1=2%')
    loop
      begin
        open l_crsr for
          q'[select sql_id from opas_ot_sql_descriptions s, opas_files f
where s.sql_id = :sqlid and (s.sql_text = f.file_id or s.sql_text_approx = f.file_id) and (]'||i.tag_autoexpr||')' using p_sql_id;
        fetch l_crsr into l_sql_id;
        if l_crsr%found then
          insert into opas_ot_sql_sql2tags
            (sql_id, tag, tag_type)
          values
            (p_sql_id, i.tag_name, 'A');
        end if;
        close l_crsr;
      exception
        when others then
          if l_crsr%isopen then close l_crsr; end if;
      end;
    end loop;
  end;

  procedure tag_all_sqls
  is
  begin
    for i in (select sql_id from opas_ot_sql_descriptions s where sql_text is not null or sql_text_approx is not null) loop
      auto_tag_sql(i.sql_id);
      commit;
    end loop;
  end;

  procedure auto_tag_sql_task(p_tag_name opas_ot_sql_tags.tag_name%type)
  is
    l_sql_id opas_ot_sql_descriptions.sql_id%type;
    l_crsr   sys_refcursor;
  begin
    --coremod_log.log('coreobj_sql_tags.tag_sql: '||p_tag_names||' -- ' || p_sql_id);

    for i in (select * from opas_ot_sql_tags where tag_name = p_tag_name and tag_name not like '%!Copy!' and tag_autoexpr not like '%1=2%' order by tag_dependent)
    loop
      open l_crsr for
        q'[select sql_id from opas_ot_sql_descriptions s, opas_files f where (s.sql_text = f.file_id or s.sql_text_approx = f.file_id) and (]'||i.tag_autoexpr||')';
      loop
        fetch l_crsr into l_sql_id;
        exit when l_crsr%notfound;

        merge into opas_ot_sql_sql2tags t
        using (select l_sql_id sql_id, p_tag_name tag from dual) s
        on (s.sql_id = t.sql_id and s.tag = t.tag)
        when not matched then insert (t.sql_id, t.tag, t.tag_type) values (s.sql_id, s.tag, 'A');

      end loop;
      close l_crsr;
    end loop;
  end;

  procedure start_auto_tag_sql_task(p_tag_name opas_ot_sql_tags.tag_name%type,
                                    p_notifyme         boolean default false)
    is
    l_tq_id      OPAS_TASK_QUEUE.tq_id%type;
    l_nt_id      opas_notification.ID%type;
  begin
    l_tq_id:=COREMOD_TASKS.prep_execute_task (  P_TASKNAME => 'OPAS_SQL_TAGSQL') ;
    COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => 'B1', p_varchar_par => p_tag_name);

      if p_notifyme then

        COREMOD_ALERTS.add_notification (
          nt_id => l_nt_id,
          NT_TEXT => 'Tagging finished for "'||p_tag_name|| '" with '||COREMOD_ALERTS.ntPlaceHolder,
          --NT_LINK => COREMOD_ALERTS.create_url(), 'f?p='||v('APP_ID')||':1401:<APP_SESSION>::::APP_OBJ_ID,APP_PREV_PAGE:'||l_obj_id||',10',
          NT_TYPE_ID => COREMOD_ALERTS.nttTaskfinished,
          --NT_COLOR => NT_COLOR, --default
          NT_USERNAME => v('APP_USER'),
          --NT_NO_BROWSER_NOTIF_FLAG => NT_NO_BROWSER_NOTIF_FLAG, default
          NT_ACTIVATE => 0) ;

        COREMOD_TASKS.set_task_param( p_tq_id => l_tq_id, p_name => COREMOD_TASKS.parNotifyMe, p_num_par => l_nt_id);
      end if;

    COREMOD_TASKS.queue_task ( p_tq_id => l_tq_id ) ;
  end;

  procedure tag_sql_by_expr(p_tag_name opas_ot_sql_tags.tag_name%type,
                            p_expr     varchar2)
  is
    l_sql_id opas_ot_sql_descriptions.sql_id%type;
    l_crsr   sys_refcursor;
  begin
    --coremod_log.log('coreobj_sql_tags.tag_sql: '||p_tag_names||' -- ' || p_sql_id);

    for i in (select * from opas_ot_sql_tags where tag_name = p_tag_name and tag_name not like '%!Copy!' and tag_name not like '%1=2%' order by tag_dependent)
    loop
      open l_crsr for
        q'[select sql_id from opas_ot_sql_descriptions s, opas_files f where (s.sql_text = f.file_id or s.sql_text_approx = f.file_id) and (]'||p_expr||')';
      loop
        fetch l_crsr into l_sql_id;
        exit when l_crsr%notfound;

        merge into opas_ot_sql_sql2tags t
        using (select l_sql_id sql_id, p_tag_name tag from dual) s
        on (s.sql_id = t.sql_id and s.tag = t.tag)
        when not matched then insert (t.sql_id, t.tag, t.tag_type) values (s.sql_id, s.tag, 'M');

      end loop;
      close l_crsr;
    end loop;
  end;

begin
  gTagListTable := tableofstrings();
end coreobj_sql_tags;
/


