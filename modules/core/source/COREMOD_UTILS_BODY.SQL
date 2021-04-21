

CREATE OR REPLACE
PACKAGE BODY COREMOD_UTILS AS

  function  lsttochr(p_list tableofnumbers) return varchar2
  is
    l_ret varchar2(4000);
  begin
    for i in 1..p_list.count loop
      l_ret:=l_ret||p_list(i)||',';
    end loop;
    return rtrim(l_ret,',');
  end;

  function bool2str(p_bool boolean) return varchar2
  is
  begin
    if p_bool is not null then
      if p_bool then return 'TRUE'; else return 'FALSE'; end if;
    else
      return 'NULL';
    end if;
  end;

  function get_remote_oracle_version(p_dblink opas_db_links.db_link_name%type) return number
  is
    l_ver  varchar2(100);
  begin
    l_ver := get_remote_full_oracle_version(p_dblink);
    return to_number(substr(l_ver,1,instr(l_ver,'.')-1));
  end;

  function get_remote_full_oracle_version(p_dblink opas_db_links.db_link_name%type) return varchar2
  is
    l_sql  varchar2(1000) := q'[begin dbms_utility.db_version<DBLINK>(:a, :b); end;]';
    l_ver  varchar2(100);
    l_comp varchar2(100);
    l_task number;
  begin
    if COREMOD_API.external_mode_dblink(p_dblink) then
      l_sql := replace(l_sql,'<DBLINK>',COREMOD_API.get_dblink_for_query(p_dblink));
      execute immediate l_sql using out l_ver, out l_comp;
    elsif COREMOD_API.external_mode_javasrv(p_dblink) then

      l_task := COREMOD_EXTPROC.create_plsql_task(P_PLSQL_BODY => l_sql,
                                                  P_DBLINK => get_remote_full_oracle_version.p_dblink,
                                                  P_PRIORITY => 3);

      COREMOD_EXTPROC.add_param (  P_TASK_ID => l_task,
                                   P_IO_TYPE => 'OUT',
                                   P_ORDR_NUM => 1,
                                   p_varchar2 => null
                                ) ;
      COREMOD_EXTPROC.add_param (  P_TASK_ID => l_task,
                                   P_IO_TYPE => 'OUT',
                                   P_ORDR_NUM => 2,
                                   p_varchar2 => null
                                ) ;

      COREMOD_EXTPROC.execute_plsql_task (  P_TASK_ID => l_task,
                                            P_TIMEOUT => 60) ;

      COREMOD_EXTPROC.get_param (  P_TASK_ID => l_task,
                                   P_ORDR_NUM => 1,
                                   P_VARCHAR2 => l_ver) ;

      COREMOD_EXTPROC.get_param (  P_TASK_ID => l_task,
                                   P_ORDR_NUM => 2,
                                   P_VARCHAR2 => l_comp) ;
    else
      raise_application_error(-20000,'Unsupported external execution mode for DB Link (get_remote_full_oracle_version): '||p_dblink);
    end if;

    return l_ver;
  end;

  function get_remote_ts(p_dblink opas_db_links.db_link_name%type) return timestamp with time zone
  is
    l_sql1  varchar2(1000) := q'[select systimestamp from dual<DBLINK>]';
    l_sql2  varchar2(1000) := q'[begin :ts := to_char(systimestamp,'yyyymmddhh24miss.ff9 tzh:tzm'); end;]';
    l_ts  timestamp with time zone;
    l_task number;
    l_ts_str varchar2(100);
  begin
    if COREMOD_API.external_mode_dblink(p_dblink) then
      l_sql1 := replace(l_sql1,'<DBLINK>',COREMOD_API.get_dblink_for_query(p_dblink));
      execute immediate l_sql1 into l_ts;
    elsif COREMOD_API.external_mode_javasrv(p_dblink) then

      l_task := COREMOD_EXTPROC.create_plsql_task(P_PLSQL_BODY => l_sql2,
                                                  P_DBLINK => get_remote_ts.p_dblink,
                                                  P_PRIORITY => 3);

      COREMOD_EXTPROC.add_param (  P_TASK_ID => l_task,
                                   P_IO_TYPE => 'OUT',
                                   P_ORDR_NUM => 1,
                                   p_varchar2 => null) ;

      COREMOD_EXTPROC.execute_plsql_task (  P_TASK_ID => l_task,
                                            P_TIMEOUT => 60) ;

      COREMOD_EXTPROC.get_param (  P_TASK_ID => l_task,
                                   P_ORDR_NUM => 1,
                                   p_varchar2 => l_ts_str) ;

      l_ts := to_timestamp_tz(l_ts_str,'yyyymmddhh24miss.ff9 tzh:tzm');
    else
      raise_application_error(-20000,'Unsupported external execution mode for DB Link (get_remote_ts): '||p_dblink);
    end if;

    return l_ts;
  end;

  procedure execute_plsql_remotelly_dblink(p_sql varchar2, p_dblink varchar2, p_output out clob, p_is_output boolean default true)
  is
    l_theCursor     integer;
    l_status        integer;
    l_line          varchar2(32767);
    l_output        varchar2(32767);
    l_open          boolean;
    l_sql2exec      varchar2(32767);
    l_dblink        varchar2(128) := COREMOD_API.get_dblink_for_query(p_dblink);
    l_sql clob:=
