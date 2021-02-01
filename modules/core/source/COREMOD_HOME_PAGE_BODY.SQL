

CREATE OR REPLACE
PACKAGE BODY COREMOD_HOME_PAGE AS

  procedure modify_brief(p_name      OPAS_HOMEPAGE_BRIEFS.NAME%type,
                         p_qry_text  OPAS_HOMEPAGE_BRIEFS.QRY_TEXT%type,
                         p_ordr      OPAS_HOMEPAGE_BRIEFS.ORDR%type,
                         p_br_id in out OPAS_HOMEPAGE_BRIEFS.BR_ID%type) AS
    l_cnt number;
  BEGIN
    select count(1) into l_cnt from OPAS_HOMEPAGE_BRIEFS  where br_id = p_br_id;
    if l_cnt=1 then
      update opas_homepage_briefs t set
        t.name = p_name,
        t.qry_text = p_qry_text,
        t.ordr = p_ordr
       where br_id = p_br_id;
    else
      insert INTO opas_homepage_briefs (name, qry_text, created, ordr)
      values (p_name, p_qry_text, systimestamp, p_ordr) returning br_id into p_br_id;
    end if;
  END modify_brief;

  procedure drop_brief(p_br_id OPAS_HOMEPAGE_BRIEFS.BR_ID%type) AS
  BEGIN
    delete from opas_homepage_briefs where br_id = p_br_id;
  END drop_brief;

  function sql_qry_brief return varchar2 AS
    l_sql varchar2(32765) := q'[select ordr||'. '||name name, message, rn+(1000*ordr) ordr, limit from (<QRY>) order by rn+(1000*ordr)]';
    l_inner_sql varchar2(32765);
    l_brief varchar2(32765);
  BEGIN
    for i in (select * from opas_homepage_briefs order by ordr) loop
      execute immediate 'begin :res:='||i.QRY_TEXT||'; end;' using out l_brief;
      if l_inner_sql is null then
        l_inner_sql := l_brief;
      else
        l_inner_sql := l_inner_sql || ' union all ' || l_brief;
      end if;
      l_inner_sql := replace(replace(l_inner_sql,'<NAME>',i.NAME),'<ORDR>',i.ORDR);
    end loop;

    if l_inner_sql is null then
      l_inner_sql := q'[select 1 rn, 'Test name' name, 'Test message' message, 1 ordr, 0 limit from dual]';
    end if;

    RETURN replace(l_sql,'<QRY>',l_inner_sql);
  END sql_qry_brief;

END COREMOD_HOME_PAGE;
/


