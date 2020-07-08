CREATE OR REPLACE
package body COREOBJ_SQL_COMP_REPORT is

  g_plan_sections_all COREMOD_REPORT_UTILS.t_arrayofstrings :=
                         COREMOD_REPORT_UTILS.t_arrayofstrings('SQL_ID',
                                                             'Plan hash value:',
                                                             'Query Block Name / Object Alias',
                                                             'Outline Data',
                                                             'Remote SQL Information',
                                                             'Peeked Binds',
                                                             'Note',
                                                             'Column Projection Information',
                                                             'Predicate Information',
                                                             'Query Block Registry',
                                                             'Hint Report');
  --g_params COREMOD_REPORT_UTILS.t_params;

  g_SectNum number;

  function ifiamcalledfromcompreport return boolean
  is
    l_result number;
  begin
    select count(1) into l_result from opas_objects where obj_id = v('APP_OBJ_ID') and obj_ot = COREOBJ_API.otSQL_COMPARISON;
    if l_result>0 then
      coreobj_api.extract_jparams(p_obj_id => v('APP_OBJ_ID'));
      return true;
    else
      return false;
    end if;
  end;

  function getparamforcaller_n(p_name varchar2) return number
  is
    l_result number;
  begin
    coreobj_api.get_jparam(p_obj_id => v('APP_OBJ_ID'),
                           p_pname => p_name,
                           p_value => l_result);
    return l_result;
  end;

  procedure setsectnum(p_num number) is begin g_SectNum := p_num; end;
  function getsectnum return number is begin return g_SectNum; end;

  procedure add   (p_obj_id       out opas_objects.obj_id%type,
                   p_obj_prnt         opas_objects.obj_prnt%type,
                   p_modname          opas_files.modname%type default COREMOD_API.gMODNAME,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_name             opas_objects.obj_name%type default null,
                   p_descr            opas_objects.obj_descr%type default null)
  is
  begin
    COREOBJ_API.add (  P_OBJ_ID => P_OBJ_ID,
      P_OBJ_PRNT  => P_OBJ_PRNT,
      P_OBJ_OT    => COREOBJ_API.otSQL_COMPARISON,
      P_OBJ_NAME  => nvl(p_name, 'SQL Comparison ' ||to_char(sysdate,'YYYYMMDD HH24:MI')),
      P_OBJ_DESCR => p_descr,
      p_obj_owner => p_owner) ;
  end;

  procedure edit  (p_obj_id           opas_objects.obj_id%type,
                   p_owner            opas_files.owner%type default 'PUBLIC',
                   p_name             opas_objects.obj_name%type default null,
                   p_descr            opas_objects.obj_descr%type default null)
  is
  begin
    COREOBJ_API.edit_descr  (p_obj_id  => p_obj_id,
                             p_obj_name => p_name,
                             p_obj_descr => p_descr,
                             p_obj_owner => p_owner);
  end;

  procedure remove  (p_obj_id         opas_objects.obj_id%type,
                     p_cascade        varchar2 default 'N')
  is
  begin
    COREOBJ_API.remove(p_obj_id);
  end;

  procedure set_initial_pars(p_obj_id         opas_objects.obj_id%type)
  is
    L_SQL_ID1   opas_ot_sql_data.sql_id%type;
    L_SQL_ID2   opas_ot_sql_data.sql_id%type;
    L_DP1       opas_ot_sql_data.sql_data_point_id%type;
    L_DP2       opas_ot_sql_data.sql_data_point_id%type;
    L_PLAN_ID1  opas_ot_sql_plans.plan_id%type;
    L_PLAN_ID2  opas_ot_sql_plans.plan_id%type;
--    L_PLANTP1   varchar2(100);
--    L_PLANOPT1  varchar2(100);
    L_PLANTP    varchar2(100) := 'MAIN';
    L_DBID      number;
    L_SNAP_START number;
    L_SNAP_END   number;
    L_PLAN_HASH  number;
    L_INST       number;
  begin
    coreobj_api.extract_jparams(p_obj_id => p_obj_id);
    coreobj_api.get_jparam(p_obj_id => p_obj_id,
                           p_pname => COREOBJ_SQL_COMP_REPORT.pPLANDP#1,
                           p_value => L_DP1);
    coreobj_api.get_jparam(p_obj_id => p_obj_id,
                           p_pname => COREOBJ_SQL_COMP_REPORT.pPLANDP#2,
                           p_value => L_DP2);

    if L_DP1 is not null then

      begin
        select sql_id into L_SQL_ID1 from opas_ot_sql_data where sql_data_point_id = L_DP1 order by sql_data_point_id desc fetch first row only;
      exception when no_data_found then L_SQL_ID1 :=null;
      end;
      coreobj_api.add_jparam(p_obj_id => p_obj_id,
                             p_pname => COREOBJ_SQL_COMP_REPORT.pSQLID#1,
                             p_value => L_SQL_ID1);

      for i in (SELECT inst_id,plan_hash_value,child_number FROM opas_ot_sql_vsql where sql_data_point_id = L_DP1
                 order by sql_data_point_id desc fetch first row only)
      loop

        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pCHLD#1,
                               p_value => i.child_number);
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pV$PLNHASH#1,
                               p_value => i.plan_hash_value);
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pV$INST#1,
                               p_value => i.inst_id);
      end loop;
    end if;

    -----------------
    if L_DP2 is not null then

      begin
        select sql_id into L_SQL_ID2 from opas_ot_sql_data where sql_data_point_id = L_DP2 order by sql_data_point_id desc fetch first row only;
      exception when no_data_found then L_SQL_ID2 :=null;
      end;
      coreobj_api.add_jparam(p_obj_id => p_obj_id,
                             p_pname => COREOBJ_SQL_COMP_REPORT.pSQLID#2,
                             p_value => L_SQL_ID2);

      for i in (SELECT inst_id,plan_hash_value,child_number FROM opas_ot_sql_vsql where sql_data_point_id = L_DP2
                 order by sql_data_point_id desc fetch first row only)
      loop

        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pCHLD#2,
                               p_value => i.child_number);
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pV$PLNHASH#2,
                               p_value => i.plan_hash_value);
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pV$INST#2,
                               p_value => i.inst_id);
      end loop;
    end if;

    if L_DP1 is not null and L_DP2 is not null then
      begin
        select r.plan_id into L_PLAN_ID1
          from OPAS_OT_SQL_PLAN_REF r,
               OPAS_OT_SQL_PLANS p
         where r.sql_data_point_id = L_DP1
           and r.PLAN_ID = p.PLAN_ID
           and p.PLAN_SOURCE = 'V$'
         order by plan_id desc fetch first row only;
      exception when no_data_found then L_PLAN_ID1 := null;
      end;

      begin
        select r.plan_id into L_PLAN_ID2
          from OPAS_OT_SQL_PLAN_REF r,
               OPAS_OT_SQL_PLANS p
         where r.sql_data_point_id = L_DP2
           and r.PLAN_ID = p.PLAN_ID
           and p.PLAN_SOURCE = 'V$'
         order by plan_id desc fetch first row only;
      exception when no_data_found then L_PLAN_ID2 := null;
      end;
--coremod_log.log('1: L_PLAN_ID1,L_PLAN_ID2:'||L_PLAN_ID1||','||L_PLAN_ID2);
      if L_PLAN_ID1 is not null and L_PLAN_ID2 is not null then
        L_PLANTP := 'MAIN';
      else
        begin
          select plan_id into L_PLAN_ID1 from OPAS_OT_SQL_AWR_PLAN_REF where sql_data_point_id = L_DP1 order by plan_id desc fetch first row only;
        exception when no_data_found then L_PLAN_ID1 := null;
        end;

        begin
          select plan_id into L_PLAN_ID2 from OPAS_OT_SQL_AWR_PLAN_REF where sql_data_point_id = L_DP2 order by plan_id desc fetch first row only;
        exception when no_data_found then L_PLAN_ID2 := null;
        end;
--coremod_log.log('2: L_PLAN_ID1,L_PLAN_ID2:'||L_PLAN_ID1||','||L_PLAN_ID2);
        if L_PLAN_ID1 is not null and L_PLAN_ID2 is not null then
          L_PLANTP := 'AWR';
        else
          begin
            select plan_id into L_PLAN_ID1 from OPAS_OT_SQL_AWR_PLAN_REF where sql_data_point_id = L_DP1 order by plan_id desc fetch first row only;
          exception when no_data_found then L_PLAN_ID1 := null;
          end;

          begin
            select plan_id into L_PLAN_ID2 from OPAS_OT_SQL_PLAN_REF where sql_data_point_id = L_DP2 order by plan_id desc fetch first row only;
          exception when no_data_found then L_PLAN_ID2 := null;
          end;
--coremod_log.log('3: L_PLAN_ID1,L_PLAN_ID2:'||L_PLAN_ID1||','||L_PLAN_ID2);
          if L_PLAN_ID1 is not null and L_PLAN_ID2 is not null then
            L_PLANTP := 'EP';
          else
            begin
              select r.plan_id into L_PLAN_ID1
                from OPAS_OT_SQL_PLAN_REF r,
                     OPAS_OT_SQL_PLANS p
               where r.sql_data_point_id = L_DP1
                 and r.PLAN_ID = p.PLAN_ID
                 and p.PLAN_SOURCE = 'HST'
               order by plan_id desc fetch first row only;
            exception when no_data_found then L_PLAN_ID1 := null;
            end;

            begin
              select r.plan_id into L_PLAN_ID2
                from OPAS_OT_SQL_PLAN_REF r,
                     OPAS_OT_SQL_PLANS p
               where r.sql_data_point_id = L_DP2
                 and r.PLAN_ID = p.PLAN_ID
                 and p.PLAN_SOURCE = 'HST'
               order by plan_id desc fetch first row only;
            exception when no_data_found then L_PLAN_ID2 := null;
            end;
