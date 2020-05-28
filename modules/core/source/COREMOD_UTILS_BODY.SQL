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
    l_sql  varchar2(1000) := q'[begin dbms_utility.db_version]'||COREMOD_API.get_dblink_for_query(p_dblink)||q'[(:a, :b); end;]';
    l_ver  varchar2(100);
    l_comp varchar2(100);
  begin
    execute immediate l_sql using out l_ver, out l_comp;
    return to_number(substr(l_ver,1,instr(l_ver,'.')-1));
  end;

  function get_remote_ts(p_dblink opas_db_links.db_link_name%type) return timestamp with time zone
  is
    l_sql  varchar2(1000) := q'[select systimestamp from dual]'||COREMOD_API.get_dblink_for_query(p_dblink);
    l_ts  timestamp with time zone;
  begin
    execute immediate l_sql into l_ts;
    return l_ts;
  end;

  procedure execute_plsql_remotelly(p_sql varchar2, p_dblink varchar2, p_output out clob, p_is_output boolean default true)
  is
    l_theCursor     integer;
    l_status        integer;
    l_line          varchar2(32767);
    l_output        varchar2(32767);
    l_open          boolean;
    l_sql2exec      varchar2(32767);
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
    execute immediate 'begin :p_theCursor:=dbms_sql.open_cursor@'||p_dblink||'; end;' using out l_theCursor;
    execute immediate 'begin dbms_sql.parse@'||p_dblink||'(:p_theCursor, :p_stmt , :p_flg ); end;' using l_theCursor, l_sql2exec, dbms_sql.native;
    execute immediate 'begin :a:=dbms_sql.execute@'||p_dblink||'(:p_theCursor); end;' using out l_status, in l_theCursor;
    execute immediate 'begin dbms_sql.close_cursor@'||p_dblink||'(:p_theCursor); end;' using in out l_theCursor;
    l_time:=DBMS_UTILITY.GET_TIME-l_time;
    coremod_log.log('Executing: '||(l_time/100),'DEBUG');
    l_time:=DBMS_UTILITY.GET_TIME;
    loop
      execute immediate 'begin DBMS_OUTPUT.GET_LINE@'||p_dblink||'(line => :p_line, status => :p_status); end;' using out l_line, out l_status;
      exit when l_status=1;
      --p_output:=p_output||l_line||chr(10);
      p_output:=p_output||utl_raw.cast_to_varchar2(UTL_COMPRESS.LZ_UNCOMPRESS(l_line));
    end loop;
    if instr(p_output,'<NO_DATA_FOUND>')>0 then p_output:=null; end if;
    l_time:=DBMS_UTILITY.GET_TIME-l_time;
    coremod_log.log('Getting output: '||(l_time/100),'DEBUG');
  exception
    when others then
       execute immediate 'begin :p_open:=dbms_sql.IS_OPEN@'||p_dblink||'(:p_theCursor); end;' using out l_open, in l_theCursor;
      if l_open then
        execute immediate 'begin dbms_sql.close_cursor@'||p_dblink||'(:p_theCursor); end;' using in out l_theCursor;
      end if;
      coremod_log.log('execute_plsql_remotelly: Error: '||sqlerrm);
      coremod_log.log('execute_plsql_remotelly: Original SQL: '||p_sql);
      coremod_log.log('execute_plsql_remotelly: Final SQL: '||l_sql2exec);
      coremod_log.log('execute_plsql_remotelly: Error stack: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      raise_application_error(-20000,'Error in COREMOD_REPORT_UTILS.execute_plsql_remotelly: '||sqlerrm);
  end;

  procedure get_clob_remotelly(p_sql varchar2, p_dblink varchar2, p_output out clob)
  is
  begin
    execute_plsql_remotelly(p_sql, p_dblink, p_output, true);
  end;
END COREMOD_UTILS;
/