q'[declare l_out clob; l_len number; l_chunk varchar2(32767); l_status integer; l_pos number; l_chunk_length number := 32767; l_r raw(32767); l_rc raw(32767);
begin
DBMS_OUTPUT.ENABLE(NULL);
<PLSQL_BLOCK>
]'||
case when p_is_output then
q'[loop DBMS_OUTPUT.GET_LINE(l_chunk,l_status); exit when l_status=1; l_out:=l_out||l_chunk||chr(10); end loop;
if l_out is null then l_out:='<NO_DATA_FOUND>';end if;
l_pos:=1;l_len:=length(l_out);
loop
l_chunk:=substr(l_out,l_pos,l_chunk_length); l_pos:=l_pos+l_chunk_length; l_r:=utl_raw.cast_to_raw(l_chunk); l_rc:=UTL_COMPRESS.LZ_COMPRESS(l_r); dbms_output.put(l_rc);
 DBMS_OUTPUT.NEW_LINE; exit when l_len<l_pos; end loop;
exception when no_data_found then l_out := '<NO_DATA_FOUND>';
end;]'
else q'[end;]' end;
    l_time number := 0;
  begin
    coremod_log.log(p_sql,'DEBUG');
    l_sql:=replace(l_sql,'<PLSQL_BLOCK>',p_sql);
    if length(l_sql) > 32767 then raise_application_error(-20000,'SQL <'||substr(l_sql,1,100)||'...> too long for remote table printing.');end if;
    l_sql2exec:=l_sql;