--coremod_log.log('4: L_PLAN_ID1,L_PLAN_ID2:'||L_PLAN_ID1||','||L_PLAN_ID2);
            if L_PLAN_ID1 is not null and L_PLAN_ID2 is not null then
              L_PLANTP := 'HST';
            end if;
          end if;
        end if;
      end if;
      if L_DP1 is not null then
        begin
          select *
            into L_SNAP_START, L_SNAP_END, L_DBID, L_PLAN_HASH, L_INST
            from (select min(s.snap_id) s1, max(s.snap_id) s2, s.dbid, s.plan_hash_value, s.instance_number
                    from opas_ot_sql_data d,
                         opas_ot_sql_awr_sqlstat s
                   where s.sql_id = d.sql_id
                     and s.snap_id between d.awr_snap_start and d.awr_snap_end
                     and d.dblink = s.dblink
                     and d.incarnation# = s.incarnation#
                     and d.sql_data_point_id=L_DP1
                   group by s.dbid, s.plan_hash_value, s.instance_number) order by s1 desc fetch first row only;
        exception when no_data_found then null;
        end;
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pDBID#1,
                               p_value => L_DBID);
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pSNAPS#1,
                               p_value => L_SNAP_START);	
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pINST#1,
                               p_value => L_INST);
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pPLNHASH#1,
                               p_value => L_PLAN_HASH);
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pSNAPE#1,
                               p_value => L_SNAP_END);
      end if;

      if L_DP2 is not null then
        begin
          select *
            into L_SNAP_START, L_SNAP_END, L_DBID, L_PLAN_HASH, L_INST
            from (select min(s.snap_id) s1, max(s.snap_id) s2, s.dbid, s.plan_hash_value, s.instance_number
                    from opas_ot_sql_data d,
                         opas_ot_sql_awr_sqlstat s
                   where s.sql_id = d.sql_id
                     and s.snap_id between d.awr_snap_start and d.awr_snap_end
                     and d.dblink = s.dblink
                     and d.incarnation# = s.incarnation#
                     and d.sql_data_point_id=L_DP2
                   group by s.dbid, s.plan_hash_value, s.instance_number) order by s1 desc fetch first row only;
        exception when no_data_found then null;
        end;
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pDBID#2,
                               p_value => L_DBID);
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pSNAPS#2,
                               p_value => L_SNAP_START);	
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pINST#2,
                               p_value => L_INST);
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pPLNHASH#2,
                               p_value => L_PLAN_HASH);
        coreobj_api.add_jparam(p_obj_id => p_obj_id,
                               p_pname => COREOBJ_SQL_COMP_REPORT.pSNAPE#2,
                               p_value => L_SNAP_END);
      end if;
      --ID
      coreobj_api.add_jparam(p_obj_id => p_obj_id,
                             p_pname => COREOBJ_SQL_COMP_REPORT.pPLANID#1,
                             p_value => L_PLAN_ID1);
      coreobj_api.add_jparam(p_obj_id => p_obj_id,
                             p_pname => COREOBJ_SQL_COMP_REPORT.pPLANID#2,
                             p_value => L_PLAN_ID2);
      --TP Section
      coreobj_api.add_jparam(p_obj_id => p_obj_id,
                             p_pname => COREOBJ_SQL_COMP_REPORT.pPLANTP#1,
                             p_value => L_PLANTP);
      coreobj_api.add_jparam(p_obj_id => p_obj_id,
                             p_pname => COREOBJ_SQL_COMP_REPORT.pMAINPLANSECTION,
                             p_value => 'SQLPLLAST');
    end if;
    coreobj_api.store_jparams(p_obj_id => p_obj_id);

  end;

  function get_object_status_to_display (p_obj_id          opas_objects.obj_id%type) return varchar2
  is
  begin
    return null;
  end;

  procedure compare(p_txt1      COREMOD_REPORT_UTILS.t_output_lines,
                    p_txt2      COREMOD_REPORT_UTILS.t_output_lines,
                    p_flags     pls_integer,
                    p_output    out COREMOD_REPORT_UTILS.t_output_lines,
                    p_c1        out COREMOD_REPORT_UTILS.t_output_lines,
                    p_c2        out COREMOD_REPORT_UTILS.t_output_lines,
                    p_c3        out COREMOD_REPORT_UTILS.t_output_lines)
  is
    l_plan_sections       COREMOD_REPORT_UTILS.t_arrayofstrings := COREMOD_REPORT_UTILS.t_arrayofstrings();
    l_available_sections  COREMOD_REPORT_UTILS.t_available_sections;
    p1                    COREMOD_REPORT_UTILS.t_arrayofstrings := COREMOD_REPORT_UTILS.t_arrayofstrings();
    p2                    COREMOD_REPORT_UTILS.t_arrayofstrings := COREMOD_REPORT_UTILS.t_arrayofstrings();
    l_sec1                COREMOD_REPORT_UTILS.t_section;
    l_sec2                COREMOD_REPORT_UTILS.t_section;
    l_tab1                COREMOD_REPORT_UTILS.t_arrayofstrings;
    l_tab2                COREMOD_REPORT_UTILS.t_arrayofstrings;
    l_curr_section        number;
    l_cnt                 number;
    l_text_rowcnt         number;
--    l_max_width           number;

    r1       varchar2(32765);
    r2       varchar2(32765);
    l_fst1   varchar2(100):='<span class="nm"><b>';
    l_fst2   varchar2(100):='</b></span>';
    l_s_tag  varchar2(2)  := '<`';
    l_e_tag  varchar2(2)  := '`>';
    l_max_ind number;

    procedure pr11(p_msg varchar2) is begin p_output(p_output.count+1):=p_msg; end;
    procedure pr21(p_msg varchar2, p_match varchar2) is begin p_output(p_output.count+1):='~~*'||p_match||'*~~'||p_msg; end;
    procedure pr2(p_col1 varchar2, p_col2 varchar2, p_col3 varchar2)
    is
    begin
      p_c1(p_c1.count+1):=p_col1;
      p_c2(p_c2.count+1):=p_col2;
      p_c3(p_c3.count+1):=p_col3;
    end;

    procedure to_table_for_comparison(p_list IN OUT VARCHAR2,
                                      p_tab out COREMOD_REPORT_UTILS.t_arrayofstrings,
                                      p_start_tag varchar2 default null,
                                      p_end_tag varchar2 default null)
    IS
      l_string         VARCHAR2(32767) := p_list;
      l_comma_index    PLS_INTEGER;
      l_index          PLS_INTEGER := 1;
      l_sep            varchar2(1) := ',';
--      l_trailing_space number;
    BEGIN
      p_tab := COREMOD_REPORT_UTILS.t_arrayofstrings();
      if instr(p_list,'|') > 0 then l_sep := '|';end if;
      if instr(p_list,'Plan hash value') > 0 then l_sep := ':';end if;
--      l_trailing_space:=nvl(length(l_string),0)-nvl(length(trim(l_string)),0);
      if substr(trim(l_string),nvl(length(trim(l_string)),0))=l_sep then null; else l_string:=l_string||l_sep; end if;
      p_list:= null;
      LOOP
        l_comma_index := INSTR(l_string, l_sep, l_index);
        EXIT WHEN l_comma_index = 0;
        p_tab.EXTEND;
        p_tab(p_tab.COUNT) := '~`'||p_tab.COUNT||'`~'||p_start_tag || trim(SUBSTR(l_string, l_index, l_comma_index - l_index)) || p_end_tag;
        p_list:=p_list|| replace(SUBSTR(l_string, l_index, l_comma_index - l_index),trim(SUBSTR(l_string, l_index, l_comma_index - l_index)),p_tab(p_tab.COUNT)) ||l_sep;
        l_index := l_comma_index + 1;
      END LOOP;
      if l_sep <> '|' then
        p_list:=rtrim(p_list,l_sep);
      else
        --p_list:=p_list||rpad(' ',l_trailing_space, ' ');
        null;
      end if;
      --l_trailing_space:=nvl(length(p_list),0)-nvl(length(trim(p_list)),0);
    END;
  begin
    -- get max width
--    l_max_width := 0;
--    for j in 1 .. p_txt1.count loop
--      if length(p_txt1(j)) > l_max_width then
--        l_max_width := length(p_txt1(j));
--      end if;
--    end loop;
--    p_max_width := l_max_width;

--    l_max_width := 0;
--    for j in 1 .. p_txt2.count loop
--      if length(p_txt2(j)) > l_max_width then
--        l_max_width := length(p_txt2(j));
--      end if;
--    end loop;
--    p_max_width := p_max_width+l_max_width;

    l_text_rowcnt := greatest(p_txt1.count, p_txt2.count);

    --aligning sections
    if p_flags = flgSQLPLAN then
      for i in 1..p_txt1.count loop
        for j in 1..g_plan_sections_all.count loop
--coremod_log.log('p_txt1(i): '||p_txt1(i));
          if instr(p_txt1(i),g_plan_sections_all(j))>0 then
            l_available_sections(g_plan_sections_all(j)):=1;
          end if;
        end loop;
      end loop;

      for i in 1..p_txt2.count loop
        for j in 1..g_plan_sections_all.count loop
--coremod_log.log('p_txt1(i): '||p_txt1(i));
          if instr(p_txt2(i),g_plan_sections_all(j))>0 then
            l_available_sections(g_plan_sections_all(j)):=1;
          end if;
        end loop;
      end loop;
--coremod_log.log('l_available_sections.count: '||l_available_sections.count);
      for j in 1..g_plan_sections_all.count loop
--coremod_log.log('g_plan_sections_all(j): '||g_plan_sections_all(j));
        if l_available_sections.exists(g_plan_sections_all(j)) then
          l_plan_sections.extend;
          l_plan_sections(l_plan_sections.count):=g_plan_sections_all(j);
        end if;
      end loop;

      for i in 1..l_plan_sections.count loop
        l_sec1(l_plan_sections(i)):=COREMOD_REPORT_UTILS.t_arrayofstrings();
        l_sec2(l_plan_sections(i)):=COREMOD_REPORT_UTILS.t_arrayofstrings();
      end loop;

      l_cnt := 1;
      l_curr_section:=1;
