CREATE OR REPLACE
PACKAGE BODY COREOBJ_SQL_REPORT_UTILS AS

  function get_header_refresh_interval(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type) return number
  is
    l_refresh_interval number := 5;
  begin
    for i in (select gathering_status from opas_ot_sql_data x where sql_data_point_id = p_sql_data_point_id) loop
      if i.gathering_status not in (COREOBJ_SQL.sdoREADY,COREOBJ_SQL.sdoFAILED) then
        l_refresh_interval := 5;
      else
        l_refresh_interval := null;
      end if;
    end loop;
    return l_refresh_interval;
  end;

  function print_data_point_params(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type) return varchar2
  result_cache
  is
    l_result varchar2(32765) :=
      '<br><b>SQL Monitor:</b> Days=<SQLMONHSTDays>; Rows=<SQLMONHSTRows>; <b>AWR:</b> Days=<AWRDataDays>; Search last day=<AWRSearchLastDays>; Start Date=<AWRStartDT>; End Date=<AWREndDT>; <b>Recursive:</b> <RECURS>';
    l_obj_id     opas_ot_sql_data_point_ref.obj_id%type;
    l_recursive  varchar2(100);
    l_rec_v$     number;
    l_rec_awr    number;
  begin
    select obj_id into l_obj_id from opas_ot_sql_data_point_ref where sql_data_point_id = p_sql_data_point_id;
    l_result := replace(l_result, '<SQLMONHSTDays>',     nvl( COREOBJ_API.get_param_n(l_obj_id, COREOBJ_SQL_UTILS.pnSQLMONHSTDays,     true), COREOBJ_SQL_UTILS.defSQLMONHSTDays));
    l_result := replace(l_result, '<SQLMONHSTRows>',     nvl( COREOBJ_API.get_param_n(l_obj_id, COREOBJ_SQL_UTILS.pnSQLMONHSTRows,     true), COREOBJ_SQL_UTILS.defSQLMONHSTRows));
    l_result := replace(l_result, '<AWRDataDays>',       nvl( COREOBJ_API.get_param_n(l_obj_id, COREOBJ_SQL_UTILS.pnAWRDataDays,       true), COREOBJ_SQL_UTILS.defAWRDataDays));
    l_result := replace(l_result, '<AWRSearchLastDays>', nvl( COREOBJ_API.get_param_c(l_obj_id, COREOBJ_SQL_UTILS.pnAWRSearchLastDays, true), COREOBJ_SQL_UTILS.defAWRSearchLastDays));

    l_result := replace(l_result, '<AWRStartDT>', nvl(to_char( COREOBJ_API.get_param_d(l_obj_id, COREOBJ_SQL_UTILS.pnAWRStartDT, true), defDataTimeFmt),'Not Specified'));
    l_result := replace(l_result, '<AWREndDT>',   nvl(to_char( COREOBJ_API.get_param_d(l_obj_id, COREOBJ_SQL_UTILS.pnAWREndDT,   true), defDataTimeFmt),'Not Specified'));

    l_rec_v$  := nvl(COREOBJ_API.get_param_n(l_obj_id, COREOBJ_SQL_UTILS.pnV$Recursive,    true), COREOBJ_SQL_UTILS.defV$Recursive);
    l_rec_awr := nvl(COREOBJ_API.get_param_n(l_obj_id, COREOBJ_SQL_UTILS.pnAWRRecursive,   true), COREOBJ_SQL_UTILS.defAWRRecursive);
    l_recursive := case when l_rec_v$  >=0 then 'V$ASH limit: '  ||l_rec_v$  else 'No V$ASH'   end || '/' ||
                   case when l_rec_awr >=0 then 'ASH HST limit: '||l_rec_awr else 'No ASH HST' end;

    l_result := replace(l_result, '<RECURS>', l_recursive);
    return l_result;
  end;

  function gathering_status(p_obj_id  opas_objects.obj_id%type) return TABLEOFSTRINGS pipelined
  is
    l_status   opas_ot_sql_data.GATHERING_STATUS%type;
    l_duration varchar2(1000);
    l_sections varchar2(1000);
  begin
    loop
      begin
      select GATHERING_STATUS, to_char(cast((nvl(d.END_GATHERING_DT,systimestamp)-d.START_GATHERING_DT) AS INTERVAL DAY(2) TO SECOND(3))),
                     (select listagg(gathering_status||': '||cnt,'; ') within group (order by gathering_status)
                        from (select gathering_status, count(1) cnt
                                from OPAS_OT_SQL_DATA_SECT i where i.sql_data_point_id = d.sql_data_point_id group by gathering_status)) sect_statuses
        into l_status, l_duration, l_sections
        from opas_ot_sql_data d, OPAS_OT_SQL_DATA_POINT_REF r
       where d.sql_data_point_id=r.sql_data_point_id and r.obj_id=p_obj_id;
      exception
        when no_data_found then l_status := 'NOTFOUND';
      end;
      if l_status = 'NOTFOUND' then
        pipe row ('SQL Data is not found.');
        exit;
      elsif l_status = 'INQUEUE' then
        pipe row ('Data gathering has been queued...');
        dbms_lock.sleep(5);
      elsif l_status <> 'READY'  then
        pipe row ('Data is being gathered for ' ||l_duration||'; Sections: '||l_sections);
        dbms_lock.sleep(5);
      else
        pipe row ('Data gathering finished.');
        exit;
      end if;
    end loop;
  end;

  procedure print_header(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                         p_mode                 number default 0) -- 0 -- full
  is
  begin
    for i in (select r.OBJ_ID, x.*,to_char(cast((x.END_GATHERING_DT-x.START_GATHERING_DT) AS INTERVAL DAY(2) TO SECOND(3))) dur,
                     (select listagg('<b>'||gathering_status||':</b> '||cnt,'; ') within group (order by gathering_status)
                        from (select gathering_status, count(1) cnt
                                from OPAS_OT_SQL_DATA_SECT where sql_data_point_id = p_sql_data_point_id group by gathering_status)) sect_statuses
                from opas_ot_sql_data x, OPAS_OT_SQL_DATA_POINT_REF r where x.sql_data_point_id = p_sql_data_point_id and x.sql_data_point_id = r.sql_data_point_id) loop

      if p_mode = 0 then
        htp.p('<b>Gathering status:</b> '||i.gathering_status||'; ');

        if i.START_GATHERING_DT is not null then
          htp.p('<b>Started:</b> '||to_char(i.START_GATHERING_DT,defDataTimeFmt)||'; ');
        end if;
      end if;

      if i.END_GATHERING_DT is not null then
        htp.p('<b>Finished:</b> '||to_char(i.END_GATHERING_DT,defDataTimeFmt)|| case when p_mode = 0 then '; <b>Duration:</b> '||i.dur end);
      end if;

      if p_mode = 0 then
        if i.sect_statuses is not null and i.END_GATHERING_DT is null then
          htp.p('<b>Sections:</b> '||i.sect_statuses);
        end if;

        htp.p(
          nvl( COREOBJ_API.get_param_c(i.OBJ_ID, COREOBJ_SQL_UTILS.pnAllParsDispl, false),print_data_point_params(p_sql_data_point_id))
          );
      end if;
    end loop;
  end;

  function get_section_duration(p_sql_data_point_id                opas_ot_sql_data.sql_data_point_id%type,
                                p_section_name           varchar2) return varchar2
  is
    l_result varchar2(100);
  begin
    select case
             when END_GATHERING_DT is null and START_GATHERING_DT is not null then 'In progress: '
             when END_GATHERING_DT is not null and START_GATHERING_DT is not null then  'Data gathered in: '
           else null end ||
           to_char(cast((nvl(END_GATHERING_DT,systimestamp)-START_GATHERING_DT) AS INTERVAL DAY(2) TO SECOND(3)))
      into l_result
      from opas_ot_sql_data_sect x
     where sql_data_point_id = p_sql_data_point_id and section_name = p_section_name;
    return l_result;
  exception
    when no_data_found then return null;
  end;


  procedure print_nonshared_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                         p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    COREMOD_REPORT_UTILS.print_query_result_html
                                           (p_query => q'[select inst_id "Instance ID",nonshared_reason "Non-shared reason",cnt "Count" from opas_ot_sql_nonshared where sql_data_point_id = ]'||p_sql_data_point_id,
                                            p_width => gwNarrowSection,
                                            p_summary => 'Non-shared reason',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            p_header => gdHeaderRepeat, --number default 0,
                                            --p_break_col varchar2 default null,
                                            p_output => print_nonshared_section_base.p_output);
  end;

  procedure print_vsql_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                    p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
    l_on varchar2(512);
    l_row_index pls_integer := 1;
    l_db_link_display_name varchar2(1000);
    l_output    COREMOD_REPORT_UTILS.t_output_lines;

    procedure p(msg varchar2) is begin l_output(l_row_index) := msg; l_row_index := l_row_index+1; end;
  begin
    --p(' ');
    select nvl(display_name,dblink) into l_db_link_display_name from v$opas_db_links l, opas_ot_sql_data sd where l.db_link_name(+) = sd.dblink and sd.sql_data_point_id = p_sql_data_point_id;
    p('Source DB: '||l_db_link_display_name);
    for i in (select * from OPAS_OT_SQL_VSQL where sql_data_point_id=p_sql_data_point_id order by inst_id, child_number) loop
      --p(' ');
      p('=====================================================================================================');
      p('SQL_ID='||i.sql_id||'; CHILD_NUMBER='||i.child_number||'; PLAN HASH: '||i.PLAN_HASH_VALUE||'; Opt Env Hash: '||i.OPTIMIZER_ENV_HASH_VALUE||';'||' INST_ID: '||i.inst_id);
    p('FORCE_MATCHING_SIGN: '||i.force_matching_signature||'; OLD_HASH_VALUE: '||i.OLD_HASH_VALUE);
    begin
      select object_type||': '||owner||'.'||object_name into l_on from opas_ot_sql_vsql_objs s where s.object_id=i.program_id and s.CHILD_NUMBER = i.CHILD_NUMBER and s.sql_data_point_id = p_sql_data_point_id;
      p(l_on||', line number: '||i.program_line#);
      exception when no_data_found then null;
    end;
      p('-----------------------------------------------------------------------------------------------------');
      p('Parsing Schema, Module, Action: '||nvl(i.parsing_schema_name,'<NULL>')||', '||nvl(i.module,'<NULL>')||', '||nvl(i.action,'<NULL>'));
      p('Load_time, First: '||i.first_load_time||', Last: '||i.last_load_time||', Active: '||to_char(i.last_active_time,defDataTimeFullFmt));
      $IF DBMS_DB_VERSION.version<11 $THEN
        p('SQL Profile: '||nvl(i.sql_profile,'<NULL>'));
      $ELSE
        p('IS_OBSOLETE, IS_BIND_SENSITIVE,IS_BIND_AWARE, IS_SHARABLE: '||nvl(i.IS_OBSOLETE,'<NULL>')||','||nvl(i.IS_BIND_SENSITIVE,'<NULL>')||','||nvl(i.IS_BIND_AWARE,'<NULL>')||','||nvl(i.is_shareable,'<NULL>'));
        p('SQL Profile, SQL Patch, SQL Plan BaseLine: '||nvl(i.sql_profile,'<NULL>')||','||nvl(i.sql_patch,'<NULL>')||','||nvl(i.sql_plan_baseline,'<NULL>'));
      $END
    p('PX_SERVERS_EXECUTIONS: '||COREMOD_REPORT_UTILS.tptformat(i.PX_SERVERS_EXECUTIONS));
      p('PHY_READ_REQ, PHY_READ_BYTES: '||COREMOD_REPORT_UTILS.tptformat(i.physical_read_requests)||'; '||COREMOD_REPORT_UTILS.tptformat(i.physical_read_bytes));
    p('PHY_WRI_REQ, PHY_WRI_BYTES: '||COREMOD_REPORT_UTILS.tptformat(i.physical_write_requests)||'; '||COREMOD_REPORT_UTILS.tptformat(i.physical_write_bytes));
      p('Calls: Parse, Exec, Fetch, Rows, EndOfFetch '||i.parse_calls||'; '||i.executions||'; '||i.fetches||'; '||i.ROWS_PROCESSED||'; '||i.end_of_fetch_count);
      p('CPU Time, Elapsed Time: '||COREMOD_REPORT_UTILS.tptformat(i.cpu_time,'TIME')||'; '||COREMOD_REPORT_UTILS.tptformat(i.elapsed_time,'TIME'));
      p('PIO, LIO, Direct WR: '||COREMOD_REPORT_UTILS.tptformat(i.disk_reads)||'; '||COREMOD_REPORT_UTILS.tptformat(i.buffer_gets)||'; '||COREMOD_REPORT_UTILS.tptformat(i.DIRECT_WRITES));
    p('WAIT: APP, CONCURR, CLUSTER, USER_IO, PL/SQL, JAVA: '||COREMOD_REPORT_UTILS.tptformat(i.application_wait_time,'TIME')||'; '||COREMOD_REPORT_UTILS.tptformat(i.concurrency_wait_time,'TIME')||'; '||COREMOD_REPORT_UTILS.tptformat(i.cluster_wait_time,'TIME')||'; '||COREMOD_REPORT_UTILS.tptformat(i.user_io_wait_time,'TIME')||'; '||COREMOD_REPORT_UTILS.tptformat(i.PLSQL_EXEC_TIME,'TIME')||'; '||COREMOD_REPORT_UTILS.tptformat(i.JAVA_EXEC_TIME,'TIME'));
    if i.disk_reads>0 then p('Awg IO time: '||COREMOD_REPORT_UTILS.tptformat(i.user_io_wait_time/i.disk_reads,'TIME'));end if;
    if i.buffer_gets>0 then p('CPU sec/1M LIO: '||COREMOD_REPORT_UTILS.tptformat(i.cpu_time/i.buffer_gets));end if;
      p('-----------------------------------------------------------------------------------------------------');
      if i.executions>0 then
        p('LIO/Exec, PIO/Exec, CPU/EXEC, ROWS/EXEC, ELA/EXEC: '||COREMOD_REPORT_UTILS.tptformat(round(i.buffer_gets/i.executions,3))||'; '||
                                                    COREMOD_REPORT_UTILS.tptformat(round((i.disk_reads+i.DIRECT_WRITES)/i.executions,3))||'; '||
                            COREMOD_REPORT_UTILS.tptformat(round(i.cpu_time/i.executions,3),'TIME')||'; '||
                            COREMOD_REPORT_UTILS.tptformat(round(i.ROWS_PROCESSED/i.executions,3))||'; '||
                            COREMOD_REPORT_UTILS.tptformat(round(i.elapsed_time/i.executions,3),'TIME'));
      else
        p('LIO/Exec, PIO/Exec, CPU/EXEC, ELA/EXEC: '||COREMOD_REPORT_UTILS.tptformat(round(i.buffer_gets))||'; '||COREMOD_REPORT_UTILS.tptformat(round(i.disk_reads+i.DIRECT_WRITES))||'; '||COREMOD_REPORT_UTILS.tptformat(round(i.cpu_time),'TIME')||'; '||COREMOD_REPORT_UTILS.tptformat(round(i.elapsed_time),'TIME'));
      end if;
      if i.ROWS_PROCESSED>0 then
        p('LIO/Row, PIO/Row, CPU/Row, ELA/Row, Rows/Sec: '||COREMOD_REPORT_UTILS.tptformat(round(i.buffer_gets/i.ROWS_PROCESSED,3))||'; '||COREMOD_REPORT_UTILS.tptformat(round((i.disk_reads+i.DIRECT_WRITES)/i.ROWS_PROCESSED,3))||'; '||COREMOD_REPORT_UTILS.tptformat(round(i.cpu_time/i.ROWS_PROCESSED,3),'TIME')||'; '||COREMOD_REPORT_UTILS.tptformat(round(i.elapsed_time/i.ROWS_PROCESSED,3),'TIME')||'; '||COREMOD_REPORT_UTILS.tptformat(round(1e6*i.ROWS_PROCESSED/case when i.elapsed_time=0 then 1 else i.elapsed_time end,3)));
      else
        p('LIO/Row, PIO/Row, CPU/Row, ELA/Row: '||COREMOD_REPORT_UTILS.tptformat(round(i.buffer_gets))||'; '||COREMOD_REPORT_UTILS.tptformat(round(i.disk_reads+i.DIRECT_WRITES))||'; '||COREMOD_REPORT_UTILS.tptformat(round(i.cpu_time),'TIME')||'; '||COREMOD_REPORT_UTILS.tptformat(round(i.elapsed_time),'TIME'));
      end if;
      $IF DBMS_DB_VERSION.version>=11 $THEN
      if i.IO_CELL_OFFLOAD_ELIGIBLE_BYTES>0 then
        p('-----------------------------------------------------------------------------------------------------');
        p('Saved %: '||round(100 * (i.IO_CELL_OFFLOAD_ELIGIBLE_BYTES - i.IO_INTERCONNECT_BYTES) / case when i.IO_CELL_OFFLOAD_ELIGIBLE_BYTES=0 then 1 else i.IO_CELL_OFFLOAD_ELIGIBLE_BYTES end,2));
        p('IO_CELL_OFFLOAD_ELIGIBLE_BYTES: '||COREMOD_REPORT_UTILS.tptformat(i.IO_CELL_OFFLOAD_ELIGIBLE_BYTES));
        p('IO_INTERCONNECT_BYTES:          '||COREMOD_REPORT_UTILS.tptformat(i.IO_INTERCONNECT_BYTES));
        p('OPTIMIZED_PHY_READ_REQUESTS:    '||COREMOD_REPORT_UTILS.tptformat(i.OPTIMIZED_PHY_READ_REQUESTS));
        p('IO_CELL_UNCOMPRESSED_BYTES:     '||COREMOD_REPORT_UTILS.tptformat(i.IO_CELL_UNCOMPRESSED_BYTES));
        p('IO_CELL_OFFLOAD_RETURNED_BYTES: '||COREMOD_REPORT_UTILS.tptformat(i.IO_CELL_OFFLOAD_RETURNED_BYTES));
        p('=====================================================================================================');
      end if;
      $END
      p(' ');

      COREMOD_REPORT_UTILS.convert_to_html_table (
        P_TEXT => null,
        P_INPUT => l_output,
        P_T_HEADER => 'V$SQL',
        P_WIDTH => gwNarrowSection,
        P_SEARCH => 'CHILD_NUMBER=([[:digit:]]*)',
        P_REPLACEMENT => HTF.ANCHOR (curl=>'#child_last_'||i.inst_id||'_'||i.child_number,ctext=>'CHILD_NUMBER=\1',cattributes=>'class="awr"'),
        --P_COMPARISON => P_COMPARISON,
        P_STYLE_TAB => 'trctd',
        P_STYLE_HEAD => 'trchd',
        P_STYLE_R1 => 'awrc1',--'trcr1',
        P_STYLE_R2 => 'awrnc1',--'trcr2',
        P_OUTPUT => p_output);

      l_output.delete; l_row_index:=1;
    end loop;

  END print_vsql_section_base;

  procedure print_exa_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                  p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    p_output(1) := '<b>Exadata statistics</b>';
    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(q'[select inst_id, offloaded + not_offloaded total, offloaded, to_char(round(100 * offloaded / (offloaded + not_offloaded), 2)) || '%' "OFFLOADED_%"
  from (select inst_id, sum(decode(offload, 'Yes', 1, 0)) offloaded, sum(decode(offload, 'No', 1, 0)) not_offloaded
          from (select inst_id, sql_id, decode(IO_CELL_OFFLOAD_ELIGIBLE_BYTES, 0, 'No', 'Yes') Offload
                  from OPAS_OT_SQL_VSQL s
                 where sql_data_point_id = '<sql_data_point_id>')
         group by inst_id) order by 1]','<sql_data_point_id>',p_sql_data_point_id),
                                            p_width => gwNarrowSection,
                                            p_summary => 'Exadata stats',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            --p_header number default 0,
                                            --p_break_col varchar2 default null,
                                            p_output => print_exa_section_base.p_output);

    p_output(p_output.count+1):='<b>Exadata details</b>';
    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(q'[select inst_id,
       child_number child,
       plan_hash_value plan_hash,
       executions execs,
       round((elapsed_time / 1000000) / decode(nvl(executions, 0), 0, 1, executions) /
       decode(px_servers_executions, 0, 1, px_servers_executions / decode(nvl(executions, 0), 0, 1, executions)),3) avg_etime,
       round(px_servers_executions / decode(nvl(executions, 0), 0, 1, executions),1) avg_px,
       decode(IO_CELL_OFFLOAD_ELIGIBLE_BYTES, 0, 'No', 'Yes') Offload,
       round(decode(IO_CELL_OFFLOAD_ELIGIBLE_BYTES,0,0,
              100 * (IO_CELL_OFFLOAD_ELIGIBLE_BYTES - IO_INTERCONNECT_BYTES) / decode(IO_CELL_OFFLOAD_ELIGIBLE_BYTES, 0, 1, IO_CELL_OFFLOAD_ELIGIBLE_BYTES)),2) "IO_SAVED_%",
       buffer_gets lio,
       round(buffer_gets / decode(nvl(executions, 0), 0, 1, executions)) avg_lio
  from OPAS_OT_SQL_VSQL s
 where sql_data_point_id = '<sql_data_point_id>'
order by 1,2]','<sql_data_point_id>',p_sql_data_point_id), --'
                                            p_width => gwNarrowSection,
                                            p_summary => 'Exadata details',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            --p_header number default 0,
                                            --p_break_col varchar2 default null,
                                            p_output => print_exa_section_base.p_output);
  end;

  procedure print_sqlmon_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                      p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
    l_text clob;
    l_k    number;
  begin

    l_k:=1;
    for i in (select rownum rn, SQLMON_ID, SQL_EXEC_ID, SQL_EXEC_START from (
                      select m.SQLMON_ID, m.SQL_EXEC_ID, m.SQL_EXEC_START
                        from opas_ot_sql_sqlmon_ref r, opas_ot_sql_sqlmon m
                       where r.sqlmon_id = m.sqlmon_id
                         and r.sql_data_point_id = p_sql_data_point_id
                         and m.sql_mon_report is not null
                         and m.source = COREOBJ_SQL_UTILS.srcV$
               order by sql_exec_start desc))
    loop
      p_output(l_k) := HTF.LISTITEM(cattributes=>'class="awr"',
                               ctext=>HTF.ANCHOR (curl=>'#sqlmonhst'||i.SQLMON_ID,
                                                  ctext=>i.rn ||'. SQL_EXEC_ID: '||i.SQL_EXEC_ID||' SQL_EXEC_START: '||to_char(i.SQL_EXEC_START,defDataTimeFullFmt),
                                                  cattributes=>'class="awr"' --'
                                                  )
                              );
      l_k:=l_k+1;
    end loop;
    p_output(p_output.count+1):=HTF.BR;
    p_output(p_output.count+1):=HTF.BR;

    for i in (select rownum rn, sql_mon_report, SQLMON_ID, SQL_EXEC_ID, SQL_EXEC_START
                from (select m.sql_mon_report, m.SQLMON_ID, m.SQL_EXEC_ID, m.SQL_EXEC_START
                        from opas_ot_sql_sqlmon_ref r, opas_ot_sql_sqlmon m
                       where r.sqlmon_id = m.sqlmon_id
                         and r.sql_data_point_id = p_sql_data_point_id
                         and m.sql_mon_report is not null
                         and m.source = COREOBJ_SQL_UTILS.srcV$
               order by sql_exec_start desc)) loop
      COREMOD_FILE_UTILS.get_locator(i.sql_mon_report, l_text);
      if l_text = 'SQL Monitoring Report' then l_text := l_text || ' (empty)'; end if;

      COREMOD_REPORT_UTILS.convert_to_html_table (
        P_TEXT => i.rn ||'. SQL_EXEC_ID: '||i.SQL_EXEC_ID||'; SQL_EXEC_START: '||to_char(i.SQL_EXEC_START,defDataTimeFullFmt)||chr(10)||l_text,
        P_INPUT => p_output,
        P_T_HEADER => '#FIRST_LINE#',
        P_WIDTH => 0, --auto width
        P_SEARCH      => 'SQL Monitoring Report',
        P_REPLACEMENT => HTF.ANCHOR(curl=>'',
                                    ctext=>'SQL Monitoring Report',
                                    cname=>'sqlmonhst'||i.SQLMON_ID,cattributes=>'class="awr"'),
        --P_COMPARISON => P_COMPARISON,
        P_STYLE_TAB => 'trctd',
        P_STYLE_HEAD => 'trchd',
        P_STYLE_R1 => 'awrc1',--'trcr1',
        P_STYLE_R2 => 'awrnc1',--'trcr2',
        P_OUTPUT => p_output);
    end loop;

  END print_sqlmon_section_base;

  procedure print_sqlmon_hst_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                          p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
    l_text clob;
    l_capture        varchar2(100);
    l_header         clob;
    l_display_params varchar2(100);
    l_k              number;
  begin

    l_display_params:='ALL ALLSTATS +peeked_binds';  l_capture := 'Execution plans extracted from SQL Monitor History';

    l_k:=1;
    for i in (select rownum rn, SQLMON_ID, SQL_EXEC_ID, SQL_EXEC_START from (
              select m.SQLMON_ID, m.SQL_EXEC_ID, m.SQL_EXEC_START
                from opas_ot_sql_sqlmon_ref r,
                     opas_ot_sql_sqlmon m
               where r.sqlmon_id = m.sqlmon_id
                 and r.sql_data_point_id = p_sql_data_point_id
                 and m.sql_mon_report is not null
                 and m.source = COREOBJ_SQL_UTILS.srcHST
               order by m.sql_exec_start desc))
    loop
      p_output(l_k) := HTF.LISTITEM(cattributes=>'class="awr"',
                               ctext=>HTF.ANCHOR (curl=>'#sqlmonhst'||i.SQLMON_ID,
                                                  ctext=>i.rn ||'. SQL_EXEC_ID: '||i.SQL_EXEC_ID||' SQL_EXEC_START: '||to_char(i.SQL_EXEC_START,defDataTimeFullFmt),
                                                  cattributes=>'class="awr"'
                                                  )
                              );
      l_k:=l_k+1;
    end loop;
    p_output(p_output.count+1):=HTF.BR;
    p_output(p_output.count+1):=HTF.BR;

    for i in (select rownum rn, sql_mon_report, SQL_PLAN_HASH_VALUE, SQL_FULL_PLAN_HASH_VALUE, plan_id, SQLMON_ID, SQL_EXEC_ID, SQL_EXEC_START from (
              select m.sql_mon_report, d.SQL_PLAN_HASH_VALUE, d.SQL_FULL_PLAN_HASH_VALUE, m.plan_id, m.SQLMON_ID, m.SQL_EXEC_ID, m.SQL_EXEC_START
                from opas_ot_sql_sqlmon_ref r,
                     opas_ot_sql_sqlmon m,
                     OPAS_OT_SQL_SQLMON_DATA d
               where r.sqlmon_id = m.sqlmon_id
                 and r.sql_data_point_id = p_sql_data_point_id
                 and m.sql_mon_report is not null
                 and m.source = COREOBJ_SQL_UTILS.srcHST
                 and d.sqlmon_id = m.sqlmon_id
               order by sql_exec_start desc))
    loop

      COREMOD_FILE_UTILS.get_locator(i.sql_mon_report, l_text);

      COREMOD_REPORT_UTILS.convert_to_html_table (
        P_TEXT => i.rn ||'. SQL_EXEC_ID: '||i.SQL_EXEC_ID||'; SQL_EXEC_START: '||to_char(i.SQL_EXEC_START,defDataTimeFullFmt)||chr(10)||l_text,
        P_INPUT => p_output,
        P_T_HEADER => '#FIRST_LINE#',
        P_WIDTH => 0, --auto width
        P_SEARCH      => 'SQL Monitoring Report',
        P_REPLACEMENT => HTF.ANCHOR(curl=>'',
                                    ctext=>'SQL Monitoring Report',
                                    cname=>'sqlmonhst'||i.SQLMON_ID,cattributes=>'class="awr"'),
        --P_COMPARISON => P_COMPARISON,
        P_STYLE_TAB => 'trctd',
        P_STYLE_HEAD => 'trchd',
        P_STYLE_R1 => 'awrc1',--'trcr1',
        P_STYLE_R2 => 'awrnc1',--'trcr2',
        P_OUTPUT => p_output);

      for plans in (select * from
                     (select unique r.PLAN_ID,d.INST_ID,d.PLAN_HASH_VALUE,d.FULL_PLAN_HASH_VALUE,d.CHILD_NUMBER
                        from OPAS_OT_SQL_PLAN_REF r, OPAS_OT_SQL_PLAN_DET d, OPAS_OT_SQL_PLANS p
                       where r.sql_data_point_id=p_sql_data_point_id
                         and r.plan_id=d.plan_id
                         and p.plan_id=r.plan_id
                         and d.plan_id=p.plan_id
                         and p.plan_source=COREOBJ_SQL_UTILS.srcHST
                         and d.PLAN_HASH_VALUE=i.SQL_PLAN_HASH_VALUE
                         and d.FULL_PLAN_HASH_VALUE=i.SQL_FULL_PLAN_HASH_VALUE
                         and p.plan_id = i.PLAN_ID)
                    order by INST_ID,CHILD_NUMBER)
      loop

        l_header := l_capture||chr(10)||'================================'||chr(10)||'Instance number: '||plans.INST_ID||'; Child number: '||plans.CHILD_NUMBER;
        l_header := l_header ||chr(10)||'Plan hash value: '||plans.PLAN_HASH_VALUE||'; Plan full hash value: '||plans.FULL_PLAN_HASH_VALUE;

        COREMOD_REPORT_UTILS.convert_to_html_table (
          P_TEXT => l_header,
          P_INPUT => p_output,
          P_T_HEADER => '#FIRST_LINE#',
          P_WIDTH => 0, --auto width
          --P_SEARCH => 'CHILD_NUMBER=([[:digit:]]*)',
          --P_REPLACEMENT => P_REPLACEMENT,
          --P_COMPARISON => P_COMPARISON,
          P_STYLE_TAB => 'trctd',
          P_STYLE_HEAD => 'trchd',
          P_STYLE_R1 => 'awrc1',--'trcr1',
          P_STYLE_R2 => 'awrnc1',--'trcr2',
          P_OUTPUT => p_output);

        COREMOD_REPORT_UTILS.print_query_result_html (
                                              p_query => replace(replace(
q'[select plan_table_output "Plan Table Output" from table(dbms_xplan.display('OPAS_OT_SQL_PLAN_DET', null, '<display_params>', 'plan_id=<PLAN_ID>'))]'
                                              ,'<PLAN_ID>',i.PLAN_ID)
                                              ,'<display_params>',l_display_params),
                                              p_width => gwWideSection1,
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
                                              p_output => print_sqlmon_hst_section_base.p_output);

      end loop;
    end loop;

  END print_sqlmon_hst_section_base;

  procedure print_wa_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                  p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(q'[select inst_id,
       child_number "CHLD#",
       policy,
       operation_id "OPER",
       operation_type "OPERATION",
       estimated_optimal_size "EST_OPTIM",
       estimated_onepass_size "EST_ONEPA",
       last_memory_used "MEM_USED",
       last_execution "LST_EXE",
       last_degree "LST_DEGREE",
       total_executions "TOT_EXE",
       optimal_executions "OPT_EXE",
       onepass_executions "ONEP_EXE",
       multipasses_executions "MULT_EXE",
       active_time "ACTIVE_TIM",
       max_tempseg_size "MAX_TMP",
       last_tempseg_size "LAST_TMP"
  from opas_ot_sql_wa
 where sql_data_point_id = <sql_data_point_id>
 order by inst_id, child_number, operation_id]','<sql_data_point_id>',p_sql_data_point_id),
                                            p_width => gwWideSection1,
                                            p_summary => 'Workareas',--'
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            --p_header number default 0,
                                            p_break_col => 'inst_id',
                                            p_output => print_wa_section_base.p_output);
  end;

  procedure print_oe_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                  p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(q'[select inst_id,child_number,name,isdefault,value from opas_ot_sql_opt_env where sql_data_point_id = <sql_data_point_id> order by inst_id,child_number,name]','<sql_data_point_id>',p_sql_data_point_id),
                                            p_width => gwWideSection1,
                                            p_summary => 'Workareas',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            p_header => gdHeaderRepeat, --number default 0,
                                            p_break_col => 'inst_id',
                                            p_output => print_oe_section_base.p_output);
  end;

  procedure print_plan_section_base(p_sql_data_point_id       opas_ot_sql_data.sql_data_point_id%type,
                                    p_section_name  varchar2,
                                    p_output    out COREMOD_REPORT_UTILS.t_output_lines) AS
    --l_indx number := 1;
    l_display_params varchar2(100);
    --l_capture        varchar2(100);
    l_header         clob;
    l_plan_filter    varchar2(10);
    l_search0        varchar2(32765);
    l_search         varchar2(32765);
    l_replace         varchar2(32765);
  begin
    case p_section_name
      when repsSQLPLLAST  then l_display_params:='LAST ALLSTATS +peeked_binds';          /*l_capture := 'Display cursor (last)';*/         l_plan_filter := COREOBJ_SQL_UTILS.srcV$;
                               l_search0 := 'Instance number: <INST>; Child number: <CHLD>';
                               l_replace := HTF.ANCHOR(curl=>'#child_all_<INST>_<CHLD>',ctext=>'<REPLTXT>',cname=>'child_last_<INST>_<CHLD>',cattributes=>'class="awr"');
      when repsSQLPLADV   then l_display_params:='LAST ADVANCED';                        /*l_capture := 'Display cursor (LAST ADVANCED)';*/ l_plan_filter := COREOBJ_SQL_UTILS.srcV$;
      when repsSQLPLALL   then l_display_params:='ALL ALLSTATS +peeked_binds';           /*l_capture := 'Display cursor (ALL)';*/           l_plan_filter := COREOBJ_SQL_UTILS.srcV$;
                               l_search0 := 'Instance number: <INST>; Child number: <CHLD>';
                               l_replace := HTF.ANCHOR(curl=>'',ctext=>'<REPLTXT>',cname=>'child_all_<INST>_<CHLD>',cattributes=>'class="awr"');
      when repsSQLPLADAPT then l_display_params:='adaptive LAST ALLSTATS +peeked_binds'; /*l_capture := 'Display cursor (ADAPTIVE)';*/      l_plan_filter := COREOBJ_SQL_UTILS.srcV$;
    end case;

    for plans in (select * from (select unique r.PLAN_ID,d.INST_ID,d.PLAN_HASH_VALUE,d.FULL_PLAN_HASH_VALUE,d.CHILD_NUMBER
                    from OPAS_OT_SQL_PLAN_REF r, OPAS_OT_SQL_PLAN_DET d, OPAS_OT_SQL_PLANS p
                   where r.sql_data_point_id=p_sql_data_point_id
                     and r.plan_id=p.plan_id
                     and p.plan_source = l_plan_filter
                     and r.plan_id=d.plan_id)
                   order by INST_ID, CHILD_NUMBER, PLAN_ID) loop

      l_header := 'Plan hash value: '||plans.PLAN_HASH_VALUE||'; Plan full hash value: '||plans.FULL_PLAN_HASH_VALUE;
      l_header := l_header ||chr(10)||'Instance number: '||plans.INST_ID||'; Child number: '||plans.CHILD_NUMBER;

      l_search := replace(replace(l_search0,'<INST>',plans.INST_ID),'<CHLD>',plans.CHILD_NUMBER);

      COREMOD_REPORT_UTILS.convert_to_html_table (
        P_TEXT => l_header,
        P_INPUT => p_output,
        P_T_HEADER => '#FIRST_LINE#',
        P_WIDTH => 0, --auto width
        P_SEARCH => l_search,
        P_REPLACEMENT => replace(replace(replace(l_replace,'<INST>',plans.INST_ID),'<CHLD>',plans.CHILD_NUMBER),'<REPLTXT>',l_search),
        --P_COMPARISON => P_COMPARISON,
        P_STYLE_TAB => 'trctd',
        P_STYLE_HEAD => 'trchd',
        P_STYLE_R1 => 'awrc1',--'trcr1',
        P_STYLE_R2 => 'awrnc1',--'trcr2',
        P_OUTPUT => p_output);

      COREMOD_REPORT_UTILS.print_query_result_html (
                                            p_query => replace(replace(
q'[select plan_table_output "Plan Table Output" from table(dbms_xplan.display('OPAS_OT_SQL_PLAN_DET', null, '<display_params>', 'plan_id=<PLAN_ID>'))]'
                                              ,'<PLAN_ID>',plans.PLAN_ID)
                                              ,'<display_params>',l_display_params),--'
                                            p_width => gwWideSection1,
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
                                            p_output => print_plan_section_base.p_output);
    end loop;
  end;

  procedure print_plan_ep_section_base(p_sql_data_point_id       opas_ot_sql_data.sql_data_point_id%type,
                                       p_output    out COREMOD_REPORT_UTILS.t_output_lines) AS
    --l_indx number := 1;
    l_display_params varchar2(100);
    --l_capture        varchar2(100);
    --l_header         clob;
    --l_plan_filter    varchar2(10);
    --l_search         varchar2(32765);
    --l_replace         varchar2(32765);
  begin
    for plans in (select * from (select unique r.PLAN_ID,d.SQL_PLAN_HASH_VALUE,d.SQL_FULL_PLAN_HASH_VALUE
                    from OPAS_OT_SQL_PLAN_REF r, OPAS_OT_SQL_EP_PLAN_DET d, OPAS_OT_SQL_PLANS p
                   where r.sql_data_point_id=p_sql_data_point_id
                     and r.plan_id=p.plan_id
                     and p.plan_source = COREOBJ_SQL_UTILS.srcEP
                     and r.plan_id=d.plan_id)) loop
