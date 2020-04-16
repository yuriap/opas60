CREATE OR REPLACE
package body coreobj_sql_tags is

  procedure add(p_tag_name opas_ot_sql_tags.tag_name%type,
                p_tag_prnt opas_ot_sql_tags.tag_prnt%type,
                p_tag_description opas_ot_sql_tags.tag_description%type,
                p_tag_autoexpr opas_ot_sql_tags.tag_autoexpr%type)
  is
  begin
    merge into opas_ot_sql_tags t
    using (select p_tag_name tag_name, p_tag_prnt tag_prnt, p_tag_description tag_description, p_tag_autoexpr tag_autoexpr from dual) s
    on (t.tag_name=s.tag_name)
    when matched then update set
      t.tag_description = s.tag_description,
      t.tag_autoexpr = s.tag_autoexpr
    when not matched then insert (t.tag_name, t.tag_prnt, t.tag_description, t.tag_autoexpr)
    values
    (s.tag_name, s.tag_prnt, s.tag_description, s.tag_autoexpr);

  end;

  procedure edit(p_tag_name opas_ot_sql_tags.tag_name%type,
                 p_tag_description opas_ot_sql_tags.tag_description%type,
                 p_tag_autoexpr opas_ot_sql_tags.tag_autoexpr%type)
  is
  begin
    null;
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
      insert into opas_ot_sql_sql2tags
        (sql_id, tag)
      values
        (p_sql_id, l_tag);
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
    loop
      l_cnt := l_cnt + 1;
      if instr(l_names,':')>0 then
        l_tag := substr(l_names,1,instr(l_names,':')-1);
      else
        l_tag := l_names;
      end if;

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

  procedure test_tag_expr(p_tag_name opas_ot_sql_tags.tag_name%type)
  is
  begin
    null;
  end;

  procedure auto_tag_sql(p_sql_id    opas_ot_sql_descriptions.sql_id%type)
  is
    l_sql_id opas_ot_sql_descriptions.sql_id%type;
    l_crsr   sys_refcursor;
  begin
    --coremod_log.log('coreobj_sql_tags.tag_sql: '||p_tag_names||' -- ' || p_sql_id);

    for i in (select * from opas_ot_sql_tags where tag_autoexpr is not null)
    loop
      open l_crsr for
        q'[select sql_id from opas_ot_sql_descriptions s, opas_files f where s.sql_id = :sqlid and s.sql_text = f.file_id and (]'||i.tag_autoexpr||')' using p_sql_id;
      fetch l_crsr into l_sql_id;
      if l_crsr%found then
        insert into opas_ot_sql_sql2tags
          (sql_id, tag)
        values
          (p_sql_id, i.tag_name);
      end if;
      close l_crsr;
    end loop;
  end;
end coreobj_sql_tags;
/