--coremod_log.log('l_plan_sections.count: '||l_plan_sections.count);
      for i in 1..p_txt1.count loop
        if instr(p_txt1(i),l_plan_sections(l_cnt))>0 then
          l_curr_section:=l_cnt;
          if l_cnt<l_plan_sections.count then
            l_cnt:=l_cnt+1;
          end if;
        end if;
        l_sec1(l_plan_sections(l_curr_section)).extend;
        l_sec1(l_plan_sections(l_curr_section))(l_sec1(l_plan_sections(l_curr_section)).count):=p_txt1(i);
      end loop;

      l_cnt := 1;l_curr_section:=1;
      for i in 1..p_txt2.count loop
        if instr(p_txt2(i),l_plan_sections(l_cnt))>0 then l_curr_section:=l_cnt; if l_cnt<l_plan_sections.count then l_cnt:=l_cnt+1; end if; end if;
        l_sec2(l_plan_sections(l_curr_section)).extend;
        l_sec2(l_plan_sections(l_curr_section))(l_sec2(l_plan_sections(l_curr_section)).count):=p_txt2(i);
      end loop;

      for a in 1..l_plan_sections.count loop
        for i in 1..greatest(l_sec1(l_plan_sections(a)).count,l_sec2(l_plan_sections(a)).count) loop
          p1.extend;
          if l_sec1(l_plan_sections(a)).exists(i) then
            p1(p1.count) := l_sec1(l_plan_sections(a))(i);
          else
            p1(p1.count):=' ';
          end if;
          p2.extend;
          if l_sec2(l_plan_sections(a)).exists(i) then
            p2(p2.count) := l_sec2(l_plan_sections(a))(i);
          else
            p2(p2.count):=' ';
          end if;
        end loop;
      end loop;
    else
      for i in 1..l_text_rowcnt loop
        p1.extend;
        if p_txt1.exists(i) then
          p1(p1.count) := p_txt1(i);
        else
          p1(p1.count):=' ';
        end if;
        p2.extend;
        if p_txt2.exists(i) then
          p2(p2.count) := p_txt2(i);
        else
          p2(p2.count):=' ';
        end if;
      end loop;
    end if;

    --comparing
    --pr1(rpad('-',p_max_width*2+1,'-'));

    <<print_plan_comparison>>
    for j in 1 .. l_text_rowcnt loop

      if p2.exists(j)then
        r2 := p2(j);
      end if;

      if p1.exists(j) then
        r1:=--rpad(
            nvl(rtrim(replace(p1(j),chr(9),' ')),' ')
            --, p_max_width, ' ')
            ;
      else
        if r2 is not null then
          r1 := --rpad(
               ' '
               --, p_max_width, ' ')
               ;
        end if;
      end if;

      if REGEXP_REPLACE(trim(ltrim(r1,'.')),'\s+','')=REGEXP_REPLACE(trim(r2),'\s+','') or (trim(TRANSLATE(r1,'-',' ')) is null and trim(TRANSLATE(r2,'-',' ')) is null) then
        --pr2(r1 || '+' || r2, '+');
        pr2(r1, '+', r2);
      else
        --coloring different words
        if r2 is not null then
          to_table_for_comparison(r1,l_tab1,l_s_tag,l_e_tag);
          to_table_for_comparison(r2,l_tab2,l_s_tag,l_e_tag);
          l_max_ind:=greatest(l_tab1.count,l_tab2.count);
          for q in 1..l_max_ind loop
            if l_tab1.exists(q) and l_tab2.exists(q) then
              if nvl(l_tab1(q),'#$%')<>nvl(l_tab2(q),'#$%') then
                if l_tab1(q) is not null and trim(TRANSLATE(replace(replace(replace(l_tab1(q),'~`'||q||'`~'),l_s_tag),l_e_tag),'-',' ')) is not null
                then
                  r1:=replace(r1,l_tab1(q),l_fst1||replace(replace(replace(l_tab1(q),'~`'||q||'`~'),l_s_tag),l_e_tag)||l_fst2);
                end if;
                if l_tab2(q) is not null and trim(TRANSLATE(replace(replace(replace(l_tab2(q),'~`'||q||'`~'),l_s_tag),l_e_tag),'-',' ')) is not null
                then
                  r2:=replace(r2,l_tab2(q),l_fst1||replace(replace(replace(l_tab2(q),'~`'||q||'`~'),l_s_tag),l_e_tag)||l_fst2);
                end if;
              end if;
            end if;
            if l_tab1.exists(q) and not l_tab2.exists(q) then
              if l_tab1(q) is not null and trim(TRANSLATE(replace(replace(replace(l_tab1(q),'~`'||q||'`~'),l_s_tag),l_e_tag),'-',' ')) is not null
              then
                r1:=replace(r1,l_tab1(q),l_fst1||replace(replace(replace(l_tab1(q),'~`'||q||'`~'),l_s_tag),l_e_tag)||l_fst2);
              end if;
            end if;
            if not l_tab1.exists(q) and l_tab2.exists(q) then
              if l_tab2(q) is not null and trim(TRANSLATE(replace(replace(replace(l_tab2(q),'~`'||q||'`~'),l_s_tag),l_e_tag),'-',' ')) is not null
              then
                r2:=replace(r2,l_tab2(q),l_fst1||replace(replace(replace(l_tab2(q),'~`'||q||'`~'),l_s_tag),l_e_tag)||l_fst2);
              end if;
            end if;
          end loop;
          for q in 1..l_max_ind loop
            r1 := replace(replace(replace(r1,'~`'||q||'`~'),l_s_tag),l_e_tag);
            r2 := replace(replace(replace(r2,'~`'||q||'`~'),l_s_tag),l_e_tag);
          end loop;
        end if;
        --pr2(r1 || case when r2 is null then '*' else '-' || r2 end, case when r2 is null then '*' else '-' end);
        pr2(r1, case when r2 is null then '*' else '-' end, r2);
      end if;
    end loop print_plan_comparison;

  end;

  procedure compare_sql_stats(p_stats1    in out t_sqlstat_base_crsr,
                              p_stats2    in out t_sqlstat_base_crsr,
                              --p_max_width number,
                              p_output    out COREMOD_REPORT_UTILS.t_output_lines) is
    l_stat_ln1   number := 50;
    l_stat_ln2   number := 30;
    r_stats1    r_sqlstat_base_crsr;
    r_stats2    r_sqlstat_base_crsr;

    procedure pr1(p_msg varchar2) is begin p_output(p_output.count+1):=p_msg; end;
    procedure pr(par1 varchar2, par2 varchar2, par3 varchar2 default null)
    is