--dbms_output.put_line(l_sql2exec);
--coremod_log.log('l_sql2exec: '||l_sql2exec);
    l_time:=DBMS_UTILITY.GET_TIME;
    execute immediate 'begin :p_theCursor:=dbms_sql.open_cursor'||l_dblink||'; end;' using out l_theCursor;
    execute immediate 'begin dbms_sql.parse'||l_dblink||'(:p_theCursor, :p_stmt , :p_flg ); end;' using l_theCursor, l_sql2exec, dbms_sql.native;
    execute immediate 'begin :a:=dbms_sql.execute'||l_dblink||'(:p_theCursor); end;' using out l_status, in l_theCursor;
    execute immediate 'begin dbms_sql.close_cursor'||l_dblink||'(:p_theCursor); end;' using in out l_theCursor;
    l_time:=DBMS_UTILITY.GET_TIME-l_time;
    coremod_log.log('Executing: '||(l_time/100),'DEBUG');
    l_time:=DBMS_UTILITY.GET_TIME;
    loop
      execute immediate 'begin DBMS_OUTPUT.GET_LINE'||l_dblink||'(line => :p_line, status => :p_status); end;' using out l_line, out l_status;
      exit when l_status=1;
      --p_output:=p_output||l_line||chr(10);
      p_output:=p_output||utl_raw.cast_to_varchar2(UTL_COMPRESS.LZ_UNCOMPRESS(l_line));
    end loop;
    if instr(p_output,'<NO_DATA_FOUND>')>0 then p_output:=null; end if;
    l_time:=DBMS_UTILITY.GET_TIME-l_time;
    coremod_log.log('Getting output: '||(l_time/100),'DEBUG');
  exception
    when others then
       execute immediate 'begin :p_open:=dbms_sql.IS_OPEN'||l_dblink||'(:p_theCursor); end;' using out l_open, in l_theCursor;
      if l_open then
        execute immediate 'begin dbms_sql.close_cursor'||l_dblink||'(:p_theCursor); end;' using in out l_theCursor;
      end if;
      coremod_log.log('execute_plsql_remotelly: Error: '||sqlerrm);
      coremod_log.log('execute_plsql_remotelly: Original SQL: '||p_sql);
      coremod_log.log('execute_plsql_remotelly: Final SQL: '||l_sql2exec);
      coremod_log.log('execute_plsql_remotelly: Error stack: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      raise_application_error(-20000,'Error in COREMOD_REPORT_UTILS.execute_plsql_remotelly: '||sqlerrm);
  end;

  procedure get_clob_remotelly(p_sql varchar2, p_dblink varchar2, p_output out clob, p_timeout number default 600)
  is
  begin
    execute_plsql_remotelly(p_sql, p_dblink, p_output, true, p_timeout);
  end;

  procedure execute_plsql_remotelly(p_sql            varchar2,
                                    p_dblink         varchar2,
                                    p_output         out clob,
                                    p_is_output      boolean default true,
                                    p_timeout        number default 600,
                                    p_priority       number default 3,
                                    p_is_parent_task boolean default false,
                                    p_parent_task    number default null)
  is
    l_task   number;
    l_output varchar2(4000);
  begin
    if COREMOD_API.external_mode_dblink(p_dblink) then
      execute_plsql_remotelly_dblink(p_sql, p_dblink, p_output, p_is_output);
    elsif COREMOD_API.external_mode_javasrv(p_dblink) then
    --  raise_application_error(-20000,'Unimplemented execute_plsql_remotelly for SQL*Plus');
      l_task := COREMOD_EXTPROC.create_plsql_task(P_PLSQL_BODY => 'declare l_outclob clob := null; begin '||replace(p_sql,'l_out','l_outclob')||' :l_out := l_outclob; exception when no_data_found then null; end;',
                                                  P_DBLINK => execute_plsql_remotelly.p_dblink,
                                                  P_PRIORITY => execute_plsql_remotelly.p_priority,
                                                  p_is_parent_task => execute_plsql_remotelly.p_is_parent_task,
                                                  p_parent_task => execute_plsql_remotelly.p_parent_task);
      if p_is_output then
        COREMOD_EXTPROC.add_param (  P_TASK_ID => l_task,
                                     P_IO_TYPE => 'OUT',
                                     P_ORDR_NUM => 1,
                                     p_clob => null) ;
      end if;
      COREMOD_EXTPROC.execute_plsql_task (  P_TASK_ID => l_task,
                                            P_TIMEOUT => p_timeout) ;
      if p_is_output then
        COREMOD_EXTPROC.get_param (  P_TASK_ID => l_task,
                                     P_ORDR_NUM => 1,
                                     p_clob => p_output) ;
        --p_output := l_output;
      end if;
    end if;
  end;
END COREMOD_UTILS;
/


