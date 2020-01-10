CREATE OR REPLACE
PACKAGE BODY COREOBJ_SQL_REPORT_UTILS AS

  gwNarrowSection    constant number := 600;
  gwWideSection1     constant number := 1200;

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
    l_result varchar2(32765) := '<br><b>SQL Monitor:</b> Days=<SQLMONHSTDays>; Rows=<SQLMONHSTRows>; <b>AWR:</b> Days=<AWRDataDays>; Search last day=<AWRSearchLastDays>; Start Date=<AWRStartDT>; End Date=<AWREndDT>';
    l_obj_id opas_ot_sql_data_point_ref.obj_id%type;
  begin
    select obj_id into l_obj_id from opas_ot_sql_data_point_ref where sql_data_point_id = p_sql_data_point_id;
    l_result := replace(l_result, '<SQLMONHSTDays>',     nvl( COREOBJ_API.get_param_n(l_obj_id, COREOBJ_SQL_UTILS.pnSQLMONHSTDays,     true), COREOBJ_SQL_UTILS.defSQLMONHSTDays));
    l_result := replace(l_result, '<SQLMONHSTRows>',     nvl( COREOBJ_API.get_param_n(l_obj_id, COREOBJ_SQL_UTILS.pnSQLMONHSTRows,     true), COREOBJ_SQL_UTILS.defSQLMONHSTRows));
    l_result := replace(l_result, '<AWRDataDays>',       nvl( COREOBJ_API.get_param_n(l_obj_id, COREOBJ_SQL_UTILS.pnAWRDataDays,       true), COREOBJ_SQL_UTILS.defAWRDataDays));
    l_result := replace(l_result, '<AWRSearchLastDays>', nvl( COREOBJ_API.get_param_c(l_obj_id, COREOBJ_SQL_UTILS.pnAWRSearchLastDays, true), COREOBJ_SQL_UTILS.defAWRSearchLastDays));

    l_result := replace(l_result, '<AWRStartDT>', nvl(to_char( COREOBJ_API.get_param_d(l_obj_id, COREOBJ_SQL_UTILS.pnAWRStartDT, true), 'YYYY/MM/DD HH24:MI'),'Not Specified'));
    l_result := replace(l_result, '<AWREndDT>',   nvl(to_char( COREOBJ_API.get_param_d(l_obj_id, COREOBJ_SQL_UTILS.pnAWREndDT,   true), 'YYYY/MM/DD HH24:MI'),'Not Specified'));
    return l_result;
  end;

  procedure print_header(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type)
  is
  begin
    for i in (select x.*,to_char(cast((x.END_GATHERING_DT-x.START_GATHERING_DT) AS INTERVAL DAY(2) TO SECOND(3))) dur,
                     (select listagg('<b>'||gathering_status||':</b> '||cnt,'; ') within group (order by gathering_status)
                        from (select gathering_status, count(1) cnt
                                from OPAS_OT_SQL_DATA_SECT where sql_data_point_id = p_sql_data_point_id group by gathering_status)) sect_statuses
                from opas_ot_sql_data x where sql_data_point_id = p_sql_data_point_id) loop
      htp.p('<b>Gathering status:</b> '||i.gathering_status||'; ');
      if i.START_GATHERING_DT is not null then
        htp.p('<b>Started:</b> '||to_char(i.START_GATHERING_DT,'YYYY-MON-DD HH24:MI')||'; ');
      end if;
      if i.END_GATHERING_DT is not null then
        htp.p('<b>Finished:</b> '||to_char(i.END_GATHERING_DT,'YYYY-MON-DD HH24:MI')||'; <b>Duration:</b> '||i.dur);
      end if;
      if i.sect_statuses is not null and i.END_GATHERING_DT is null then
        htp.p('<b>Sections:</b> '||i.sect_statuses);
      end if;
      --htp.p(' <b>sysdate:</b> '||to_char(sysdate,'YYYY-MON-DD HH24:MI:SS'));
      htp.p(print_data_point_params(p_sql_data_point_id));
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
                                            --p_header number default 0,
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
      p('=================================================================================================');
      p('SQL_ID='||i.sql_id||'; CHILD_NUMBER='||i.child_number||'; PLAN HASH: '||i.PLAN_HASH_VALUE||'; Opt Env Hash: '||i.OPTIMIZER_ENV_HASH_VALUE||';'||' INST_ID: '||i.inst_id);
	  p('FORCE_MATCHING_SIGN: '||i.force_matching_signature||'; OLD_HASH_VALUE: '||i.OLD_HASH_VALUE);
	  begin
  	  select object_type||': '||owner||'.'||object_name into l_on from opas_ot_sql_vsql_objs s where s.object_id=i.program_id and s.CHILD_NUMBER = i.CHILD_NUMBER and s.sql_data_point_id = p_sql_data_point_id;
	    p(l_on||', line number: '||i.program_line#);
	    exception when no_data_found then null;
	  end;
      p('-------------------------------------------------------------------------------------------------');
      p('Parsing Schema, Module, Action: '||nvl(i.parsing_schema_name,'<NULL>')||', '||nvl(i.module,'<NULL>')||', '||nvl(i.action,'<NULL>'));
      p('Load_time, First: '||i.first_load_time||', Last: '||i.last_load_time||', Active: '||to_char(i.last_active_time,'dd/mm/yyyy hh24:mi:ss'));
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
      p('-------------------------------------------------------------------------------------------------');
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
	      p('-------------------------------------------------------------------------------------------------');
		  p('Saved %: '||round(100 * (i.IO_CELL_OFFLOAD_ELIGIBLE_BYTES - i.IO_INTERCONNECT_BYTES) / case when i.IO_CELL_OFFLOAD_ELIGIBLE_BYTES=0 then 1 else i.IO_CELL_OFFLOAD_ELIGIBLE_BYTES end,2));
          p('IO_CELL_OFFLOAD_ELIGIBLE_BYTES: '||COREMOD_REPORT_UTILS.tptformat(i.IO_CELL_OFFLOAD_ELIGIBLE_BYTES));
	      p('IO_INTERCONNECT_BYTES:          '||COREMOD_REPORT_UTILS.tptformat(i.IO_INTERCONNECT_BYTES));
	      p('OPTIMIZED_PHY_READ_REQUESTS:    '||COREMOD_REPORT_UTILS.tptformat(i.OPTIMIZED_PHY_READ_REQUESTS));
	      p('IO_CELL_UNCOMPRESSED_BYTES:     '||COREMOD_REPORT_UTILS.tptformat(i.IO_CELL_UNCOMPRESSED_BYTES));
	      p('IO_CELL_OFFLOAD_RETURNED_BYTES: '||COREMOD_REPORT_UTILS.tptformat(i.IO_CELL_OFFLOAD_RETURNED_BYTES));
          p('=================================================================================================');
	    end if;
      $END
      p(' ');
    end loop;

    COREMOD_REPORT_UTILS.convert_to_html_table (
      P_TEXT => null,
      P_INPUT => l_output,
      P_T_HEADER => 'V$SQL',
      P_WIDTH => gwNarrowSection,
      --P_SEARCH => P_SEARCH,
      --P_REPLACEMENT => P_REPLACEMENT,
      --P_COMPARISON => P_COMPARISON,
      P_STYLE_TAB => 'trctd',
      P_STYLE_HEAD => 'trchd',
      P_STYLE_R1 => 'awrc1',--'trcr1',
      P_STYLE_R2 => 'awrnc1',--'trcr2',
      P_OUTPUT => p_output);

  END print_vsql_section_base;

  procedure print_exa_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                  p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    p_output(1):='Exadata statistics';
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
    p_output(p_output.count+1):='Exadata details';
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
order by 1,2]','<sql_data_point_id>',p_sql_data_point_id),
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
  begin

    for i in (select m.sql_mon_report from opas_ot_sql_sqlmon_ref r, opas_ot_sql_sqlmon m where r.sqlmon_id = m.sqlmon_id and r.sql_data_point_id = p_sql_data_point_id and sql_mon_report is not null
               order by sql_exec_start desc) loop
      COREMOD_FILE_UTILS.get_locator(i.sql_mon_report, l_text);
      COREMOD_REPORT_UTILS.convert_to_html_table (
        P_TEXT => l_text,
        P_INPUT => p_output,
        P_T_HEADER => '#FIRST_LINE#',
        P_WIDTH => 0, --auto width
        --P_SEARCH => P_SEARCH,
        --P_REPLACEMENT => P_REPLACEMENT,
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
  begin

    l_display_params:='ALL ALLSTATS +peeked_binds';  l_capture := 'Execution plans extracted from SQL Monitor History';

    for i in (select m.sql_mon_report, d.SQL_PLAN_HASH_VALUE, d.SQL_FULL_PLAN_HASH_VALUE, m.plan_id
                from opas_ot_sql_sqlmon_ref r,
                     opas_ot_sql_sqlmon m,
                     OPAS_OT_SQL_SQLMON_DATA d
               where r.sqlmon_id = m.sqlmon_id
                 and r.sql_data_point_id = p_sql_data_point_id
                 and m.sql_mon_report is not null
                 and m.source = COREOBJ_SQL_UTILS.srcHST
                 and d.sqlmon_id = m.sqlmon_id
               order by sql_exec_start desc)
    loop

      COREMOD_FILE_UTILS.get_locator(i.sql_mon_report, l_text);
      COREMOD_REPORT_UTILS.convert_to_html_table (
        P_TEXT => l_text,
        P_INPUT => p_output,
        P_T_HEADER => '#FIRST_LINE#',
        P_WIDTH => 0, --auto width
        --P_SEARCH => P_SEARCH,
        --P_REPLACEMENT => P_REPLACEMENT,
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
          --P_SEARCH => P_SEARCH,
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
                                            p_summary => 'Workareas',
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
                                            --p_header number default 0,
                                            p_break_col => 'inst_id',
                                            p_output => print_oe_section_base.p_output);
  end;

  procedure print_plan_section_base(p_sql_data_point_id       opas_ot_sql_data.sql_data_point_id%type,
                                    p_section_name  varchar2,
                                    p_output    out COREMOD_REPORT_UTILS.t_output_lines) AS
    --l_indx number := 1;
    l_display_params varchar2(100);
    l_capture        varchar2(100);
    l_header         clob;
    l_plan_filter    varchar2(10);
  begin
    case p_section_name
      when repsSQLPLLAST  then l_display_params:='LAST ALLSTATS +peeked_binds'; l_capture := 'Display cursor (last)'; l_plan_filter := COREOBJ_SQL_UTILS.srcV$;
      when repsSQLPLADV   then l_display_params:='LAST ADVANCED';               l_capture := 'Display cursor (LAST ADVANCED)'; l_plan_filter := COREOBJ_SQL_UTILS.srcV$;
      when repsSQLPLALL   then l_display_params:='ALL ALLSTATS +peeked_binds';  l_capture := 'Display cursor (ALL)'; l_plan_filter := COREOBJ_SQL_UTILS.srcV$;
      when repsSQLPLADAPT then l_display_params:='adaptive LAST ALLSTATS +peeked_binds'; l_capture := 'Display cursor (ADAPTIVE)'; l_plan_filter := COREOBJ_SQL_UTILS.srcV$;
      --when repsSQLPLAWR   then l_display_params:='LAST ALLSTATS +peeked_binds';
    end case;

    l_header := l_capture||chr(10)||'================================';
    COREMOD_REPORT_UTILS.convert_to_html_table (
        P_TEXT => l_header,
        P_INPUT => p_output,
        P_T_HEADER => '#FIRST_LINE#',
        P_WIDTH => 0, --auto width
        --P_SEARCH => P_SEARCH,
        --P_REPLACEMENT => P_REPLACEMENT,
        --P_COMPARISON => P_COMPARISON,
        P_STYLE_TAB => 'trctd',
        P_STYLE_HEAD => 'trchd',
        P_STYLE_R1 => 'awrc1',--'trcr1',
        P_STYLE_R2 => 'awrnc1',--'trcr2',
        P_OUTPUT => p_output);

    for plans in (select * from (select unique r.PLAN_ID,d.INST_ID,d.PLAN_HASH_VALUE,d.FULL_PLAN_HASH_VALUE,d.CHILD_NUMBER
                    from OPAS_OT_SQL_PLAN_REF r, OPAS_OT_SQL_PLAN_DET d, OPAS_OT_SQL_PLANS p
                   where r.sql_data_point_id=p_sql_data_point_id
                     and r.plan_id=p.plan_id
                     and p.plan_source = l_plan_filter
                     and r.plan_id=d.plan_id)
                   order by INST_ID, CHILD_NUMBER, PLAN_ID) loop
      l_header := 'Instance number: '||plans.INST_ID||'; Child number: '||plans.CHILD_NUMBER;
      l_header := l_header ||chr(10)||'Plan hash value: '||plans.PLAN_HASH_VALUE||'; Plan full hash value: '||plans.FULL_PLAN_HASH_VALUE;

      COREMOD_REPORT_UTILS.convert_to_html_table (
        P_TEXT => l_header,
        P_INPUT => p_output,
        P_T_HEADER => '#FIRST_LINE#',
        P_WIDTH => 0, --auto width
        --P_SEARCH => P_SEARCH,
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
                                              ,'<PLAN_ID>',plans.PLAN_ID)
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
                                            p_output => print_plan_section_base.p_output);
    end loop;
  end;

  procedure print_vash_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                    p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin

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
                                            --p_header number default 0,
                                            p_break_col => 'plan_hash_value',
                                            p_output => print_vash_section_base.p_output);

    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(q'[select to_char(SQL_EXEC_START,'YYYY-MM-DD HH24:MI:SS') SQL_EXEC_START, to_char(sql_exec_end,'YYYY-MM-DD HH24:MI:SS') sql_exec_end, plan_hash_value, id, row_src, event, cnt, tim_pct, tim_id_pct, obj, tbs
  from OPAS_OT_SQL_VASH1 x where sql_data_point_id = <sql_data_point_id>
 order by SQL_EXEC_START, plan_hash_value, id, event]','<sql_data_point_id>',p_sql_data_point_id),
                                            p_width => gwWideSection1,
                                            p_summary => 'V$ASH Details',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => null, --'trctotr',
                                            --p_header number default 0,
                                            p_break_col => 'SQL_EXEC_START',
                                            p_output => print_vash_section_base.p_output);

  end;

  procedure print_awr_sqlstat_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                           p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin

    COREMOD_REPORT_UTILS.print_query_result_html (
p_query => replace(q'[with data1 as (
select
        s.snap_id snap,to_char(sn.end_interval_time,'dd/mm/yyyy hh24:mi:ss') end_interval_time
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
  sum(iowait_delta_sec), sum(disk_reads_delta), sum(buffer_gets_delta), sum(rows_processed_delta), avg(lio_per_row), avg(io_per_row), avg(awg_io_tim),
  1 noprn_lastrow
FROM data1
order by snap nulls last, inst_id]','<sql_data_point_id>',p_sql_data_point_id),
                                            p_width => gwWideSection1,
                                            p_summary => 'AWR SQL statistics',
                                            --p_search varchar2 default null,
                                            --p_replacement varchar2 default null,
                                            p_style_tab => 'trctd',
                                            p_style_head => 'trchd', --head
                                            p_style_r1 => 'trcr1',   --odd rows
                                            p_style_r2  => 'trcr2', --even rows
                                            p_style_finrow => 'trctotr',
                                            --p_header number default 0,
                                            p_break_col => 'PLAN_HASH',
                                            p_output => print_awr_sqlstat_section_base.p_output);

  end;

  procedure print_awr_binds_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                           p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    null;
  end;

  procedure print_awr_plans_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                           p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    null;
  end;

  procedure print_awr_plsqlsrc_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                           p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    null;
  end;

  procedure print_awr_ashinv_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                           p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    null;
  end;

  procedure print_awr_ashplstats_section_base(p_sql_data_point_id    opas_ot_sql_data.sql_data_point_id%type,
                                           p_output out COREMOD_REPORT_UTILS.t_output_lines) AS
  begin
    null;
  end;

  procedure print_sql_text_web(p_sql_data_point_id   opas_ot_sql_data.sql_data_point_id%type)
  is
  begin
    htp.prn('<code class="codeView">');
    htp.prn('<ol start="1">');

    for i in (SELECT line_number, payload
                FROM V$OPAS_FILE_CONTENTBYROW
               where file_id=(select nvl(sql_text,sql_text_approx)
                                from OPAS_OT_SQL_DESCRIPTIONS de,
                                     OPAS_OT_SQL_DATA da
                               where de.sql_id = da.sql_id
                                 and da.sql_data_point_id=p_sql_data_point_id)
               order by line_number)
    loop
      htp.prn('<li id="L'||to_char(i.line_number)||'">'||apex_escape.html(i.payload) ||'</li>');
    end loop;

    htp.p('</ol>');
    htp.p('</code>');
  end;

  procedure print_section_web(p_output COREMOD_REPORT_UTILS.t_output_lines)
  is
  begin
    for i in 1..p_output.count loop
      htp.p(p_output(i));
    end loop;
  end;

  procedure print_section_html(p_sql_data_point_id   opas_ot_sql_data.sql_data_point_id%type,
                               p_section_name varchar2)
  is
    l_status     opas_ot_sql_data_sect.gathering_status%type;
    l_errm       opas_ot_sql_data_sect.error_message%type;
    l_output     COREMOD_REPORT_UTILS.t_output_lines;
  begin
    COREOBJ_SQL_UTILS.is_section_ready(p_sql_data_point_id,p_section_name,l_status,l_errm);

    if l_status = COREOBJ_SQL_UTILS.sstReady then
      case p_section_name
        when repsSQL_TEXT    then print_sql_text_web(p_sql_data_point_id);
        when repsSHARING     then print_nonshared_section_base(p_sql_data_point_id,l_output);
        when repsVSQL        then print_vsql_section_base(p_sql_data_point_id,l_output);
        when repsEXADATA     then print_exa_section_base(p_sql_data_point_id,l_output);
        when repsSQLMONV$    then print_sqlmon_section_base(p_sql_data_point_id,l_output);
        when repsWORKAREA    then print_wa_section_base(p_sql_data_point_id,l_output);
        when repsOPTENV      then print_oe_section_base(p_sql_data_point_id,l_output);
        when repsSQLPLLAST   then print_plan_section_base(p_sql_data_point_id,p_section_name,l_output);
        when repsSQLPLADV    then print_plan_section_base(p_sql_data_point_id,p_section_name,l_output);
        when repsSQLPLALL    then print_plan_section_base(p_sql_data_point_id,p_section_name,l_output);
        when repsSQLPLADAPT  then print_plan_section_base(p_sql_data_point_id,p_section_name,l_output);
        when repsSQLMONHST   then print_sqlmon_hst_section_base(p_sql_data_point_id,l_output);
        when repsVASH        then print_vash_section_base(p_sql_data_point_id,l_output);
        when repsAWR_SQLSTAT then print_awr_sqlstat_section_base(p_sql_data_point_id,l_output);

        when repsAWR_BINDS       then print_awr_binds_section_base(p_sql_data_point_id,l_output);
        when repsAWR_SQLPLAN     then print_awr_plans_section_base(p_sql_data_point_id,l_output);
        when repsAWR_PLSQLSRC    then print_awr_plsqlsrc_section_base(p_sql_data_point_id,l_output);
        when repsAWR_ASHINVOKER  then print_awr_ashinv_section_base(p_sql_data_point_id,l_output);
        when repsAWR_ASHPLSTATS  then print_awr_ashplstats_section_base(p_sql_data_point_id,l_output);
      else
        null;
      end case;
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
    htp.small(get_section_duration(p_sql_data_point_id,p_section_name));
  end;

END COREOBJ_SQL_REPORT_UTILS;
/