--      delim1 varchar2(10) := '*';
--      delim2 varchar2(10) := '';
    begin
      --pr1(rpad(par1, length1, ' ') || delim1 ||rpad(par2, length2, ' ')|| delim2 ||rpad(par3, length1, ' '));
      pr1(rpad(par1, l_stat_ln1, ' ') || rpad(par2, l_stat_ln2, ' ')||par3);
    end;
  begin
    fetch p_stats1 into r_stats1;
    fetch p_stats2 into r_stats2;

    pr('Metric                  Value 1',                        'Value 2',                   'Delta, %            Delta to ELA/EXEC, %');
    pr('EXECS:                  '||r_stats1.EXECUTIONS_DELTA,    r_stats2.EXECUTIONS_DELTA,    round(100*((r_stats2.EXECUTIONS_DELTA-r_stats1.EXECUTIONS_DELTA)        /(case when r_stats1.EXECUTIONS_DELTA=0 then case when r_stats2.EXECUTIONS_DELTA=0 then 1 else r_stats2.EXECUTIONS_DELTA end else r_stats1.EXECUTIONS_DELTA end)),2)||'%');
    pr('ELA/EXEC(MS):           '||r_stats1.ela_poe,             r_stats2.ela_poe,             round(100*((r_stats2.ela_poe-r_stats1.ela_poe)                          /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
    pr('LIO/EXEC:               '||r_stats1.LIO_poe,             r_stats2.LIO_poe,             round(100*((r_stats2.LIO_poe-r_stats1.LIO_poe)                          /(case when r_stats1.LIO_poe=0 then case when r_stats2.LIO_poe=0 then 1 else r_stats2.LIO_poe end else r_stats1.LIO_poe end)),2)||'%');
    pr('CPU/EXEC(MS):           '||r_stats1.CPU_poe,             r_stats2.CPU_poe,             rpad(round(100*((r_stats2.CPU_poe-r_stats1.CPU_poe)                     /(case when r_stats1.CPU_poe=0 then case when r_stats2.CPU_poe=0 then 1 else r_stats2.CPU_poe end else r_stats1.CPU_poe end)),2)||'%',20,' ')||
        round(100*((r_stats2.CPU_poe-r_stats1.CPU_poe)                          /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
    pr('IOWAIT/EXEC(MS):        '||r_stats1.IOWAIT_poe,          r_stats2.IOWAIT_poe,          rpad(round(100*((r_stats2.IOWAIT_poe-r_stats1.IOWAIT_poe)               /(case when r_stats1.IOWAIT_poe=0 then case when r_stats2.IOWAIT_poe=0 then 1 else r_stats2.IOWAIT_poe end else r_stats1.IOWAIT_poe end)),2)||'%',20,' ')||
        round(100*((r_stats2.IOWAIT_poe-r_stats1.IOWAIT_poe)                    /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
    pr('CCWAIT/EXEC(MS):        '||r_stats1.CCWAIT_poe,          r_stats2.CCWAIT_poe,          rpad(round(100*((r_stats2.CCWAIT_poe-r_stats1.CCWAIT_poe)               /(case when r_stats1.CCWAIT_poe=0 then case when r_stats2.CCWAIT_poe=0 then 1 else r_stats2.CCWAIT_poe end else r_stats1.CCWAIT_poe end)),2)||'%',20,' ')||
        round(100*((r_stats2.CCWAIT_poe-r_stats1.CCWAIT_poe)                    /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
    pr('APWAIT/EXEC(MS):        '||r_stats1.APWAIT_poe,          r_stats2.APWAIT_poe,          rpad(round(100*((r_stats2.APWAIT_poe-r_stats1.APWAIT_poe)               /(case when r_stats1.APWAIT_poe=0 then case when r_stats2.APWAIT_poe=0 then 1 else r_stats2.APWAIT_poe end else r_stats1.APWAIT_poe end)),2)||'%',20,' ')||
        round(100*((r_stats2.APWAIT_poe-r_stats1.APWAIT_poe)                    /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
    pr('CLWAIT/EXEC(MS):        '||r_stats1.CLWAIT_poe,          r_stats2.CLWAIT_poe,          rpad(round(100*((r_stats2.CLWAIT_poe-r_stats1.CLWAIT_poe)               /(case when r_stats1.CLWAIT_poe=0 then case when r_stats2.CLWAIT_poe=0 then 1 else r_stats2.CLWAIT_poe end else r_stats1.CLWAIT_poe end)),2)||'%',20,' ')||
        round(100*((r_stats2.CLWAIT_poe-r_stats1.CLWAIT_poe)                    /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');

    pr('READS/EXEC:             '||r_stats1.reads_poe,           r_stats2.reads_poe,           round(100*((r_stats2.reads_poe-r_stats1.reads_poe)                      /(case when r_stats1.reads_poe=0 then case when r_stats2.reads_poe=0 then 1 else r_stats2.reads_poe end else r_stats1.reads_poe end)),2)||'%');
    pr('WRITES/EXEC:            '||r_stats1.dwrites_poe,         r_stats2.dwrites_poe,         round(100*((r_stats2.dwrites_poe-r_stats1.dwrites_poe)                  /(case when r_stats1.dwrites_poe=0 then case when r_stats2.dwrites_poe=0 then 1 else r_stats2.dwrites_poe end else r_stats1.dwrites_poe end)),2)||'%');

    pr('ROWS/EXEC:              '||r_stats1.Rows_poe,            r_stats2.Rows_poe,            round(100*((r_stats2.Rows_poe-r_stats1.Rows_poe)                        /(case when r_stats1.Rows_poe=0 then case when r_stats2.Rows_poe=0 then 1 else r_stats2.Rows_poe end else r_stats1.Rows_poe end)),2)||'%');
    pr('ELA(SEC):               '||r_stats1.ELA_DELTA_SEC,       r_stats2.ELA_DELTA_SEC,       round(100*((r_stats2.ELA_DELTA_SEC-r_stats1.ELA_DELTA_SEC)              /(case when r_stats1.ELA_DELTA_SEC=0 then case when r_stats2.ELA_DELTA_SEC=0 then 1 else r_stats2.ELA_DELTA_SEC end else r_stats1.ELA_DELTA_SEC end)),2)||'%');
    pr('CPU(SEC):               '||r_stats1.CPU_DELTA_SEC,       r_stats2.CPU_DELTA_SEC,       round(100*((r_stats2.CPU_DELTA_SEC-r_stats1.CPU_DELTA_SEC)              /(case when r_stats1.CPU_DELTA_SEC=0 then case when r_stats2.CPU_DELTA_SEC=0 then 1 else r_stats2.CPU_DELTA_SEC end else r_stats1.CPU_DELTA_SEC end)),2)||'%');

    pr('IOWAIT(SEC):            '||r_stats1.IOWAIT_DELTA_SEC,    r_stats2.IOWAIT_DELTA_SEC,    round(100*((r_stats2.IOWAIT_DELTA_SEC-r_stats1.IOWAIT_DELTA_SEC)        /(case when r_stats1.IOWAIT_DELTA_SEC=0 then case when r_stats2.IOWAIT_DELTA_SEC=0 then 1 else r_stats2.IOWAIT_DELTA_SEC end else r_stats1.IOWAIT_DELTA_SEC end)),2)||'%');
    pr('CCWAIT(SEC):            '||r_stats1.CCWAIT_DELTA_SEC,    r_stats2.CCWAIT_DELTA_SEC,    round(100*((r_stats2.CCWAIT_DELTA_SEC-r_stats1.CCWAIT_DELTA_SEC)        /(case when r_stats1.CCWAIT_DELTA_SEC=0 then case when r_stats2.CCWAIT_DELTA_SEC=0 then 1 else r_stats2.CCWAIT_DELTA_SEC end else r_stats1.CCWAIT_DELTA_SEC end)),2)||'%');
    pr('APWAIT(SEC):            '||r_stats1.APWAIT_DELTA_SEC,    r_stats2.APWAIT_DELTA_SEC,    round(100*((r_stats2.APWAIT_DELTA_SEC-r_stats1.APWAIT_DELTA_SEC)        /(case when r_stats1.APWAIT_DELTA_SEC=0 then case when r_stats2.APWAIT_DELTA_SEC=0 then 1 else r_stats2.APWAIT_DELTA_SEC end else r_stats1.APWAIT_DELTA_SEC end)),2)||'%');
    pr('CLWAIT(SEC):            '||r_stats1.CLWAIT_DELTA_SEC,    r_stats2.CLWAIT_DELTA_SEC,    round(100*((r_stats2.CLWAIT_DELTA_SEC-r_stats1.CLWAIT_DELTA_SEC)        /(case when r_stats1.CLWAIT_DELTA_SEC=0 then case when r_stats2.CLWAIT_DELTA_SEC=0 then 1 else r_stats2.CLWAIT_DELTA_SEC end else r_stats1.CLWAIT_DELTA_SEC end)),2)||'%');

    pr('READS:                  '||r_stats1.DISK_READS_DELTA,    r_stats2.DISK_READS_DELTA,    round(100*((r_stats2.DISK_READS_DELTA-r_stats1.DISK_READS_DELTA)        /(case when r_stats1.DISK_READS_DELTA=0 then case when r_stats2.DISK_READS_DELTA=0 then 1 else r_stats2.DISK_READS_DELTA end else r_stats1.DISK_READS_DELTA end)),2)||'%');
    pr('DIR WRITES:             '||r_stats1.DISK_WRITES_DELTA,   r_stats2.DISK_WRITES_DELTA,   round(100*((r_stats2.DISK_WRITES_DELTA-r_stats1.DISK_WRITES_DELTA)      /(case when r_stats1.DISK_WRITES_DELTA=0 then case when r_stats2.DISK_WRITES_DELTA=0 then 1 else r_stats2.DISK_WRITES_DELTA end else r_stats1.DISK_WRITES_DELTA end)),2)||'%');

    pr('READ REQ:               '||r_stats1.PHY_READ_REQ_DELTA,  r_stats2.PHY_READ_REQ_DELTA,  round(100*((r_stats2.PHY_READ_REQ_DELTA-r_stats1.PHY_READ_REQ_DELTA)    /(case when r_stats1.PHY_READ_REQ_DELTA=0 then case when r_stats2.PHY_READ_REQ_DELTA=0 then 1 else r_stats2.PHY_READ_REQ_DELTA end else r_stats1.PHY_READ_REQ_DELTA end)),2)||'%');
    pr('WRITE REQ:              '||r_stats1.PHY_WRITE_REQ_DELTA, r_stats2.PHY_WRITE_REQ_DELTA, round(100*((r_stats2.PHY_WRITE_REQ_DELTA-r_stats1.PHY_WRITE_REQ_DELTA)  /(case when r_stats1.PHY_WRITE_REQ_DELTA=0 then case when r_stats2.PHY_WRITE_REQ_DELTA=0 then 1 else r_stats2.PHY_WRITE_REQ_DELTA end else r_stats1.PHY_WRITE_REQ_DELTA end)),2)||'%');


    pr('LIO:                    '||r_stats1.BUFFER_GETS_DELTA,   r_stats2.BUFFER_GETS_DELTA,   round(100*((r_stats2.BUFFER_GETS_DELTA-r_stats1.BUFFER_GETS_DELTA)      /(case when r_stats1.BUFFER_GETS_DELTA=0 then case when r_stats2.BUFFER_GETS_DELTA=0 then 1 else r_stats2.BUFFER_GETS_DELTA end else r_stats1.BUFFER_GETS_DELTA end)),2)||'%');
    pr('ROWS:                   '||r_stats1.ROWS_PROCESSED_DELTA,r_stats2.ROWS_PROCESSED_DELTA,round(100*((r_stats2.ROWS_PROCESSED_DELTA-r_stats1.ROWS_PROCESSED_DELTA)/(case when r_stats1.ROWS_PROCESSED_DELTA=0 then case when r_stats2.ROWS_PROCESSED_DELTA=0 then 1 else r_stats2.ROWS_PROCESSED_DELTA end else r_stats1.ROWS_PROCESSED_DELTA end)),2)||'%');
    pr('LIO/ROW:                '||r_stats1.LIO_PER_ROW,         r_stats2.LIO_PER_ROW,         round(100*((r_stats2.LIO_PER_ROW-r_stats1.LIO_PER_ROW)                  /(case when r_stats1.LIO_PER_ROW=0 then case when r_stats2.LIO_PER_ROW=0 then 1 else r_stats2.LIO_PER_ROW end else r_stats1.LIO_PER_ROW end)),2)||'%');
    pr('PIO/ROW:                '||r_stats1.IO_PER_ROW,          r_stats2.IO_PER_ROW,          round(100*((r_stats2.IO_PER_ROW-r_stats1.IO_PER_ROW)                    /(case when r_stats1.IO_PER_ROW=0 then case when r_stats2.IO_PER_ROW=0 then 1 else r_stats2.IO_PER_ROW end else r_stats1.IO_PER_ROW end)),2)||'%');
    pr('CPU/ROW:                '||r_stats1.CPU_PER_ROW,         r_stats2.CPU_PER_ROW,         round(100*((r_stats2.CPU_PER_ROW-r_stats1.CPU_PER_ROW)                  /(case when r_stats1.CPU_PER_ROW=0 then case when r_stats2.CPU_PER_ROW=0 then 1 else r_stats2.CPU_PER_ROW end else r_stats1.CPU_PER_ROW end)),2)||'%');
    pr('AVG IO (MS):            '||r_stats1.awg_IO_tim,          r_stats2.awg_IO_tim,          round(100*((r_stats2.awg_IO_tim-r_stats1.awg_IO_tim)                    /(case when r_stats1.awg_IO_tim=0 then case when r_stats2.awg_IO_tim=0 then 1 else r_stats2.awg_IO_tim end else r_stats1.awg_IO_tim end)),2)||'%');
--    pr('IOWT/EXEC(MS)5ms:       '||r_stats1.io_wait_pe_5ms,      'IOWT/EXEC(MS)5ms:  '||r_stats2.io_wait_pe_5ms,      round(100*((r_stats2.io_wait_pe_5ms-r_stats1.io_wait_pe_5ms)            /(case when r_stats1.io_wait_pe_5ms=0 then case when r_stats2.io_wait_pe_5ms=0 then 1 else r_stats2.io_wait_pe_5ms end else r_stats1.io_wait_pe_5ms end)),2)||'%');
--    pr('IOWAIT(SEC)5ms:         '||r_stats1.io_wait_5ms,         'IOWAIT(SEC)5ms:    '||r_stats2.io_wait_5ms,         round(100*((r_stats2.io_wait_5ms-r_stats1.io_wait_5ms)                  /(case when r_stats1.io_wait_5ms=0 then case when r_stats2.io_wait_5ms=0 then 1 else r_stats2.io_wait_5ms end else r_stats1.io_wait_5ms end)),2)||'%');
  end;

  function getsqltext(p_sql_id varchar2,
                      p_max_length out number) return COREMOD_REPORT_UTILS.t_output_lines
  is
    l_file_id   opas_files.file_id%type;
    l_output    COREMOD_REPORT_UTILS.t_output_lines;
  begin
    p_max_length := 0;
    select nvl(sql_text,sql_text_approx) into l_file_id from OPAS_OT_SQL_DESCRIPTIONS de where sql_id=p_sql_id;
    for i in (SELECT line_number, payload
                FROM V$OPAS_FILE_CONTENTBYROW
               where file_id=l_file_id
               order by line_number)
    loop
      l_output(i.line_number) := rtrim(apex_escape.html(i.payload));
      if length(i.payload) > p_max_length then p_max_length := length(i.payload); end if;
    end loop;

    return l_output;
  end;

  procedure read_awr_plan(p_plan_id    opas_ot_sql_awr_plan_det.plan_id%type,
                          p_output out COREMOD_REPORT_UTILS.t_output_lines,
                          p_max_length out number) AS
  begin
    p_max_length := 0;

    for i in (select rownum line_number, plan_table_output from table(dbms_xplan.display('OPAS_OT_SQL_AWR_PLAN_DET', null, 'ADVANCED', 'plan_id='||p_plan_id)))
    loop
      read_awr_plan.p_output(i.line_number) := rtrim(apex_escape.html(i.plan_table_output));
      if length(i.plan_table_output) > p_max_length then p_max_length := length(i.plan_table_output); end if;
    end loop;
  end;

  procedure read_plan_ep(p_plan_id       opas_ot_sql_ep_plan_det.plan_id%type,
                         p_output    out COREMOD_REPORT_UTILS.t_output_lines,
                         p_max_length out number) AS
  begin
    p_max_length := 0;

    for i in (select rownum line_number, plan_table_output from table(dbms_xplan.display('OPAS_OT_SQL_EP_PLAN_DET', null, 'ADVANCED', 'plan_id='||p_plan_id)))
    loop
      read_plan_ep.p_output(i.line_number) := rtrim(apex_escape.html(i.plan_table_output));
      if length(i.plan_table_output) > p_max_length then p_max_length := length(i.plan_table_output); end if;
    end loop;
  end;

  procedure read_plan_main(p_plan_id        opas_ot_sql_awr_plan_det.plan_id%type,
                           p_section_name   varchar2,
                           p_output     out COREMOD_REPORT_UTILS.t_output_lines,
                           p_max_length out number) AS
    l_display_params varchar2(100);
  begin
    p_max_length := 0;
    case p_section_name
      when COREOBJ_SQL_REPORT_UTILS.repsSQLPLLAST
        then l_display_params:='LAST ALLSTATS +peeked_binds';
      when COREOBJ_SQL_REPORT_UTILS.repsSQLPLADV
        then l_display_params:='LAST ADVANCED';
      when COREOBJ_SQL_REPORT_UTILS.repsSQLPLALL
        then l_display_params:='ALL ALLSTATS +peeked_binds';
      when COREOBJ_SQL_REPORT_UTILS.repsSQLPLADAPT
        then l_display_params:='adaptive LAST ALLSTATS +peeked_binds';
    end case;

    for i in (select rownum line_number, plan_table_output from table(dbms_xplan.display('OPAS_OT_SQL_PLAN_DET', null, l_display_params, 'plan_id='||p_plan_id)))
    loop
      read_plan_main.p_output(i.line_number) := rtrim(apex_escape.html(i.plan_table_output));
      if length(i.plan_table_output) > p_max_length then p_max_length := length(i.plan_table_output); end if;
    end loop;
  end;


  function getsqlplan(p_obj_id           opas_objects.obj_id%type,
                      p_num              number,
                      p_max_length   out number) return COREMOD_REPORT_UTILS.t_output_lines
  is
    l_output    COREMOD_REPORT_UTILS.t_output_lines;
    l_plan_tp   varchar2(10);
    l_plan_id   varchar2(10);
    l_section_name  varchar2(100);
  begin
    coreobj_api.get_jparam(p_obj_id,pPLANTP#1,l_plan_tp);
    case p_num
      when 1 then
        coreobj_api.get_jparam(p_obj_id,pPLANID#1,l_plan_id);
      when 2 then
        coreobj_api.get_jparam(p_obj_id,pPLANID#2,l_plan_id);
    end case;

    case l_plan_tp
      when ptAWR then read_awr_plan(l_plan_id, l_output, p_max_length);
      when ptEP  then read_plan_ep(l_plan_id, l_output, p_max_length);
      when ptMAIN then
        coreobj_api.get_jparam(p_obj_id,pMAINPLANSECTION,l_section_name);
        read_plan_main(l_plan_id, l_section_name, l_output, p_max_length);
      when ptHST then
        read_plan_main(l_plan_id, null, l_output, p_max_length);
    end case;

    return l_output;
  end;

  procedure comprep_section_sqltext(p_obj_id           opas_objects.obj_id%type,
                                    p_output    out COREMOD_REPORT_UTILS.t_output_lines)
  is
    --l_max_width number;
    l_output    COREMOD_REPORT_UTILS.t_output_lines;
    l_c1        COREMOD_REPORT_UTILS.t_output_lines;
    l_c2        COREMOD_REPORT_UTILS.t_output_lines;
    l_c3        COREMOD_REPORT_UTILS.t_output_lines;
    l_sql1      varchar2(100);
    l_sql2      varchar2(100);
    l_length1   number;
    l_length2   number;
  begin
    coreobj_api.extract_jparams(p_obj_id);
    coreobj_api.get_jparam(p_obj_id,pSQLID#1,l_sql1);
    coreobj_api.get_jparam(p_obj_id,pSQLID#2,l_sql2);

    COREOBJ_SQL_COMP_REPORT.compare
                    (getsqltext(l_sql1, l_length1),
                     getsqltext(l_sql2, l_length2),
                     flgTEXT,
                     l_output,
                     l_c1,
                     l_c2,
                     l_c3);
     if l_length1 + l_length2 > 280 then
       l_length1 := 140;l_length2 := 140;
     end if;
     COREMOD_REPORT_UTILS.print_3arrays
                (p_t_header   => 'SQL Text Comparison', -- of '||l_sql1||' and '||l_sql2||' texts',
                 p_width      => (l_length1 + l_length2) * COREMOD_REPORT_UTILS.gPixelPerChar,
                 p_style_r1   => 'awrc1', --odd rows
                 p_style_r2   => 'awrnc1', --even rows
                 p_style_head => 'trchd',
                 p_style_tab  => 'trctd',
                 p_output     => comprep_section_sqltext.p_output,
                 p_col1       => l_c1,
                 p_col2       => l_c2,
                 p_col3       => l_c3);

  end;

  procedure comprep_section_sqlplan(p_obj_id           opas_objects.obj_id%type,
                                    p_output    out COREMOD_REPORT_UTILS.t_output_lines)
  is
    --l_max_width number;
    l_output    COREMOD_REPORT_UTILS.t_output_lines;
    l_c1        COREMOD_REPORT_UTILS.t_output_lines;
    l_c2        COREMOD_REPORT_UTILS.t_output_lines;
    l_c3        COREMOD_REPORT_UTILS.t_output_lines;
    l_sql1      varchar2(100);
    l_sql2      varchar2(100);

    l_plan_tp   varchar2(10);
    l_plan_id1  varchar2(10);
    l_plan_id2  varchar2(10);
    l_length1   number;
    l_length2   number;
  begin
    coreobj_api.extract_jparams(p_obj_id);
    coreobj_api.get_jparam(p_obj_id,pSQLID#1,l_sql1);
    coreobj_api.get_jparam(p_obj_id,pSQLID#2,l_sql2);

    coreobj_api.get_jparam(p_obj_id,pPLANTP#1,l_plan_tp);
    coreobj_api.get_jparam(p_obj_id,pPLANID#1,l_plan_id1);
    coreobj_api.get_jparam(p_obj_id,pPLANID#2,l_plan_id2);

    if l_plan_tp is not null and l_plan_id1 is not null and l_plan_id2 is not null then
      COREOBJ_SQL_COMP_REPORT.compare
                      (getsqlplan(p_obj_id, 1, l_length1),
                       getsqlplan(p_obj_id, 2, l_length2),
                       flgSQLPLAN,
                       l_output,
                       l_c1,
                       l_c2,
                       l_c3);

      COREMOD_REPORT_UTILS.print_3arrays
                  (p_t_header   => 'SQL Execution Plan Comparison', -- of '||l_sql1||' and '||l_sql2,
                   p_width      => (l_length1+l_length2 + 2) * COREMOD_REPORT_UTILS.gPixelPerChar,
                   p_style_r1   => 'awrc1', --odd rows
                   p_style_r2   => 'awrnc1', --even rows
                   p_style_head => 'trchd',
                   p_style_tab  => 'trctd',
                   p_output     => comprep_section_sqlplan.p_output,
                   p_col1       => l_c1,
                   p_col2       => l_c2,
                   p_col3       => l_c3);
    end if;
  exception
    when others then comprep_section_sqlplan.p_output.delete; comprep_section_sqlplan.p_output(1) := 'Comparison not available';
  end;

  procedure stats_open_awr_crsr(p_obj_id           opas_objects.obj_id%type,
                                p_c1 in out COREOBJ_SQL_COMP_REPORT.t_sqlstat_base_crsr,
                                p_c2 in out COREOBJ_SQL_COMP_REPORT.t_sqlstat_base_crsr)
  is
    l_dbid1 number;
    l_dbid2 number;
    l_sql1  varchar2(100);
    l_sql2  varchar2(100);
    l_snap_start1  number;
    l_snap_start2  number;
    l_snap_end1    number;
    l_snap_end2    number;
    l_inst1        number;
    l_inst2        number;
    l_plhs1        number;
    l_plhs2        number;
  begin
    coreobj_api.get_jparam(p_obj_id,pDBID#1,l_dbid1);
    coreobj_api.get_jparam(p_obj_id,pDBID#2,l_dbid2);
    coreobj_api.get_jparam(p_obj_id,pSQLID#1,l_sql1);
    coreobj_api.get_jparam(p_obj_id,pSQLID#2,l_sql2);
    coreobj_api.get_jparam(p_obj_id,pSNAPS#1,l_snap_start1);
    coreobj_api.get_jparam(p_obj_id,pSNAPS#2,l_snap_start2);
    coreobj_api.get_jparam(p_obj_id,pSNAPE#1,l_snap_end1);
    coreobj_api.get_jparam(p_obj_id,pSNAPE#2,l_snap_end2);
    coreobj_api.get_jparam(p_obj_id,pINST#1,l_inst1);
    coreobj_api.get_jparam(p_obj_id,pINST#2,l_inst2);
    coreobj_api.get_jparam(p_obj_id,pPLNHASH#1,l_plhs1);
    coreobj_api.get_jparam(p_obj_id,pPLNHASH#2,l_plhs2);

    open p_c1 for
      select
        --  s.sql_id
        --, s.plan_hash_value
        --, s.dbid
         sum(s.EXECUTIONS_DELTA) EXECUTIONS_DELTA
        , (round(sum(s.ELAPSED_TIME_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as ela_poe
        , (round(sum(s.BUFFER_GETS_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as LIO_poe
        , (round(sum(s.CPU_TIME_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as CPU_poe
        , (round(sum(s.IOWAIT_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as IOWAIT_poe
        , (round(sum(s.ccwait_delta)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as CCWAIT_poe
        , (round(sum(s.APWAIT_delta)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as APWAIT_poe
        , (round(sum(s.CLWAIT_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as CLWAIT_poe
        , (round(sum(s.DISK_READS_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as reads_poe
        , (round(sum(s.DIRECT_WRITES_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as dwrites_poe
        , (round(sum(s.ROWS_PROCESSED_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as Rows_poe
        , ROUND(sum(ELAPSED_TIME_DELTA)/1000000,3) ELA_DELTA_SEC
        , ROUND(sum(CPU_TIME_DELTA)/1000000,3) CPU_DELTA_SEC
        , ROUND(sum(IOWAIT_DELTA)/1000000,3) IOWAIT_DELTA_SEC
        , ROUND(sum(ccwait_delta)/1000000,3) ccwait_delta_SEC
        , ROUND(sum(APWAIT_delta)/1000000,3) APWAIT_delta_SEC
        , ROUND(sum(CLWAIT_DELTA)/1000000,3) CLWAIT_DELTA_SEC
        ,sum(DISK_READS_DELTA)DISK_READS_DELTA
        ,sum(DIRECT_WRITES_DELTA)DISK_WRITES_DELTA
        ,sum(BUFFER_GETS_DELTA)BUFFER_GETS_DELTA
        ,sum(ROWS_PROCESSED_DELTA)ROWS_PROCESSED_DELTA
        ,sum(PHYSICAL_READ_REQUESTS_DELTA)PHY_READ_REQ_DELTA
        ,sum(PHYSICAL_WRITE_REQUESTS_DELTA)PHY_WRITE_REQ_DELTA
        ,round(sum(BUFFER_GETS_DELTA)/decode(sum(ROWS_PROCESSED_DELTA),0,null,sum(ROWS_PROCESSED_DELTA)),3) LIO_PER_ROW
        ,round(sum(DISK_READS_DELTA)/decode(sum(ROWS_PROCESSED_DELTA),0,null,sum(ROWS_PROCESSED_DELTA)),3) IO_PER_ROW
        ,round(sum(CPU_TIME_DELTA)/decode(sum(ROWS_PROCESSED_DELTA),0,null,sum(ROWS_PROCESSED_DELTA)),3) CPU_PER_ROW
        ,round(sum(s.IOWAIT_DELTA)/decode(sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA), null, decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)),0,decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)), sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))/1000,3) as awg_IO_tim
        --,(sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))*0.005 as io_wait_5ms
        --,round((sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))/decode(sum(s.EXECUTIONS_DELTA), null, decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)),0,decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)), sum(s.EXECUTIONS_DELTA))*5) io_wait_pe_5ms
      from opas_ot_sql_awr_sqlstat s
      where s.sql_id = l_sql1
        and snap_id between l_snap_start1 and l_snap_end1 -- 12448
        and dbid = l_dbid1
        and instance_number = nvl(l_inst1,instance_number)
        and plan_hash_value = nvl(l_plhs1,plan_hash_value)
      --group by s.dbid,s.plan_hash_value,s.sql_id
      ;

    open p_c2 for
      select
        --  s.sql_id
        --, s.plan_hash_value
        --, s.dbid
         sum(s.EXECUTIONS_DELTA) EXECUTIONS_DELTA
        , (round(sum(s.ELAPSED_TIME_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as ela_poe
        , (round(sum(s.BUFFER_GETS_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as LIO_poe
        , (round(sum(s.CPU_TIME_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as CPU_poe
        , (round(sum(s.IOWAIT_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as IOWAIT_poe
        , (round(sum(s.ccwait_delta)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as CCWAIT_poe
        , (round(sum(s.APWAIT_delta)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as APWAIT_poe
        , (round(sum(s.CLWAIT_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA))/1000,3)) as CLWAIT_poe
        , (round(sum(s.DISK_READS_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as reads_poe
        , (round(sum(s.DIRECT_WRITES_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as dwrites_poe
        , (round(sum(s.ROWS_PROCESSED_DELTA)/decode(sum(s.EXECUTIONS_DELTA), null, 1,0,1, sum(s.EXECUTIONS_DELTA)),3)) as Rows_poe
        , ROUND(sum(ELAPSED_TIME_DELTA)/1000000,3) ELA_DELTA_SEC
        , ROUND(sum(CPU_TIME_DELTA)/1000000,3) CPU_DELTA_SEC
        , ROUND(sum(IOWAIT_DELTA)/1000000,3) IOWAIT_DELTA_SEC
        , ROUND(sum(ccwait_delta)/1000000,3) ccwait_delta_SEC
        , ROUND(sum(APWAIT_delta)/1000000,3) APWAIT_delta_SEC
        , ROUND(sum(CLWAIT_DELTA)/1000000,3) CLWAIT_DELTA_SEC
        ,sum(DISK_READS_DELTA)DISK_READS_DELTA
        ,sum(DIRECT_WRITES_DELTA)DISK_WRITES_DELTA
        ,sum(BUFFER_GETS_DELTA)BUFFER_GETS_DELTA
        ,sum(ROWS_PROCESSED_DELTA)ROWS_PROCESSED_DELTA
        ,sum(PHYSICAL_READ_REQUESTS_DELTA)PHY_READ_REQ_DELTA
        ,sum(PHYSICAL_WRITE_REQUESTS_DELTA)PHY_WRITE_REQ_DELTA
        ,round(sum(BUFFER_GETS_DELTA)/decode(sum(ROWS_PROCESSED_DELTA),0,null,sum(ROWS_PROCESSED_DELTA)),3) LIO_PER_ROW
        ,round(sum(DISK_READS_DELTA)/decode(sum(ROWS_PROCESSED_DELTA),0,null,sum(ROWS_PROCESSED_DELTA)),3) IO_PER_ROW
        ,round(sum(CPU_TIME_DELTA)/decode(sum(ROWS_PROCESSED_DELTA),0,null,sum(ROWS_PROCESSED_DELTA)),3) CPU_PER_ROW
        ,round(sum(s.IOWAIT_DELTA)/decode(sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA), null, decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)),0,decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)), sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))/1000,3) as awg_IO_tim
        --,(sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))*0.005 as io_wait_5ms
        --,round((sum(s.PHYSICAL_READ_REQUESTS_DELTA)+sum(s.PHYSICAL_WRITE_REQUESTS_DELTA))/decode(sum(s.EXECUTIONS_DELTA), null, decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)),0,decode(sum(DISK_READS_DELTA),0,1,sum(DISK_READS_DELTA)), sum(s.EXECUTIONS_DELTA))*5) io_wait_pe_5ms
      from opas_ot_sql_awr_sqlstat s
      where
          s.sql_id = l_sql2
        and snap_id between l_snap_start2 and l_snap_end2 -- 12448
        and dbid = l_dbid2
        and instance_number = nvl(l_inst2,instance_number)
        and plan_hash_value = nvl(l_plhs2,plan_hash_value)
      --group by s.dbid,s.plan_hash_value,s.sql_id
      ;
  end;

  procedure stats_open_vsql_crsr(p_obj_id           opas_objects.obj_id%type,
                                 p_c1 in out COREOBJ_SQL_COMP_REPORT.t_sqlstat_base_crsr,
                                 p_c2 in out COREOBJ_SQL_COMP_REPORT.t_sqlstat_base_crsr)
  is
    l_dp_id1       number;
    l_dp_id2       number;
    l_chld1        number;
    l_chld2        number;
    l_plhs1        number;
    l_plhs2        number;
    l_inst1        number;
    l_inst2        number;
  begin
    coreobj_api.get_jparam(p_obj_id,pPLANDP#1,l_dp_id1);
    coreobj_api.get_jparam(p_obj_id,pPLANDP#2,l_dp_id2);
    coreobj_api.get_jparam(p_obj_id,pCHLD#1,l_chld1);
    coreobj_api.get_jparam(p_obj_id,pCHLD#2,l_chld2);
    coreobj_api.get_jparam(p_obj_id,pPLNHASH#1,l_plhs1);
    coreobj_api.get_jparam(p_obj_id,pPLNHASH#2,l_plhs2);
    coreobj_api.get_jparam(p_obj_id,pV$INST#1,l_inst1);
    coreobj_api.get_jparam(p_obj_id,pV$INST#2,l_inst2);

    open p_c1 for
    select
      --  s.sql_id
      --, s.plan_hash_value
      --, null dbid
       sum(s.EXECUTIONS) EXECUTIONS_DELTA
      , (round(sum(s.ELAPSED_TIME)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS))/1000,3)) as ela_poe
      , (round(sum(s.BUFFER_GETS)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS)),3)) as LIO_poe
      , (round(sum(s.CPU_TIME)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS))/1000,3)) as CPU_poe
      , (round(sum(s.USER_IO_WAIT_TIME)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS))/1000,3)) as IOWAIT_poe
      , (round(sum(s.CONCURRENCY_WAIT_TIME)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS))/1000,3)) as CCWAIT_poe
      , (round(sum(s.APPLICATION_WAIT_TIME)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS))/1000,3)) as APWAIT_poe
      , (round(sum(s.CLUSTER_WAIT_TIME)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS))/1000,3)) as CLWAIT_poe
      , (round(sum(s.DISK_READS)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS)),3)) as reads_poe
      , (round(sum(s.DIRECT_WRITES)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS)),3)) as dwrites_poe
      , (round(sum(s.ROWS_PROCESSED)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS)),3)) as Rows_poe
      , ROUND(sum(ELAPSED_TIME)/1000000,3) ELA_DELTA_SEC
      , ROUND(sum(CPU_TIME)/1000000,3) CPU_DELTA_SEC
      , ROUND(sum(USER_IO_WAIT_TIME)/1000000,3) IOWAIT_DELTA_SEC
      , ROUND(sum(CONCURRENCY_WAIT_TIME)/1000000,3) ccwait_delta_SEC
      , ROUND(sum(APPLICATION_WAIT_TIME)/1000000,3) APWAIT_delta_SEC
      , ROUND(sum(CLUSTER_WAIT_TIME)/1000000,3) CLWAIT_DELTA_SEC
      ,sum(DISK_READS)DISK_READS_DELTA
      ,sum(DIRECT_WRITES)DISK_WRITES_DELTA
      ,sum(BUFFER_GETS)BUFFER_GETS_DELTA
      ,sum(ROWS_PROCESSED)ROWS_PROCESSED_DELTA
      ,sum(PHYSICAL_READ_REQUESTS)PHY_READ_REQ_DELTA
      ,sum(PHYSICAL_WRITE_REQUESTS)PHY_WRITE_REQ_DELTA
      ,round(sum(BUFFER_GETS)/decode(sum(ROWS_PROCESSED),0,null,sum(ROWS_PROCESSED)),3) LIO_PER_ROW
      ,round(sum(DISK_READS)/decode(sum(ROWS_PROCESSED),0,null,sum(ROWS_PROCESSED)),3) IO_PER_ROW
      ,round(sum(CPU_TIME)/decode(sum(ROWS_PROCESSED),0,null,sum(ROWS_PROCESSED)),3) CPU_PER_ROW
      ,round(sum(s.USER_IO_WAIT_TIME)/decode(sum(s.PHYSICAL_READ_REQUESTS)+sum(s.PHYSICAL_WRITE_REQUESTS), null, decode(sum(DISK_READS),0,1,sum(DISK_READS)),0,decode(sum(DISK_READS),0,1,sum(DISK_READS)), sum(s.PHYSICAL_READ_REQUESTS)+sum(s.PHYSICAL_WRITE_REQUESTS))/1000,3) as awg_IO_tim
      --,(sum(s.PHYSICAL_READ_REQUESTS)+sum(s.PHYSICAL_WRITE_REQUESTS))*0.005 as io_wait_5ms
      --,round((sum(s.PHYSICAL_READ_REQUESTS)+sum(s.PHYSICAL_WRITE_REQUESTS))/decode(sum(s.EXECUTIONS), null, decode(sum(DISK_READS),0,1,sum(DISK_READS)),0,decode(sum(DISK_READS),0,1,sum(DISK_READS)), sum(s.EXECUTIONS))*5) io_wait_pe_5ms
    from OPAS_OT_SQL_VSQL s
    where sql_data_point_id=l_dp_id1
      and child_number = nvl(l_chld1,child_number)
      and plan_hash_value = nvl(l_plhs1,plan_hash_value)
      and inst_id = nvl(l_inst1,inst_id)
    --group by s.plan_hash_value,s.sql_id
    ;

    open p_c2 for
    select
      --  s.sql_id
      --, s.plan_hash_value
      --, null dbid
       sum(s.EXECUTIONS) EXECUTIONS_DELTA
      , (round(sum(s.ELAPSED_TIME)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS))/1000,3)) as ela_poe
      , (round(sum(s.BUFFER_GETS)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS)),3)) as LIO_poe
      , (round(sum(s.CPU_TIME)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS))/1000,3)) as CPU_poe
      , (round(sum(s.USER_IO_WAIT_TIME)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS))/1000,3)) as IOWAIT_poe
      , (round(sum(s.CONCURRENCY_WAIT_TIME)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS))/1000,3)) as CCWAIT_poe
      , (round(sum(s.APPLICATION_WAIT_TIME)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS))/1000,3)) as APWAIT_poe
      , (round(sum(s.CLUSTER_WAIT_TIME)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS))/1000,3)) as CLWAIT_poe
      , (round(sum(s.DISK_READS)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS)),3)) as reads_poe
      , (round(sum(s.DIRECT_WRITES)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS)),3)) as dwrites_poe
      , (round(sum(s.ROWS_PROCESSED)/decode(sum(s.EXECUTIONS), null, 1,0,1, sum(s.EXECUTIONS)),3)) as Rows_poe
      , ROUND(sum(ELAPSED_TIME)/1000000,3) ELA_DELTA_SEC
      , ROUND(sum(CPU_TIME)/1000000,3) CPU_DELTA_SEC
      , ROUND(sum(USER_IO_WAIT_TIME)/1000000,3) IOWAIT_DELTA_SEC
      , ROUND(sum(CONCURRENCY_WAIT_TIME)/1000000,3) ccwait_delta_SEC
      , ROUND(sum(APPLICATION_WAIT_TIME)/1000000,3) APWAIT_delta_SEC
      , ROUND(sum(CLUSTER_WAIT_TIME)/1000000,3) CLWAIT_DELTA_SEC
      ,sum(DISK_READS)DISK_READS_DELTA
      ,sum(DIRECT_WRITES)DISK_WRITES_DELTA
      ,sum(BUFFER_GETS)BUFFER_GETS_DELTA
      ,sum(ROWS_PROCESSED)ROWS_PROCESSED_DELTA
      ,sum(PHYSICAL_READ_REQUESTS)PHY_READ_REQ_DELTA
      ,sum(PHYSICAL_WRITE_REQUESTS)PHY_WRITE_REQ_DELTA
      ,round(sum(BUFFER_GETS)/decode(sum(ROWS_PROCESSED),0,null,sum(ROWS_PROCESSED)),3) LIO_PER_ROW
      ,round(sum(DISK_READS)/decode(sum(ROWS_PROCESSED),0,null,sum(ROWS_PROCESSED)),3) IO_PER_ROW
      ,round(sum(CPU_TIME)/decode(sum(ROWS_PROCESSED),0,null,sum(ROWS_PROCESSED)),3) CPU_PER_ROW
      ,round(sum(s.USER_IO_WAIT_TIME)/decode(sum(s.PHYSICAL_READ_REQUESTS)+sum(s.PHYSICAL_WRITE_REQUESTS), null, decode(sum(DISK_READS),0,1,sum(DISK_READS)),0,decode(sum(DISK_READS),0,1,sum(DISK_READS)), sum(s.PHYSICAL_READ_REQUESTS)+sum(s.PHYSICAL_WRITE_REQUESTS))/1000,3) as awg_IO_tim
      --,(sum(s.PHYSICAL_READ_REQUESTS)+sum(s.PHYSICAL_WRITE_REQUESTS))*0.005 as io_wait_5ms
      --,round((sum(s.PHYSICAL_READ_REQUESTS)+sum(s.PHYSICAL_WRITE_REQUESTS))/decode(sum(s.EXECUTIONS), null, decode(sum(DISK_READS),0,1,sum(DISK_READS)),0,decode(sum(DISK_READS),0,1,sum(DISK_READS)), sum(s.EXECUTIONS))*5) io_wait_pe_5ms
    from OPAS_OT_SQL_VSQL s
    where sql_data_point_id=l_dp_id2
      and child_number = nvl(l_chld2,child_number)
      and plan_hash_value = nvl(l_plhs2,plan_hash_value)
      and inst_id = nvl(l_inst2,inst_id)
    --group by s.plan_hash_value,s.sql_id
    ;
  end;

  procedure comprep_section_stats(p_obj_id        opas_objects.obj_id%type,
                                  p_stattp        varchar2,
                                  p_output    out COREMOD_REPORT_UTILS.t_output_lines)
  is
    l_output    COREMOD_REPORT_UTILS.t_output_lines;
--    l_stattp    varchar2(100);

    c1 COREOBJ_SQL_COMP_REPORT.t_sqlstat_base_crsr;
    c2 COREOBJ_SQL_COMP_REPORT.t_sqlstat_base_crsr;
  begin
    coreobj_api.extract_jparams(p_obj_id);
    --coreobj_api.get_jparam(p_obj_id,pSTATTP,l_stattp);
    --coreobj_api.get_jparam(p_obj_id,pSQLID#2,l_sql2);

    case p_stattp
      when stAWR then   stats_open_awr_crsr(p_obj_id,c1,c2);
      when stV$SQL then stats_open_vsql_crsr(p_obj_id,c1,c2);
    end case;

    COREOBJ_SQL_COMP_REPORT.compare_sql_stats(p_stats1    => c1,
                                              p_stats2    => c2,
                                              --p_max_width => 50,
                                              p_output    => l_output);

    COREMOD_REPORT_UTILS.convert_to_html_table (
        P_TEXT => null,
        P_INPUT => l_output,
        P_T_HEADER => case p_stattp
                         when stAWR then 'AWR Statistics comparison'
                         when stV$SQL then 'V$SQL Statistics comparison' end,
        P_WIDTH => 1000,
        P_SEARCH => null, --'CHILD_NUMBER=([[:digit:]]*)',
        P_REPLACEMENT => null, --HTF.ANCHOR (curl=>'#child_last_'||i.inst_id||'_'||i.child_number,ctext=>'CHILD_NUMBER=\1',cattributes=>'class="awr"'),
        --P_COMPARISON => P_COMPARISON,
        P_STYLE_TAB => 'trctd',
        P_STYLE_HEAD => 'trchd',
        P_STYLE_R1 => 'awrc1',--'trcr1',
        P_STYLE_R2 => 'awrnc1',--'trcr2',
        P_OUTPUT => p_output);

  end;

  procedure create_comprep_section(p_obj_id        opas_objects.obj_id%type,
                                   p_section       varchar2,
                                   p_output    out COREMOD_REPORT_UTILS.t_output_lines)
  is
  begin
    case p_section
      when repcoCSQLTEXT then comprep_section_sqltext(p_obj_id, p_output);
      when repcoEXECPLAN then comprep_section_sqlplan(p_obj_id, p_output);
      when repcoVSQLSTAT then comprep_section_stats (p_obj_id, stV$SQL, p_output);
      when repcoAWRSTAT  then comprep_section_stats (p_obj_id, stAWR,   p_output);
      when repcoASHWAIT  then null;           -- ASH Wait Profiles
      when repcoASHPLANSTAT then null;        -- ASH Plan Stats
    else
      null;
    end case;
  end;

  procedure print_comprep_section_web(p_obj_id           opas_objects.obj_id%type,
                                      p_section varchar2)
  is
    l_output        COREMOD_REPORT_UTILS.t_output_lines;
  begin
    create_comprep_section(p_obj_id, p_section, l_output);
    if l_output is not null then
      for i in 1..l_output.count loop
        htp.p(l_output(i));
      end loop;
    end if;
  exception
    when others then
      raise_application_error(-20000,sqlerrm||chr(10)||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
  end;

  function print_report_html(p_obj_id  opas_objects.obj_id%type,
                             p_section_list varchar2 default null) return TABLEOFSTRINGS pipelined
  is
    l_output              COREMOD_REPORT_UTILS.t_output_lines;
    l_str                 varchar2(32765);
    l_sql_data_point      opas_ot_sql_data%rowtype;
    l_object              opas_objects%rowtype;
    l_text                clob;

    L_SQL_ID1   opas_ot_sql_data.sql_id%type;
    L_SQL_ID2   opas_ot_sql_data.sql_id%type;
    L_DP1       opas_ot_sql_data.sql_data_point_id%type;
    L_DP2       opas_ot_sql_data.sql_data_point_id%type;
    L_PLANTP1   varchar2(100);
    L_PLANOPT1  varchar2(100);
    l_child_number number;
    l_plan_hash_value number;
    l_inst_id number;
    l_dbid number;
    l_snap1 number;
    l_snap2 number;
    l_obj_id     opas_objects.obj_id%type;

    function doprint(p_section_nm varchar2) return boolean
    is
    begin
      return nvl(p_section_list, 'ALLSECTIONS') = 'ALLSECTIONS' or instr(p_section_list,p_section_nm)>0;
    end;
  begin

    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_SQL_COMP_REPORT.PRINT_REPORT_HTML.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_SQL_COMP_REPORT.PRINT_REPORT_HTML.SQL_TRACE');

    coreobj_api.extract_jparams(p_obj_id => p_obj_id);
    coreobj_api.get_jparam(p_obj_id => p_obj_id,
                           p_pname => COREOBJ_SQL_COMP_REPORT.pSQLID#1,
                           p_value => L_SQL_ID1);
    coreobj_api.get_jparam(p_obj_id => p_obj_id,
                           p_pname => COREOBJ_SQL_COMP_REPORT.pSQLID#1,
                           p_value => L_SQL_ID2);

    pipe row (HTF.HTMLOPEN);
    pipe row (HTF.HEADOPEN);
    pipe row (HTF.TITLE('SQL Comparison Report for SQL_ID #1 = '||L_SQL_ID1||' and SQL_ID #2 = '||L_SQL_ID2));

    pipe row ('<style type="text/css">');
    for i in (SELECT payload
                FROM V$OPAS_FILE_CONTENTBYROW
               where file_id=COREMOD_API.getconf('OPASAWR.CSS',COREMOD_API.getMODNAME)) loop
      pipe row (i.payload);
    end loop;
    pipe row ('</style>');
    pipe row (HTF.HEADCLOSE);
    pipe row (HTF.BODYOPEN(cattributes=>'class="awr"'));

    pipe row (HTF.header (1,'SQL Comparison Report for SQL_ID #1 = '||L_SQL_ID1||' and SQL_ID #2 = '||L_SQL_ID2,cattributes=>'class="awr"'));
    pipe row (HTF.BR);
    pipe row (HTF.BR);
    pipe row (HTF.header (2,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Table of contents',cname=>'tblofcont',cattributes=>'class="awr"'),cattributes=>'class="awr"'));
    pipe row (HTF.BR);

    pipe row (HTF.LISTITEM(cattributes=>'class="awr"',
                           ctext=>HTF.ANCHOR (curl=>'#report_descr',
                                              ctext=>'Report description',
                                              cattributes=>'class="awr"'
                                              )
                          )
              );

    for i in (select d.DISPLAY_VAL, d.SPARSE1, d.val section_name
                from OPAS_DICTIONARY d
               where d.MODNAME=COREMOD_API.getMODNAME
                 and d.DIC_NAME='SQLCOMPSECT'
               order by d.DIC_ORDR)
    loop
      if doprint(i.section_name) then
        pipe row (HTF.LISTITEM(cattributes=>'class="awr"',
                               ctext=>HTF.ANCHOR (curl=>'#'||i.SPARSE1,
                                                  ctext=>i.DISPLAY_VAL,
                                                  cattributes=>'class="awr"'
                                                  )
                              )
                  );
      end if;
    end loop;
    pipe row (HTF.BR);
    pipe row (HTF.BR);

    pipe row (HTF.header (3,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Report description',cname=>'report_descr',cattributes=>'class="awr"'),cattributes=>'class="awr"'));
    pipe row (HTF.BR);

    coreobj_api.get_jparam(p_obj_id => p_obj_id,
                           p_pname => COREOBJ_SQL_COMP_REPORT.pPLANDP#1,
                           p_value => L_DP1);
    coreobj_api.get_jparam(p_obj_id => p_obj_id,
                           p_pname => COREOBJ_SQL_COMP_REPORT.pPLANDP#2,
                           p_value => L_DP2);

    select * into l_object from opas_objects where obj_id=p_obj_id;

    l_str := coreobj_api.get_object_path(p_obj_id => p_obj_id, p_including_object => 'Y');

    l_text:='Report: '||l_object.obj_name||chr(10);
    l_text:=l_text||'Path/Name: '||l_str||chr(10);
    l_text:=l_text||'Description: '||l_object.OBJ_DESCR||chr(10);

    select d.* into l_sql_data_point from OPAS_OT_SQL_DATA d where d.sql_data_point_id = L_DP1;
    select obj_id into l_obj_id from opas_ot_sql_data_point_ref where sql_data_point_id = L_DP1;

    l_str := coreobj_api.get_object_path(p_obj_id => l_obj_id, p_including_object => 'Y');
    select * into l_object from opas_objects where obj_id=l_obj_id;
    l_text:=l_text||'SQL Data Point #1'||chr(10);
    l_text:=l_text||'Path/SQL_ID: '||l_str||chr(10);
    l_text:=l_text||'DP ID: '||l_sql_data_point.sql_data_point_id||chr(10);
    l_text:=l_text||'Description: '||l_object.OBJ_DESCR||chr(10);

    select d.* into l_sql_data_point from OPAS_OT_SQL_DATA d where d.sql_data_point_id = L_DP2;
    select obj_id into l_obj_id from opas_ot_sql_data_point_ref where sql_data_point_id = L_DP2;

    l_str := coreobj_api.get_object_path(p_obj_id => l_obj_id, p_including_object => 'Y');
    select * into l_object from opas_objects where obj_id=l_obj_id;
    l_text:=l_text||'SQL Data Point #2'||chr(10);
    l_text:=l_text||'Path/SQL_ID: '||l_str||chr(10);
    l_text:=l_text||'DP ID: '||l_sql_data_point.sql_data_point_id||chr(10);
    l_text:=l_text||'Description: '||l_object.OBJ_DESCR||chr(10);

    COREMOD_REPORT_UTILS.convert_to_html_table (
          P_TEXT => l_text,
          P_INPUT => l_output,
          P_T_HEADER => '#FIRST_LINE#',
          P_WIDTH => 1000, --auto width
          --P_SEARCH => P_SEARCH,
          --P_REPLACEMENT => P_REPLACEMENT,
          --P_COMPARISON => P_COMPARISON,
          P_STYLE_TAB => 'trctd',
          P_STYLE_HEAD => 'trchd',
          P_STYLE_R1 => 'awrc1',--'trcr1',
          P_STYLE_R2 => 'awrnc1',--'trcr2',
          P_OUTPUT => l_output);
    for i in 1..l_output.count loop
        pipe row (l_output(i));
    end loop;
    l_output.delete;

    pipe row (HTF.BR);
    pipe row (HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
    pipe row (HTF.BR);
    pipe row (HTF.BR);

    for i in (select d.DISPLAY_VAL, d.SPARSE1, d.val section_name
                from OPAS_DICTIONARY d
               where d.MODNAME=COREMOD_API.getMODNAME
                 and d.DIC_NAME='SQLCOMPSECT'
               order by d.DIC_ORDR)
    loop
      if doprint(i.section_name) then
        pipe row (HTF.header (3,cheader=>HTF.ANCHOR (curl=>'',ctext=>i.DISPLAY_VAL,cname=>i.SPARSE1,cattributes=>'class="awr"'),cattributes=>'class="awr"'));

        case
          when i.section_name = repcoEXECPLAN then
            begin
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pPLANTP#1,
                                     p_value => L_PLANTP1);
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pMAINPLANSECTION,
                                     p_value => L_PLANOPT1);
              pipe row ('Source: '||
                        case
                          when L_PLANTP1 = ptMAIN then 'V$SQL_PLAN with display option: '||
                            case
                              when L_PLANOPT1 = 'SQLPLLAST' then 'LAST'
                              when L_PLANOPT1 = 'SQLPLADV' then 'LAST ADVANCED'
                              when L_PLANOPT1 = 'SQLPLALL' then 'ALL'
                              when L_PLANOPT1 = 'SQLPLADAPT' then 'ADAPTIVE'
                              else null end
                          when L_PLANTP1 = ptAWR then 'AWR Repository'
                          when L_PLANTP1 = ptEP then 'Explain Plan'
                          when L_PLANTP1 = ptHST then 'SQL Monitor History'
                         else null end
                        );
            end;
          when i.section_name = repcoVSQLSTAT then
            begin
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pCHLD#1,
                                     p_value => l_child_number);
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pPLNHASH#1,
                                     p_value => l_plan_hash_value);	
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pV$INST#1,
                                     p_value => l_inst_id);
              l_str := 'Left: INST_ID: '||l_inst_id||'; PLAN HASH: '||l_plan_hash_value||'; Child #: '||l_child_number;
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pCHLD#2,
                                     p_value => l_child_number);
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pPLNHASH#2,
                                     p_value => l_plan_hash_value);	
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pV$INST#2,
                                     p_value => l_inst_id);
              l_str := l_str||'. Right: INST_ID: '||l_inst_id||'; PLAN HASH: '||l_plan_hash_value||'; Child #: '||l_child_number;
              pipe row (l_str);
            end;
          when i.section_name = repcoAWRSTAT then
            begin
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pDBID#1,
                                     p_value => l_dbid);
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pSNAPS#1,
                                     p_value => l_snap1);	
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pSNAPE#1,
                                     p_value => l_snap2);
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pINST#1,
                                     p_value => l_inst_id);
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pPLNHASH#1,
                                     p_value => l_plan_hash_value);
              l_str := 'Left: Snaps: '||l_snap1||'-'||l_snap2||'; DBID: '||l_dbid||'; INST_ID: '||l_inst_id||'; PLAN HASH: '||l_plan_hash_value;
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pDBID#2,
                                     p_value => l_dbid);
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pSNAPS#2,
                                     p_value => l_snap1);	
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pSNAPE#2,
                                     p_value => l_snap2);
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pINST#2,
                                     p_value => l_inst_id);
              coreobj_api.get_jparam(p_obj_id => p_obj_id,
                                     p_pname => COREOBJ_SQL_COMP_REPORT.pPLNHASH#2,
                                     p_value => l_plan_hash_value);
              l_str := l_str || '. Right: Snaps: '||l_snap1||'-'||l_snap2||'; DBID: '||l_dbid||'; INST_ID: '||l_inst_id||'; PLAN HASH: '||l_plan_hash_value;
              pipe row (l_str);
            end;
          else
            null;
        end case;
        create_comprep_section(p_obj_id, i.section_name, l_output);
        for i in 1..l_output.count loop
          if length(l_output(i))>4000 then
            l_str := l_output(i);
            loop
              pipe row (substr(l_str,1,4000));
              l_str := substr(l_str,4000);
              exit when l_str is null;
            end loop;
          else
            pipe row (l_output(i));
          end if;
        end loop;

        l_output.delete;

        pipe row (HTF.BR);
        pipe row (HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
        pipe row (HTF.BR);
      end if;
    end loop;

    pipe row (HTF.BODYCLOSE);
    pipe row (HTF.HTMLCLOSE);

    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_SQL_COMP_REPORT.PRINT_REPORT_HTML.SQL_TRACE');
    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_SQL_COMP_REPORT.PRINT_REPORT_HTML.GATHER_SQL_STAT');
  end;

  function prepare_report_4download(p_obj_id  opas_objects.obj_id%type,
                                    p_section_list varchar2) return opas_files.file_id%type
  is
    l_file_id    opas_files.file_id%type;
    L_SQL_ID1   opas_ot_sql_data.sql_id%type;
    L_SQL_ID2   opas_ot_sql_data.sql_id%type;
    l_text                clob;
  begin

    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_SQL_COMP_REPORT.PREPARE_REPORT_4DOWNLOAD.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_SQL_COMP_REPORT.PREPARE_REPORT_4DOWNLOAD.SQL_TRACE');

    coreobj_api.extract_jparams(p_obj_id => p_obj_id);
    coreobj_api.get_jparam(p_obj_id => p_obj_id,
                           p_pname => COREOBJ_SQL_COMP_REPORT.pSQLID#1,
                           p_value => L_SQL_ID1);
    coreobj_api.get_jparam(p_obj_id => p_obj_id,
                           p_pname => COREOBJ_SQL_COMP_REPORT.pSQLID#1,
                           p_value => L_SQL_ID2);

    l_file_id := COREMOD_FILE_UTILS.create_tmp_4downl(
      P_FILE_NAME => 'opas60_sqlcomp_'||L_SQL_ID1||'_'||L_SQL_ID2||'.html',
      P_MIMETYPE => COREMOD_FILE_UTILS.mtHTML);

    for i in (select column_value from table(COREOBJ_SQL_COMP_REPORT.print_report_html(p_obj_id, p_section_list)))
    loop
      l_text := l_text || i.column_value || chr(10);
    end loop;

    COREMOD_FILE_UTILS.store_content (
       P_FILE_ID => l_file_id,
       P_CONTENT => l_text) ;

    coremod_file_utils.clob2blob_prep(p_file_id => l_file_id);

    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_SQL_COMP_REPORT.PREPARE_REPORT_4DOWNLOAD.SQL_TRACE');
    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_SQL_COMP_REPORT.PREPARE_REPORT_4DOWNLOAD.GATHER_SQL_STAT');

    return l_file_id;
  end;
end COREOBJ_SQL_COMP_REPORT;
/