/*
      l_header := 'Plan hash value: '||plans.SQL_PLAN_HASH_VALUE||'; Plan full hash value: '||plans.SQL_FULL_PLAN_HASH_VALUE;

      COREMOD_REPORT_UTILS.convert_to_html_table (
        P_TEXT => l_header,
        P_INPUT => p_output,
        P_T_HEADER => '#FIRST_LINE#',
        P_WIDTH => 0, --auto width
        P_SEARCH => null, --l_search,
        P_REPLACEMENT => null, --replace(replace(replace(l_replace,'<INST>',plans.INST_ID),'<CHLD>',plans.CHILD_NUMBER),'<REPLTXT>',l_search),
        --P_COMPARISON => P_COMPARISON,
        P_STYLE_TAB => 'trctd',
        P_STYLE_HEAD => 'trchd',
        P_STYLE_R1 => 'awrc1',--'trcr1',
        P_STYLE_R2 => 'awrnc1',--'trcr2',
        P_OUTPUT => p_output);
*/

      p_output(1):=HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Explain plan (simple)',cname=>'dp_ep_smpl',cattributes=>'class="awr"'),cattributes=>'class="awr"');

      p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#dp_ep_smpl',ctext=>'Explain plan (simple)',cattributes=>'class="awr"'));
      p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#dp_ep_adv',ctext=>'Explain plan (advanced)',cattributes=>'class="awr"'));
      p_output(p_output.count+1):=HTF.BR;

      l_display_params := '';

      COREMOD_REPORT_UTILS.print_query_result_html (
                                            p_query => replace(replace(
q'[select plan_table_output "Plan Table Output" from table(dbms_xplan.display('OPAS_OT_SQL_EP_PLAN_DET', null, null, 'plan_id=<PLAN_ID>'))]'
                                              ,'<PLAN_ID>',plans.PLAN_ID)
                                              ,'<display_params>',l_display_params),--'
                                            p_width => gwWideSection1,
                                            p_summary => 'Execution plan',
                                            p_search => 'Plan hash value: ([[:digit:]]*)',
                                            p_replacement => HTF.ANCHOR(curl=>'#epplanadv_\1',ctext=>'Plan hash value: \1',cname=>'epplan_\1',cattributes=>'class="awr"'),
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            --p_header number default 0,
                                            --p_break_col => 'inst_id',
                                            p_output => print_plan_ep_section_base.p_output);

      p_output(p_output.count+1):=HTF.BR;

      p_output(p_output.count+1):=HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Explain plan (advanced)',cname=>'dp_ep_adv',cattributes=>'class="awr"'),cattributes=>'class="awr"');

      p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#dp_ep_smpl',ctext=>'Explain plan (simple)',cattributes=>'class="awr"'));
      p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#dp_ep_adv',ctext=>'Explain plan (advanced)',cattributes=>'class="awr"'));
      p_output(p_output.count+1):=HTF.BR;

      l_display_params := 'ADVANCED';

      COREMOD_REPORT_UTILS.print_query_result_html (
                                            p_query => replace(replace(
q'[select plan_table_output "Plan Table Output" from table(dbms_xplan.display('OPAS_OT_SQL_EP_PLAN_DET', null, 'ADVANCED', 'plan_id=<PLAN_ID>'))]'
                                              ,'<PLAN_ID>',plans.PLAN_ID)
                                              ,'<display_params>',l_display_params),--'
                                            p_width => gwWideSection1,
                                            p_summary => 'Execution plan (advanced)',
                                            p_search => 'Plan hash value: ([[:digit:]]*)',
                                            p_replacement => HTF.ANCHOR(curl=>'',ctext=>'Plan hash value: \1',cname=>'epplanadv_\1',cattributes=>'class="awr"'),
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            --p_header number default 0,
                                            --p_break_col => 'inst_id',
                                            p_output => print_plan_ep_section_base.p_output);
    end loop;
  end;

  procedure print_vash_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                    p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin

