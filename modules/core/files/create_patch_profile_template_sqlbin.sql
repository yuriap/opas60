set serveroutput on
declare
  g_sql_id varchar2(20)     :='<SQL_ID>';
  g_outline varchar2(32765) := q'{<SQL Outline>}';
  g_sqlbin clob := q'{<SQL_BIN_TEXT>}';
  function decypher_sql(p_sqlbin clob) return clob
  is
    cl_sql_text clob;
    l_len          number;
    l_chunk        varchar2(80);
    l_pos          number;
    l_chunk_length number := 80;
    l_sqlbin       clob;
  begin
    l_sqlbin := replace(replace(p_sqlbin,chr(13)),chr(10));
    l_pos := 1;
    l_len := length(l_sqlbin);
    loop
      l_chunk := substr(l_sqlbin, l_pos, l_chunk_length);
      l_pos   := l_pos + l_chunk_length;
      cl_sql_text:=cl_sql_text||utl_raw.cast_to_varchar2(l_chunk);
      exit when l_len < l_pos;
    end loop;       
    return cl_sql_text;
  end;
  procedure create_profile(p_sql_id varchar2, p_outline varchar2)
  is
    l_profile_name varchar2(30);
    cl_sql_text clob;
    function split_outln(p_outline varchar2) return sqlprof_attr
    is
      l_outln sqlprof_attr:=sqlprof_attr();
      l_part varchar2(500);
      l_outline varchar2(32765):=p_outline;
      l_end_pos number;
begin
      loop
        l_end_pos := instr(substr(l_outline,1,500),')',-1);
        if l_end_pos=0 and length(l_outline)>0 then
          l_part := l_outline;
        else
          l_part:=substr(l_outline,1,l_end_pos);
        end if;
        l_outln.extend;
        l_outln(l_outln.last):=l_part;  
        l_outline:=substr(l_outline,length(l_part)+1);
        exit when l_outline is null;
      end loop;
      return l_outln;
    end;
  begin
    cl_sql_text := decypher_sql(g_sqlbin);
    l_profile_name := 'PROF_'||p_sql_id;
    begin dbms_sqltune.drop_sql_profile(l_profile_name); exception when others then null; end;
    dbms_sqltune.import_sql_profile(
      sql_text => cl_sql_text, 
      profile => split_outln(p_outline),
      category => 'DEFAULT',
      name => l_profile_name,
      force_match => true
    );
    dbms_output.put_line(' ');
    dbms_output.put_line('Profile '||l_profile_name||' created.');
    dbms_output.put_line(' ');
  EXCEPTION
    when others then 
      dbms_output.put_line('ERROR: SQL with sql_id='||p_sql_id||' '||sqlerrm);
  end;
  procedure create_sql_patch(p_sql_id varchar2, p_hint varchar2)
  is
    l_sqlpatch_name varchar2(30);
    cl_sql_text clob;
  begin  
    cl_sql_text := decypher_sql(g_sqlbin);
    l_sqlpatch_name := 'SQLPATCH_'||p_sql_id;
    begin DBMS_SQLDIAG.drop_sql_patch(name => l_sqlpatch_name); exception when others then null; end;
    SYS.DBMS_SQLDIAG_INTERNAL.i_create_patch(
      sql_text  => cl_sql_text,
      hint_text => p_hint,
      name      => l_sqlpatch_name);    
    dbms_output.put_line(' ');
    dbms_output.put_line('SQL Parch '||l_sqlpatch_name||' created.');
    dbms_output.put_line(' ');
  EXCEPTION
    when others then 
      dbms_output.put_line('ERROR creating SQL Patch: SQL with sql_id='||p_sql_id||' '||sqlerrm);
  end;  
begin
  <COMMENTSQLPATCH>create_sql_patch(g_sql_id,g_outline);  
  <COMMENTSQLPROFILE>create_profile(g_sql_id,g_outline);
end;