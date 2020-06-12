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
      P_OBJ_NAME  => nvl(p_name, 'SQL Comparison ' ||to_char(sysdate,'YYYYMMDD')),
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
                    p_c3        out COREMOD_REPORT_UTILS.t_output_lines,
                    p_max_width out number)
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

    r1       varchar2(1000);
    r2       varchar2(1000);
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
      l_trailing_space number;
    BEGIN
      p_tab := COREMOD_REPORT_UTILS.t_arrayofstrings();
      if instr(p_list,'|') > 0 then l_sep := '|';end if;
      if instr(p_list,'Plan hash value') > 0 then l_sep := ':';end if;
      l_trailing_space:=nvl(length(l_string),0)-nvl(length(trim(l_string)),0);
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
    p_max_width :=0;
    for j in 1 .. p_txt1.count loop
      if length(p_txt1(j)) > p_max_width then
        p_max_width := length(p_txt1(j));
      end if;
    end loop;
    for j in 1 .. p_txt2.count loop
      if length(p_txt2(j)) > p_max_width then
        p_max_width := length(p_txt2(j));
      end if;
    end loop;

    l_text_rowcnt := greatest(p_txt1.count, p_txt2.count);

    --aligning sections
    if p_flags = flgSQLPLAN then
      for i in 1..p_txt1.count loop
        for j in 1..g_plan_sections_all.count loop
          if instr(p_txt1(i),g_plan_sections_all(j))>0 then
            l_available_sections(g_plan_sections_all(j)):=1;
          end if;
        end loop;
      end loop;

      for i in 1..p_txt2.count loop
        for j in 1..g_plan_sections_all.count loop
          if instr(p_txt2(i),g_plan_sections_all(j))>0 then
            l_available_sections(g_plan_sections_all(j)):=1;
          end if;
        end loop;
      end loop;

      for j in 1..g_plan_sections_all.count loop
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

      for i in 1..p_txt1.count loop
        if instr(p_txt1(i),l_plan_sections(l_cnt))>0 then l_curr_section:=l_cnt; if l_cnt<l_plan_sections.count then l_cnt:=l_cnt+1; end if; end if;
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
                              p_max_width number,
                              p_output    out COREMOD_REPORT_UTILS.t_output_lines) is
    l_stat_ln   number := 40;
    r_stats1    r_sqlstat_base_crsr;
    r_stats2    r_sqlstat_base_crsr;

    procedure pr1(p_msg varchar2) is begin p_output(p_output.count+1):=p_msg; end;
    procedure pr(length1 number,length2 number, par1 varchar2, par2 varchar2, par3 varchar2 default null)
    is
      delim1 varchar2(10) := '*';
      delim2 varchar2(10) := '';
    begin
      pr1(rpad(par1, length1, ' ') || delim1 ||rpad(par2, length2, ' ')|| delim2 ||rpad(par3, length1, ' '));
    end;
  begin
    fetch p_stats1 into r_stats1;
    fetch p_stats2 into r_stats2;

    pr(p_max_width,l_stat_ln,'Metric             Value',                          'Metric             Value',    'Delta, %            Delta to ELA/EXEC, %');
    pr(p_max_width,l_stat_ln,'EXECS:             '||r_stats1.EXECUTIONS_DELTA,    'EXECS:             '||r_stats2.EXECUTIONS_DELTA,    round(100*((r_stats2.EXECUTIONS_DELTA-r_stats1.EXECUTIONS_DELTA)        /(case when r_stats1.EXECUTIONS_DELTA=0 then case when r_stats2.EXECUTIONS_DELTA=0 then 1 else r_stats2.EXECUTIONS_DELTA end else r_stats1.EXECUTIONS_DELTA end)),2)||'%');
    pr(p_max_width,l_stat_ln,'ELA/EXEC(MS):      '||r_stats1.ela_poe,             'ELA/EXEC(MS):      '||r_stats2.ela_poe,             round(100*((r_stats2.ela_poe-r_stats1.ela_poe)                          /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
    pr(p_max_width,l_stat_ln,'LIO/EXEC:          '||r_stats1.LIO_poe,             'LIO/EXEC:          '||r_stats2.LIO_poe,             round(100*((r_stats2.LIO_poe-r_stats1.LIO_poe)                          /(case when r_stats1.LIO_poe=0 then case when r_stats2.LIO_poe=0 then 1 else r_stats2.LIO_poe end else r_stats1.LIO_poe end)),2)||'%');
    pr(p_max_width,l_stat_ln,'CPU/EXEC(MS):      '||r_stats1.CPU_poe,             'CPU/EXEC(MS):      '||r_stats2.CPU_poe,             rpad(round(100*((r_stats2.CPU_poe-r_stats1.CPU_poe)                     /(case when r_stats1.CPU_poe=0 then case when r_stats2.CPU_poe=0 then 1 else r_stats2.CPU_poe end else r_stats1.CPU_poe end)),2)||'%',20,' ')||
        round(100*((r_stats2.CPU_poe-r_stats1.CPU_poe)                          /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
    pr(p_max_width,l_stat_ln,'IOWAIT/EXEC(MS):   '||r_stats1.IOWAIT_poe,          'IOWAIT/EXEC(MS):   '||r_stats2.IOWAIT_poe,          rpad(round(100*((r_stats2.IOWAIT_poe-r_stats1.IOWAIT_poe)               /(case when r_stats1.IOWAIT_poe=0 then case when r_stats2.IOWAIT_poe=0 then 1 else r_stats2.IOWAIT_poe end else r_stats1.IOWAIT_poe end)),2)||'%',20,' ')||
        round(100*((r_stats2.IOWAIT_poe-r_stats1.IOWAIT_poe)                    /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
    pr(p_max_width,l_stat_ln,'CCWAIT/EXEC(MS):   '||r_stats1.CCWAIT_poe,          'CCWAIT/EXEC(MS):   '||r_stats2.CCWAIT_poe,          rpad(round(100*((r_stats2.CCWAIT_poe-r_stats1.CCWAIT_poe)               /(case when r_stats1.CCWAIT_poe=0 then case when r_stats2.CCWAIT_poe=0 then 1 else r_stats2.CCWAIT_poe end else r_stats1.CCWAIT_poe end)),2)||'%',20,' ')||
        round(100*((r_stats2.CCWAIT_poe-r_stats1.CCWAIT_poe)                    /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
    pr(p_max_width,l_stat_ln,'APWAIT/EXEC(MS):   '||r_stats1.APWAIT_poe,          'APWAIT/EXEC(MS):   '||r_stats2.APWAIT_poe,          rpad(round(100*((r_stats2.APWAIT_poe-r_stats1.APWAIT_poe)               /(case when r_stats1.APWAIT_poe=0 then case when r_stats2.APWAIT_poe=0 then 1 else r_stats2.APWAIT_poe end else r_stats1.APWAIT_poe end)),2)||'%',20,' ')||
        round(100*((r_stats2.APWAIT_poe-r_stats1.APWAIT_poe)                    /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');
    pr(p_max_width,l_stat_ln,'CLWAIT/EXEC(MS):   '||r_stats1.CLWAIT_poe,          'CLWAIT/EXEC(MS):   '||r_stats2.CLWAIT_poe,          rpad(round(100*((r_stats2.CLWAIT_poe-r_stats1.CLWAIT_poe)               /(case when r_stats1.CLWAIT_poe=0 then case when r_stats2.CLWAIT_poe=0 then 1 else r_stats2.CLWAIT_poe end else r_stats1.CLWAIT_poe end)),2)||'%',20,' ')||
        round(100*((r_stats2.CLWAIT_poe-r_stats1.CLWAIT_poe)                    /(case when r_stats1.ela_poe=0 then case when r_stats2.ela_poe=0 then 1 else r_stats2.ela_poe end else r_stats1.ela_poe end)),2)||'%');

    pr(p_max_width,l_stat_ln,'READS/EXEC:        '||r_stats1.reads_poe,           'READS/EXEC:        '||r_stats2.reads_poe,           round(100*((r_stats2.reads_poe-r_stats1.reads_poe)                      /(case when r_stats1.reads_poe=0 then case when r_stats2.reads_poe=0 then 1 else r_stats2.reads_poe end else r_stats1.reads_poe end)),2)||'%');
    pr(p_max_width,l_stat_ln,'WRITES/EXEC:       '||r_stats1.dwrites_poe,         'WRITES/EXEC:       '||r_stats2.dwrites_poe,         round(100*((r_stats2.dwrites_poe-r_stats1.dwrites_poe)                  /(case when r_stats1.dwrites_poe=0 then case when r_stats2.dwrites_poe=0 then 1 else r_stats2.dwrites_poe end else r_stats1.dwrites_poe end)),2)||'%');

    pr(p_max_width,l_stat_ln,'ROWS/EXEC:         '||r_stats1.Rows_poe,            'ROWS/EXEC:         '||r_stats2.Rows_poe,            round(100*((r_stats2.Rows_poe-r_stats1.Rows_poe)                        /(case when r_stats1.Rows_poe=0 then case when r_stats2.Rows_poe=0 then 1 else r_stats2.Rows_poe end else r_stats1.Rows_poe end)),2)||'%');
    pr(p_max_width,l_stat_ln,'ELA(SEC):          '||r_stats1.ELA_DELTA_SEC,       'ELA(SEC):          '||r_stats2.ELA_DELTA_SEC,       round(100*((r_stats2.ELA_DELTA_SEC-r_stats1.ELA_DELTA_SEC)              /(case when r_stats1.ELA_DELTA_SEC=0 then case when r_stats2.ELA_DELTA_SEC=0 then 1 else r_stats2.ELA_DELTA_SEC end else r_stats1.ELA_DELTA_SEC end)),2)||'%');
    pr(p_max_width,l_stat_ln,'CPU(SEC):          '||r_stats1.CPU_DELTA_SEC,       'CPU(SEC):          '||r_stats2.CPU_DELTA_SEC,       round(100*((r_stats2.CPU_DELTA_SEC-r_stats1.CPU_DELTA_SEC)              /(case when r_stats1.CPU_DELTA_SEC=0 then case when r_stats2.CPU_DELTA_SEC=0 then 1 else r_stats2.CPU_DELTA_SEC end else r_stats1.CPU_DELTA_SEC end)),2)||'%');

    pr(p_max_width,l_stat_ln,'IOWAIT(SEC):       '||r_stats1.IOWAIT_DELTA_SEC,    'IOWAIT(SEC):       '||r_stats2.IOWAIT_DELTA_SEC,    round(100*((r_stats2.IOWAIT_DELTA_SEC-r_stats1.IOWAIT_DELTA_SEC)        /(case when r_stats1.IOWAIT_DELTA_SEC=0 then case when r_stats2.IOWAIT_DELTA_SEC=0 then 1 else r_stats2.IOWAIT_DELTA_SEC end else r_stats1.IOWAIT_DELTA_SEC end)),2)||'%');
    pr(p_max_width,l_stat_ln,'CCWAIT(SEC):       '||r_stats1.CCWAIT_DELTA_SEC,    'CCWAIT(SEC):       '||r_stats2.CCWAIT_DELTA_SEC,    round(100*((r_stats2.CCWAIT_DELTA_SEC-r_stats1.CCWAIT_DELTA_SEC)        /(case when r_stats1.CCWAIT_DELTA_SEC=0 then case when r_stats2.CCWAIT_DELTA_SEC=0 then 1 else r_stats2.CCWAIT_DELTA_SEC end else r_stats1.CCWAIT_DELTA_SEC end)),2)||'%');
    pr(p_max_width,l_stat_ln,'APWAIT(SEC):       '||r_stats1.APWAIT_DELTA_SEC,    'APWAIT(SEC):       '||r_stats2.APWAIT_DELTA_SEC,    round(100*((r_stats2.APWAIT_DELTA_SEC-r_stats1.APWAIT_DELTA_SEC)        /(case when r_stats1.APWAIT_DELTA_SEC=0 then case when r_stats2.APWAIT_DELTA_SEC=0 then 1 else r_stats2.APWAIT_DELTA_SEC end else r_stats1.APWAIT_DELTA_SEC end)),2)||'%');
    pr(p_max_width,l_stat_ln,'CLWAIT(SEC):       '||r_stats1.CLWAIT_DELTA_SEC,    'CLWAIT(SEC):       '||r_stats2.CLWAIT_DELTA_SEC,    round(100*((r_stats2.CLWAIT_DELTA_SEC-r_stats1.CLWAIT_DELTA_SEC)        /(case when r_stats1.CLWAIT_DELTA_SEC=0 then case when r_stats2.CLWAIT_DELTA_SEC=0 then 1 else r_stats2.CLWAIT_DELTA_SEC end else r_stats1.CLWAIT_DELTA_SEC end)),2)||'%');

    pr(p_max_width,l_stat_ln,'READS:             '||r_stats1.DISK_READS_DELTA,    'READS:             '||r_stats2.DISK_READS_DELTA,    round(100*((r_stats2.DISK_READS_DELTA-r_stats1.DISK_READS_DELTA)        /(case when r_stats1.DISK_READS_DELTA=0 then case when r_stats2.DISK_READS_DELTA=0 then 1 else r_stats2.DISK_READS_DELTA end else r_stats1.DISK_READS_DELTA end)),2)||'%');
    pr(p_max_width,l_stat_ln,'DIR WRITES:        '||r_stats1.DISK_WRITES_DELTA,   'DIR WRITES:        '||r_stats2.DISK_WRITES_DELTA,   round(100*((r_stats2.DISK_WRITES_DELTA-r_stats1.DISK_WRITES_DELTA)      /(case when r_stats1.DISK_WRITES_DELTA=0 then case when r_stats2.DISK_WRITES_DELTA=0 then 1 else r_stats2.DISK_WRITES_DELTA end else r_stats1.DISK_WRITES_DELTA end)),2)||'%');

    pr(p_max_width,l_stat_ln,'READ REQ:          '||r_stats1.PHY_READ_REQ_DELTA,  'READ REQ:          '||r_stats2.PHY_READ_REQ_DELTA,  round(100*((r_stats2.PHY_READ_REQ_DELTA-r_stats1.PHY_READ_REQ_DELTA)    /(case when r_stats1.PHY_READ_REQ_DELTA=0 then case when r_stats2.PHY_READ_REQ_DELTA=0 then 1 else r_stats2.PHY_READ_REQ_DELTA end else r_stats1.PHY_READ_REQ_DELTA end)),2)||'%');
    pr(p_max_width,l_stat_ln,'WRITE REQ:         '||r_stats1.PHY_WRITE_REQ_DELTA, 'WRITE REQ:         '||r_stats2.PHY_WRITE_REQ_DELTA, round(100*((r_stats2.PHY_WRITE_REQ_DELTA-r_stats1.PHY_WRITE_REQ_DELTA)  /(case when r_stats1.PHY_WRITE_REQ_DELTA=0 then case when r_stats2.PHY_WRITE_REQ_DELTA=0 then 1 else r_stats2.PHY_WRITE_REQ_DELTA end else r_stats1.PHY_WRITE_REQ_DELTA end)),2)||'%');


    pr(p_max_width,l_stat_ln,'LIO:               '||r_stats1.BUFFER_GETS_DELTA,   'LIO:               '||r_stats2.BUFFER_GETS_DELTA,   round(100*((r_stats2.BUFFER_GETS_DELTA-r_stats1.BUFFER_GETS_DELTA)      /(case when r_stats1.BUFFER_GETS_DELTA=0 then case when r_stats2.BUFFER_GETS_DELTA=0 then 1 else r_stats2.BUFFER_GETS_DELTA end else r_stats1.BUFFER_GETS_DELTA end)),2)||'%');
    pr(p_max_width,l_stat_ln,'ROWS:              '||r_stats1.ROWS_PROCESSED_DELTA,'ROWS:              '||r_stats2.ROWS_PROCESSED_DELTA,round(100*((r_stats2.ROWS_PROCESSED_DELTA-r_stats1.ROWS_PROCESSED_DELTA)/(case when r_stats1.ROWS_PROCESSED_DELTA=0 then case when r_stats2.ROWS_PROCESSED_DELTA=0 then 1 else r_stats2.ROWS_PROCESSED_DELTA end else r_stats1.ROWS_PROCESSED_DELTA end)),2)||'%');
    pr(p_max_width,l_stat_ln,'LIO/ROW:           '||r_stats1.LIO_PER_ROW,         'LIO/ROW:           '||r_stats2.LIO_PER_ROW,         round(100*((r_stats2.LIO_PER_ROW-r_stats1.LIO_PER_ROW)                  /(case when r_stats1.LIO_PER_ROW=0 then case when r_stats2.LIO_PER_ROW=0 then 1 else r_stats2.LIO_PER_ROW end else r_stats1.LIO_PER_ROW end)),2)||'%');
    pr(p_max_width,l_stat_ln,'PIO/ROW:           '||r_stats1.IO_PER_ROW,          'PIO/ROW:           '||r_stats2.IO_PER_ROW,          round(100*((r_stats2.IO_PER_ROW-r_stats1.IO_PER_ROW)                    /(case when r_stats1.IO_PER_ROW=0 then case when r_stats2.IO_PER_ROW=0 then 1 else r_stats2.IO_PER_ROW end else r_stats1.IO_PER_ROW end)),2)||'%');
    pr(p_max_width,l_stat_ln,'CPU/ROW:           '||r_stats1.CPU_PER_ROW,         'CPU/ROW:           '||r_stats2.CPU_PER_ROW,         round(100*((r_stats2.CPU_PER_ROW-r_stats1.CPU_PER_ROW)                  /(case when r_stats1.CPU_PER_ROW=0 then case when r_stats2.CPU_PER_ROW=0 then 1 else r_stats2.CPU_PER_ROW end else r_stats1.CPU_PER_ROW end)),2)||'%');
    pr(p_max_width,l_stat_ln,'AVG IO (MS):       '||r_stats1.awg_IO_tim,          'AVG IO (MS):       '||r_stats2.awg_IO_tim,          round(100*((r_stats2.awg_IO_tim-r_stats1.awg_IO_tim)                    /(case when r_stats1.awg_IO_tim=0 then case when r_stats2.awg_IO_tim=0 then 1 else r_stats2.awg_IO_tim end else r_stats1.awg_IO_tim end)),2)||'%');
    --pr(p_max_width,l_stat_ln,'IOWT/EXEC(MS)5ms:  '||r_stats1.io_wait_pe_5ms,      'IOWT/EXEC(MS)5ms:  '||r_stats2.io_wait_pe_5ms,      round(100*((r_stats2.io_wait_pe_5ms-r_stats1.io_wait_pe_5ms)            /(case when r_stats1.io_wait_pe_5ms=0 then case when r_stats2.io_wait_pe_5ms=0 then 1 else r_stats2.io_wait_pe_5ms end else r_stats1.io_wait_pe_5ms end)),2)||'%');
    --pr(p_max_width,l_stat_ln,'IOWAIT(SEC)5ms:    '||r_stats1.io_wait_5ms,         'IOWAIT(SEC)5ms:    '||r_stats2.io_wait_5ms,         round(100*((r_stats2.io_wait_5ms-r_stats1.io_wait_5ms)                  /(case when r_stats1.io_wait_5ms=0 then case when r_stats2.io_wait_5ms=0 then 1 else r_stats2.io_wait_5ms end else r_stats1.io_wait_5ms end)),2)||'%');
  end;

  function getsqltext(p_sql_id varchar2,
                      p_width  number default null) return COREMOD_REPORT_UTILS.t_output_lines
  is
    l_file_id   opas_files.file_id%type;
    l_output    COREMOD_REPORT_UTILS.t_output_lines;
    l_max_width number := 0;
  begin
    select nvl(sql_text,sql_text_approx) into l_file_id from OPAS_OT_SQL_DESCRIPTIONS de where sql_id=p_sql_id;
    for i in (SELECT line_number, payload
                FROM V$OPAS_FILE_CONTENTBYROW
               where file_id=l_file_id
               order by line_number)
    loop
      l_output(i.line_number) := rtrim(apex_escape.html(i.payload));
      if length(l_output(i.line_number)) > l_max_width then l_max_width := length(l_output(i.line_number)); end if;
    end loop;
    for i in 1..l_output.count loop
      l_output(i) := rpad(l_output(i),l_max_width,' ');
    end loop;
    return l_output;
  end;

  procedure read_awr_plan(p_plan_id    opas_ot_sql_awr_plan_det.plan_id%type,
                          p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
    l_display_params varchar2(100);
  begin
    l_display_params:='ADVANCED';

    COREMOD_REPORT_UTILS.print_query_result_html (
                                            p_query => replace(replace(
q'[select plan_table_output "Plan Table Output" from table(dbms_xplan.display('OPAS_OT_SQL_AWR_PLAN_DET', null, '<display_params>', 'plan_id=<PLAN_ID>'))]' --'
                                              ,'<PLAN_ID>',p_plan_id)
                                              ,'<display_params>',l_display_params),--'
                                            p_width => COREOBJ_SQL_REPORT_UTILS.gwWideSection1,
                                            p_summary => 'AWR execution plan',
                                            p_search => null, -- 'Plan hash value: ([[:digit:]]*)',
                                            p_replacement => null, --HTF.ANCHOR(curl=>'#epplan_\1',ctext=>'Plan hash value: \1',cname=>'awrplan_\1',cattributes=>'class="awr"'),
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            --p_header number default 0,
                                            --p_break_col => 'inst_id',
                                            p_output => read_awr_plan.p_output);
  end;

  procedure read_plan_ep(p_plan_id       opas_ot_sql_ep_plan_det.plan_id%type,
                         p_output    out COREMOD_REPORT_UTILS.t_output_lines) AS
    l_display_params varchar2(100);
  begin
/*
      p_output(1):=HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Explain plan (simple)',cname=>'dp_ep_smpl',cattributes=>'class="awr"'),cattributes=>'class="awr"');

      p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#dp_ep_smpl',ctext=>'Explain plan (simple)',cattributes=>'class="awr"'));
      p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#dp_ep_adv',ctext=>'Explain plan (advanced)',cattributes=>'class="awr"'));
      p_output(p_output.count+1):=HTF.BR;

      COREMOD_REPORT_UTILS.print_query_result_html (
                                            p_query => replace(replace(
q'[select plan_table_output "Plan Table Output" from table(dbms_xplan.display('OPAS_OT_SQL_EP_PLAN_DET', null, null, 'plan_id=<PLAN_ID>'))]' --'
                                              ,'<PLAN_ID>',p_plan_id)
                                              ,'<display_params>',l_display_params),--'
                                            p_width => COREOBJ_SQL_REPORT_UTILS.gwWideSection1,
                                            p_summary => 'Execution plan',
                                            p_search => null, --'Plan hash value: ([[:digit:]]*)',
                                            p_replacement => null, --HTF.ANCHOR(curl=>'#epplanadv_\1',ctext=>'Plan hash value: \1',cname=>'epplan_\1',cattributes=>'class="awr"'),
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            --p_header number default 0,
                                            --p_break_col => 'inst_id',
                                            p_output => read_plan_ep.p_output);

      p_output(p_output.count+1):=HTF.BR;

      p_output(p_output.count+1):=HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Explain plan (advanced)',cname=>'dp_ep_adv',cattributes=>'class="awr"'),cattributes=>'class="awr"');

      p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#dp_ep_smpl',ctext=>'Explain plan (simple)',cattributes=>'class="awr"'));
      p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#dp_ep_adv',ctext=>'Explain plan (advanced)',cattributes=>'class="awr"'));
      p_output(p_output.count+1):=HTF.BR;

      l_display_params := 'ADVANCED';
*/
      COREMOD_REPORT_UTILS.print_query_result_html (
                                            p_query => replace(replace(
q'[select plan_table_output "Plan Table Output" from table(dbms_xplan.display('OPAS_OT_SQL_EP_PLAN_DET', null, 'ADVANCED', 'plan_id=<PLAN_ID>'))]' --'
                                              ,'<PLAN_ID>',p_plan_id)
                                              ,'<display_params>',l_display_params),--'
                                            p_width => COREOBJ_SQL_REPORT_UTILS.gwWideSection1,
                                            p_summary => 'Execution plan (advanced)',
                                            p_search => null, --'Plan hash value: ([[:digit:]]*)',
                                            p_replacement => null, --HTF.ANCHOR(curl=>'',ctext=>'Plan hash value: \1',cname=>'epplanadv_\1',cattributes=>'class="awr"'),
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            --p_header number default 0,
                                            --p_break_col => 'inst_id',
                                            p_output => read_plan_ep.p_output);
  end;

  procedure read_plan_main(p_plan_id       opas_ot_sql_awr_plan_det.plan_id%type,
                           p_section_name  varchar2,
                           p_output    out COREMOD_REPORT_UTILS.t_output_lines) AS
    l_display_params varchar2(100);
  begin

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

    COREMOD_REPORT_UTILS.print_query_result_html (
                                            p_query => replace(replace(
q'[select plan_table_output "Plan Table Output" from table(dbms_xplan.display('OPAS_OT_SQL_PLAN_DET', null, '<display_params>', 'plan_id=<PLAN_ID>'))]'--'
                                              ,'<PLAN_ID>',p_plan_id)
                                              ,'<display_params>',l_display_params),--'
                                            p_width => COREOBJ_SQL_REPORT_UTILS.gwWideSection1,
                                            p_summary => 'Execution plan',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            --p_header number default 0,
                                            --p_break_col => 'inst_id',
                                            p_output => read_plan_main.p_output);

  end;


  function getsqlplan(p_obj_id           opas_objects.obj_id%type,
                      p_num              number) return COREMOD_REPORT_UTILS.t_output_lines
  is
    --l_file_id   opas_files.file_id%type;
    l_output    COREMOD_REPORT_UTILS.t_output_lines;
    l_max_width number := 0;

    l_plan_tp   varchar2(10);
    l_plan_id   varchar2(10);
    l_section_name  varchar2(100);
  begin
    case p_num
      when 1 then
        coreobj_api.get_jparam(p_obj_id,pPLANTP#1,l_plan_tp);
        coreobj_api.get_jparam(p_obj_id,pPLANID#1,l_plan_id);
      when 2 then
        coreobj_api.get_jparam(p_obj_id,pPLANTP#2,l_plan_tp);
        coreobj_api.get_jparam(p_obj_id,pPLANID#2,l_plan_id);
    end case;

    case l_plan_tp
      when ptAWR then read_awr_plan(l_plan_id, l_output);
      when ptEP  then read_plan_ep(l_plan_id, l_output);
      when ptMAIN then
        coreobj_api.get_jparam(p_obj_id,pMAINPLANSECTION,l_section_name);
        read_plan_main(l_plan_id, l_section_name, l_output);
    end case;

    for i in 1..l_output.count loop
      l_output(i) := rpad(l_output(i),l_max_width,' ');
    end loop;
    return l_output;
  end;

  procedure comprep_section_sqltext(p_obj_id           opas_objects.obj_id%type,
                                    p_output    out COREMOD_REPORT_UTILS.t_output_lines)
  is
    l_max_width number;
    l_output    COREMOD_REPORT_UTILS.t_output_lines;
    l_c1        COREMOD_REPORT_UTILS.t_output_lines;
    l_c2        COREMOD_REPORT_UTILS.t_output_lines;
    l_c3        COREMOD_REPORT_UTILS.t_output_lines;
    l_sql1      varchar2(100);
    l_sql2      varchar2(100);
  begin
    coreobj_api.extract_jparams(p_obj_id);
    coreobj_api.get_jparam(p_obj_id,pSQLID#1,l_sql1);
    coreobj_api.get_jparam(p_obj_id,pSQLID#2,l_sql2);

    COREOBJ_SQL_COMP_REPORT.compare
                    (getsqltext(l_sql1),
                     getsqltext(l_sql2),
                     flgTEXT,
                     l_output,
                     l_c1,
                     l_c2,
                     l_c3,
                     l_max_width);

     COREMOD_REPORT_UTILS.print_3arrays
                (p_t_header   => 'Comparison of '||l_sql1||' and '||l_sql2||' texts',
                 p_width      => 0,
                 p_style_r1   => 'awrc1', --odd rows
                 p_style_r2   => 'awrnc1', --even rows
                 p_style_head => 'trchd',
                 p_style_tab  => 'trctd',
                 p_output     => comprep_section_sqltext.p_output,
                 p_col1       => l_c1,
                 p_col2       => l_c2,
                 p_col3       => l_c3);

    coreobj_api.add_jparam(p_obj_id,pMAX_WIDTH,l_max_width);
    coreobj_api.store_jparams(p_obj_id);
  end;

  procedure comprep_section_sqlplan(p_obj_id           opas_objects.obj_id%type,
                                    p_output    out COREMOD_REPORT_UTILS.t_output_lines)
  is
    l_max_width number;
    l_output    COREMOD_REPORT_UTILS.t_output_lines;
    l_c1    COREMOD_REPORT_UTILS.t_output_lines;
    l_c2    COREMOD_REPORT_UTILS.t_output_lines;
    l_c3    COREMOD_REPORT_UTILS.t_output_lines;
    l_sql1      varchar2(100);
    l_sql2      varchar2(100);
  begin
    coreobj_api.extract_jparams(p_obj_id);
    coreobj_api.get_jparam(p_obj_id,pSQLID#1,l_sql1);
    coreobj_api.get_jparam(p_obj_id,pSQLID#2,l_sql2);

    COREOBJ_SQL_COMP_REPORT.compare
                    (getsqlplan(p_obj_id, l_sql1),
                     getsqlplan(p_obj_id, l_sql2),
                     flgSQLPLAN,
                     l_output,
                     l_c1,
                     l_c2,
                     l_c3,
                     l_max_width);
    coreobj_api.add_jparam(p_obj_id,pMAX_WIDTH,l_max_width);

    COREMOD_REPORT_UTILS.print_3arrays
                (p_t_header   => 'SQL Execution Plan Comparison of '||l_sql1||' and '||l_sql2,
                 p_width      => 0,
                 p_style_r1   => 'awrc1', --odd rows
                 p_style_r2   => 'awrnc1', --even rows
                 p_style_head => 'trchd',
                 p_style_tab  => 'trctd',
                 p_output     => comprep_section_sqlplan.p_output,
                 p_col1       => l_c1,
                 p_col2       => l_c2,
                 p_col3       => l_c3);

    coreobj_api.store_jparams(p_obj_id);
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
    l_dp_id1 number;
    l_dp_id2 number;
    l_chld1  number;
    l_chld2  number;
    l_plhs1        number;
    l_plhs2        number;
  begin
    coreobj_api.get_jparam(p_obj_id,pDP_ID#1,l_dp_id1);
    coreobj_api.get_jparam(p_obj_id,pDP_ID#2,l_dp_id2);
    coreobj_api.get_jparam(p_obj_id,pCHLD#1,l_chld1);
    coreobj_api.get_jparam(p_obj_id,pCHLD#2,l_chld2);
    coreobj_api.get_jparam(p_obj_id,pPLNHASH#1,l_plhs1);
    coreobj_api.get_jparam(p_obj_id,pPLNHASH#2,l_plhs2);

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
    --group by s.plan_hash_value,s.sql_id
    ;
  end;

  procedure comprep_section_stats(p_obj_id           opas_objects.obj_id%type,
                                  p_output    out COREMOD_REPORT_UTILS.t_output_lines)
  is
    l_output    COREMOD_REPORT_UTILS.t_output_lines;
    l_stattp    varchar2(100);

    c1 COREOBJ_SQL_COMP_REPORT.t_sqlstat_base_crsr;
    c2 COREOBJ_SQL_COMP_REPORT.t_sqlstat_base_crsr;
  begin
    coreobj_api.extract_jparams(p_obj_id);
    coreobj_api.get_jparam(p_obj_id,pSTATTP,l_stattp);
    --coreobj_api.get_jparam(p_obj_id,pSQLID#2,l_sql2);

    case l_stattp
      when stAWR then   stats_open_awr_crsr(p_obj_id,c1,c2);
      when stV$SQL then stats_open_vsql_crsr(p_obj_id,c1,c2);
    end case;

    COREOBJ_SQL_COMP_REPORT.compare_sql_stats(p_stats1    => c1,
                                              p_stats2    => c2,
                                              p_max_width => 50,
                                              p_output    => l_output);

    COREMOD_REPORT_UTILS.convert_to_html_table (
        P_TEXT => null,
        P_INPUT => l_output,
        P_T_HEADER => 'TEST',
        P_WIDTH => 5000,
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
      when repcoVSQLSTAT then comprep_section_stats (p_obj_id, p_output);
      when repcoAWRSTAT  then comprep_section_stats (p_obj_id, p_output);
      when repcoAWRSTAT  then null;           -- AWR statistics
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

end COREOBJ_SQL_COMP_REPORT;
/
