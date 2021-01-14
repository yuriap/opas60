

CREATE OR REPLACE
PACKAGE BODY COREOBJ_SQL_PROFILE AS

  function get_binary_sql_text(p_sql_text clob) return clob AS
    l_result clob;
    l_len          number;
    l_chunk        varchar2(4000);
    l_pos          number;
    l_chunk_length number := 100;
    l_r            varchar2(4000); --raw(32767);	
  begin
    l_pos := 1;
    l_len := length(p_sql_text);
    loop
      l_chunk := substr(p_sql_text, l_pos, l_chunk_length);
      l_pos   := l_pos + l_chunk_length;
      l_r     := utl_raw.cast_to_raw(l_chunk);
      l_result := l_result || l_r || chr(10);
      exit when l_len < l_pos;
    end loop;	
    return l_result;
  end;

  function get_binary_sql_text(p_file_id opas_files.file_id%type) return clob AS
    l_text   clob;
  BEGIN
    select FILE_CONTENTC into l_text from OPAS_FILES where FILE_ID = p_file_id;

    RETURN get_binary_sql_text(l_text);
  END get_binary_sql_text;

  function prepare_sql_profile_patch(p_sql_id         opas_ot_sql_descriptions.sql_id%type,
                                     p_type           number,
                                     p_hint           varchar2) return opas_files.file_id%type
  is
    l_tmpl_file_id opas_files.file_id%type;
    l_tmpl         clob;
    l_sql_orig_id  opas_files.file_id%type;
    l_sql_bin      clob;
    l_script       clob;
    l_filename     varchar2(1000);
  begin
    l_tmpl_file_id := to_number(COREMOD_API.getconf('SQLPROFILERTEMPL',COREMOD_API.gMODNAME));
    select rtrim(rtrim(file_contentc,chr(10)),chr(13)) into l_tmpl from OPAS_FILES where file_id=l_tmpl_file_id;
    select SQL_TEXT into l_sql_orig_id from OPAS_OT_SQL_DESCRIPTIONS where SQL_ID = p_sql_id;
    l_sql_bin := get_binary_sql_text(l_sql_orig_id);

    l_script := replace(l_tmpl,'<SQL_ID>',p_sql_id);
    l_script := replace(l_script,'<SQL Outline>',p_hint);
    l_script := replace(l_script,'<SQL_BIN_TEXT>',l_sql_bin);

    if p_type = tpSQLProfile then
      l_script := replace(l_script,'<COMMENTSQLPATCH>','--');
      l_script := replace(l_script,'<COMMENTSQLPROFILE>','');
      l_filename := 'SQLProfile_'||p_sql_id||'.sql';
    elsif p_type = tpSQLPatch then
      l_script := replace(l_script,'<COMMENTSQLPATCH>','');
      l_script := replace(l_script,'<COMMENTSQLPROFILE>','--');
      l_filename := 'SQLPatch_'||p_sql_id||'.sql';
    end if;

    l_tmpl_file_id := COREMOD_FILE_UTILS.prepare_file_4download(P_FILE_NAME => l_filename,
                                                                P_FILE_MIME_TYPE => COREMOD_FILE_UTILS.mtPLAINTEXT,
                                                                P_FILE_CONTENT => l_script||chr(10)||'/');

    return l_tmpl_file_id;
  end;

  function bulk_create_sql_profile(p_src_qry         varchar2, -- select sql_text from some_table
                                   p_hint            varchar2)
                                   return opas_files.file_id%type
  is
    l_crsr     sys_refcursor;
    l_qry_text clob;
    l_sql_id   varchar2(100);
    l_sql_bin  clob;
    l_file_id  opas_files.file_id%type;
    l_script   clob;

    g_script1 varchar2(32765):=q'~declare
    g_sql_id varchar2(20);
    g_outline varchar2(32765) := q'[~'; --'

    g_script2 varchar2(32765):=q'~]';
    g_sqlbin clob;
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

    procedure create_profile(p_sql_id varchar2, p_outline varchar2, p_sqlbin clob)
    is
      l_profile_name varchar2(30);
      l_sql_id varchar2(20):=p_sql_id;
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
      cl_sql_text := decypher_sql(p_sqlbin);
      l_profile_name := 'PROFB_'||l_sql_id;
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
        dbms_output.put_line('ERROR: SQL with sql_id='||l_sql_id||' '||sqlerrm);
    end;
  begin
  ~'; --'

    procedure p (p_msg varchar2) is
    begin l_script := l_script || chr(10) || p_msg; end;
  begin
    p(g_script1);
    p(p_hint);
    p(g_script2);

    open l_crsr for p_src_qry;
    loop
      fetch l_crsr into l_qry_text;
      exit when l_crsr%notfound;
      l_sql_id :=  sys.dbms_sqltune_util0.sqltext_to_sqlid (l_qry_text);

      p('g_sqlbin:=q''[');

      p(get_binary_sql_text(l_qry_text));
      p(']'';');
      p('g_sql_id:='''||l_sql_id||''';');
      p('create_profile(g_sql_id,g_outline,g_sqlbin);');
    end loop;
    p('end;');
    --p('/');
    l_file_id := COREMOD_FILE_UTILS.prepare_file_4download(P_FILE_NAME => 'PROFB_'||to_char(sysdate,'YYYYMMDD_HH24MI')||'.sql',
                                                           P_FILE_MIME_TYPE => COREMOD_FILE_UTILS.mtPLAINTEXT,
                                                           P_FILE_CONTENT => l_script||chr(10)||'/');

    return l_file_id;
  end;

END COREOBJ_SQL_PROFILE;
/