--    p_output(1) := '<b>Summary for each PLAN HASH</b>';
    p_output(1):=HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'V$ASH Identitiy',cname=>'vash_ident',cattributes=>'class="awr"'),cattributes=>'class="awr"');
    p_output(p_output.count+1):=HTF.BR;

    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(replace(q'[select to_char(MIN_SAMPLE_TIME,'<DTFMT>') MIN_SAMPLE_TIME, to_char(MAX_SAMPLE_TIME,'<DTFMT>') MAX_SAMPLE_TIME,to_char(SQL_EXEC_START,'<DTFMT>') SQL_EXEC_START,PROGRAM,MODULE,ACTION,CLIENT_ID,SAMPLES_CNT
  from opas_ot_sql_ash_ident x where sql_data_point_id = <sql_data_point_id> and source_tab='V$'
 order by SAMPLES_CNT desc]','<sql_data_point_id>',p_sql_data_point_id),'<DTFMT>',defDataTimeFmt),
                                            p_width => gwWideSection1,
                                            p_summary => 'V$ASH Identity',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            p_header => gdHeaderRepeat, --number default 0,
                                            p_break_col => null, --'plan_hash_value',
                                            p_output => print_vash_section_base.p_output);
    p_output(p_output.count+1):=HTF.BR;

    p_output(p_output.count+1):=HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Summary for each PLAN HASH',cname=>'vash_summ1',cattributes=>'class="awr"'),cattributes=>'class="awr"');

    p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#vash_summ1',ctext=>'Summary for each PLAN HASH',cattributes=>'class="awr"'));
    p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#vash_summ2',ctext=>'Summary for each PLAN HASH per HOUR',cattributes=>'class="awr"'));
    p_output(p_output.count+1):=HTF.BR;

    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(q'[select plan_hash_value, id, row_src "Row source", event, cnt "Time", tim_pct "Time, %", tim_id_pct "Time by ID, %", obj "Object", tbs "Tablespace"
  from OPAS_OT_SQL_VASH2 x where sql_data_point_id = <sql_data_point_id>
 order by plan_hash_value, id, event]','<sql_data_point_id>',p_sql_data_point_id),
                                            p_width => gwWideSection1,
                                            p_summary => 'V$ASH Summary',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            p_header => gdHeaderRepeat, --number default 0,
                                            p_break_col => 'plan_hash_value',
                                            p_output => print_vash_section_base.p_output);

    --p_output(p_output.count+1) := '<b>Summary for each PLAN HASH per HOUR</b>';
    p_output(p_output.count+1):=HTF.BR;

    p_output(p_output.count+1):=HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Summary for each PLAN HASH per HOUR',cname=>'vash_summ2',cattributes=>'class="awr"'),cattributes=>'class="awr"');

    p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#vash_summ1',ctext=>'Summary for each PLAN HASH',cattributes=>'class="awr"'));
    p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#vash_summ2',ctext=>'Summary for each PLAN HASH per HOUR',cattributes=>'class="awr"'));
    p_output(p_output.count+1):=HTF.BR;

    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(replace(replace(q'[select to_char(sql_hour,'<defDTFullFmt>') "Hour", to_char(SQL_EXEC_START,'<defDTFullFmt>') SQL_EXEC_START, to_char(sql_exec_end,'<defDTFullFmt>') sql_exec_end, plan_hash_value, id, row_src, event, cnt, tim_pct, tim_id_pct, obj, tbs
  from OPAS_OT_SQL_VASH1 x where sql_data_point_id = <sql_data_point_id>
 order by SQL_EXEC_START, plan_hash_value, id, event]','<sql_data_point_id>',p_sql_data_point_id),'<defDTFmt>',defDataTimeFmt),'<defDTFullFmt>',defDataTimeFullFmt),
                                            p_width => gwWideSection1,--'
                                            p_summary => 'V$ASH Details',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            p_header => gdHeaderRepeat, --number default 0,
                                            p_break_col => 'SQL_EXEC_START',
                                            p_output => print_vash_section_base.p_output);

  end;

  procedure print_awr_sqlstat_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                           p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(replace(replace(q'[with data1 as (
select
        s.snap_id snap,to_char(sn.end_interval_time,'<defDTFullFmt>') end_interval_time
      , s.instance_number inst_id
      , s.plan_hash_value plan_hash
      , EXECUTIONS_DELTA EXEC_DELTA
      , (round(s.ELAPSED_TIME_DELTA/decode(s.EXECUTIONS_DELTA, null, 1,0,1, s.EXECUTIONS_DELTA)/1000)) as ela_poe
      , (round(s.BUFFER_GETS_DELTA/decode(s.EXECUTIONS_DELTA, null, 1,0,1, s.EXECUTIONS_DELTA))) as LIO_poe
      , (round(s.CPU_TIME_DELTA/decode(s.EXECUTIONS_DELTA, null, 1,0,1, s.EXECUTIONS_DELTA)/1000)) as CPU_poe
      , (round(s.IOWAIT_DELTA/decode(s.EXECUTIONS_DELTA, null, 1,0,1, s.EXECUTIONS_DELTA)/1000)) as IOWAIT_poe
      , (round(s.ccwait_delta/decode(s.EXECUTIONS_DELTA, null, 1,0,1, s.EXECUTIONS_DELTA)/1000)) as CCWAIT_poe
      , (round(s.APWAIT_delta/decode(s.EXECUTIONS_DELTA, null, 1,0,1, s.EXECUTIONS_DELTA)/1000)) as APWAIT_poe
      , (round(s.CLWAIT_DELTA/decode(s.EXECUTIONS_DELTA, null, 1,0,1, s.EXECUTIONS_DELTA)/1000)) as CLWAIT_poe
      , (round(s.DISK_READS_DELTA/decode(s.EXECUTIONS_DELTA, null, 1,0,1, s.EXECUTIONS_DELTA))) as PIO_poe
      , (round(s.ROWS_PROCESSED_DELTA/decode(s.EXECUTIONS_DELTA, null, 1,0,1, s.EXECUTIONS_DELTA))) as Rows_poe
      , ROUND(ELAPSED_TIME_DELTA/1000000) ELA_DELTA_SEC
      , ROUND(CPU_TIME_DELTA/1000000) CPU_DELTA_SEC
      , ROUND(IOWAIT_DELTA/1000000) IOWAIT_DELTA_SEC
      , DISK_READS_DELTA
      , BUFFER_GETS_DELTA
      , ROWS_PROCESSED_DELTA
      , round(BUFFER_GETS_DELTA/decode(ROWS_PROCESSED_DELTA,0,null,ROWS_PROCESSED_DELTA)) LIO_PER_ROW
      , round(DISK_READS_DELTA/decode(ROWS_PROCESSED_DELTA,0,null,ROWS_PROCESSED_DELTA),2) IO_PER_ROW
      , round(s.IOWAIT_DELTA/decode(s.DISK_READS_DELTA, null, 1,0,1, s.DISK_READS_DELTA)/1000, 3) as awg_IO_tim
from OPAS_OT_SQL_AWR_SQLSTAT s, OPAS_DB_LINK_AWRSNAPS sn, OPAS_OT_SQL_DATA dp
where s.sql_id = dp.sql_id
  and s.snap_id = sn.snap_id
  and sn.snap_id between dp.AWR_SNAP_START and dp.AWR_SNAP_END
  and sn.instance_number = s.instance_number
  and dp.INCARNATION# = sn.INCARNATION#
  and dp.INCARNATION# = s.INCARNATION#
  and dp.dblink=sn.dblink
  and dp.dblink=s.dblink
  and dp.SQL_DATA_POINT_ID = <sql_data_point_id>)
SELECT
  snap, end_interval_time, inst_id, plan_hash, exec_delta, ela_poe, lio_poe, cpu_poe, iowait_poe, ccwait_poe, apwait_poe, clwait_poe, pio_poe, rows_poe, ela_delta_sec, cpu_delta_sec,
  iowait_delta_sec, disk_reads_delta, buffer_gets_delta, rows_processed_delta, lio_per_row, io_per_row, awg_io_tim,
  0 noprn_lastrow
FROM data1
union all
SELECT
  null snap, 'Totals:' end_interval_time, null inst_id, null plan_hash, sum(exec_delta), null ela_poe, null lio_poe, null cpu_poe, null iowait_poe, null ccwait_poe, null apwait_poe, null clwait_poe,
  null pio_poe, null rows_poe, sum(ela_delta_sec), sum(cpu_delta_sec),
  sum(iowait_delta_sec), sum(disk_reads_delta), sum(buffer_gets_delta), sum(rows_processed_delta), round(avg(lio_per_row),3), round(avg(io_per_row),3), round(avg(awg_io_tim),4),
  1 noprn_lastrow
FROM data1
order by snap nulls last, inst_id]','<sql_data_point_id>',p_sql_data_point_id),'<defDTFmt>',defDataTimeFmt),'<defDTFullFmt>',defDataTimeFullFmt),
                                            p_width => gwWideSection1,--'
                                            p_summary => 'AWR SQL statistics',
                                            p_search => 'PLAN_HASH',
                                            p_replacement => HTF.ANCHOR (curl=>'#awrplan_\1',ctext=>'\1',cattributes=>'class="awr"'),
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => 'trctotr',
                                            p_header => 20, --number default 0,
                                            p_break_col => 'PLAN_HASH',
                                            p_output => print_awr_sqlstat_section_base.p_output);

  end;

  procedure print_awr_binds_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                           p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(replace(replace(q'[select b.snap_id snap, to_char(sn.end_interval_time,'<defDTFullFmt>') end_interval_time, name, position, datatype_string,to_char(last_captured,'<defDTFullFmt>') last_captured, value_string
from OPAS_OT_SQL_AWR_SQLBIND b,
     OPAS_DB_LINK_AWRSNAPS sn,
     OPAS_OT_SQL_DATA dp
where b.sql_id = dp.sql_id
and b.snap_id = sn.snap_id
and sn.snap_id between dp.AWR_SNAP_START and dp.AWR_SNAP_END
and sn.instance_number = b.instance_number
and dp.dblink=sn.dblink
and dp.dblink=b.dblink
and dp.INCARNATION# = sn.INCARNATION#
and dp.INCARNATION# = b.INCARNATION#
and dp.SQL_DATA_POINT_ID = <sql_data_point_id>
order by b.snap_id,position]','<sql_data_point_id>',p_sql_data_point_id),'<defDTFmt>',defDataTimeFmt),'<defDTFullFmt>',defDataTimeFullFmt),
                                            p_width => gwWideSection1,--'
                                            p_summary => 'AWR SQL binds',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            p_header => gdHeaderRepeat, --number default 0,
                                            p_break_col => 'SNAP',
                                            p_output => print_awr_binds_section_base.p_output);
  end;

  procedure print_awr_plans_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                         p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
    l_display_params varchar2(100);
    --l_capture        varchar2(100);
    --l_header         clob;
    --l_plan_filter    varchar2(10);
  begin
    l_display_params:='ADVANCED';
    --l_capture := 'AWR Display cursor';

    for plans in (select * from (select unique r.PLAN_ID
                    from OPAS_OT_SQL_AWR_PLAN_REF r, OPAS_OT_SQL_AWR_PLAN_DET d, OPAS_OT_SQL_AWR_PLANS p
                   where r.sql_data_point_id=p_sql_data_point_id
                     and r.plan_id=p.plan_id
                     and r.plan_id=d.plan_id)
                   order by PLAN_ID) loop

      COREMOD_REPORT_UTILS.print_query_result_html (
                                            p_query => replace(replace(
q'[select plan_table_output "Plan Table Output" from table(dbms_xplan.display('OPAS_OT_SQL_AWR_PLAN_DET', null, '<display_params>', 'plan_id=<PLAN_ID>'))]'
                                              ,'<PLAN_ID>',plans.PLAN_ID)
                                              ,'<display_params>',l_display_params),--'
                                            p_width => gwWideSection1,
                                            p_summary => 'AWR execution plan',
                                            p_search => 'Plan hash value: ([[:digit:]]*)',
                                            p_replacement => HTF.ANCHOR(curl=>'#epplan_\1',ctext=>'Plan hash value: \1',cname=>'awrplan_\1',cattributes=>'class="awr"'),
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            --p_header number default 0,
                                            --p_break_col => 'inst_id',
                                            p_output => print_awr_plans_section_base.p_output);
    end loop;
  end;

  procedure print_awr_plsqlsrc_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                           p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(replace(replace(q'[select s.snap_id snap, to_char(sn.end_interval_time,'<defDTFullFmt>') end_interval_time, PLSQL_TOP "Top level PL/SQL", PLSQL_END "End point PL/SQL"
from OPAS_OT_SQL_AWR_ASH_SUMM s,
     OPAS_DB_LINK_AWRSNAPS sn,
     OPAS_OT_SQL_DATA dp
where s.sql_id = dp.sql_id
and s.snap_id = sn.snap_id
and sn.snap_id between dp.AWR_SNAP_START and dp.AWR_SNAP_END
and sn.instance_number = s.instance_number
and dp.dblink=sn.dblink
and dp.dblink=s.dblink
and dp.INCARNATION# = sn.INCARNATION#
and dp.INCARNATION# = s.INCARNATION#
and dp.SQL_DATA_POINT_ID = <sql_data_point_id>
and (PLSQL_TOP is not null or PLSQL_END is not null)
order by s.snap_id]','<sql_data_point_id>',p_sql_data_point_id),'<defDTFmt>',defDataTimeFmt),'<defDTFullFmt>',defDataTimeFullFmt),
                                            p_width => gwWideSection1,--'
                                            p_summary => 'AWR PL/SQL source',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            p_header => gdHeaderRepeat, --number default 0,
                                            p_break_col => 'SNAP',
                                            p_output => print_awr_plsqlsrc_section_base.p_output);
  end;

  procedure print_awr_ashinv_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                           p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(replace(replace(q'[select s.snap_id snap, to_char(sn.end_interval_time,'<defDTFullFmt>') end_interval_time,
topn, SESSION_ID, SESSION_SERIAL#, s.INSTANCE_NUMBER, TOP_LEVEL_SQL_ID, SQL_CHILD_NUMBER CHILD#, SQL_PLAN_HASH_VALUE PLAN_HASH, SQL_FULL_PLAN_HASH_VALUE FULL_PLAN__HASH,
USER_ID, PROGRAM, MACHINE, MODULE, ACTION, CLIENT_ID, ECID, FORCE_MATCHING_SIGNATURE,
SQL_EXEC_ID, to_char(SQL_EXEC_START,'<defDTFmt>') SQL_EXEC_START, SESSION_TYPE, USERNAME, to_char(MIN_SAMPLE_TIME,'<defDTFmt>') MIN_SAMPLE_TIME, to_char(MAX_SAMPLE_TIME,'<defDTFmt>') MAX_SAMPLE_TIME,
SAMPLES, PGA_ALLOCATED, TEMP_SPACE_ALLOCATED
from OPAS_OT_SQL_AWR_ASH_SUMM s,
     OPAS_DB_LINK_AWRSNAPS sn,
     OPAS_OT_SQL_DATA dp
where s.sql_id = dp.sql_id
and s.snap_id = sn.snap_id
and sn.snap_id between dp.AWR_SNAP_START and dp.AWR_SNAP_END
and sn.instance_number = s.instance_number
and dp.dblink=sn.dblink
and dp.dblink=s.dblink
and dp.INCARNATION# = sn.INCARNATION#
and dp.INCARNATION# = s.INCARNATION#
and dp.SQL_DATA_POINT_ID = <sql_data_point_id>
order by s.snap_id, topn]','<sql_data_point_id>',p_sql_data_point_id),'<defDTFmt>',defDataTimeFmt),'<defDTFullFmt>',defDataTimeFullFmt),
                                            p_width => gwWideSection1,--'
                                            p_summary => 'AWR ASH Top executions',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_search => 'PLAN_HASH',
                                            p_replacement => HTF.ANCHOR (curl=>'#awrplan_\1',ctext=>'\1',cattributes=>'class="awr"'),
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            p_header => gdHeaderRepeat, --number default 0,
                                            p_break_col => 'SNAP',
                                            p_output => print_awr_ashinv_section_base.p_output);
  end;

  procedure print_awr_ashplstats_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                              p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    --p_output(1) := '<b>Summary for each PLAN HASH</b>';

    p_output(1):=HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'AWR ASH Identitiy',cname=>'awrash_ident',cattributes=>'class="awr"'),cattributes=>'class="awr"');
    p_output(p_output.count+1):=HTF.BR;

    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(replace(q'[select to_char(MIN_SAMPLE_TIME,'<DTFMT>') MIN_SAMPLE_TIME, to_char(MAX_SAMPLE_TIME,'<DTFMT>') MAX_SAMPLE_TIME,to_char(SQL_EXEC_START,'<DTFMT>') SQL_EXEC_START,PROGRAM,MODULE,ACTION,CLIENT_ID,SAMPLES_CNT
  from opas_ot_sql_ash_ident x where sql_data_point_id = <sql_data_point_id> and source_tab='AWR'
 order by SAMPLES_CNT desc]','<sql_data_point_id>',p_sql_data_point_id),'<DTFMT>',defDataTimeFmt), --'
                                            p_width => gwWideSection1,
                                            p_summary => 'AWR ASH Identity',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            p_header => gdHeaderRepeat, --number default 0,
                                            p_break_col => null, --'plan_hash_value',
                                            p_output => print_awr_ashplstats_section_base.p_output);
    p_output(p_output.count+1):=HTF.BR;

    p_output(p_output.count+1):=HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Summary for each PLAN HASH',cname=>'awrash_summ1',cattributes=>'class="awr"'),cattributes=>'class="awr"');

    p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#awrash_summ1',ctext=>'Summary for each PLAN HASH',cattributes=>'class="awr"'));
    p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#awrash_summ2',ctext=>'Summary for each PLAN HASH per HOUR',cattributes=>'class="awr"'));
    p_output(p_output.count+1):=HTF.BR;

    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(replace(replace(q'[select
  plan_hash_value PLAN_HASH, FULL_PLAN_HASH_VALUE FULL_PLAN__HASH, PLAN_LINE_ID ID, PLAN_OPERATION ||' '|| PLAN_OPTIONS "Row source", EVENT, SAMPLES*10 "Time",
  round(100 * SAMPLES / sum(SAMPLES) over(partition by plan_hash_value), 2) "Time, %",
  round(100 * sum(SAMPLES) over(partition by PLAN_LINE_ID, plan_hash_value) / sum(SAMPLES) over(partition by plan_hash_value), 2) "Time by ID, %",
  obj "Object", tbs "Tablespace"
from
(select sql_plan_hash_value plan_hash_value, SQL_FULL_PLAN_HASH_VALUE FULL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID PLAN_LINE_ID,
        SQL_PLAN_OPERATION PLAN_OPERATION, SQL_PLAN_OPTIONS PLAN_OPTIONS, EVENT, sum(SAMPLES) SAMPLES, obj, tbs
from OPAS_OT_SQL_AWR_ASH_PLST s,
     OPAS_DB_LINK_AWRSNAPS sn,
     OPAS_OT_SQL_DATA dp
where s.sql_id = dp.sql_id
and s.snap_id = sn.snap_id
and sn.snap_id between dp.AWR_SNAP_START and dp.AWR_SNAP_END
and sn.instance_number = s.instance_number
and dp.dblink=sn.dblink
and dp.dblink=s.dblink
and dp.INCARNATION# = sn.INCARNATION#
and dp.INCARNATION# = s.INCARNATION#
and dp.SQL_DATA_POINT_ID = <sql_data_point_id>
group by sql_plan_hash_value, SQL_FULL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID, SQL_PLAN_OPERATION, SQL_PLAN_OPTIONS, EVENT, obj, tbs)
order by plan_hash_value,PLAN_LINE_ID nulls first,SAMPLES desc]','<sql_data_point_id>',p_sql_data_point_id),'<defDTFmt>',defDataTimeFmt),'<defDTFullFmt>',defDataTimeFullFmt),
                                            p_width => gwWideSection1,
                                            p_summary => 'AWR ASH Plan stats',
                                            p_search => 'PLAN_HASH',
                                            p_replacement => HTF.ANCHOR (curl=>'#awrplan_\1',ctext=>'\1',cattributes=>'class="awr"'),
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --trctotr,
                                            p_header => gdHeaderRepeat, --number default 0,
                                            p_break_col => 'plan_hash_value',
                                            p_output => print_awr_ashplstats_section_base.p_output); --'
    p_output(p_output.count+1):=HTF.BR;

    p_output(p_output.count+1):=HTF.header (4,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Summary for each PLAN HASH per HOUR',cname=>'awrash_summ2',cattributes=>'class="awr"'),cattributes=>'class="awr"');

    p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#awrash_summ1',ctext=>'Summary for each PLAN HASH',cattributes=>'class="awr"'));
    p_output(p_output.count+1):=HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#awrash_summ2',ctext=>'Summary for each PLAN HASH per HOUR',cattributes=>'class="awr"'));
    p_output(p_output.count+1):=HTF.BR;

    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(replace(replace(q'[select snap,end_interval_time,
  plan_hash_value PLAN_HASH, FULL_PLAN_HASH_VALUE FULL_PLAN__HASH, PLAN_LINE_ID ID, PLAN_OPERATION ||' '|| PLAN_OPTIONS "Row source", EVENT, SAMPLES*10 "Time",
  round(100 * SAMPLES / sum(SAMPLES) over(partition by plan_hash_value), 2) "Time, %",
  round(100 * sum(SAMPLES) over(partition by PLAN_LINE_ID, plan_hash_value) / sum(SAMPLES) over(partition by plan_hash_value), 2) "Time by ID, %",
  obj "Object", tbs "Tablespace"
from
(select s.snap_id snap, to_char(sn.end_interval_time,'<defDTFullFmt>') end_interval_time,
        sql_plan_hash_value plan_hash_value, SQL_FULL_PLAN_HASH_VALUE FULL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID PLAN_LINE_ID,
        SQL_PLAN_OPERATION PLAN_OPERATION, SQL_PLAN_OPTIONS PLAN_OPTIONS, EVENT, sum(SAMPLES) SAMPLES, obj, tbs
from OPAS_OT_SQL_AWR_ASH_PLST s,
     OPAS_DB_LINK_AWRSNAPS sn,
     OPAS_OT_SQL_DATA dp
where s.sql_id = dp.sql_id
and s.snap_id = sn.snap_id
and sn.snap_id between dp.AWR_SNAP_START and dp.AWR_SNAP_END
and sn.instance_number = s.instance_number
and dp.dblink=sn.dblink
and dp.dblink=s.dblink
and dp.INCARNATION# = sn.INCARNATION#
and dp.INCARNATION# = s.INCARNATION#
and dp.SQL_DATA_POINT_ID = <sql_data_point_id>
group by s.snap_id, sn.end_interval_time, sql_plan_hash_value, SQL_FULL_PLAN_HASH_VALUE, SQL_PLAN_LINE_ID, SQL_PLAN_OPERATION, SQL_PLAN_OPTIONS, EVENT, obj, tbs)
order by snap,plan_hash_value,PLAN_LINE_ID nulls first,SAMPLES desc]','<sql_data_point_id>',p_sql_data_point_id),'<defDTFmt>',defDataTimeFmt),'<defDTFullFmt>',defDataTimeFullFmt),
                                            p_width => gwWideSection1,--'
                                            p_summary => 'AWR ASH Plan stats per snap',
                                            p_search => 'PLAN_HASH',
                                            p_replacement => HTF.ANCHOR (curl=>'#awrplan_\1',ctext=>'\1',cattributes=>'class="awr"'),
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            p_header => gdHeaderRepeat, --number default 0,
                                            p_break_col => 'SNAP',
                                            p_output => print_awr_ashplstats_section_base.p_output); --'
  end;

  procedure print_sql_text_web(p_sql_id              opas_ot_sql_data.sql_id%type,
                               p_output          out COREMOD_REPORT_UTILS.t_output_lines)
  is
    l_text     clob;
    l_length   number;
    l_file_id   opas_files.file_id%type;
  begin

    p_output(1):='<code class="codeView">';
    p_output(1):=p_output(1)||'<ol start="1">';

    select nvl(sql_text,sql_text_approx) into l_file_id from OPAS_OT_SQL_DESCRIPTIONS de where sql_id=p_sql_id;

    for i in (SELECT line_number, payload
                FROM V$OPAS_FILE_CONTENTBYROW
               where file_id=l_file_id
               order by line_number)
    loop
      l_text:=l_text||'<li id="L'||to_char(i.line_number)||'">'||apex_escape.html(i.payload) ||'</li>';
    end loop;

    l_length := dbms_lob.getlength(l_text);
    l_text := substr(l_text,1,32600);
    p_output(1) := p_output(1)||l_text;

    if l_length > 32600 then
      p_output(1) := p_output(1)||'...Truncated...';
    end if;

    p_output(1):=p_output(1)||'</ol>';
    p_output(1):=p_output(1)||'</code>';

  end;

  procedure print_section_web(p_output COREMOD_REPORT_UTILS.t_output_lines)
  is
  begin
    for i in 1..p_output.count loop
      htp.p(p_output(i));
    end loop;
  end;

  procedure print_sql_text_web(p_sql_id opas_ot_sql_data.sql_id%type)
  is
    l_output     COREMOD_REPORT_UTILS.t_output_lines;
  begin
    print_sql_text_web(p_sql_id, l_output);
    print_section_web(l_output);
  end;

  procedure print_section_html_i(p_sql_id              opas_ot_sql_data.sql_id%type,
                                 p_sql_data_point_id   opas_ot_sql_data.sql_data_point_id%type,
                                 p_section_name        varchar2,
                                 p_output          out COREMOD_REPORT_UTILS.t_output_lines)
  is
  begin

      case p_section_name
        when repsSQL_TEXT    then print_sql_text_web(p_sql_id,p_output);
        when repsSHARING     then print_nonshared_section_base(p_sql_data_point_id,p_output);
        when repsVSQL        then print_vsql_section_base(p_sql_data_point_id,p_output);
        when repsEXADATA     then print_exa_section_base(p_sql_data_point_id,p_output);
        when repsSQLMONV$    then print_sqlmon_section_base(p_sql_data_point_id,p_output);
        when repsWORKAREA    then print_wa_section_base(p_sql_data_point_id,p_output);
        when repsOPTENV      then print_oe_section_base(p_sql_data_point_id,p_output);
        when repsSQLPLLAST   then print_plan_section_base(p_sql_data_point_id,p_section_name,p_output);
        when repsSQLPLADV    then print_plan_section_base(p_sql_data_point_id,p_section_name,p_output);
        when repsSQLPLALL    then print_plan_section_base(p_sql_data_point_id,p_section_name,p_output);
        when repsSQLPLADAPT  then print_plan_section_base(p_sql_data_point_id,p_section_name,p_output);
        when repsSQLPLEP     then print_plan_ep_section_base(p_sql_data_point_id,p_output);
        when repsSQLMONHST   then print_sqlmon_hst_section_base(p_sql_data_point_id,p_output);
        when repsVASH        then print_vash_section_base(p_sql_data_point_id,p_output);
        when repsAWR_SQLSTAT then print_awr_sqlstat_section_base(p_sql_data_point_id,p_output);
        when repsAWR_BINDS       then print_awr_binds_section_base(p_sql_data_point_id,p_output);
        when repsAWR_SQLPLAN     then print_awr_plans_section_base(p_sql_data_point_id,p_output);
        when repsAWR_PLSQLSRC    then print_awr_plsqlsrc_section_base(p_sql_data_point_id,p_output);
        when repsAWR_ASHINVOKER  then print_awr_ashinv_section_base(p_sql_data_point_id,p_output);
        when repsAWR_ASHPLSTATS  then print_awr_ashplstats_section_base(p_sql_data_point_id,p_output);
      else
        null;
      end case;
  end;

  procedure print_section_html(p_sql_data_point_id   opas_ot_sql_data.sql_data_point_id%type,
                               p_section_name        varchar2,
                               p_sql_id              opas_ot_sql_data.sql_id%type)
  is
    l_status     opas_ot_sql_data_sect.gathering_status%type;
    l_errm       opas_ot_sql_data_sect.error_message%type;
    l_output     COREMOD_REPORT_UTILS.t_output_lines;
    l_mode       number := case when p_sql_data_point_id is null then 1 else 0 end; --0 data point mode; 1 - all data point mode
    l_sql_data_point_id   opas_ot_sql_data.sql_data_point_id%type;
  begin

    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_SQL_REPORT_UTILS.print_section_html.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_SQL_REPORT_UTILS.print_section_html.SQL_TRACE');

    for i in (select sql_data_point_id from opas_ot_sql_data where sql_id = p_sql_id and l_mode = 1 union
              select sql_data_point_id from opas_ot_sql_data where sql_data_point_id = p_sql_data_point_id and l_mode = 0
              order by 1)
    loop
      l_sql_data_point_id := i.sql_data_point_id;
      COREOBJ_SQL_UTILS.is_section_ready(l_sql_data_point_id,p_section_name,l_status,l_errm);

      if l_status = COREOBJ_SQL_UTILS.sstReady or
         (p_section_name = repsSQL_TEXT and l_status = COREOBJ_SQL_UTILS.sstNoSection)
      then
        if l_mode = 1 and p_section_name != repsSQL_TEXT then
          print_header(l_sql_data_point_id, 1);
        end if;
        print_section_html_i(p_sql_id, l_sql_data_point_id,p_section_name,l_output);

        if l_output is not null then
          print_section_web(l_output);
        end if;

      elsif l_status = COREOBJ_SQL_UTILS.sstFailed then
        htp.p('<b>Section name:</b> '|| COREMOD_DICT.gdicSQLREPSECT(p_section_name) ||'; <br>'|| l_errm);
      elsif l_status in (COREOBJ_SQL_UTILS.sstNotStarted, COREOBJ_SQL_UTILS.sstInProgress) then
        htp.p('<b>Section name:</b> '|| COREMOD_DICT.gdicSQLREPSECT(p_section_name) || ' <b>is not ready.</b>');
      elsif l_status = COREOBJ_SQL_UTILS.sstEmpty then
        htp.p('<b>Section name:</b> '|| COREMOD_DICT.gdicSQLREPSECT(p_section_name) || ' <b>is empty.</b>');
      end if;
      htp.small(get_section_duration(l_sql_data_point_id,p_section_name));
      htp.p('<br>');htp.p('<br>');

      if p_section_name = repsSQL_TEXT then exit; end if;
    end loop;

    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_SQL_REPORT_UTILS.PRINT_SECTION_HTML.SQL_TRACE');
    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_SQL_REPORT_UTILS.PRINT_SECTION_HTML.GATHER_SQL_STAT');
  end;

  function print_report_html(p_obj_id  opas_objects.obj_id%type,
                             p_section_list varchar2 default null) return TABLEOFSTRINGS pipelined
  is
    l_output              COREMOD_REPORT_UTILS.t_output_lines;
    l_str                 varchar2(32765);
    l_sql_data_point      opas_ot_sql_data%rowtype;
    l_object              opas_objects%rowtype;
    l_text                clob;
    --l_sub_plan_txtx       boolean := false;
    function doprint(p_section_nm varchar2) return boolean
    is
    begin
      return nvl(p_section_list, 'ALLSECTIONS') = 'ALLSECTIONS' or instr(p_section_list,p_section_nm)>0;
    end;
  begin

    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_SQL_REPORT_UTILS.PRINT_REPORT_HTML.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_SQL_REPORT_UTILS.PRINT_REPORT_HTML.SQL_TRACE');

    select * into l_object from opas_objects where obj_id=p_obj_id;

    select d.*
      into l_sql_data_point
      from OPAS_OT_SQL_DATA_POINT_REF r, OPAS_OT_SQL_DATA d
     where r.obj_id=p_obj_id and r.sql_data_point_id=d.sql_data_point_id;

    pipe row (HTF.HTMLOPEN);
    pipe row (HTF.HEADOPEN);
    pipe row (HTF.TITLE('SQL Report for SQL_ID='||l_sql_data_point.sql_id));

    pipe row ('<style type="text/css">');
    for i in (SELECT payload
                FROM V$OPAS_FILE_CONTENTBYROW
               where file_id=COREMOD_API.getconf('OPASAWR.CSS',COREMOD_API.getMODNAME)) loop
      pipe row (i.payload);
    end loop;
    pipe row ('</style>');
    pipe row (HTF.HEADCLOSE);
    pipe row (HTF.BODYOPEN(cattributes=>'class="awr"'));

    pipe row (HTF.header (1,'SQL Report for SQL_ID='||l_sql_data_point.sql_id,cattributes=>'class="awr"'));
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

    for i in (select d.DISPLAY_VAL,d.SPARSE1,s.GATHERING_STATUS, s.section_name
                from OPAS_DICTIONARY d, OPAS_OT_SQL_DATA_SECT s
               where d.val=s.SECTION_NAME
                 and s.SQL_DATA_POINT_ID=l_sql_data_point.sql_data_point_id
                 and d.MODNAME=COREMOD_API.getMODNAME
                 and d.DIC_NAME='SQLREPSECT'
               order by d.DIC_ORDR)
    loop
      if doprint(i.section_name) then
        if i.GATHERING_STATUS<>COREOBJ_SQL_UTILS.sstReady then
        pipe row (HTF.LISTITEM(cattributes=>'class="awr"',
                               ctext=>i.DISPLAY_VAL||' ('||i.GATHERING_STATUS||')'
                              )
                  );
        else
          pipe row (HTF.LISTITEM(cattributes=>'class="awr"',
                                 ctext=>HTF.ANCHOR (curl=>'#'||i.SPARSE1,
                                                    ctext=>i.DISPLAY_VAL,
                                                    cattributes=>'class="awr"'
                                                    )
                                )
                    );
        end if;
      end if;
    end loop;
    pipe row (HTF.BR);
    pipe row (HTF.BR);

    pipe row (HTF.header (3,cheader=>HTF.ANCHOR (curl=>'',ctext=>'Report description',cname=>'report_descr',cattributes=>'class="awr"'),cattributes=>'class="awr"'));
    pipe row (HTF.BR);

    --select SYS_CONNECT_BY_PATH(obj_name,' / ') into l_str from opas_objects where CONNECT_BY_ISLEAF = 1 start with obj_id=p_obj_id connect by prior obj_prnt=obj_id;
    l_str := coreobj_api.get_object_path(p_obj_id => p_obj_id,
                                         p_including_object => 'Y');

    --l_str:=ltrim(l_str,' / ');
    l_text:='SQL Data Point'||chr(10);
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

    for i in (select s.SECTION_NAME,d.DISPLAY_VAL,d.SPARSE1, nvl(q.SQL_TEXT,q.SQL_TEXT_APPROX) txt
                from OPAS_DICTIONARY d, OPAS_OT_SQL_DATA_SECT s, OPAS_OT_SQL_DESCRIPTIONS q, OPAS_OT_SQL_DATA dp
               where d.val=s.SECTION_NAME
                 and s.SQL_DATA_POINT_ID=l_sql_data_point.sql_data_point_id
                 and d.MODNAME=COREMOD_API.getMODNAME
                 and d.DIC_NAME='SQLREPSECT'
                 and s.GATHERING_STATUS=COREOBJ_SQL_UTILS.sstReady
                 and dp.sql_id=q.sql_id
                 and dp.sql_data_point_id=s.sql_data_point_id
               order by d.DIC_ORDR)
    loop
      if doprint(i.section_name) then
        pipe row (HTF.header (3,cheader=>HTF.ANCHOR (curl=>'',ctext=>i.DISPLAY_VAL,cname=>i.SPARSE1,cattributes=>'class="awr"'),cattributes=>'class="awr"'));

        if i.SECTION_NAME like 'SQLPL%' then

          for i in (select d.DISPLAY_VAL,d.SPARSE1,s.GATHERING_STATUS
                      from OPAS_DICTIONARY d, OPAS_OT_SQL_DATA_SECT s
                     where d.val=s.SECTION_NAME
                       and s.SQL_DATA_POINT_ID=l_sql_data_point.sql_data_point_id
                       and d.MODNAME=COREMOD_API.getMODNAME
                       and d.DIC_NAME='SQLREPSECT'
                       and s.SECTION_NAME like 'SQLPL%'
                       and s.GATHERING_STATUS=COREOBJ_SQL_UTILS.sstReady
                     order by d.DIC_ORDR)
          loop
            pipe row (HTF.LISTITEM(cattributes=>'class="awr"',
                                   ctext=>HTF.ANCHOR (curl=>'#'||i.SPARSE1,
                                                      ctext=>i.DISPLAY_VAL,
                                                      cattributes=>'class="awr"'
                                                      )
                                  )
                      );
          end loop;
          pipe row (HTF.BR);
        end if;

        pipe row (HTF.BR);

        if i.SECTION_NAME like 'AWR_%' then

          for i in (select d.DISPLAY_VAL,d.SPARSE1,s.GATHERING_STATUS
                      from OPAS_DICTIONARY d, OPAS_OT_SQL_DATA_SECT s
                     where d.val=s.SECTION_NAME
                       and s.SQL_DATA_POINT_ID=l_sql_data_point.sql_data_point_id
                       and d.MODNAME=COREMOD_API.getMODNAME
                       and d.DIC_NAME='SQLREPSECT'
                       and s.SECTION_NAME like 'AWR_%'
                       and s.GATHERING_STATUS=COREOBJ_SQL_UTILS.sstReady
                     order by d.DIC_ORDR)
          loop
            pipe row (HTF.LISTITEM(cattributes=>'class="awr"',
                                   ctext=>HTF.ANCHOR (curl=>'#'||i.SPARSE1,
                                                      ctext=>i.DISPLAY_VAL,
                                                      cattributes=>'class="awr"'
                                                      )
                                  )
                      );
          end loop;
          pipe row (HTF.BR);
        end if;
        pipe row (HTF.BR);

        if i.SECTION_NAME = repsSQL_TEXT then
          if i.txt is not null then
            COREMOD_FILE_UTILS.get_locator(i.txt, l_text);
          else
            l_text := 'No SQL text acailable';
          end if;
          COREMOD_REPORT_UTILS.convert_to_html_table (
            P_TEXT => 'SQL Text'||chr(10)||l_text,
            P_INPUT => l_output,
            P_T_HEADER => '#FIRST_LINE#',
            P_WIDTH => 0, --auto width
            --P_SEARCH => P_SEARCH,
            --P_REPLACEMENT => P_REPLACEMENT,
            --P_COMPARISON => P_COMPARISON,
            P_STYLE_TAB => 'trctd',
            P_STYLE_HEAD => 'trchd',
            P_STYLE_R1 => 'awrc1',--'trcr1',
            P_STYLE_R2 => 'awrnc1',--'trcr2',
            P_OUTPUT => l_output);
          for i in 1..l_output.count loop
            pipe row (substr(l_output(i),1,4000));
          end loop;
          l_output.delete;
        else
          print_section_html_i(l_sql_data_point.sql_id, l_sql_data_point.sql_data_point_id,i.SECTION_NAME,l_output);
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
        end if;
        l_output.delete;

        pipe row (HTF.BR);
        pipe row (HTF.LISTITEM(cattributes=>'class="awr"',ctext=>HTF.ANCHOR (curl=>'#tblofcont',ctext=>'Back to top',cattributes=>'class="awr"')));
        pipe row (HTF.BR);
      end if;
    end loop;

    pipe row (HTF.BODYCLOSE);
    pipe row (HTF.HTMLCLOSE);

    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_SQL_REPORT_UTILS.PRINT_REPORT_HTML.SQL_TRACE');
    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_SQL_REPORT_UTILS.PRINT_REPORT_HTML.GATHER_SQL_STAT');
  end;

  function prepare_report_4download(p_obj_id  opas_objects.obj_id%type,
                                    p_section_list varchar2) return opas_files.file_id%type
  is
    l_file_id    opas_files.file_id%type;
    l_sql_data_point      opas_ot_sql_data%rowtype;
    l_text                clob;
  begin

    COREMOD_LOG.Start_SQL_GATHER_STAT('COREOBJ_SQL_REPORT_UTILS.PREPARE_REPORT_4DOWNLOAD.GATHER_SQL_STAT');
    COREMOD_LOG.Start_SQL_TRACE('COREOBJ_SQL_REPORT_UTILS.PREPARE_REPORT_4DOWNLOAD.SQL_TRACE');

    select d.*
      into l_sql_data_point
      from OPAS_OT_SQL_DATA_POINT_REF r, OPAS_OT_SQL_DATA d
     where r.obj_id=p_obj_id and r.sql_data_point_id=d.sql_data_point_id;

    l_file_id := COREMOD_FILE_UTILS.create_tmp_4downl(
      P_FILE_NAME => 'opas60_sqldp_'||l_sql_data_point.sql_id||'.html',
      P_MIMETYPE => COREMOD_FILE_UTILS.mtHTML);

    for i in (select column_value from table(COREOBJ_SQL_REPORT_UTILS.print_report_html(p_obj_id, p_section_list)))
    loop
      l_text := l_text || i.column_value || chr(10);
    end loop;

    COREMOD_FILE_UTILS.store_content (
       P_FILE_ID => l_file_id,
       P_CONTENT => l_text) ;

    coremod_file_utils.clob2blob_prep(p_file_id => l_file_id);

    COREMOD_LOG.Stop_SQL_TRACE('COREOBJ_SQL_REPORT_UTILS.PREPARE_REPORT_4DOWNLOAD.SQL_TRACE');
    COREMOD_LOG.Stop_SQL_GATHER_STAT('COREOBJ_SQL_REPORT_UTILS.PREPARE_REPORT_4DOWNLOAD.GATHER_SQL_STAT');

    return l_file_id;
  end;

END COREOBJ_SQL_REPORT_UTILS;
/
